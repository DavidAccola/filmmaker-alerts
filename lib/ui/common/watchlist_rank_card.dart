import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../data/models/watchlist_entry.dart';
import '../../data/models/contributor_detail.dart';
import '../../providers/providers.dart';

/// A compact watchlist card for Custom Order reorder mode.
/// Layout: [#rank] [poster] [title year / send-to-top send-to-bottom] [drag handle]
class WatchlistRankCard extends ConsumerStatefulWidget {
  final WatchlistEntry entry;
  final int rank;
  final int index;
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

  bool get _isCollection => widget.entry.type == WorkType.movie &&
      widget.entry.followedContributors.any((c) => c.role == 'Collection');

  IconData get _typeIcon => widget.entry.type == WorkType.tvShow
      ? Symbols.tv_gen
      : _isCollection
          ? Symbols.stack
          : Symbols.movie;

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
    final year = _getEffectiveReleaseDate()?.year;
    final tooltipText = year != null ? '${widget.entry.title} ($year)' : widget.entry.title;
    final hasSendButtons = widget.onSendToTop != null || widget.onSendToBottom != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: widget.isDragging
            ? theme.colorScheme.surfaceContainerHighest
            : theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        elevation: widget.isDragging ? 4 : 1,
        child: SizedBox(
          height: hasSendButtons ? 52 : 36,
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    '#${widget.rank}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              // Poster
              GestureDetector(
                onTap: widget.onTap,
                child: SizedBox(
                  width: 24,
                  height: hasSendButtons ? 52 : 36,
                  child: widget.entry.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w200${widget.entry.posterPath}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(_typeIcon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(_typeIcon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        ),
                ),
              ),

              const SizedBox(width: 10),

              // Title + year (top line), send-to-top/bottom (bottom line)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + year row
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final titleStyle = theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 13,
                          ) ?? const TextStyle(fontSize: 13);
                          final yearStyle = theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant, fontSize: 11,
                          ) ?? const TextStyle(fontSize: 11);

                          final yearStr = year != null ? '$year' : null;
                          final yearWidth = yearStr != null
                              ? (TextPainter(
                                  text: TextSpan(text: yearStr, style: yearStyle),
                                  maxLines: 1,
                                  textDirection: TextDirection.ltr,
                                )..layout()).width + 6
                              : 0.0;

                          final titlePainter = TextPainter(
                            text: TextSpan(text: widget.entry.title, style: titleStyle),
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                          )..layout();

                          final showYear = yearStr != null &&
                              titlePainter.width <= constraints.maxWidth - yearWidth;
                          final isTruncated = titlePainter.width > (constraints.maxWidth - (showYear ? yearWidth : 0));

                          final row = Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.entry.title,
                                  style: titleStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (showYear) ...[
                                const SizedBox(width: 6),
                                Text('$year', style: yearStyle),
                              ],
                            ],
                          );

                          if (isTruncated || (!showYear && yearStr != null)) {
                            return Tooltip(message: tooltipText, child: row);
                          }
                          return row;
                        },
                      ),

                      // Send to top / bottom buttons
                      if (hasSendButtons)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              if (widget.onSendToTop != null)
                                _SmallActionButton(
                                  icon: Icons.vertical_align_top,
                                  label: 'Top',
                                  onTap: widget.onSendToTop!,
                                ),
                              if (widget.onSendToTop != null && widget.onSendToBottom != null)
                                const SizedBox(width: 8),
                              if (widget.onSendToBottom != null)
                                _SmallActionButton(
                                  icon: Icons.vertical_align_bottom,
                                  label: 'Bottom',
                                  onTap: widget.onSendToBottom!,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Drag handle
              MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 12),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
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
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
