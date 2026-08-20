import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ImmersiveWebSurface extends StatefulWidget {
  final Uri viewerUri;
  final String title;

  const ImmersiveWebSurface({
    super.key,
    required this.viewerUri,
    required this.title,
  });

  @override
  State<ImmersiveWebSurface> createState() => _ImmersiveWebSurfaceState();
}

class _ImmersiveWebSurfaceState extends State<ImmersiveWebSurface> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF090909))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _progress = 0;
              _error = null;
            });
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) return;
            setState(() => _error = '数字现场暂时无法加载，请检查网络后重试');
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null ||
                (uri.scheme != 'https' && uri.scheme != 'http')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(widget.viewerUri);
  }

  @override
  void didUpdateWidget(covariant ImmersiveWebSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerUri != widget.viewerUri) {
      _controller.loadRequest(widget.viewerUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_progress < 100 && error == null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              value: _progress <= 0 ? null : _progress / 100,
              color: Colors.white70,
              backgroundColor: Colors.white10,
            ),
          ),
        if (error != null)
          ColoredBox(
            color: const Color(0xFF090909),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 30,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _controller.reload(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('重新加载'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
