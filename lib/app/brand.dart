import 'package:flutter/material.dart';

/// Identité visuelle CityCare.
///
/// Ce fichier ne contient que des constantes de design (couleurs, espacements,
/// rayons, durées). Aucune logique métier, aucun secret.
///
/// Règle de lisibilité retenue pour toute l'application : un écran peut être lu
/// par un parent en situation de panique. On privilégie donc des contrastes
/// élevés, des cibles tactiles larges et un nombre limité de couleurs porteuses
/// de sens.
class CityCareBrand {
  const CityCareBrand._();

  // --- Couleurs de marque -------------------------------------------------

  /// Bleu de confiance : couleur principale, institutionnelle et calme.
  static const Color primary = Color(0xFF1B5CD9);
  static const Color primaryDark = Color(0xFF0E3E9E);
  static const Color primaryLight = Color(0xFF6E9BF0);

  /// Turquoise « soin » : accompagnement, présence, lien familial.
  static const Color secondary = Color(0xFF0E9A8D);
  static const Color secondaryDark = Color(0xFF00675C);

  /// Ambre « vigilance » : prévention, avertissement non urgent.
  static const Color amber = Color(0xFFF5A524);
  static const Color amberDark = Color(0xFF9A6200);

  /// Rouge SOS : réservé à l'urgence. Ne jamais l'utiliser pour du décor.
  static const Color sos = Color(0xFFE5322D);
  static const Color sosDark = Color(0xFF9C1B18);

  /// Vert sécurité : zone sûre, état nominal.
  static const Color safe = Color(0xFF1E8E5A);
  static const Color safeDark = Color(0xFF0B5E38);

  // --- Couleurs sémantiques de la carte -----------------------------------
  // Elles sont volontairement identiques en thème clair et sombre : sur une
  // carte, la signification d'une couleur ne doit pas changer avec le thème.

  /// Cercle d'une zone de sécurité (école, maison…).
  static const Color mapSafeZone = Color(0xFF2E7D32);

  /// Cercle d'une zone à risque déclarée.
  static const Color mapRiskZone = Color(0xFFE65100);

  /// Cercle d'une zone estimée par la recherche (Search Intelligence).
  static const Color mapEstimateZone = Color(0xFF1565C0);

  /// Zone de recherche prioritaire.
  static const Color mapPriorityZone = Color(0xFF8E24AA);

  /// Zone de recherche prioritaire de plus haut rang.
  static const Color mapHighPriorityZone = Color(0xFF6A1B9A);

  /// Témoignage déposé par un tiers.
  static const Color mapTestimony = Color(0xFF00897B);

  // --- Surfaces ------------------------------------------------------------

  static const Color lightBackground = Color(0xFFF6F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF0E1420);
  static const Color darkSurface = Color(0xFF161E2E);

  // --- Dégradés ------------------------------------------------------------

  /// Dégradé de marque : utilisé par le splash, l'en-tête d'accueil et le logo.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B5CD9), Color(0xFF0E9A8D)],
  );

  /// Dégradé nocturne du splash en thème sombre.
  static const LinearGradient nightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B2B6B), Color(0xFF06504A)],
  );

  /// Dégradé d'urgence : réservé au bouton SOS et au MODE URGENCE.
  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE5322D), Color(0xFFB3130F)],
  );

  // --- Espacements ---------------------------------------------------------

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // --- Rayons --------------------------------------------------------------

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));

  // --- Cibles tactiles -----------------------------------------------------

  /// Hauteur minimale d'un bouton important : utilisable sans viser.
  static const double touchTargetHeight = 56;

  /// Diamètre du bouton SOS circulaire.
  static const double sosButtonSize = 168;
}
