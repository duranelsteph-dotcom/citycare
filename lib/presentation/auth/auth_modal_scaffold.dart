import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../widgets/brand_backdrop.dart';
import '../widgets/citycare_logo.dart';

/// Fond violet + modal blanc arrondi, calqué sur l’auth Life360 (marque CityCare).
class AuthModalScaffold extends StatelessWidget {
  const AuthModalScaffold({
    super.key,
    required this.body,
  });

  final Widget body;

  @override
  Widget build(BuildContext context) {
    // Modal blanc Life360 : on force le thème clair pour que saisie, curseur
    // et labels restent foncés même si le téléphone est en mode nuit.
    return Theme(
      data: CityCareTheme.light(),
      child: Scaffold(
      backgroundColor: CityCareBrand.violet,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CityCareBrandBackdrop(),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Retour',
                      ),
                      const CityCareLogoMark(size: 36, monochromeColor: Colors.white),
                      const SizedBox(width: 10),
                      const CityCareWordmark(fontSize: 22, onBrand: true),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(CityCareBrand.radiusXl)),
                  clipBehavior: Clip.antiAlias,
                  child: body,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
