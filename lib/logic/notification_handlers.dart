import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles notification action taps that arrive while the app is in the
/// background or terminated (Android only).
///
/// Must be a top-level function annotated @pragma('vm:entry-point') so the
/// Dart tree-shaker keeps it. Runs in a separate isolate — no BuildContext,
/// no UI, no Riverpod access.
///
/// 'see_details' (or a plain notification body tap) with an http:// payload
/// opens the TMDB URL directly in the browser.
/// 'dismiss' is a no-op — the notification auto-cancels via cancelNotification: true.
/// 'app://history' payload requires the app to be in the foreground or warming up;
/// it is handled by onDidReceiveNotificationResponse / getNotificationAppLaunchDetails
/// in the main isolate.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  final action = response.actionId;
  final payload = response.payload;

  if (action == 'see_details' || action == null) {
    if (payload != null && payload.startsWith('http')) {
      final uri = Uri.parse(payload);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    // 'app://history' — handled in main isolate on resume/launch
  }
  // 'dismiss' — cancelNotification: true already dismissed it
}
