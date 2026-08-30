import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/brand.dart';
import '../widgets/brand_backdrop.dart';
import '../widgets/citycare_logo.dart';
import 'auth_scope.dart';

/// Deuxième facteur : 6 chiffres, après le mot de passe.
class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
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

  Future<void> _verify([String? value]) async {
    final auth = AuthScope.of(context);
    if (auth.isBusy) {
      return;
    }
    final digits = (value ?? _code.text).replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le code OTP doit contenir 6 chiffres.')),
      );
      return;
    }
    final ok = await auth.verifyOtp(digits);
    if (ok && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _resend() async {
    final auth = AuthScope.of(context);
    final ok = await auth.resendOtp();
    if (!mounted) {
      return;
    }
    if (ok) {
      setState(_code.clear);
      final demo = auth.pendingChallenge?.otpDev;
      if (demo != null && demo.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mode démo : le nouveau code est $demo (aucun SMS).')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final demo = auth.pendingChallenge?.otpDev;

    return Scaffold(
      backgroundColor: CityCareBrand.violet,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Vérification'),
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
                    'Deuxième facteur après le mot de passe. '
                    'Aucun SMS n’est branché pour l’instant.',
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
                              key: const Key('auth-otp-dev-code'),
                              demo,
                              style: const TextStyle(
                                color: CityCareBrand.violet,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              key: const Key('auth-otp-use-dev'),
                              onPressed: auth.isBusy
                                  ? null
                                  : () {
                                      _code.text = demo;
                                      _verify(demo);
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: CityCareBrand.violet,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Utiliser le code démo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: CityCareBrand.spaceXl),
                  Material(
                    color: Colors.white,
                    borderRadius: CityCareBrand.borderRadiusLg,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        children: [
                          TextField(
                            key: const Key('auth-otp-field'),
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
                              fillColor: CityCareBrand.fieldFill,
                              counterText: '',
                              hintText: '••••••',
                              hintStyle: TextStyle(color: Color(0xFF9E9E9E), letterSpacing: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: CityCareBrand.borderRadiusLg,
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: CityCareBrand.borderRadiusLg,
                                borderSide: BorderSide(color: CityCareBrand.violet, width: 2),
                              ),
                            ),
                            onChanged: (value) {
                              if (value.length == 6) {
                                _verify(value);
                              }
                            },
                            onSubmitted: _verify,
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
                                    color: filled ? CityCareBrand.violet : CityCareBrand.tileBorder,
                                    width: 1.4,
                                  ),
                                  color: filled ? CityCareBrand.lavender : CityCareBrand.fieldFill,
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
                        ],
                      ),
                    ),
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
                    key: const Key('auth-otp-submit'),
                    onPressed: auth.isBusy ? null : _verify,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: CityCareBrand.violet,
                    ),
                    child: auth.isBusy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: CityCareBrand.violet),
                          )
                        : const Text('Valider le code'),
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
