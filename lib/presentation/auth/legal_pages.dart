import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';

/// Texte CGU CityCare sous le champ téléphone (pas de marque tierce).
class LegalConsentText extends StatefulWidget {
  const LegalConsentText({super.key});

  @override
  State<LegalConsentText> createState() => _LegalConsentTextState();
}

class _LegalConsentTextState extends State<LegalConsentText> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()
      ..onTap = () => _open(const TermsOfUsePage());
    _privacy = TapGestureRecognizer()
      ..onTap = () => _open(const PrivacyPolicyPage());
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: CityCareBrand.mutedText,
      fontSize: 13,
      height: 1.45,
    );
    final link = base.copyWith(
      color: CityCareBrand.violet,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: CityCareBrand.violet,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'En continuant j’accepte les '),
          TextSpan(text: 'Conditions d’utilisation', style: link, recognizer: _terms),
          const TextSpan(text: ' et la '),
          TextSpan(text: 'Politique de confidentialité', style: link, recognizer: _privacy),
          const TextSpan(text: ' de CityCare.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentPage(
      title: 'Conditions d’utilisation',
      paragraphs: [
        'CityCare est une application de veille familiale. En créant un compte, vous confirmez avoir l’âge légal ou l’accord d’un tuteur, et vous vous engagez à n’inviter que des personnes de confiance.',
        'Un SOS, une sortie de zone ou une dernière position connue ne constituent pas un kidnapping confirmé. CityCare n’est pas un service d’urgence : en danger immédiat, composez les numéros officiels de votre pays.',
        'Le partage de position est limité aux membres que vous autorisez. Vous pouvez révoquer un lien, quitter un cercle ou supprimer votre compte. Toute utilisation abusive (surveillance sans consentement, harcèlement) est interdite.',
        'Ces conditions concernent uniquement CityCare. Elles ne reprennent pas les règles d’une autre application de localisation.',
      ],
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentPage(
      title: 'Politique de confidentialité',
      paragraphs: [
        'CityCare enregistre votre numéro de téléphone pour l’authentification (mot de passe, puis code à usage unique). L’e-mail est facultatif. Le mot de passe est haché côté serveur ; le jeton d’accès reste sur l’appareil, hors du code source.',
        'Les positions affichées sont des points horodatés (dernière position connue), pas un suivi en direct continu. Les alertes et notifications décrivent un événement ; elles ne prouvent pas une disparition.',
        'Vous pouvez demander l’accès, la correction ou la suppression de vos données auprès de l’opérateur CityCare. Aucun secret d’API n’est embarqué dans l’application.',
      ],
    );
  }
}

class _LegalDocumentPage extends StatelessWidget {
  const _LegalDocumentPage({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          for (final paragraph in paragraphs) ...[
            Text(paragraph, style: const TextStyle(fontSize: 15, height: 1.45)),
            const SizedBox(height: CityCareBrand.spaceLg),
          ],
        ],
      ),
    );
  }
}
