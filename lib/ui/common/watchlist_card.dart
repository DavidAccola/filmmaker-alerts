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
                              widget.onStatusChanged?.call(WatchStatus.dnf);
                              break;
                          }
                        },
                        itemBuilder: (context) {
                          if (entry.isSnoozed) {
                            return [
                              const PopupMenuItem(
                                value: 'snooze',
                                child: Text('Unhide'),
                              ),
                              const PopupMenuItem(
                                value: 'dnf',
                                child: Text('Did not finish'),
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

                  // DNF indicator (when hidden)
                  if (entry.isSnoozed && entry.statusRecords.any((r) => r.status == WatchStatus.dnf))
                    Positioned(
                      top: 8,
                      left: entry.notificationsSnoozed ? 40 : 8,
                      child: Tooltip(
                        message: 'Did not finish',
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
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
                        entry.type == WorkType.movie ? Icons.movie : Icons.tv,
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
                  // Get episode counts for TV shows
                  final episodeCounts = entry.type == WorkType.tvShow 
                      ? _getEpisodeStatusCounts() 
                      : <WatchStatus, int>{};
                  final wantToWatchCount = episodeCounts[WatchStatus.wantToWatch] ?? 0;
                  final inProgressCount = episodeCounts[WatchStatus.inProgress] ?? 0;
                  final watchedCount = episodeCounts[WatchStatus.watched] ?? 0;
                  
                  // For TV shows, icons are active if ANY episodes have that status
                  // For movies, use the work-level status
                  final isTvShow = entry.type == WorkType.tvShow;
                  final showWantToWatch = isTvShow ? wantToWatchCount > 0 : hasWantToWatch;
                  final showInProgress = isTvShow ? inProgressCount > 0 : hasInProgress;
                  final showWatched = isTvShow ? watchedCount > 0 : hasWatched;
                  
                  // Format count for display - abbreviate large numbers
                  String? formatCount(int count) {
                    if (count == 0) return null;
                    if (count > 99) return '99+';
                    return '$count';
                  }
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Want to watch button
                      Expanded(
                        child: _StatusButton(
                          icon: Icons.bookmark_border,
                          activeIcon: Icons.bookmark,
                          isActive: showWantToWatch,
                          tooltip: isTvShow && wantToWatchCount > 0 
                              ? 'Want to watch ($wantToWatchCount episodes)' 
                              : 'Want to watch',
                          label: formatCount(wantToWatchCount),
                          // TV shows: navigate to config screen, movies: toggle want to watch
                          onTap: isTvShow ? () => _navigateToShowConfig() : () => _handleWantToWatchToggle(hasWantToWatch),
                        ),
                      ),

                      // In progress button
                      Expanded(
                        child: _StatusButton(
                          icon: Icons.play_circle_outline,
                          activeIcon: Icons.play_circle,
                          isActive: showInProgress,
                          tooltip: isTvShow && inProgressCount > 0 
                              ? 'In progress ($inProgressCount episodes)' 
                              : 'In progress',
                          label: formatCount(inProgressCount),
                          // TV shows: navigate to config screen, movies: set in progress
                          onTap: isTvShow ? () => _navigateToShowConfig() : () => widget.onStatusChanged?.call(WatchStatus.inProgress),
                          onLongPress: isTvShow ? null : () => _showDNFMenu(WatchStatus.inProgress),
                        ),
                      ),

                      // Watched button
                      Expanded(
                        child: _StatusButton(
                          icon: Icons.check_circle_outline,
                          activeIcon: Icons.check_circle,
                          isActive: showWatched,
                          tooltip: isTvShow && watchedCount > 0
                              ? 'Watched ($watchedCount episodes)'
                              : watchCount > 1 
                                  ? 'Watched x$watchCount' 
                                  : 'Watched',
                          label: isTvShow 
                              ? formatCount(watchedCount)
                              : watchCount > 1 
                                  ? 'x$watchCount' 
                                  : null,
                          // TV shows: navigate to config screen, movies: set watched
                          onTap: isTvShow ? () => _navigateToShowConfig() : () => widget.onStatusChanged?.call(WatchStatus.watched),
                          onLongPress: isTvShow ? null : () => _showDNFMenu(WatchStatus.watched),
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Did not finish'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onStatusChanged?.call(WatchStatus.dnf);
                },
              ),
              ListTile(
                leading: Icon(
                  otherStatus == WatchStatus.inProgress
                      ? Icons.play_circle
                      : Icons.check_circle,
                ),
                title: Text(
                  otherStatus == WatchStatus.inProgress
                      ? 'In progress'
                      : 'Watched',
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onStatusChanged?.call(otherStatus);
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
  final bool isActive;
  final String tooltip;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _StatusButton({
    required this.icon,
    required this.activeIcon,
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
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
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
                            ? theme.colorScheme.primary
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
                                ? theme.colorScheme.primary
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
