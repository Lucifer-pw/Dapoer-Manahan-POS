// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'notification_helper.dart';

class WebNotificationHelper implements NotificationHelper {
  @override
  Future<void> init() async {
    try {
      if (html.Notification.permission == 'default') {
        await html.Notification.requestPermission();
      }
    } catch (e) {
      // Browser might not support or block it
    }
  }

  @override
  Future<void> showNotification({required String title, required String body, String? payload}) async {
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(
          title,
          body: body,
          icon: 'assets/assets/images/app_logo.png',
        );
      } else if (html.Notification.permission == 'default') {
        final permission = await html.Notification.requestPermission();
        if (permission == 'granted') {
          html.Notification(
            title,
            body: body,
            icon: 'assets/assets/images/app_logo.png',
          );
        }
      }
    } catch (e) {
      // ignore web notify errors (e.g. non-HTTPS, unsupported browser)
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    // Web notifications local display doesn't require registration token
    return null;
  }
}

NotificationHelper getNotificationHelper() => WebNotificationHelper();
