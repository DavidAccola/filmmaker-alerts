import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class SystemTrayService with TrayListener {
  static final SystemTrayService _instance = SystemTrayService._internal();
  
  bool _isInitialized = false;
  ProviderContainer? _container;

  factory SystemTrayService() {
    return _instance;
  }

  SystemTrayService._internal();

  // Set the provider container so we can access services
  void setContainer(ProviderContainer container) {
    _container = container;
    debugPrint('[SystemTray] Provider container set');
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
      
      debugPrint('[SystemTray] Calling findNewReleases...');
      
      // Perform the release check
      final newReleases = await releaseChecker.findNewReleases();
      
      debugPrint('[SystemTray] Release check completed. Found ${newReleases.length} new releases');
      
      // Send notifications for new releases
      if (newReleases.isNotEmpty) {
        // Get titles from cache like the background service does
        final movieTitles = <String>[];
        final tvCacheRepo = _container!.read(tvCacheRepositoryProvider);
        final movieCacheRepo = _container!.read(movieCacheRepositoryProvider);
        
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
        
        // Create a summary notification
        final title = newReleases.length == 1 
            ? 'New Release Found!' 
            : '${newReleases.length} New Releases Found!';
            
        final body = movieTitles.isNotEmpty
            ? (movieTitles.length == 1 ? movieTitles.first : '${movieTitles.length} new releases')
            : 'Check the app for details';
            
        await notificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          payload: 'app://history',
          totalMovieCount: newReleases.length,
        );
        
        debugPrint('[SystemTray] Sent notification for ${newReleases.length} releases');
      } else {
        debugPrint('[SystemTray] No new releases found');
        
        // Optional: Show a "no new releases" notification
        // You could uncomment this if you want feedback when no releases are found
        /*
        await notificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Filmmaker Alerts',
          body: 'No new releases found.',
          payload: 'app://history',
          totalMovieCount: 0,
        );
        */
      }
      
    } catch (e) {
      debugPrint('[SystemTray] Error during release check: $e');
      debugPrint('[SystemTray] Stack trace: ${StackTrace.current}');
      
      // Optional: Show error notification
      /*
      try {
        final notificationService = _container!.read(notificationServiceProvider);
        await notificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Filmmaker Alerts - Error',
          body: 'Failed to check for new releases.',
          payload: 'app://history',
          totalMovieCount: 0,
        );
      } catch (e2) {
        debugPrint('[SystemTray] Failed to show error notification: $e2');
      }
      */
    }
  }

  bool get isInitialized => _isInitialized;
}
