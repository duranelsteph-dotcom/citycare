import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import '../auth/role_labels.dart';
import 'kit_copy.dart';
import 'kit_secret_dialog.dart';
import 'tracker_controller.dart';
import 'tracker_scope.dart';

class KitDetailPage extends StatefulWidget {
  const KitDetailPage({super.key, required this.trackerId, this.canManage = true});

  final String trackerId;
  final bool canManage;

  @override
  State<KitDetailPage> createState() => _KitDetailPageState();
}

class _KitDetailPageState extends State<KitDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrackerScope.of(context).loadEvents(widget.trackerId);
    });
  }

  Future<void> _refresh(TrackerController kits) async {
    final youngId = kits.loadedYoungPersonId;
    if (youngId == null) {
      await kits.loadMine();
    } else {
      await kits.loadChild(youngId);
    }
    if (mounted) {
      await kits.loadEvents(widget.trackerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kits = TrackerScope.of(context);
    return ListenableBuilder(
      listenable: kits,
      builder: (context, _) {
        final kit = kits.byId(widget.trackerId);
        if (kit == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Kit IoT')),
            body: Center(child: Text(kits.errorMessage ?? 'Ce kit n’est plus enregistré.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(kit.label),
            actions: [
              IconButton(
                tooltip: 'Actualiser — dernière connue, pas en direct',
                onPressed: kits.isBusy ? null : () => _refresh(kits),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (kits.isBusy) const LinearProgressIndicator(),
              const Text(
                'Dernière communication, batterie et position sont des valeurs connues, '
                'pas un état en direct. Le kit ou le simulateur parle au serveur, pas à cette application. '
                'Désactiver empêche le SOS du kit. Ce n’est pas un kidnapping confirmé.',
              ),
              if (kits.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(kits.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              if (kit.status == TrackerStatus.signalLost ||
                  kit.status == TrackerStatus.removed ||
                  kit.status == TrackerStatus.lowBattery)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(kitStatusHeadline(kit)),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Historique kit', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              const Text(
                'Traces datées. Une perte de signal n’est pas la position actuelle, '
                'pas un kidnapping confirmé.',
              ),
              if (kits.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Aucun événement kit pour le moment.'),
                )
              else
                ...kits.events.take(8).map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(kitEventLine(event)),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kit activé'),
                subtitle: Text(
                  kit.isEnabled
                      ? 'Le kit peut envoyer un SOS à l’API.'
                      : 'Kit désactivé : le SOS kit est refusé. À utiliser si le kit est perdu ou retiré.',
                ),
                value: kit.isEnabled,
                onChanged: !widget.canManage || kits.isBusy ? null : (value) => kits.update(kit.id, enabled: value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Identifiant'),
                subtitle: SelectableText(kit.deviceUid),
                trailing: IconButton(
                  tooltip: 'Copier l’UID',
                  onPressed: () => Clipboard.setData(ClipboardData(text: kit.deviceUid)),
                  icon: const Icon(Icons.copy),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Statut'),
                subtitle: Text(trackerStatusLabel(kit.status)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dernière communication'),
                subtitle: Text(
                  kit.lastSeenAt == null
                      ? 'Pas encore de communication kit. Ce n’est pas un suivi en direct.'
                      : '${knownClock(kit.lastSeenAt)} (${kit.lastSeenAt!.toLocal()}) — dernière connue, pas actuelle.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Batterie'),
                subtitle: Text(
                  kit.batteryLevel == null
                      ? 'Pas encore de niveau connu.'
                      : 'Dernière batterie connue : ${kit.batteryLevel} % — pas la batterie actuelle.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dernière position du kit'),
                subtitle: Text(_lastPointCopy(kit)),
              ),
              const SizedBox(height: 8),
              Text('Mode enregistré', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              const Text(
                'Préférence du kit. L’intervalle de rafraîchissement s’en sert '
                '(urgence si SOS ouvert, économie si batterie faible). Ce n’est pas un GPS continu.',
              ),
              const SizedBox(height: 8),
              DropdownButton<TrackingMode>(
                isExpanded: true,
                value: kit.trackingMode,
                items: [
                  for (final mode in TrackingMode.values)
                    DropdownMenuItem(value: mode, child: Text(trackingModeLabel(mode))),
                ],
                onChanged: !widget.canManage || kits.isBusy
                    ? null
                    : (mode) {
                        if (mode != null) {
                          kits.update(kit.id, trackingMode: mode);
                        }
                      },
              ),
              if (widget.canManage) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: kits.isBusy ? null : () => _rename(context, kit),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Renommer'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: kits.isBusy ? null : () => _rotate(context, kit),
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Renouveler le secret'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: kits.isBusy ? null : () => _unregister(context, kit),
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  label: Text('Retirer ce kit', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

String _lastPointCopy(GpsTracker kit) {
  if (kit.lastLatitude == null || kit.lastLongitude == null) {
    return 'Aucune position kit connue.';
  }
  return '${kit.lastLatitude}, ${kit.lastLongitude} — dernière connue, pas un suivi en direct.';
}

Future<void> _rename(BuildContext context, GpsTracker kit) async {
  final controller = TextEditingController(text: kit.label);
  final next = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Nom du kit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Libellé'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (next == null || next.length < 2 || !context.mounted) {
    return;
  }
  await TrackerScope.of(context).update(kit.id, label: next);
}

Future<void> _rotate(BuildContext context, GpsTracker kit) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Renouveler le secret ?'),
        content: const Text(
          'L’ancien secret ne pourra plus envoyer de SOS. Copiez le nouveau tout de suite. '
          'Le kit parle à l’API, pas à Flutter.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Renouveler')),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final kits = TrackerScope.of(context);
  final ok = await kits.rotateSecret(kit.id);
  if (!context.mounted) {
    return;
  }
  final created = kits.lastCreated;
  if (!ok || created == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(kits.errorMessage ?? 'Renouvellement impossible')),
    );
    return;
  }
  await showKitSecretDialog(context, created);
}

Future<void> _unregister(BuildContext context, GpsTracker kit) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Retirer ce kit ?'),
        content: const Text(
          'Le kit ne pourra plus envoyer de SOS. Les anciennes positions restent des traces, '
          'pas un suivi en direct.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final kits = TrackerScope.of(context);
  final ok = await kits.delete(kit.id);
  if (!context.mounted) {
    return;
  }
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(kits.errorMessage ?? 'Retrait impossible')),
    );
    return;
  }
  Navigator.of(context).pop();
}
