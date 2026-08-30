import 'package:flutter/material.dart';

import 'brand.dart';

/// Thèmes clair et sombre de CityCare : violet, blanc, SOS rouge.
///
/// AppBar violette à titre centré, boutons pilule, tuiles bordées,
/// indicateur de navigation lavande. Le SOS reste rouge.
class CityCareTheme {
  const CityCareTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);
    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true);

    final fieldFill = isDark ? Colors.white.withValues(alpha: 0.06) : CityCareBrand.fieldFill;
    final tileSide = BorderSide(color: isDark ? scheme.outlineVariant : CityCareBrand.tileBorder);

    return base.copyWith(
      // InkSparkle (M3) casse `flutter test` sur Windows (shader ink_sparkle.frag).
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: isDark ? CityCareBrand.darkBackground : CityCareBrand.lightBackground,
      textTheme: _textTheme(base.textTheme, scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? CityCareBrand.darkSurface : CityCareBrand.violet,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: CityCareBrand.spaceSm / 2),
        shape: RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusSm, side: tileSide),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: CityCareBrand.violet,
        shape: const RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusSm),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CityCareBrand.spaceMd,
          vertical: CityCareBrand.spaceXs,
        ),
        minVerticalPadding: 10,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.35,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CityCareBrand.violet,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(CityCareBrand.touchTargetHeight),
          shape: CityCareBrand.stadium,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CityCareBrand.violet,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(CityCareBrand.touchTargetHeight),
          shape: CityCareBrand.stadium,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CityCareBrand.violet,
          minimumSize: const Size.fromHeight(48),
          shape: CityCareBrand.stadium,
          side: const BorderSide(color: CityCareBrand.violet, width: 2),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CityCareBrand.violet,
          minimumSize: const Size(64, 44),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: CityCareBrand.violet,
        selectionColor: CityCareBrand.lavender,
        selectionHandleColor: CityCareBrand.violet,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: fieldFill,
        prefixIconColor: CityCareBrand.violet,
        suffixIconColor: CityCareBrand.violet,
        labelStyle: TextStyle(color: isDark ? scheme.onSurfaceVariant : CityCareBrand.titleInk),
        hintStyle: TextStyle(color: isDark ? scheme.onSurfaceVariant : const Color(0xFF757575)),
        floatingLabelStyle: const TextStyle(color: CityCareBrand.violet, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CityCareBrand.spaceMd,
          vertical: CityCareBrand.spaceMd,
        ),
        border: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusLg,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusLg,
          borderSide: const BorderSide(color: CityCareBrand.violet, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusLg,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusLg,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: CityCareBrand.violet.withValues(alpha: 0.12),
        side: tileSide,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: scheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: CityCareBrand.spaceSm, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: CityCareBrand.stadium,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 15),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: CityCareBrand.lavender,
        shape: RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusXl),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(CityCareBrand.radiusLg)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: CityCareBrand.sos,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: CityCareBrand.stadium,
        extendedTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? CityCareBrand.darkSurface : Colors.white,
        elevation: 0,
        indicatorColor: CityCareBrand.lavender,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? CityCareBrand.violet : CityCareBrand.mutedText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? CityCareBrand.violet : CityCareBrand.mutedText);
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CityCareBrand.violet,
        linearMinHeight: 3,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: CityCareBrand.sos,
        textColor: Colors.white,
      ),
    );
  }

  static ColorScheme _scheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const ColorScheme.dark(
        primary: Color(0xFFCE93D8),
        onPrimary: Color(0xFF4A148C),
        primaryContainer: Color(0xFF6A1B9A),
        onPrimaryContainer: Color(0xFFF3E5F5),
        secondary: Color(0xFFE1BEE7),
        onSecondary: Color(0xFF4A148C),
        secondaryContainer: CityCareBrand.secondaryDark,
        onSecondaryContainer: Color(0xFFF3E5F5),
        tertiary: CityCareBrand.lavender,
        onTertiary: Color(0xFF4A148C),
        tertiaryContainer: CityCareBrand.amberDark,
        onTertiaryContainer: Color(0xFFFFE7C2),
        error: Color(0xFFFF8A83),
        onError: Color(0xFF5B0F0C),
        errorContainer: CityCareBrand.sosDark,
        onErrorContainer: Color(0xFFFFDAD7),
        surface: CityCareBrand.darkSurface,
        onSurface: Color(0xFFF3E5F5),
        surfaceContainerHighest: Color(0xFF3D1A5C),
        onSurfaceVariant: Color(0xFFCEB3D9),
        outline: Color(0xFF8E6AA3),
        outlineVariant: Color(0xFF4A2A62),
        inverseSurface: Color(0xFFF3E5F5),
        onInverseSurface: Color(0xFF2A1248),
      );
    }
    return const ColorScheme.light(
      primary: CityCareBrand.violet,
      onPrimary: Colors.white,
      primaryContainer: CityCareBrand.lavender,
      onPrimaryContainer: Color(0xFF4A148C),
      secondary: CityCareBrand.primaryLight,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF3E5F5),
      onSecondaryContainer: Color(0xFF4A148C),
      tertiary: CityCareBrand.amberDark,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFF3C4),
      onTertiaryContainer: Color(0xFF3E2600),
      error: Color(0xFFC1211C),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD7),
      onErrorContainer: Color(0xFF5B0F0C),
      surface: Colors.white,
      onSurface: CityCareBrand.titleInk,
      surfaceContainerHighest: CityCareBrand.fieldFill,
      onSurfaceVariant: Color(0xFF616161),
      outline: Color(0xFFBDBDBD),
      outlineVariant: CityCareBrand.tileBorder,
      inverseSurface: Color(0xFF2E2E2E),
      onInverseSurface: Color(0xFFF5F5F5),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.4, color: scheme.onSurface),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.4, color: scheme.onSurfaceVariant),
      bodySmall: base.bodySmall?.copyWith(height: 1.35, color: scheme.onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
