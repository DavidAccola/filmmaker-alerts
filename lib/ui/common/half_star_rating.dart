import 'package:flutter/material.dart';

/// A 1–10 rating displayed as 1–5 stars with half-star precision.
/// [value] is 1–10 (integer). Displayed as 0.5–5.0 stars.
/// Tapping sets a new value. Set [onChanged] to null for read-only.
class HalfStarRating extends StatelessWidget {
  final int? value; // 1–10, null = unrated
  final ValueChanged<int>? onChanged; // receives 1–10
  final double starSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool compact; // if true, renders smaller with less spacing

  const HalfStarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.starSize = 28,
    this.activeColor,
    this.inactiveColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? Colors.amber;
    final inactive = inactiveColor ?? theme.colorScheme.outlineVariant;
    final spacing = compact ? 1.0 : 2.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (starIndex) {
        // Each star represents values (starIndex*2+1) and (starIndex*2+2)
        // e.g. star 0 = half=1, full=2; star 1 = half=3, full=4; etc.
        final halfValue = starIndex * 2 + 1;
        final fullValue = starIndex * 2 + 2;

        // Determine fill state
        final isFull = value != null && value! >= fullValue;
        final isHalf = value != null && value! == halfValue;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: onChanged != null
              ? _InteractiveStar(
                  isFull: isFull,
                  isHalf: isHalf,
                  size: starSize,
                  active: active,
                  inactive: inactive,
                  onHalfTap: () => onChanged!(halfValue),
                  onFullTap: () => onChanged!(fullValue),
                )
              : _StaticStar(
                  isFull: isFull,
                  isHalf: isHalf,
                  size: starSize,
                  active: active,
                  inactive: inactive,
                ),
        );
      }),
    );
  }
}

/// Read-only star
class _StaticStar extends StatelessWidget {
  final bool isFull;
  final bool isHalf;
  final double size;
  final Color active;
  final Color inactive;

  const _StaticStar({
    required this.isFull,
    required this.isHalf,
    required this.size,
    required this.active,
    required this.inactive,
  });

  @override
  Widget build(BuildContext context) {
    if (isFull) {
      return Icon(Icons.star_rounded, size: size, color: active);
    } else if (isHalf) {
      return Icon(Icons.star_half_rounded, size: size, color: active);
    } else {
      return Icon(Icons.star_outline_rounded, size: size, color: inactive);
    }
  }
}

/// Interactive star — left half sets halfValue, right half sets fullValue
class _InteractiveStar extends StatefulWidget {
  final bool isFull;
  final bool isHalf;
  final double size;
  final Color active;
  final Color inactive;
  final VoidCallback onHalfTap;
  final VoidCallback onFullTap;

  const _InteractiveStar({
    required this.isFull,
    required this.isHalf,
    required this.size,
    required this.active,
    required this.inactive,
    required this.onHalfTap,
    required this.onFullTap,
  });

  @override
  State<_InteractiveStar> createState() => _InteractiveStarState();
}

class _InteractiveStarState extends State<_InteractiveStar> {
  bool _hoverHalf = false;
  bool _hoverFull = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _hoverHalf || _hoverFull;

    Widget starIcon;
    if (widget.isFull || _hoverFull) {
      // When hoverFull is true, hovered is always true — no need for the isActive branch.
      final color = hovered
          ? widget.active.withValues(alpha: 0.8)
          : (widget.isFull ? widget.active : widget.inactive);
      starIcon = Icon(Icons.star_rounded, size: widget.size, color: color);
    } else if (widget.isHalf || _hoverHalf) {
      starIcon = Icon(Icons.star_half_rounded, size: widget.size,
          color: hovered ? widget.active.withValues(alpha: 0.8) : widget.active);
    } else {
      starIcon = Icon(Icons.star_outline_rounded, size: widget.size,
          color: hovered ? widget.active.withValues(alpha: 0.5) : widget.inactive);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          starIcon,
          // Left half — half star
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.size / 2,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() { _hoverHalf = true; _hoverFull = false; }),
              onExit: (_) => setState(() { _hoverHalf = false; }),
              child: GestureDetector(
                onTap: widget.onHalfTap,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Right half — full star
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: widget.size / 2,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() { _hoverFull = true; _hoverHalf = false; }),
              onExit: (_) => setState(() { _hoverFull = false; }),
              child: GestureDetector(
                onTap: widget.onFullTap,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact read-only badge: "★ 7.5" styled text.
/// [value] is 1–10. Displayed as X.0 or X.5.
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
    // Display as X or X.5 (trim unnecessary .0)
    final display = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
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
