import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/login_status.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

import 'backend_api_service.dart';
import 'tencent_push_service.dart';

class TencentImLoginState {
  final int sdkAppId;
  final String identifier;
  final String expiresAt;
  final String accountSync;

  const TencentImLoginState({
    required this.sdkAppId,
    required this.identifier,
    required this.expiresAt,
    required this.accountSync,
  });

  factory TencentImLoginState.fromJson(Map<String, dynamic> json) {
    return TencentImLoginState(
      sdkAppId: json['sdk_app_id'] is int
          ? json['sdk_app_id'] as int
          : int.parse(json['sdk_app_id'].toString()),
      identifier: json['identifier'].toString(),
      expiresAt: json['expires_at'].toString(),
      accountSync: json['account_sync']?.toString() ?? 'unknown',
    );
  }
}

class TencentImService {
  TencentImService._();

  static int? _initializedSdkAppId;
  static String? _loggedInIdentifier;
  static TencentImLoginState? _loginState;
  static Future<TencentImLoginState?>? _loginFuture;
  static Timer? _reloginTimer;
  static V2TimAdvancedMsgListener? _advancedMsgListener;
  static final Set<void Function(Map<String, dynamic>)> _messageHandlers = {};

  static V2TIMManager get _manager => TencentImSDKPlugin.v2TIMManager;

  static Future<TencentImLoginState?> ensureLoggedIn() async {
    if (_loggedInIdentifier != null && _loginState != null) {
      final status = await _manager.getLoginStatus();
      if (status.code == 0 && status.data == LoginStatus.V2TIM_STATUS_LOGINED) {
        return _loginState;
      }
      _loggedInIdentifier = null;
      _loginState = null;
    }

    final pending = _loginFuture;
    if (pending != null) return pending;
    final future = _login();
    _loginFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_loginFuture, future)) _loginFuture = null;
    }
  }

  static Future<TencentImLoginState?> _login() async {
    final config = await BackendApiService.fetchTencentImConfig();
    final sdkAppId = config['sdk_app_id'] is int
        ? config['sdk_app_id'] as int
        : int.parse(config['sdk_app_id'].toString());
    final identifier = config['identifier']?.toString() ?? '';
    final userSig = config['user_sig']?.toString() ?? '';

    if (sdkAppId <= 0 || identifier.isEmpty || userSig.isEmpty) {
      throw StateError('腾讯云 IM 登录配置不完整');
    }

    if (_initializedSdkAppId != sdkAppId) {
      final init = await _manager.initSDK(
        sdkAppID: sdkAppId,
        loglevel: kDebugMode
            ? LogLevelEnum.V2TIM_LOG_DEBUG
            : LogLevelEnum.V2TIM_LOG_INFO,
        showImLog: kDebugMode,
        listener: V2TimSDKListener(
          onUserSigExpired: _scheduleRelogin,
          onKickedOffline: _handleKickedOffline,
        ),
      );
      _throwIfFailed('腾讯云 IM 初始化失败', init.code, init.desc);
      _initializedSdkAppId = sdkAppId;
    }

    final login = await _manager.login(userID: identifier, userSig: userSig);
    _throwIfFailed('腾讯云 IM 登录失败', login.code, login.desc);
    _loggedInIdentifier = identifier;
    _loginState = TencentImLoginState.fromJson(config);
    unawaited(_registerPushAfterLogin(_loginState!));
    return _loginState;
  }

  static Future<bool> getPushConsent() => TencentPushService.getConsent();

  static Future<TencentPushActionResult> setPushConsent(bool enabled) async {
    final consentResult = await TencentPushService.setConsent(enabled);
    if (!enabled) return consentResult;

    final state = await ensureLoggedIn();
    if (state == null) return consentResult;
    var result = await TencentPushService.registerAfterImLogin(
      sdkAppId: state.sdkAppId,
      requestPermission: true,
    );
    // A background registration started by the just-completed IM login may
    // have checked permission without prompting. Retry once after that shared
    // operation completes so this explicit user action can show the OS dialog.
    if (result.configured && !result.permissionGranted) {
      result = await TencentPushService.registerAfterImLogin(
        sdkAppId: state.sdkAppId,
        requestPermission: true,
      );
    }
    return result;
  }

  static Future<void> addTextMessageHandler(
    void Function(Map<String, dynamic>) handler,
  ) async {
    _messageHandlers.add(handler);
    if (_advancedMsgListener != null) return;

    await ensureLoggedIn();
    _advancedMsgListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (message) {
        final mapped = _messageToMap(message);
        if (mapped == null) return;
        for (final listener in List.of(_messageHandlers)) {
          listener(mapped);
        }
      },
    );
    await _manager.getMessageManager().addAdvancedMsgListener(
          listener: _advancedMsgListener!,
        );
  }

  static Future<void> removeTextMessageHandler(
    void Function(Map<String, dynamic>) handler,
  ) async {
    _messageHandlers.remove(handler);
    if (_messageHandlers.isNotEmpty || _advancedMsgListener == null) return;

    final listener = _advancedMsgListener;
    _advancedMsgListener = null;
    await _manager.getMessageManager().removeAdvancedMsgListener(
          listener: listener,
        );
  }

  static Future<void> logout() async {
    _reloginTimer?.cancel();
    _reloginTimer = null;
    await TencentPushService.unregister();
    final shouldLogout = _loggedInIdentifier != null;
    final listener = _advancedMsgListener;
    if (!shouldLogout && listener == null) return;
    _advancedMsgListener = null;
    _messageHandlers.clear();
    try {
      if (listener != null) {
        await _manager.getMessageManager().removeAdvancedMsgListener(
              listener: listener,
            );
      }
      if (shouldLogout) {
        await _manager.logout();
      }
    } finally {
      _loggedInIdentifier = null;
      _loginState = null;
    }
  }

  static void resetLocalState() {
    _loggedInIdentifier = null;
    _loginState = null;
    _loginFuture = null;
    _reloginTimer?.cancel();
    _reloginTimer = null;
  }

  static void _scheduleRelogin() {
    _loggedInIdentifier = null;
    _loginState = null;
    _reloginTimer?.cancel();
    _reloginTimer = Timer(const Duration(seconds: 1), () {
      unawaited(
        ensureLoggedIn().then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Tencent IM UserSig refresh failed: $error');
          },
        ),
      );
    });
  }

  static void _handleKickedOffline() {
    _loggedInIdentifier = null;
    _loginState = null;
    _loginFuture = null;
    _reloginTimer?.cancel();
    _reloginTimer = null;
    unawaited(TencentPushService.unregister());
    debugPrint(
        'Tencent IM account was kicked offline; login will recover on next use.');
  }

  static Future<void> _registerPushAfterLogin(
    TencentImLoginState state,
  ) async {
    final result = await TencentPushService.registerAfterImLogin(
      sdkAppId: state.sdkAppId,
    );
    if (kDebugMode && result.consentEnabled && !result.registered) {
      debugPrint('Tencent Push not registered: ${result.message}');
    }
  }

  static Map<String, dynamic>? _messageToMap(dynamic message) {
    final body = _dynamicString(message?.textElem?.text);
    if (body == null || body.trim().isEmpty) return null;

    final isSelf = _dynamicBool(message?.isSelf) ?? false;
    final msgId = _dynamicString(message?.msgID) ?? _dynamicString(message?.id);
    final peerIdentifier = _dynamicString(message?.userID);
    final senderIdentifier = _dynamicString(message?.sender);
    final groupId = _dynamicString(message?.groupID);
    final cloudCustomData = _decodeCloudCustomData(message?.cloudCustomData);

    return <String, dynamic>{
      if (msgId != null && msgId.isNotEmpty) 'id': 'im_$msgId',
      'sender_id': senderIdentifier,
      'sender_role': isSelf ? 'me' : 'peer',
      'body': body,
      'message_type': 'text',
      'created_at': _timestampToIso(message?.timestamp),
      'metadata': <String, dynamic>{
        'provider': 'tencent_im',
        if (msgId != null && msgId.isNotEmpty) 'im_msg_id': msgId,
        if (peerIdentifier != null && peerIdentifier.isNotEmpty)
          'peer_im_identifier': peerIdentifier,
        if (senderIdentifier != null && senderIdentifier.isNotEmpty)
          'sender_im_identifier': senderIdentifier,
        if (groupId != null && groupId.isNotEmpty) 'im_group_id': groupId,
        ...cloudCustomData,
        'is_self': isSelf,
      },
    };
  }

  static String _timestampToIso(dynamic raw) {
    final timestamp = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (timestamp == null || timestamp <= 0) {
      return DateTime.now().toIso8601String();
    }
    final milliseconds = timestamp > 20000000000 ? timestamp : timestamp * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds).toIso8601String();
  }

  static String? _dynamicString(dynamic value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }

  static bool? _dynamicBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    return value.toString() == 'true';
  }

  static Map<String, dynamic> _decodeCloudCustomData(dynamic value) {
    final text = _dynamicString(value);
    if (text == null) return const {};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const <String, dynamic>{};
    } catch (_) {
      return const {};
    }
  }

  static void _throwIfFailed(String prefix, int code, String desc) {
    if (code == 0) return;
    throw StateError('$prefix: $code $desc');
  }
}
