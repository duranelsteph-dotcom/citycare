import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/brand.dart';

/// Texte passé au menu de partage système. Pas d'envoi SMS automatique,
/// pas de deep link (le projet n'a pas uni_links / app_links).
String circleShareText(String code) {
  final cleaned = _normalizeInviteCode(code);
  return 'Rejoins mon cercle CityCare : $cleaned';
}

/// Payload du QR : uniquement les 6 caractères, lisibles à l'œil ou par n'importe quel scanneur.
String circleQrPayload(String code) => _normalizeInviteCode(code);

String _normalizeInviteCode(String code) {
  return code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
}

/// Doubles de test : intercepte partage / presse-papiers sans plugins natifs.
@visibleForTesting
Future<void> Function(String text)? debugCircleShareOverride;

@visibleForTesting
Future<void> Function(String text)? debugCircleCopyOverride;

Future<void> shareCircleInvite(String code) async {
  final text = circleShareText(code);
  final override = debugCircleShareOverride;
  if (override != null) {
    await override(text);
    return;
  }
  await Share.share(text);
}

Future<void> copyCircleInvite(String code) async {
  final text = _normalizeInviteCode(code);
  final override = debugCircleCopyOverride;
  if (override != null) {
    await override(text);
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
}

/// Gros code + Copier + Partager + QR. Réutilisé par la page et la feuille de création.
class CircleInviteSharePanel extends StatelessWidget {
  const CircleInviteSharePanel({
    super.key,
    required this.code,
    this.showCopiedSnack = true,
  });

  final String code;
  final bool showCopiedSnack;

  Future<void> _copy(BuildContext context) async {
    if (code.isEmpty) {
      return;
    }
    await copyCircleInvite(code);
    if (!context.mounted || !showCopiedSnack) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié')),
    );
  }

  Future<void> _share() async {
    if (code.isEmpty) {
      return;
    }
    await shareCircleInvite(code);
  }

  @override
  Widget build(BuildContext context) {
    final payload = circleQrPayload(code);
    return Column(
      key: const Key('circle-invite-share-panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: CityCareBrand.lavender,
            borderRadius: CityCareBrand.borderRadiusMd,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                Text(
                  payload.isEmpty ? '——————' : payload,
                  key: const Key('circle-invite-code'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: CityCareBrand.violet,
                  ),
                ),
                const SizedBox(height: CityCareBrand.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('circle-invite-copy'),
                        onPressed: payload.isEmpty ? null : () => _copy(context),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copier'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('circle-invite-share'),
                        onPressed: payload.isEmpty ? null : _share,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Partager'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (payload.length == 6) ...[
          const SizedBox(height: CityCareBrand.spaceLg),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: CityCareBrand.borderRadiusMd,
                border: Border.all(color: CityCareBrand.tileBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  key: const Key('circle-invite-qr'),
                  data: payload,
                  size: 180,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: CityCareBrand.violetDeep,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: CityCareBrand.violetDeep,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: CityCareBrand.spaceSm),
          Text(
            'Le proche peut lire les 6 caractères à l’œil, ou scanner ce QR '
            'avec n’importe quelle appli. Il n’y a pas de lien profond.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CityCareBrand.mutedText),
          ),
        ],
      ],
    );
  }
}
