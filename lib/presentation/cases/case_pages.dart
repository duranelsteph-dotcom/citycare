import 'package:flutter/material.dart';

import '../../domain/entities/identity.dart';
import '../../domain/entities/search.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/case_repository.dart';
import '../auth/auth_scope.dart';
import '../auth/role_labels.dart';
import '../family/family_controller.dart';
import '../family/family_scope.dart';
import '../location/emergency_page.dart';
import '../location/location_map.dart';
import 'case_scope.dart';

class CasesPage extends StatefulWidget {
  const CasesPage({super.key});

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isYoung = AuthScope.of(context).user?.role == UserRole.young;
      if (isYoung) {
        CaseScope.of(context).loadMineAsYoung();
      } else {
        FamilyScope.of(context).loadForGuardian();
        CaseScope.of(context).loadMineAsGuardian();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    final family = FamilyScope.of(context);
    final isYoung = AuthScope.of(context).user?.role == UserRole.young;
    return Scaffold(
      appBar: AppBar(title: const Text('Dossiers de disparition')),
      floatingActionButton: isYoung
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _startDeclaration(context, family),
              icon: const Icon(Icons.person_search),
              label: const Text('Déclarer'),
            ),
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
                  title: Text(item.youngDisplayName ?? 'Jeune'),
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

  Future<void> _startDeclaration(BuildContext context, FamilyController family) async {
    final eligible = family.active.where((link) => link.canReportMissing).toList();
    if (eligible.isEmpty) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun jeune ne vous a autorisé à déclarer une disparition.'),
        ),
      );
      return;
    }
    GuardianLink chosen = eligible.first;
    if (eligible.length > 1) {
      final selected = await showModalBottomSheet<GuardianLink>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('Quel jeune ?')),
                ...eligible.map(
                  (link) => ListTile(
                    title: Text(link.youngDisplayName ?? 'Jeune'),
                    onTap: () => Navigator.pop(context, link),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (selected == null) {
        return;
      }
      chosen = selected;
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CaseCreatePage(
          youngPersonId: chosen.youngPersonId,
          displayName: chosen.youngDisplayName ?? 'Jeune',
        ),
      ),
    );
  }
}

class CaseCreatePage extends StatefulWidget {
  const CaseCreatePage({
    super.key,
    required this.youngPersonId,
    required this.displayName,
  });

  final String youngPersonId;
  final String displayName;

  @override
  State<CaseCreatePage> createState() => _CaseCreatePageState();
}

class _CaseCreatePageState extends State<CaseCreatePage> {
  final _circumstances = TextEditingController();
  final _clothing = TextEditingController();
  final _lastSeenBy = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _circumstances.dispose();
    _clothing.dispose();
    _lastSeenBy.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cases = CaseScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Disparition — ${widget.displayName}')),
      body: ListenableBuilder(
        listenable: cases,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (cases.isBusy) const LinearProgressIndicator(),
              const Text(
                'MON ENFANT A DISPARU ouvre un dossier avec un instantané des faits connus. '
                'Ce n’est pas un kidnapping confirmé. La dernière position n’est pas la position actuelle. '
                'Aucune zone de recherche n’est calculée ici.',
              ),
              const SizedBox(height: 16),
              if (cases.errorMessage != null)
                Text(cases.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextField(
                controller: _circumstances,
                decoration: const InputDecoration(labelText: 'Circonstances (optionnel)'),
                maxLines: 3,
              ),
              TextField(
                controller: _clothing,
                decoration: const InputDecoration(labelText: 'Vêtements (optionnel)'),
              ),
              TextField(
                controller: _lastSeenBy,
                decoration: const InputDecoration(labelText: 'Vu pour la dernière fois par (optionnel)'),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description (optionnel)'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: cases.isBusy ? null : () => _confirmAndCreate(context),
                child: Text(cases.isBusy ? 'Envoi…' : 'MON ENFANT A DISPARU'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndCreate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Déclarer une disparition ?'),
          content: const Text(
            'Un instantané des faits connus sera enregistré. '
            'Ce n’est pas un kidnapping confirmé, pas un suivi en direct, pas une trajectoire analysée.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Déclarer')),
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
        circumstances: _circumstances.text.trim(),
        clothing: _clothing.text.trim(),
        lastSeenBy: _lastSeenBy.text.trim(),
        description: _description.text.trim(),
      ),
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
    final isYoung = AuthScope.of(context).user?.role == UserRole.young;
    final family = FamilyScope.of(context);
    return Scaffold(
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
              item.isOpen &&
              family.active.any((link) => link.youngPersonId == item.youngPersonId);
          final canModerate = !isYoung &&
              family.active.any(
                (link) => link.youngPersonId == item.youngPersonId && link.canReportMissing,
              );
          return ListView(
            children: [
              SizedBox(
                height: 240,
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
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _CaseFacts(
                  item: item,
                  isYoung: isYoung,
                  canSubmitTestimony: canSubmit,
                  canModerateTestimony: canModerate,
                ),
              ),
              if (!isYoung)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EmergencyModePage(
                          youngPersonId: item.youngPersonId,
                          displayName: item.youngDisplayName ?? 'Jeune',
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

class _CaseFacts extends StatelessWidget {
  const _CaseFacts({
    required this.item,
    required this.isYoung,
    required this.canSubmitTestimony,
    required this.canModerateTestimony,
  });

  final MissingPersonCase item;
  final bool isYoung;
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
        Text('Concerné : ${item.youngDisplayName ?? 'Jeune'}'),
        if (item.reporterName != null) Text('Déclaré par : ${item.reporterName}'),
        Text('Déclaré le ${item.occurredAt.toLocal()}'),
        const SizedBox(height: 8),
        Text(
          item.lastKnownLatitude == null
              ? 'Aucune dernière position connue au moment de la déclaration.'
              : 'Dernière position connue au moment de la déclaration — pas la position actuelle, pas un suivi en direct.',
        ),
        const SizedBox(height: 8),
        Text(snapshot['disclaimer'] as String? ?? 'Ce n’est pas un kidnapping confirmé.'),
        const SizedBox(height: 16),
        if (!isYoung && item.status == CaseStatus.open) ...[
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
        if (!isYoung && item.isOpen) ...[
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
