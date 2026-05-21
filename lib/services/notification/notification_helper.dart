import 'notification_helper_stub.dart'
    if (dart.library.html) 'notification_helper_web.dart'
    if (dart.library.io) 'notification_helper_mobile.dart';

abstract class NotificationHelper {
  static NotificationHelper? _instance;

  static NotificationHelper get instance {
    _instance ??= getNotificationHelper();
    return _instance!;
  }

  Future<void> init();
  Future<void> showNotification({required String title, required String body, String? payload});
  Future<String?> getDeviceToken();
}
