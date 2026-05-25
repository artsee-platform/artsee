import 'package:flutter/material.dart';
import '../widgets/common.dart';
import 'artsee_ui_colors.dart';

/// 白天：与历史「青花典藏」浅色稿一致
ThemeData buildArtseeLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    extensions: const <ThemeExtension<dynamic>>[ArtseeUiColors.light],
    colorScheme: const ColorScheme.light(
      primary: kCobalt,
      onPrimary: Colors.white,
      primaryContainer: kCobaltMuted,
      onPrimaryContainer: Colors.white,
      secondary: kSilver,
      onSecondary: kInk,
      surface: Colors.white,
      onSurface: kInk,
      surfaceContainerLowest: Colors.white,
      error: Color(0xFFDC2626),
      onError: Colors.white,
    ),
    fontFamily: 'Noto Sans SC',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, color: kInk, height: 1.2),
      headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: kInk, height: 1.3),
      headlineSmall: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: kInk, height: 1.4),
      titleLarge:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kInk),
      titleMedium:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kInk),
      titleSmall:
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kInk),
      bodyLarge: TextStyle(fontSize: 15, color: kInk, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13, color: kInk, height: 1.5),
      bodySmall: TextStyle(fontSize: 11, color: kInk, height: 1.4),
      labelLarge:
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kInk),
      labelMedium:
          TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kInk),
      labelSmall: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: kInk,
        letterSpacing: 0.5,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: kInk,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: kInk, size: 22),
      actionsIconTheme: IconThemeData(color: kInk, size: 22),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: kCobalt,
      unselectedItemColor: kSilver,
      selectedLabelStyle: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      unselectedLabelStyle:
          TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kCobalt,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kCobalt,
        side: const BorderSide(color: kCobalt, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kCobalt,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSilver.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: kCobalt, width: 1.5),
      ),
      hintStyle: TextStyle(fontSize: 13, color: kInk.withValues(alpha: 0.4)),
      prefixIconColor: kInk.withValues(alpha: 0.4),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kCobalt,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kCobalt,
      unselectedLabelColor: kSilver,
      indicatorColor: kCobalt,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle:
          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSilver.withValues(alpha: 0.5),
      selectedColor: kCobalt,
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSmall),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: kSilver.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      minLeadingWidth: 24,
      titleTextStyle:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kInk),
      subtitleTextStyle: TextStyle(fontSize: 12, color: kSilver),
    ),
    scaffoldBackgroundColor: kPorcelain,
  );
}

const Color _dInk = Color(0xFFECEDF1);
const Color _dBg = Color(0xFF07080C);
const Color _dSurface = Color(0xFF101218);
const Color _dSilver = Color(0xFF2E333D);
const Color _dOutline = Color(0xFF3A404A);

/// 夜晚：不改动浅色数值，只增加一套深色
ThemeData buildArtseeDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    extensions: const <ThemeExtension<dynamic>>[ArtseeUiColors.dark],
    colorScheme: const ColorScheme.dark(
      primary: kCobalt,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF1E2F4A),
      onPrimaryContainer: Color(0xFFCBDCF0),
      secondary: kCobaltMuted,
      onSecondary: Colors.white,
      surface: _dSurface,
      onSurface: _dInk,
      surfaceContainerLowest: _dSurface,
      surfaceContainerHighest: _dOutline,
      error: Color(0xFFF87171),
      onError: Color(0xFF1A0505),
    ),
    fontFamily: 'Noto Sans SC',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, color: _dInk, height: 1.2),
      headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: _dInk, height: 1.3),
      headlineSmall: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: _dInk, height: 1.4),
      titleLarge:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _dInk),
      titleMedium:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dInk),
      titleSmall:
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dInk),
      bodyLarge: TextStyle(fontSize: 15, color: _dInk, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13, color: _dInk, height: 1.5),
      bodySmall: TextStyle(fontSize: 11, color: _dInk, height: 1.4),
      labelLarge:
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dInk),
      labelMedium:
          TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _dInk),
      labelSmall: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: _dInk,
        letterSpacing: 0.5,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _dSurface,
      foregroundColor: _dInk,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: _dInk,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: _dInk, size: 22),
      actionsIconTheme: IconThemeData(color: _dInk, size: 22),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _dSurface,
      selectedItemColor: kCobaltMuted,
      unselectedItemColor: _dSilver,
      selectedLabelStyle: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      unselectedLabelStyle:
          TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF141820),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kCobalt,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kCobaltMuted,
        side: const BorderSide(color: kCobaltMuted, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kCobaltMuted,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1F28),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: kCobaltMuted, width: 1.5),
      ),
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8A9099)),
      prefixIconColor: const Color(0xFF8A9099),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kCobalt,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kCobaltMuted,
      unselectedLabelColor: _dSilver,
      indicatorColor: kCobaltMuted,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle:
          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF222831),
      selectedColor: kCobalt,
      labelStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: _dInk),
      secondaryLabelStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSmall),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A3038),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      minLeadingWidth: 24,
      titleTextStyle:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dInk),
      subtitleTextStyle: TextStyle(fontSize: 12, color: Color(0xFF9AA0A8)),
    ),
    scaffoldBackgroundColor: _dBg,
  );
}
