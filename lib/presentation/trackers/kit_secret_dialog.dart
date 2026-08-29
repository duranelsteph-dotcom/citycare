import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/tracking.dart';

Future<void> showKitSecretDialog(BuildContext context, GpsTracker created) async {
  final secret = created.deviceSecret;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Secret du kit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Copiez ce secret maintenant. Il ne sera plus renvoyé. '
              'Il sert au SOS du kit vers l’API, pas à Flutter.',
            ),
            const SizedBox(height: 12),
            SelectableText('UID : ${created.deviceUid}'),
            if (secret != null) ...[
              const SizedBox(height: 8),
              SelectableText('Secret : $secret'),
            ],
          ],
        ),
        actions: [
          if (secret != null)
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: '${created.deviceUid}\n$secret'));
              },
              child: const Text('Copier'),
            ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('J’ai copié')),
        ],
      );
    },
  );
}
