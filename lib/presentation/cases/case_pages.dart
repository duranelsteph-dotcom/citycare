import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../../core/config/api_config.dart';
import '../../domain/entities/search.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/case_repository.dart';
import '../auth/auth_modal_scaffold.dart';
import '../auth/auth_scope.dart';
import '../auth/role_labels.dart';
import '../family/family_controller.dart';
import '../family/family_scope.dart';
import '../location/emergency_page.dart';
import '../location/location_map.dart';
import '../map/member_sheet.dart';
import 'case_scope.dart';

/// Ouvre la création d’avis (proche / parent). Sans jeune rattaché : sujet libre.
Future<void> startMissingPersonDeclaration(BuildContext context) async {
  final family = FamilyScope.of(context);
  await family.loadForGuardian();
  if (!context.mounted) {
    return;
  }
  await _startDeclaration(context, family);
}

Future<void> _startDeclaration(BuildContext context, FamilyController family) async {
  final eligible = family.active.where((link) => link.canReportMissing).toList();
  String? youngPersonId;
  String? linkedName;
  if (eligible.length == 1) {
    youngPersonId = eligible.first.youngPersonId;
    linkedName = eligible.first.youngDisplayName;
  } else if (eligible.length > 1) {
    final selected = await showModalBottomSheet<_YoungChoice>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Pour qui déposez l’avis ?')),
              ...eligible.map(
                (link) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(link.youngDisplayName ?? 'Jeune'),
                  onTap: () => Navigator.pop(
                    context,
                    _YoungChoice(youngPersonId: link.youngPersonId, displayName: link.youngDisplayName),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Autre personne (sans compte jeune)'),
                onTap: () => Navigator.pop(context, const _YoungChoice()),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !context.mounted) {
      return;
    }
    youngPersonId = selected.youngPersonId;
    linkedName = selected.displayName;
  }
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CaseCreatePage(
        youngPersonId: youngPersonId,
        linkedDisplayName: linkedName,
      ),
    ),
  );
}

class _YoungChoice {
  const _YoungChoice({this.youngPersonId, this.displayName});

  final String? youngPersonId;
  final String? displayName;
}

class CasesPage extends StatefulWidget {
  const CasesPage({super.key, this.title});

  final String? title;

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final role = AuthScope.of(context).user?.role;
      if (role == UserRole.young) {
        CaseScope.of(context).loadMineAsYoung();
      } else {
        if (role != UserRole.authority) {
          FamilyScope.of(context).loadForGuardian();
        }
        CaseScope.of(context).loadMineAsGuardian();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    final family = FamilyScope.of(context);
    final role = AuthScope.of(context).user?.role;
    final isYoung = role == UserRole.young;
    final canDeclare = role == UserRole.parent || role == UserRole.relative;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Dossiers de disparition')),
      floatingActionButton: canDeclare
          ? FloatingActionButton.extended(
              key: const Key('cases-declare'),
              onPressed: () => _startDeclaration(context, family),
              icon: const Icon(Icons.person_search),
              label: const Text('Déclarer'),
            )
          : null,
      body: ListenableBuilder(
        listenable: Listenable.merge([cases, family]),
        builder: (context, _) {
          if (cases.isBusy && cases.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cases.errorMessage != null && cases.items.isEmpty) {
            return Center(child: Text(cases.errorMessage!));
          }
          if (cases.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  isYoung
                      ? 'Aucun dossier ne vous concerne pour le moment. Un dossier n’est pas un kidnapping confirmé.'
                      : 'Aucun dossier. Déclarer une disparition n’est pas un kidnapping confirmé, et n’ouvre pas un suivi en direct.',
                ),
              ],
            );
          }
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Ce n’est pas un kidnapping confirmé. Instantané des faits connus, pas une zone de recherche.'),
              ),
              ...cases.items.map((item) {
                return ListTile(
                  leading: Icon(
                    Icons.person_search,
                    color: item.isOpen ? Theme.of(context).colorScheme.error : null,
                  ),
                  title: Text(item.displayName),
                  subtitle: Text('${caseStatusLabel(item.status)} · ${item.occurredAt.toLocal()}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => CaseDetailPage(caseId: item.id)),
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

class CaseCreatePage extends StatefulWidget {
  const CaseCreatePage({
    super.key,
    this.youngPersonId,
    this.linkedDisplayName,
  });

  final String? youngPersonId;
  final String? linkedDisplayName;

  @override
  State<CaseCreatePage> createState() => _CaseCreatePageState();
}

class _CaseCreatePageState extends State<CaseCreatePage> {
  final _subjectName = TextEditingController();
  final _subjectAge = TextEditingController();
  final _distinctiveSigns = TextEditingController();
  final _lastKnownAddress = TextEditingController();
  final _circumstances = TextEditingController();
  final _description = TextEditingController();
  String? _subjectSex;
  String? _photoPath;
  double? _latitude;
  double? _longitude;

  bool get _linkedYoung => widget.youngPersonId != null && widget.youngPersonId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_linkedYoung && widget.linkedDisplayName != null) {
      _subjectName.text = widget.linkedDisplayName!;
    }
  }

  @override
  void dispose() {
    _subjectName.dispose();
    _subjectAge.dispose();
    _distinctiveSigns.dispose();
    _lastKnownAddress.dispose();
    _circumstances.dispose();
    _description.dispose();
    super.dispose();
  }

  InputDecoration _field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: CityCareBrand.fieldFill,
      border: const OutlineInputBorder(borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: CityCareBrand.borderRadiusSm,
        borderSide: const BorderSide(color: CityCareBrand.tileBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: CityCareBrand.borderRadiusSm,
        borderSide: const BorderSide(color: CityCareBrand.violet, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    return Theme(
      data: CityCareTheme.light(),
      child: AuthModalScaffold(
        body: ListenableBuilder(
          listenable: cases,
          builder: (context, _) {
            return ListView(
              key: const Key('case-create-form'),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              children: [
                const Text(
                  'Nouvel avis de recherche',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: CityCareBrand.titleInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _linkedYoung
                      ? 'Dossier pour ${widget.linkedDisplayName ?? 'le jeune rattaché'}. '
                          'Ce n’est pas un kidnapping confirmé.'
                      : 'Décrivez la personne disparue. Le backend crée une fiche sujet si aucun jeune n’est rattaché. '
                          'Ce n’est pas un kidnapping confirmé.',
                  style: const TextStyle(color: CityCareBrand.mutedText, height: 1.4),
                ),
                if (cases.isBusy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (cases.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(cases.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                if (!_linkedYoung)
                  TextField(
                    key: const Key('case-subject-name'),
                    controller: _subjectName,
                    decoration: _field('Nom de la personne *', hint: 'Prénom et nom'),
                    style: const TextStyle(color: CityCareBrand.titleInk),
                  ),
                if (!_linkedYoung) const SizedBox(height: 12),
                TextField(
                  key: const Key('case-subject-age'),
                  controller: _subjectAge,
                  decoration: _field('Âge approximatif', hint: 'Ex. 14 ans'),
                  style: const TextStyle(color: CityCareBrand.titleInk),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('case-subject-sex'),
                  initialValue: _subjectSex,
                  decoration: _field('Sexe'),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: CityCareBrand.titleInk),
                  items: const [
                    DropdownMenuItem(value: 'F', child: Text('Féminin')),
                    DropdownMenuItem(value: 'M', child: Text('Masculin')),
                    DropdownMenuItem(value: 'Autre', child: Text('Autre / non précisé')),
                  ],
                  onChanged: cases.isBusy ? null : (value) => setState(() => _subjectSex = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('case-distinctive-signs'),
                  controller: _distinctiveSigns,
                  decoration: _field('Signes distinctifs', hint: 'Cicatrice, vêtements, accessoires…'),
                  maxLines: 2,
                  style: const TextStyle(color: CityCareBrand.titleInk),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, color: CityCareBrand.titleInk),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('case-pick-photo'),
                  onPressed: cases.isBusy ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_photoPath == null ? 'Ajouter une photo' : 'Changer la photo'),
                ),
                if (_photoPath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: CityCareBrand.borderRadiusSm,
                    child: Image.file(
                      File(_photoPath!),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Dernière localisation connue',
                  style: TextStyle(fontWeight: FontWeight.w600, color: CityCareBrand.titleInk),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Touchez la carte pour placer le lieu. Pas la position actuelle, pas un suivi en direct.',
                  style: TextStyle(color: CityCareBrand.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: LocationMapView(
                    latitude: _latitude,
                    longitude: _longitude,
                    isStale: true,
                    onTap: (lat, lng) => setState(() {
                      _latitude = lat;
                      _longitude = lng;
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _latitude == null
                      ? 'Aucun point sur la carte.'
                      : 'Coordonnées : ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(color: CityCareBrand.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('case-last-address'),
                  controller: _lastKnownAddress,
                  decoration: _field('Adresse ou lieu (texte)', hint: 'Quartier, école, carrefour…'),
                  maxLines: 2,
                  style: const TextStyle(color: CityCareBrand.titleInk),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('case-circumstances'),
                  controller: _circumstances,
                  decoration: _field('Circonstances', hint: 'Dernières nouvelles, contexte…'),
                  maxLines: 3,
                  style: const TextStyle(color: CityCareBrand.titleInk),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('case-description'),
                  controller: _description,
                  decoration: _field('Description complémentaire'),
                  maxLines: 3,
                  style: const TextStyle(color: CityCareBrand.titleInk),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('case-submit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: CityCareBrand.sos,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: cases.isBusy ? null : () => _confirmAndCreate(context),
                  child: Text(cases.isBusy ? 'Envoi…' : 'Déposer l’avis de recherche'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galerie'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Appareil photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) {
      return;
    }
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _photoPath = picked.path);
  }

  Future<void> _confirmAndCreate(BuildContext context) async {
    final name = _subjectName.text.trim();
    if (!_linkedYoung && name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez le nom de la personne disparue.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Déposer l’avis ?'),
          content: const Text(
            'Un instantané des faits connus sera enregistré et transmis aux autorités actives. '
            'Ce n’est pas un kidnapping confirmé.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Déposer')),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final ok = await CaseScope.of(context).create(
      CaseDraft(
        youngPersonId: widget.youngPersonId,
        subjectName: _linkedYoung ? null : name,
        subjectAgeApprox: _subjectAge.text.trim().isEmpty ? null : _subjectAge.text.trim(),
        subjectSex: _subjectSex,
        distinctiveSigns: _distinctiveSigns.text.trim().isEmpty ? null : _distinctiveSigns.text.trim(),
        lastKnownLatitude: _latitude,
        lastKnownLongitude: _longitude,
        lastKnownAddress: _lastKnownAddress.text.trim().isEmpty ? null : _lastKnownAddress.text.trim(),
        circumstances: _circumstances.text.trim().isEmpty ? null : _circumstances.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      ),
      photoPath: _photoPath,
    );
    if (!ok || !context.mounted) {
      return;
    }
    final created = CaseScope.of(context).current;
    if (created == null) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => CaseDetailPage(caseId: created.id)),
    );
  }
}

class CaseDetailPage extends StatefulWidget {
  const CaseDetailPage({super.key, required this.caseId});

  final String caseId;

  @override
  State<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends State<CaseDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isYoung = AuthScope.of(context).user?.role == UserRole.young;
      if (!isYoung) {
        FamilyScope.of(context).loadForGuardian();
      }
      CaseScope.of(context).loadOne(widget.caseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    final role = AuthScope.of(context).user?.role;
    final isYoung = role == UserRole.young;
    final isAuthority = role == UserRole.authority;
    final family = FamilyScope.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Fiche disparition')),
      body: ListenableBuilder(
        listenable: Listenable.merge([cases, family]),
        builder: (context, _) {
          if (cases.isBusy && cases.current?.id != widget.caseId) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = cases.current?.id == widget.caseId ? cases.current : null;
          if (item == null) {
            return Center(child: Text(cases.errorMessage ?? 'Dossier introuvable'));
          }
          final canSubmit = !isYoung &&
              !isAuthority &&
              item.isOpen &&
              family.active.any((link) => link.youngPersonId == item.youngPersonId);
          final canModerate = !isYoung &&
              !isAuthority &&
              family.active.any(
                (link) => link.youngPersonId == item.youngPersonId && link.canReportMissing,
              );
          final photoUrl = ApiConfig.resolveMediaUrl(item.photoUrl);
          return ListView(
            children: [
              if (photoUrl != null)
                Image.network(
                  photoUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _CasePhotoPlaceholder(name: item.displayName),
                )
              else
                _CasePhotoPlaceholder(name: item.displayName),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _CaseStatusTrack(status: item.status),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _CaseTimelineCard(events: cases.timeline),
              ),
              SizedBox(
                height: 220,
                child: LocationMapView(
                  latitude: item.lastKnownLatitude,
                  longitude: item.lastKnownLongitude,
                  isStale: true,
                  pathSegments: trajectorySegments(cases.trajectory),
                  circles: [
                    if (cases.probableZone != null)
                      MapCircle(
                        latitude: cases.probableZone!.centerLatitude,
                        longitude: cases.probableZone!.centerLongitude,
                        radiusMeters: cases.probableZone!.radiusMeters,
                        isEstimate: true,
                      ),
                    for (final zone in cases.priorityZones)
                      MapCircle(
                        latitude: zone.centerLatitude,
                        longitude: zone.centerLongitude,
                        radiusMeters: zone.radiusMeters,
                        isPriority: true,
                        isHighPriority: zone.priority == SearchPriority.high,
                      ),
                  ],
                  pins: [
                    for (final note in cases.testimonies)
                      MapPin(
                        latitude: note.latitude,
                        longitude: note.longitude,
                        isTestimony: true,
                      ),
                  ],
                ),
              ),
              if (cases.probableZone != null || cases.priorityZones.isNotEmpty || cases.testimonies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    [
                      if (cases.probableZone != null)
                        'Cercle bleu : zone de recherche estimée — pas la position actuelle.',
                      if (cases.priorityZones.isNotEmpty)
                        'Cercles violets : priorités de recherche — classement par règles, pas un kidnapping confirmé.',
                      if (cases.testimonies.isNotEmpty)
                        'Épingles teal : témoignages — cohérence estimée, pas une preuve, pas la position actuelle.',
                    ].join(' '),
                    style: const TextStyle(color: CityCareBrand.mutedText, fontSize: 13),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _CaseFacts(
                  item: item,
                  isYoung: isYoung,
                  isAuthority: isAuthority,
                  canSubmitTestimony: canSubmit,
                  canModerateTestimony: canModerate,
                ),
              ),
              if (!isYoung && !isAuthority)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EmergencyModePage(
                          youngPersonId: item.youngPersonId,
                          displayName: item.displayName,
                        ),
                      ),
                    ),
                    child: const Text('Ouvrir le MODE URGENCE'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CasePhotoPlaceholder extends StatelessWidget {
  const _CasePhotoPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: CityCareBrand.lavender,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            foregroundColor: CityCareBrand.violet,
            child: Text(memberInitials(name), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: CityCareBrand.titleInk, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Fil d’Ariane des statuts ouverts : Déposé → Pris en charge → Recherches → Infos → Clos.
class _CaseStatusTrack extends StatelessWidget {
  const _CaseStatusTrack({required this.status});

  final CaseStatus status;

  static const _flow = [
    CaseStatus.open,
    CaseStatus.acknowledged,
    CaseStatus.searching,
    CaseStatus.info,
    CaseStatus.closed,
  ];

  int _index(CaseStatus value) {
    if (value == CaseStatus.found) {
      return _flow.indexOf(CaseStatus.closed);
    }
    final idx = _flow.indexOf(value);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final current = _index(status);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _flow.length; i++)
          Chip(
            label: Text(caseStatusLabel(_flow[i])),
            backgroundColor: i <= current ? CityCareBrand.lavender : CityCareBrand.fieldFill,
            labelStyle: TextStyle(
              color: i == current ? CityCareBrand.violet : CityCareBrand.mutedText,
              fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            side: BorderSide(color: i == current ? CityCareBrand.violet : CityCareBrand.tileBorder),
          ),
      ],
    );
  }
}

class _CaseTimelineCard extends StatelessWidget {
  const _CaseTimelineCard({required this.events});

  final List<CaseEvent> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chronologie', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Évolution du dossier. Ce n’est pas un kidnapping confirmé.',
              style: TextStyle(color: CityCareBrand.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Text('Aucun événement enregistré.')
            else
              for (final event in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.timeline, size: 18, color: CityCareBrand.violet),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.label,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: CityCareBrand.titleInk),
                            ),
                            Text(
                              '${caseStatusLabel(event.status)} · ${event.createdAt.toLocal()}'
                              '${event.actorName == null ? '' : ' · ${event.actorName}'}',
                              style: const TextStyle(color: CityCareBrand.mutedText, fontSize: 12),
                            ),
                          ],
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

class _CaseFacts extends StatelessWidget {
  const _CaseFacts({
    required this.item,
    required this.isYoung,
    required this.isAuthority,
    required this.canSubmitTestimony,
    required this.canModerateTestimony,
  });

  final MissingPersonCase item;
  final bool isYoung;
  final bool isAuthority;
  final bool canSubmitTestimony;
  final bool canModerateTestimony;

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    final snapshot = item.snapshot ?? const <String, dynamic>{};
    final lastKnown = snapshot['last_known'];
    final recent = snapshot['recent_points'];
    final kits = snapshot['kits'];
    final exits = snapshot['geofence_exits'];
    final kitEvents = snapshot['kit_events'];
    final sos = snapshot['open_sos'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Statut : ${caseStatusLabel(item.status)}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Concerné : ${item.displayName}'),
        if (item.subjectAgeApprox != null && item.subjectAgeApprox!.isNotEmpty)
          Text('Âge approx. : ${item.subjectAgeApprox}'),
        if (item.subjectSex != null && item.subjectSex!.isNotEmpty) Text('Sexe : ${item.subjectSex}'),
        if (item.distinctiveSigns != null && item.distinctiveSigns!.isNotEmpty)
          Text('Signes distinctifs : ${item.distinctiveSigns}'),
        if (item.reporterName != null) Text('Déclaré par : ${item.reporterName}'),
        Text('Déclaré le ${item.occurredAt.toLocal()}'),
        if (item.lastKnownAddress != null && item.lastKnownAddress!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Dernière adresse : ${item.lastKnownAddress}'),
        ],
        const SizedBox(height: 8),
        Text(
          item.lastKnownLatitude == null
              ? 'Aucune dernière position connue au moment de la déclaration.'
              : 'Dernière position connue au moment de la déclaration — pas la position actuelle, pas un suivi en direct.',
        ),
        const SizedBox(height: 8),
        Text(snapshot['disclaimer'] as String? ?? 'Ce n’est pas un kidnapping confirmé.'),
        const SizedBox(height: 16),
        if (isAuthority && item.isOpen) ...[
          if (item.status == CaseStatus.open)
            FilledButton(
              key: const Key('case-acknowledge'),
              onPressed: cases.isBusy ? null : () => cases.acknowledge(item.id),
              child: const Text('Prendre en charge'),
            ),
          if (item.status == CaseStatus.open) const SizedBox(height: 8),
          if (item.status == CaseStatus.open || item.status == CaseStatus.acknowledged)
            FilledButton(
              onPressed: cases.isBusy ? null : () => cases.startSearch(item.id),
              child: const Text('Lancer les recherches'),
            ),
          if (item.status == CaseStatus.open || item.status == CaseStatus.acknowledged) const SizedBox(height: 8),
          if (item.status == CaseStatus.searching)
            OutlinedButton(
              onPressed: cases.isBusy ? null : () => cases.markInfo(item.id),
              child: const Text('Marquer « Infos »'),
            ),
          if (item.status == CaseStatus.searching) const SizedBox(height: 8),
          OutlinedButton(
            onPressed: cases.isBusy ? null : () => cases.close(item.id),
            child: const Text('Clore le dossier'),
          ),
          const SizedBox(height: 16),
        ],
        if (!isYoung && !isAuthority && item.status == CaseStatus.open) ...[
          FilledButton(
            onPressed: cases.isBusy ? null : () => cases.startSearch(item.id),
            child: const Text('Démarrer la recherche'),
          ),
          const SizedBox(height: 8),
          const Text('Lancer une recherche n’est pas un kidnapping confirmé.'),
          const SizedBox(height: 16),
        ],
        if (isYoung && item.isOpen)
          FilledButton(
            onPressed: cases.isBusy ? null : () => cases.markFound(item.id),
            child: const Text('Je suis en sécurité'),
          ),
        if (!isYoung && !isAuthority && item.isOpen) ...[
          FilledButton(
            onPressed: cases.isBusy ? null : () => cases.markFound(item.id),
            child: const Text('Marquer comme retrouvé'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: cases.isBusy ? null : () => cases.close(item.id),
            child: const Text('Clôturer le dossier'),
          ),
          const SizedBox(height: 16),
        ],
        if (item.circumstances != null && item.circumstances!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Circonstances : ${item.circumstances}'),
        ],
        if (item.clothing != null && item.clothing!.isNotEmpty) Text('Vêtements : ${item.clothing}'),
        if (item.lastSeenBy != null && item.lastSeenBy!.isNotEmpty) Text('Vu par : ${item.lastSeenBy}'),
        if (item.description != null && item.description!.isNotEmpty) Text(item.description!),
        const SizedBox(height: 12),
        if (cases.trajectory != null && cases.trajectory!.pointCount > 0) ...[
          Text(
            '${cases.trajectory!.pointCount} positions reliées (${cases.trajectory!.distanceMeters.toStringAsFixed(0)} m). '
            '${cases.trajectory!.gapCount == 0 ? 'Sans trou visible.' : '${cases.trajectory!.gapCount} trou(s) de communication — pas interpolé.'}',
          ),
          Text(cases.trajectory!.disclaimer),
        ] else if (recent is List)
          Text(
            '${recent.length} dernière(s) position(s) enregistrée(s) — pas une trajectoire analysée.',
          ),
        if (lastKnown is Map && lastKnown['recorded_at'] != null)
          Text('Horodatage de la dernière position : ${lastKnown['recorded_at']}'),
        if (kits is List && kits.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Kits au moment de la déclaration'),
          ...kits.whereType<Map>().map((kit) {
            return Text(
              '${kit['label'] ?? 'Kit'} · ${kit['status'] ?? ''} · batterie ${kit['battery_level'] ?? 'n/c'}',
            );
          }),
        ],
        if (exits is List && exits.isNotEmpty)
          Text('${exits.length} sortie(s) de zone enregistrée(s) — ce n’est pas un kidnapping.'),
        if (kitEvents is List && kitEvents.isNotEmpty)
          Text('${kitEvents.length} événement(s) kit (signal, retrait, batterie).'),
        if (sos is Map)
          Text('SOS ouvert au moment de la déclaration (${sos['source'] ?? ''}) — pas un kidnapping confirmé.'),
        const SizedBox(height: 16),
        _IntelligenceCard(isYoung: isYoung),
        const SizedBox(height: 16),
        const _ProbableZoneCard(),
        const SizedBox(height: 16),
        const _PriorityZonesCard(),
        const SizedBox(height: 16),
        _TestimoniesCard(
          caseId: item.id,
          isOpen: item.isOpen,
          canSubmit: canSubmitTestimony,
          canModerate: canModerateTestimony,
        ),
        const SizedBox(height: 16),
        const _AiAnalysisCard(),
        if (cases.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(cases.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

class _IntelligenceCard extends StatelessWidget {
  const _IntelligenceCard({required this.isYoung});

  final bool isYoung;

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    final analysis = cases.intelligence;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Search Intelligence — aide à la décision', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Aide à la décision par règles. Aucun modèle ML. Ce n’est pas un kidnapping confirmé.'),
            const SizedBox(height: 8),
            if (analysis == null)
              const Text('Aucune analyse pour le moment.')
            else ...[
              Text('Niveau : ${riskLevelLabel(analysis.riskLevel)} (score ${analysis.score}, ${analysis.method}).'),
              const SizedBox(height: 8),
              Text(analysis.disclaimer),
              const SizedBox(height: 8),
              Text(analysis.explanation),
              if (analysis.contributors.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Facteurs pris en compte'),
                ...analysis.contributors.map((item) => Text('• ${item['label'] ?? item['code']}')),
              ],
              if (analysis.crudeRangeMeters != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ordre de grandeur si le déplacement avait continué : '
                  '${analysis.crudeRangeMeters!.toStringAsFixed(0)} m. Sert à estimer un cercle, pas la position réelle.',
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  analysis.hasSearchZone
                      ? 'Une zone de recherche estimée et, le cas échéant, des priorités sont affichées sur la carte. Ce n’est pas la position actuelle.'
                      : 'Aucune zone de recherche n’a été dessinée sur la carte.',
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: cases.isBusy || cases.current == null
                  ? null
                  : () => cases.refreshIntelligence(cases.current!.id),
              child: Text(isYoung ? 'Actualiser l’analyse' : 'Actualiser Search Intelligence'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiAnalysisCard extends StatelessWidget {
  const _AiAnalysisCard();

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    final analysis = cases.aiAnalysis;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Analyse IA — aide à la décision', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Règles métier et calculs géographiques. Aucun modèle ML n’a été entraîné. '
              'Ce n’est pas un kidnapping confirmé, pas une preuve, pas la position actuelle.',
            ),
            const SizedBox(height: 8),
            if (analysis == null)
              const Text('Aucune analyse IA pour le moment.')
            else ...[
              Text(
                'Niveau : ${riskLevelLabel(analysis.riskLevel)} '
                '(score ${analysis.score}/${analysis.maxScore}, ${analysis.method}).',
              ),
              const SizedBox(height: 4),
              Text(
                analysis.trainedModel
                    ? 'Un modèle entraîné est déclaré — à vérifier : CityCare n’utilise pas de ML sans dataset labellisé.'
                    : 'Aucun modèle entraîné. Un Random Forest pourra être branché lorsqu’un jeu de données réel existera.',
              ),
              const SizedBox(height: 8),
              Text(analysis.disclaimer),
              const SizedBox(height: 8),
              Text(analysis.explanation),
              if (analysis.dimensions.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Axes analysés'),
                ...analysis.dimensions.entries.map((entry) {
                  final notes = entry.value['notes'];
                  final score = entry.value['score'];
                  final max = entry.value['max'] ?? 3;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${aiDimensionLabel(entry.key)} : $score/$max'
                      '${notes is List && notes.isNotEmpty ? ' — ${notes.first}' : ''}',
                    ),
                  );
                }),
              ],
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: cases.isBusy || cases.current == null
                  ? null
                  : () => cases.refreshAiAnalysis(cases.current!.id),
              child: const Text('Actualiser l’analyse IA'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbableZoneCard extends StatelessWidget {
  const _ProbableZoneCard();

  @override
  Widget build(BuildContext context) {
    final zone = CaseScope.of(context).probableZone;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Zone probable de déplacement', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Zone de recherche estimée. Ce n’est pas la position actuelle, pas un kidnapping confirmé, pas une zone prioritaire.',
            ),
            const SizedBox(height: 8),
            if (zone == null)
              const Text('Aucune zone estimée : il manque une dernière position connue.')
            else ...[
              Text('${searchZoneKindLabel(zone.kind)} · rayon ${zone.radiusMeters.toStringAsFixed(0)} m.'),
              const SizedBox(height: 8),
              Text(zone.disclaimer),
              const SizedBox(height: 8),
              Text(zone.explanation),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriorityZonesCard extends StatelessWidget {
  const _PriorityZonesCard();

  @override
  Widget build(BuildContext context) {
    final zones = CaseScope.of(context).priorityZones;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Zones de recherche prioritaires', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Classement par règles métier. Pas de ML, pas un itinéraire, pas la position actuelle, '
              'pas un kidnapping confirmé. Les témoignages ne classent pas ces zones.',
            ),
            const SizedBox(height: 8),
            if (zones.isEmpty)
              const Text('Aucune zone prioritaire : il manque une dernière position connue.')
            else
              ...[
                for (final zone in zones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${searchZoneKindLabel(zone.kind)} · ${searchPriorityLabel(zone.priority)} · '
                          'rayon ${zone.radiusMeters.toStringAsFixed(0)} m.',
                        ),
                        const SizedBox(height: 4),
                        Text(zone.disclaimer),
                        const SizedBox(height: 4),
                        Text(zone.explanation),
                      ],
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _TestimoniesCard extends StatelessWidget {
  const _TestimoniesCard({
    required this.caseId,
    required this.isOpen,
    required this.canSubmit,
    required this.canModerate,
  });

  final String caseId;
  final bool isOpen;
  final bool canSubmit;
  final bool canModerate;

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Témoignages', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Signalement humain, croisé avec la trajectoire par règles métier. '
              'Aide à la décision : ce n’est pas une preuve, pas un kidnapping confirmé, '
              'pas la position actuelle, pas de ML.',
            ),
            const SizedBox(height: 8),
            if (cases.testimonies.isEmpty)
              const Text('Aucun témoignage pour le moment.')
            else
              for (final note in cases.testimonies)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${testimonyStatusLabel(note.status)}'
                        '${note.submitterName == null ? '' : ' · ${note.submitterName}'}'
                        ' · ${note.observedAt.toLocal()}',
                      ),
                      const SizedBox(height: 4),
                      Text(note.description),
                      const SizedBox(height: 4),
                      Text(note.disclaimer),
                      if (note.consistency == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Cohérence GPS : non calculée.'),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Cohérence estimée : ${consistencyLevelLabel(note.consistency!)} — '
                            'aide à la décision, pas une preuve.',
                          ),
                        ),
                        if (note.consistencyNote != null && note.consistencyNote!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(note.consistencyNote!),
                          ),
                      ],
                      if (canModerate && note.isOpen) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (note.status == TestimonyStatus.submitted)
                              OutlinedButton(
                                onPressed: cases.isBusy ? null : () => cases.reviewTestimony(caseId, note.id),
                                child: const Text('Examiner'),
                              ),
                            FilledButton(
                              onPressed: cases.isBusy ? null : () => cases.verifyTestimony(caseId, note.id),
                              child: const Text('Vérifier'),
                            ),
                            OutlinedButton(
                              onPressed: cases.isBusy ? null : () => cases.rejectTestimony(caseId, note.id),
                              child: const Text('Rejeter'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            if (cases.testimonies.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: cases.isBusy ? null : () => cases.refreshTestimonyConsistency(caseId),
                child: const Text('Recalculer la cohérence'),
              ),
            ],
            if (canSubmit && isOpen) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => TestimonyCreatePage(caseId: caseId)),
                  );
                },
                child: const Text('Ajouter un témoignage'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TestimonyCreatePage extends StatefulWidget {
  const TestimonyCreatePage({super.key, required this.caseId});

  final String caseId;

  @override
  State<TestimonyCreatePage> createState() => _TestimonyCreatePageState();
}

class _TestimonyCreatePageState extends State<TestimonyCreatePage> {
  final _description = TextEditingController();
  final _photoUrl = TextEditingController();
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _description.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau témoignage')),
      body: ListenableBuilder(
        listenable: cases,
        builder: (context, _) {
          return ListView(
            children: [
              SizedBox(
                height: 240,
                child: LocationMapView(
                  latitude: _latitude,
                  longitude: _longitude,
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
                      'Touchez la carte pour indiquer le lieu d’observation. '
                      'Ce n’est pas un kidnapping confirmé, pas une preuve, pas la position actuelle.',
                    ),
                    const SizedBox(height: 12),
                    if (cases.errorMessage != null)
                      Text(cases.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    TextField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: 'Ce que vous avez vu',
                        hintText: 'Lieu, heure approximative, vêtements…',
                      ),
                      maxLines: 4,
                    ),
                    TextField(
                      controller: _photoUrl,
                      decoration: const InputDecoration(
                        labelText: 'Lien photo (optionnel)',
                        hintText: 'Aucune photo n’est envoyée depuis l’appareil dans cette version',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _latitude == null
                          ? 'Aucun lieu choisi sur la carte.'
                          : 'Lieu : ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: cases.isBusy ? null : () => _submit(context),
                      child: Text(cases.isBusy ? 'Envoi…' : 'Envoyer le témoignage'),
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

  Future<void> _submit(BuildContext context) async {
    final description = _description.text.trim();
    if (description.length < 8 || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décrivez ce que vous avez vu et touchez la carte.')),
      );
      return;
    }
    final ok = await CaseScope.of(context).submitTestimony(
      widget.caseId,
      TestimonyDraft(
        description: description,
        latitude: _latitude!,
        longitude: _longitude!,
        photoUrl: _photoUrl.text.trim(),
      ),
    );
    if (!ok || !context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}
