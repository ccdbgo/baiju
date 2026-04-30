import 'package:flutter/services.dart';

/// Sends notifications via the native Windows Shell_NotifyIcon balloon tip.
/// Uses a MethodChannel backed by our own C++ plugin — no third-party libs.
class NativeNotificationChannel {
  NativeNotificationChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.baiju.app/notification');

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', <String, String>{
        'title': title,
        'body': body,
      });
    } catch (_) {
      // Silently ignore if native side is unavailable (e.g. web/test)
    }
  }
}
