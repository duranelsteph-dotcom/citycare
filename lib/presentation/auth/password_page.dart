import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../dev/dev_api_settings_page.dart';
import 'auth_modal_scaffold.dart';
import 'auth_scope.dart';
import 'forgot_password_page.dart';
import 'otp_page.dart';

/// Deuxième écran : mot de passe, avant l’OTP 2FA existant.
class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final auth = AuthScope.of(context);
    final ok = await auth.login(phone: widget.phoneE164, password: _password.text);
    if (!mounted) {
      return;
    }
    if (ok && auth.pendingChallenge != null) {
      final demo = auth.pendingChallenge!.otpDev;
      if (demo != null && demo.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mode démo : le code est $demo (aucun SMS n’est envoyé).'),
          ),
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const OtpPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return AuthModalScaffold(
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const Text(
                'Entrez votre mot de passe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: CityCareBrand.titleInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.phoneE164,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CityCareBrand.violet,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ensuite, un code à usage unique confirme la connexion.',
                style: TextStyle(color: CityCareBrand.mutedText, height: 1.4),
              ),
              const SizedBox(height: CityCareBrand.spaceXl),
              TextFormField(
                key: const Key('auth-password-field'),
                controller: _password,
                obscureText: _obscure,
                autofocus: true,
                style: const TextStyle(color: CityCareBrand.titleInk, fontSize: 17, fontWeight: FontWeight.w600),
                cursorColor: CityCareBrand.violet,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
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
                const SizedBox(height: CityCareBrand.spaceMd),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (kDebugMode && auth.errorMessage!.toLowerCase().contains('injoignable')) ...[
                  const SizedBox(height: CityCareBrand.spaceSm),
                  TextButton(
                    onPressed: auth.isBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const DevApiSettingsPage()),
                            );
                          },
                    child: const Text('Configurer l’URL du serveur'),
                  ),
                ],
              ],
              const SizedBox(height: CityCareBrand.spaceXl),
              FilledButton(
                key: const Key('auth-login-submit'),
                onPressed: auth.isBusy ? null : _submit,
                child: auth.isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Se connecter'),
              ),
              const SizedBox(height: CityCareBrand.spaceSm),
              TextButton(
                key: const Key('auth-forgot-link'),
                onPressed: auth.isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ForgotPasswordPhonePage(initialPhone: widget.phoneE164),
                          ),
                        );
                      },
                child: const Text('Mot de passe oublié'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
