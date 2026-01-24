import 'package:flutter/material.dart';
import 'hover_action_button.dart';

/// Reusable Follow button with white color, subtle shadow, and hover-only visibility
class FollowButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final double iconSize;
  final bool isCardHovered;

  const FollowButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Add',
    this.iconSize = 18,
    required this.isCardHovered,
  });

  @override
  Widget build(BuildContext context) {
    return HoverActionButton(
      onPressed: onPressed,
      icon: Icons.add_circle,
      tooltip: tooltip,
      iconSize: iconSize,
      isCardHovered: isCardHovered,
    );
  }
}
