import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../widgets/prevention_illustrations.dart';

/// Conseils de prévention contre l'enlèvement d'enfants.
///
/// Contenu éditorial statique, sans appel réseau : il reste consultable hors
/// ligne et avant même d'être connecté, ce qui est le cas d'usage réel
/// (un parent qui découvre l'application, un jeune qui prépare sa rentrée).
class PreventionPage extends StatelessWidget {
  const PreventionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CityCareTheme.light(),
      child: Builder(
        builder: (context) => Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: CityCareBrand.violet,
        foregroundColor: Colors.white,
        title: const Text('Prévention'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CityCareBrand.spaceMd,
          CityCareBrand.spaceMd,
          CityCareBrand.spaceMd,
          CityCareBrand.spaceXl,
        ),
        children: [
          Text(
            'Lire les conseils de prévention',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: CityCareBrand.violet),
          ),
          const SizedBox(height: CityCareBrand.spaceXs),
          Text(
            'Trois réflexes qui protègent',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: CityCareBrand.violet),
          ),
          const SizedBox(height: CityCareBrand.spaceSm),
          Text(
            'Ces conseils ne remplacent pas les services de police ou de secours. '
            'Ils réduisent le risque et font gagner du temps si quelque chose arrive.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: CityCareBrand.spaceLg),
          const _PreventionSection(
            scene: PreventionScene.knownRoute,
            title: 'Un trajet connu, à des horaires connus',
            advice: [
              'Convenir ensemble du chemin entre la maison et l’école, et s’y tenir.',
              'Enregistrer ce chemin dans les zones de sécurité de CityCare, avec les jours et les heures.',
              'Prévenir un adulte de confiance en cas de changement, même petit.',
              'Éviter les raccourcis isolés, surtout à la tombée de la nuit.',
            ],
          ),
          const _PreventionSection(
            scene: PreventionScene.strangerDanger,
            title: 'Ne jamais suivre ni monter avec une personne inconnue',
            advice: [
              'Rester à plus d’un bras de distance d’un véhicule qui s’arrête.',
              'Un adulte qui a vraiment besoin d’aide s’adresse à un autre adulte, pas à un enfant.',
              'Refuser un cadeau, un téléphone, un trajet « pour dépanner ».',
              'S’éloigner vers un lieu fréquenté — boutique, marché, arrêt — et appeler.',
              'Convenir en famille d’un mot de passe : personne ne repart avec l’enfant sans ce mot.',
            ],
          ),
          const _PreventionSection(
            scene: PreventionScene.raiseAlert,
            title: 'Donner l’alerte tout de suite',
            advice: [
              'Ne pas attendre « au cas où ce serait rien » : les premières minutes comptent le plus.',
              'Utiliser le bouton SOS de CityCare — il joint la position connue à la demande d’aide.',
              'Le SOS vocal permet d’alerter sans sortir le téléphone, en prononçant la phrase d’aide.',
              'Prévenir en parallèle les secours et la police : CityCare informe vos proches, pas les autorités.',
            ],
          ),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(CityCareBrand.spaceMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onTertiaryContainer),
                  const SizedBox(width: CityCareBrand.spaceSm),
                  Expanded(
                    child: Text(
                      'CityCare est un outil d’entraide familiale. Une alerte n’est jamais un enlèvement '
                      'confirmé, et l’application ne remplace pas un signalement officiel.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                    ),
                  ),
                ],
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

class _PreventionSection extends StatelessWidget {
  const _PreventionSection({
    required this.scene,
    required this.title,
    required this.advice,
  });

  final PreventionScene scene;
  final String title;
  final List<String> advice;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: CityCareBrand.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(CityCareBrand.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: PreventionIllustration(scene: scene, height: 160)),
            const SizedBox(height: CityCareBrand.spaceMd),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CityCareBrand.spaceSm),
            for (final item in advice)
              Padding(
                padding: const EdgeInsets.only(bottom: CityCareBrand.spaceSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.check_circle, size: 16, color: CityCareBrand.violet),
                    ),
                    const SizedBox(width: CityCareBrand.spaceSm),
                    Expanded(
                      child: Text(item, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
