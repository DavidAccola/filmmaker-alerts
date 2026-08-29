import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:windows_notification/windows_notification.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../logic/notification_handlers.dart' show notificationTapBackground;

class NotificationService {
  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
  WindowsNotification? _windowsNotification;
  final Dio _dio = Dio();
  
  Function(String)? onAction;
  bool _isInitialized = false;
  
  Future<void> init({Function(String)? onAction}) async {
    if (_isInitialized) return;
    
    try {
      this.onAction = onAction;
      
      if (Platform.isWindows) {
        
        // Create Windows notification instance
        // applicationId must match the AppUserModelID set in main.cpp
        _windowsNotification = WindowsNotification(
          applicationId: r"FilmmakerAlerts.App",
        );
        
        // Initialize callback for handling notification actions
        dynamic notificationCallback(NotificationCallBackDetails message, [dynamic eventType, dynamic arguments]) {
          try {
            if (arguments == 'app://history') {
              // In debug mode, we can't use app:// protocol, so we'll handle it through the callback
              onAction?.call('app://history');
            }
            return null;
          } catch (e) {
            return null;
          }
        }
        
        try {
          _windowsNotification!.initNotificationCallBack(notificationCallback);
        } catch (e) {
          // Continue without callback - notifications will still work
        }
        
      } else {
        
        // Only create the plugin instance for supported platforms
        _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        
        // Android Initialization
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        // Linux Initialization
        const LinuxInitializationSettings initializationSettingsLinux =
            LinuxInitializationSettings(defaultActionName: 'Open notification');

        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          linux: initializationSettingsLinux,
          // iOS settings can be added here
        );

        await _flutterLocalNotificationsPlugin!.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) async {
            final String? payload = response.payload;
            if (payload != null) {
              if (payload.startsWith('http')) {
                final uri = Uri.parse(payload);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } else if (payload.startsWith('app://')) {
                onAction?.call(payload);
              }
            }
          },
          // Handles action button taps while the app is backgrounded / terminated.
          // Must be a top-level @pragma('vm:entry-point') function.
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );

        // Android: create notification channel (required Android 8+)
        if (Platform.isAndroid) {
          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            'release_alerts',
            'Release Alerts',
            description: 'New movie and TV release notifications',
            importance: Importance.high,
          );
          await _flutterLocalNotificationsPlugin!
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(channel);

          // Request POST_NOTIFICATIONS permission (Android 13+)
          await _flutterLocalNotificationsPlugin!
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
        }
        
      }
      
      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imagePath,
    List<String>? imagePaths,
    List<String>? releaseDates,
    int? totalMovieCount,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      
      if (Platform.isWindows) {
        if (_windowsNotification == null) {
          throw StateError('Windows notification not initialized');
        }

        // Download images to local temp files (Windows Toast requires file:// paths)
        final List<String> localImagePaths = [];
        if (imagePaths != null && imagePaths.isNotEmpty) {
          for (int i = 0; i < imagePaths.length && i < 4; i++) {
            final imageUrl = imagePaths[i];
            if (imageUrl.startsWith('http')) {
              try {
                localImagePaths.add(await _downloadImageForNotification(imageUrl));
              } catch (_) {
                // Skip image on download failure — notification still shows without it
              }
            } else {
              localImagePaths.add(imageUrl);
            }
          }
        } else if (imagePath != null) {
          // Single image (backward compatibility)
          if (imagePath.startsWith('http')) {
            try {
              localImagePaths.add(await _downloadImageForNotification(imagePath));
            } catch (_) {}
          } else {
            localImagePaths.add(imagePath);
          }
        }

        try {
          String releaseDatesXml = '';
          String imagesXml = '';

          if (localImagePaths.isNotEmpty) {
            if (releaseDates != null && releaseDates.isNotEmpty) {
              releaseDatesXml = '<group>';
              for (int i = 0; i < localImagePaths.length && i < 4; i++) {
                final releaseText = i < releaseDates.length ? releaseDates[i] : '';
                releaseDatesXml += '<subgroup hint-weight="25" hint-textStacking="center"><text hint-align="center" hint-style="captionSubtle">$releaseText</text></subgroup>';
              }
              if (totalMovieCount != null && totalMovieCount > localImagePaths.length) {
                releaseDatesXml += '<subgroup hint-weight="25" hint-textStacking="center"><text hint-align="center" hint-style="captionSubtle"></text></subgroup>';
              }
              releaseDatesXml += '</group>';
            }

            imagesXml = '<group>';
            for (int i = 0; i < localImagePaths.length && i < 4; i++) {
              imagesXml += '<subgroup hint-weight="25"><image src="${localImagePaths[i]}" hint-removeMargin="true"/></subgroup>';
            }
            if (totalMovieCount != null && totalMovieCount > localImagePaths.length) {
              final moreCount = totalMovieCount - localImagePaths.length;
              imagesXml += '<subgroup hint-weight="25" hint-textStacking="center"><text hint-align="center" hint-style="captionSubtle">+$moreCount more</text></subgroup>';
            }
            imagesXml += '</group>';
          }
          
          String customTemplate = '''
<?xml version="1.0" encoding="utf-8"?>
<toast launch="app://history" activationType="protocol">
  <visual>
    <binding template="ToastGeneric">
      <text>${_escapeXml(title)}</text>
      <text hint-style="body">${_escapeXml(body)}</text>
      $releaseDatesXml
      $imagesXml
    </binding>
  </visual>
  <actions>
    <action content="See details" activationType="protocol" arguments="app://history"/>
    <action content="Dismiss" activationType="system" arguments="dismiss"/>
  </actions>
</toast>''';

          final message = NotificationMessage.fromCustomTemplate(
            id.toString(),
            group: "filmmaker_alerts",
          );
          
          await _windowsNotification!.showNotificationCustomTemplate(message, customTemplate);
        } catch (e, _) {
          // Custom template failed — fall back to the simpler plugin template with first image
          try {
            final firstImage = localImagePaths.isNotEmpty ? localImagePaths.first : null;
            final message = NotificationMessage.fromPluginTemplate(
              id.toString(),
              title,
              body,
              launch: payload,
              image: firstImage,
            );
            await _windowsNotification!.showNotificationPluginTemplate(message);
          } catch (fallbackError) {
            rethrow;
          }
        }
      } else {
        if (_flutterLocalNotificationsPlugin == null) {
          throw StateError('Notification plugin not initialized for this platform');
        }

        // --- Android: download poster image(s) for rich notification ---
        String? firstLocalImagePath;
        if (Platform.isAndroid && imagePaths != null && imagePaths.isNotEmpty) {
          try {
            firstLocalImagePath = await _downloadImageForNotification(imagePaths.first);
          } catch (_) {
            // Proceed without image if download fails
          }
        }

        // Build the appropriate Android style depending on number of releases
        StyleInformation? styleInformation;

        if (Platform.isAndroid) {
          final isSingleRelease = totalMovieCount == null || totalMovieCount == 1;

          if (isSingleRelease && firstLocalImagePath != null) {
            // BigPictureStyle: poster shown as hero image when expanded,
            // also as the largeIcon in the collapsed drawer row.
            final bitmap = FilePathAndroidBitmap(firstLocalImagePath);
            styleInformation = BigPictureStyleInformation(
              bitmap,
              largeIcon: bitmap,
              hideExpandedLargeIcon: true,  // don't show duplicate small icon when expanded
              contentTitle: title,
              summaryText: body,
              htmlFormatSummaryText: false,
            );
          } else if (!isSingleRelease) {
            // InboxStyle: one line per release with title + release date.
            // Combine movie titles with their release dates so each line reads:
            //   "Movie Title   💻 08/15/2026"
            final List<String> inboxLines = _buildInboxLines(body, releaseDates, totalMovieCount!);
            styleInformation = InboxStyleInformation(
              inboxLines,
              contentTitle: title,
              summaryText: 'Filmmaker Alerts',
            );
          }
        }

        // --- Build AndroidNotificationDetails ---
        final androidDetails = AndroidNotificationDetails(
          'release_alerts',
          'Release Alerts',
          channelDescription: 'New movie and TV release notifications',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: styleInformation,
          // Large icon (poster thumbnail in collapsed row) for multi-release
          largeIcon: (Platform.isAndroid && firstLocalImagePath != null && styleInformation is! BigPictureStyleInformation)
              ? FilePathAndroidBitmap(firstLocalImagePath)
              : null,
          // Action buttons — mirror the Windows notification actions
          actions: Platform.isAndroid
              ? const <AndroidNotificationAction>[
                  AndroidNotificationAction(
                    'see_details',
                    'See Details',
                    showsUserInterface: true,   // brings app to foreground
                    cancelNotification: true,
                  ),
                  AndroidNotificationAction(
                    'dismiss',
                    'Dismiss',
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                ]
              : null,
        );

        await _flutterLocalNotificationsPlugin!.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: androidDetails,
            linux: const LinuxNotificationDetails(),
          ),
          payload: payload,
        );
      }
    } catch (e, _) {
      rethrow;
    }
  }

  /// Returns details about the notification that launched the app (Android/iOS).
  /// Returns null if the app was not launched via a notification, or on Windows.
  Future<NotificationAppLaunchDetails?> getNotificationLaunchDetails() async {
    if (Platform.isWindows || _flutterLocalNotificationsPlugin == null) return null;
    return _flutterLocalNotificationsPlugin!.getNotificationAppLaunchDetails();
  }

  Future<void> showTestNotification() async {
    // Check if we're on Windows and handle accordingly
    if (Platform.isWindows) {
      // Windows platform detected
      try {
        await showNotification(
          id: 999,
          title: 'Test Notification',
          body: 'This is a test notification to verify Windows notifications work!',
          payload: 'test://notification',
          imagePath: 'https://image.tmdb.org/t/p/w200/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg', // Sample movie poster
        );
      } catch (e) {
        // Fallback notification failed
        rethrow;
      }
    } else {
      await showNotification(
        id: 999,
        title: 'Test Notification',
        body: 'This is a test notification to verify notifications work!',
        payload: 'test://notification',
      );
    }
  }

  /// Downloads an image from a URL and saves it locally for Windows notifications
  Future<String> _downloadImageForNotification(String imageUrl) async {
    final tempDir = await getTemporaryDirectory();
    final notificationImagesDir = Directory('${tempDir.path}/notification_images');
    
    // Create directory if it doesn't exist
    if (!await notificationImagesDir.exists()) {
      await notificationImagesDir.create(recursive: true);
    }
    
    // Generate filename from URL
    final uri = Uri.parse(imageUrl);
    final filename = uri.pathSegments.last.isNotEmpty 
        ? uri.pathSegments.last 
        : 'notification_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final localPath = '${notificationImagesDir.path}/$filename';
    final file = File(localPath);
    
    // Download if not already cached
    if (!await file.exists()) {
      final response = await _dio.download(imageUrl, localPath);
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    }
    
    return localPath;
  }

  /// Builds InboxStyle lines for multi-release Android notifications.
  /// Each line: "Movie Title   💻 08/15/2026" or just "Movie Title" if no date.
  /// Shows up to 5 lines; any excess becomes a "+N more" summary line.
  List<String> _buildInboxLines(
    String body,
    List<String>? releaseDates,
    int totalMovieCount,  // must equal newReleases.length; non-nullable to prevent silent truncation
  ) {
    // body for multi-release: "Movie A • Movie B • Movie C [• +N more]"
    final rawParts = body.split(' • ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    // Drop a trailing "+N more" fragment that may have been appended in formatBody
    final titles = rawParts.where((s) => !s.startsWith('+')).toList();

    const int maxLines = 5;
    final int showCount = titles.length.clamp(0, maxLines);

    final List<String> lines = [];
    for (int i = 0; i < showCount; i++) {
      final movieTitle = titles[i];
      // releaseDates[i] may contain newlines (multiple dates for one movie) — flatten to single line
      final date = (releaseDates != null && i < releaseDates.length)
          ? releaseDates[i].replaceAll('\n', ' ').trim()
          : '';
      lines.add(date.isNotEmpty ? '$movieTitle  $date' : movieTitle);
    }

    // Add "+N more" summary line if there are more releases than shown
    final remaining = totalMovieCount - lines.length;
    if (remaining > 0) {
      lines.add('+$remaining more');
    }

    return lines;
  }

  /// Escape XML special characters to prevent XML parsing errors
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}