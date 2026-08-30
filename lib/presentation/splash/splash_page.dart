import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../widgets/brand_backdrop.dart';
import '../widgets/citycare_logo.dart';

/// Durée exacte du splash Flutter avant Welcome / MainShell / onboarding.
const Duration kSplashHold = Duration(seconds: 5);

/// Splash violet : logo, accroche, Bienvenue, pastilles. Aucun CTA.
///
/// Après [hold] (5 s par défaut), [onFinished] est appelé. La session
/// peut se restaurer pendant ce délai : le parent route ensuite vers
/// MainShell, l’onboarding ou Welcome (avec les boutons).
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.message,
    this.hold = kSplashHold,
    this.onFinished,
  });

  /// Texte discret en bas (ex. restauration de session).
  final String? message;

  /// Délai avant [onFinished]. `Duration.zero` pour les tests widget.
  final Duration hold;

  /// Naviguer une fois le délai écoulé. Ignoré si null (aperçu visuel).
  final VoidCallback? onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleFinished() {
    final done = widget.onFinished;
    if (done == null) {
      return;
    }
    if (widget.hold == Duration.zero) {
      // Post-frame : éviter setState pendant le premier build du parent.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          done();
        }
      });
      return;
    }
    _timer = Timer(widget.hold, () {
      if (mounted) {
        done();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash-page'),
      backgroundColor: CityCareBrand.violet,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CityCareBrandBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CityCareBrand.spaceLg),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  const CityCareLogo(
                    axis: Axis.vertical,
                    markSize: 112,
                    fontSize: 34,
                    tagline: CityCareBrand.tagline,
                    monochromeColor: Colors.white,
                    color: Colors.white,
                  ),
                  const Spacer(flex: 2),
                  const Text(
                    'Bienvenue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: CityCareBrand.spaceSm),
                  Text(
                    'Prévention, alerte et assistance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: CityCareBrand.spaceXl),
                  const _SplashHighlights(),
                  const Spacer(flex: 3),
                  if (widget.message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: CityCareBrand.spaceLg),
                      child: Text(
                        widget.message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CityCareBrand.wordmarkLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastilles décoratives : Prévention / Alerte SOS. Pas de navigation.
class _SplashHighlights extends StatelessWidget {
  const _SplashHighlights();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SplashPill(
          label: 'Prévention',
          child: Icon(Icons.shield_outlined, color: Colors.white, size: 28),
        ),
        SizedBox(width: 40),
        _SplashPill(
          label: 'Alerte SOS',
          child: Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashPill extends StatelessWidget {
  const _SplashPill({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.6),
          ),
          child: child,
        ),
        const SizedBox(height: CityCareBrand.spaceSm),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
