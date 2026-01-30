import 'package:flutter/material.dart';
import 'snackbar_utils.dart';

/// A widget that displays filter controls for work sections
/// Shows either a "Filtered" badge or an info icon depending on filter state
class FilterToggleWidget extends StatelessWidget {
  /// Whether filtering is currently active
  final bool isFiltered;

  /// Whether filtering is applicable (can be toggled)
  final bool isApplicable;

  /// Callback when the toggle is clicked
  final VoidCallback onToggle;

  /// The reason why filtering is disabled (if applicable)
  /// Used for the info icon tooltip
  final String? disabledReason;

  /// The list of followed roles (for tooltip display)
  final String? followedRolesList;

  const FilterToggleWidget({
    super.key,
    required this.isFiltered,
    required this.isApplicable,
    required this.onToggle,
    this.disabledReason,
    this.followedRolesList,
  });

  @override
  Widget build(BuildContext context) {
    if (!isApplicable) {
      return const SizedBox.shrink();
    }

    // If filtering is disabled due to empty results, show info icon
    if (!isFiltered && disabledReason != null) {
      final tooltipText = disabledReason ?? '';
      return Tooltip(
        message: tooltipText,
        child: GestureDetector(
          onTap: () {
            // Show tooltip on tap for mobile
            showSimpleSnackBar(context, tooltipText, duration: const Duration(seconds: 3));
          },
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
    }

    // If filtering is active, show "Filtered" badge with toggle
    if (isFiltered) {
      final tooltipText = followedRolesList != null
          ? 'Filtered to followed roles: $followedRolesList\n\nClick to show all works'
          : 'Click to show all works';
      
      return GestureDetector(
        onTap: onToggle,
        child: Tooltip(
          message: tooltipText,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Filtered',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If filtering is disabled by user toggle, show "All works" toggle
    final tooltipText = followedRolesList != null
        ? 'Showing all works.\n\nClick to filter to followed roles: $followedRolesList'
        : 'Showing all works';
    
    return GestureDetector(
      onTap: onToggle,
      child: Tooltip(
        message: tooltipText,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.unfold_more,
                size: 14,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                'All works',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
