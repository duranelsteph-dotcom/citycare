import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../widgets/citycare_logo.dart';
import '../widgets/prevention_illustrations.dart';

/// Écran d'accueil affiché pendant la restauration de la session.
///
/// Il porte le message de prévention plutôt qu'un simple indicateur de
/// chargement : c'est le seul moment où l'utilisateur regarde l'écran sans
/// avoir de tâche en cours, donc le bon moment pour rappeler la règle de base.
///
/// L'animation est **jouée une seule fois** (pas de boucle) : un écran de
/// démarrage qui pulse indéfiniment retient l'attention pour rien et rend les
/// tests d'interface instables.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.message});

  /// Ligne d'état affichée en bas (ex. « Restauration de votre session… »).
  final String? message;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<double> _rise = Tween<double>(begin: 18, end: 0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark ? CityCareBrand.nightGradient : CityCareBrand.brandGradient,
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fade.value,
                child: Transform.translate(offset: Offset(0, _rise.value), child: child),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CityCareBrand.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const CityCareLogoMark(size: 108),
                  const SizedBox(height: CityCareBrand.spaceLg),
                  const CityCareWordmark(fontSize: 40, color: Colors.white, accentColor: Color(0xFFB9F5EE)),
                  const SizedBox(height: CityCareBrand.spaceSm),
                  Text(
                    'Prévention, alerte et assistance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: CityCareBrand.spaceXl),
                  const PreventionIllustration(
                    scene: PreventionScene.knownRoute,
                    height: 168,
                    onDarkSurface: true,
                  ),
                  const SizedBox(height: CityCareBrand.spaceLg),
                  _SplashMessage(
                    text: 'Un trajet connu, un adulte de confiance prévenu, '
                        'et une alerte qui part en un seul geste.',
                  ),
                  const Spacer(),
                  if (widget.message != null) ...[
                    Text(
                      widget.message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                    ),
                    const SizedBox(height: CityCareBrand.spaceMd),
                  ],
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: CityCareBrand.spaceXl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashMessage extends StatelessWidget {
  const _SplashMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CityCareBrand.spaceMd,
        vertical: CityCareBrand.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: CityCareBrand.borderRadiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
          const SizedBox(width: CityCareBrand.spaceSm),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
