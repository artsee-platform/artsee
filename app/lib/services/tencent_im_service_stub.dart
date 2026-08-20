// Stub implementation for platforms unsupported by Tencent IM SDK.

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

  static Future<TencentImLoginState?> ensureLoggedIn() async {
    throw UnsupportedError('腾讯云 IM 不支持当前平台');
  }

  static Future<bool> getPushConsent() => TencentPushService.getConsent();

  static Future<TencentPushActionResult> setPushConsent(bool enabled) =>
      TencentPushService.setConsent(enabled);

  static Future<void> addTextMessageHandler(
    void Function(Map<String, dynamic>) handler,
  ) async {
    // No-op on unsupported platforms.
  }

  static Future<void> removeTextMessageHandler(
    void Function(Map<String, dynamic>) handler,
  ) async {
    // No-op on unsupported platforms.
  }

  static Future<void> logout() async {
    // No-op on unsupported platforms.
  }

  static void resetLocalState() {
    // No-op on unsupported platforms.
  }
}
