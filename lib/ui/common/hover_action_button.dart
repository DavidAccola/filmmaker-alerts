import 'dart:async';
import 'package:flutter/material.dart';

/// Reusable wrapper for action buttons with white color, subtle shadow, and hover-controlled visibility
class HoverActionButton extends StatefulWidget {
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
  State<HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<HoverActionButton> {
  Timer? _hoverTimer;
  bool _showButton = false;

  @override
  void didUpdateWidget(HoverActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isCardHovered != oldWidget.isCardHovered) {
      if (widget.isCardHovered) {
        // Start timer when hover begins
        _hoverTimer = Timer(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() => _showButton = true);
          }
        });
      } else {
        // Cancel timer and hide immediately when hover ends
        _hoverTimer?.cancel();
        setState(() => _showButton = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If already hovering when widget is built/updated, ensure button shows
    if (widget.isCardHovered && !_showButton) {
      _hoverTimer?.cancel();
      _hoverTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() => _showButton = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _showButton ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_showButton,
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: Duration.zero, // Show immediately once button is visible
          showDuration: const Duration(seconds: 3),
          child: IconButton(
            onPressed: widget.onPressed,
            icon: Icon(
              widget.icon,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            iconSize: widget.iconSize,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: widget.iconSize + 8,
              minHeight: widget.iconSize + 8,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}

