import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'family_scope.dart';

class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final family = FamilyScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Code de rattachement')),
      body: ListenableBuilder(
        listenable: family,
        builder: (context, _) {
          final code = family.pairingCode;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ce code est valable 15 minutes. Le donner à un parent revient à accepter le rattachement. La localisation n’est pas partagée automatiquement.',
                ),
                const SizedBox(height: 24),
                if (code != null) ...[
                  Text(code.code, textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  Text('Expire à ${code.expiresAt.toLocal()}', textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: code.code)),
                    child: const Text('Copier le code'),
                  ),
                ],
                if (family.errorMessage != null)
                  Text(family.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: family.isLoading ? null : family.generateCode,
                  child: Text(code == null ? 'Générer un code' : 'Générer un nouveau code'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
