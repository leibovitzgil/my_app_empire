import 'dart:async';
import 'dart:convert';

import 'package:core_utils/core_utils.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pieces/src/data/annotation_mappers.dart';
import 'package:pieces/src/domain/annotation_repository.dart';
import 'package:pieces/src/domain/audio_note.dart';
import 'package:pieces/src/domain/ink_layer.dart';
import 'package:pieces/src/domain/ink_stroke.dart';
import 'package:pieces/src/domain/ownership.dart';
import 'package:pieces/src/domain/piece.dart';
import 'package:pieces/src/domain/piece_repository.dart';

/// An [AnnotationRepository] backed by [LocalStorageService] (JSON-encoded
/// per piece). Ownership enforcement (guarded by [_currentUserId]) applies
/// to every user-facing mutation; [replaceAuthorSlice] and [clearPiece] are
/// the two privileged, non-gated operations used by piece deletion and
/// review-bundle import.
class LocalAnnotationRepository implements AnnotationRepository {
  /// Creates a [LocalAnnotationRepository], guarding mutating calls with
  /// [currentUserId]. [pieceRepository] resolves a new author's
  /// [PieceRole] (owner vs. collaborator) the first time they add a stroke.
  LocalAnnotationRepository({
    required LocalStorageService storage,
    required String Function() currentUserId,
    required PieceRepository pieceRepository,
  }) : _storage = storage,
       _currentUserId = currentUserId,
       _pieceRepository = pieceRepository;

  static const String _keyPrefix = 'pieces.annotations.';

  final LocalStorageService _storage;
  final String Function() _currentUserId;
  final PieceRepository _pieceRepository;
  final Map<String, PieceAnnotations> _cache = <String, PieceAnnotations>{};
  final StreamController<PieceAnnotations> _controller =
      StreamController<PieceAnnotations>.broadcast();

  PieceAnnotations _annotationsFor(String pieceId) {
    final cached = _cache[pieceId];
    if (cached != null) return cached;
    final loaded = _load(pieceId);
    _cache[pieceId] = loaded;
    return loaded;
  }

  PieceAnnotations _load(String pieceId) {
    final raw = _storage.getString('$_keyPrefix$pieceId');
    if (raw == null) return PieceAnnotations.empty(pieceId);
    return pieceAnnotationsFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _emit(String pieceId, PieceAnnotations annotations) async {
    _cache[pieceId] = annotations;
    await _storage.setString(
      '$_keyPrefix$pieceId',
      jsonEncode(pieceAnnotationsToJson(annotations)),
    );
    if (!_controller.isClosed) _controller.add(annotations);
  }

  Future<PieceRole> _roleFor(String pieceId, String authorId) async {
    final result = await _pieceRepository.getPiece(pieceId);
    if (result case Success<Piece>(:final value)) {
      if (value.ownerId == authorId) return PieceRole.owner;
      if (value.isCollaborator(authorId)) return PieceRole.collaborator;
    }
    // Unknown piece or participant; default to collaborator since the owner
    // is always expected to be resolvable (they created the piece).
    return PieceRole.collaborator;
  }

  @override
  Stream<PieceAnnotations> watch(String pieceId) async* {
    yield _annotationsFor(pieceId);
    yield* _controller.stream.where((a) => a.pieceId == pieceId);
  }

  @override
  Future<Result<void>> addStroke(String pieceId, InkStroke stroke) =>
      Result.guard<void>(() async {
        final authorId = stroke.authorId;
        if (authorId != _currentUserId()) {
          throw OwnershipViolation(
            stroke.id,
            reason: 'cannot add a stroke authored by another participant',
          );
        }
        final current = _annotationsFor(pieceId);
        final existing = current.layers.where((l) => l.ownerId == authorId);
        final InkLayer layer;
        if (existing.isEmpty) {
          final role = await _roleFor(pieceId, authorId);
          layer = InkLayer(ownerId: authorId, role: role, strokes: [stroke]);
        } else {
          layer = existing.first.copyWith(
            strokes: [...existing.first.strokes, stroke],
          );
        }
        await _emit(
          pieceId,
          PieceAnnotations(
            pieceId: pieceId,
            layers: [
              ...current.layers.where((l) => l.ownerId != authorId),
              layer,
            ],
            audioNotes: current.audioNotes,
          ),
        );
      });

  @override
  Future<Result<void>> eraseStroke(String pieceId, String strokeId) =>
      Result.guard<void>(() async {
        final current = _annotationsFor(pieceId);
        for (final layer in current.layers) {
          final match = layer.strokes.where((s) => s.id == strokeId);
          if (match.isEmpty) continue;
          if (match.first.authorId != _currentUserId()) {
            throw OwnershipViolation(strokeId, reason: 'not the stroke author');
          }
          final updatedStrokes = [...layer.strokes]
            ..removeWhere((s) => s.id == strokeId);
          await _emit(
            pieceId,
            PieceAnnotations(
              pieceId: pieceId,
              layers: [
                for (final l in current.layers)
                  if (l.ownerId == layer.ownerId)
                    l.copyWith(strokes: updatedStrokes)
                  else
                    l,
              ],
              audioNotes: current.audioNotes,
            ),
          );
          return;
        }
        throw StateError('Unknown stroke: $strokeId');
      });

  @override
  Future<Result<void>> addAudioNote(String pieceId, AudioNote note) =>
      Result.guard<void>(() async {
        if (note.authorId != _currentUserId()) {
          throw OwnershipViolation(
            note.id,
            reason:
                'cannot add an audio note authored by another '
                'participant',
          );
        }
        final current = _annotationsFor(pieceId);
        await _emit(
          pieceId,
          PieceAnnotations(
            pieceId: pieceId,
            layers: current.layers,
            audioNotes: [...current.audioNotes, note],
          ),
        );
      });

  @override
  Future<Result<void>> deleteAudioNote(String pieceId, String noteId) =>
      Result.guard<void>(() async {
        final current = _annotationsFor(pieceId);
        final match = current.audioNotes.where((n) => n.id == noteId);
        if (match.isEmpty) {
          throw StateError('Unknown audio note: $noteId');
        }
        if (match.first.authorId != _currentUserId()) {
          throw OwnershipViolation(noteId, reason: 'not the note author');
        }
        await _emit(
          pieceId,
          PieceAnnotations(
            pieceId: pieceId,
            layers: current.layers,
            audioNotes: current.audioNotes
                .where((n) => n.id != noteId)
                .toList(),
          ),
        );
      });

  @override
  Future<Result<void>> clearPiece(String pieceId) =>
      Result.guard<void>(() async {
        final empty = PieceAnnotations.empty(pieceId);
        _cache[pieceId] = empty;
        await _storage.remove('$_keyPrefix$pieceId');
        if (!_controller.isClosed) _controller.add(empty);
      });

  @override
  Future<Result<void>> replaceAuthorSlice(
    String pieceId,
    String authorId, {
    required PieceRole role,
    required List<InkStroke> strokes,
    required List<AudioNote> audioNotes,
  }) => Result.guard<void>(() async {
    final current = _annotationsFor(pieceId);
    final layer = InkLayer(ownerId: authorId, role: role, strokes: strokes);
    await _emit(
      pieceId,
      PieceAnnotations(
        pieceId: pieceId,
        layers: [
          ...current.layers.where((l) => l.ownerId != authorId),
          layer,
        ],
        audioNotes: [
          ...current.audioNotes.where((n) => n.authorId != authorId),
          ...audioNotes,
        ],
      ),
    );
  });

  @override
  Future<Result<void>> removeAuthorSlice(String pieceId, String authorId) =>
      Result.guard<void>(() async {
        final current = _annotationsFor(pieceId);
        await _emit(
          pieceId,
          PieceAnnotations(
            pieceId: pieceId,
            layers: current.layers.where((l) => l.ownerId != authorId).toList(),
            audioNotes: current.audioNotes
                .where((n) => n.authorId != authorId)
                .toList(),
          ),
        );
      });
}
