import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:duet/features/score/src/bloc/audio_playback_cubit.dart';
import 'package:duet/features/score/src/bloc/record_audio_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The floating "Audio note" card shown over the reader while a note is
/// being recorded for a selected passage (which stays spotlit on the page
/// behind it — see `RegionHighlightOverlay`).
///
/// Drives the full record → review → keep/discard loop against the
/// [RecordAudioCubit] it reads from context:
///
/// * Recording starts as soon as the card mounts — the user just chose
///   "Record an audio note", so the natural next act is to talk, not to hunt
///   for a second record button. A pulsing mic, an elapsed timer, and an
///   honest progress track toward the [RecordAudioCubit.maxDuration] cap
///   show it's live; Stop moves to review.
/// * Review offers a real listen-back (via the shared [AudioPlaybackCubit],
///   under [previewNoteId]) before committing — Save keeps it, Discard
///   throws it away.
/// * A denied microphone (or any recorder failure) lands in an inline error
///   state with retry, never a dead card.
///
/// Unmounting mid-recording cancels the recorder (the mic never stays hot)
/// and mid-preview stops playback.
class RecordNoteCard extends StatefulWidget {
  /// Creates a [RecordNoteCard].
  const RecordNoteCard({
    required this.regionLabel,
    required this.outputPathBuilder,
    required this.onSave,
    required this.onDismiss,
    super.key,
  });

  /// Where on the piece the note will pin, e.g. "Page 2 · selected passage".
  final String regionLabel;

  /// Produces a fresh on-device output path for each recording attempt.
  final String Function() outputPathBuilder;

  /// Called with the recorded file and its duration when "Save note" is
  /// tapped. The caller owns persisting the note and closing the flow.
  final void Function(String path, Duration elapsed) onSave;

  /// Called when the recording is discarded or the error state is cancelled.
  /// The caller owns closing the flow.
  final VoidCallback onDismiss;

  /// The [AudioPlaybackCubit] note id used for the pre-save listen-back —
  /// namespaced so it can never collide with a real pinned note's id.
  static const String previewNoteId = '__record_preview__';

  @override
  State<RecordNoteCard> createState() => _RecordNoteCardState();
}

class _RecordNoteCardState extends State<RecordNoteCard> {
  // Captured at mount because dispose() needs them after this widget has
  // left the tree, where context lookups are no longer safe.
  late final RecordAudioCubit _record;
  late final AudioPlaybackCubit _playback;

  @override
  void initState() {
    super.initState();
    _record = context.read<RecordAudioCubit>();
    _playback = context.read<AudioPlaybackCubit>();
    // Post-frame so the first build (and its BlocBuilder subscriptions) is
    // in place before the cubit starts emitting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_record.state.status == RecordAudioStatus.idle) {
        unawaited(_record.start(widget.outputPathBuilder()));
      }
    });
  }

  @override
  void dispose() {
    if (_record.state.status == RecordAudioStatus.recording) {
      unawaited(_record.cancel());
    }
    _stopPreviewIfPlaying();
    super.dispose();
  }

  void _stopPreviewIfPlaying() {
    if (_playback.state.isPlaying(RecordNoteCard.previewNoteId)) {
      unawaited(_playback.stop());
    }
  }

  void _togglePreview(RecordAudioState state) {
    if (_playback.state.isPlaying(RecordNoteCard.previewNoteId)) {
      unawaited(_playback.stop());
    } else {
      final path = state.path;
      if (path != null) {
        unawaited(_playback.play(RecordNoteCard.previewNoteId, path));
      }
    }
  }

  void _save(RecordAudioState state) {
    final path = state.path;
    if (path == null) return;
    _stopPreviewIfPlaying();
    widget.onSave(path, state.elapsed);
    _record.save();
  }

  void _discard() {
    _stopPreviewIfPlaying();
    _record.discard();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<RecordAudioCubit, RecordAudioState>(
      builder: (context, state) {
        return Material(
          color: scheme.surfaceContainerHigh,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md + AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: switch (state.status) {
                RecordAudioStatus.idle ||
                RecordAudioStatus.recording => _RecordingBody(
                  regionLabel: widget.regionLabel,
                  elapsed: state.elapsed,
                  onStop: () => unawaited(_record.stop()),
                ),
                RecordAudioStatus.reviewing => _ReviewBody(
                  regionLabel: widget.regionLabel,
                  state: state,
                  onTogglePreview: () => _togglePreview(state),
                  onDiscard: _discard,
                  onSave: () => _save(state),
                ),
                RecordAudioStatus.error => _ErrorBody(
                  message: state.error ?? 'Something went wrong.',
                  onRetry: () =>
                      unawaited(_record.start(widget.outputPathBuilder())),
                  onCancel: _discard,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

/// `m:ss` with no leading zero on minutes, matching the reader's other
/// duration labels.
String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.regionLabel});

  final String title;
  final String regionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            regionLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordingBody extends StatelessWidget {
  const _RecordingBody({
    required this.regionLabel,
    required this.elapsed,
    required this.onStop,
  });

  final String regionLabel;
  final Duration elapsed;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const cap = RecordAudioCubit.maxDuration;
    final fraction = (elapsed.inMilliseconds / cap.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardHeader(title: 'Audio note', regionLabel: regionLabel),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _PulsingMicDisc(color: scheme.error, iconColor: scheme.onError),
            const SizedBox(width: AppSpacing.lg),
            // An honest track — real elapsed time against the recording cap,
            // not a synthesized waveform.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.error,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              label: 'Recording, ${elapsed.inSeconds} seconds',
              child: Text(
                _formatDuration(elapsed),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recording… talk through the passage for your partner.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: 'Stop recording',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: onStop,
                icon: const Icon(Icons.stop, size: 20),
                label: const Text(
                  'Stop',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.regionLabel,
    required this.state,
    required this.onTogglePreview,
    required this.onDiscard,
    required this.onSave,
  });

  final String regionLabel;
  final RecordAudioState state;
  final VoidCallback onTogglePreview;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardHeader(
          title: 'Recorded ${state.elapsed.inSeconds}s — keep it?',
          regionLabel: regionLabel,
        ),
        const SizedBox(height: AppSpacing.md),
        BlocBuilder<AudioPlaybackCubit, AudioPlaybackState>(
          builder: (context, playback) {
            final playing = playback.isPlaying(RecordNoteCard.previewNoteId);
            final progress = playing ? playback.progress : null;
            final position = progress?.position ?? Duration.zero;
            final fraction =
                progress == null || progress.duration == Duration.zero
                ? (playing ? null : 0.0)
                : (position.inMilliseconds / progress.duration.inMilliseconds)
                      .clamp(0.0, 1.0);
            return Row(
              children: [
                Semantics(
                  button: true,
                  label: playing
                      ? 'Stop listening'
                      : 'Listen to your recording',
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                      icon: Icon(
                        playing ? Icons.stop : Icons.play_arrow,
                        size: 26,
                      ),
                      onPressed: onTogglePreview,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 5,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(
                  '${_formatDuration(position)} / '
                  '${_formatDuration(state.elapsed)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: 'Discard this recording',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  side: BorderSide(color: scheme.outlineVariant),
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: onDiscard,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Discard'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Semantics(
              button: true,
              label: 'Save this audio note',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: onSave,
                icon: const Icon(Icons.check, size: 20),
                label: const Text(
                  'Save note',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.mic_off_outlined, size: 21, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "Couldn't record",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: 'Cancel recording an audio note',
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  side: BorderSide(color: scheme.outlineVariant),
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Semantics(
              button: true,
              label: 'Try recording again',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.mic, size: 20),
                label: const Text('Try again'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The recording state's mic disc: a filled circle with a soft breathing
/// halo, so "the mic is live" is visible even before the timer ticks.
class _PulsingMicDisc extends StatefulWidget {
  const _PulsingMicDisc({required this.color, required this.iconColor});

  final Color color;
  final Color iconColor;

  @override
  State<_PulsingMicDisc> createState() => _PulsingMicDiscState();
}

class _PulsingMicDiscState extends State<_PulsingMicDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.10 + 0.14 * t),
                  spreadRadius: 4 + 5 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
          child: Icon(Icons.mic, size: 28, color: widget.iconColor),
        ),
      ),
    );
  }
}
