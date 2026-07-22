import 'dart:ui';

import 'package:flutter/material.dart';

const kDeepSeaBackground = Color(0xFF09111B);
const kDeepSeaMidnight = Color(0xFF050A10);
const kDeepSeaPanel = Color(0xFF14243A);
const kDeepSeaPanelSoft = Color(0xFF223247);
const kDeepSeaMetal = Color(0xFF34404C);
const kDeepSeaGlow = Color(0xFF9BE7E3);
const kDeepSeaInk = Color(0xFFF3F8FF);
const kDeepSeaMuted = Color(0xFFAAB8C7);
const kInkWashPaper = Color(0xFFF7F9F8);
const kInkWashInk = Color(0xFF30333A);
const kInkWashAccent = Color(0xFF647180);
const kGlassInk = Color(0xFF30333A);
const kGlassMuted = Color(0xFF6B6C73);
const kGlassAccent = Color(0xFF647180);
const kPageArtworkAsset = 'assets/images/soft_peach_light_background.jpg';

const kDeepSeaTextStyle = TextStyle(
  fontFamily: 'SF Pro Text',
  fontFamilyFallback: ['PingFang SC', 'Noto Sans SC'],
  letterSpacing: 0,
);

BoxDecoration deepSeaGlassDecoration({
  double radius = 28,
  double opacity = 0.74,
  bool glow = false,
  bool includeShadow = true,
  bool includeBorder = true,
}) {
  return BoxDecoration(
    color: kDeepSeaPanel.withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(radius),
    border: includeBorder
        ? Border.all(
            color: glow
                ? kDeepSeaGlow.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.13),
            width: glow ? 1.1 : 0.8,
          )
        : null,
    boxShadow: includeShadow
        ? [
            BoxShadow(
              color: const Color(0xFF050B1A).withValues(alpha: 0.32),
              blurRadius: glow ? 30 : 24,
              offset: const Offset(0, 14),
            ),
            if (glow)
              BoxShadow(
                color: kDeepSeaGlow.withValues(alpha: 0.11),
                blurRadius: 22,
                spreadRadius: -7,
                offset: const Offset(0, 7),
              ),
          ]
        : null,
  );
}

class DeepSeaBackdrop extends StatelessWidget {
  final Widget child;
  final String? artworkAsset;
  final double blurSigma;
  final double scrimOpacity;
  final Color backgroundColor;
  final Color scrimColor;

  const DeepSeaBackdrop({
    super.key,
    required this.child,
    this.artworkAsset,
    this.blurSigma = 34,
    this.scrimOpacity = 0.68,
    this.backgroundColor = kDeepSeaBackground,
    this.scrimColor = kDeepSeaMidnight,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (artworkAsset != null)
            ClipRect(
              child: Transform.scale(
                scale: 1.08,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: Image.asset(
                    artworkAsset!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: backgroundColor,
                    ),
                  ),
                ),
              ),
            ),
          if (artworkAsset != null)
            ColoredBox(
              color: scrimColor.withValues(alpha: scrimOpacity),
            ),
          child,
        ],
      ),
    );
  }
}

class DeepSeaGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool glow;
  final double opacity;
  final bool airy;

  const DeepSeaGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.glow = false,
    this.opacity = 0.74,
    this.airy = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final rimWidth = glow ? 1.35 : 1.05;
    final innerRadius = radius > rimWidth ? radius - rimWidth : 0.0;

    if (airy) {
      final materialStrength = opacity.clamp(0.5, 0.8).toDouble();
      final surfaceOpacity = (0.18 + ((materialStrength - 0.5) * 0.2))
          .clamp(0.18, 0.24)
          .toDouble();
      return OpticalGlassSurface(
        padding: padding,
        radius: radius,
        surfaceOpacity: surfaceOpacity,
        blurSigma: 14,
        emphasized: glow,
        child: child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: kDeepSeaMidnight.withValues(alpha: 0.34),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 11),
          ),
          if (glow)
            BoxShadow(
              color: kDeepSeaGlow.withValues(alpha: 0.1),
              blurRadius: 18,
              spreadRadius: -6,
              offset: const Offset(0, 7),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: Colors.white.withValues(alpha: glow ? 0.2 : 0.12),
            ),
            child: Padding(
              padding: EdgeInsets.all(rimWidth),
              child: DecoratedBox(
                decoration: deepSeaGlassDecoration(
                  radius: innerRadius,
                  opacity: opacity,
                  includeShadow: false,
                  includeBorder: false,
                ),
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OpticalGlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double surfaceOpacity;
  final double blurSigma;
  final bool elevated;
  final bool emphasized;

  const OpticalGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 24,
    this.surfaceOpacity = 0.2,
    this.blurSigma = 14,
    this.elevated = true,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final innerRadius = BorderRadius.circular(
      (radius - 1).clamp(0, radius).toDouble(),
    );
    final highlightInset = (radius * 0.58).clamp(10.0, 24.0).toDouble();
    final thicknessInset = (radius * 0.72).clamp(12.0, 30.0).toDouble();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 28,
                  spreadRadius: -9,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 13,
                  spreadRadius: -9,
                  offset: const Offset(-3, -3),
                ),
                if (emphasized)
                  BoxShadow(
                    color: kGlassAccent.withValues(alpha: 0.1),
                    blurRadius: 18,
                    spreadRadius: -7,
                    offset: const Offset(0, 7),
                  ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: surfaceOpacity),
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: emphasized
                          ? kGlassAccent.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.68),
                      width: 0.75,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(1.15),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: innerRadius,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.55,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: child,
              ),
              Positioned(
                top: 1,
                left: highlightInset,
                right: highlightInset,
                child: IgnorePointer(
                  child: Container(
                    height: 0.9,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 1,
                left: thicknessInset,
                right: thicknessInset,
                child: IgnorePointer(
                  child: Container(
                    height: 1.1,
                    decoration: BoxDecoration(
                      color: kGlassInk.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OpticalGlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final double iconSize;
  final Color iconColor;
  final bool emphasized;

  const OpticalGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 36,
    this.iconSize = 21,
    this.iconColor = kGlassInk,
    this.emphasized = false,
  });

  @override
  State<OpticalGlassIconButton> createState() => _OpticalGlassIconButtonState();
}

class _OpticalGlassIconButtonState extends State<OpticalGlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            scale: _pressed ? 0.96 : 1,
            child: OpticalGlassSurface(
              padding: EdgeInsets.zero,
              radius: widget.size / 2,
              surfaceOpacity: widget.emphasized ? 0.24 : 0.18,
              blurSigma: 12,
              emphasized: widget.emphasized,
              child: SizedBox.square(
                dimension: widget.size,
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: widget.iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
