import 'package:flutter/material.dart';
import '../../data/models/status_record.dart';

/// A bar that displays status selection options for marking episodes.
/// 
/// Uses [SegmentedButton] on desktop (≥768px) with symbol + label text,
/// and compact [FilterChip] row on mobile (<768px) with symbol only.
/// 
/// The selected status determines what status will be applied when
/// checking episode/season checkboxes. Changing the selection does NOT
/// affect already-marked items.
class StatusSelectorBar extends StatelessWidget {
  /// The currently selected status.
  final WatchStatus selectedStatus;

  /// Called when the user selects a different status.
  final ValueChanged<WatchStatus> onStatusChanged;

  /// Desktop breakpoint width in pixels.
  static const double _desktopBreakpoint = 768.0;

  const StatusSelectorBar({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

          if (isDesktop) {
            return _buildDesktopLayout(context);
          } else {
            return _buildMobileLayout(context);
          }
        },
      ),
    );
  }

  /// Builds the desktop layout using [SegmentedButton] with icon + label.
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Text(
          'Status to apply:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SegmentedButton<WatchStatus>(
            showSelectedIcon: false,
            segments: WatchStatus.values.map((status) {
              final isSelected = selectedStatus == status;
              return ButtonSegment<WatchStatus>(
                value: status,
                icon: Icon(
                  _getStatusIcon(status),
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(_getStatusText(status)),
              );
            }).toList(),
            selected: {selectedStatus},
            onSelectionChanged: (Set<WatchStatus> newSelection) {
              onStatusChanged(newSelection.first);
            },
          ),
        ),
      ],
    );
  }

  /// Builds the mobile layout using [FilterChip] row with icon only.
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Status to apply:',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: WatchStatus.values.map((status) {
            final isSelected = selectedStatus == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: _getStatusText(status),
                child: FilterChip(
                  label: Icon(
                    _getStatusIcon(status),
                    size: 18,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  selected: isSelected,
                  onSelected: (_) => onStatusChanged(status),
                  backgroundColor: Colors.transparent,
                  selectedColor: theme.colorScheme.primaryContainer,
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Returns the icon for a given [WatchStatus].
  /// Uses the same icons as WatchlistCard for consistency.
  IconData _getStatusIcon(WatchStatus status) {
    switch (status) {
      case WatchStatus.wantToWatch:
        return Icons.bookmark;
      case WatchStatus.inProgress:
        return Icons.play_circle;
      case WatchStatus.watched:
        return Icons.check_circle;
      case WatchStatus.dnf:
        return Icons.cancel;
    }
  }

  /// Returns the display text for a given [WatchStatus].
  String _getStatusText(WatchStatus status) {
    switch (status) {
      case WatchStatus.wantToWatch:
        return 'Want to Watch';
      case WatchStatus.inProgress:
        return 'In Progress';
      case WatchStatus.watched:
        return 'Watched';
      case WatchStatus.dnf:
        return 'Did Not Finish';
    }
  }
}
