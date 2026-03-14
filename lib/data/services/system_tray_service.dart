import 'dart:io';
import 'dart:async';
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
    
    // Start the scheduled check timer now that we have the container
    if (_isInitialized) {
      _startScheduledCheckTimer();
    }
  }

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    
    if (!Platform.isWindows) {
      return;
    }

    try {
      // Initialize tray manager
      // Try ICO file first (better for Windows tray icons)
      final iconPath = r'C:\Tools\Filmmaker Alerts\filmmaker_alerts_flutter\assets\images\icon.ico';
      
      try {
        await trayManager.setIcon(iconPath);
      } catch (e) {
        // Fallback to PNG
        try {
          final pngPath = r'C:\Tools\Filmmaker Alerts\filmmaker_alerts_flutter\assets\images\app_icon.png';
          await trayManager.setIcon(pngPath);
        } catch (e2) {
          // Continuing without icon
        }
      }
      await trayManager.setToolTip('Filmmaker Alerts');
      
      // Build context menu
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
      await trayManager.setContextMenu(menu);
      
      // Register as listener
      trayManager.addListener(this);

      _isInitialized = true;
      
      // Start the scheduled check timer
      _startScheduledCheckTimer();
      
      // Try to verify the tray is actually visible
      try {
        // Force a context menu update to ensure tray is active
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
      }
    } catch (e) {
      // Don't fail the app if system tray fails - it's optional
    }
  }

  @override
  void onTrayIconMouseDown() {
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        showWindow();
        break;
      case 'check_now':
        _checkForNewReleases();
        break;
      case 'exit_app':
        closeApp();
        break;
    }
  }

  Future<void> minimizeToTray() async {
    if (_isInitialized) {
      try {
        await windowManager.hide();
      } catch (e) {
      }
    }
  }

  Future<void> showWindow() async {
    if (_isInitialized) {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (e) {
      }
    }
  }

  Future<void> closeApp() async {
    try {
      if (_isInitialized) {
        trayManager.removeListener(this);
        await trayManager.destroy();
      }
      
      await windowManager.setPreventClose(false);
      
      // Attempt a graceful close
      await windowManager.close();
      
      // Fallback: If the app hasn't closed after a short delay (e.g. 2 seconds),
      // something might be hanging, so force it.
      Future.delayed(const Duration(seconds: 2), () {
        exit(0);
      });
      
    } catch (e) {
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
    // Cancel any existing timer
    _scheduledCheckTimer?.cancel();
    
    // Get the scheduled time from preferences
    try {
      if (_container == null) {
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
      
      // Calculate time until next scheduled check
      final now = DateTime.now();
      var nextCheck = DateTime(now.year, now.month, now.day, scheduleHour, scheduleMinute);
      
      // Check if scheduled time has already passed today
      if (nextCheck.isBefore(now)) {
        // Only run catch-up check if we haven't already checked after today's scheduled time
        bool shouldCatchUp = true;
        if (prefs.lastCheckTime != null && prefs.lastCheckTime!.isNotEmpty) {
          try {
            final lastCheck = DateTime.parse(prefs.lastCheckTime!);
            if (lastCheck.isAfter(nextCheck)) {
              // Already ran after today's scheduled time, skip catch-up
              shouldCatchUp = false;
            }
          } catch (_) {}
        }
        
        if (shouldCatchUp) {
          _checkForNewReleases();
        }
        
        // Schedule for tomorrow
        nextCheck = nextCheck.add(const Duration(days: 1));
      }
      
      final timeUntilCheck = nextCheck.difference(now);
      
      // Set a timer to run at the scheduled time
      _scheduledCheckTimer = Timer(timeUntilCheck, () {
        _checkForNewReleases();
        
        // Reschedule for tomorrow
        _startScheduledCheckTimer();
      });
      
    } catch (e) {
    }
  }

  Future<void> _checkForNewReleases() async {
    if (_container == null) {
      return;
    }
    
    try {
      // Get the release checker from the provider container
      final releaseChecker = _container!.read(releaseCheckerProvider);
      final notificationService = _container!.read(notificationServiceProvider);
      final tvCacheRepo = _container!.read(tvCacheRepositoryProvider);
      final movieCacheRepo = _container!.read(movieCacheRepositoryProvider);
      final prefsRepo = _container!.read(preferencesRepositoryProvider);
      
      // Perform the release check (ignore debug date for scheduled checks)
      final newReleases = await releaseChecker.findNewReleases(ignoreDebugDate: true);
      
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
      
      // Send notifications for new releases
      if (newReleases.isNotEmpty) {
        // Add to history (like the background service does)
        final historyRepo = _container!.read(historyRepositoryProvider);
        for (final release in newReleases) {
          await historyRepo.addNotificationToHistory(release);
        }
        
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
        
      } else {
      }
      
    } catch (e) {
    }
  }

  bool get isInitialized => _isInitialized;
}
