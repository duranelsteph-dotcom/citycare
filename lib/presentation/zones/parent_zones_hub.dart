import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/identity.dart';
import '../family/family_scope.dart';
import '../family/link_child_page.dart';
import 'zone_pages.dart';
import 'zone_scope.dart';

/// Hub parent : un enfant, ses zones, bouton pour en ajouter une.
class ParentZonesHubPage extends StatefulWidget {
  const ParentZonesHubPage({super.key});

  @override
  State<ParentZonesHubPage> createState() => _ParentZonesHubPageState();
}

class _ParentZonesHubPageState extends State<ParentZonesHubPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FamilyScope.of(context).loadForGuardian();
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = FamilyScope.of(context);
    return Scaffold(
      key: const Key('parent-zones-hub'),
      appBar: AppBar(title: const Text('Zones de sécurité')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'parent-zones-link',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LinkChildPage()),
        ),
        icon: const Icon(Icons.link),
        label: const Text('Rattacher un enfant'),
      ),
      body: ListenableBuilder(
        listenable: family,
        builder: (context, _) {
          final children = family.active;
          if (family.isLoading && children.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (children.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(CityCareBrand.spaceLg),
              child: Text(
                'Rattachez d’abord un enfant. Ensuite vous définirez sa maison, '
                'son école, et le rayon de chaque zone.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              const Text(
                'Vous choisissez les lieux sûrs de votre enfant : nom, carte, rayon. '
                'Ce n’est pas une alerte de kidnapping.',
                style: TextStyle(color: Color(0xFF616161), height: 1.4),
              ),
              const SizedBox(height: 12),
              for (final link in children) _ChildZonesCard(link: link),
            ],
          );
        },
      ),
    );
  }
}

class _ChildZonesCard extends StatefulWidget {
  const _ChildZonesCard({required this.link});

  final GuardianLink link;

  @override
  State<_ChildZonesCard> createState() => _ChildZonesCardState();
}

class _ChildZonesCardState extends State<_ChildZonesCard> {
  int? _count;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCount());
  }

  Future<void> _loadCount() async {
    final zones = ZoneScope.of(context);
    await zones.loadChild(widget.link.youngPersonId);
    if (mounted) {
      setState(() => _count = zones.zones.length);
    }
  }

  void _open({bool add = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SafetyZonesPage(
          youngPersonId: widget.link.youngPersonId,
          displayName: widget.link.youngDisplayName ?? 'Enfant',
          canEdit: widget.link.canManageZones,
          openEditorOnStart: add && widget.link.canManageZones,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.link.youngDisplayName ?? 'Enfant';
    final canEdit = widget.link.canManageZones;
    return Card(
      key: Key('parent-zone-child-${widget.link.youngPersonId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _count == null
                  ? 'Zones de sécurité de $name'
                  : _count == 0
                      ? 'Aucune zone pour le moment'
                      : '$_count lieu(x) défini(s)',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: canEdit ? () => _open(add: true) : null,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Ajouter un lieu'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _open(),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Voir les zones'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
