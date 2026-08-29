import 'package:flutter/material.dart';

import 'family_scope.dart';

class LinkChildPage extends StatefulWidget {
  const LinkChildPage({super.key});

  @override
  State<LinkChildPage> createState() => _LinkChildPageState();
}

class _LinkChildPageState extends State<LinkChildPage> {
  final _code = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = FamilyScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rattacher un jeune')),
      body: ListenableBuilder(
        listenable: family,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Le jeune génère un code dans son application. En l’entrant ici, le rattachement est immédiat.'),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Code à 6 chiffres', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: family.isLoading
                    ? null
                    : () async {
                        final ok = await family.linkByCode(_code.text.trim());
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                child: const Text('Rattacher avec le code'),
              ),
              const Divider(height: 40),
              const Text('Ou envoyer une invitation : le jeune devra l’accepter.'),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone du jeune', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: family.isLoading
                    ? null
                    : () async {
                        final ok = await family.inviteByPhone(_phone.text.trim());
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                child: const Text('Envoyer une invitation'),
              ),
              if (family.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(family.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          );
        },
      ),
    );
  }
}
