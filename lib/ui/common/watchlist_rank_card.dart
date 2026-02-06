import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/watchlist_entry.dart';
import '../../data/models/contributor_detail.dart';
import 'adaptive_tooltip_text.dart';

/// A compact watchlist card designed for User Rank mode.
/// Shows poster, title, and rank number without status buttons.
/// Poster and title are tappable for navigation, rest of card initiates drag.
class WatchlistRankCard extends StatefulWidget {
  final WatchlistEntry entry;
  final int rank;
  final int index; // Required for ReorderableDragStartListener
  final VoidCallback? onTap;
  final bool isDragging;

  const WatchlistRankCard({
    super.key,
    required this.entry,
    required this.rank,
    required this.index,
    this.onTap,
    this.isDragging = false,
  });

  @override
  State<WatchlistRankCard> createState() => _WatchlistRankCardState();
}

class _WatchlistRankCardState extends State<WatchlistRankCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: widget.isDragging
              ? [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: widget.isDragging
              ? theme.colorScheme.surfaceContainerHighest
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 75,
            child: Row(
              children: [
                // Rank number badge - DRAG AREA
                ReorderableDragStartListener(
                  index: widget.index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Container(
                      width: 48,
                      height: 75,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        border: Border(
                          right: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        '#${widget.rank}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),

                // Poster thumbnail - TAPPABLE for navigation
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                    child: SizedBox(
                      width: 50,
                      height: 75,
                      child: widget.entry.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: 'https://image.tmdb.org/t/p/w200${widget.entry.posterPath}',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  widget.entry.type == WorkType.movie ? Icons.movie : Icons.tv,
                                  size: 24,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                widget.entry.type == WorkType.movie ? Icons.movie : Icons.tv,
                                size: 24,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                ),

                // Title area - TAPPABLE for navigation (constrained width)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AdaptiveTooltipText(
                            widget.entry.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.entry.type == WorkType.movie ? Icons.movie : Icons.tv,
                                size: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.entry.type == WorkType.movie ? 'Movie' : 'TV',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              if (widget.entry.releaseDate != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.entry.releaseDate!.year}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Empty space - DRAG AREA (fills remaining space)
                Expanded(
                  child: ReorderableDragStartListener(
                    index: widget.index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        height: 75,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),

                // Drag handle icon - DRAG AREA
                ReorderableDragStartListener(
                  index: widget.index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 75,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.drag_handle,
                        color: _isHovered
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
