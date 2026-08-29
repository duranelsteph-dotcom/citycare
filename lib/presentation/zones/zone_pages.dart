import 'package:flutter/material.dart';

import '../../domain/entities/zones.dart';
import '../../domain/repositories/zone_repository.dart';
import '../location/location_map.dart';
import 'schedule_labels.dart';
import 'zone_scope.dart';

class SafetyZonesPage extends StatefulWidget {
  const SafetyZonesPage({
    super.key,
    this.youngPersonId,
    this.displayName,
    this.canEdit = false,
  });

  final String? youngPersonId;
  final String? displayName;
  final bool canEdit;

  @override
  State<SafetyZonesPage> createState() => _SafetyZonesPageState();
}

class _SafetyZonesPageState extends State<SafetyZonesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
    });
  }

  Future<void> _reload() {
    final zones = ZoneScope.of(context);
    final youngId = widget.youngPersonId;
    if (youngId == null) {
      return zones.loadMine();
    }
    return zones.loadChild(youngId);
  }

  @override
  Widget build(BuildContext context) {
    final zones = ZoneScope.of(context);
    final title = widget.displayName == null ? 'Mes zones de sécurité' : 'Zones · ${widget.displayName}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: widget.canEdit && widget.youngPersonId != null
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une zone'),
            )
          : null,
      body: ListenableBuilder(
        listenable: zones,
        builder: (context, _) {
          return Column(
            children: [
              if (zones.isBusy) const LinearProgressIndicator(),
              SizedBox(
                height: 240,
                child: LocationMapView(
                  circles: [
                    for (final zone in zones.zones)
                      MapCircle(
                        latitude: zone.latitude,
                        longitude: zone.longitude,
                        radiusMeters: zone.radiusMeters,
                        isActive: zone.isActive,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  children: [
                    const Text(
                      'Une zone n’est valable que les jours et heures indiqués. '
                      'Ce n’est pas une alerte de sortie : les notifications arriveront ensuite.',
                    ),
                    if (zones.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(zones.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 12),
                    if (zones.zones.isEmpty) const Text('Aucune zone définie pour le moment.'),
                    ...zones.zones.map((zone) {
                      return Card(
                        child: ListTile(
                          title: Text(zone.name),
                          subtitle: Text(
                            '${zone.radiusMeters.round()} m · ${scheduleSummary(zone)}'
                            '${zone.insideOnLastFix ? ' · Zone de sécurité active — dernière connue, pas actuelle' : ''}'
                            '${zone.scheduleActiveNow && !zone.insideOnLastFix ? ' · plage en cours' : ''}'
                            '${zone.isActive ? '' : ' · inactive'}',
                          ),
                          isThreeLine: true,
                          onTap: widget.canEdit ? () => _openEditor(context, existing: zone) : null,
                          trailing: widget.canEdit
                              ? IconButton(
                                  tooltip: 'Supprimer',
                                  onPressed: () => zones.delete(zone.id),
                                  icon: const Icon(Icons.delete_outline),
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {SafetyZone? existing}) async {
    final youngId = widget.youngPersonId;
    if (youngId == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ZoneEditorPage(youngPersonId: youngId, existing: existing),
      ),
    );
  }
}

class ZoneEditorPage extends StatefulWidget {
  const ZoneEditorPage({super.key, required this.youngPersonId, this.existing});

  final String youngPersonId;
  final SafetyZone? existing;

  @override
  State<ZoneEditorPage> createState() => _ZoneEditorPageState();
}

class _ZoneEditorPageState extends State<ZoneEditorPage> {
  late final TextEditingController _name;
  late double _radius;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final Set<int> _days = {};
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _radius = existing?.radiusMeters ?? 300;
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
    if (existing != null && existing.schedules.isNotEmpty) {
      _start = parseApiTime(existing.schedules.first.startTime);
      _end = parseApiTime(existing.schedules.first.endTime);
      _days.addAll(existing.schedules.map((item) => item.weekday));
    } else {
      _start = const TimeOfDay(hour: 7, minute: 30);
      _end = const TimeOfDay(hour: 17, minute: 0);
      _days.addAll({0, 1, 2, 3, 4});
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _crossesMidnight {
    final start = _start.hour * 60 + _start.minute;
    final end = _end.hour * 60 + _end.minute;
    return end <= start;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Nouvelle zone' : 'Modifier la zone')),
      body: ListView(
        children: [
          SizedBox(
            height: 260,
            child: LocationMapView(
              latitude: _latitude,
              longitude: _longitude,
              circles: [
                if (_latitude != null && _longitude != null)
                  MapCircle(latitude: _latitude!, longitude: _longitude!, radiusMeters: _radius),
              ],
              onTap: (lat, lng) => setState(() {
                _latitude = lat;
                _longitude = lng;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Touchez la carte pour placer le centre. Le cercle vert est le rayon.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('École lun–ven 07:30–17:00'),
                      onPressed: () => setState(() {
                        _name.text = 'École';
                        _radius = 300;
                        _start = const TimeOfDay(hour: 7, minute: 30);
                        _end = const TimeOfDay(hour: 17, minute: 0);
                        _days
                          ..clear()
                          ..addAll({0, 1, 2, 3, 4});
                      }),
                    ),
                    ActionChip(
                      label: const Text('Maison tous les jours 18:00–07:00'),
                      onPressed: () => setState(() {
                        _name.text = 'Maison';
                        _radius = 150;
                        _start = const TimeOfDay(hour: 18, minute: 0);
                        _end = const TimeOfDay(hour: 7, minute: 0);
                        _days
                          ..clear()
                          ..addAll({0, 1, 2, 3, 4, 5, 6});
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nom', hintText: 'École, Maison…'),
                ),
                const SizedBox(height: 12),
                Text('Rayon : ${_radius.round()} m'),
                Slider(
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  value: _radius.clamp(50, 1000),
                  label: '${_radius.round()} m',
                  onChanged: (value) => setState(() => _radius = value),
                ),
                const SizedBox(height: 8),
                const Text('Jours'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var day = 0; day < 7; day++)
                      FilterChip(
                        label: Text(weekdayLabels[day]),
                        selected: _days.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _days.add(day);
                          } else {
                            _days.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: _start);
                          if (picked != null) {
                            setState(() => _start = picked);
                          }
                        },
                        child: Text('Début ${_start.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: _end);
                          if (picked != null) {
                            setState(() => _end = picked);
                          }
                        },
                        child: Text('Fin ${_end.format(context)}'),
                      ),
                    ),
                  ],
                ),
                if (_crossesMidnight)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Cette plage traverse minuit (ex. 18:00 → 07:00).'),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez un nom.')));
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Touchez la carte pour placer la zone.')));
      return;
    }
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez au moins un jour.')));
      return;
    }
    final draft = SafetyZoneDraft(
      name: name,
      latitude: _latitude!,
      longitude: _longitude!,
      radiusMeters: _radius,
      schedules: [
        for (final day in (_days.toList()..sort()))
          ScheduleDraft(weekday: day, startTime: apiTime(_start), endTime: apiTime(_end)),
      ],
    );
    setState(() => _saving = true);
    final zones = ZoneScope.of(context);
    final ok = widget.existing == null
        ? await zones.create(draft, youngPersonId: widget.youngPersonId)
        : await zones.update(widget.existing!.id, draft);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(zones.errorMessage ?? 'Enregistrement impossible')),
      );
    }
  }
}
