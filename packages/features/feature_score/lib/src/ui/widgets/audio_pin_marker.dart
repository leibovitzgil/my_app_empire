import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:pieces/pieces.dart';

/// A tappable circular marker for a single [AudioNote], positioned by the
/// caller at the region's centroid.
///
/// Tapping plays/stops the note (driven by `AudioPlaybackCubit` in the
/// caller); when [isPlaying] a progress ring fills in around the marker.
/// Long-pressing surfaces a delete action, but only when [note] belongs to
/// [currentUserId] — otherwise the affordance is entirely absent, not just
/// disabled.
class AudioPinMarker extends StatelessWidget {
  /// Creates an [AudioPinMarker] for [note].
  const AudioPinMarker({
    required this.note,
    required this.currentUserId,
    required this.isPlaying,
    required this.onTap,
    required this.onDelete,
    this.progress,
    super.key,
  });

  /// The audio note this marker represents.
  final AudioNote note;

  /// The signed-in participant's id, used to gate the delete affordance.
  final String currentUserId;

  /// Whether this note is the one currently playing.
  final bool isPlaying;

  /// The current playback progress, if [isPlaying].
  final double? progress;

  /// Called when the marker is tapped (play or stop, caller's choice).
  final VoidCallback onTap;

  /// Called when the user confirms deletion from the long-press menu.
  final VoidCallback onDelete;

  bool get _ownedByCurrentUser => note.authorId == currentUserId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ringColor = _ownedByCurrentUser ? scheme.primary : scheme.tertiary;
    final label = isPlaying
        ? 'Playing audio note. Double tap to stop.'
        : _ownedByCurrentUser
        ? 'Your audio note. Double tap to play.'
        : 'Audio note. Double tap to play.';

    final marker = SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: scheme.surface,
        shape: CircleBorder(
          side: BorderSide(color: ringColor, width: isPlaying ? 3 : 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: isPlaying
                ? SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2,
                      color: ringColor,
                    ),
                  )
                : Icon(Icons.play_arrow, color: ringColor, size: 20),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: label,
      child: _ownedByCurrentUser
          ? GestureDetector(
              onLongPress: () => _confirmDelete(context),
              child: marker,
            )
          : marker,
    );
  }

  Future<void> _confirmDelete(BuildContext context) {
    return AppBottomSheet.show<void>(
      context,
      title: 'Audio note',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Delete this audio note',
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDelete();
              },
            ),
          ),
        ],
      ),
    );
  }
}
