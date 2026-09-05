import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../dev/dev_api_settings_page.dart';
import '../prevention/prevention_page.dart';
import '../widgets/prevention_carousel.dart';
import 'login_page.dart';
import 'register_page.dart';

/// Première page avant connexion : hero photo + dégradé violet, puis accès 2FA.
///
/// [LoginPage] est phone-first (modal blanc) ; mot de passe puis OTP restent
/// sur les écrans suivants. [RegisterPage] garde le mot de passe.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CityCareBrand.heroViolet,
      body: Column(
        children: [
          const Expanded(
            child: SafeArea(
              bottom: false,
              child: PreventionCarousel(),
            ),
          ),
          const _WelcomeActions(),
        ],
      ),
    );
  }
}

/// CTA discrets sous le hero : connexion et création de compte, puis 2FA.
class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CityCareBrand.heroViolet,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CityCareBrand.spaceLg,
            CityCareBrand.spaceSm,
            CityCareBrand.spaceLg,
            CityCareBrand.spaceSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: CityCareBrand.violet,
                    shape: CityCareBrand.stadium,
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Se connecter'),
                ),
              ),
              const SizedBox(height: CityCareBrand.spaceSm),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.4),
                    shape: CityCareBrand.stadium,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Créer un compte'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const PreventionPage()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Lire les conseils de prévention'),
              ),
              if (kDebugMode)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const DevApiSettingsPage()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Configurer l’URL du serveur'),
                ),
              Text(
                'Connexion par téléphone, puis un code à usage unique.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
