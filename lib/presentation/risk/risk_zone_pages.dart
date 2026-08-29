import 'package:flutter/material.dart';

import '../../domain/entities/zones.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/risk_zone_repository.dart';
import '../auth/auth_scope.dart';
import '../location/location_map.dart';
import 'risk_zone_scope.dart';

String riskHourSummary(RiskZone zone) {
  final start = zone.typicalStartHour;
  final end = zone.typicalEndHour;
  if (start == null && end == null) {
    return 'à toute heure';
  }
  if (start == null || end == null) {
    return 'à toute heure';
  }
  return '${start}h–${end}h';
}

class RiskZonesPage extends StatefulWidget {
  const RiskZonesPage({super.key});

  @override
  State<RiskZonesPage> createState() => _RiskZonesPageState();
}

class _RiskZonesPageState extends State<RiskZonesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RiskZoneScope.of(context).load();
    });
  }

  bool get _canEdit {
    final role = AuthScope.of(context).user?.role;
    return role == UserRole.parent || role == UserRole.authority;
  }

  @override
  Widget build(BuildContext context) {
    final zones = RiskZoneScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Zones à risque')),
      floatingActionButton: _canEdit
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
                        isRisk: true,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  children: [
                    const Text(
                      'Prévention : vous êtes informé à l’entrée. '
                      'Ce n’est pas un kidnapping, ni un SOS. '
                      'Le nombre d’incidents vient des déclarations enregistrées, pas d’un modèle d’IA.',
                    ),
                    if (zones.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(zones.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 12),
                    if (zones.zones.isEmpty) const Text('Aucune zone à risque pour le moment.'),
                    ...zones.zones.map((zone) {
                      return Card(
                        child: ListTile(
                          title: Text(zone.name),
                          subtitle: Text(
                            '${zone.radiusMeters.round()} m · ${riskHourSummary(zone)}'
                            '${zone.isHourActiveNow ? ' · plage en cours' : ''}'
                            ' · ${zone.incidentCount} incident(s)'
                            '${zone.isActive ? '' : ' · inactive'}',
                          ),
                          isThreeLine: true,
                          onTap: _canEdit ? () => _openEditor(context, existing: zone) : null,
                          trailing: _canEdit
                              ? IconButton(
                                  tooltip: 'Enregistrer un incident',
                                  onPressed: () => _recordIncident(context, zone),
                                  icon: const Icon(Icons.report_outlined),
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

  Future<void> _openEditor(BuildContext context, {RiskZone? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RiskZoneEditorPage(existing: existing)),
    );
  }

  Future<void> _recordIncident(BuildContext context, RiskZone zone) async {
    final title = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Incident · ${zone.name}'),
          content: TextField(
            controller: title,
            decoration: const InputDecoration(
              labelText: 'Titre',
              hintText: 'Agression signalée…',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
          ],
        );
      },
    );
    final text = title.text.trim();
    title.dispose();
    if (confirmed != true || text.length < 2 || !context.mounted) {
      return;
    }
    final zones = RiskZoneScope.of(context);
    final ok = await zones.addIncident(zone.id, IncidentDraft(title: text, source: 'déclaration'));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Incident enregistré. Le compteur reflète les déclarations, pas un modèle entraîné.'
              : (zones.errorMessage ?? 'Enregistrement impossible'),
        ),
      ),
    );
  }
}

class RiskZoneEditorPage extends StatefulWidget {
  const RiskZoneEditorPage({super.key, this.existing});

  final RiskZone? existing;

  @override
  State<RiskZoneEditorPage> createState() => _RiskZoneEditorPageState();
}

class _RiskZoneEditorPageState extends State<RiskZoneEditorPage> {
  late final TextEditingController _name;
  late double _radius;
  late bool _limitHours;
  late int _startHour;
  late int _endHour;
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _radius = existing?.radiusMeters ?? 250;
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
    _limitHours = existing?.typicalStartHour != null && existing?.typicalEndHour != null;
    _startHour = existing?.typicalStartHour ?? 18;
    _endHour = existing?.typicalEndHour ?? 23;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Nouvelle zone à risque' : 'Modifier la zone à risque')),
      body: ListView(
        children: [
          SizedBox(
            height: 260,
            child: LocationMapView(
              latitude: _latitude,
              longitude: _longitude,
              circles: [
                if (_latitude != null && _longitude != null)
                  MapCircle(
                    latitude: _latitude!,
                    longitude: _longitude!,
                    radiusMeters: _radius,
                    isRisk: true,
                  ),
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
                const Text(
                  'Touchez la carte pour placer le centre. Le cercle orange est le rayon. '
                  'Une zone à risque n’est pas une zone de sécurité.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Carrefour 18h–23h'),
                      onPressed: () => setState(() {
                        _name.text = 'Carrefour dangereux';
                        _radius = 250;
                        _limitHours = true;
                        _startHour = 18;
                        _endHour = 23;
                      }),
                    ),
                    ActionChip(
                      label: const Text('Toute heure'),
                      onPressed: () => setState(() {
                        _limitHours = false;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nom', hintText: 'Carrefour, marché…'),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Limiter aux heures typiques'),
                  subtitle: const Text('Sinon la zone est considérée à tout moment'),
                  value: _limitHours,
                  onChanged: (value) => setState(() => _limitHours = value),
                ),
                if (_limitHours)
                  Row(
                    children: [
                      Expanded(child: _HourDropdown(label: 'Début', value: _startHour, onChanged: (v) => setState(() => _startHour = v))),
                      const SizedBox(width: 8),
                      Expanded(child: _HourDropdown(label: 'Fin', value: _endHour, onChanged: (v) => setState(() => _endHour = v))),
                    ],
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
    final draft = RiskZoneDraft(
      name: name,
      latitude: _latitude!,
      longitude: _longitude!,
      radiusMeters: _radius,
      typicalStartHour: _limitHours ? _startHour : null,
      typicalEndHour: _limitHours ? _endHour : null,
    );
    setState(() => _saving = true);
    final zones = RiskZoneScope.of(context);
    final ok = widget.existing == null
        ? await zones.create(draft)
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

class _HourDropdown extends StatelessWidget {
  const _HourDropdown({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: [
            for (var hour = 0; hour < 24; hour++)
              DropdownMenuItem(value: hour, child: Text('${hour}h')),
          ],
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ),
    );
  }
}
