import 'package:equatable/equatable.dart';

/// A serialized, shareable snapshot of a piece's annotations (ink strokes
/// and audio notes) plus the audio asset files it references, ready to hand
/// off via `ReviewSyncService.share`.
class ExportedBundle extends Equatable {
  /// Creates an [ExportedBundle].
  const ExportedBundle({
    required this.pieceId,
    required this.filePath,
    required this.manifest,
  });

  /// The id of the piece this bundle was exported from.
  final String pieceId;

  /// The on-device path of the packaged bundle file.
  final String filePath;

  /// A human-readable summary of the bundle's contents.
  final ReviewBundleSummary manifest;

  @override
  List<Object?> get props => [pieceId, filePath, manifest];
}

/// A human-readable summary of an [ExportedBundle]'s contents, so a
/// recipient can preview what they're about to import.
class ReviewBundleSummary extends Equatable {
  /// Creates a [ReviewBundleSummary].
  const ReviewBundleSummary({
    required this.pieceTitle,
    required this.strokeCount,
    required this.audioNoteCount,
    required this.exportedAt,
  });

  /// The title of the piece the bundle was exported from.
  final String pieceTitle;

  /// The number of ink strokes contained in the bundle.
  final int strokeCount;

  /// The number of audio notes contained in the bundle.
  final int audioNoteCount;

  /// When the bundle was exported.
  final DateTime exportedAt;

  @override
  List<Object?> get props => [
    pieceTitle,
    strokeCount,
    audioNoteCount,
    exportedAt,
  ];
}
