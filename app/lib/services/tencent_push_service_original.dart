import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_push/common/tim_push_listener.dart';
import 'package:tencent_cloud_chat_push/tencent_cloud_chat_push.dart';

import 'tencent_push_models.dart';

class TencentPushService {
  TencentPushService._();

  static const _consentKey = 'tencent_push_consent_v1';
  static const _enabled =
      bool.fromEnvironment('TENCENT_PUSH_ENABLED', defaultValue: false);
  static const _apnsCertificateId = int.fromEnvironment(
    'TENCENT_PUSH_APNS_CERTIFICATE_ID',
    defaultValue: 0,
  );
  static const _applicationGroupId = String.fromEnvironment(
    'TENCENT_PUSH_APPLICATION_GROUP_ID',
  );

  static final TencentCloudChatPush _push = TencentCloudChatPush();
  static final StreamController<TencentPushNotificationClick>
      _notificationClicks = StreamController.broadcast();
  static TIMPushListener? _listener;
  static TencentPushNotificationClick? _pendingNotification;
  static bool _registered = false;
  static int _registrationGeneration = 0;
  static Future<TencentPushActionResult>? _registrationFuture;
  static String? _lastClickExt;
  static DateTime? _lastClickAt;

  static bool get _supported => Platform.isAndroid || Platform.isIOS;
  static bool get _configured =>
      _enabled && (!Platform.isIOS || _apnsCertificateId > 0);

  static Stream<TencentPushNotificationClick> get notificationClicks =>
      _notificationClicks.stream;

  static Future<bool> getConsent() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_consentKey) ?? false;
  }

  static Future<TencentPushActionResult> setConsent(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_consentKey, enabled);
    if (!enabled) return unregister();
    return TencentPushActionResult(
      consentEnabled: true,
      supported: _supported,
      configured: _configured,
      registered: _registered,
      permissionGranted: false,
      message: _configured ? '已允许推送通知' : '已保存偏好，推送服务仍待配置',
    );
  }

  /// Register only after the app user has opted in and Tencent IM is logged in.
  /// The Push Key is intentionally not passed here: in IM-integrated mode the
  /// native Push SDK reuses the authenticated IM session.
  static Future<TencentPushActionResult> registerAfterImLogin({
    required int sdkAppId,
    bool requestPermission = false,
  }) {
    final pending = _registrationFuture;
    if (pending != null) return pending;
    final future = _registerAfterImLogin(
      sdkAppId: sdkAppId,
      requestPermission: requestPermission,
    );
    late final Future<TencentPushActionResult> trackedFuture;
    trackedFuture = future.whenComplete(() {
      if (identical(_registrationFuture, trackedFuture)) {
        _registrationFuture = null;
      }
    });
    _registrationFuture = trackedFuture;
    return trackedFuture;
  }

  static Future<TencentPushActionResult> _registerAfterImLogin({
    required int sdkAppId,
    required bool requestPermission,
  }) async {
    final generation = _registrationGeneration;
    final consent = await getConsent();
    if (!consent) {
      return TencentPushActionResult(
        consentEnabled: false,
        supported: _supported,
        configured: false,
        registered: false,
        permissionGranted: false,
        message: '用户尚未允许推送通知',
      );
    }
    if (!_supported) {
      return const TencentPushActionResult(
        consentEnabled: true,
        supported: false,
        configured: false,
        registered: false,
        permissionGranted: false,
        message: '当前平台不支持腾讯离线推送',
      );
    }
    if (!_configured) {
      return TencentPushActionResult(
        consentEnabled: true,
        supported: true,
        configured: false,
        registered: false,
        permissionGranted: false,
        message: Platform.isIOS && _apnsCertificateId <= 0
            ? '缺少 APNs 证书 ID，推送偏好已保存'
            : '腾讯推送尚未启用，推送偏好已保存',
      );
    }
    if (_registered) {
      return const TencentPushActionResult(
        consentEnabled: true,
        supported: true,
        configured: true,
        registered: true,
        permissionGranted: true,
        message: '推送通知已开启',
      );
    }

    try {
      var permission = await Permission.notification.status;
      if (requestPermission &&
          !permission.isGranted &&
          !permission.isProvisional) {
        permission = await Permission.notification.request();
      }
      final permissionGranted =
          permission.isGranted || permission.isProvisional;
      if (!permissionGranted) {
        return TencentPushActionResult(
          consentEnabled: true,
          supported: true,
          configured: true,
          registered: false,
          permissionGranted: false,
          message: permission.isPermanentlyDenied
              ? '系统通知权限已关闭，请在系统设置中开启'
              : '未获得系统通知权限',
        );
      }

      await _ensureListener();
      final result = await _push.registerPush(
        sdkAppId: sdkAppId,
        apnsCertificateID: Platform.isIOS ? _apnsCertificateId : null,
        applicationGroupID:
            _applicationGroupId.isEmpty ? null : _applicationGroupId,
        onNotificationClicked: ({
          required String ext,
          String? userID,
          String? groupID,
        }) {
          _recordNotificationClick(ext, userId: userID, groupId: groupID);
        },
      );
      if (result.code != 0) {
        return TencentPushActionResult(
          consentEnabled: true,
          supported: true,
          configured: true,
          registered: false,
          permissionGranted: true,
          message: result.errorMessage ?? '腾讯推送注册失败',
          code: result.code,
        );
      }

      // Logout/opt-out may happen while the native registration call is in
      // flight. Undo a stale success so the previous account cannot remain
      // bound to this device.
      final currentConsent = await getConsent();
      if (generation != _registrationGeneration || !currentConsent) {
        await _push.unRegisterPush();
        return TencentPushActionResult(
          consentEnabled: currentConsent,
          supported: true,
          configured: true,
          registered: false,
          permissionGranted: true,
          message: '推送注册已取消',
        );
      }

      _registered = true;
      final registration = await _push.getRegistrationID();
      final registrationId =
          registration.code == 0 ? registration.data?.toString().trim() : null;
      if (kDebugMode) {
        debugPrint(
          'Tencent Push registered; registration ID present: '
          '${registrationId?.isNotEmpty == true}',
        );
      }
      return TencentPushActionResult(
        consentEnabled: true,
        supported: true,
        configured: true,
        registered: true,
        permissionGranted: true,
        message: registrationId?.isNotEmpty == true
            ? '推送通知已开启'
            : '推送已注册，但尚未取得设备 RegistrationID',
        registrationId: registrationId,
      );
    } catch (error) {
      debugPrint('Tencent Push registration failed: $error');
      return TencentPushActionResult(
        consentEnabled: true,
        supported: true,
        configured: true,
        registered: false,
        permissionGranted: false,
        message: '腾讯推送注册失败：$error',
      );
    }
  }

  static Future<TencentPushActionResult> unregister() async {
    _registrationGeneration += 1;
    final consent = await getConsent();
    if (!_supported || !_registered) {
      return TencentPushActionResult(
        consentEnabled: consent,
        supported: _supported,
        configured: _configured,
        registered: false,
        permissionGranted: false,
        message: consent ? '当前没有已注册的腾讯推送' : '推送通知已关闭',
      );
    }

    try {
      final result = await _push.unRegisterPush();
      if (result.code != 0) {
        return TencentPushActionResult(
          consentEnabled: consent,
          supported: true,
          configured: _configured,
          registered: true,
          permissionGranted: true,
          message: result.errorMessage ?? '腾讯推送解绑失败',
          code: result.code,
        );
      }
      _registered = false;
      return TencentPushActionResult(
        consentEnabled: consent,
        supported: true,
        configured: _configured,
        registered: false,
        permissionGranted: false,
        message: consent ? '腾讯推送已解绑' : '推送通知已关闭',
      );
    } catch (error) {
      debugPrint('Tencent Push unregister failed: $error');
      return TencentPushActionResult(
        consentEnabled: consent,
        supported: true,
        configured: _configured,
        registered: true,
        permissionGranted: true,
        message: '腾讯推送解绑失败：$error',
      );
    }
  }

  static TencentPushNotificationClick? consumePendingNotification() {
    final click = _pendingNotification;
    _pendingNotification = null;
    return click;
  }

  static Future<void> _ensureListener() async {
    if (_listener != null) return;
    final listener = TIMPushListener(
      onNotificationClicked: _recordNotificationClick,
    );
    _listener = listener;
    await _push.addPushListener(listener: listener);
  }

  static void _recordNotificationClick(
    String ext, {
    String? userId,
    String? groupId,
  }) {
    final now = DateTime.now();
    if (_lastClickExt == ext &&
        _lastClickAt != null &&
        now.difference(_lastClickAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastClickExt = ext;
    _lastClickAt = now;
    final click = TencentPushNotificationClick.fromExt(
      ext,
      userId: userId,
      groupId: groupId,
    );
    _pendingNotification = click;
    _notificationClicks.add(click);
  }
}
