import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../config/api_config.dart';
import 'tencent_captcha_models.dart';

class TencentCaptchaService {
  TencentCaptchaService._();

  static Future<TencentCaptchaProof?> verify(BuildContext context) {
    return showDialog<TencentCaptchaProof>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _TencentCaptchaDialog(),
    );
  }
}

class _TencentCaptchaDialog extends StatefulWidget {
  const _TencentCaptchaDialog();

  @override
  State<_TencentCaptchaDialog> createState() => _TencentCaptchaDialogState();
}

class _TencentCaptchaDialogState extends State<_TencentCaptchaDialog> {
  late final String _viewType;
  late final Uri _challengeUri;
  late final StreamSubscription<web.MessageEvent> _subscription;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
    _challengeUri = Uri.parse('$base/api/v1/auth/captcha/challenge').replace(
      queryParameters: {'return_origin': web.window.location.origin},
    );
    _viewType =
        'artsee-tencent-captcha-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return web.HTMLIFrameElement()
        ..src = _challengeUri.toString()
        ..title = '腾讯安全验证'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    });
    _subscription = web.window.onMessage.listen(_handleMessage);
    _timeout = Timer(const Duration(minutes: 5), () {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('安全验证已超时，请重试')),
      );
    });
  }

  void _handleMessage(web.MessageEvent event) {
    if (!mounted || event.origin != _challengeUri.origin) return;
    final data = event.data;
    if (data is! JSString) return;
    try {
      final decoded = jsonDecode(data.toDart);
      if (decoded is! Map || decoded['type'] != 'artsee.tencent-captcha') {
        return;
      }
      if (decoded['result'] == 'cancel') {
        Navigator.of(context).pop();
        return;
      }
      final proof = TencentCaptchaProof(
        ticket: decoded['ticket']?.toString() ?? '',
        randstr: decoded['randstr']?.toString() ?? '',
      );
      if (decoded['result'] == 'success' && proof.isValid) {
        Navigator.of(context).pop(proof);
      }
    } catch (_) {
      // Ignore messages not produced by the validated captcha frame.
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 420,
        height: size.height.clamp(420, 620).toDouble(),
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
