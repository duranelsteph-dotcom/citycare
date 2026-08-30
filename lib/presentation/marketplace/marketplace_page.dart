import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../trackers/kit_page.dart';
import 'marketplace_catalog.dart';
import 'marketplace_controller.dart';
import 'marketplace_product_page.dart';
import 'marketplace_scope.dart';

/// Boutique in-app : kits GPS / traceurs, commande démo persistée.
class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key, MarketplaceController? controller})
      : _controller = controller;

  final MarketplaceController? _controller;

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  MarketplaceController get _controller {
    return widget._controller ?? MarketplaceScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Theme(
      data: CityCareTheme.light(),
      child: Scaffold(
        key: const Key('marketplace-page'),
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: CityCareBrand.violet,
          foregroundColor: Colors.white,
          title: const Text('Boutique'),
        ),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                CityCareBrand.spaceMd,
                CityCareBrand.spaceMd,
                CityCareBrand.spaceMd,
                120,
              ),
              children: [
                Text(
                  'Kits GPS et traceurs',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: CityCareBrand.violet,
                      ),
                ),
                const SizedBox(height: CityCareBrand.spaceSm),
                const Text(
                  'Catalogue CityCare, prix en francs CFA. '
                  'Confirmer le paiement démo enregistre la commande '
                  '(serveur + cet appareil). Aucun Mobile Money réel.',
                  style: TextStyle(color: Color(0xFF616161), height: 1.4),
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: CityCareBrand.spaceSm),
                  Text(
                    controller.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: CityCareBrand.spaceLg),
                for (final product in marketplaceCatalog)
                  _ProductCard(
                    product: product,
                    ordered: controller.isOrdered(product.id),
                    onView: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MarketplaceProductPage(
                          product: product,
                          controller: controller,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: CityCareBrand.spaceMd),
                OutlinedButton.icon(
                  key: const Key('marketplace-register-kit'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const KitPage()),
                  ),
                  icon: const Icon(Icons.watch),
                  label: const Text('J’ai déjà un kit — l’enregistrer'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.ordered,
    required this.onView,
  });

  final MarketplaceProduct product;
  final bool ordered;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('marketplace-card-${product.id}'),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: CityCareBrand.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(CityCareBrand.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: CityCareBrand.lavender,
                  foregroundColor: CityCareBrand.violet,
                  child: Icon(product.icon),
                ),
                const SizedBox(width: CityCareBrand.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: CityCareBrand.violet,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        product.tagline,
                        style: const TextStyle(color: Color(0xFF616161), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CityCareBrand.spaceSm),
            Text(
              product.priceLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: CityCareBrand.titleInk,
              ),
            ),
            if (ordered)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Commande enregistrée — paiement démo',
                  style: TextStyle(color: CityCareBrand.safe, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: CityCareBrand.spaceSm),
            FilledButton(
              key: Key('marketplace-voir-${product.id}'),
              onPressed: onView,
              child: const Text('Voir'),
            ),
          ],
        ),
      ),
    );
  }
}
