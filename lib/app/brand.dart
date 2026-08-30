import 'package:flutter/material.dart';

/// Identité visuelle CityCare, inspirée d’une app sécurité (violet profond,
/// blanc, SOS rouge) — pas une copie de nom ni de slogan.
///
/// Le vert fluo MotoDiGo n’est plus la marque. [lime] reste un alias du
/// violet pour ne pas casser les écrans qui s’y réfèrent encore.
class CityCareBrand {
  const CityCareBrand._();

  /// Accroche originale, distincte de « Never walk alone ».
  static const String tagline = 'Ici, on veille';

  // --- Couleurs de marque (violet bSafe-like, pas le vert Benskin) --------

  /// Violet profond des fonds plein écran et de l’AppBar.
  static const Color violet = Color(0xFF5B2C8B);

  /// Violet un peu plus saturé, boutons et accents.
  static const Color violetMid = Color(0xFF6A1B9A);

  /// Violet très sombre, splash / coins / thème nuit.
  static const Color violetDeep = Color(0xFF4A148C);

  /// Lavande des modales d’autorisation et des pastilles.
  static const Color lavender = Color(0xFFEDE4F5);

  static const Color primary = violet;
  static const Color primaryDark = violetDeep;
  static const Color primaryLight = Color(0xFF9C4DCC);

  /// Alias historique : l’ancien lime pointe vers le violet de marque.
  static const Color lime = violet;
  static const Color limeSoft = primaryLight;
  static const Color limeDark = violetDeep;

  static const Color secondary = primaryLight;
  static const Color secondaryDark = Color(0xFF7B1FA2);

  /// Wordmark : blanc sur violet, plus de jaune « DiGo ».
  static const Color wordmarkYellow = Color(0xFFFFFFFF);
  static const Color accentYellow = Color(0xFFD1C4E9);
  static const Color navYellow = lavender;

  static const Color wordmarkLight = Color(0xFFFFFFFF);

  /// Ambre « vigilance » : prévention, pas l’urgence.
  static const Color amber = Color(0xFFFFC107);
  static const Color amberDark = Color(0xFF9A6200);

  /// Rouge SOS : seul écart volontaire, réservé à l’urgence.
  static const Color sos = Color(0xFFE5322D);
  static const Color sosDark = Color(0xFF9C1B18);

  /// Vert sécurité carte : lisible, distinct du violet d’interface.
  static const Color safe = Color(0xFF2E7D32);
  static const Color safeDark = Color(0xFF00695C);

  // --- Couleurs sémantiques de la carte -----------------------------------

  static const Color mapSafeZone = Color(0xFF2E7D32);
  static const Color mapRiskZone = Color(0xFFE65100);
  static const Color mapEstimateZone = Color(0xFF1565C0);
  static const Color mapPriorityZone = Color(0xFF8E24AA);
  static const Color mapHighPriorityZone = Color(0xFF6A1B9A);
  static const Color mapTestimony = Color(0xFF00897B);

  // --- Surfaces ------------------------------------------------------------

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color fieldFill = Color(0xFFF5F5F5);
  static const Color tileBorder = Color(0xFFE0E0E0);
  static const Color mutedText = Color(0xFF9E9E9E);
  static const Color titleInk = Color(0xFF424242);

  static const Color darkBackground = Color(0xFF1A0A2E);
  static const Color darkSurface = Color(0xFF2A1248);

  // --- Dégradés ------------------------------------------------------------

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
  );

  static const LinearGradient welcomeTitleGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFE1BEE7)],
  );

  static const LinearGradient nightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A0A2E), Color(0xFF4A148C)],
  );

  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE5322D), Color(0xFFB3130F)],
  );

  /// Violet un peu plus vif du bas des slides d’accueil (photo → fond uni).
  static const Color heroViolet = Color(0xFF6B2FA0);

  /// Photo lisible en haut (~60 %), puis fondu transparent → violet uni.
  static const LinearGradient heroPhotoFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.00, 0.40, 0.56, 0.70, 1.00],
    colors: [
      Color(0x00000000),
      Color(0x00000000),
      Color(0x996B2FA0),
      Color(0xFF6B2FA0),
      Color(0xFF6B2FA0),
    ],
  );

  // --- Espacements ---------------------------------------------------------

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double spaceXxl = 40;

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius borderRadiusPill = BorderRadius.all(Radius.circular(radiusPill));

  static const StadiumBorder stadium = StadiumBorder();

  static const double touchTargetHeight = 56;
  static const double sosButtonSize = 168;
}
