import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:windows_notification/windows_notification.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class NotificationService {
  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
  WindowsNotification? _windowsNotification;
  final Dio _dio = Dio();
  
  Function(String)? onAction;
  bool _isInitialized = false;
  
  Future<void> init({Function(String)? onAction}) async {
    if (_isInitialized) return;
    
    try {
      debugPrint('[NotificationService] Starting initialization...');
      
      this.onAction = onAction;
      
      if (Platform.isWindows) {
        debugPrint('[NotificationService] Initializing for Windows using windows_notification...');
        
        // Create Windows notification instance
        // For development/debug mode, we can use an applicationId
        // For packaged apps, applicationId should be null to use the app's display name
        _windowsNotification = WindowsNotification(
          applicationId: kDebugMode ? r"Filmmaker.Alerts.Debug" : r"Filmmaker Alerts",
        );
        
        // Initialize callback for handling notification actions
        dynamic notificationCallback(NotificationCallBackDetails message, [dynamic eventType, dynamic arguments]) {
          try {
            debugPrint('[NotificationService] Notification callback: $eventType, args: $arguments');
            if (arguments == 'app://history') {
              // In debug mode, we can't use app:// protocol, so we'll handle it through the callback
              onAction?.call('app://history');
            }
            return null;
          } catch (e) {
            debugPrint('[NotificationService] Callback error: $e');
            return null;
          }
        }
        
        try {
          _windowsNotification!.initNotificationCallBack(notificationCallback);
          debugPrint('[NotificationService] Notification callback initialized successfully');
        } catch (e) {
          debugPrint('[NotificationService] Failed to initialize callback: $e');
          // Continue without callback - notifications will still work
        }
        
        debugPrint('[NotificationService] Windows notification setup completed');
      } else {
        debugPrint('[NotificationService] Initializing for non-Windows platform...');
        
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

        debugPrint('[NotificationService] Calling plugin initialize...');
        final result = await _flutterLocalNotificationsPlugin!.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) async {
            debugPrint('[NotificationService] Received notification response: ${response.payload}');
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
        );
        
        debugPrint('[NotificationService] Plugin initialize result: $result');
      }
      
      _isInitialized = true;
      debugPrint('[NotificationService] Initialization completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] Initialization failed: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imagePath,
    List<String>? imagePaths, // New parameter for multiple images
    List<String>? releaseDates, // New parameter for release dates above posters
    int? totalMovieCount, // Total number of movies for "+X more" logic
  }) async {
    try {
      debugPrint('[NotificationService] showNotification called - ID: $id, Title: $title');
      
      if (!_isInitialized) {
        debugPrint('[NotificationService] Not initialized, calling init...');
        await init();
      }
      
      if (Platform.isWindows) {
        debugPrint('[NotificationService] Using windows_notification for Windows...');
        
        if (_windowsNotification == null) {
          throw StateError('Windows notification not initialized');
        }
        
        // Download images locally if provided
        List<String> localImagePaths = [];
        
        // Handle multiple images (up to 4)
        if (imagePaths != null && imagePaths.isNotEmpty) {
          for (int i = 0; i < imagePaths.length && i < 4; i++) {
            final imageUrl = imagePaths[i];
            if (imageUrl.startsWith('http')) {
              try {
                final localPath = await _downloadImageForNotification(imageUrl);
                localImagePaths.add(localPath);
                debugPrint('[NotificationService] Downloaded image ${i + 1} to: $localPath');
              } catch (e) {
                debugPrint('[NotificationService] Failed to download image ${i + 1}: $e');
              }
            } else {
              localImagePaths.add(imageUrl);
            }
          }
        } else if (imagePath != null) {
          // Handle single image (backward compatibility)
          if (imagePath.startsWith('http')) {
            try {
              final localPath = await _downloadImageForNotification(imagePath);
              localImagePaths.add(localPath);
              debugPrint('[NotificationService] Downloaded image to: $localPath');
            } catch (e) {
              debugPrint('[NotificationService] Failed to download image: $e');
            }
          } else {
            localImagePaths.add(imagePath);
          }
        }
        
        try {
          // Use custom XML template with text first, then release dates, then images below
          String releaseDatesXml = '';
          String imagesXml = '';
          
          debugPrint('[NotificationService] Building notification template...');
          
          if (localImagePaths.isNotEmpty) {
            debugPrint('[NotificationService] Adding ${localImagePaths.length} images to template');
            
            // Add release dates grid above posters if provided
            if (releaseDates != null && releaseDates.isNotEmpty) {
              debugPrint('[NotificationService] Adding ${releaseDates.length} release dates');
              releaseDatesXml = '<group>';
              
              // Show release dates for actual movie columns
              for (int i = 0; i < localImagePaths.length && i < 4; i++) {
                final releaseText = i < releaseDates.length ? releaseDates[i] : '';
                releaseDatesXml += '<subgroup hint-weight="25" hint-textStacking="center"><text hint-align="center" hint-style="captionSubtle">$releaseText</text></subgroup>';
              }
              
              // Add empty cell above "+X more" indicator if present
              if (totalMovieCount != null && totalMovieCount > localImagePaths.length) {
                releaseDatesXml += '<subgroup hint-weight="25" hint-textStacking="center"><text hint-align="center" hint-style="captionSubtle"></text></subgroup>';
              }
              
              releaseDatesXml += '</group>';
            }
            
            // Add poster images grid
            imagesXml = '<group>';
            for (int i = 0; i < localImagePaths.length && i < 4; i++) {
              debugPrint('[NotificationService] Adding image $i: ${localImagePaths[i]}');
              imagesXml += '<subgroup hint-weight="25"><image src="${localImagePaths[i]}" hint-removeMargin="true"/></subgroup>';
            }
            
            // Add "+X more" text in poster grid if there are more movies than posters
            if (totalMovieCount != null && totalMovieCount > localImagePaths.length) {
              final moreCount = totalMovieCount - localImagePaths.length;
              debugPrint('[NotificationService] Adding +$moreCount more indicator');
              imagesXml += '<subgroup hint-weight="25" hint-textStacking="center"><text hint-align="center" hint-style="captionSubtle">+$moreCount more</text></subgroup>';
            }
            
            imagesXml += '</group>';
          }
          
          String customTemplate = '''
<?xml version="1.0" encoding="utf-8"?>
<toast launch="app://history" scenario="reminder" activationType="protocol">
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

          debugPrint('[NotificationService] Template created, sending notification...');

          final message = NotificationMessage.fromCustomTemplate(
            id.toString(),
            group: "filmmaker_alerts",
          );
          
          await _windowsNotification!.showNotificationCustomTemplate(message, customTemplate);
          debugPrint('[NotificationService] Windows notification sent with custom template (text first, ${localImagePaths.length} images below)');
        } catch (e, stackTrace) {
          debugPrint('[NotificationService] Custom template failed: $e');
          debugPrint('[NotificationService] Stack trace: $stackTrace');
          
          try {
            // Fallback to plugin template with first image
            debugPrint('[NotificationService] Attempting fallback to plugin template...');
            final firstImage = localImagePaths.isNotEmpty ? localImagePaths.first : null;
            final message = NotificationMessage.fromPluginTemplate(
              id.toString(),
              title,
              body,
              launch: payload,
              image: firstImage,
            );
            await _windowsNotification!.showNotificationPluginTemplate(message);
            debugPrint('[NotificationService] Windows notification sent with plugin template');
          } catch (fallbackError) {
            debugPrint('[NotificationService] Fallback also failed: $fallbackError');
            rethrow;
          }
        }
      } else {
        debugPrint('[NotificationService] Using flutter_local_notifications for non-Windows...');
        
        if (_flutterLocalNotificationsPlugin == null) {
          throw StateError('Notification plugin not initialized for this platform');
        }
        
        // Try with minimal notification details first
        const NotificationDetails notificationDetails = NotificationDetails();

        debugPrint('[NotificationService] Calling plugin show with minimal details...');
        await _flutterLocalNotificationsPlugin!.show(
          id,
          title,
          body,
          notificationDetails,
          payload: payload,
        );
        debugPrint('[NotificationService] Notification sent successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] showNotification failed: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> showTestNotification() async {
    debugPrint('[NotificationService] showTestNotification called');
    
    // Check if we're on Windows and handle accordingly
    if (Platform.isWindows) {
      debugPrint('[NotificationService] Detected Windows platform');
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
        debugPrint('[NotificationService] Windows notification failed, trying fallback: $e');
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
      debugPrint('[NotificationService] Downloading image: $imageUrl');
      final response = await _dio.download(imageUrl, localPath);
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } else {
      debugPrint('[NotificationService] Using cached image: $localPath');
    }
    
    return localPath;
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
}