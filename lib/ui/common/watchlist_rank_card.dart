import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../data/models/watchlist_entry.dart';
import '../../data/models/contributor_detail.dart';
import '../../providers/providers.dart';
import 'adaptive_tooltip_text.dart';

/// A compact watchlist card designed for User Rank mode.
/// Shows poster, title, and rank number without status buttons.
/// Poster and title are tappable for navigation, rest of card initiates drag.
class WatchlistRankCard extends ConsumerStatefulWidget {
  final WatchlistEntry entry;
  final int rank;
  final int index; // Used by ReorderableDragStartListener
  final VoidCallback? onTap;
  final VoidCallback? onSendToTop;
  final VoidCallback? onSendToBottom;
  final bool isDragging;

  const WatchlistRankCard({
    super.key,
    required this.entry,
    required this.rank,
    required this.index,
    this.onTap,
    this.onSendToTop,
    this.onSendToBottom,
    this.isDragging = false,
  });

  @override
  ConsumerState<WatchlistRankCard> createState() => _WatchlistRankCardState();
}

class _WatchlistRankCardState extends ConsumerState<WatchlistRankCard> {
  bool _isHovered = false;

  /// Checks if this entry is a collection (movie with Collection role)
  bool get _isCollection => widget.entry.type == WorkType.movie && 
      widget.entry.followedContributors.any((c) => c.role == 'Collection');

  /// Gets the appropriate icon for this entry type
  IconData get _typeIcon => widget.entry.type == WorkType.tvShow 
      ? Symbols.tv_gen 
      : _isCollection 
          ? Symbols.stack 
          : Symbols.movie;

  /// Gets the appropriate label for this entry type
  String get _typeLabel => widget.entry.type == WorkType.tvShow 
      ? 'TV' 
      : _isCollection 
          ? 'Collection' 
          : 'Movie';

  /// Gets the most relevant release date for display
  DateTime? _getEffectiveReleaseDate() {
    final entry = widget.entry;

    if (entry.type == WorkType.tvShow) {
      final tvDetailRepo = ref.read(tvDetailRepositoryProvider);
      final showDetail = tvDetailRepo.getTvShowDetail(entry.tmdbId);
      if (showDetail != null && showDetail.lastAirDate != null) {
        return showDetail.lastAirDate;
      }
      return entry.releaseDate;
    }

    if (_isCollection) {
      final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
      final movies = movieStatusRepo.getMoviesByCollection(entry.tmdbId);
      DateTime? mostRecent;
      for (final movie in movies) {
        if (movie.releaseDate != null) {
          if (mostRecent == null || movie.releaseDate!.isAfter(mostRecent)) {
            mostRecent = movie.releaseDate;
          }
        }
      }
      return mostRecent ?? entry.releaseDate;
    }

    return entry.releaseDate;
  }

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
                // Rank number badge
                Container(
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

                // Poster thumbnail - tap navigates, drag reorders
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
                                _typeIcon,
                                size: 24,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              _typeIcon,
                              size: 24,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                ),

                // Title area - tap navigates
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                    child: Padding(
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
                              _typeIcon,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _typeLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            if (_getEffectiveReleaseDate() != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${_getEffectiveReleaseDate()!.year}',
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
                ),

                // Send to top / Send to bottom buttons
                if (widget.onSendToTop != null || widget.onSendToBottom != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onSendToTop != null)
                        IconButton(
                          icon: Icon(
                            Icons.vertical_align_top,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip: 'Send to top',
                          onPressed: widget.onSendToTop,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      if (widget.onSendToBottom != null)
                        IconButton(
                          icon: Icon(
                            Icons.vertical_align_bottom,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip: 'Send to bottom',
                          onPressed: widget.onSendToBottom,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                    ],
                  ),

                // Drag handle — visual indicator for drag-to-reorder
                MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    padding: const EdgeInsets.only(left: 8, right: 16),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
