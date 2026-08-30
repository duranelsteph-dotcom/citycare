import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../auth/auth_scope.dart';

/// Dialogue RGPD : confirmation + mot de passe. En succès, [AuthController] vide la session.
Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _obscure = true;
  String? _localError;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _localError = 'Entrez votre mot de passe pour confirmer.');
      return;
    }
    setState(() => _localError = null);
    final auth = AuthScope.of(context);
    final ok = await auth.deleteAccount(password: password);
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _localError = auth.errorMessage ?? 'Suppression impossible.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return AlertDialog(
      key: const Key('profile-delete-dialog'),
      title: const Text('Supprimer mon compte'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cette action est définitive. Vos données personnelles seront '
            'effacées. Les dossiers de disparition déjà ouverts restent '
            'anonymisés pour la sécurité des proches.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('profile-delete-password'),
            controller: _password,
            obscureText: _obscure,
            enabled: !auth.isBusy,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              errorText: _localError,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
            onSubmitted: (_) => auth.isBusy ? null : _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('profile-delete-cancel'),
          onPressed: auth.isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          key: const Key('profile-delete-confirm'),
          onPressed: auth.isBusy ? null : _confirm,
          style: TextButton.styleFrom(foregroundColor: CityCareBrand.sos),
          child: auth.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Supprimer'),
        ),
      ],
    );
  }
}
