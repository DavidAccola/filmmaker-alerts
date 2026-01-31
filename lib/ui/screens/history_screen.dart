import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/preferences.dart';
import '../../data/models/notification_history.dart';
import '../../data/models/contributor_detail.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';
import '../common/watchlist_button.dart';
import '../common/tmdb_attribution.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import 'tv_episode_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Map<int, bool> _posterHoverStates = {};

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);

    // Mark history as viewed when the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markHistoryAsViewed(ref);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
        actions: [
          // Clear All button (debug mode only)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear All History (Debug)',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All History'),
                    content: const Text('Are you sure you want to delete all notification history? This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  final historyRepo = ref.read(historyRepositoryProvider);
                  await historyRepo.clearAllHistory();
                  ref.invalidate(historyProvider);
                  if (context.mounted) {
                    showSimpleSnackBar(context, 'All notification history cleared');
                  }
                }
              },
            ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (history) {
          if (history.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications have been sent yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    'Movies and TV shows you have been notified about will appear here.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Identify the most recent batch (notifications from the last few minutes)
          DateTime? mostRecentNotificationTime;
          if (history.isNotEmpty) {
            final firstEntry = history.first.entry;
            if (firstEntry.notificationEvents.isNotEmpty) {
              try {
                mostRecentNotificationTime = DateTime.parse(firstEntry.notificationEvents.last.notifiedAt);
              } catch (e) {
                // If parsing fails, fall back to string comparison
                debugPrint('[HistoryScreen] Failed to parse notification time: $e');
              }
            }
          }

          // Check if user has viewed history since the most recent notification
          final prefsAsync = ref.watch(preferencesProvider);
          
          prefsAsync.whenData((prefs) {
            if (mostRecentNotificationTime != null) {
              final lastViewedTime = prefs.lastViewedHistoryTime;
              if (lastViewedTime == null) {
                // hasUnviewedBatch = true;
              } else {
                try {
                  DateTime.parse(lastViewedTime);
                  // hasUnviewedBatch = mostRecentNotificationTime.isAfter(lastViewed);
                } catch (e) {
                  // hasUnviewedBatch = true;
                }
              }
            }
          });

          return CustomScrollView(
            slivers: [
              // Check if we need to show a "New Notifications" section header
              // (removed - new items look normal, old items are de-emphasized)
              
              // Movie list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = history[index];
                    final entry = item.entry;

                    // Check if this is part of the most recent batch (within last 5 minutes)
                    bool isRecentBatch = false;
                    if (mostRecentNotificationTime != null && entry.notificationEvents.isNotEmpty) {
                      try {
                        final entryTime = DateTime.parse(entry.notificationEvents.last.notifiedAt);
                        final timeDifference = mostRecentNotificationTime.difference(entryTime).abs();
                        // Consider notifications within 5 minutes as part of the same batch
                        if (timeDifference.inMinutes <= 5) {
                          isRecentBatch = true;
                        }
                      } catch (e) {
                        // If parsing fails, fall back to string comparison for same day
                        final entryTimeStr = entry.notificationEvents.last.notifiedAt;
                        final mostRecentStr = mostRecentNotificationTime.toIso8601String();
                        if (entryTimeStr.startsWith(mostRecentStr.substring(0, 10))) {
                          isRecentBatch = true;
                        }
                      }
                    }

              // Group reasons by contributor name, collecting all their roles
              final reasonsByContributor = <String, List<String>>{};
              bool isWatchlistOnly = false;
              
              for (var reason in entry.reasons) {
                // Check if this is a watchlist entry
                if (reason.department == 'Watchlist' && reason.job == 'Watchlist Entry') {
                  isWatchlistOnly = true;
                  continue; // Skip adding to reasonsByContributor, we'll handle it separately
                }
                
                // Skip "Followed Show" entries (TV shows)
                if (reason.job == 'Followed Show') {
                  continue;
                }
                
                // Collect all jobs for this contributor
                if (reason.job != null) {
                  reasonsByContributor.putIfAbsent(reason.contributorName, () => []).add(reason.job!);
                }
              }
              
              String reasonsText = '';
              if (isWatchlistOnly) {
                reasonsText = 'On Watchlist';
              } else if (reasonsByContributor.isNotEmpty) {
                reasonsText = reasonsByContributor.entries.map((e) {
                  return '${e.key} - ${e.value.join(", ")}';
                }).join("\n");
              }

              // Format Events with proper release type labels and date formatting
              final eventsText = entry.notificationEvents.map((e) {
                final formattedDate = _formatDateForHistory(e.releaseDate);
                final releaseTypeLabel = _getReleaseTypeLabel(e.releaseType);
                return '$releaseTypeLabel: $formattedDate';
              }).join("\n");

              // TV-specific episode information widgets
              final episodeWidgets = <Widget>[];
              if (entry.mediaType == 'tv') {
                episodeWidgets.addAll(_getTvEpisodeWidgets(context, entry));
              }

              // Footer Date (Most recent notification) - format as MM/DD/YYYY
              final notifiedOn = entry.notificationEvents.isNotEmpty
                  ? _formatNotificationDate(entry.notificationEvents.last.notifiedAt)
                  : 'Unknown';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: !isRecentBatch 
                      ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.6)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigateToInternalDetail(context, entry, item.title),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Poster - 60px wide, fills card height and left edge
                          MouseRegion(
                            onEnter: (_) => setState(() => _posterHoverStates[entry.tmdbId] = true),
                            onExit: (_) => setState(() => _posterHoverStates[entry.tmdbId] = false),
                            child: SizedBox(
                              width: 60,
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(4),
                                      ),
                                      child: item.posterPath != null
                                          ? CachedNetworkImage(
                                              imageUrl: 'https://image.tmdb.org/t/p/w200${item.posterPath}',
                                              fit: BoxFit.fitWidth,
                                              width: 60,
                                              placeholder: (_, __) => const SizedBox(
                                                width: 60,
                                                height: 90,
                                              ),
                                              errorWidget: (_, __, ___) => const SizedBox(
                                                width: 60,
                                                height: 90,
                                                child: Icon(Icons.movie, color: Colors.grey),
                                              ),
                                            )
                                          : const SizedBox(
                                              width: 60,
                                              height: 90,
                                              child: Icon(Icons.movie, color: Colors.grey),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: WatchlistButton(
                                      tmdbId: entry.tmdbId,
                                      workType: entry.mediaType == 'tv' ? WorkType.tvShow : WorkType.movie,
                                      workTitle: item.title,
                                      posterPath: item.posterPath,
                                      releaseDate: entry.notificationEvents.isNotEmpty 
                                          ? DateTime.tryParse(entry.notificationEvents.first.releaseDate)
                                          : null,
                                      position: WatchlistButtonStyle.topRight,
                                      showOnHoverOnly: true,
                                      iconSize: 16,
                                      isHovered: _posterHoverStates[entry.tmdbId] ?? false,
                                      applyPositioning: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (episodeWidgets.isNotEmpty) ...[
                                    ...episodeWidgets,
                                    const SizedBox(height: 4),
                                  ],
                                  if (reasonsText.isNotEmpty) ...[
                                    Text(reasonsText, style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 8),
                                  ],
                                  if (entry.mediaType != 'tv') ...[
                                    Text(eventsText, style: Theme.of(context).textTheme.bodySmall),
                                    const SizedBox(height: 8),
                                  ],
                                  Text('Notified on $notifiedOn', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          if (kDebugMode)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Remove (Debug)',
                              onPressed: () async {
                                final historyRepo = ref.read(historyRepositoryProvider);
                                final success = await historyRepo.removeNotificationFromHistory(entry.tmdbId);
                                if (success) {
                                  ref.invalidate(historyProvider);
                                  if (context.mounted) {
                                    showRemovalSnackBar(
                                      context,
                                      message: 'Removed "${item.title}" from history',
                                      onUndo: () {
                                        historyRepo.addNotificationToHistory(entry);
                                        ref.invalidate(historyProvider);
                                      },
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: history.length,
          ),
        ),
        
        // TMDB Attribution - pushed to bottom
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [TmdbAttribution()],
          ),
        ),
      ],
    );
        },
      ),
    );
  }

  String _formatDateForHistory(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  String _getReleaseTypeLabel(String releaseType) {
    switch (releaseType.toLowerCase()) {
      case 'streaming':
      case 'digital':
        return 'Streaming';
      case 'theatrical':
        return 'In theatres';
      case 'theatrical (limited)':
      case 'premiere':
        return 'Theatrical premiere';
      case 'tv':
        return 'Airing';
      default:
        return releaseType;
    }
  }

  String _formatNotificationDate(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return dateTimeStr; // Return original if parsing fails
    }
  }

  /// Get TV episode widgets for display in history (returns multiple widgets for grouped episodes)
  List<Widget> _getTvEpisodeWidgets(BuildContext context, NotificationHistoryEntry entry) {
    if (entry.mediaType != 'tv') return [];
    
    // Initialize logger and log entry details
    // DebugLogger.instance.init();
    // DebugLogger.instance.logHistory('=== TV Episode Debug ===');
    // DebugLogger.instance.logHistory('tmdbId: ${entry.tmdbId}');
    // DebugLogger.instance.logHistory('mediaType: ${entry.mediaType}');
    // DebugLogger.instance.logHistory('tvNotificationType: ${entry.tvNotificationType}');
    // DebugLogger.instance.logHistory('seasonNumber: ${entry.seasonNumber}');
    // DebugLogger.instance.logHistory('episodeNumber: ${entry.episodeNumber}');
    // DebugLogger.instance.logHistory('episodeTitle: "${entry.episodeTitle}"');
    // DebugLogger.instance.logHistory('notificationEvents.length: ${entry.notificationEvents.length}');
    // for (int i = 0; i < entry.notificationEvents.length; i++) {
    //   final event = entry.notificationEvents[i];
    //   DebugLogger.instance.logHistory('event[$i]: releaseType="${event.releaseType}", releaseDate="${event.releaseDate}"');
    // }
    
    final List<Widget> episodeWidgets = [];
    
    // Handle grouped episodes differently
    final isGroupedByType = entry.tvNotificationType == 'grouped_episodes';
    final isGroupedByCount = entry.notificationEvents.length > 1;
    final isGroupedByTitle = entry.episodeTitle != null && entry.episodeTitle!.contains('episodes');
    
    // DebugLogger.instance.logHistory('isGroupedByType: $isGroupedByType');
    // DebugLogger.instance.logHistory('isGroupedByCount: $isGroupedByCount');
    // DebugLogger.instance.logHistory('isGroupedByTitle: $isGroupedByTitle');
    
    if ((isGroupedByType || isGroupedByCount || isGroupedByTitle) && 
        entry.notificationEvents.isNotEmpty) {
      // DebugLogger.instance.logHistory('Using GROUPED episode logic');
      
      // For grouped episodes, create one widget per episode
      if (entry.notificationEvents.length > 1) {
        // DebugLogger.instance.logHistory('Multiple events format (${entry.notificationEvents.length} events)');
        // New format: multiple notification events with individual episode data
        for (int i = 0; i < entry.notificationEvents.length; i++) {
          final event = entry.notificationEvents[i];
          // DebugLogger.instance.logHistory('Processing event $i: ${event.releaseType}');
          
          // Parse episode info from releaseType: "episode_type|season|episode|title"
          final releaseTypeParts = event.releaseType.split('|');
          if (releaseTypeParts.length >= 4) {
            // DebugLogger.instance.logHistory('Using pipe format parsing');
            final seasonNum = int.tryParse(releaseTypeParts[1]) ?? 1;
            final episodeNum = int.tryParse(releaseTypeParts[2]) ?? 1;
            final episodeTitle = releaseTypeParts[3];
            
            // DebugLogger.instance.logHistory('Parsed: S${seasonNum}E${episodeNum} - "$episodeTitle"');
            
            // Format the air date
            final formattedDate = _formatDateForHistory(event.releaseDate);
            
            // Create a widget for this episode with consistent styling
            episodeWidgets.add(
              Text(
                '"$episodeTitle" - S${seasonNum}E${episodeNum.toString().padLeft(2, '0')} - $formattedDate',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            );
          } else {
            // DebugLogger.instance.logHistory('Using underscore format parsing');
            // Fallback for old format or unparseable data
            final underscoreParts = event.releaseType.split('_');
            if (underscoreParts.length >= 4) {
              // DebugLogger.instance.logHistory('Underscore parts: $underscoreParts');
              
              // Handle different old formats:
              // Format 1: episode_37_14_Title
              // Format 2: season_finale_37_15_Title
              int seasonNum = 1;
              int episodeNum = 1;
              int titleStartIndex = 3;
              
              if (underscoreParts[0] == 'episode') {
                // Format: episode_37_14_Title
                seasonNum = int.tryParse(underscoreParts[1]) ?? 1;
                episodeNum = int.tryParse(underscoreParts[2]) ?? 1;
                titleStartIndex = 3;
                // DebugLogger.instance.logHistory('Format 1: episode_season_episode_title');
              } else if (underscoreParts.length >= 5 && 
                         (underscoreParts[0] == 'season' || underscoreParts[0] == 'series')) {
                // Format: season_finale_37_15_Title or series_premiere_1_1_Title
                seasonNum = int.tryParse(underscoreParts[2]) ?? 1;
                episodeNum = int.tryParse(underscoreParts[3]) ?? 1;
                titleStartIndex = 4;
                // DebugLogger.instance.logHistory('Format 2: season_type_season_episode_title');
              } else {
                // DebugLogger.instance.logHistory('Format 3: fallback numeric search');
                // Fallback: assume last two numeric parts are season/episode
                for (int j = 1; j < underscoreParts.length - 1; j++) {
                  final num1 = int.tryParse(underscoreParts[j]);
                  final num2 = int.tryParse(underscoreParts[j + 1]);
                  if (num1 != null && num2 != null) {
                    seasonNum = num1;
                    episodeNum = num2;
                    titleStartIndex = j + 2;
                    // DebugLogger.instance.logHistory('Found numbers at positions $j,${j+1}: $seasonNum,$episodeNum');
                    break;
                  }
                }
              }
              
              // Extract episode title
              String episodeTitle = 'Episode $episodeNum';
              if (underscoreParts.length > titleStartIndex) {
                episodeTitle = underscoreParts.sublist(titleStartIndex).join(' ');
              }
              
              // DebugLogger.instance.logHistory('Final parsed: S${seasonNum}E${episodeNum} - "$episodeTitle"');
              
              // Format the air date
              final formattedDate = _formatDateForHistory(event.releaseDate);
              
              // Create a widget for this episode
              episodeWidgets.add(
                Text(
                  '"$episodeTitle" - S${seasonNum}E${episodeNum.toString().padLeft(2, '0')} - $formattedDate',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              );
            } else {
              // DebugLogger.instance.logHistory('Could not parse event: ${event.releaseType}');
            }
          }
        }
      } else {
        // DebugLogger.instance.logHistory('Single event format, generating from episode count');
        // Old format: single notification event but multiple episodes
        // Generate episode widgets based on episode count
        final episodeCount = entry.episodeNumber ?? 1;
        final seasonNum = entry.seasonNumber ?? 1;
        final baseEpisodeNum = 1; // We don't know the starting episode number, so assume 1
        final airDate = entry.notificationEvents.first.releaseDate;
        final formattedDate = _formatDateForHistory(airDate);
        
        // DebugLogger.instance.logHistory('Generating $episodeCount episodes starting from S${seasonNum}E${baseEpisodeNum}');
        
        for (int i = 0; i < episodeCount; i++) {
          final episodeNum = baseEpisodeNum + i;
          final episodeTitle = 'Episode $episodeNum'; // Generic title since we don't have individual titles
          
          episodeWidgets.add(
            Text(
              '"$episodeTitle" - S${seasonNum}E${episodeNum.toString().padLeft(2, '0')} - $formattedDate',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          );
        }
      }
      
      // Add spacing between episode widgets
      final spacedWidgets = <Widget>[];
      for (int i = 0; i < episodeWidgets.length; i++) {
        spacedWidgets.add(episodeWidgets[i]);
        if (i < episodeWidgets.length - 1) {
          spacedWidgets.add(const SizedBox(height: 2)); // Small spacing between episodes
        }
      }
      
      // DebugLogger.instance.logHistory('Created ${spacedWidgets.length} widgets (${episodeWidgets.length} episodes + spacing)');
      return spacedWidgets;
    } else {
      // DebugLogger.instance.logHistory('Using SINGLE episode logic');
      // Single episode - create one widget
      final List<String> parts = [];
      
      if (entry.episodeTitle != null && 
          entry.episodeTitle!.isNotEmpty && 
          !entry.episodeTitle!.contains('episodes')) {
        parts.add('"${entry.episodeTitle}"');
        // DebugLogger.instance.logHistory('Added episode title: "${entry.episodeTitle}"');
      } else {
        // DebugLogger.instance.logHistory('No episode title (empty or contains "episodes")');
      }
      
      // Add episode format (S#E#)
      if (entry.seasonNumber != null && entry.episodeNumber != null) {
        parts.add('S${entry.seasonNumber}E${entry.episodeNumber.toString().padLeft(2, '0')}');
        // DebugLogger.instance.logHistory('Added S#E#: S${entry.seasonNumber}E${entry.episodeNumber}');
      }
      
      // Add the air date
      if (entry.notificationEvents.isNotEmpty) {
        final formattedDate = _formatDateForHistory(entry.notificationEvents.first.releaseDate);
        parts.add(formattedDate);
        // DebugLogger.instance.logHistory('Added date: $formattedDate');
      }
      
      final finalText = parts.join(' - ');
      // DebugLogger.instance.logHistory('Final single episode text: "$finalText"');
      
      if (parts.isNotEmpty) {
        return [
          Text(
            finalText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ];
      }
    }
    
    // DebugLogger.instance.logHistory('Returning empty widget list');
    return [];
  }

  void _markHistoryAsViewed(WidgetRef ref) async {
    try {
      final prefsRepo = ref.read(preferencesRepositoryProvider);
      final currentPrefs = prefsRepo.getPreferences();
      
      final updatedPrefs = Preferences(
        notifyTheatre: currentPrefs.notifyTheatre,
        notifyStreaming: currentPrefs.notifyStreaming,
        scheduleTime: currentPrefs.scheduleTime,
        defaultDepartments: currentPrefs.defaultDepartments,
        notifyPhysical: currentPrefs.notifyPhysical,
        notifyTV: currentPrefs.notifyTV,
        pretendToday: currentPrefs.pretendToday,
        includeCollectionsInMovieSearch: currentPrefs.includeCollectionsInMovieSearch,
        useGridView: currentPrefs.useGridView,
        homeSortOrder: currentPrefs.homeSortOrder,
        groupByType: currentPrefs.groupByType,
        allRolesSelected: currentPrefs.allRolesSelected,
        allReleaseTypesSelected: currentPrefs.allReleaseTypesSelected,
        autoFollowNewRoles: currentPrefs.autoFollowNewRoles,
        lastCheckTime: currentPrefs.lastCheckTime,
        lastViewedHistoryTime: DateTime.now().toIso8601String(),
        movieDetailsPreference: currentPrefs.movieDetailsPreference,
        defaultTvNotificationPrefs: currentPrefs.defaultTvNotificationPrefs,
        notifyPersonTvEpisodes: currentPrefs.notifyPersonTvEpisodes,
      );
      
      await prefsRepo.savePreferences(updatedPrefs);
    } catch (e) {
      debugPrint('[HistoryScreen] Failed to mark history as viewed: $e');
    }
  }

  Future<void> _navigateToInternalDetail(BuildContext context, NotificationHistoryEntry entry, String title) async {
    final mediaType = entry.mediaType;
    final isTV = mediaType == 'tv';

    if (isTV) {
      // Check if it's a specific episode or a show-level notification
      final isEpisode = entry.tvNotificationType == 'episode' || 
                        entry.tvNotificationType == 'season_finale' || 
                        entry.tvNotificationType == 'season_premiere' ||
                        entry.tvNotificationType == 'special';
      
      if (isEpisode && entry.seasonNumber != null && entry.episodeNumber != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TvEpisodeDetailScreen(
              showId: entry.tmdbId,
              seasonNumber: entry.seasonNumber!,
              episodeNumber: entry.episodeNumber!,
              showName: title,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TvShowDetailScreen(
              showId: entry.tmdbId,
              showTitle: title,
            ),
          ),
        );
      }
    } else {
      // Movie
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailScreen(
            movieId: entry.tmdbId,
            movieTitle: title,
          ),
        ),
      );
    }
  }
}