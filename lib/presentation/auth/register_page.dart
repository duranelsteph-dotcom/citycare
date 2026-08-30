import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../core/auth/password_rules.dart';
import '../../core/phone/phone_e164.dart';
import '../../domain/enums/citycare_enums.dart';
import 'auth_modal_scaffold.dart';
import 'auth_scope.dart';
import 'legal_pages.dart';
import 'phone_number_field.dart';
import 'role_labels.dart';

/// Inscription phone-first : même modal blanc, e-mail facultatif, mot de passe conservé.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  DialCountry _country = PhoneE164.defaultCountry;
  UserRole _role = UserRole.young;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final email = _email.text.trim();
    final ok = await AuthScope.of(context).register(
      fullName: _name.text.trim(),
      phone: PhoneE164.compose(_country, _phone.text),
      password: _password.text,
      role: _role,
      email: email.isEmpty ? null : email,
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
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
                'Créer un compte',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: CityCareBrand.titleInk,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Rejoignez la protection familiale. L’e-mail est facultatif.',
                style: TextStyle(color: CityCareBrand.mutedText, height: 1.4),
              ),
              const SizedBox(height: CityCareBrand.spaceXl),
              const Text(
                'Type de compte',
                style: TextStyle(
                  color: CityCareBrand.violet,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: CityCareBrand.spaceMd),
              Wrap(
                spacing: CityCareBrand.spaceSm,
                runSpacing: CityCareBrand.spaceSm,
                children: UserRole.values.map((role) {
                  final selected = _role == role;
                  return SizedBox(
                    width: 168,
                    child: _RoleCard(
                      role: role,
                      selected: selected,
                      onTap: () => setState(() => _role = role),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: CityCareBrand.spaceXl),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: CityCareBrand.titleInk, fontSize: 17, fontWeight: FontWeight.w600),
                cursorColor: CityCareBrand.violet,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 2) {
                    return 'Entrez votre nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: CityCareBrand.spaceLg),
              PhoneNumberFormField(
                controller: _phone,
                country: _country,
                onCountryChanged: (country) => setState(() => _country = country),
              ),
              const SizedBox(height: CityCareBrand.spaceLg),
              TextFormField(
                key: const Key('auth-email-field'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: CityCareBrand.titleInk, fontSize: 17, fontWeight: FontWeight.w600),
                cursorColor: CityCareBrand.violet,
                decoration: const InputDecoration(
                  labelText: 'E-mail (facultatif)',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'E-mail invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: CityCareBrand.spaceLg),
              TextFormField(
                key: const Key('auth-register-password'),
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: CityCareBrand.titleInk, fontSize: 17, fontWeight: FontWeight.w600),
                cursorColor: CityCareBrand.violet,
                decoration: InputDecoration(
                  labelText: 'Mot de passe fort',
                  helperText: PasswordRules.message,
                  helperMaxLines: 3,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: PasswordRules.validate,
              ),
              const SizedBox(height: CityCareBrand.spaceLg),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                style: const TextStyle(color: CityCareBrand.titleInk, fontSize: 17, fontWeight: FontWeight.w600),
                cursorColor: CityCareBrand.violet,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value != _password.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: CityCareBrand.spaceLg),
              const LegalConsentText(),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: CityCareBrand.spaceMd),
                Text(auth.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: CityCareBrand.spaceXl),
              FilledButton(
                onPressed: auth.isBusy ? null : _submit,
                child: auth.isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Créer le compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.selected, required this.onTap});

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (role) {
        UserRole.young => Icons.person_outline,
        UserRole.parent => Icons.family_restroom,
        UserRole.relative => Icons.group_outlined,
        UserRole.authority => Icons.badge_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final color = selected ? CityCareBrand.violet : CityCareBrand.mutedText;
    return Material(
      color: selected ? CityCareBrand.violet.withValues(alpha: 0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: CityCareBrand.borderRadiusSm,
        side: BorderSide(color: selected ? CityCareBrand.violet : CityCareBrand.tileBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: CityCareBrand.borderRadiusSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Icon(_icon, color: color),
              const SizedBox(height: 6),
              Text(
                roleLabel(role),
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
