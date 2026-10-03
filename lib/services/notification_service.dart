import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('com.tradepulse.stocksimulator/notifications');
  static const String _prefPermissionRequested = 'tradex_notification_permission_prompted';
  static const String _prefPermissionGranted = 'tradex_notification_permission_granted';

  bool _hasPromptedPermission = false;
  bool _isPermissionGranted = false;

  bool get hasPromptedPermission => _hasPromptedPermission;
  bool get isPermissionGranted => _isPermissionGranted;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasPromptedPermission = prefs.getBool(_prefPermissionRequested) ?? false;
      _isPermissionGranted = prefs.getBool(_prefPermissionGranted) ?? false;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final enabled = await areNotificationsEnabled();
        _isPermissionGranted = enabled;
        await prefs.setBool(_prefPermissionGranted, enabled);
      }
    } catch (e) {
      debugPrint('[NotificationService] init error: $e');
    }
  }

  // Check if system notifications are currently enabled on the device
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return enabled ?? false;
    } catch (e) {
      debugPrint('[NotificationService] areNotificationsEnabled error: $e');
      return false;
    }
  }

  // Request Android 13+ POST_NOTIFICATIONS runtime permission appropriately
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool? granted = await _channel.invokeMethod<bool>('requestNotificationPermission');
      final result = granted ?? false;

      _hasPromptedPermission = true;
      _isPermissionGranted = result;

      await prefs.setBool(_prefPermissionRequested, true);
      await prefs.setBool(_prefPermissionGranted, result);

      debugPrint('[NotificationService] Permission request result: $result');
      return result;
    } catch (e) {
      debugPrint('[NotificationService] requestNotificationPermission error: $e');
      return false;
    }
  }

  // Record user decision to decline notifications without asking again
  Future<void> declineNotificationPermission() async {
    _hasPromptedPermission = true;
    _isPermissionGranted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefPermissionRequested, true);
      await prefs.setBool(_prefPermissionGranted, false);
      await cancelNotifications();
    } catch (e) {
      debugPrint('[NotificationService] declineNotificationPermission error: $e');
    }
  }

  // Send a REAL Android phone system notification
  Future<bool> showSystemNotification({
    required String title,
    required String body,
    String? details,
    int id = 1001,
  }) async {
    debugPrint('[NotificationService] Sending REAL system notification: $title - $body');
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('[NotificationService] Skipped system notification (not Android): $title');
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'details': details,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[NotificationService] showSystemNotification error: $e');
      return false;
    }
  }

  // Schedule background hourly notifications via Android AlarmManager
  Future<bool> scheduleHourlyNotification({
    required String title,
    required String body,
    String? details,
    int intervalMinutes = 60,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>('scheduleHourlyNotification', {
        'title': title,
        'body': body,
        'details': details,
        'intervalMinutes': intervalMinutes,
      });
      debugPrint('[NotificationService] Scheduled background hourly notification: $success');
      return success ?? false;
    } catch (e) {
      debugPrint('[NotificationService] scheduleHourlyNotification error: $e');
      return false;
    }
  }

  // Cancel scheduled background alarms and active notifications
  Future<bool> cancelNotifications() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>('cancelNotifications');
      return success ?? false;
    } catch (e) {
      debugPrint('[NotificationService] cancelNotifications error: $e');
      return false;
    }
  }
}
