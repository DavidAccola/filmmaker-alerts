import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/preferences.dart';
import '../../data/models/notification_history.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';
import '../common/tmdb_attribution.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All notification history cleared')),
                    );
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
                    'Movies you have been notified about will appear here.',
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
          bool hasUnviewedBatch = false;
          
          prefsAsync.whenData((prefs) {
            if (mostRecentNotificationTime != null) {
              final lastViewedTime = prefs.lastViewedHistoryTime;
              if (lastViewedTime == null) {
                hasUnviewedBatch = true;
              } else {
                try {
                  final lastViewed = DateTime.parse(lastViewedTime);
                  hasUnviewedBatch = mostRecentNotificationTime!.isAfter(lastViewed);
                } catch (e) {
                  hasUnviewedBatch = true;
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

              // Group reasons by contributor name - only show for people contributors
              final reasonsMap = <String, List<String>>{};
              for (var reason in entry.reasons) {
                // Only include person contributors (those with typical film roles)
                if (reason.job != null && 
                    ['Director', 'Writer', 'Producer', 'Actor', 'Actress', 'Creator', 'Editor', 'Cinematographer'].contains(reason.job)) {
                  reasonsMap.putIfAbsent(reason.contributorName, () => []).add(reason.job!);
                }
              }
              
              String reasonsText = '';
              if (reasonsMap.isNotEmpty) {
                reasonsText = reasonsMap.entries.map((e) {
                  return '${e.key} - ${e.value.join(", ")}';
                }).join("\n");
              }

              // Format Events with proper release type labels and date formatting
              final eventsText = entry.notificationEvents.map((e) {
                final formattedDate = _formatDateForHistory(e.releaseDate);
                final releaseTypeLabel = _getReleaseTypeLabel(e.releaseType);
                return '$releaseTypeLabel: $formattedDate';
              }).join("\n");

              // Footer Date (Most recent notification) - format as MM/DD/YYYY
              final notifiedOn = entry.notificationEvents.isNotEmpty
                  ? _formatNotificationDate(entry.notificationEvents.last.notifiedAt)
                  : 'Unknown';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: !isRecentBatch 
                    ? Theme.of(context).colorScheme.surface.withOpacity(0.6) // De-emphasized older items
                    : null, // New items look normal
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      Consumer(
                        builder: (context, ref, child) {
                          final prefsAsync = ref.watch(preferencesProvider);
                          return prefsAsync.when(
                            data: (prefs) {
                              final movieDetailsPreference = prefs.movieDetailsPreference ?? 'both';
                              final movieCacheRepo = ref.read(movieCacheRepositoryProvider);
                              final movie = movieCacheRepo.getMovie(entry.tmdbId);
                              final hasImdbId = movie?.imdbId != null && movie!.imdbId!.isNotEmpty;
                              
                              // Determine primary provider (poster/title click)
                              String primaryProvider;
                              String primaryTooltip;
                              VoidCallback primaryAction;
                              
                              if (movieDetailsPreference == 'imdb' && hasImdbId) {
                                primaryProvider = 'imdb';
                                primaryTooltip = 'View on IMDb';
                                primaryAction = () => _launchImdbUrl(context, movie!.imdbId!);
                              } else {
                                primaryProvider = 'tmdb';
                                primaryTooltip = 'View on TMDB';
                                primaryAction = () => _launchTmdbUrl(context, entry);
                              }
                              
                              return Tooltip(
                                message: primaryTooltip,
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: primaryAction,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: SizedBox(
                                        width: 60,
                                        height: 90,
                                        child: item.posterPath != null
                                            ? CachedNetworkImage(
                                                imageUrl: 'https://image.tmdb.org/t/p/w200${item.posterPath}',
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => const Icon(Icons.movie),
                                              )
                                            : Container(color: Colors.grey, child: const Icon(Icons.movie)),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            loading: () => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 60,
                                height: 90,
                                child: item.posterPath != null
                                    ? CachedNetworkImage(
                                        imageUrl: 'https://image.tmdb.org/t/p/w200${item.posterPath}',
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(Icons.movie),
                                      )
                                    : Container(color: Colors.grey, child: const Icon(Icons.movie)),
                              ),
                            ),
                            error: (_, __) => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 60,
                                height: 90,
                                child: item.posterPath != null
                                    ? CachedNetworkImage(
                                        imageUrl: 'https://image.tmdb.org/t/p/w200${item.posterPath}',
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(Icons.movie),
                                      )
                                    : Container(color: Colors.grey, child: const Icon(Icons.movie)),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, child) {
                                      final prefsAsync = ref.watch(preferencesProvider);
                                      return prefsAsync.when(
                                        data: (prefs) {
                                          final movieDetailsPreference = prefs.movieDetailsPreference ?? 'both';
                                          final movieCacheRepo = ref.read(movieCacheRepositoryProvider);
                                          final movie = movieCacheRepo.getMovie(entry.tmdbId);
                                          final hasImdbId = movie?.imdbId != null && movie!.imdbId!.isNotEmpty;
                                          
                                          // Determine primary provider (poster/title click)
                                          String primaryTooltip;
                                          VoidCallback primaryAction;
                                          
                                          if (movieDetailsPreference == 'imdb' && hasImdbId) {
                                            primaryTooltip = 'View on IMDb';
                                            primaryAction = () => _launchImdbUrl(context, movie!.imdbId!);
                                          } else {
                                            primaryTooltip = 'View on TMDB';
                                            primaryAction = () => _launchTmdbUrl(context, entry);
                                          }
                                          
                                          return Tooltip(
                                            message: primaryTooltip,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: primaryAction,
                                                child: Text(
                                                  item.title, 
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        loading: () => Text(
                                          item.title, 
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                                        ),
                                        error: (_, __) => Text(
                                          item.title, 
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (reasonsText.isNotEmpty) ...[
                              Text(reasonsText, style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 8),
                            ],
                            Text(eventsText, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Text('Notified on $notifiedOn', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      ),
                      // Action buttons
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Get preferences to determine which buttons to show
                          Consumer(
                            builder: (context, ref, child) {
                              final prefsAsync = ref.watch(preferencesProvider);
                              return prefsAsync.when(
                                data: (prefs) {
                                  final movieDetailsPreference = prefs.movieDetailsPreference ?? 'both';
                                  final movieCacheRepo = ref.read(movieCacheRepositoryProvider);
                                  final movie = movieCacheRepo.getMovie(entry.tmdbId);
                                  final hasImdbId = movie?.imdbId != null && movie!.imdbId!.isNotEmpty;
                                  
                                  // Only show button in "both" mode for Provider B (IMDb)
                                  final showImdbButton = movieDetailsPreference == 'both' && hasImdbId;
                                  
                                  return Column(
                                    children: [
                                      // View on IMDb button (Provider B in "both" mode)
                                      if (showImdbButton)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          child: Tooltip(
                                            message: 'View on IMDb',
                                            child: Material(
                                              color: Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(4),
                                                onTap: () => _launchImdbUrl(context, movie!.imdbId!),
                                                child: Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: Colors.white, width: 1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(3),
                                                    child: Image.asset(
                                                      'assets/images/imdb_square_black.png',
                                                      width: 36,
                                                      height: 36,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => Container(
                                                        width: 36,
                                                        height: 36,
                                                        color: const Color(0xFFF5C518),
                                                        child: const Center(
                                                          child: Text(
                                                            'I',
                                                            style: TextStyle(
                                                              color: Colors.black,
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Delete button (debug mode only)
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
                                                    // Re-add the entry
                                                    historyRepo.addNotificationToHistory(entry);
                                                    ref.invalidate(historyProvider);
                                                  },
                                                );
                                              }
                                            }
                                          },
                                        ),
                                    ],
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: history.length,
          ),
        ),
        
        // TMDB Attribution
        const SliverToBoxAdapter(
          child: TmdbAttribution(),
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

  void _markHistoryAsViewed(WidgetRef ref) async {
    try {
      final prefsRepo = ref.read(preferencesRepositoryProvider);
      final currentPrefs = await prefsRepo.getPreferences();
      
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
      );
      
      await prefsRepo.savePreferences(updatedPrefs);
    } catch (e) {
      debugPrint('[HistoryScreen] Failed to mark history as viewed: $e');
    }
  }

  Future<void> _launchTmdbUrl(BuildContext context, NotificationHistoryEntry entry) async {
    final tmdbId = entry.tmdbId;
    // Determine if it's a TV show or movie based on release events
    final isTV = entry.notificationEvents.any((e) => e.releaseType.toLowerCase() == 'tv');
    final typePath = isTV ? 'tv' : 'movie';
    final url = 'https://www.themoviedb.org/$typePath/$tmdbId';
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open TMDB page')),
        );
      }
    }
  }

  Future<void> _launchImdbUrl(BuildContext context, String imdbId) async {
    if (imdbId.isNotEmpty) {
      final url = 'https://www.imdb.com/title/$imdbId/';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open IMDb page')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IMDb ID not available for this movie')),
        );
      }
    }
  }
}