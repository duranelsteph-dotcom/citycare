import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/search.dart';
import 'location_controller.dart';
import 'location_map.dart';
import 'location_scope.dart';
import 'trip_copy.dart';

/// Historique de déplacements (liste de trajets). Pas un rapport de conduite.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.youngPersonId, this.displayName});

  /// Null = compte jeune (soi). Sinon le jeune regardé (mêmes droits que watch).
  final String? youngPersonId;
  final String? displayName;

  bool get isSelf => youngPersonId == null;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(TripPeriod.today));
  }

  Future<void> _load(TripPeriod period, {DateTime? from, DateTime? to}) async {
    final locations = LocationScope.of(context);
    if (widget.isSelf) {
      await locations.loadMyTrips(period: period, from: from, to: to);
    } else {
      await locations.loadChildTrips(widget.youngPersonId!, period: period, from: from, to: to);
    }
  }

  Future<void> _onChip(TripPeriod period) async {
    if (period == TripPeriod.custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: now.subtract(const Duration(days: 31)),
        lastDate: now,
        helpText: 'Période (31 jours max)',
        cancelText: 'Annuler',
        confirmText: 'Voir',
      );
      if (range == null || !mounted) {
        return;
      }
      final from = DateTime(range.start.year, range.start.month, range.start.day);
      final to = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      await _load(TripPeriod.custom, from: from, to: to);
      return;
    }
    await _load(period);
  }

  @override
  Widget build(BuildContext context) {
    final locations = LocationScope.of(context);
    final title = widget.displayName == null ? 'Historique' : 'Historique · ${widget.displayName}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            key: const Key('history-refresh'),
            tooltip: 'Actualiser',
            onPressed: locations.isBusy
                ? null
                : () => _load(locations.tripPeriod, from: locations.tripFrom, to: locations.tripTo),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: locations,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (locations.isBusy) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CityCareBrand.spaceMd,
                  CityCareBrand.spaceSm,
                  CityCareBrand.spaceMd,
                  0,
                ),
                child: Wrap(
                  key: const Key('history-period-chips'),
                  spacing: CityCareBrand.spaceSm,
                  runSpacing: CityCareBrand.spaceSm,
                  children: [
                    for (final period in TripPeriod.values)
                      FilterChip(
                        key: Key('history-chip-${period.apiValue}'),
                        label: Text(period.chipLabel),
                        selected: locations.tripPeriod == period,
                        onSelected: locations.isBusy ? null : (_) => _onChip(period),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CityCareBrand.spaceMd,
                  CityCareBrand.spaceSm,
                  CityCareBrand.spaceMd,
                  CityCareBrand.spaceSm,
                ),
                child: Text(
                  locations.tripHistory?.disclaimer ??
                      'Trajets reconstruits à partir des positions enregistrées. '
                          'Ce n’est pas un suivi en direct, pas un rapport de conduite '
                          '(vitesse max, distraction).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(child: _body(locations)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(LocationController locations) {
    final error = locations.errorMessage;
    if (error != null && locations.tripHistory == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CityCareBrand.spaceLg),
          child: Text(
            key: const Key('history-forbidden'),
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final trips = locations.tripHistory?.trips ?? const <Trip>[];
    if (!locations.isBusy && trips.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(CityCareBrand.spaceLg),
          child: Text(
            key: Key('history-empty'),
            'Aucun trajet sur cette période. Ce n’est pas un suivi en direct.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('history-trip-list'),
      padding: const EdgeInsets.fromLTRB(
        CityCareBrand.spaceMd,
        0,
        CityCareBrand.spaceMd,
        CityCareBrand.spaceXl,
      ),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: CityCareBrand.spaceSm),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _TripCard(
          trip: trip,
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TripMapPage(
                trip: trip,
                youngPersonId: locations.tripHistory?.youngPersonId ?? widget.youngPersonId ?? '',
                displayName: widget.displayName,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onOpen});

  final Trip trip;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('history-trip-${trip.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TripMiniMap(points: trip.points),
            Padding(
              padding: const EdgeInsets.all(CityCareBrand.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tripDateLabel(trip.startedAt), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(tripWindowLabel(trip), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(tripSubtitle(trip)),
                  const SizedBox(height: 4),
                  Text(
                    'Ouvrir sur la carte — pas un rapport de conduite.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini-carte schématique (polyline). Pas de tuiles, pas un GPS live.
class TripMiniMap extends StatelessWidget {
  const TripMiniMap({super.key, required this.points, this.height = 120});

  final List<TrajectoryPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: CityCareBrand.lavender,
        child: CustomPaint(
          painter: _TripPathPainter(
            points: points,
            color: CityCareBrand.violet,
            dot: CityCareBrand.violetMid,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TripPathPainter extends CustomPainter {
  const _TripPathPainter({required this.points, required this.color, required this.dot});

  final List<TrajectoryPoint> points;
  final Color color;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }
    const pad = 16.0;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    final dLat = (maxLat - minLat).abs() < 1e-6 ? 0.001 : maxLat - minLat;
    final dLng = (maxLng - minLng).abs() < 1e-6 ? 0.001 : maxLng - minLng;
    Offset map(TrajectoryPoint point) {
      final x = pad + (point.longitude - minLng) / dLng * (size.width - 2 * pad);
      final y = pad + (maxLat - point.latitude) / dLat * (size.height - 2 * pad);
      return Offset(x, y);
    }

    final mapped = points.map(map).toList();
    if (mapped.length >= 2) {
      final path = Path()..moveTo(mapped.first.dx, mapped.first.dy);
      for (final offset in mapped.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawCircle(mapped.first, 5, Paint()..color = dot);
    canvas.drawCircle(mapped.last, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TripPathPainter oldDelegate) => oldDelegate.points != points;
}

/// Carte existante (LocationMapView) pour un trajet sélectionné.
class TripMapPage extends StatelessWidget {
  const TripMapPage({
    super.key,
    required this.trip,
    required this.youngPersonId,
    this.displayName,
  });

  final Trip trip;
  final String youngPersonId;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final trajectory = trip.asTrajectory(youngPersonId);
    final last = trip.points.isEmpty ? null : trip.points.last;
    return Scaffold(
      appBar: AppBar(title: Text(displayName == null ? 'Trajet' : 'Trajet · $displayName')),
      body: Column(
        children: [
          Expanded(
            child: LocationMapView(
              latitude: last?.latitude,
              longitude: last?.longitude,
              pathSegments: trajectorySegments(trajectory),
            ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tripDateLabel(trip.startedAt), style: Theme.of(context).textTheme.titleSmall),
                    Text(tripWindowLabel(trip), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(tripSubtitle(trip)),
                    const SizedBox(height: 8),
                    const Text(
                      'Positions enregistrées reliées. Ce n’est pas un suivi en direct, '
                      'pas un rapport de conduite (vitesse max, distraction).',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
