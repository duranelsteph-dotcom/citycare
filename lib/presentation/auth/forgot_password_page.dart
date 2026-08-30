import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/brand.dart';
import '../../core/auth/password_rules.dart';
import '../../core/phone/phone_e164.dart';
import '../widgets/brand_backdrop.dart';
import '../widgets/citycare_logo.dart';
import 'auth_modal_scaffold.dart';
import 'auth_scope.dart';
import 'phone_number_field.dart';

/// Étape 1 : saisie téléphone (même champ que le login).
class ForgotPasswordPhonePage extends StatefulWidget {
  const ForgotPasswordPhonePage({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  State<ForgotPasswordPhonePage> createState() => _ForgotPasswordPhonePageState();
}

class _ForgotPasswordPhonePageState extends State<ForgotPasswordPhonePage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  DialCountry _country = PhoneE164.defaultCountry;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPhone;
    if (initial == null || initial.isEmpty) {
      return;
    }
    final detected = PhoneE164.countryForInternational(initial);
    if (detected == null) {
      return;
    }
    _country = detected;
    _phone.text = initial.startsWith(detected.dialCode)
        ? initial.substring(detected.dialCode.length)
        : PhoneE164.digitsOnly(initial);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final e164 = PhoneE164.compose(_country, _phone.text);
    final auth = AuthScope.of(context);
    final ok = await auth.requestPasswordReset(phone: e164);
    if (!mounted || !ok || auth.pendingReset == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordCodePage(phoneE164: e164),
      ),
    );
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
                'Mot de passe oublié',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: CityCareBrand.titleInk,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entrez le numéro du compte. Un code à 6 chiffres sera généré. '
                'Aucun SMS n’est envoyé pour l’instant.',
                style: TextStyle(color: CityCareBrand.mutedText, height: 1.4),
              ),
              const SizedBox(height: CityCareBrand.spaceXl),
              PhoneNumberFormField(
                controller: _phone,
                country: _country,
                onCountryChanged: (country) => setState(() => _country = country),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: CityCareBrand.spaceMd),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: CityCareBrand.spaceXl),
              FilledButton(
                key: const Key('auth-forgot-phone-continue'),
                onPressed: auth.isBusy ? null : _submit,
                child: auth.isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Envoyer le code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Étape 2 : code 6 chiffres, même lecture que l’OTP de connexion.
class ForgotPasswordCodePage extends StatefulWidget {
  const ForgotPasswordCodePage({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<ForgotPasswordCodePage> createState() => _ForgotPasswordCodePageState();
}

class _ForgotPasswordCodePageState extends State<ForgotPasswordCodePage> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _continue([String? value]) {
    final digits = (value ?? _code.text).replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordNewPage(phoneE164: widget.phoneE164, code: digits),
      ),
    );
  }

  Future<void> _resend() async {
    final auth = AuthScope.of(context);
    final ok = await auth.requestPasswordReset(phone: widget.phoneE164);
    if (!mounted) {
      return;
    }
    if (ok) {
      setState(_code.clear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final demo = auth.pendingReset?.resetCodeDev;

    return Scaffold(
      backgroundColor: CityCareBrand.violet,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Code de réinitialisation'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CityCareBrandBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CityCareLogoMark(size: 72, monochromeColor: Colors.white),
                  const SizedBox(height: CityCareBrand.spaceMd),
                  const Center(child: CityCareWordmark(fontSize: 28, onBrand: true)),
                  const SizedBox(height: CityCareBrand.spaceXl),
                  const Text(
                    'Entrez le code à 6 chiffres',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: CityCareBrand.spaceSm),
                  const Text(
                    'Aucun SMS n’est branché. En démo, le code s’affiche ci-dessous.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (demo != null && demo.isNotEmpty) ...[
                    const SizedBox(height: CityCareBrand.spaceLg),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: CityCareBrand.lavender,
                        borderRadius: CityCareBrand.borderRadiusMd,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(CityCareBrand.spaceMd),
                        child: Column(
                          children: [
                            const Text(
                              'Mode démo : le code s’affiche ici car SMS n’est pas branché',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: CityCareBrand.violetDeep,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              demo,
                              key: const Key('auth-forgot-demo-code'),
                              style: const TextStyle(
                                color: CityCareBrand.violet,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: CityCareBrand.spaceXl),
                  TextField(
                    key: const Key('auth-forgot-code-field'),
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      color: CityCareBrand.titleInk,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10,
                    ),
                    cursorColor: CityCareBrand.violet,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: TextStyle(color: Color(0xFF9E9E9E), letterSpacing: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: CityCareBrand.borderRadiusLg,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: CityCareBrand.borderRadiusLg,
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length == 6) {
                        _continue(value);
                      }
                    },
                    onSubmitted: _continue,
                  ),
                  const SizedBox(height: CityCareBrand.spaceMd),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final filled = index < _code.text.length;
                      return Container(
                        width: 40,
                        height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: filled ? Colors.white : Colors.white70,
                            width: 1.4,
                          ),
                          color: Colors.white,
                        ),
                        child: Text(
                          filled ? _code.text[index] : '',
                          style: const TextStyle(
                            color: CityCareBrand.titleInk,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: CityCareBrand.spaceMd),
                    Text(
                      auth.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFCDD2)),
                    ),
                  ],
                  const SizedBox(height: CityCareBrand.spaceXl),
                  FilledButton(
                    key: const Key('auth-forgot-code-continue'),
                    onPressed: auth.isBusy ? null : _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: CityCareBrand.violet,
                    ),
                    child: const Text('Continuer'),
                  ),
                  const SizedBox(height: CityCareBrand.spaceMd),
                  TextButton(
                    onPressed: auth.isBusy ? null : _resend,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Renvoyer le code'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Étape 3 : nouveau mot de passe, puis retour à la connexion.
class ForgotPasswordNewPage extends StatefulWidget {
  const ForgotPasswordNewPage({
    super.key,
    required this.phoneE164,
    required this.code,
  });

  final String phoneE164;
  final String code;

  @override
  State<ForgotPasswordNewPage> createState() => _ForgotPasswordNewPageState();
}

class _ForgotPasswordNewPageState extends State<ForgotPasswordNewPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final auth = AuthScope.of(context);
    final ok = await auth.resetPassword(
      phone: widget.phoneE164,
      code: widget.code,
      newPassword: _password.text,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe mis à jour. Connectez-vous.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
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
                'Nouveau mot de passe',
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
                'Ensuite, reconnectez-vous : le mot de passe puis le code 2FA.',
                style: TextStyle(color: CityCareBrand.mutedText, height: 1.4),
              ),
              const SizedBox(height: CityCareBrand.spaceXl),
              TextFormField(
                key: const Key('auth-forgot-new-password'),
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: CityCareBrand.titleInk, fontSize: 17, fontWeight: FontWeight.w600),
                cursorColor: CityCareBrand.violet,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
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
                key: const Key('auth-forgot-confirm-password'),
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
              if (auth.errorMessage != null) ...[
                const SizedBox(height: CityCareBrand.spaceMd),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: CityCareBrand.spaceXl),
              FilledButton(
                key: const Key('auth-forgot-submit'),
                onPressed: auth.isBusy ? null : _submit,
                child: auth.isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
