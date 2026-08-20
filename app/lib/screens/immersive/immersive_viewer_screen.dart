import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/immersive_asset.dart';
import '../../widgets/immersive/immersive_web_surface.dart';

class ImmersiveViewerScreen extends StatefulWidget {
  final ImmersiveAsset asset;
  final String artworkTitle;
  final String? fallbackPosterUrl;

  const ImmersiveViewerScreen({
    super.key,
    required this.asset,
    required this.artworkTitle,
    this.fallbackPosterUrl,
  });

  @override
  State<ImmersiveViewerScreen> createState() => _ImmersiveViewerScreenState();
}

class _ImmersiveViewerScreenState extends State<ImmersiveViewerScreen> {
  Timer? _hintTimer;
  bool _hintVisible = true;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final viewerUri = _buildViewerUri(context);
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ImmersiveWebSurface(
            viewerUri: viewerUri,
            title: '${widget.artworkTitle}沉浸查看器',
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 96,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xF2090909),
                      Color(0xC9090909),
                      Color(0x00090909),
                    ],
                    stops: [0, 0.62, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    _ViewerRoundButton(
                      tooltip: '返回',
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '艺见心 · 数字典藏',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.artworkTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (widget.asset.credits?.trim().isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.asset.credits!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        '3DGS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _hintVisible ? 1 : 0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: const Center(
                    child: _ViewerHint(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Uri _buildViewerUri(BuildContext context) {
    final uri = widget.asset.buildViewerUri(
      viewerBaseUri: Uri.parse(AppConfig.immersiveViewerUrl),
      fallbackTitle: widget.artworkTitle,
      fallbackPosterUrl: widget.fallbackPosterUrl,
    );
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'layout': MediaQuery.orientationOf(context).name,
      },
    );
  }
}

class _ViewerRoundButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _ViewerRoundButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white12),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _ViewerHint extends StatelessWidget {
  const _ViewerHint();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swipe_rounded, size: 17, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              '拖动环绕 · 双指缩放',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
