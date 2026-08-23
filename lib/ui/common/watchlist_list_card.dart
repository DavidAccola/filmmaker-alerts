import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../data/models/watchlist_entry.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/status_record.dart';
import '../../providers/providers.dart';
import 'status_colors.dart';
import 'half_star_rating.dart';
import 'snackbar_utils.dart';
import '../screens/show_configuration_screen.dart';
import '../screens/collection_configuration_screen.dart';

/// A compact single-line list card for watchlist items.
/// Shows: [title] [year] ... [want-to-watch] [in-progress] [watched] [⋮ menu]
class WatchlistListCard extends ConsumerStatefulWidget {
  final WatchlistEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSnooze;
  final Function(WatchStatus)? onStatusChanged;
  final bool showDateAlways;

  const WatchlistListCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onDelete,
    this.onSnooze,
    this.onStatusChanged,
    this.showDateAlways = false,
  });

  @override
  ConsumerState<WatchlistListCard> createState() => _WatchlistListCardState();
}

class _WatchlistListCardState extends ConsumerState<WatchlistListCard> {
  bool get _isCollection => widget.entry.type == WorkType.movie &&
      widget.entry.followedContributors.any((c) => c.role == 'Collection');

  bool get _hasConfigScreen => widget.entry.type == WorkType.tvShow || _isCollection;

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

  Map<WatchStatus, int> _getStatusCounts() {
    final entry = widget.entry;
    if (entry.type == WorkType.tvShow) {
      final episodeRepo = ref.read(episodeStatusRepositoryProvider);
      final episodes = episodeRepo.getEpisodesByShow(entry.tmdbId);
      final counts = <WatchStatus, int>{};
      for (final episode in episodes) {
        for (final record in episode.statusRecords) {
          counts[record.status] = (counts[record.status] ?? 0) + 1;
        }
      }
      return counts;
    } else if (_isCollection) {
      final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
      final movies = movieStatusRepo.getMoviesByCollection(entry.tmdbId);
      final counts = <WatchStatus, int>{};
      for (final movie in movies) {
        for (final record in movie.statusRecords) {
          counts[record.status] = (counts[record.status] ?? 0) + 1;
        }
      }
      return counts;
    }
    return {};
  }

  int _getDnfCount() {
    final entry = widget.entry;
    if (entry.type == WorkType.tvShow) {
      final episodeRepo = ref.read(episodeStatusRepositoryProvider);
      final episodes = episodeRepo.getEpisodesByShow(entry.tmdbId);
      int count = 0;
      for (final ep in episodes) {
        if (ep.statusRecords.any((r) => r.status == WatchStatus.dnf)) count++;
      }
      return count;
    } else if (_isCollection) {
      final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
      final movies = movieStatusRepo.getMoviesByCollection(entry.tmdbId);
      int count = 0;
      for (final movie in movies) {
        if (movie.statusRecords.any((r) => r.status == WatchStatus.dnf)) count++;
      }
      return count;
    }
    return 0;
  }

  int _getTotalItemCount() {
    final entry = widget.entry;
    if (entry.type == WorkType.tvShow) {
      final tvDetailRepo = ref.read(tvDetailRepositoryProvider);
      final showDetail = tvDetailRepo.getTvShowDetail(entry.tmdbId);
      return showDetail?.numberOfEpisodes ?? 0;
    } else if (_isCollection) {
      final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
      return movieStatusRepo.getMoviesByCollection(entry.tmdbId).length;
    }
    return 0;
  }

  void _navigateToConfigWithMarkAll(WatchStatus status, {bool isUnmarking = false}) {
    final entry = widget.entry;
    if (entry.type == WorkType.tvShow) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShowConfigurationScreen(
            showId: entry.tmdbId,
            showTitle: entry.title,
            initialMarkAllStatus: status,
            isUnmarkingStatus: isUnmarking,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CollectionConfigurationScreen(
            collectionId: entry.tmdbId,
            collectionTitle: entry.title,
            initialMarkAllStatus: status,
            isUnmarkingStatus: isUnmarking,
          ),
        ),
      );
    }
  }

  Future<void> _handleWantToWatchToggle(bool currentlyMarked) async {
    if (currentlyMarked) {
      final result = await showWantToWatchUnmarkPrompt(context, widget.entry.title);
      if (result == 'unmark') {
        final logic = ref.read(watchlistLogicProvider);
        await logic.removeStatusFromWork(
          widget.entry.tmdbId, widget.entry.type, WatchStatus.wantToWatch);
        ref.invalidate(watchlistEntriesProvider);
      } else if (result == 'hide') {
        final logic = ref.read(watchlistLogicProvider);
        await logic.removeStatusFromWork(
          widget.entry.tmdbId, widget.entry.type, WatchStatus.wantToWatch);
        await logic.setSnoozed(widget.entry.tmdbId, widget.entry.type, true);
        ref.invalidate(watchlistEntriesProvider);
      } else if (result == 'delete') {
        widget.onDelete?.call();
      }
    } else {
      widget.onStatusChanged?.call(WatchStatus.wantToWatch);
    }
  }

  IconData get _typeIcon => widget.entry.type == WorkType.tvShow
      ? Symbols.tv_gen
      : _isCollection
          ? Symbols.stack
          : Symbols.movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final hasDnf = entry.statusRecords.any((r) => r.status == WatchStatus.dnf);
    final hasWantToWatch = entry.statusRecords.any((r) => r.status == WatchStatus.wantToWatch);
    final hasInProgress = entry.statusRecords.any((r) => r.status == WatchStatus.inProgress);
    final watchedRecords = entry.statusRecords.where((r) => r.status == WatchStatus.watched).toList();
    final hasWatched = watchedRecords.isNotEmpty;
    final watchCount = watchedRecords.isNotEmpty ? (watchedRecords.first.watchDates?.length ?? 1) : 0;
    final dnfCount = _hasConfigScreen ? _getDnfCount() : 0;
    final totalItemCount = _getTotalItemCount();

    // Reduced opacity for all-DNF items
    final showReducedOpacity = _hasConfigScreen
        ? (dnfCount > 0 && totalItemCount > 0 && dnfCount >= totalItemCount)
        : hasDnf;

    // Status counts for TV/collections
    final statusCounts = _hasConfigScreen ? _getStatusCounts() : <WatchStatus, int>{};
    final showWantToWatch = _hasConfigScreen ? (statusCounts[WatchStatus.wantToWatch] ?? 0) > 0 : hasWantToWatch;
    final showInProgress = _hasConfigScreen ? (statusCounts[WatchStatus.inProgress] ?? 0) > 0 : hasInProgress;
    final showWatched = _hasConfigScreen ? (statusCounts[WatchStatus.watched] ?? 0) > 0 : hasWatched;

    final year = _getEffectiveReleaseDate()?.year;
    final tooltipText = year != null ? '${entry.title} ($year)' : entry.title;
    final isDark = theme.brightness == Brightness.dark;

    return Opacity(
      opacity: showReducedOpacity ? 0.6 : 1.0,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: 36,
            child: Row(
              children: [
                // Poster
                SizedBox(
                  width: 24,
                  height: 36,
                  child: entry.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w200${entry.posterPath}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(_typeIcon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(_typeIcon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        ),
                ),
                const SizedBox(width: 10),

                // Title + year (flexible, title truncates first, year hides on small screens)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final yearStr = year != null ? '$year' : null;
                      // Measure title to detect truncation
                      final titleStyle = theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 13,
                      ) ?? const TextStyle(fontSize: 13);
                      final yearStyle = theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant, fontSize: 11,
                      ) ?? const TextStyle(fontSize: 11);

                      // Reserve space for year if present
                      final yearWidth = yearStr != null
                          ? (TextPainter(
                              text: TextSpan(text: yearStr, style: yearStyle),
                              maxLines: 1,
                              textDirection: TextDirection.ltr,
                            )..layout()).width + 6 // 6 = gap
                          : 0.0;

                      final titlePainter = TextPainter(
                        text: TextSpan(text: entry.title, style: titleStyle),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout();

                      final availableForTitle = constraints.maxWidth - yearWidth;
                      final isTruncated = titlePainter.width > availableForTitle;
                      // If title won't fit even without year, hide year
                      final showYear = yearStr != null && titlePainter.width <= constraints.maxWidth - yearWidth;

                      final row = Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.title,
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
                        return Tooltip(
                          message: tooltipText,
                          child: row,
                        );
                      }
                      return row;
                    },
                  ),
                ),

                const SizedBox(width: 4),

                // Rating badge (shown when rated)
                Builder(builder: (context) {
                  final ratingLogic = ref.read(ratingLogicProvider);
                  final effective = ratingLogic.effectiveRating(entry);
                  final isComputed = effective != null && !ratingLogic.isManualRating(entry);
                  if (effective == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: RatingBadge(
                      value: effective,
                      isComputed: isComputed,
                      fontSize: 11,
                    ),
                  );
                }),

                // Status buttons
                _buildStatusIcon(
                  icon: Icons.bookmark_border,
                  activeIcon: Icons.bookmark,
                  status: WatchStatus.wantToWatch,
                  isActive: showWantToWatch,
                  isDark: isDark,
                  onTap: _hasConfigScreen
                      ? () => _navigateToConfigWithMarkAll(WatchStatus.wantToWatch)
                      : () => _handleWantToWatchToggle(hasWantToWatch),
                ),
                _buildStatusIcon(
                  icon: Icons.play_circle_outline,
                  activeIcon: Icons.play_circle,
                  status: WatchStatus.inProgress,
                  isActive: showInProgress,
                  isDark: isDark,
                  onTap: _hasConfigScreen
                      ? () => _navigateToConfigWithMarkAll(WatchStatus.inProgress)
                      : () => widget.onStatusChanged?.call(WatchStatus.inProgress),
                ),
                _buildStatusIcon(
                  icon: Icons.check_circle_outline,
                  activeIcon: Icons.check_circle,
                  status: WatchStatus.watched,
                  isActive: showWatched,
                  isDark: isDark,
                  label: _hasConfigScreen
                      ? null
                      : watchCount > 1 ? 'x$watchCount' : null,
                  onTap: _hasConfigScreen
                      ? () => _navigateToConfigWithMarkAll(WatchStatus.watched)
                      : () => widget.onStatusChanged?.call(WatchStatus.watched),
                ),

                // 3-dot menu
                _buildPopupMenu(context, theme, entry, hasDnf, dnfCount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon({
    required IconData icon,
    required IconData activeIcon,
    required WatchStatus status,
    required bool isActive,
    required bool isDark,
    String? label,
    VoidCallback? onTap,
  }) {
    final color = isActive
        ? StatusColors.getColor(status, isDark: isDark)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 18, color: color),
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, ThemeData theme, WatchlistEntry entry,
      bool hasDnf, int dnfCount) {
    final totalItemCount = _getTotalItemCount();
    final allItemsDnf = _hasConfigScreen
        ? (dnfCount > 0 && totalItemCount > 0 && dnfCount >= totalItemCount)
        : hasDnf;
    final dnfLabel = allItemsDnf ? 'Unmark Did not finish' : 'Did not finish';

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.onSurfaceVariant),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        switch (value) {
          case 'delete':
            widget.onDelete?.call();
            break;
          case 'snooze':
            widget.onSnooze?.call();
            break;
          case 'dnf':
            if (hasDnf && !_hasConfigScreen) {
              final logic = ref.read(watchlistLogicProvider);
              logic.removeStatusFromWork(entry.tmdbId, entry.type, WatchStatus.dnf);
              ref.invalidate(watchlistEntriesProvider);
            } else if (_hasConfigScreen) {
              _navigateToConfigWithMarkAll(WatchStatus.dnf, isUnmarking: allItemsDnf);
            } else {
              widget.onStatusChanged?.call(WatchStatus.dnf);
            }
            break;
        }
      },
      itemBuilder: (context) {
        if (entry.isSnoozed) {
          return [
            const PopupMenuItem(value: 'snooze', child: Text('Unhide')),
            PopupMenuItem(value: 'dnf', child: Text(dnfLabel)),
            const PopupMenuItem(value: 'delete', child: Text('Remove')),
          ];
        } else {
          return [
            PopupMenuItem(value: 'dnf', child: Text(dnfLabel)),
            const PopupMenuItem(value: 'snooze', child: Text('Hide')),
            const PopupMenuItem(value: 'delete', child: Text('Remove')),
          ];
        }
      },
    );
  }
}
