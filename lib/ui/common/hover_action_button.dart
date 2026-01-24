import 'package:flutter/material.dart';

/// Reusable wrapper for action buttons with white color, subtle shadow, and hover-controlled visibility
class HoverActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final double iconSize;
  final bool isCardHovered; // Controlled by parent card's hover state

  const HoverActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.iconSize = 24,
    required this.isCardHovered,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isCardHovered ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            Shadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        iconSize: iconSize,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: iconSize + 8,
          minHeight: iconSize + 8,
        ),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

