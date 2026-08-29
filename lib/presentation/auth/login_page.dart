import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/enums/citycare_enums.dart';
import '../prevention/prevention_page.dart';
import '../widgets/citycare_logo.dart';
import '../widgets/prevention_illustrations.dart';
import 'auth_scope.dart';
import 'register_page.dart';
import 'role_labels.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await AuthScope.of(context).login(phone: _phone.text.trim(), password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Scaffold(
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
                    const SizedBox(height: CityCareBrand.spaceMd),
                    const Center(
                      child: CityCareLogo(
                        axis: Axis.vertical,
                        markSize: 72,
                        fontSize: 32,
                        tagline: 'Prévention, alerte et assistance',
                      ),
                    ),
                    const SizedBox(height: CityCareBrand.spaceMd),
                    const _PreventionTeaser(),
                    const SizedBox(height: CityCareBrand.spaceMd),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
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
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Le mot de passe doit contenir au moins 8 caractères';
                        }
                        return null;
                      },
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
                          : const Text('Se connecter'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterPage()));
                            },
                      child: const Text('Créer un compte'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Rôles : ${UserRole.values.map(roleLabel).join(', ')}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le jeton d’accès est stocké de façon sécurisée sur l’appareil. '
                      'Aucun secret n’est dans le code source. En production l’API passe par HTTPS.',
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

/// Accroche de prévention affichée avant même la connexion.
///
/// Elle donne le sujet de l'application en une image et ouvre les conseils
/// détaillés sans exiger de compte : un parent doit pouvoir lire les conseils
/// tout de suite.
class _PreventionTeaser extends StatelessWidget {
  const _PreventionTeaser();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PreventionPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CityCareBrand.spaceSm + 2),
          child: Row(
            children: [
              const PreventionIllustration(scene: PreventionScene.strangerDanger, height: 68),
              const SizedBox(width: CityCareBrand.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Prévenir l’enlèvement d’un enfant',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Un trajet connu, un adulte prévenu, une alerte immédiate.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: CityCareBrand.spaceXs),
                    Text(
                      'Lire les conseils de prévention',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
