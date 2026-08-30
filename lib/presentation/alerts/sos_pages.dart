import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../data/datasources/voice_sos_service.dart';
import '../../domain/entities/alerts.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../auth/auth_scope.dart';
import '../auth/role_labels.dart';
import '../family/family_scope.dart';
import '../location/emergency_page.dart';
import '../location/location_map.dart';
import 'alert_scope.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlertScope.of(context).loadMineAsYoung();
    });
  }

  @override
  Widget build(BuildContext context) {
    final alerts = AlertScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: ListenableBuilder(
        listenable: alerts,
        builder: (context, _) {
          final open = alerts.openSos;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (alerts.isBusy) const LinearProgressIndicator(),
              const Text(
                key: Key('sos-disclaimer'),
                'Le SOS est une demande d’aide, depuis l’application, la voix du téléphone, ou le kit IoT. '
                'Ce n’est pas un kidnapping confirmé. Inbox plus notification push FCM si Firebase est configuré.',
              ),
              const SizedBox(height: 16),
              if (alerts.errorMessage != null)
                Text(alerts.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (alerts.infoMessage != null) Text(alerts.infoMessage!),
              const SizedBox(height: 16),
              if (open != null)
                _AlertCard(alert: open, isYoung: true)
              else ...[
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CityCareBrand.sos,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(72),
                    shape: CityCareBrand.stadium,
                  ),
                  onPressed: alerts.isBusy ? null : () => _confirmAndSend(context),
                  child: Text(alerts.isBusy ? 'Envoi…' : 'Déclencher un SOS'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: alerts.isBusy ? null : () => _confirmAndSend(context, discreet: true),
                  child: const Text('SOS discret'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: alerts.isBusy ? null : () => _listenVoice(context),
                  child: const Text('SOS vocal'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SOS vocal : dites « au secours » ou « à l’aide ». '
                  'Reconnaissance du système, pas une commande inventée. Confirmation ensuite.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndSend(BuildContext context, {bool discreet = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(discreet ? 'SOS discret ?' : 'Envoyer un SOS ?'),
          content: Text(
            discreet
                ? 'Même alerte, confirmation supplémentaire pour limiter un appui accidentel. '
                    'Ce n’est pas un kidnapping confirmé.'
                : 'Vos contacts qui reçoivent les alertes seront prévenus dans l’application '
                    '(et par push FCM si un jeton appareil est enregistré). '
                    'Ce n’est pas un kidnapping confirmé.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await AlertScope.of(context).triggerSos(description: discreet ? 'Déclenchement discret (application)' : null);
  }

  Future<void> _listenVoice(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Écoute… dites « au secours » ou « à l’aide ».')));
    final outcome = await VoiceSosService().listen();
    if (!context.mounted) {
      return;
    }
    messenger.hideCurrentSnackBar();
    switch (outcome.status) {
      case VoiceListenStatus.unavailable:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Reconnaissance vocale indisponible sur cet appareil. '
              'Ce n’est pas un SOS simulé.',
            ),
          ),
        );
        return;
      case VoiceListenStatus.cancelled:
        return;
      case VoiceListenStatus.noMatch:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              outcome.transcript.isEmpty
                  ? 'Aucune phrase d’aide reconnue.'
                  : 'Entendu : « ${outcome.transcript} ». Ce n’est pas une phrase d’aide.',
            ),
          ),
        );
        return;
      case VoiceListenStatus.matched:
        break;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Envoyer un SOS vocal ?'),
          content: Text(
            'Phrase reconnue : « ${outcome.transcript} ». '
            'Confirmation pour limiter un déclenchement accidentel. Ce n’est pas un kidnapping confirmé.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await AlertScope.of(context).triggerSos(
      source: AlertSource.voice,
      description: 'SOS vocal : ${outcome.transcript}',
    );
  }
}

class GuardianAlertsPage extends StatefulWidget {
  const GuardianAlertsPage({super.key, this.title});

  final String? title;

  @override
  State<GuardianAlertsPage> createState() => _GuardianAlertsPageState();
}

class _GuardianAlertsPageState extends State<GuardianAlertsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlertScope.of(context).loadMineAsGuardian();
      if (AuthScope.of(context).user?.role != UserRole.authority) {
        FamilyScope.of(context).loadForGuardian();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alerts = AlertScope.of(context);
    final family = FamilyScope.of(context);
    final isAuthority = AuthScope.of(context).user?.role == UserRole.authority;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? (isAuthority ? 'Traiter les alertes' : 'Alertes SOS'))),
      floatingActionButton: ListenableBuilder(
        listenable: family,
        builder: (context, _) {
          if (isAuthority) {
            return const SizedBox.shrink();
          }
          final canTrigger = family.active.where((link) => link.canTriggerAlert).toList();
          if (canTrigger.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            heroTag: 'guardian-relative-sos',
            onPressed: alerts.isBusy ? null : () => _relativeSos(context, canTrigger),
            icon: const Icon(Icons.sos),
            label: const Text('Signaler un danger'),
          );
        },
      ),
      body: ListenableBuilder(
        listenable: alerts,
        builder: (context, _) {
          final Widget content;
          if (alerts.isBusy && alerts.items.isEmpty) {
            content = const Center(child: CircularProgressIndicator());
          } else if (alerts.errorMessage != null && alerts.items.isEmpty) {
            content = Center(child: Text(alerts.errorMessage!));
          } else if (alerts.items.isEmpty) {
            content = const Center(child: Text('Aucun SOS pour le moment.'));
          } else {
            content = ListView(
              children: alerts.items.map((alert) {
                return ListTile(
                  leading: Icon(
                    Icons.sos,
                    color: alert.isOpen ? Theme.of(context).colorScheme.error : null,
                  ),
                  title: Text(alert.youngDisplayName ?? 'Jeune'),
                  subtitle: Text('${alertStatusLabel(alert.status)} · ${alert.triggeredAt.toLocal()}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SosDetailPage(alertId: alert.id)),
                  ),
                );
              }).toList(),
            );
          }
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  key: Key('sos-disclaimer'),
                  'Demandes d’aide reçues. Ce n’est pas un kidnapping confirmé. '
                  'Inbox dans l’application, plus un push FCM si un jeton appareil est enregistré.',
                ),
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Future<void> _relativeSos(BuildContext context, List<GuardianLink> candidates) async {
    GuardianLink? chosen = candidates.length == 1 ? candidates.first : null;
    chosen ??= await showDialog<GuardianLink>(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: const Text('Pour quel jeune ?'),
            children: [
              for (final link in candidates)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, link),
                  child: Text(link.youngDisplayName ?? 'Jeune'),
                ),
            ],
          );
        },
      );
    if (chosen == null || !context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Signaler un danger ?'),
          content: const Text(
            'Un SOS sera envoyé au nom du jeune. Ce n’est pas un kidnapping confirmé. '
            'Un push FCM est tenté si un jeton appareil est enregistré.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await AlertScope.of(context).triggerSos(youngPersonId: chosen.youngPersonId);
  }
}

class SosDetailPage extends StatefulWidget {
  const SosDetailPage({super.key, required this.alertId});

  final String alertId;

  @override
  State<SosDetailPage> createState() => _SosDetailPageState();
}

class _SosDetailPageState extends State<SosDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlertScope.of(context).loadOne(widget.alertId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final alerts = AlertScope.of(context);
    final isYoung = AuthScope.of(context).user?.role == UserRole.young;
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche SOS')),
      body: ListenableBuilder(
        listenable: alerts,
        builder: (context, _) {
          if (alerts.isBusy && alerts.current?.id != widget.alertId) {
            return const Center(child: CircularProgressIndicator());
          }
          final alert = alerts.current?.id == widget.alertId ? alerts.current : null;
          if (alert == null) {
            return Center(child: Text(alerts.errorMessage ?? 'Alerte introuvable'));
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _AlertCard(alert: alert, isYoung: isYoung),
              ),
              SizedBox(
                height: 240,
                child: LocationMapView(
                  latitude: alert.latitude,
                  longitude: alert.longitude,
                  accuracyMeters: alert.accuracy,
                  isStale: alert.positionLooksStale,
                ),
              ),
              if (!isYoung)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EmergencyModePage(
                          youngPersonId: alert.youngPersonId,
                          displayName: alert.youngDisplayName ?? 'Jeune',
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.isYoung});

  final Alert alert;
  final bool isYoung;

  @override
  Widget build(BuildContext context) {
    final alerts = AlertScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Statut : ${alertStatusLabel(alert.status)}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Source : ${alertSourceLabel(alert.source)}'),
        const SizedBox(height: 8),
        Text('Déclenché le ${alert.triggeredAt.toLocal()}'),
        const SizedBox(height: 8),
        Text(_positionCopy(alert)),
        const SizedBox(height: 12),
        const Text('Ce n’est pas un kidnapping confirmé. Inbox dans l’app, plus push FCM si configuré.'),
        if (alerts.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(alerts.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        if (isYoung && alert.isOpen) ...[
          FilledButton(
            onPressed: alerts.isBusy ? null : () => alerts.resolve(alert.id),
            child: const Text('Je vais bien'),
          ),
          const SizedBox(height: 8),
          const Text('Clore le SOS n’est pas un kidnapping confirmé.'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: alerts.isBusy ? null : () => alerts.cancel(alert.id),
            child: const Text('Annuler le SOS'),
          ),
        ],
        if (!isYoung && alert.isOpen) ...[
          if (alert.status != AlertStatus.acknowledged)
            FilledButton(
              onPressed: alerts.isBusy ? null : () => alerts.acknowledge(alert.id),
              child: const Text('Prendre en compte'),
            ),
          if (alert.status != AlertStatus.acknowledged) const SizedBox(height: 8),
          FilledButton(
            onPressed: alerts.isBusy ? null : () => alerts.resolve(alert.id),
            child: const Text('Clore le SOS'),
          ),
          const SizedBox(height: 8),
          const Text('Clore le SOS n’est pas un kidnapping confirmé.'),
        ],
      ],
    );
  }
}

String _positionCopy(Alert alert) {
  if (!alert.hasPoint) {
    return 'Aucune position jointe. Le SOS a bien été envoyé.';
  }
  if (alert.positionLooksStale) {
    return 'Dernière position connue (peut être ancienne) — pas la position actuelle, pas un suivi en direct.';
  }
  return 'Position ${alert.source == AlertSource.iot ? 'du kit' : 'du téléphone'} au moment du SOS — pas un suivi en direct.';
}
