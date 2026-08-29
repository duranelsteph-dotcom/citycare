import 'package:flutter/material.dart';

import '../../domain/enums/citycare_enums.dart';
import '../auth/role_labels.dart';
import '../location/location_scope.dart';
import 'family_scope.dart';

class GuardiansPage extends StatefulWidget {
  const GuardiansPage({super.key});

  @override
  State<GuardiansPage> createState() => _GuardiansPageState();
}

class _GuardiansPageState extends State<GuardiansPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FamilyScope.of(context).loadForYoung();
      LocationScope.of(context).loadMyShares();
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = FamilyScope.of(context);
    final locations = LocationScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts de confiance')),
      body: ListenableBuilder(
        listenable: Listenable.merge([family, locations]),
        builder: (context, _) {
          if (family.isLoading && family.links.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (family.links.isEmpty) {
            return const Center(child: Text('Aucun parent ou proche rattaché pour le moment.'));
          }
          return ListView(
            children: [
              if (family.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(family.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ...family.links.map((link) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(link.guardianName ?? 'Contact', style: Theme.of(context).textTheme.titleMedium),
                        Text('${relationLabel(link.relation)} · ${linkStatusLabel(link.status)}'),
                        if (link.guardianPhone != null) Text(link.guardianPhone!),
                        if (link.status == GuardianLinkStatus.pending) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: () => family.accept(link.id),
                                child: const Text('Accepter'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => family.revoke(link.id, asYoung: true),
                                child: const Text('Refuser'),
                              ),
                            ],
                          ),
                        ],
                        if (link.status == GuardianLinkStatus.active) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Autoriser la localisation'),
                            subtitle: const Text(
                              'Le parent voit la dernière position connue, pas un GPS continu, uniquement si ceci est activé.',
                            ),
                            value: link.canViewLocation,
                            onChanged: (value) => family.setLocationPermission(link.id, value),
                          ),
                          const Text(
                            'Ou partager pour une durée limitée (révocable). Ce n’est pas un suivi en direct.',
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final minutes in [15, 60, 480])
                                OutlinedButton(
                                  onPressed: locations.isBusy
                                      ? null
                                      : () => locations.shareWith(
                                            targetUserId: link.guardianUserId,
                                            durationMinutes: minutes,
                                          ),
                                  child: Text(minutes == 60 ? '1 h' : minutes == 480 ? '8 h' : '15 min'),
                                ),
                            ],
                          ),
                          ...locations.shares
                              .where((share) => share.targetUserId == link.guardianUserId && share.isActive)
                              .map(
                                (share) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    share.expiresAt == null
                                        ? 'Partage actif'
                                        : 'Partage jusqu’à ${share.expiresAt!.toLocal().hour.toString().padLeft(2, '0')}:${share.expiresAt!.toLocal().minute.toString().padLeft(2, '0')}',
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => locations.revokeShare(share.id),
                                    child: const Text('Révoquer'),
                                  ),
                                ),
                              ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Autoriser la gestion des zones'),
                            subtitle: const Text(
                              'École, maison, jours et heures. Une sortie de zone est un événement daté, pas un kidnapping.',
                            ),
                            value: link.canManageZones,
                            onChanged: (value) => family.setZonePermission(link.id, value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Autoriser à déclarer une disparition'),
                            subtitle: const Text(
                              'Ouvre un dossier avec un instantané. Ce n’est pas un kidnapping confirmé.',
                            ),
                            value: link.canReportMissing,
                            onChanged: (value) => family.setReportPermission(link.id, value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Autoriser à déclencher un SOS'),
                            subtitle: const Text(
                              'Le proche peut signaler un danger depuis l’application. Ce n’est pas un kidnapping confirmé.',
                            ),
                            value: link.canTriggerAlert,
                            onChanged: (value) => family.setTriggerPermission(link.id, value),
                          ),
                          TextButton(
                            onPressed: () => family.revoke(link.id, asYoung: true),
                            child: const Text('Révoquer ce contact'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
