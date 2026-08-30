import 'package:flutter/material.dart';

/// Produit du catalogue in-app (kits GPS / traceurs). Pas un lien Play Store.
class MarketplaceProduct {
  const MarketplaceProduct({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.priceFcfa,
    required this.icon,
  });

  final String id;
  final String name;
  final String tagline;
  final String description;
  final int priceFcfa;
  final IconData icon;

  /// Prix affiché en francs CFA, espaces milliers (FR).
  String get priceLabel => '${formatFcfa(priceFcfa)} FCFA';
}

/// Catalogue CityCare : prix honnêtes en XAF, commande encore stub.
const marketplaceCatalog = <MarketplaceProduct>[
  MarketplaceProduct(
    id: 'kit-gps',
    name: 'Kit GPS CityCare',
    tagline: 'Traceur familial — le kit parle au serveur',
    description:
        'Boîtier GPS prévu pour un sac, un cartable ou un proche. '
        'Il envoie sa dernière position connue au serveur CityCare, '
        'pas à cette application en Bluetooth. Ce n’est pas un bracelet magique '
        'ni un suivi en direct. Après réception, enregistrez-le dans Mon kit IoT.',
    priceFcfa: 45000,
    icon: Icons.watch,
  ),
  MarketplaceProduct(
    id: 'traceur-bt',
    name: 'Traceur Bluetooth',
    tagline: 'Type Tile — clés, sac, cartable',
    description:
        'Petite pastille pour retrouver un objet à proximité. '
        'CityCare ne parle pas au Bluetooth du Tile : c’est un aide-mémoire, '
        'pas un GPS continu. Utile en complément du kit serveur.',
    priceFcfa: 18500,
    icon: Icons.bluetooth_searching,
  ),
  MarketplaceProduct(
    id: 'montre-gps',
    name: 'Montre GPS enfant',
    tagline: 'Poignet, dernière position connue',
    description:
        'Montre-traceur pour un trajet école / maison. '
        'La position affichée dans CityCare reste la dernière connue — '
        'pas un suivi en direct, pas un kidnapping confirmé.',
    priceFcfa: 65000,
    icon: Icons.watch_later_outlined,
  ),
];

MarketplaceProduct? marketplaceProductById(String id) {
  for (final item in marketplaceCatalog) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}

/// 45000 → « 45 000 » (espace milliers FR).
String formatFcfa(int amount) {
  final raw = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(raw[i]);
  }
  return buffer.toString();
}
