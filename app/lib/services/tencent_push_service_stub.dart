import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'tencent_push_models.dart';

/// Web/desktop-safe implementation. Tencent's Flutter Push plugin currently
/// supports Android and iOS only.
class TencentPushService {
  TencentPushService._();

  static const _consentKey = 'tencent_push_consent_v1';
  static final StreamController<TencentPushNotificationClick>
      _notificationClicks = StreamController.broadcast();

  static Stream<TencentPushNotificationClick> get notificationClicks =>
      _notificationClicks.stream;

  static Future<bool> getConsent() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_consentKey) ?? false;
  }

  static Future<TencentPushActionResult> setConsent(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_consentKey, enabled);
    return TencentPushActionResult(
      consentEnabled: enabled,
      supported: false,
      configured: false,
      registered: false,
      permissionGranted: false,
      message: enabled ? '当前平台不支持腾讯离线推送' : '推送通知已关闭',
    );
  }

  static Future<TencentPushActionResult> registerAfterImLogin({
    required int sdkAppId,
    bool requestPermission = false,
  }) async {
    final consent = await getConsent();
    return TencentPushActionResult(
      consentEnabled: consent,
      supported: false,
      configured: false,
      registered: false,
      permissionGranted: false,
      message: '当前平台不支持腾讯离线推送',
    );
  }

  static Future<TencentPushActionResult> unregister() async {
    return TencentPushActionResult(
      consentEnabled: await getConsent(),
      supported: false,
      configured: false,
      registered: false,
      permissionGranted: false,
      message: '当前平台没有已注册的腾讯推送',
    );
  }

  static TencentPushNotificationClick? consumePendingNotification() => null;
}
