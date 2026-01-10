import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A widget that automatically wraps its text in a Tooltip if it overflows.
class AdaptiveTooltipText extends StatelessWidget {
  final String? text;
  final InlineSpan? richText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final TextOverflow overflow;
  final String? customTooltip;
  final double? maxWidth;

  const AdaptiveTooltipText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.customTooltip,
    this.maxWidth,
  }) : richText = null;

  const AdaptiveTooltipText.rich(
    this.richText, {
    super.key,
    this.style, // This is the default style for the rich text
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.customTooltip,
    this.maxWidth,
  }) : text = null;

  @override
  Widget build(BuildContext context) {
    if (maxWidth != null) {
      return _buildWithWidth(context, maxWidth!);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildWithWidth(context, constraints.maxWidth);
      },
    );
  }

  Widget _buildWithWidth(BuildContext context, double width) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final span = richText ?? TextSpan(text: text, style: effectiveStyle);

    final textPainter = TextPainter(
      text: span,
      maxLines: maxLines,
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign ?? TextAlign.start,
    )..layout(maxWidth: width);

    // More robust truncation check
    final bool isTruncated = textPainter.didExceedMaxLines || 
                           (maxLines == 1 && textPainter.width >= width);

    final Widget textWidget = Text.rich(
      span,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );

    if (isTruncated) {
      return Tooltip(
        message: customTooltip ?? span.toPlainText(),
        waitDuration: const Duration(milliseconds: 200),
        child: textWidget,
      );
    }

    return textWidget;
  }
}
