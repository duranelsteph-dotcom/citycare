import 'package:flutter/material.dart';

import '../../domain/enums/citycare_enums.dart';
import '../auth/role_labels.dart';
import '../cases/case_pages.dart';
import '../trackers/kit_copy.dart';
import '../location/location_map.dart';
import '../location/location_scope.dart';

class EmergencyModePage extends StatefulWidget {
  const EmergencyModePage({super.key, required this.youngPersonId, required this.displayName});

  final String youngPersonId;
  final String displayName;

  @override
  State<EmergencyModePage> createState() => _EmergencyModePageState();
}

class _EmergencyModePageState extends State<EmergencyModePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationScope.of(context).loadEmergency(widget.youngPersonId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = LocationScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('MODE URGENCE')),
      body: ListenableBuilder(
        listenable: locations,
        builder: (context, _) {
          if (locations.isBusy && locations.emergency?.youngPersonId != widget.youngPersonId) {
            return const Center(child: CircularProgressIndicator());
          }
          final snap = locations.emergency?.youngPersonId == widget.youngPersonId ? locations.emergency : null;
          if (snap == null) {
            return Center(child: Text(locations.errorMessage ?? 'Mode urgence indisponible'));
          }
          final last = snap.lastKnown;
          return ListView(
            children: [
              SizedBox(
                height: 260,
                child: LocationMapView(
                  latitude: last?.latitude,
                  longitude: last?.longitude,
                  accuracyMeters: last?.accuracy,
                  isStale: true,
                  pathSegments: trajectorySegments(snap.trajectory),
                  circles: [
                    for (final zone in snap.searchZones)
                      MapCircle(
                        latitude: zone.centerLatitude,
                        longitude: zone.centerLongitude,
                        radiusMeters: zone.radiusMeters,
                        isEstimate: zone.isProbable,
                        isPriority: zone.isPriority,
                        isHighPriority: zone.priority == SearchPriority.high,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enfant : ${snap.displayName}', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(snap.disclaimer),
                    const SizedBox(height: 12),
                    Text('Dernière communication : ${snap.lastCommunicationAt == null ? 'inconnue' : knownClock(snap.lastCommunicationAt)}'),
                    Text('Batterie kit (dernière info) : ${snap.batteryLevel == null ? 'inconnue' : '${snap.batteryLevel} %'}'),
                    Text('État du kit : ${snap.kitStatus ?? 'aucun kit'}'),
                    if (snap.kitStatus == 'SIGNAL_LOST')
                      const Text(
                        'Connexion avec le kit perdue. Dernière position connue — pas actuelle, pas un suivi en direct.',
                      ),
                    if (snap.kitStatus == 'REMOVED')
                      const Text(
                        'Le kit a signalé un retrait. Dernière communication connue — pas un suivi en direct.',
                      ),
                    if (snap.kitEvents.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Traces kit — historique daté, pas un suivi en direct'),
                      for (final event in snap.kitEvents) Text(kitEventLine(event)),
                    ],
                    Text('Mode conseillé : ${trackingModeLabel(snap.effectiveMode)} — pas un GPS continu'),
                    if (snap.openSos != null) Text('SOS ouvert (${alertSourceLabel(snap.openSos!.source)})'),
                    Text('Témoignages : ${snap.testimonyCount}'),
                    if (locations.errorMessage != null)
                      Text(locations.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                    if (snap.openCaseId != null)
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => CaseDetailPage(caseId: snap.openCaseId!)),
                        ),
                        child: const Text('Ouvrir le dossier'),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
