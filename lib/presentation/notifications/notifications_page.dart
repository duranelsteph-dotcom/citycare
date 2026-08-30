import 'package:flutter/material.dart';

import '../../domain/entities/alerts.dart';
import '../../domain/enums/citycare_enums.dart';
import '../alerts/sos_pages.dart';
import '../auth/auth_scope.dart';
import '../cases/case_pages.dart';
import '../location/position_pages.dart';
import '../trackers/kit_page.dart';
import 'notification_controller.dart';
import 'notification_scope.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScope.of(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inbox = NotificationScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: inbox.isBusy ? null : () => inbox.markAllRead(),
            child: const Text('Tout lu'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: inbox,
        builder: (context, _) {
          return Column(
            children: [
              if (inbox.isBusy) const LinearProgressIndicator(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Inbox dans l’application, plus un push FCM si Firebase est configuré. '
                  'Une alerte n’est pas un kidnapping confirmé. '
                  'Une position indiquée n’est pas actuelle — ouvrez la carte pour la dernière valeur connue.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('Non lues'),
                    selected: inbox.unreadOnly,
                    onSelected: (value) => inbox.load(unreadOnly: value),
                  ),
                ),
              ),
              if (inbox.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(inbox.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Expanded(child: _list(context, inbox)),
            ],
          );
        },
      ),
    );
  }

  Widget _list(BuildContext context, NotificationController inbox) {
    if (inbox.isBusy && inbox.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (inbox.items.isEmpty) {
      return const Center(child: Text('Aucune notification pour le moment.'));
    }
    return ListView(
      children: inbox.items.map<Widget>((note) {
        return ListTile(
          leading: Icon(_icon(note), color: note.isRead ? null : Theme.of(context).colorScheme.error),
          title: Text(note.title, style: TextStyle(fontWeight: note.isRead ? FontWeight.normal : FontWeight.bold)),
          subtitle: Text(_subtitle(note)),
          isThreeLine: true,
          onTap: () => _open(context, note),
        );
      }).toList(),
    );
  }

  String _subtitle(AppNotification note) {
    final extra = <String>[];
    final zone = note.context?.zoneName;
    if (zone != null && zone.isNotEmpty) {
      extra.add(zone);
    }
    if (note.context?.latitude != null && note.context?.longitude != null) {
      extra.add('dernière connue, pas actuelle');
    }
    extra.add(note.body);
    return extra.join(' · ');
  }

  IconData _icon(AppNotification note) {
    return switch (note.target) {
      'SOS' => Icons.sos,
      'CASE' => note.notificationType == NotificationType.testimony
          ? Icons.record_voice_over
          : note.notificationType == NotificationType.searchUpdate
              ? Icons.analytics_outlined
              : Icons.person_search,
      'KIT' => Icons.watch,
      'SHARE' => Icons.share_location,
      'MAP' => note.notificationType == NotificationType.anomaly
          ? Icons.warning_amber_outlined
          : note.notificationType == NotificationType.riskZoneEnter
              ? Icons.report_gmailerrorred_outlined
              : Icons.map_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  Future<void> _open(BuildContext context, AppNotification note) async {
    final inbox = NotificationScope.of(context);
    await inbox.open(note);
    if (!context.mounted) {
      return;
    }
    final isYoung = AuthScope.of(context).user?.role == UserRole.young;
    final target = note.target;
    if (target == 'CASE' && note.caseId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CaseDetailPage(caseId: note.caseId!)),
      );
      return;
    }
    if (target == 'SOS' && note.alertId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SosDetailPage(alertId: note.alertId!)),
      );
      return;
    }
    if (isYoung) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => target == 'KIT' ? const KitPage() : const MyPositionPage(),
        ),
      );
      return;
    }
    final youngId = note.youngPersonId;
    if (youngId == null) {
      return;
    }
    final role = AuthScope.of(context).user?.role;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => target == 'KIT'
            ? KitPage(
                youngPersonId: youngId,
                displayName: note.youngDisplayName ?? 'Jeune',
                canManage: role == UserRole.parent,
              )
            : ChildPositionPage(
                youngPersonId: youngId,
                displayName: note.youngDisplayName ?? 'Jeune',
              ),
      ),
    );
  }
}
