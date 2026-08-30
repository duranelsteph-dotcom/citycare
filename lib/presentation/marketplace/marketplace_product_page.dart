import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../trackers/kit_page.dart';
import 'marketplace_catalog.dart';
import 'marketplace_controller.dart';

/// Fiche produit + confirmation du paiement démo (écrit en base).
class MarketplaceProductPage extends StatelessWidget {
  const MarketplaceProductPage({
    super.key,
    required this.product,
    required this.controller,
  });

  final MarketplaceProduct product;
  final MarketplaceController controller;

  Future<void> _confirm(BuildContext context) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Commander ${product.name} ?'),
          content: Text(
            '${product.priceLabel}. Paiement démo : aucun Mobile Money '
            'ni carte n’est débité. La commande sera enregistrée.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              key: Key('marketplace-confirm-demo-${product.id}'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer le paiement démo'),
            ),
          ],
        );
      },
    );
    if (agreed != true || !context.mounted) {
      return;
    }
    final ok = await controller.recordOrder(product.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (controller.orders
                      .where((order) => order.productId == product.id)
                      .map((order) => order.message)
                      .firstOrNull ??
                  MarketplaceController.stubMessage)
              : (controller.errorMessage ?? 'Enregistrement impossible'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CityCareTheme.light(),
      child: Scaffold(
        key: Key('marketplace-product-${product.id}'),
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: CityCareBrand.violet,
          foregroundColor: Colors.white,
          title: Text(product.name),
        ),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final ordered = controller.isOrdered(product.id);
            return ListView(
              padding: const EdgeInsets.all(CityCareBrand.spaceLg),
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: CityCareBrand.lavender,
                  foregroundColor: CityCareBrand.violet,
                  child: Icon(product.icon, size: 36),
                ),
                const SizedBox(height: CityCareBrand.spaceMd),
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: CityCareBrand.violet,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.tagline,
                  style: const TextStyle(color: Color(0xFF616161), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: CityCareBrand.spaceMd),
                Text(
                  product.priceLabel,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: CityCareBrand.titleInk,
                  ),
                ),
                const SizedBox(height: CityCareBrand.spaceMd),
                Text(
                  product.description,
                  style: const TextStyle(color: Color(0xFF616161), height: 1.45, fontSize: 15),
                ),
                const SizedBox(height: CityCareBrand.spaceLg),
                Text(
                  ordered
                      ? MarketplaceController.stubMessage
                      : 'Choisissez l’offre, confirmez le paiement démo. '
                          'Aucun débit réel.',
                  style: const TextStyle(color: CityCareBrand.titleInk, height: 1.4),
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: CityCareBrand.spaceSm),
                  Text(
                    controller.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: CityCareBrand.spaceXl),
                FilledButton(
                  key: Key('marketplace-commander-${product.id}'),
                  onPressed: controller.isBusy || ordered ? null : () => _confirm(context),
                  child: Text(ordered ? 'Commande enregistrée' : 'Commander'),
                ),
                const SizedBox(height: CityCareBrand.spaceSm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const KitPage()),
                  ),
                  icon: const Icon(Icons.watch),
                  label: const Text('Enregistrer un kit déjà reçu'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
