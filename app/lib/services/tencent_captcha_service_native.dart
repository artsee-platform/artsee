import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/api_config.dart';
import 'tencent_captcha_models.dart';

class TencentCaptchaService {
  TencentCaptchaService._();

  static Future<TencentCaptchaProof?> verify(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const TencentCaptchaClientException(
        '当前桌面平台暂不支持腾讯安全验证',
      );
    }
    return Navigator.of(context).push<TencentCaptchaProof>(
      MaterialPageRoute<TencentCaptchaProof>(
        fullscreenDialog: true,
        builder: (_) => const _TencentCaptchaPage(),
      ),
    );
  }
}

class _TencentCaptchaPage extends StatefulWidget {
  const _TencentCaptchaPage();

  @override
  State<_TencentCaptchaPage> createState() => _TencentCaptchaPageState();
}

class _TencentCaptchaPageState extends State<_TencentCaptchaPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xfff6f7f8))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _loading = false;
              _error = '安全验证页面加载失败，请检查网络后重试';
            });
          },
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadRequest(_challengeUri());
  }

  Uri _challengeUri() {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base/api/v1/auth/captcha/challenge');
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri?.scheme != 'artsee-captcha') {
      return NavigationDecision.navigate;
    }
    if (uri?.host == 'success') {
      final proof = TencentCaptchaProof(
        ticket: uri?.queryParameters['ticket'] ?? '',
        randstr: uri?.queryParameters['randstr'] ?? '',
      );
      if (proof.isValid) {
        Navigator.of(context).pop(proof);
      } else {
        setState(() => _error = '安全验证结果无效，请重试');
      }
    } else if (uri?.host == 'cancel') {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = '安全验证未通过，请重试');
    }
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('安全验证')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator.adaptive()),
          if (_error != null)
            ColoredBox(
              color: const Color(0xfff6f7f8),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _controller.loadRequest(_challengeUri());
                        },
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
