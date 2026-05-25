import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// ═══════════════════════════════════════════════════════════════
/// 全局环境配置（开发 / 生产）
/// ═══════════════════════════════════════════════════════════════
///
/// 编译时可通过 `--dart-define` 注入：
///   --dart-define=DEV_MODE=true
///   --dart-define=DEV_LOGIN=true
///   --dart-define=API_BASE_URL=https://api.example.com
///
class AppConfig {
  AppConfig._();

  static const bool _devMode =
      bool.fromEnvironment('DEV_MODE', defaultValue: false);
  static const bool _devLogin =
      bool.fromEnvironment('DEV_LOGIN', defaultValue: false);
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _webDevPort =
      String.fromEnvironment('WEB_DEV_PORT', defaultValue: '3003');

  /// 是否处于开发模式
  /// - Debug 构建自动为 true
  /// - Release 构建可传 `--dart-define=DEV_MODE=true`
  static bool get isDev => kDebugMode || _devMode;

  /// 是否处于生产模式
  static bool get isProd => !isDev;

  /// 是否启用登录页的「开发者一键登录」
  static bool get devLoginEnabled => kDebugMode || _devLogin || _devMode;

  /// Next.js BFF 基地址
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (kIsWeb) return 'http://localhost:$_webDevPort';
    if (Platform.isAndroid) return 'http://10.0.2.2:$_webDevPort';
    return 'http://127.0.0.1:$_webDevPort';
  }
}
