import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/search.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import '../auth/role_labels.dart';
import '../risk/risk_zone_scope.dart';
import '../zones/zone_scope.dart';
import 'location_map.dart';
import 'location_permission_gate.dart';
import 'location_scope.dart';

class MyPositionPage extends StatefulWidget {
  const MyPositionPage({super.key});

  @override
  State<MyPositionPage> createState() => _MyPositionPageState();
}

class _MyPositionPageState extends State<MyPositionPage> {
  Timer? _timer;
  bool _followPhone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ZoneScope.of(context).loadMine();
      RiskZoneScope.of(context).load();
      _cycle(first: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cycle({bool first = false}) async {
    final locations = LocationScope.of(context);
    if (!first && _followPhone) {
      await locations.captureAndPublish();
    }
    await locations.watchMine(busy: first);
    if (!mounted) {
      return;
    }
    _timer?.cancel();
    final wait = locations.pollAfterSeconds.clamp(5, 180);
    _timer = Timer(Duration(seconds: wait), () {
      if (mounted) {
        _cycle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = LocationScope.of(context);
    final zones = ZoneScope.of(context);
    final risk = RiskZoneScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma position'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: locations.isBusy ? null : () => _cycle(first: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([locations, zones, risk]),
        builder: (context, _) {
          return Column(
            children: [
              if (locations.isBusy) const LinearProgressIndicator(),
              Expanded(
                child: LocationMapView(
                  latitude: locations.unsyncedFix?.latitude ?? locations.latest?.latitude,
                  longitude: locations.unsyncedFix?.longitude ?? locations.latest?.longitude,
                  accuracyMeters: locations.unsyncedFix?.accuracy ?? locations.latest?.accuracy,
                  isStale: locations.unsyncedFix == null && (locations.latest?.isStale ?? false),
                  isUnsynced: locations.unsyncedFix != null,
                  pathSegments: trajectorySegments(locations.trajectory),
                  circles: [
                    for (final zone in zones.zones)
                      MapCircle(
                        latitude: zone.latitude,
                        longitude: zone.longitude,
                        radiusMeters: zone.radiusMeters,
                        isActive: zone.isActive,
                      ),
                    for (final zone in risk.zones)
                      MapCircle(
                        latitude: zone.latitude,
                        longitude: zone.longitude,
                        radiusMeters: zone.radiusMeters,
                        isActive: zone.isActive,
                        isRisk: true,
                      ),
                  ],
                ),
              ),
              _PositionPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Le parcours d'autorisation est traité ici, au plus près
                    // du bouton qui a besoin du GPS.
                    const LocationPermissionCard(),
                    const Text('Pas un suivi en direct. Une pastille ancienne n’est pas la position actuelle.'),
                    const SizedBox(height: 8),
                    Text(_trajectoryCopy(locations.trajectory)),
                    const SizedBox(height: 8),
                    Text(
                      locations.watchMessage.isEmpty
                          ? 'Rafraîchissement de la dernière position connue — pas un GPS continu.'
                          : locations.watchMessage,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Prochain cycle dans ${locations.pollAfterSeconds} s '
                      '(${trackingModeLabel(locations.effectiveMode)}).',
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Envoyer le GPS du téléphone à chaque cycle'),
                      subtitle: const Text('Uniquement tant que cet écran est ouvert. Pas un suivi en arrière-plan.'),
                      value: _followPhone,
                      onChanged: (value) async {
                        setState(() => _followPhone = value);
                        if (value) {
                          await LocationScope.of(context).captureAndPublish();
                          if (mounted) {
                            await _cycle();
                          }
                        }
                      },
                    ),
                    FilledButton(
                      onPressed: locations.isBusy ? null : locations.captureAndPublish,
                      child: Text(locations.isBusy ? 'Localisation…' : 'Mettre à jour ma position maintenant'),
                    ),
                    if (locations.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(locations.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    if (locations.unsyncedFix != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Position appareil non synchronisée : '
                        '${locations.unsyncedFix!.latitude.toStringAsFixed(5)}, '
                        '${locations.unsyncedFix!.longitude.toStringAsFixed(5)}',
                      ),
                    ],
                    const SizedBox(height: 12),
                    _PositionCard(title: 'Dernière position connue', point: locations.latest),
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

class ChildPositionPage extends StatefulWidget {
  const ChildPositionPage({super.key, required this.youngPersonId, required this.displayName});

  final String youngPersonId;
  final String displayName;

  @override
  State<ChildPositionPage> createState() => _ChildPositionPageState();
}

class _ChildPositionPageState extends State<ChildPositionPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ZoneScope.of(context).loadChild(widget.youngPersonId);
      RiskZoneScope.of(context).load();
      _cycle(first: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cycle({bool first = false}) async {
    final locations = LocationScope.of(context);
    await locations.watchChild(widget.youngPersonId, busy: first);
    if (!mounted || locations.errorMessage != null) {
      return;
    }
    _timer?.cancel();
    final wait = locations.pollAfterSeconds.clamp(5, 180);
    _timer = Timer(Duration(seconds: wait), () {
      if (mounted) {
        _cycle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = LocationScope.of(context);
    final zones = ZoneScope.of(context);
    final risk = RiskZoneScope.of(context);
    final accessLabel = switch (locations.access) {
      'SHARE' => 'Accès par partage limité — révocable, pas un GPS continu.',
      'PERMISSION' => 'Accès par autorisation du jeune — dernière position connue seulement.',
      _ => 'Dernière position connue, pas un suivi en direct.',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('Position · ${widget.displayName}'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: locations.isBusy ? null : () => _cycle(first: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([locations, zones, risk]),
        builder: (context, _) {
          return Column(
            children: [
              if (locations.isBusy) const LinearProgressIndicator(),
              Expanded(
                child: LocationMapView(
                  latitude: locations.latest?.latitude,
                  longitude: locations.latest?.longitude,
                  accuracyMeters: locations.latest?.accuracy,
                  isStale: locations.latest?.isStale ?? false,
                  pathSegments: trajectorySegments(locations.trajectory),
                  circles: [
                    for (final zone in zones.zones)
                      MapCircle(
                        latitude: zone.latitude,
                        longitude: zone.longitude,
                        radiusMeters: zone.radiusMeters,
                        isActive: zone.isActive,
                      ),
                    for (final zone in risk.zones)
                      MapCircle(
                        latitude: zone.latitude,
                        longitude: zone.longitude,
                        radiusMeters: zone.radiusMeters,
                        isActive: zone.isActive,
                        isRisk: true,
                      ),
                  ],
                ),
              ),
              _PositionPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(accessLabel),
                    const SizedBox(height: 8),
                    Text(_trajectoryCopy(locations.trajectory)),
                    const SizedBox(height: 8),
                    Text(
                      'Prochain cycle dans ${locations.pollAfterSeconds} s '
                      '(${trackingModeLabel(locations.effectiveMode)}). '
                      'Une pastille ancienne n’est pas la position actuelle.',
                    ),
                    if (locations.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(locations.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 12),
                    _PositionCard(title: 'Dernière position connue', point: locations.latest),
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

class _PositionPanel extends StatelessWidget {
  const _PositionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: child,
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.title, required this.point});

  final String title;
  final TrackerLocation? point;

  @override
  Widget build(BuildContext context) {
    if (point == null) {
      return Text('$title : aucune.');
    }
    final age = Duration(seconds: point!.ageSeconds);
    final label = point!.isStale
        ? 'Ancienne (il y a ${age.inMinutes} min) — pas la position actuelle'
        : 'Récente (il y a ${age.inSeconds} s)';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('Latitude : ${point!.latitude.toStringAsFixed(6)}'),
            Text('Longitude : ${point!.longitude.toStringAsFixed(6)}'),
            if (point!.accuracy != null) Text('Précision : ${point!.accuracy!.toStringAsFixed(0)} m'),
            Text('Source : ${point!.source == LocationSource.phone ? 'Téléphone' : 'Kit IoT'}'),
            Text('Horodatage : ${point!.recordedAt.toLocal()}'),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: point!.isStale ? Theme.of(context).colorScheme.error : null)),
          ],
        ),
      ),
    );
  }
}

String _trajectoryCopy(Trajectory? trajectory) {
  if (trajectory == null || trajectory.pointCount == 0) {
    return 'Aucune trajectoire enregistrée. Ce n’est pas un suivi en direct.';
  }
  final gaps = trajectory.gapCount == 0
      ? 'Sans trou de communication visible.'
      : '${trajectory.gapCount} trou(s) de communication — le trait n’est pas interpolé.';
  return '${trajectory.pointCount} positions reliées (${trajectory.distanceMeters.toStringAsFixed(0)} m). '
      '$gaps Ce n’est pas une zone de recherche. ${trajectory.disclaimer}';
}
