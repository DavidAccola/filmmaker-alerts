import 'package:flutter/material.dart';

class ExpandableSynopsis extends StatefulWidget {
  final String synopsis;
  final bool isEpisode;
  final bool isUpcoming;

  const ExpandableSynopsis({
    super.key,
    required this.synopsis,
    this.isEpisode = false,
    this.isUpcoming = false,
  });

  @override
  State<ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<ExpandableSynopsis> {
  bool _isExpanded = false;
  bool _revealSpoiler = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    
    // Spoilers are hidden by default
    if (!_revealSpoiler) {
      return InkWell(
        onTap: () => setState(() => _revealSpoiler = true),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_off, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'View Synopsis',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String displaySynopsis = widget.synopsis.isEmpty ? 'No synopsis available.' : widget.synopsis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final span = TextSpan(text: displaySynopsis, style: textStyle);
            final painter = TextPainter(
              text: span,
              maxLines: 4,
              textDirection: TextDirection.ltr,
            );
            painter.layout(maxWidth: constraints.maxWidth);
            final bool hasMore = painter.didExceedMaxLines;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displaySynopsis,
                  maxLines: _isExpanded ? null : 4,
                  overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: textStyle,
                ),
                if (hasMore)
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        _isExpanded ? 'Show less' : 'Show more',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
