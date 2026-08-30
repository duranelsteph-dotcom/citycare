import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../trackers/kit_page.dart';
import 'circle_controller.dart';
import 'circle_invite_share.dart';
import 'circle_scope.dart';

/// Feuille « Personnalisez votre Cercle » (nom + Continuer).
///
/// « Associer un kit » ouvre la page trackers déjà existante — pas un
/// « tracker Life360 ».
Future<void> showCreateCircleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const CreateCircleSheet(),
  );
}

class CreateCircleSheet extends StatefulWidget {
  const CreateCircleSheet({super.key});

  @override
  State<CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends State<CreateCircleSheet> {
  final _name = TextEditingController();
  var _created = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      return;
    }
    final ok = await CircleScope.of(context).create(name);
    if (ok && mounted) {
      setState(() => _created = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final circles = CircleScope.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return ListenableBuilder(
      listenable: circles,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
          child: _created ? _CreatedStep(circles: circles) : _NameStep(
            controller: _name,
            busy: circles.isLoading,
            error: circles.errorMessage,
            onContinue: _continue,
          ),
        );
      },
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onContinue,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('create-circle-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Personnalisez votre Cercle', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Un nom pour regrouper vos proches. Ce n’est pas un suivi en direct, '
          'et cela ne remplace pas les autorisations déjà données.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CityCareBrand.mutedText),
        ),
        const SizedBox(height: CityCareBrand.spaceLg),
        TextField(
          key: const Key('circle-name-field'),
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nom du cercle',
            hintText: 'Famille Steph',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => onContinue(),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: CityCareBrand.spaceLg),
        FilledButton(
          key: const Key('circle-continue'),
          onPressed: busy ? null : onContinue,
          child: busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continuer'),
        ),
      ],
    );
  }
}

class _CreatedStep extends StatelessWidget {
  const _CreatedStep({required this.circles});

  final CircleController circles;

  @override
  Widget build(BuildContext context) {
    final circle = circles.selected;
    final code = circle?.inviteCode ?? '';
    return Column(
      key: const Key('create-circle-done'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(circle?.name ?? 'Cercle', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Partagez ce code pour rejoindre. Quitter le cercle n’efface pas '
          'les liens de confiance déjà en place.',
        ),
        const SizedBox(height: CityCareBrand.spaceLg),
        CircleInviteSharePanel(code: code),
        const SizedBox(height: CityCareBrand.spaceLg),
        OutlinedButton.icon(
          key: const Key('circle-associate-kit'),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const KitPage()),
            );
          },
          icon: const Icon(Icons.watch_outlined),
          label: const Text('Associer un kit'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminé'),
        ),
      ],
    );
  }
}
