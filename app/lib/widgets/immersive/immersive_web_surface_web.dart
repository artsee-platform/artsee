import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

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
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    _viewType = 'artiqore-immersive-${identityHashCode(this)}';
    _iframe = web.HTMLIFrameElement()
      ..src = widget.viewerUri.toString()
      ..title = widget.title
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0'
      ..style.backgroundColor = '#090909'
      ..setAttribute('allow', 'fullscreen; xr-spatial-tracking')
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('loading', 'eager')
      ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) => _iframe,
    );
  }

  @override
  void didUpdateWidget(covariant ImmersiveWebSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerUri != widget.viewerUri) {
      _iframe.src = widget.viewerUri.toString();
    }
    if (oldWidget.title != widget.title) _iframe.title = widget.title;
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
