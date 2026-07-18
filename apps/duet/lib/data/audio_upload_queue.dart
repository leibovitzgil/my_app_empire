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
/// [drain] retries each task, bumping its attempt count on failure; once a task
/// reaches `maxAttempts` it is **not silently dropped** but moved to a
/// dedicated *failed* list (a persisted dead-letter set) so a permanently
/// failing upload is surfaced rather than becoming silent data loss. It
/// reconciles against current storage on completion so an [enqueue] that races
/// a drain is never clobbered. The [pending] count stream feeds the sync badge
/// (M4.1); the [failed] count stream lets the app surface poison entries the
/// user can then [skip] (permanently discard) or [retryFailed] (M8.4).
class AudioUploadQueue {
  /// Creates an [AudioUploadQueue] persisted under [storage].
  AudioUploadQueue({required LocalStorageService storage, int maxAttempts = 5})
    : _storage = storage,
      _maxAttempts = maxAttempts {
    _controller = StreamController<int>.broadcast(
      onListen: () => _controller.add(pendingCount),
    );
    _failedController = StreamController<int>.broadcast(
      onListen: () => _failedController.add(failedCount),
    );
  }

  static const String _key = 'audio.upload_queue';
  static const String _failedKey = 'audio.upload_queue.failed';

  final LocalStorageService _storage;
  final int _maxAttempts;
  late final StreamController<int> _controller;
  late final StreamController<int> _failedController;
  bool _draining = false;

  /// The current pending count, emitted whenever the queue changes (and once
  /// on subscribe).
  Stream<int> get pending => _controller.stream;

  /// How many uploads are currently queued.
  int get pendingCount => _load().length;

  /// The count of permanently-failed (poison) uploads, emitted whenever the
  /// failed set changes (and once on subscribe). A non-zero value means a
  /// recorded note gave up after `maxAttempts` drains and needs the user's
  /// attention — it is retained, never silently lost.
  Stream<int> get failed => _failedController.stream;

  /// How many uploads have permanently failed (reached `maxAttempts`).
  int get failedCount => _loadFailed().length;

  /// The permanently-failed tasks, so the app can name the affected notes when
  /// surfacing them.
  List<AudioUploadTask> get failedTasks => _loadFailed();

  List<AudioUploadTask> _load() => _read(_key);

  List<AudioUploadTask> _loadFailed() => _read(_failedKey);

  List<AudioUploadTask> _read(String key) {
    final raw = _storage.getString(key);
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

  Future<void> _saveFailed(List<AudioUploadTask> tasks) async {
    await _storage.setString(
      _failedKey,
      jsonEncode([for (final t in tasks) t.toJson()]),
    );
    if (!_failedController.isClosed) _failedController.add(tasks.length);
  }

  /// Appends [task] (idempotent by `assetId` — re-enqueuing the same recording
  /// is a no-op).
  Future<void> enqueue(AudioUploadTask task) async {
    final tasks = _load();
    if (tasks.any((t) => t.assetId == task.assetId)) return;
    await _save([...tasks, task]);
  }

  /// Uploads each queued task via [uploadOne]: on success it's removed; on
  /// failure its attempt count is bumped and it's kept for a later drain. Once
  /// a task reaches `maxAttempts` it is moved to the [failed] set rather than
  /// silently dropped, so a permanently-failing note is surfaced (and
  /// [skip]/[retryFailed]-able) instead of lost. Re-entrant-safe — a concurrent
  /// drain returns immediately.
  Future<void> drain(
    Future<Result<void>> Function(AudioUploadTask task) uploadOne,
  ) async {
    if (_draining) return;
    _draining = true;
    try {
      final snapshot = _load();
      // assetId -> replacement task, or absent from the map = "removed from the
      // active queue" (either uploaded, or poisoned into `failed`).
      final replacements = <String, AudioUploadTask>{};
      final dropped = <String>{};
      // Tasks that exhausted their attempts this drain — retained (not lost).
      final poisoned = <AudioUploadTask>[];
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
          // Give up on the active queue, but keep it in the failed set so the
          // user is told and can decide, instead of silent data loss.
          dropped.add(task.assetId);
          poisoned.add(retried);
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
      if (poisoned.isNotEmpty) {
        final existing = _loadFailed();
        final seen = {for (final t in existing) t.assetId};
        await _saveFailed([
          ...existing,
          for (final t in poisoned)
            if (seen.add(t.assetId)) t,
        ]);
      }
    } finally {
      _draining = false;
    }
  }

  /// Permanently discards the failed upload [assetId] (the user chose to skip
  /// it). A no-op if it isn't in the failed set.
  Future<void> skip(String assetId) async {
    final failed = _loadFailed();
    if (!failed.any((t) => t.assetId == assetId)) return;
    await _saveFailed([
      for (final t in failed)
        if (t.assetId != assetId) t,
    ]);
  }

  /// Moves every failed upload back onto the active queue with a fresh attempt
  /// count, so a later [drain] retries them (e.g. the user tapped "retry" once
  /// connectivity is restored). Failed entries already queued (by `assetId`)
  /// are not duplicated.
  Future<void> retryFailed() async {
    final failed = _loadFailed();
    if (failed.isEmpty) return;
    final active = _load();
    final queued = {for (final t in active) t.assetId};
    await _save([
      ...active,
      for (final t in failed)
        if (queued.add(t.assetId))
          AudioUploadTask(
            pieceId: t.pieceId,
            assetId: t.assetId,
            localPath: t.localPath,
          ),
    ]);
    await _saveFailed(const <AudioUploadTask>[]);
  }

  /// Releases the [pending] and [failed] streams.
  Future<void> close() async {
    await _controller.close();
    await _failedController.close();
  }
}
