import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/watchlist_entry.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/contributor.dart'; // For TvNotificationPreferences
import '../../data/models/status_record.dart';
import 'adaptive_tooltip_text.dart';
import 'snackbar_utils.dart';
import 'release_preferences_dialog.dart';
import 'tv_preferences_dialog.dart';
import 'expand_poster_button.dart';
import 'status_colors.dart';
import '../../providers/providers.dart';
import '../screens/show_configuration_screen.dart';
import '../screens/collection_configuration_screen.dart';

class WatchlistCard extends ConsumerStatefulWidget {
  final WatchlistEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSnooze;
  final VoidCallback? onToggleNotificationSnooze;
  final Function(WatchStatus)? onStatusChanged;

  const WatchlistCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onDelete,
    this.onSnooze,
    this.onToggleNotificationSnooze,
    this.onStatusChanged,
  });

  @override
  ConsumerState<WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends ConsumerState<WatchlistCard> {
  bool _isHovered = false;

  /// Checks if this entry is a collection (movie with Collection role)
  bool get _isCollection => widget.entry.type == WorkType.movie && 
      widget.entry.followedContributors.any((c) => c.role == 'Collection');

  /// Gets episode status counts for a TV show
  Map<WatchStatus, int> _getEpisodeStatusCounts() {
    if (widget.entry.type != WorkType.tvShow) return {};
    
    final episodeRepo = ref.read(episodeStatusRepositoryProvider);
    final episodes = episodeRepo.getEpisodesByShow(widget.entry.tmdbId);
    
    final counts = <WatchStatus, int>{};
    for (final episode in episodes) {
      // Count all statuses for each episode (episodes can have multiple statuses)
      for (final record in episode.statusRecords) {
        counts[record.status] = (counts[record.status] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Gets movie status counts for a collection
  Map<WatchStatus, int> _getMovieStatusCounts() {
    if (!_isCollection) return {};
    
    final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
    final movies = movieStatusRepo.getMoviesByCollection(widget.entry.tmdbId);
    
    final counts = <WatchStatus, int>{};
    for (final movie in movies) {
      // Count all statuses for each movie (movies can have multiple statuses)
      for (final record in movie.statusRecords) {
        counts[record.status] = (counts[record.status] ?? 0) + 1;
      }
    }
    return counts;
  }

  void _navigateToCollectionConfig() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CollectionConfigurationScreen(
          collectionId: widget.entry.tmdbId,
          collectionTitle: widget.entry.title,
        ),
      ),
    );
  }

  /// Navigates to the config screen and shows a "Mark all as X" dialog
  Future<void> _navigateToConfigWithMarkAll(WatchStatus status) async {
    final entry = widget.entry;
    final isTvShow = entry.type == WorkType.tvShow;
    final itemLabel = isTvShow ? 'episodes' : 'movies';
    
    String statusName;
    switch (status) {
      case WatchStatus.wantToWatch:
        statusName = 'Want to watch';
        break;
      case WatchStatus.inProgress:
        statusName = 'In progress';
        break;
      case WatchStatus.watched:
        statusName = 'Watched';
        break;
      case WatchStatus.dnf:
        statusName = 'Did not finish';
        break;
    }
    
    // Show confirmation dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark all as $statusName?'),
        content: Text('This will mark all $itemLabel in "${entry.title}" as $statusName.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      // Navigate to config screen
      if (isTvShow) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ShowConfigurationScreen(
              showId: entry.tmdbId,
              showTitle: entry.title,
              initialMarkAllStatus: status,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CollectionConfigurationScreen(
              collectionId: entry.tmdbId,
              collectionTitle: entry.title,
              initialMarkAllStatus: status,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    // Get current statuses
    final hasWantToWatch = entry.statusRecords.any((r) => r.status == WatchStatus.wantToWatch);
    final hasInProgress = entry.statusRecords.any((r) => r.status == WatchStatus.inProgress);
    final watchedRecords = entry.statusRecords.where((r) => r.status == WatchStatus.watched).toList();
    final hasWatched = watchedRecords.isNotEmpty;
    final watchCount = watchedRecords.isNotEmpty ? watchedRecords.first.watchCount : 0;
    final hasDnf = entry.statusRecords.any((r) => r.status == WatchStatus.dnf);
    
    // For TV/collections, get DNF count and total count
    final isTvShow = entry.type == WorkType.tvShow;
    final isCollection = _isCollection;
    final hasConfigScreen = isTvShow || isCollection;
    
    int dnfCount = 0;
    int totalItemCount = 0;
    if (hasConfigScreen) {
      final statusCounts = isTvShow ? _getEpisodeStatusCounts() : _getMovieStatusCounts();
      dnfCount = statusCounts[WatchStatus.dnf] ?? 0;
      // Get total count from the repository
      if (isTvShow) {
        final episodeRepo = ref.read(episodeStatusRepositoryProvider);
        final tvDetailRepo = ref.read(tvDetailRepositoryProvider);
        final showDetail = tvDetailRepo.getTvShowDetail(entry.tmdbId);
        totalItemCount = showDetail?.numberOfEpisodes ?? 0;
      } else {
        // For collections, we need to check the movie count
        final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
        final movies = movieStatusRepo.getMoviesByCollection(entry.tmdbId);
        // Use the count from TMDB if available, otherwise use what we have
        totalItemCount = movies.length;
      }
    }
    
    // Determine if we should show reduced opacity
    // For movies: when hasDnf is true
    // For TV/collections: only when ALL items are DNF
    final showReducedOpacity = hasConfigScreen 
        ? (dnfCount > 0 && totalItemCount > 0 && dnfCount >= totalItemCount)
        : hasDnf;
    
    // Determine if we should show DNF indicator
    // For movies: when hasDnf is true
    // For TV/collections: when any items are DNF (show with count)
    final showDnfIndicator = hasConfigScreen ? dnfCount > 0 : hasDnf;

    Widget poster = entry.posterPath != null
        ? CachedNetworkImage(
            imageUrl: 'https://image.tmdb.org/t/p/w300${entry.posterPath}',
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.movie,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        : Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.movie,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Opacity(
        opacity: showReducedOpacity ? 0.6 : 1.0,
        child: Card(
          elevation: _isHovered ? 4 : 1,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              if (entry.type == WorkType.tvShow) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ShowConfigurationScreen(
                      showId: entry.tmdbId,
                      showTitle: entry.title,
                    ),
                  ),
                );
              } else if (entry.type == WorkType.movie && 
                        entry.followedContributors.any((c) => c.role == 'Collection')) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CollectionConfigurationScreen(
                      collectionId: entry.tmdbId,
                      collectionTitle: entry.title,
                    ),
                  ),
                );
              } else {
                widget.onTap?.call();
              }
            },
            child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poster image area - takes remaining space after title and buttons
              Expanded(
                child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fallback background for transparent posters
                  Container(
                    color: theme.colorScheme.surface,
                    child: poster,
                  ),

                  // Three-dot menu button (upper-right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          switch (value) {
                            case 'release_preferences':
                              _showReleasePreferencesDialog();
                              break;
                            case 'delete':
                              widget.onDelete?.call();
                              break;
                            case 'snooze':
                              widget.onSnooze?.call();
                              break;
                            case 'toggle_notifications':
                              widget.onToggleNotificationSnooze?.call();
                              break;
                            case 'dnf':
                              // For movies: toggle DNF status
                              // For TV/collections: navigate to config screen
                              if (entry.type == WorkType.tvShow) {
                                _navigateToShowConfig();
                              } else if (_isCollection) {
                                _navigateToCollectionConfig();
                              } else {
                                // Movie - toggle DNF
                                if (hasDnf) {
                                  // Remove DNF status
                                  final logic = ref.read(watchlistLogicProvider);
                                  logic.removeStatusFromWork(
                                    entry.tmdbId,
                                    entry.type,
                                    WatchStatus.dnf,
                                  );
                                  ref.invalidate(watchlistEntriesProvider);
                                } else {
                                  widget.onStatusChanged?.call(WatchStatus.dnf);
                                }
                              }
                              break;
                          }
                        },
                        itemBuilder: (context) {
                          final dnfLabel = entry.type == WorkType.tvShow || _isCollection
                              ? 'Did not finish...'
                              : hasDnf 
                                  ? 'Unmark Did not finish'
                                  : 'Did not finish';
                          
                          if (entry.isSnoozed) {
                            return [
                              const PopupMenuItem(
                                value: 'snooze',
                                child: Text('Unhide'),
                              ),
                              PopupMenuItem(
                                value: 'dnf',
                                child: Text(dnfLabel),
                              ),
                              const PopupMenuItem(
                                value: 'release_preferences',
                                child: Text('Release Preferences'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ];
                          } else {
                            return [
                              PopupMenuItem(
                                value: 'toggle_notifications',
                                child: Text(entry.notificationsSnoozed ? 'Unpause Notifications' : 'Pause Notifications'),
                              ),
                              PopupMenuItem(
                                value: 'dnf',
                                child: Text(dnfLabel),
                              ),
                              const PopupMenuItem(
                                value: 'release_preferences',
                                child: Text('Release Preferences'),
                              ),
                              const PopupMenuItem(
                                value: 'snooze',
                                child: Text('Hide'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ];
                          }
                        },
                      ),
                    ),
                  ),

                  // Notification snooze indicator
                  if (entry.notificationsSnoozed)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.notifications_off,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // DNF indicator (shows when item has DNF status)
                  if (showDnfIndicator)
                    Positioned(
                      top: entry.notificationsSnoozed ? 40 : 8,
                      left: 8,
                      child: Tooltip(
                        message: hasConfigScreen && dnfCount > 0
                            ? 'Did not finish ($dnfCount ${isTvShow ? 'episodes' : 'movies'})'
                            : 'Did not finish',
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close,
                                size: 16,
                                color: StatusColors.getColor(WatchStatus.dnf),
                              ),
                              if (hasConfigScreen && dnfCount > 0) ...[
                                const SizedBox(width: 2),
                                Text(
                                  dnfCount > 99 ? '99+' : '$dnfCount',
                                  style: TextStyle(
                                    color: StatusColors.getColor(WatchStatus.dnf),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Release date in bottom-left
                  if (entry.releaseDate != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatReleaseDate(entry.releaseDate!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),

                  // Media type icon in bottom-right
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        entry.type == WorkType.tvShow 
                            ? Icons.tv 
                            : _isCollection 
                                ? Icons.video_library 
                                : Icons.movie,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Expand Poster Button - appears in upper-left of poster
                  Positioned(
                    top: 4,
                    left: 4,
                    child: ExpandPosterButton(
                      posterPath: entry.posterPath,
                      title: entry.title,
                      isCardHovered: _isHovered,
                      iconSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Work information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: SizedBox(
                height: 20,
                child: AdaptiveTooltipText(
                  entry.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Status bar
            Container(
              height: 44, // Fixed height to prevent cutoff
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Builder(
                builder: (context) {
                  // Get episode counts for TV shows, movie counts for collections
                  final isTvShow = entry.type == WorkType.tvShow;
                  final isCollection = _isCollection;
                  final hasConfigScreen = isTvShow || isCollection;
                  
                  final statusCounts = isTvShow 
                      ? _getEpisodeStatusCounts() 
                      : isCollection
                          ? _getMovieStatusCounts()
                          : <WatchStatus, int>{};
                  final wantToWatchCount = statusCounts[WatchStatus.wantToWatch] ?? 0;
                  final inProgressCount = statusCounts[WatchStatus.inProgress] ?? 0;
                  final watchedCount = statusCounts[WatchStatus.watched] ?? 0;
                  
                  // For TV shows and collections, icons are active if ANY items have that status
                  // For movies, use the work-level status
                  final showWantToWatch = hasConfigScreen ? wantToWatchCount > 0 : hasWantToWatch;
                  final showInProgress = hasConfigScreen ? inProgressCount > 0 : hasInProgress;
                  final showWatched = hasConfigScreen ? watchedCount > 0 : hasWatched;
                  
                  // Format count for display - abbreviate large numbers
                  String? formatCount(int count) {
                    if (count == 0) return null;
                    if (count > 99) return '99+';
                    return '$count';
                  }

                  // Item label for tooltips
                  final itemLabel = isTvShow ? 'episodes' : 'movies';
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Want to watch button
                      Expanded(
                        child: _StatusButton(
                          icon: Icons.bookmark_border,
                          activeIcon: Icons.bookmark,
                          status: WatchStatus.wantToWatch,
                          isActive: showWantToWatch,
                          tooltip: hasConfigScreen && wantToWatchCount > 0 
                              ? 'Want to watch ($wantToWatchCount $itemLabel)' 
                              : 'Want to watch',
                          label: formatCount(wantToWatchCount),
                          // TV shows/collections: navigate with mark all dialog, movies: toggle want to watch
                          onTap: hasConfigScreen 
                              ? () => _navigateToConfigWithMarkAll(WatchStatus.wantToWatch)
                              : () => _handleWantToWatchToggle(hasWantToWatch),
                          onLongPress: hasConfigScreen ? () => _showDNFMenu(WatchStatus.wantToWatch) : null,
                        ),
                      ),

                      // In progress button
                      Expanded(
                        child: _StatusButton(
                          icon: Icons.play_circle_outline,
                          activeIcon: Icons.play_circle,
                          status: WatchStatus.inProgress,
                          isActive: showInProgress,
                          tooltip: hasConfigScreen && inProgressCount > 0 
                              ? 'In progress ($inProgressCount $itemLabel)' 
                              : 'In progress',
                          label: formatCount(inProgressCount),
                          // TV shows/collections: navigate with mark all dialog, movies: set in progress
                          onTap: hasConfigScreen 
                              ? () => _navigateToConfigWithMarkAll(WatchStatus.inProgress)
                              : () => widget.onStatusChanged?.call(WatchStatus.inProgress),
                          onLongPress: () => _showDNFMenu(WatchStatus.inProgress),
                        ),
                      ),

                      // Watched button
                      Expanded(
                        child: _StatusButton(
                          icon: Icons.check_circle_outline,
                          activeIcon: Icons.check_circle,
                          status: WatchStatus.watched,
                          isActive: showWatched,
                          tooltip: hasConfigScreen && watchedCount > 0
                              ? 'Watched ($watchedCount $itemLabel)'
                              : watchCount > 1 
                                  ? 'Watched x$watchCount' 
                                  : 'Watched',
                          label: hasConfigScreen 
                              ? formatCount(watchedCount)
                              : watchCount > 1 
                                  ? 'x$watchCount' 
                                  : null,
                          // TV shows/collections: navigate with mark all dialog, movies: set watched
                          onTap: hasConfigScreen 
                              ? () => _navigateToConfigWithMarkAll(WatchStatus.watched)
                              : () => widget.onStatusChanged?.call(WatchStatus.watched),
                          onLongPress: () => _showDNFMenu(WatchStatus.watched),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  void _navigateToShowConfig() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShowConfigurationScreen(
          showId: widget.entry.tmdbId,
          showTitle: widget.entry.title,
        ),
      ),
    );
  }

  Future<void> _handleWantToWatchToggle(bool currentlyMarked) async {
    if (currentlyMarked) {
      // Show prompt for movies or entire shows
      final result = await showWantToWatchUnmarkPrompt(context, widget.entry.title);
      if (result == 'unmark') {
        // Just remove Want to watch status
        final logic = ref.read(watchlistLogicProvider);
        await logic.removeStatusFromWork(
          widget.entry.tmdbId,
          widget.entry.type,
          WatchStatus.wantToWatch,
        );
        ref.invalidate(watchlistEntriesProvider);
      } else if (result == 'hide') {
        // Remove Want to watch status, then hide
        final logic = ref.read(watchlistLogicProvider);
        await logic.removeStatusFromWork(
          widget.entry.tmdbId,
          widget.entry.type,
          WatchStatus.wantToWatch,
        );
        await logic.setSnoozed(widget.entry.tmdbId, widget.entry.type, true);
        ref.invalidate(watchlistEntriesProvider);
      } else if (result == 'delete') {
        widget.onDelete?.call();
      }
    } else {
      // Mark as want to watch
      widget.onStatusChanged?.call(WatchStatus.wantToWatch);
    }
  }

  void _showDNFMenu(WatchStatus otherStatus) {
    final entry = widget.entry;
    final hasDnf = entry.statusRecords.any((r) => r.status == WatchStatus.dnf);
    final isTvShow = entry.type == WorkType.tvShow;
    final isCollection = _isCollection;
    final hasConfigScreen = isTvShow || isCollection;
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  hasDnf ? Icons.cancel_outlined : Icons.cancel,
                  color: hasDnf ? null : StatusColors.getColor(WatchStatus.dnf),
                ),
                title: Text(hasDnf ? 'Unmark Did not finish' : 'Did not finish'),
                onTap: () {
                  Navigator.pop(context);
                  if (hasConfigScreen) {
                    // Navigate to config screen with mark all dialog
                    _navigateToConfigWithMarkAll(WatchStatus.dnf);
                  } else if (hasDnf) {
                    // Remove DNF status for movies
                    final logic = ref.read(watchlistLogicProvider);
                    logic.removeStatusFromWork(
                      entry.tmdbId,
                      entry.type,
                      WatchStatus.dnf,
                    );
                    ref.invalidate(watchlistEntriesProvider);
                  } else {
                    widget.onStatusChanged?.call(WatchStatus.dnf);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  otherStatus == WatchStatus.inProgress
                      ? Icons.play_circle
                      : Icons.check_circle,
                  color: StatusColors.getColor(otherStatus),
                ),
                title: Text(
                  otherStatus == WatchStatus.inProgress
                      ? 'In progress'
                      : 'Watched',
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (hasConfigScreen) {
                    _navigateToConfigWithMarkAll(otherStatus);
                  } else {
                    widget.onStatusChanged?.call(otherStatus);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReleasePreferencesDialog() async {
    if (widget.entry.type == WorkType.movie) {
      // Show movie release preferences dialog
      final result = await showDialog<ReleaseNotificationPreferences>(
        context: context,
        builder: (context) => ReleasePreferencesDialog(
          workTitle: widget.entry.title,
          initialPreferences: widget.entry.releaseNotificationPrefs ?? ReleaseNotificationPreferences(),
        ),
      );

      if (result != null) {
        // Update the entry with new preferences
        final watchlistLogic = ref.read(watchlistLogicProvider);
        await watchlistLogic.updateReleaseNotificationPreferences(
          widget.entry.tmdbId,
          widget.entry.type,
          result,
        );
        ref.invalidate(watchlistEntriesProvider);
        
        if (mounted) {
          showSimpleSnackBar(
            context,
            'Release preferences updated for ${widget.entry.title}',
            duration: const Duration(seconds: 2),
          );
        }
      }
    } else if (widget.entry.type == WorkType.tvShow) {
      // Show TV show episode preferences dialog
      final result = await showDialog<TvNotificationPreferences>(
        context: context,
        builder: (context) => TvPreferencesDialog(
          workTitle: widget.entry.title,
          initialPreferences: widget.entry.tvNotificationPrefs ?? TvNotificationPreferences(),
        ),
      );

      if (result != null) {
        // Update the entry with new preferences
        final watchlistLogic = ref.read(watchlistLogicProvider);
        await watchlistLogic.updateTvNotificationPreferences(
          widget.entry.tmdbId,
          result,
        );
        ref.invalidate(watchlistEntriesProvider);
        
        if (mounted) {
          showSimpleSnackBar(
            context,
            'Episode preferences updated for ${widget.entry.title}',
            duration: const Duration(seconds: 2),
          );
        }
      }
    }
  }

  String _formatReleaseDate(DateTime date) {
    final now = DateTime.now();
    final threeYearsAgo = now.subtract(const Duration(days: 365 * 3));
    
    if (date.isBefore(threeYearsAgo)) {
      return date.year.toString();
    }
    if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }
}

class _StatusButton extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final WatchStatus status;
  final bool isActive;
  final String tooltip;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _StatusButton({
    required this.icon,
    required this.activeIcon,
    required this.status,
    required this.isActive,
    required this.tooltip,
    this.label,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_StatusButton> createState() => _StatusButtonState();
}

class _StatusButtonState extends State<_StatusButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = StatusColors.getColor(widget.status, isDark: isDark);
    
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTapDown: (_) {
                setState(() => _isPressed = true);
                _animationController.forward();
              },
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _animationController.reverse();
                widget.onTap?.call();
              },
              onTapCancel: () {
                setState(() => _isPressed = false);
                _animationController.reverse();
              },
              onLongPress: widget.onLongPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? statusColor.withValues(alpha: 0.2)
                      : _isPressed
                          ? theme.colorScheme.surfaceContainerHighest
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.isActive ? widget.activeIcon : widget.icon,
                        key: ValueKey(widget.isActive),
                        size: 20,
                        color: widget.isActive
                            ? statusColor
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.label != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: widget.isActive
                                ? statusColor
                                : theme.colorScheme.onSurfaceVariant,
                          ) ?? const TextStyle(),
                          child: Text(widget.label!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
