import 'package:core_ui/core_ui.dart';
import 'package:feature_score/src/bloc/score_bloc.dart';
import 'package:flutter/material.dart';
import 'package:pieces/pieces.dart';

/// Three [LabeledToggleChip]s for teacher ink / student ink / audio pins,
/// shown below the Score Viewer's app bar.
///
/// Whichever chip matches [currentRole] (teacher ink for a teacher, student
/// ink for a student) shows the chip's owned-indicator.
class LayerToggleBar extends StatelessWidget {
  /// Creates a [LayerToggleBar].
  const LayerToggleBar({
    required this.currentRole,
    required this.teacherInkVisible,
    required this.studentInkVisible,
    required this.audioPinsVisible,
    required this.onToggle,
    super.key,
  });

  /// The signed-in participant's role, used to show the owned-indicator.
  final PieceRole currentRole;

  /// Whether the teacher ink chip is currently selected (visible).
  final bool teacherInkVisible;

  /// Whether the student ink chip is currently selected (visible).
  final bool studentInkVisible;

  /// Whether the audio pins chip is currently selected (visible).
  final bool audioPinsVisible;

  /// Called with the toggled [LayerKind] when a chip is tapped.
  final ValueChanged<LayerKind> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          _chip(
            label: 'Teacher',
            icon: Icons.school_outlined,
            selected: teacherInkVisible,
            owned: currentRole == PieceRole.teacher,
            onTap: () => onToggle(LayerKind.teacherInk),
          ),
          const SizedBox(width: AppSpacing.sm),
          _chip(
            label: 'Student',
            icon: Icons.person_outline,
            selected: studentInkVisible,
            owned: currentRole == PieceRole.student,
            onTap: () => onToggle(LayerKind.studentInk),
          ),
          const SizedBox(width: AppSpacing.sm),
          _chip(
            label: 'Audio pins',
            icon: Icons.mic_none_outlined,
            selected: audioPinsVisible,
            onTap: () => onToggle(LayerKind.audioPins),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool owned = false,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Semantics(
        button: true,
        label:
            '$label layer${owned ? ' (yours)' : ''}, '
            '${selected ? 'shown' : 'hidden'}. Double tap to '
            '${selected ? 'hide' : 'show'}.',
        child: Center(
          child: LabeledToggleChip(
            label: label,
            icon: icon,
            selected: selected,
            owned: owned,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
