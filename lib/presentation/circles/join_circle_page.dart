import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/brand.dart';
import 'circle_scope.dart';

/// Saisie du code d'invitation à 6 caractères (pas le code de rattachement dyadique).
class JoinCirclePage extends StatefulWidget {
  const JoinCirclePage({super.key});

  @override
  State<JoinCirclePage> createState() => _JoinCirclePageState();
}

class _JoinCirclePageState extends State<JoinCirclePage> {
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

  Future<void> _join([String? value]) async {
    final code = (value ?? _code.text).replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (code.length != 6) {
      return;
    }
    final ok = await CircleScope.of(context).join(code);
    if (ok && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final circles = CircleScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre un cercle')),
      body: ListenableBuilder(
        listenable: circles,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Entrez le code à 6 caractères partagé par un proche. '
                'Si on vous a montré un QR, lisez-le à l’œil puis saisissez-le ici '
                '(pas de scan caméra dans cette version). '
                'Rejoindre un cercle ne donne pas automatiquement accès à la position.',
              ),
              const SizedBox(height: CityCareBrand.spaceXl),
              TextField(
                key: const Key('join-circle-code-field'),
                controller: _code,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 10),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  _UpperCaseFormatter(),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    _join(value);
                  }
                },
                onSubmitted: _join,
              ),
              const SizedBox(height: CityCareBrand.spaceMd),
              Row(
                key: const Key('join-circle-boxes'),
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
                      border: Border.all(color: CityCareBrand.violet, width: 1.4),
                      color: CityCareBrand.lavender.withValues(alpha: filled ? 1 : 0.4),
                    ),
                    child: Text(
                      filled ? _code.text[index] : '',
                      style: const TextStyle(
                        color: CityCareBrand.violet,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
              ),
              if (circles.errorMessage != null) ...[
                const SizedBox(height: CityCareBrand.spaceMd),
                Text(
                  circles.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: CityCareBrand.spaceXl),
              FilledButton(
                key: const Key('join-circle-submit'),
                onPressed: circles.isLoading ? null : _join,
                child: circles.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Rejoindre'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
