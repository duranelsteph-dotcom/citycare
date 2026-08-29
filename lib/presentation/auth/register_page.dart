import 'package:flutter/material.dart';

import '../../domain/enums/citycare_enums.dart';
import 'auth_scope.dart';
import 'role_labels.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  UserRole _role = UserRole.young;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final ok = await AuthScope.of(context).register(
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      password: _password.text,
      role: _role,
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Entrez votre nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 8) {
                          return 'Entrez un numéro de téléphone valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe (8 caractères min.)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Au moins 8 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != _password.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Text('Je suis', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: UserRole.values.map((role) {
                        return ChoiceChip(
                          label: Text(roleLabel(role)),
                          selected: _role == role,
                          onSelected: (_) => setState(() => _role = role),
                        );
                      }).toList(),
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(auth.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: auth.isBusy ? null : _submit,
                      child: auth.isBusy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Créer le compte'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Le mot de passe est haché côté serveur. Le jeton n’est pas dans le code source.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
