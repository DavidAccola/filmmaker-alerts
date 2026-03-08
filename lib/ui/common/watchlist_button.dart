import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/contributor.dart'; // For TvNotificationPreferences
import '../../data/models/watchlist_entry.dart';
import '../../data/models/status_record.dart';
import '../../providers/providers.dart';
import 'snackbar_utils.dart';
import '../screens/home_screen.dart';
import 'hover_action_button.dart';
import 'release_preferences_dialog.dart';
import 'tv_preferences_dialog.dart';

enum WatchlistButtonStyle {
  topRight,    // Top right corner (default)
  topLeft,     // Top left corner
  center,      // Centered (for TV credits)
  bottomRight, // Bottom right corner
}


class WatchlistButton extends ConsumerStatefulWidget {
  final int tmdbId;
  final WorkType workType;
  final String workTitle;
  final String? posterPath;
  final DateTime? releaseDate;
  final ReleaseType releaseType;
  final WatchlistButtonStyle position;
  final bool showOnHoverOnly;
  final double iconSize;
  final VoidCallback? onAdded;
  final bool? isHovered; // Optional: parent can pass hover state
  final VoidCallback? onUndo; // Callback for undo action
  final VoidCallback? onView; // Callback for view action (navigate to watchlist)
  final bool showViewButton; // Whether to show View button (true for non-search screens)
  final bool applyPositioning; // Whether to apply internal Positioned wrapper (false when parent handles positioning)

  const WatchlistButton({
    super.key,
    required this.tmdbId,
    required this.workType,
    required this.workTitle,
    this.posterPath,
    this.releaseDate,
    this.releaseType = ReleaseType.streaming,
    this.position = WatchlistButtonStyle.topRight,
    this.showOnHoverOnly = true,
    this.iconSize = 24,
    this.onAdded,
    this.isHovered,
    this.onUndo,
    this.onView,
    this.showViewButton = true,
    this.applyPositioning = true, // Default to true for backward compatibility
  });

  @override
  ConsumerState<WatchlistButton> createState() => _WatchlistButtonState();
}

class _WatchlistButtonState extends ConsumerState<WatchlistButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(watchlistEntriesProvider);

    return watchlistAsync.when(
      data: (entries) {
        final isInWatchlist = entries.any((e) =>
            e.tmdbId == widget.tmdbId && e.type == widget.workType);

        final shouldShow = widget.showOnHoverOnly ? (widget.isHovered ?? false) : true;
        
        final button = HoverActionButton(
          onPressed: _isLoading ? () {} : () => _handleWatchlistToggle(isInWatchlist),
          icon: isInWatchlist ? Icons.check_circle : Icons.add_circle,
          tooltip: isInWatchlist ? 'Remove from Watchlist' : 'Add to Watchlist',
          iconSize: widget.iconSize,
          isCardHovered: shouldShow,
        );

        return _positionButton(button);
      },
      loading: () => SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _positionButton(Widget button) {
    // If parent is handling positioning, just return the button
    if (!widget.applyPositioning) {
      return button;
    }
    
    // Otherwise apply internal positioning (for backward compatibility)
    switch (widget.position) {
      case WatchlistButtonStyle.topRight:
        return Positioned(
          top: 2,
          right: 2,
          child: button,
        );
      case WatchlistButtonStyle.topLeft:
        return Positioned(
          top: 2,
          left: 2,
          child: button,
        );
      case WatchlistButtonStyle.center:
        return Center(child: button);
      case WatchlistButtonStyle.bottomRight:
        return Positioned(
          bottom: 2,
          right: 2,
          child: button,
        );
    }
  }

  Future<void> _handleWatchlistToggle(bool isInWatchlist) async {
    setState(() => _isLoading = true);

    try {
      final watchlistLogic = ref.read(watchlistLogicProvider);

      if (isInWatchlist) {
        // Check if user has changed statuses from defaults
        final hasChangedStatuses = _hasNonDefaultStatuses(watchlistLogic);
        
        if (hasChangedStatuses) {
          // Show confirmation dialog
          final result = await _showRemoveConfirmationDialog();
          
          if (result == null || result == 'cancel') {
            // User cancelled - do nothing
            setState(() => _isLoading = false);
            return;
          }
          // result == 'delete' - continue with removal below
        }
        
        // Remove from watchlist
        await watchlistLogic.removeWorkFromWatchlist(
          widget.tmdbId,
          widget.workType,
        );

        if (mounted) {
          showSimpleSnackBar(
            context,
            '${widget.workTitle} removed from watchlist',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // Check if item is already in watchlist before adding
        final isAlreadyInWatchlist = await watchlistLogic.isWorkInWatchlist(widget.tmdbId, widget.workType);
        
        if (isAlreadyInWatchlist) {
          // Item is already in watchlist - show "already following" snackbar
          final existingEntry = watchlistLogic.getWork(widget.tmdbId, widget.workType);
          if (existingEntry != null && mounted) {
            if (widget.workType == WorkType.movie) {
              showAlreadyInWatchlistSnackBar(
                context,
                widget.workTitle,
                () async {
                  await watchlistLogic.removeWorkFromWatchlist(
                    widget.tmdbId,
                    widget.workType,
                  );
                  ref.invalidate(watchlistEntriesProvider);
                },
              );
            } else if (widget.workType == WorkType.tvShow) {
              showAlreadyInWatchlistSnackBar(
                context,
                widget.workTitle,
                () async {
                  await watchlistLogic.removeWorkFromWatchlist(
                    widget.tmdbId,
                    widget.workType,
                  );
                  ref.invalidate(watchlistEntriesProvider);
                },
              );
            }
          }
        } else {
          // Add to watchlist with default preferences
          final entry = await watchlistLogic.addWorkToWatchlist(
            tmdbId: widget.tmdbId,
            type: widget.workType,
            title: widget.workTitle,
            posterPath: widget.posterPath,
            releaseDate: widget.releaseDate,
            releaseType: widget.releaseType,
          );

          if (mounted) {
            // Determine if we should show the View button
            final shouldShowView = widget.showViewButton;
            
            if (widget.workType == WorkType.movie) {
              // Handle movie with release preferences
              final prefs = entry.releaseNotificationPrefs;
              final selectedTypes = prefs?.selectedTypes ?? [];
              
              showWatchlistWithPreferencesSnackBar(
                context,
                workTitle: widget.workTitle,
                selectedReleaseTypes: selectedTypes,
                onUndo: () async {
                  await watchlistLogic.removeWorkFromWatchlist(
                    widget.tmdbId,
                    widget.workType,
                  );
                  ref.invalidate(watchlistEntriesProvider);
                },
                onEditPreferences: () => _showReleasePreferencesDialog(entry),
                onView: shouldShowView ? (widget.onView ?? _defaultViewAction) : null,
              );
            } else if (widget.workType == WorkType.tvShow) {
              // Handle TV show with episode preferences
              final tvPrefs = entry.tvNotificationPrefs;
              final selectedTypes = tvPrefs?.selectedTypes ?? [];
              
              // Fetch show details and mark all episodes as "Want to Watch"
              try {
                final workLogic = ref.read(workLogicProvider);
                
                // Fetch show details (this will cache them)
                final showDetail = await workLogic.fetchAndCacheTvShowDetail(widget.tmdbId);
                
                if (showDetail != null) {
                  final allEpisodes = <Map<String, dynamic>>[];
                  
                  // Fetch all seasons and collect episodes
                  for (final season in showDetail.seasons) {
                    final seasonDetail = await workLogic.fetchAndCacheTvSeasonDetail(
                      showId: widget.tmdbId,
                      seasonNumber: season.seasonNumber,
                    );
                    
                    if (seasonDetail != null) {
                      for (final episode in seasonDetail.episodes) {
                        allEpisodes.add({
                          'seasonNumber': season.seasonNumber,
                          'episodeNumber': episode.episodeNumber,
                          'episodeTitle': episode.name,
                        });
                      }
                    }
                  }
                  
                  // Mark all episodes as "Want to Watch"
                  if (allEpisodes.isNotEmpty) {
                    await watchlistLogic.markMultipleEpisodes(
                      widget.tmdbId,
                      allEpisodes,
                      WatchStatus.wantToWatch,
                    );
                    ref.invalidate(episodeStatusRepositoryProvider);
                  }
                }
              } catch (e) {
                // Continue even if episode marking fails - the show is still added
              }
              
              if (!mounted) return;
              showTvWatchlistSnackBar(
                context,
                workTitle: widget.workTitle,
                selectedEpisodeTypes: selectedTypes,
                onUndo: () async {
                  await watchlistLogic.removeWorkFromWatchlist(
                    widget.tmdbId,
                    widget.workType,
                  );
                  ref.invalidate(watchlistEntriesProvider);
                },
                onEditPreferences: () => _showTvPreferencesDialog(entry),
                onView: shouldShowView ? (widget.onView ?? _defaultViewAction) : null,
              );
            }
          }
        }
      }

      ref.invalidate(watchlistEntriesProvider);
      widget.onAdded?.call();
    } catch (e) {
      if (mounted) {
        showSimpleSnackBar(
          context,
          'Failed to update watchlist: $e',
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _defaultViewAction() {
    // Default view action: navigate to watchlist tab and scroll to item
    ref.read(homeTabProvider.notifier).setTab(1);
    ref.read(watchlistScrollTargetProvider.notifier).setTarget(widget.tmdbId);
    
    // Clear scroll target after a delay
    Future.delayed(const Duration(seconds: 2), () {
      ref.read(watchlistScrollTargetProvider.notifier).clear();
    });
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  Future<void> _showReleasePreferencesDialog(WatchlistEntry entry) async {
    final result = await showDialog<ReleaseNotificationPreferences>(
      context: context,
      builder: (context) => ReleasePreferencesDialog(
        workTitle: entry.title,
        initialPreferences: entry.releaseNotificationPrefs ?? ReleaseNotificationPreferences(),
      ),
    );

    if (result != null) {
      // Update the entry with new preferences
      final watchlistLogic = ref.read(watchlistLogicProvider);
      await watchlistLogic.updateReleaseNotificationPreferences(entry.tmdbId, entry.type, result);
      ref.invalidate(watchlistEntriesProvider);
      
      if (mounted) {
        showSimpleSnackBar(
          context,
          'Release preferences updated for ${entry.title}',
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _showTvPreferencesDialog(WatchlistEntry entry) async {
    final result = await showDialog<TvPreferencesResult>(
      context: context,
      builder: (context) => TvPreferencesDialog(
        workTitle: entry.title,
        initialPreferences: entry.tvNotificationPrefs ?? TvNotificationPreferences(),
        initialNotificationsPaused: entry.notificationsSnoozed,
      ),
    );

    if (result != null) {
      // Update the entry with new preferences
      final watchlistLogic = ref.read(watchlistLogicProvider);
      await watchlistLogic.updateTvNotificationPreferences(entry.tmdbId, result.preferences);
      ref.invalidate(watchlistEntriesProvider);
      
      if (mounted) {
        showSimpleSnackBar(
          context,
          'Episode preferences updated for ${entry.title}',
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  /// Checks if the work has non-default statuses (i.e., user has made changes).
  /// Default is considered: no statuses, or only "Want to Watch" status.
  /// For TV shows, also checks if any episodes have statuses.
  bool _hasNonDefaultStatuses(dynamic watchlistLogic) {
    final entry = watchlistLogic.getWork(widget.tmdbId, widget.workType);
    if (entry == null) return false;
    
    // Check work-level statuses
    final statuses = entry.statusRecords as List<StatusRecord>;
    
    // If there are statuses other than "Want to Watch", it's non-default
    final hasNonWantToWatchStatus = statuses.any((r) => 
      r.status != WatchStatus.wantToWatch
    );
    if (hasNonWantToWatchStatus) return true;
    
    // For TV shows, check if any episodes have statuses
    if (widget.workType == WorkType.tvShow) {
      final episodeRepo = ref.read(episodeStatusRepositoryProvider);
      final episodes = episodeRepo.getEpisodesByShow(widget.tmdbId);
      
      // If any episode has any status, it's non-default
      if (episodes.any((e) => e.statusRecords.isNotEmpty)) {
        return true;
      }
    }
    
    return false;
  }

  /// Shows a confirmation dialog when removing a work with non-default statuses.
  Future<String?> _showRemoveConfirmationDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Watchlist?'),
        content: Text(
          'You have tracking data for "${widget.workTitle}". '
          'Are you sure you want to remove it from your watchlist?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('DELETE FROM WATCHLIST'),
          ),
        ],
      ),
    );
  }
}
