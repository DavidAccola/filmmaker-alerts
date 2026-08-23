import 'package:flutter/material.dart';
import 'half_star_rating.dart';

/// The context for what is being rated — affects title/copy.
enum RatingContext {
  movie,
  tvShow,
  tvSeason,
  tvEpisode,
}

/// Result returned by the rating prompt.
class RatingResult {
  /// The chosen rating (1–10), or null if user chose to skip/clear.
  final int? rating;

  /// True if the user explicitly chose "Clear rating" (distinct from Skip).
  final bool cleared;

  const RatingResult({this.rating, this.cleared = false});
}

/// Shows a rating prompt as a bottom sheet (or dialog fallback).
/// Returns a [RatingResult], or null if dismissed (no action taken).
Future<RatingResult?> showRatingPrompt(
  BuildContext context, {
  required String title,
  required RatingContext ratingContext,
  int? existingRating,
  bool allowClear = false, // show "Clear rating" option when re-rating
}) async {
  return showModalBottomSheet<RatingResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RatingPromptSheet(
      title: title,
      ratingContext: ratingContext,
      existingRating: existingRating,
      allowClear: allowClear,
    ),
  );
}

class _RatingPromptSheet extends StatefulWidget {
  final String title;
  final RatingContext ratingContext;
  final int? existingRating;
  final bool allowClear;

  const _RatingPromptSheet({
    required this.title,
    required this.ratingContext,
    required this.existingRating,
    required this.allowClear,
  });

  @override
  State<_RatingPromptSheet> createState() => _RatingPromptSheetState();
}

class _RatingPromptSheetState extends State<_RatingPromptSheet> {
  int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.existingRating;
  }

  String get _headline {
    if (widget.existingRating != null) {
      return 'Update your rating';
    }
    return 'How was it?';
  }

  String get _ratingLabel {
    if (_selected == null) return 'Tap to rate';
    // Map 1–10 to descriptive labels
    return switch (_selected!) {
      1 || 2 => 'Awful',
      3 || 4 => 'Bad',
      5 || 6 => 'Okay',
      7 || 8 => 'Good',
      9 || 10 => 'Great',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Headline
          Text(
            _headline,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),

          // Stars
          HalfStarRating(
            value: _selected,
            starSize: 40,
            onChanged: (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: 8),

          // Descriptive label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              _ratingLabel,
              key: ValueKey(_ratingLabel),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _selected != null
                    ? Colors.amber
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Actions row
          Row(
            children: [
              // Clear (only when re-rating and explicitly allowed)
              if (widget.allowClear)
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pop(const RatingResult(cleared: true)),
                  child: Text(
                    'Clear rating',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const Spacer(),
              // Skip
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Skip'),
              ),
              const SizedBox(width: 8),
              // Save
              FilledButton(
                onPressed: _selected != null
                    ? () => Navigator.of(context)
                        .pop(RatingResult(rating: _selected))
                    : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
