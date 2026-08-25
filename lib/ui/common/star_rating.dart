import 'package:flutter/material.dart';

/// A 1–10 rating displayed as 10 full stars.
/// Each star represents one point. Tapping a star sets that value.
/// Set [onChanged] to null for read-only.
class StarRating extends StatefulWidget {
  final int? value; // 1–10, null = unrated
  final ValueChanged<int>? onChanged; // receives 1–10
  final double starSize;
  final Color? activeColor;
  final Color? hoverColor;
  final Color? inactiveColor;
  final bool compact;

  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.starSize = 28,
    this.activeColor,
    this.hoverColor,
    this.inactiveColor,
    this.compact = false,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  /// The value (1–10) currently being hovered, or null if not hovering.
  int? _hoverValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.activeColor ?? Colors.amber;
    final hover = widget.hoverColor ?? Colors.amber.withValues(alpha: 0.6);
    final inactive = widget.inactiveColor ?? theme.colorScheme.outlineVariant;
    final spacing = widget.compact ? 1.0 : 2.0;

    // Hover takes precedence over set value for display
    final displayValue = _hoverValue ?? widget.value ?? 0;
    final isHovering = _hoverValue != null;

    return MouseRegion(
      onExit: widget.onChanged != null
          ? (_) => setState(() => _hoverValue = null)
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(10, (i) {
          final starValue = i + 1; // 1–10
          final isFilled = displayValue >= starValue;
          final fillColor = isHovering ? hover : active;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: widget.onChanged != null
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoverValue = starValue),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onChanged!(starValue),
                      child: Icon(
                        isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: widget.starSize,
                        color: isFilled ? fillColor : inactive,
                      ),
                    ),
                  )
                : Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: widget.starSize,
                    color: isFilled ? active : inactive,
                  ),
          );
        }),
      ),
    );
  }
}

/// Compact read-only badge: "★ 7/10" styled text.
class RatingBadge extends StatelessWidget {
  final double value; // 1.0–10.0
  final bool isComputed; // true = derived from episodes/seasons (shown lighter)
  final double fontSize;

  const RatingBadge({
    super.key,
    required this.value,
    this.isComputed = false,
    this.fontSize = 11,
  });

  String get _label {
    // Show as integer if whole number, one decimal if not (e.g. computed avg 7.3)
    final display = value % 1 == 0
        ? '${value.toInt()}/10'
        : '${value.toStringAsFixed(1)}/10';
    return '★ $display';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: isComputed
            ? Colors.amber.withValues(alpha: 0.65)
            : Colors.amber,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}
