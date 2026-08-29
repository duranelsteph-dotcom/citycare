import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/location_access.dart';
import 'location_permission_copy.dart';
import 'location_scope.dart';

/// Bandeau d'autorisation de localisation.
///
/// Couvre le parcours réel de bout en bout :
/// service de localisation éteint, refus simple (on peut redemander), refus
/// définitif (seuls les réglages débloquent) et état indéterminable.
///
/// Le bandeau se met à jour tout seul au retour des réglages système grâce à
/// l'observation du cycle de vie de l'application : l'utilisateur revient et
/// voit immédiatement que c'est réglé, sans avoir à comprendre qu'il doit
/// rafraîchir l'écran.
class LocationPermissionCard extends StatefulWidget {
  const LocationPermissionCard({super.key, this.showWhenGranted = false});

  /// Affiche aussi une confirmation discrète quand tout est en ordre.
  final bool showWhenGranted;

  @override
  State<LocationPermissionCard> createState() => _LocationPermissionCardState();
}

class _LocationPermissionCardState extends State<LocationPermissionCard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LocationScope.of(context).refreshLocationAccess();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      LocationScope.of(context).refreshLocationAccess();
    }
  }

  Future<void> _handle(LocationAccess access) async {
    final locations = LocationScope.of(context);
    switch (access.status) {
      case LocationAccessStatus.denied:
        await locations.requestLocationAccess();
      case LocationAccessStatus.deniedForever:
        await locations.openAppSettings();
      case LocationAccessStatus.serviceDisabled:
        await locations.openLocationSettings();
      case LocationAccessStatus.unavailable:
        await locations.refreshLocationAccess();
      case LocationAccessStatus.granted:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = LocationScope.of(context);
    return ListenableBuilder(
      listenable: locations,
      builder: (context, _) {
        final access = locations.locationAccess;
        if (access == null) {
          return const SizedBox.shrink();
        }
        if (access.isGranted && !widget.showWhenGranted) {
          return const SizedBox.shrink();
        }
        final copy = LocationPermissionCopy.of(access);
        final scheme = Theme.of(context).colorScheme;
        final accent = copy.isBlocking ? CityCareBrand.amberDark : CityCareBrand.safe;
        final label = copy.actionLabel;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: CityCareBrand.spaceSm),
          child: Padding(
            padding: const EdgeInsets.all(CityCareBrand.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: CityCareBrand.borderRadiusSm,
                      ),
                      child: Icon(copy.icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: CityCareBrand.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurface),
                          ),
                          const SizedBox(height: CityCareBrand.spaceXs),
                          Text(copy.message, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                if (label != null) ...[
                  const SizedBox(height: CityCareBrand.spaceMd),
                  FilledButton.icon(
                    onPressed: locations.isRequestingLocationAccess ? null : () => _handle(access),
                    icon: locations.isRequestingLocationAccess
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(label),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
