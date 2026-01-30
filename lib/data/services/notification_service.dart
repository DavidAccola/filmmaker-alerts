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
          settings: initializationSettings,
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
      // Initialize logger
      // await DebugLogger.instance.init();
      
      // DebugLogger.instance.logNotification('=== SHOW NOTIFICATION DEBUG ===');
      // DebugLogger.instance.logNotification('ID: $id');
      // DebugLogger.instance.logNotification('Title: "$title"');
      // DebugLogger.instance.logNotification('Body: "$body"');
      // DebugLogger.instance.logNotification('Payload: $payload');
      // DebugLogger.instance.logNotification('ImagePath: $imagePath');
      // DebugLogger.instance.logNotification('ImagePaths: $imagePaths');
      // DebugLogger.instance.logNotification('ReleaseDates: $releaseDates');
      // DebugLogger.instance.logNotification('TotalMovieCount: $totalMovieCount');
      // DebugLogger.instance.logNotification('Platform.isWindows: ${Platform.isWindows}');
      // DebugLogger.instance.logNotification('_isInitialized: $_isInitialized');
      
      if (!_isInitialized) {
        // DebugLogger.instance.logNotification('Not initialized, calling init...');
        await init();
      }
      
      if (Platform.isWindows) {
        // DebugLogger.instance.logNotification('Using windows_notification for Windows...');
        // DebugLogger.instance.logNotification('_windowsNotification == null: ${_windowsNotification == null}');
        
        if (_windowsNotification == null) {
          // DebugLogger.instance.logNotification('ERROR: Windows notification not initialized');
          throw StateError('Windows notification not initialized');
        }
        
        // Download images locally if provided
        List<String> localImagePaths = [];
        
        // Handle multiple images (up to 4)
        if (imagePaths != null && imagePaths.isNotEmpty) {
          // DebugLogger.instance.logNotification('Processing ${imagePaths.length} image paths...');
          for (int i = 0; i < imagePaths.length && i < 4; i++) {
            final imageUrl = imagePaths[i];
            // DebugLogger.instance.logNotification('Processing image $i: $imageUrl');
            if (imageUrl.startsWith('http')) {
              try {
                final localPath = await _downloadImageForNotification(imageUrl);
                localImagePaths.add(localPath);
                // DebugLogger.instance.logNotification('Downloaded image ${i + 1} to: $localPath');
              } catch (e) {
                // DebugLogger.instance.logNotification('Failed to download image ${i + 1}: $e');
              }
            } else {
              localImagePaths.add(imageUrl);
              // DebugLogger.instance.logNotification('Using local image path: $imageUrl');
            }
          }
        } else if (imagePath != null) {
          // DebugLogger.instance.logNotification('Processing single image path: $imagePath');
          // Handle single image (backward compatibility)
          if (imagePath.startsWith('http')) {
            try {
              final localPath = await _downloadImageForNotification(imagePath);
              localImagePaths.add(localPath);
              // DebugLogger.instance.logNotification('Downloaded image to: $localPath');
            } catch (e) {
              // DebugLogger.instance.logNotification('Failed to download image: $e');
            }
          } else {
            localImagePaths.add(imagePath);
            // DebugLogger.instance.logNotification('Using local image path: $imagePath');
          }
        } else {
          // DebugLogger.instance.logNotification('No images to process');
        }
        
        try {
          // Use custom XML template with text first, then release dates, then images below
          String releaseDatesXml = '';
          String imagesXml = '';
          
          // DebugLogger.instance.logNotification('Building notification template...');
          
          if (localImagePaths.isNotEmpty) {
            // DebugLogger.instance.logNotification('Adding ${localImagePaths.length} images to template');
            
            // Add release dates grid above posters if provided
            if (releaseDates != null && releaseDates.isNotEmpty) {
              // DebugLogger.instance.logNotification('Adding ${releaseDates.length} release dates');
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
              // DebugLogger.instance.logNotification('Adding image $i: ${localImagePaths[i]}');
              imagesXml += '<subgroup hint-weight="25"><image src="${localImagePaths[i]}" hint-removeMargin="true"/></subgroup>';
            }
            
            // Add "+X more" text in poster grid if there are more movies than posters
            if (totalMovieCount != null && totalMovieCount > localImagePaths.length) {
              final moreCount = totalMovieCount - localImagePaths.length;
              // DebugLogger.instance.logNotification('Adding +$moreCount more indicator');
              imagesXml += '<subgroup hint-weight="25" hint-textStacking="center"><text hint-align="center" hint-style="captionSubtle">+$moreCount more</text></subgroup>';
            }
            
            imagesXml += '</group>';
          } else {
            // DebugLogger.instance.logNotification('No images to add to template');
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

          // DebugLogger.instance.logNotification('Custom template created (${customTemplate.length} chars)');
          // DebugLogger.instance.logNotification('Attempting to send notification...');

          final message = NotificationMessage.fromCustomTemplate(
            id.toString(),
            group: "filmmaker_alerts",
          );
          
          await _windowsNotification!.showNotificationCustomTemplate(message, customTemplate);
          // DebugLogger.instance.logNotification('✅ Windows notification sent successfully with custom template');
        } catch (e, _) {
          // DebugLogger.instance.logNotification('❌ Custom template failed: $e');
          // DebugLogger.instance.logNotification('Stack trace: ${stackTrace.toString().substring(0, 500)}...');
          
          try {
            // Fallback to plugin template with first image
            // DebugLogger.instance.logNotification('Attempting fallback to plugin template...');
            final firstImage = localImagePaths.isNotEmpty ? localImagePaths.first : null;
            // DebugLogger.instance.logNotification('Using fallback image: $firstImage');
            
            final message = NotificationMessage.fromPluginTemplate(
              id.toString(),
              title,
              body,
              launch: payload,
              image: firstImage,
            );
            await _windowsNotification!.showNotificationPluginTemplate(message);
            // DebugLogger.instance.logNotification('✅ Windows notification sent with plugin template');
          } catch (fallbackError) {
            // DebugLogger.instance.logNotification('❌ Fallback also failed: $fallbackError');
            rethrow;
          }
        }
      } else {
        // DebugLogger.instance.logNotification('Using flutter_local_notifications for non-Windows...');
        
        if (_flutterLocalNotificationsPlugin == null) {
          // DebugLogger.instance.logNotification('ERROR: Notification plugin not initialized for this platform');
          throw StateError('Notification plugin not initialized for this platform');
        }
        
        // Try with minimal notification details first
        const NotificationDetails notificationDetails = NotificationDetails();

        // DebugLogger.instance.logNotification('Calling plugin show with minimal details...');
        await _flutterLocalNotificationsPlugin!.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: notificationDetails,
          payload: payload,
        );
        // DebugLogger.instance.logNotification('✅ Non-Windows notification sent successfully');
      }
    } catch (e, _) {
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

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}