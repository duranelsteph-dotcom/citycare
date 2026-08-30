import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../core/phone/phone_e164.dart';
import 'auth_modal_scaffold.dart';
import 'legal_pages.dart';
import 'password_page.dart';
import 'phone_number_field.dart';
import 'register_page.dart';

/// Première étape phone-first (modal blanc sur violet).
///
/// Le mot de passe et l’OTP restent sur les écrans suivants.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  DialCountry _country = PhoneE164.defaultCountry;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final e164 = PhoneE164.compose(_country, _phone.text);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PasswordPage(phoneE164: e164)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthModalScaffold(
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const Text(
                'Entrez votre numéro de téléphone',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: CityCareBrand.titleInk,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nous utiliserons ce numéro pour vous connecter, puis un mot de passe et un code.',
                style: TextStyle(color: CityCareBrand.mutedText, height: 1.4),
              ),
              const SizedBox(height: CityCareBrand.spaceXl),
              PhoneNumberFormField(
                controller: _phone,
                country: _country,
                onCountryChanged: (country) => setState(() => _country = country),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _continue(),
              ),
              const SizedBox(height: CityCareBrand.spaceLg),
              const LegalConsentText(),
              const SizedBox(height: CityCareBrand.spaceXl),
              FilledButton(
                key: const Key('auth-phone-continue'),
                onPressed: _continue,
                child: const Text('Continuer'),
              ),
              const SizedBox(height: CityCareBrand.spaceSm),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                  );
                },
                child: const Text('Créer un compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
