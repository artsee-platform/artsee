import 'package:flutter/material.dart';
import '../widgets/common.dart';

/// Imperial Blue 界面语义色（与 Theme 绑定，供昼/夜两套视觉）
@immutable
class ArtseeUiColors extends ThemeExtension<ArtseeUiColors> {
  final Color porcelain;
  final Color ink;
  final Color silver;
  final Color cardIconBg;
  final Color deepPanel;
  final Color nightInk;
  final Color inkWash;
  final Color stageBlue;
  final Color mistBlue;
  final Color lanternGold;

  const ArtseeUiColors({
    required this.porcelain,
    required this.ink,
    required this.silver,
    required this.cardIconBg,
    required this.deepPanel,
    required this.nightInk,
    required this.inkWash,
    required this.stageBlue,
    required this.mistBlue,
    required this.lanternGold,
  });

  static const ArtseeUiColors light = ArtseeUiColors(
    porcelain: kPorcelain,
    ink: kInk,
    silver: kSilver,
    cardIconBg: Colors.white,
    deepPanel: kInk,
    nightInk: Color(0xFF07111F),
    inkWash: Color(0xFF0A1833),
    stageBlue: Color(0xFF001D51),
    mistBlue: Color(0xFF8FA9C7),
    lanternGold: Color(0xFFC8A45D),
  );

  static const ArtseeUiColors dark = ArtseeUiColors(
    porcelain: Color(0xFF07111F),
    ink: Color(0xFFECEDF1),
    silver: Color(0xFF2E333D),
    cardIconBg: Color(0xFF0A1833),
    deepPanel: Color(0xFF001D51),
    nightInk: Color(0xFF07111F),
    inkWash: Color(0xFF0A1833),
    stageBlue: Color(0xFF001D51),
    mistBlue: Color(0xFF8FA9C7),
    lanternGold: Color(0xFFC8A45D),
  );

  @override
  ArtseeUiColors copyWith({
    Color? porcelain,
    Color? ink,
    Color? silver,
    Color? cardIconBg,
    Color? deepPanel,
    Color? nightInk,
    Color? inkWash,
    Color? stageBlue,
    Color? mistBlue,
    Color? lanternGold,
  }) {
    return ArtseeUiColors(
      porcelain: porcelain ?? this.porcelain,
      ink: ink ?? this.ink,
      silver: silver ?? this.silver,
      cardIconBg: cardIconBg ?? this.cardIconBg,
      deepPanel: deepPanel ?? this.deepPanel,
      nightInk: nightInk ?? this.nightInk,
      inkWash: inkWash ?? this.inkWash,
      stageBlue: stageBlue ?? this.stageBlue,
      mistBlue: mistBlue ?? this.mistBlue,
      lanternGold: lanternGold ?? this.lanternGold,
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
      nightInk: Color.lerp(nightInk, other.nightInk, t)!,
      inkWash: Color.lerp(inkWash, other.inkWash, t)!,
      stageBlue: Color.lerp(stageBlue, other.stageBlue, t)!,
      mistBlue: Color.lerp(mistBlue, other.mistBlue, t)!,
      lanternGold: Color.lerp(lanternGold, other.lanternGold, t)!,
    );
  }
}

extension ArtseeUiX on BuildContext {
  ArtseeUiColors get artC =>
      Theme.of(this).extension<ArtseeUiColors>() ?? ArtseeUiColors.light;
}
