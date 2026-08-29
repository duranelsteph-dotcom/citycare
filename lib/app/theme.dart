import 'package:flutter/material.dart';

import 'brand.dart';

/// Thèmes clair et sombre de CityCare.
///
/// Les deux thèmes partagent la même grammaire visuelle : même hiérarchie
/// typographique, mêmes rayons, mêmes cibles tactiles. Seules les surfaces
/// changent, pour qu'un écran appris en plein jour reste reconnaissable la nuit.
class CityCareTheme {
  const CityCareTheme._();

  /// Thème clair — utilisé par défaut.
  static ThemeData light() => _build(Brightness.light);

  /// Thème sombre — utile la nuit, moment où une disparition est signalée.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);
    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? CityCareBrand.darkBackground : CityCareBrand.lightBackground,
      textTheme: _textTheme(base.textTheme, scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? CityCareBrand.darkSurface : CityCareBrand.lightSurface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1.5,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0 : 0.12),
        margin: const EdgeInsets.symmetric(vertical: CityCareBrand.spaceSm / 2),
        shape: RoundedRectangleBorder(
          borderRadius: CityCareBrand.borderRadiusMd,
          side: BorderSide(color: scheme.outlineVariant, width: isDark ? 1 : 0.6),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        shape: const RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusMd),
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
          minimumSize: const Size.fromHeight(CityCareBrand.touchTargetHeight),
          shape: const RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusSm),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusSm),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 44),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CityCareBrand.spaceMd,
          vertical: CityCareBrand.spaceMd,
        ),
        border: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusSm,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusSm,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusSm,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusSm,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: CityCareBrand.borderRadiusSm,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(999))),
        labelStyle: TextStyle(color: scheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: CityCareBrand.spaceSm, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusSm),
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 15),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusMd),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(CityCareBrand.radiusLg)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: CityCareBrand.sos,
        foregroundColor: Colors.white,
        elevation: 6,
        extendedTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
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
        primary: Color(0xFF9DBBFA),
        onPrimary: Color(0xFF04214F),
        primaryContainer: Color(0xFF17408F),
        onPrimaryContainer: Color(0xFFDCE6FF),
        secondary: Color(0xFF5FD6C7),
        onSecondary: Color(0xFF00332E),
        secondaryContainer: CityCareBrand.secondaryDark,
        onSecondaryContainer: Color(0xFFD3FFF8),
        tertiary: Color(0xFFFFC46B),
        onTertiary: Color(0xFF3E2600),
        tertiaryContainer: CityCareBrand.amberDark,
        onTertiaryContainer: Color(0xFFFFE7C2),
        error: Color(0xFFFF8A83),
        onError: Color(0xFF5B0F0C),
        errorContainer: CityCareBrand.sosDark,
        onErrorContainer: Color(0xFFFFDAD7),
        surface: CityCareBrand.darkSurface,
        onSurface: Color(0xFFE6EBF5),
        surfaceContainerHighest: Color(0xFF20293B),
        onSurfaceVariant: Color(0xFFAFBACD),
        outline: Color(0xFF5C6879),
        outlineVariant: Color(0xFF2C374A),
        inverseSurface: Color(0xFFE6EBF5),
        onInverseSurface: Color(0xFF161E2C),
      );
    }
    return const ColorScheme.light(
      primary: CityCareBrand.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE6FF),
      onPrimaryContainer: Color(0xFF04214F),
      secondary: CityCareBrand.secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFCFF5F0),
      onSecondaryContainer: Color(0xFF00332E),
      tertiary: CityCareBrand.amberDark,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFEBCB),
      onTertiaryContainer: Color(0xFF3E2600),
      error: Color(0xFFC1211C),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD7),
      onErrorContainer: Color(0xFF5B0F0C),
      surface: CityCareBrand.lightSurface,
      onSurface: Color(0xFF141A24),
      surfaceContainerHighest: Color(0xFFEDF1F8),
      onSurfaceVariant: Color(0xFF4E5865),
      outline: Color(0xFF8B96A5),
      outlineVariant: Color(0xFFD8DFE9),
      inverseSurface: Color(0xFF232B36),
      onInverseSurface: Color(0xFFF2F5FA),
    );
  }

  /// Typographie : titres denses et lisibles, corps de texte aéré (hauteur de
  /// ligne 1.4) car beaucoup d'écrans portent des avertissements à lire vite.
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
