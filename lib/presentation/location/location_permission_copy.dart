import 'package:flutter/material.dart';

import '../../domain/entities/location_access.dart';

/// Textes affichés pour chaque état d'accès à la localisation.
///
/// Ils sont écrits pour un parent inquiet : on explique d'abord à quoi sert la
/// position, ensuite ce qui bloque, enfin le geste exact à faire. Aucun jargon
/// (« permission denied forever »), aucune culpabilisation.
class LocationPermissionCopy {
  const LocationPermissionCopy({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.icon,
    required this.isBlocking,
  });

  final String title;
  final String message;

  /// Libellé du bouton principal. `null` quand aucune action n'est possible.
  final String? actionLabel;

  final IconData icon;

  /// `true` quand la position ne peut pas être lue tant que rien n'est fait.
  final bool isBlocking;

  static LocationPermissionCopy of(LocationAccess access) {
    switch (access.status) {
      case LocationAccessStatus.granted:
        return const LocationPermissionCopy(
          title: 'Localisation autorisée',
          message: 'CityCare peut relever la position de ce téléphone. '
              'Le suivi en arrière-plan n’est actif que si vous l’avez autorisé dans Profil.',
          actionLabel: null,
          icon: Icons.check_circle_outline,
          isBlocking: false,
        );

      case LocationAccessStatus.serviceDisabled:
        return const LocationPermissionCopy(
          title: 'La localisation du téléphone est éteinte',
          message: 'Le GPS de l’appareil est désactivé, donc aucune position ne peut être relevée — '
              'ni par vous, ni par vos proches. '
              'Ouvrez les réglages et activez la localisation, puis revenez sur cet écran.',
          actionLabel: 'Ouvrir les réglages de localisation',
          icon: Icons.location_disabled,
          isBlocking: true,
        );

      case LocationAccessStatus.denied:
        return const LocationPermissionCopy(
          title: 'CityCare a besoin de la position',
          message: 'La position sert à afficher votre point sur la carte, à savoir si vous êtes dans une '
              'zone de sécurité, et à joindre un lieu à un SOS. '
              'Elle n’est partagée qu’avec les personnes que vous avez autorisées.',
          actionLabel: 'Autoriser la localisation',
          icon: Icons.my_location,
          isBlocking: true,
        );

      case LocationAccessStatus.deniedForever:
        return const LocationPermissionCopy(
          title: 'Localisation bloquée dans les réglages',
          message: 'L’autorisation a été refusée définitivement : le téléphone ne permet plus à CityCare '
              'de la redemander. '
              'Ouvrez les réglages de l’application, puis choisissez « Autoriser » pour la position. '
              'Sans cela, un SOS partira sans lieu.',
          actionLabel: 'Ouvrir les réglages de l’application',
          icon: Icons.lock_outline,
          isBlocking: true,
        );

      case LocationAccessStatus.unavailable:
        return const LocationPermissionCopy(
          title: 'Localisation indisponible',
          message: 'Ce téléphone n’a pas répondu à la demande de position. '
              'Les autres fonctions de CityCare restent utilisables, mais la carte ne pourra pas afficher '
              'votre point actuel.',
          actionLabel: 'Réessayer',
          icon: Icons.help_outline,
          isBlocking: true,
        );
    }
  }
}
