import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/background_share.dart';
import 'location_scope.dart';

/// Interrupteur «-in « Partage en arrière-plan ».
///
/// États : actif, permission refusée, GPS éteint. Jamais « en direct ».
class BackgroundShareTile extends StatefulWidget {
  const BackgroundShareTile({
    super.key,
    this.subtitle,
  });

  /// Précision optionnelle (jeune vs parent qui partage).
  final String? subtitle;

  @override
  State<BackgroundShareTile> createState() => _BackgroundShareTileState();
}

class _BackgroundShareTileState extends State<BackgroundShareTile> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final locations = LocationScope.of(context);
      if (locations.backgroundOptIn) {
        locations.restoreBackgroundSharing();
      } else {
        locations.refreshLocationAccess();
      }
    }
  }

  Future<void> _onChanged(bool value) async {
    final locations = LocationScope.of(context);
    final ok = await locations.setBackgroundSharing(value);
    if (!mounted) {
      return;
    }
    if (!ok && value) {
      final access = locations.locationAccess;
      if (access?.needsLocationSettings == true) {
        await locations.openLocationSettings();
      } else if (access?.needsAppSettings == true ||
          locations.backgroundStatus == BackgroundShareStatus.needsAlways) {
        await locations.openAppSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = LocationScope.of(context);
    return ListenableBuilder(
      listenable: locations,
      builder: (context, _) {
        final status = locations.backgroundStatus;
        final label = BackgroundSharePolicy.statusLabel(status);
        final scheme = Theme.of(context).colorScheme;
        final accent = switch (status) {
          BackgroundShareStatus.active => CityCareBrand.safe,
          BackgroundShareStatus.off => scheme.onSurfaceVariant,
          BackgroundShareStatus.gpsOff ||
          BackgroundShareStatus.denied ||
          BackgroundShareStatus.needsAlways =>
            CityCareBrand.amberDark,
        };
        return Card(
          key: const Key('background-share-tile'),
          margin: const EdgeInsets.symmetric(vertical: CityCareBrand.spaceXs),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CityCareBrand.spaceSm,
              0,
              CityCareBrand.spaceSm,
              CityCareBrand.spaceSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  key: const Key('background-share-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Partage en arrière-plan'),
                  subtitle: Text(
                    widget.subtitle ??
                        'Opt-in. SOS, zones de sécurité, proches autorisés. '
                        'Android affiche une notification persistante.',
                  ),
                  value: locations.backgroundOptIn,
                  onChanged: locations.isRequestingLocationAccess ? null : _onChanged,
                ),
                Text(
                  label,
                  key: const Key('background-share-status'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: accent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
