import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../logic/notification_logic.dart';
import '../../data/models/preferences.dart';

class SystemTrayService with TrayListener {
  static final SystemTrayService _instance = SystemTrayService._internal();
  
  bool _isInitialized = false;
  ProviderContainer? _container;
  Timer? _scheduledCheckTimer;

  factory SystemTrayService() {
    return _instance;
  }

  SystemTrayService._internal();

  // Set the provider container so we can access services
  void setContainer(ProviderContainer container) {
    _container = container;
    debugPrint('[SystemTray] Provider container set');
    
    // Start the scheduled check timer now that we have the container
    if (_isInitialized) {
      _startScheduledCheckTimer();
    }
  }

  Future<void> init() async {
    debugPrint('[SystemTray] init() called');
    if (_isInitialized) {
      debugPrint('[SystemTray] Already initialized, skipping');
      return;
    }
    
    if (!Platform.isWindows) {
      debugPrint('[SystemTray] Not Windows platform, skipping initialization');
      return;
    }

    try {
      debugPrint('[SystemTray] Initializing tray manager...');
      
      // Initialize tray manager
      debugPrint('[SystemTray] Setting tray icon...');
      // Try ICO file first (better for Windows tray icons)
      final iconPath = r'C:\Tools\Filmmaker Alerts\filmmaker_alerts_flutter\assets\images\icon.ico';
      debugPrint('[SystemTray] Using ICO icon path: $iconPath');
      
      try {
        await trayManager.setIcon(iconPath);
        debugPrint('[SystemTray] Tray icon set successfully');
      } catch (e) {
        debugPrint('[SystemTray] Error setting ICO icon: $e');
        // Fallback to PNG
        try {
          final pngPath = r'C:\Tools\Filmmaker Alerts\filmmaker_alerts_flutter\assets\images\app_icon.png';
          debugPrint('[SystemTray] Trying PNG fallback: $pngPath');
          await trayManager.setIcon(pngPath);
          debugPrint('[SystemTray] PNG tray icon set successfully');
        } catch (e2) {
          debugPrint('[SystemTray] Error setting PNG icon: $e2');
          debugPrint('[SystemTray] Continuing without icon...');
        }
      }
      debugPrint('[SystemTray] Setting tray tooltip...');
      await trayManager.setToolTip('Filmmaker Alerts');
      
      // Build context menu
      debugPrint('[SystemTray] Building context menu...');
      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Show Window',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'check_now',
            label: 'Check for New Releases',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit',
          ),
        ],
      );
      debugPrint('[SystemTray] Setting context menu...');
      await trayManager.setContextMenu(menu);
      
      // Register as listener
      debugPrint('[SystemTray] Adding tray listener...');
      trayManager.addListener(this);

      _isInitialized = true;
      debugPrint('[SystemTray] System tray initialized successfully');
      
      // Start the scheduled check timer
      _startScheduledCheckTimer();
      
      // Try to verify the tray is actually visible
      debugPrint('[SystemTray] Attempting to verify tray visibility...');
      try {
        // Force a context menu update to ensure tray is active
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('[SystemTray] Tray should now be visible in system tray area');
      } catch (e) {
        debugPrint('[SystemTray] Error during tray verification: $e');
      }
    } catch (e) {
      debugPrint('[SystemTray] Error initializing system tray: $e');
      debugPrint('[SystemTray] Stack trace: ${StackTrace.current}');
      // Don't fail the app if system tray fails - it's optional
    }
  }

  @override
  void onTrayIconMouseDown() {
    debugPrint('[SystemTray] Tray icon clicked');
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    debugPrint('[SystemTray] Tray icon right-clicked');
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('[SystemTray] Menu item clicked: ${menuItem.key}');
    switch (menuItem.key) {
      case 'show_window':
        debugPrint('[SystemTray] Show window menu item selected');
        showWindow();
        break;
      case 'check_now':
        debugPrint('[SystemTray] Check now menu item selected');
        _checkForNewReleases();
        break;
      case 'exit_app':
        debugPrint('[SystemTray] Exit app menu item selected');
        closeApp();
        break;
      default:
        debugPrint('[SystemTray] Unknown menu item: ${menuItem.key}');
    }
  }

  Future<void> minimizeToTray() async {
    debugPrint('[SystemTray] minimizeToTray() called');
    debugPrint('[SystemTray] _isInitialized: $_isInitialized');
    
    if (_isInitialized) {
      try {
        debugPrint('[SystemTray] Calling windowManager.hide()');
        await windowManager.hide();
        debugPrint('[SystemTray] Window hidden successfully');
        
        // Check if window is actually hidden
        bool isVisible = await windowManager.isVisible();
        debugPrint('[SystemTray] Window visible after hide: $isVisible');
        
        debugPrint('[SystemTray] Window minimized to tray');
        
        // Optional: Show a brief notification that the app is still running
        // This helps users understand the app didn't actually close
      } catch (e) {
        debugPrint('[SystemTray] Error minimizing to tray: $e');
        debugPrint('[SystemTray] Stack trace: ${StackTrace.current}');
      }
    } else {
      debugPrint('[SystemTray] Cannot minimize to tray - not initialized');
    }
  }

  Future<void> showWindow() async {
    debugPrint('[SystemTray] showWindow() called');
    debugPrint('[SystemTray] _isInitialized: $_isInitialized');
    
    if (_isInitialized) {
      try {
        debugPrint('[SystemTray] Calling windowManager.show()');
        await windowManager.show();
        debugPrint('[SystemTray] Calling windowManager.focus()');
        await windowManager.focus();
        debugPrint('[SystemTray] Window restored from tray');
      } catch (e) {
        debugPrint('[SystemTray] Error showing window: $e');
        debugPrint('[SystemTray] Stack trace: ${StackTrace.current}');
      }
    } else {
      debugPrint('[SystemTray] Cannot show window - not initialized');
    }
  }

  Future<void> closeApp() async {
    debugPrint('[SystemTray] closeApp() called');
    
    try {
      if (_isInitialized) {
        debugPrint('[SystemTray] Cleaning up tray manager');
        trayManager.removeListener(this);
        await trayManager.destroy();
      }
      
      debugPrint('[SystemTray] Disabling preventClose and triggering close');
      await windowManager.setPreventClose(false);
      
      // Attempt a graceful close
      await windowManager.close();
      debugPrint('[SystemTray] Graceful close command sent');
      
      // Fallback: If the app hasn't closed after a short delay (e.g. 2 seconds),
      // something might be hanging, so force it.
      Future.delayed(const Duration(seconds: 2), () {
        debugPrint('[SystemTray] Graceful close timeout reached, forcing exit');
        exit(0);
      });
      
    } catch (e) {
      debugPrint('[SystemTray] Error closing app: $e');
      debugPrint('[SystemTray] Force exiting application');
      exit(0);
    }
  }

  void dispose() {
    if (_isInitialized) {
      trayManager.removeListener(this);
      trayManager.destroy();
    }
    _scheduledCheckTimer?.cancel();
  }

  /// Start a timer that checks for new releases at the scheduled time
  void _startScheduledCheckTimer() {
    debugPrint('[SystemTray] Starting scheduled check timer...');
    
    // Cancel any existing timer
    _scheduledCheckTimer?.cancel();
    
    // Get the scheduled time from preferences
    try {
      if (_container == null) {
        debugPrint('[SystemTray] Container not available yet, will retry');
        return;
      }
      
      final prefsRepo = _container!.read(preferencesRepositoryProvider);
      final prefs = prefsRepo.getPreferences();
      
      // Parse scheduled time
      int scheduleHour = 9;
      int scheduleMinute = 0;
      try {
        final parts = prefs.scheduleTime.split(':');
        if (parts.length == 2) {
          scheduleHour = int.parse(parts[0]);
          scheduleMinute = int.parse(parts[1]);
        }
      } catch (_) {}
      
      debugPrint('[SystemTray] Scheduled check time: ${scheduleHour.toString().padLeft(2, '0')}:${scheduleMinute.toString().padLeft(2, '0')}');
      
      // Calculate time until next scheduled check
      final now = DateTime.now();
      var nextCheck = DateTime(now.year, now.month, now.day, scheduleHour, scheduleMinute);
      
      // Check if scheduled time has already passed today
      if (nextCheck.isBefore(now)) {
        debugPrint('[SystemTray] Scheduled time has already passed today, running check immediately');
        _checkForNewReleases();
        
        // Schedule for tomorrow
        nextCheck = nextCheck.add(const Duration(days: 1));
      }
      
      final timeUntilCheck = nextCheck.difference(now);
      debugPrint('[SystemTray] Next scheduled check in ${timeUntilCheck.inMinutes} minutes at $nextCheck');
      
      // Set a timer to run at the scheduled time
      _scheduledCheckTimer = Timer(timeUntilCheck, () {
        debugPrint('[SystemTray] Scheduled check time reached, running check...');
        _checkForNewReleases();
        
        // Reschedule for tomorrow
        _startScheduledCheckTimer();
      });
      
    } catch (e) {
      debugPrint('[SystemTray] Error starting scheduled check timer: $e');
    }
  }

  Future<void> _checkForNewReleases() async {
    debugPrint('[SystemTray] Starting manual release check...');
    
    if (_container == null) {
      debugPrint('[SystemTray] Error: Provider container not set, cannot check releases');
      return;
    }
    
    try {
      // Get the release checker from the provider container
      final releaseChecker = _container!.read(releaseCheckerProvider);
      final notificationService = _container!.read(notificationServiceProvider);
      final tvCacheRepo = _container!.read(tvCacheRepositoryProvider);
      final movieCacheRepo = _container!.read(movieCacheRepositoryProvider);
      final prefsRepo = _container!.read(preferencesRepositoryProvider);
      
      debugPrint('[SystemTray] Calling findNewReleases...');
      
      // Perform the release check (ignore debug date for scheduled checks)
      final newReleases = await releaseChecker.findNewReleases(ignoreDebugDate: true);
      
      debugPrint('[SystemTray] Release check completed. Found ${newReleases.length} new releases');
      
      // Update last check time (like the background service does)
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
        lastViewedHistoryTime: currentPrefs.lastViewedHistoryTime,
        movieDetailsPreference: currentPrefs.movieDetailsPreference,
        defaultTvNotificationPrefs: currentPrefs.defaultTvNotificationPrefs,
        notifyPersonTvEpisodes: currentPrefs.notifyPersonTvEpisodes,
      );
      await prefsRepo.savePreferences(updatedPrefs);
      debugPrint('[SystemTray] Updated lastCheckTime to ${updatedPrefs.lastCheckTime}');
      
      // Send notifications for new releases
      if (newReleases.isNotEmpty) {
        // Add to history (like the background service does)
        final historyRepo = _container!.read(historyRepositoryProvider);
        for (final release in newReleases) {
          await historyRepo.addNotificationToHistory(release);
        }
        debugPrint('[SystemTray] Added ${newReleases.length} releases to history');
        
        // Get titles from cache like the background service does
        final movieTitles = <String>[];
        
        for (final release in newReleases) {
          String? title;
          
          if (release.mediaType == 'tv') {
            // Get TV show title from TV cache
            final tvShow = tvCacheRepo.getShow(release.tmdbId);
            title = tvShow?.name;
          } else {
            // Get movie title from movie cache
            final movie = movieCacheRepo.getMovie(release.tmdbId);
            title = movie?.title;
          }
          
          if (title != null) {
            movieTitles.add(title);
          }
        }
        
        // Use the same notification formatting as the background service
        final notificationTitle = NotificationLogic.formatTitle(movieTitles, entries: newReleases);
        final notificationBody = NotificationLogic.formatBody(movieTitles, newReleases,
          getMoviePosterPath: (tmdbId) {
            final release = newReleases.firstWhere((r) => r.tmdbId == tmdbId, orElse: () => newReleases.first);
            if (release.mediaType == 'tv') {
              final tvShow = tvCacheRepo.getShow(tmdbId);
              return tvShow?.posterPath;
            } else {
              return movieCacheRepo.getMovie(tmdbId)?.posterPath;
            }
          });
        
        // Collect poster images
        List<String> imagePaths = [];
        for (int i = 0; i < newReleases.length && i < 4; i++) {
          final release = newReleases[i];
          String? posterPath;
          
          if (release.mediaType == 'tv') {
            final tvShow = tvCacheRepo.getShow(release.tmdbId);
            posterPath = tvShow?.posterPath;
          } else {
            final movie = movieCacheRepo.getMovie(release.tmdbId);
            posterPath = movie?.posterPath;
          }
          
          if (posterPath != null && posterPath.isNotEmpty) {
            imagePaths.add('https://image.tmdb.org/t/p/w200$posterPath');
          }
        }
        
        // Get priority-based release dates for 2-3 movie notifications
        List<String>? releaseDates;
        if (newReleases.length >= 2 && newReleases.length <= 3) {
          releaseDates = NotificationLogic.getPriorityReleaseDates(movieTitles, newReleases);
        }
        
        // Determine payload
        String payload;
        if (newReleases.length == 1) {
          final entry = newReleases.first;
          final isTV = entry.mediaType == 'tv' || entry.notificationEvents.any((e) => e.releaseType.toLowerCase() == 'tv');
          final typePath = isTV ? 'tv' : 'movie';
          payload = 'https://www.themoviedb.org/$typePath/${entry.tmdbId}';
        } else {
          payload = 'app://history';
        }
        
        await notificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: notificationTitle,
          body: notificationBody,
          payload: payload,
          imagePaths: imagePaths.isNotEmpty ? imagePaths : null,
          releaseDates: releaseDates,
          totalMovieCount: newReleases.length,
        );
        
        debugPrint('[SystemTray] Sent notification for ${newReleases.length} releases');
      } else {
        debugPrint('[SystemTray] No new releases found');
      }
      
    } catch (e) {
      debugPrint('[SystemTray] Error during release check: $e');
      debugPrint('[SystemTray] Stack trace: ${StackTrace.current}');
    }
  }

  bool get isInitialized => _isInitialized;
}
