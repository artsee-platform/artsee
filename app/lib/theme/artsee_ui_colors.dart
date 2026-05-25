import 'package:flutter/material.dart';
import '../widgets/common.dart';

/// 青花系界面语义色（与 Theme 绑定，供昼/夜两套视觉）
@immutable
class ArtseeUiColors extends ThemeExtension<ArtseeUiColors> {
  final Color porcelain;
  final Color ink;
  final Color silver;
  final Color cardIconBg;
  final Color deepPanel;

  const ArtseeUiColors({
    required this.porcelain,
    required this.ink,
    required this.silver,
    required this.cardIconBg,
    required this.deepPanel,
  });

  static const ArtseeUiColors light = ArtseeUiColors(
    porcelain: kPorcelain,
    ink: kInk,
    silver: kSilver,
    cardIconBg: Colors.white,
    deepPanel: kInk,
  );

  static const ArtseeUiColors dark = ArtseeUiColors(
    porcelain: Color(0xFF07080C),
    ink: Color(0xFFECEDF1),
    silver: Color(0xFF2E333D),
    cardIconBg: Color(0xFF171A21),
    deepPanel: Color(0xFF0A0B0E),
  );

  @override
  ArtseeUiColors copyWith({
    Color? porcelain,
    Color? ink,
    Color? silver,
    Color? cardIconBg,
    Color? deepPanel,
  }) {
    return ArtseeUiColors(
      porcelain: porcelain ?? this.porcelain,
      ink: ink ?? this.ink,
      silver: silver ?? this.silver,
      cardIconBg: cardIconBg ?? this.cardIconBg,
      deepPanel: deepPanel ?? this.deepPanel,
    );
  }

  @override
  ArtseeUiColors lerp(ThemeExtension<ArtseeUiColors>? other, double t) {
    if (other is! ArtseeUiColors) return this;
    return ArtseeUiColors(
      porcelain: Color.lerp(porcelain, other.porcelain, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
      cardIconBg: Color.lerp(cardIconBg, other.cardIconBg, t)!,
      deepPanel: Color.lerp(deepPanel, other.deepPanel, t)!,
    );
  }
}

extension ArtseeUiX on BuildContext {
  ArtseeUiColors get artC =>
      Theme.of(this).extension<ArtseeUiColors>() ?? ArtseeUiColors.light;
}
