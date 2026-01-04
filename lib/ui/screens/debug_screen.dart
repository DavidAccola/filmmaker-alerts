import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../providers/providers.dart';
import '../../logic/notification_logic.dart';
import '../../data/models/preferences.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationService = ref.read(notificationServiceProvider);
    final preferencesAsync = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Notification Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Windows Notification Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Platform: ${Platform.operatingSystem}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Is Windows: ${Platform.isWindows}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            
            // Pretend Today Date Picker
            preferencesAsync.when(
              data: (prefs) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Testing Date Override',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Pretend Today Is'),
                        subtitle: Text(prefs.pretendToday ?? 'Today (${DateTime.now().toIso8601String().split('T').first})'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: prefs.pretendToday != null 
                                ? DateTime.parse(prefs.pretendToday!) 
                                : DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            final dateStr = picked.toIso8601String().split('T').first;
                            await _updatePrefs(ref, prefs, pretendToday: dateStr);
                          }
                        },
                        onLongPress: () async {
                          await _updatePrefs(ref, prefs, pretendToday: null);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cleared pretend date - using real date')),
                            );
                          }
                        },
                      ),
                      const Text(
                        'Tap to set date, long press to clear',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (prefs.lastCheckTime != null && prefs.lastCheckTime!.isNotEmpty)
                        Text(
                          'Last check: ${prefs.lastCheckTime}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading preferences: $error'),
            ),
            
            const SizedBox(height: 20),
            const Text(
              'Click the buttons below to test notifications.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  debugPrint('Attempting to send test notification...');
                  await notificationService.showTestNotification();
                  debugPrint('Test notification sent successfully');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test notification sent! Check your system notifications.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e, stackTrace) {
                  debugPrint('Error sending notification: $e');
                  debugPrint('Stack trace: $stackTrace');
                  if (context.mounted) {
                    String message = 'Error sending notification: $e';
                    Color color = Colors.red;
                    
                    if (e is UnsupportedError && e.message?.contains('Windows') == true) {
                      message = 'Windows notifications are not supported by Flutter plugins yet';
                      color = Colors.orange;
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: color,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.notifications),
              label: const Text('Send Test Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  debugPrint('Testing direct notification service initialization...');
                  await notificationService.init();
                  debugPrint('Notification service initialized successfully');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification service initialized successfully!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                } catch (e, stackTrace) {
                  debugPrint('Error initializing notification service: $e');
                  debugPrint('Stack trace: $stackTrace');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error initializing: $e'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.settings),
              label: const Text('Test Initialization Only'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  debugPrint('Triggering real notification check...');
                  
                  // Get the release checker
                  final releaseChecker = ref.read(releaseCheckerProvider);
                  final notificationService = ref.read(notificationServiceProvider);
                  final movieCacheRepo = ref.read(movieCacheRepositoryProvider);
                  final historyRepo = ref.read(historyRepositoryProvider);
                  
                  // Run the actual release check
                  final newReleases = await releaseChecker.findNewReleases();
                  
                  // Update last check time (like the real background service does)
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
                    lastCheckTime: DateTime.now().toIso8601String(),
                  );
                  await prefsRepo.savePreferences(updatedPrefs);
                  ref.invalidate(preferencesProvider);
                  
                  if (newReleases.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No new releases found. Try adding some contributors first!'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                  
                  debugPrint('Found ${newReleases.length} new releases');
                  
                  // Add to history (like the real background service does)
                  for (final release in newReleases) {
                    await historyRepo.addNotificationToHistory(release);
                  }
                  
                  // Refresh the history provider to ensure UI updates
                  ref.invalidate(historyProvider);
                  
                  // Get movie titles for notification
                  final movieTitles = <String>[];
                  for (final release in newReleases) {
                    final movie = movieCacheRepo.getMovie(release.tmdbId);
                    if (movie != null) {
                      movieTitles.add(movie.title);
                    }
                  }
                  
                  if (movieTitles.isNotEmpty) {
                    // Format notification using real logic
                    final title = NotificationLogic.formatTitle(movieTitles);
                    final body = NotificationLogic.formatBody(movieTitles, newReleases,
                      getMoviePosterPath: (tmdbId) => movieCacheRepo.getMovie(tmdbId)?.posterPath);
                    
                    // Always use history payload for debug notifications
                    String payload = 'app://history';
                    
                    // Image Logic: Collect up to 4 poster images from the releases
                    List<String> imagePaths = [];
                    for (int i = 0; i < newReleases.length && i < 4; i++) {
                      final movie = movieCacheRepo.getMovie(newReleases[i].tmdbId);
                      if (movie?.posterPath != null && movie!.posterPath!.isNotEmpty) {
                        // Convert TMDB poster path to full URL
                        imagePaths.add('https://image.tmdb.org/t/p/w200${movie.posterPath}');
                      }
                    }
                    
                    // Get priority-based release dates for 2-3 movie notifications
                    List<String>? releaseDates;
                    if (newReleases.length >= 2 && newReleases.length <= 3) {
                      releaseDates = NotificationLogic.getPriorityReleaseDates(movieTitles, newReleases);
                    }
                    
                    // Send the real notification
                    await notificationService.showNotification(
                      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      title: title,
                      body: body,
                      payload: payload,
                      imagePaths: imagePaths.isNotEmpty ? imagePaths : null,
                      releaseDates: releaseDates,
                      totalMovieCount: newReleases.length,
                    );
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Real notification sent! Found ${newReleases.length} new release(s)'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e, stackTrace) {
                  debugPrint('Error triggering real notification: $e');
                  debugPrint('Stack trace: $stackTrace');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.movie),
              label: const Text('Trigger Real Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final historyRepo = ref.read(historyRepositoryProvider);
                  await historyRepo.clearAllHistory();
                  ref.invalidate(historyProvider);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification history cleared! You can now re-test notifications.'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error clearing history: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error clearing history: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Notification History'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Testing Windows notifications using the windows_notification package. '
              'The "Trigger Real Notification" button runs the actual release checker and sends '
              'properly formatted notifications like the background service would.\n\n'
              'Release checking logic:\n'
              '• Debug mode (future pretend date): checks from real today to pretend date\n'
              '• Normal mode: checks from last check time to now (or 7 days if first time)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePrefs(WidgetRef ref, Preferences current, {
    String? pretendToday,
  }) async {
    final newPrefs = Preferences(
      notifyTheatre: current.notifyTheatre,
      notifyStreaming: current.notifyStreaming,
      scheduleTime: current.scheduleTime,
      defaultDepartments: current.defaultDepartments,
      notifyPhysical: current.notifyPhysical,
      notifyTV: current.notifyTV,
      pretendToday: pretendToday ?? current.pretendToday,
      includeCollectionsInMovieSearch: current.includeCollectionsInMovieSearch,
      useGridView: current.useGridView,
      homeSortOrder: current.homeSortOrder,
      groupByType: current.groupByType,
      allRolesSelected: current.allRolesSelected,
      allReleaseTypesSelected: current.allReleaseTypesSelected,
      autoFollowNewRoles: current.autoFollowNewRoles,
      lastCheckTime: current.lastCheckTime,
    );

    await ref.read(preferencesRepositoryProvider).savePreferences(newPrefs);
    ref.invalidate(preferencesProvider);
  }
}