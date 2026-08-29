import 'package:flutter/material.dart';

import '../../domain/enums/citycare_enums.dart';
import 'kit_copy.dart';
import 'kit_detail_page.dart';
import 'kit_secret_dialog.dart';
import 'tracker_scope.dart';

class KitPage extends StatefulWidget {
  const KitPage({super.key, this.youngPersonId, this.displayName, this.canManage = true});

  final String? youngPersonId;
  final String? displayName;
  final bool canManage;

  @override
  State<KitPage> createState() => _KitPageState();
}

class _KitPageState extends State<KitPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kits = TrackerScope.of(context);
      final youngId = widget.youngPersonId;
      if (youngId == null) {
        kits.loadMine();
      } else {
        kits.loadChild(youngId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kits = TrackerScope.of(context);
    final title = widget.displayName == null ? 'Mon kit IoT' : 'Kit · ${widget.displayName}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Actualiser — dernière connue, pas en direct',
            onPressed: kits.isBusy
                ? null
                : () {
                    final youngId = widget.youngPersonId;
                    if (youngId == null) {
                      kits.loadMine();
                    } else {
                      kits.loadChild(youngId);
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: kits.isBusy ? null : () => _register(context),
              icon: const Icon(Icons.add),
              label: const Text('Enregistrer un kit'),
            )
          : null,
      body: ListenableBuilder(
        listenable: kits,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              if (kits.isBusy) const LinearProgressIndicator(),
              const Text(
                'Le kit (ou le simulateur) parle au serveur, pas à cette application. '
                'Actualisez pour la dernière valeur connue — pas un suivi en direct, pas un bracelet réel. '
                'Le secret n’est affiché qu’à la création ou au renouvellement.',
              ),
              if (kits.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(kits.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              if (kits.items.isEmpty) const Text('Aucun kit enregistré pour le moment.'),
              ...kits.items.map((kit) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.watch),
                    title: Text(kit.label),
                    subtitle: Text(
                      '${kit.deviceUid}\n'
                      '${kitStatusHeadline(kit)}'
                      '${kit.batteryLevel == null || kit.status == TrackerStatus.lowBattery ? '' : '\nBatterie connue ${kit.batteryLevel} %'}',
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => KitDetailPage(trackerId: kit.id, canManage: widget.canManage),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _register(BuildContext context) async {
    final kits = TrackerScope.of(context);
    final ok = await kits.register(youngPersonId: widget.youngPersonId);
    if (!context.mounted) {
      return;
    }
    final created = kits.lastCreated;
    if (!ok || created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kits.errorMessage ?? 'Enregistrement impossible')),
      );
      return;
    }
    await showKitSecretDialog(context, created);
  }
}
