import 'dart:async';
import 'dart:convert';

import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:local_storage/local_storage.dart';

/// One pending audio-asset upload: the recorded file at [localPath] must reach
/// Storage as `pieces/[pieceId]/audio/[assetId]`. [attempts] counts failed
/// drains so the queue can give up on a persistently-failing task.
class AudioUploadTask extends Equatable {
  /// Creates an [AudioUploadTask].
  const AudioUploadTask({
    required this.pieceId,
    required this.assetId,
    required this.localPath,
    this.attempts = 0,
  });

  /// Reverses [toJson].
  factory AudioUploadTask.fromJson(Map<String, dynamic> json) =>
      AudioUploadTask(
        pieceId: json['pieceId'] as String,
        assetId: json['assetId'] as String,
        localPath: json['localPath'] as String,
        attempts: json['attempts'] as int? ?? 0,
      );

  /// The piece the asset belongs to.
  final String pieceId;

  /// The asset id (the Storage object name).
  final String assetId;

  /// The on-device path of the recorded file to upload.
  final String localPath;

  /// How many drains have failed for this task.
  final int attempts;

  /// A copy with [attempts] bumped by one.
  AudioUploadTask retried() => AudioUploadTask(
    pieceId: pieceId,
    assetId: assetId,
    localPath: localPath,
    attempts: attempts + 1,
  );

  /// Serializes to JSON for persistence.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'pieceId': pieceId,
    'assetId': assetId,
    'localPath': localPath,
    'attempts': attempts,
  };

  @override
  List<Object?> get props => [pieceId, assetId, localPath, attempts];
}

/// A persisted FIFO queue of audio uploads that **survives app restarts**
/// (backed by [LocalStorageService]), so a note recorded offline still reaches
/// Storage once connectivity returns.
///
/// [drain] retries each task, bumping its attempt count on failure and dropping
/// it after `maxAttempts`; it reconciles against current storage on completion
/// so an [enqueue] that races a drain is never clobbered. The [pending] count
/// stream feeds the sync badge (M4.1).
class AudioUploadQueue {
  /// Creates an [AudioUploadQueue] persisted under [storage].
  AudioUploadQueue({required LocalStorageService storage, int maxAttempts = 5})
    : _storage = storage,
      _maxAttempts = maxAttempts {
    _controller = StreamController<int>.broadcast(
      onListen: () => _controller.add(pendingCount),
    );
  }

  static const String _key = 'audio.upload_queue';

  final LocalStorageService _storage;
  final int _maxAttempts;
  late final StreamController<int> _controller;
  bool _draining = false;

  /// The current pending count, emitted whenever the queue changes (and once
  /// on subscribe).
  Stream<int> get pending => _controller.stream;

  /// How many uploads are currently queued.
  int get pendingCount => _load().length;

  List<AudioUploadTask> _load() {
    final raw = _storage.getString(_key);
    if (raw == null) return <AudioUploadTask>[];
    return [
      for (final e in jsonDecode(raw) as List<dynamic>)
        AudioUploadTask.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<void> _save(List<AudioUploadTask> tasks) async {
    await _storage.setString(
      _key,
      jsonEncode([for (final t in tasks) t.toJson()]),
    );
    if (!_controller.isClosed) _controller.add(tasks.length);
  }

  /// Appends [task] (idempotent by `assetId` — re-enqueuing the same recording
  /// is a no-op).
  Future<void> enqueue(AudioUploadTask task) async {
    final tasks = _load();
    if (tasks.any((t) => t.assetId == task.assetId)) return;
    await _save([...tasks, task]);
  }

  /// Uploads each queued task via [uploadOne]: on success it's removed; on
  /// failure its attempt count is bumped and it's kept for a later drain
  /// (dropped once it reaches `maxAttempts`). Re-entrant-safe — a concurrent
  /// drain returns immediately.
  Future<void> drain(
    Future<Result<void>> Function(AudioUploadTask task) uploadOne,
  ) async {
    if (_draining) return;
    _draining = true;
    try {
      final snapshot = _load();
      // assetId -> replacement task, or absent from the map = "drop".
      final replacements = <String, AudioUploadTask>{};
      final dropped = <String>{};
      for (final task in snapshot) {
        final result = await uploadOne(task);
        if (result is Success<void>) {
          dropped.add(task.assetId);
          continue;
        }
        final retried = task.retried();
        if (retried.attempts < _maxAttempts) {
          replacements[task.assetId] = retried;
        } else {
          dropped.add(task.assetId); // Give up.
        }
      }
      // Reconcile against current storage (which may hold enqueues that raced
      // this drain): keep every task that wasn't dropped, swapping in its
      // retried copy where one exists. A task enqueued mid-drain is in neither
      // set, so it survives untouched.
      final reconciled = <AudioUploadTask>[
        for (final task in _load())
          if (!dropped.contains(task.assetId))
            replacements[task.assetId] ?? task,
      ];
      await _save(reconciled);
    } finally {
      _draining = false;
    }
  }

  /// Releases the [pending] stream.
  Future<void> close() => _controller.close();
}
