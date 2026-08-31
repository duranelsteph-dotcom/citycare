import 'package:flutter/material.dart';

import '../../domain/enums/citycare_enums.dart';
import '../alerts/alert_scope.dart';
import '../auth/role_labels.dart';
import '../cases/case_pages.dart';
import '../location/emergency_page.dart';
import '../location/history_page.dart';
import '../location/location_scope.dart';
import '../location/position_pages.dart';
import '../map/care_status.dart';
import '../notifications/notification_scope.dart';
import '../trackers/kit_copy.dart';
import '../trackers/kit_page.dart';
import '../trackers/tracker_scope.dart';
import '../zones/zone_pages.dart';
import 'family_scope.dart';
import 'link_child_page.dart';

class ChildrenPage extends StatefulWidget {
  const ChildrenPage({super.key});

  @override
  State<ChildrenPage> createState() => _ChildrenPageState();
}

class _ChildrenPageState extends State<ChildrenPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FamilyScope.of(context).loadForGuardian();
      if (!mounted) {
        return;
      }
      await LocationScope.of(context).loadReceivedShares();
      if (!mounted) {
        return;
      }
      final ids = FamilyScope.of(context).active.map((link) => link.youngPersonId).toList();
      await TrackerScope.of(context).loadSummaries(ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = FamilyScope.of(context);
    final kits = TrackerScope.of(context);
    final locations = LocationScope.of(context);
    final alerts = AlertScope.maybeOf(context);
    final inbox = NotificationScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes enfants / jeunes')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'children-link',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LinkChildPage())),
        icon: const Icon(Icons.link),
        label: const Text('Rattacher'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          family,
          kits,
          locations,
          if (alerts != null) alerts,
          if (inbox != null) inbox,
        ]),
        builder: (context, _) {
          if (family.isLoading && family.links.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (family.links.isEmpty) {
            return const Center(child: Text('Aucun jeune rattaché. Utilisez un code ou une invitation.'));
          }
          return ListView(
            children: family.links.map((link) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(link.youngDisplayName ?? 'Jeune', style: Theme.of(context).textTheme.titleMedium),
                      if (link.status == GuardianLinkStatus.active) ...[
                        const SizedBox(height: 6),
                        CareStatusBadge(
                          status: careStatusForMember(
                            point: locations.familyLatest[link.youngPersonId],
                            youngPersonId: link.youngPersonId,
                            alerts: alerts?.items ?? const [],
                            inbox: inbox?.items ?? const [],
                          ),
                          compact: false,
                          showDisclaimer: true,
                        ),
                      ],
                      Text(
                        '${link.youngPhone ?? ''} · ${linkStatusLabel(link.status)}'
                        '${link.status == GuardianLinkStatus.active && !link.canViewLocation ? ' · localisation non autorisée' : ''}',
                      ),
                      if (link.status == GuardianLinkStatus.active) ...[
                        const Text(
                          'Dernière position et kit connus — pas un suivi en direct, pas un kidnapping confirmé.',
                        ),
                        if (kits.summaries[link.youngPersonId] != null)
                          Text(childKitLine(kits.summaries[link.youngPersonId]!)),
                        if (locations.receivedShareFor(link.youngPersonId) != null)
                          Text(
                            'Partage limité jusqu’à ${knownClock(locations.receivedShareFor(link.youngPersonId)!.expiresAt)} — '
                            'dernière position connue, pas un GPS continu.',
                          ),
                      ],
                      if (link.status == GuardianLinkStatus.active) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChildPositionPage(
                                    youngPersonId: link.youngPersonId,
                                    displayName: link.youngDisplayName ?? 'Jeune',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Position'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChildPositionPage(
                                    youngPersonId: link.youngPersonId,
                                    displayName: link.youngDisplayName ?? 'Jeune',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.timeline),
                              label: const Text('Trajectoire'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => HistoryPage(
                                    youngPersonId: link.youngPersonId,
                                    displayName: link.youngDisplayName ?? 'Jeune',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.history),
                              label: const Text('Historique'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EmergencyModePage(
                                    youngPersonId: link.youngPersonId,
                                    displayName: link.youngDisplayName ?? 'Jeune',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.warning_amber),
                              label: const Text('Urgence'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => KitPage(
                                    youngPersonId: link.youngPersonId,
                                    displayName: link.youngDisplayName ?? 'Jeune',
                                    canManage: link.canManageTracker,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.watch),
                              label: const Text('Kit'),
                            ),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SafetyZonesPage(
                                    youngPersonId: link.youngPersonId,
                                    displayName: link.youngDisplayName ?? 'Jeune',
                                    canEdit: link.canManageZones,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.shield_outlined),
                              label: const Text('Zones de sécurité'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => const CasesPage()),
                              ),
                              icon: const Icon(Icons.analytics_outlined),
                              label: const Text('Recherche'),
                            ),
                            if (link.canReportMissing)
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CaseCreatePage(
                                      youngPersonId: link.youngPersonId,
                                      linkedDisplayName: link.youngDisplayName ?? 'Jeune',
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.person_search),
                                label: const Text('Disparition'),
                              ),
                            TextButton.icon(
                              onPressed: () => family.revoke(link.id, asYoung: false),
                              icon: const Icon(Icons.link_off),
                              label: const Text('Retirer'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
