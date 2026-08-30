import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/subscription.dart';
import 'subscription_scope.dart';

/// Offre annuelle. Paiement démo confirmé → statut Actif en base + local.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SubscriptionScope.of(context).load();
    });
  }

  Future<void> _confirmDemo() async {
    final billing = SubscriptionScope.of(context);
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmer l’offre annuelle ?'),
          content: const Text(
            'Paiement démo : aucun Mobile Money ni carte n’est débité. '
            'Le statut « Actif » sera enregistré sur le serveur et sur cet appareil.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              key: const Key('subscription-confirm-demo'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer le paiement démo'),
            ),
          ],
        );
      },
    );
    if (agreed != true || !mounted) {
      return;
    }
    final ok = await billing.recordAnnualIntent();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (billing.current.message ?? 'Abonnement actif. Paiement démo, aucun débit réel.')
              : (billing.errorMessage ?? 'Enregistrement impossible'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billing = SubscriptionScope.of(context);
    return Scaffold(
      key: const Key('subscription-page'),
      appBar: AppBar(title: const Text('Abonnement')),
      body: ListenableBuilder(
        listenable: billing,
        builder: (context, _) {
          final sub = billing.current;
          final expiry = sub.expiresAt?.toLocal().toString().split(' ').first ?? '—';
          return ListView(
            padding: const EdgeInsets.all(CityCareBrand.spaceLg),
            children: [
              Container(
                padding: const EdgeInsets.all(CityCareBrand.spaceLg),
                decoration: BoxDecoration(
                  gradient: CityCareBrand.brandGradient,
                  borderRadius: CityCareBrand.borderRadiusXl,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CityCare Famille',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${CareSubscription.annualAmount} FCFA / 12 mois',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Prix annuel en francs CFA (XAF), pensé pour le Cameroun. '
                      'Carte, SOS, zones de sécurité des enfants.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CityCareBrand.spaceLg),
              Text(
                key: const Key('subscription-status'),
                sub.isActive
                    ? 'Statut : Actif jusqu’au $expiry.'
                    : 'Aucun abonnement actif pour le moment.',
                style: const TextStyle(color: CityCareBrand.titleInk, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                sub.message ??
                    'Choisissez l’offre, puis confirmez le paiement démo. '
                    'Aucun Mobile Money réel n’est branché.',
                style: const TextStyle(color: Color(0xFF616161), height: 1.4),
              ),
              if (billing.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(billing.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: CityCareBrand.spaceXl),
              FilledButton(
                key: const Key('subscription-record'),
                onPressed: billing.isBusy || sub.isActive ? null : _confirmDemo,
                child: Text(sub.isActive ? 'Actif' : 'Choisir l’offre annuelle'),
              ),
            ],
          );
        },
      ),
    );
  }
}
