import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../trackers/kit_page.dart';
import 'circle_invite_share.dart';
import 'circle_scope.dart';

/// Écran « Partager le code » : gros code, Copier, Partager, QR local.
class CircleInvitePage extends StatefulWidget {
  const CircleInvitePage({super.key});

  @override
  State<CircleInvitePage> createState() => _CircleInvitePageState();
}

class _CircleInvitePageState extends State<CircleInvitePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        CircleScope.of(context).refreshInviteCode();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final circles = CircleScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Partager le code')),
      body: ListenableBuilder(
        listenable: circles,
        builder: (context, _) {
          final circle = circles.selected;
          if (circle == null) {
            return const Center(child: Text('Aucun cercle sélectionné'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(circle.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Ce code permet de rejoindre le cercle. Il ne donne pas la position : '
                  'les autorisations restent celles de GuardianLink.',
                ),
                const SizedBox(height: CityCareBrand.spaceLg),
                CircleInviteSharePanel(code: circle.inviteCode),
                if (circles.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(circles.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (circle.isOwner) ...[
                  const SizedBox(height: CityCareBrand.spaceLg),
                  OutlinedButton(
                    onPressed: circles.isLoading ? null : circles.regenerateInvite,
                    child: const Text('Générer un nouveau code'),
                  ),
                ],
                const SizedBox(height: CityCareBrand.spaceLg),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const KitPage()),
                  ),
                  icon: const Icon(Icons.watch_outlined),
                  label: const Text('Associer un kit'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
