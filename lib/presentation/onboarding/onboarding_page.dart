import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/location_access.dart';
import '../location/location_permission_copy.dart';
import '../location/location_scope.dart';
import '../widgets/citycare_logo.dart';
import 'notification_permission.dart';
import 'onboarding_scope.dart';

/// Une diapositive de l’onboarding permissions (post-inscription).
class OnboardingSlide {
  const OnboardingSlide({
    required this.kind,
    required this.title,
    required this.body,
    required this.icon,
    required this.semanticLabel,
  });

  final OnboardingSlideKind kind;
  final String title;
  final String body;
  final IconData icon;
  final String semanticLabel;
}

enum OnboardingSlideKind {
  location,
  notifications,
  background,
}

/// Onboarding post-auth, style écrans d’autorisation : pourquoi, puis le geste.
///
/// Trois slides honnêtes. L’arrière-plan existe (Phase 12) mais reste **opt-in** :
/// on n’active rien ici, on n’exige pas « toujours » à l’inscription.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.notificationPermission,
  });

  /// Production : [FcmNotificationPermissionClient]. Tests : un double.
  final NotificationPermissionClient? notificationPermission;

  static const slides = <OnboardingSlide>[
    OnboardingSlide(
      kind: OnboardingSlideKind.location,
      title: 'Pourquoi la localisation ?',
      body:
          'CityCare relève la position de ce téléphone quand vous l’utilisez : '
          'afficher votre point sur la carte, savoir si vous êtes dans une zone '
          'de sécurité, et joindre un lieu à un SOS.\n\n'
          'Ce n’est pas un suivi en continu, et la position n’est partagée '
          'qu’avec les personnes que vous avez autorisées.',
      icon: Icons.my_location,
      semanticLabel: 'Localisation à la demande, pour la carte, le SOS et les zones.',
    ),
    OnboardingSlide(
      kind: OnboardingSlideKind.notifications,
      title: 'Pourquoi les notifications ?',
      body:
          'Les notifications servent à prévenir vos proches d’un SOS, et à vous '
          'alerter d’une sortie de zone de sécurité.\n\n'
          'Sans cette autorisation, les alertes restent visibles dans '
          'l’application, mais le téléphone ne pourra pas les afficher écran '
          'verrouillé.',
      icon: Icons.notifications_active_outlined,
      semanticLabel: 'Notifications pour un SOS ou une sortie de zone.',
    ),
    OnboardingSlide(
      kind: OnboardingSlideKind.background,
      title: 'Localisation en arrière-plan',
      body:
          'Le partage GPS en arrière-plan est optionnel : vous l’activez plus '
          'tard dans Profil (« Partage en arrière-plan »).\n\n'
          'Il sert au SOS, aux zones de sécurité et aux proches que vous avez '
          'autorisés. Android affiche alors une notification persistante '
          '(« CityCare partage ta position ») et demande l’autorisation '
          '« toujours ». Rien n’est activé maintenant.',
      icon: Icons.schedule_outlined,
      semanticLabel:
          'La localisation en arrière-plan est optionnelle, à activer dans Profil.',
    ),
  ];

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with WidgetsBindingObserver {
  late final PageController _pages;
  late final NotificationPermissionClient _notifications;
  int _index = 0;
  bool _locationTouched = false;
  bool _notificationTouched = false;
  bool _requestingNotifications = false;
  NotificationAccess? _notificationAccess;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _notifications = widget.notificationPermission ?? const FcmNotificationPermissionClient();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      LocationScope.of(context).refreshLocationAccess();
      _refreshNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      LocationScope.of(context).refreshLocationAccess();
      _refreshNotifications();
    }
  }

  Future<void> _refreshNotifications() async {
    final access = await _notifications.check();
    if (mounted) {
      setState(() => _notificationAccess = access);
    }
  }

  Future<void> _handleLocation(LocationAccess access) async {
    final locations = LocationScope.of(context);
    setState(() => _locationTouched = true);
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

  Future<void> _handleNotifications(NotificationAccess access) async {
    setState(() {
      _notificationTouched = true;
      _requestingNotifications = true;
    });
    try {
      if (access.needsAppSettings) {
        await LocationScope.of(context).openAppSettings();
        return;
      }
      final next = await _notifications.request();
      if (mounted) {
        setState(() => _notificationAccess = next);
      }
    } finally {
      if (mounted) {
        setState(() => _requestingNotifications = false);
      }
    }
  }

  Future<void> _finish() => OnboardingScope.of(context).markSeen();

  void _goTo(int index) {
    if (!_pages.hasClients || index == _index) {
      return;
    }
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = OnboardingPage.slides;
    return Scaffold(
      key: const Key('onboarding-page'),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('onboarding-skip'),
                onPressed: _finish,
                child: const Text('Passer'),
              ),
            ),
            const CityCareLogoMark(size: 44),
            const SizedBox(height: CityCareBrand.spaceSm),
            const CityCareWordmark(fontSize: 20),
            Expanded(
              child: PageView.builder(
                key: const Key('onboarding-carousel'),
                controller: _pages,
                onPageChanged: (index) => setState(() => _index = index),
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  return _SlideBody(
                    slide: slides[index],
                    locationTouched: _locationTouched,
                    notificationTouched: _notificationTouched,
                    notificationAccess: _notificationAccess,
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  _Dot(
                    key: Key('onboarding-dot-$i'),
                    active: i == _index,
                    onTap: () => _goTo(i),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CityCareBrand.spaceLg,
                CityCareBrand.spaceMd,
                CityCareBrand.spaceLg,
                CityCareBrand.spaceLg,
              ),
              child: _ActionBar(
                slide: slides[_index],
                notificationAccess: _notificationAccess,
                requestingNotifications: _requestingNotifications,
                onLocation: _handleLocation,
                onNotifications: _handleNotifications,
                onFinish: _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideBody extends StatelessWidget {
  const _SlideBody({
    required this.slide,
    required this.locationTouched,
    required this.notificationTouched,
    required this.notificationAccess,
  });

  final OnboardingSlide slide;
  final bool locationTouched;
  final bool notificationTouched;
  final NotificationAccess? notificationAccess;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocationScope.of(context),
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CityCareBrand.spaceLg,
            CityCareBrand.spaceMd,
            CityCareBrand.spaceLg,
            CityCareBrand.spaceSm,
          ),
          child: Column(
            children: [
              Semantics(
                label: slide.semanticLabel,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: CityCareBrand.lavender,
                    borderRadius: CityCareBrand.borderRadiusXl,
                  ),
                  child: Icon(slide.icon, size: 40, color: CityCareBrand.violet),
                ),
              ),
              const SizedBox(height: CityCareBrand.spaceLg),
              Text(
                slide.title,
                key: Key('onboarding-title-${slide.kind.name}'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: CityCareBrand.spaceMd),
              Text(
                slide.body,
                key: Key('onboarding-body-${slide.kind.name}'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (slide.kind == OnboardingSlideKind.location)
                _LocationStatus(touched: locationTouched),
              if (slide.kind == OnboardingSlideKind.notifications)
                _NotificationStatus(
                  access: notificationAccess,
                  touched: notificationTouched,
                ),
              if (slide.kind == OnboardingSlideKind.background) ...[
                const SizedBox(height: CityCareBrand.spaceMd),
                const _HonestNote(
                  text:
                      'Rien n’est activé en secret. Le partage en arrière-plan '
                      'reste optionnel : vous l’allumez dans Profil.',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.touched});

  final bool touched;

  @override
  Widget build(BuildContext context) {
    final access = LocationScope.of(context).locationAccess;
    if (access == null) {
      return const SizedBox.shrink();
    }
    final showDenied = touched && access.status == LocationAccessStatus.denied;
    final showAlways = access.status == LocationAccessStatus.granted ||
        access.status == LocationAccessStatus.deniedForever ||
        access.status == LocationAccessStatus.serviceDisabled ||
        access.status == LocationAccessStatus.unavailable;
    if (!showDenied && !showAlways) {
      return const SizedBox.shrink();
    }
    final copy = LocationPermissionCopy.of(access);
    return _StatusCard(
      title: copy.title,
      message: copy.message,
      isOk: access.isGranted,
    );
  }
}

class _NotificationStatus extends StatelessWidget {
  const _NotificationStatus({required this.access, required this.touched});

  final NotificationAccess? access;
  final bool touched;

  @override
  Widget build(BuildContext context) {
    final current = access;
    if (current == null) {
      return const SizedBox.shrink();
    }
    if (current.isGranted) {
      return const _StatusCard(
        title: 'Notifications autorisées',
        message:
            'CityCare pourra afficher un SOS ou une sortie de zone comme '
            'alerte système, en plus de l’onglet Alertes.',
        isOk: true,
      );
    }
    if (current.status == NotificationAccessStatus.unavailable) {
      return const _StatusCard(
        title: 'Notifications indisponibles',
        message:
            'Ce téléphone n’a pas répondu à la demande. Les alertes restent '
            'visibles dans l’application.',
        isOk: false,
      );
    }
    if (!touched && !current.needsAppSettings) {
      return const SizedBox.shrink();
    }
    if (current.needsAppSettings) {
      return const _StatusCard(
        title: 'Notifications bloquées dans les réglages',
        message:
            'L’autorisation a été refusée : le téléphone ne permet plus à '
            'CityCare de la redemander. Ouvrez les réglages de l’application, '
            'puis activez les notifications. Un SOS et une sortie de zone '
            'resteront visibles dans l’onglet Alertes.',
        isOk: false,
      );
    }
    return const _StatusCard(
      title: 'Notifications refusées',
      message:
          'Sans cette autorisation, un SOS et une sortie de zone n’apparaîtront '
          'pas comme une alerte système. Vous pouvez réessayer, ou les activer '
          'plus tard dans les réglages.',
      isOk: false,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.message,
    required this.isOk,
  });

  final String title;
  final String message;
  final bool isOk;

  @override
  Widget build(BuildContext context) {
    final accent = isOk ? CityCareBrand.safe : CityCareBrand.amberDark;
    return Padding(
      padding: const EdgeInsets.only(top: CityCareBrand.spaceMd),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: CityCareBrand.borderRadiusSm,
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CityCareBrand.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: accent),
              ),
              const SizedBox(height: CityCareBrand.spaceXs),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _HonestNote extends StatelessWidget {
  const _HonestNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CityCareBrand.lavender,
        borderRadius: CityCareBrand.borderRadiusSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(CityCareBrand.spaceMd),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CityCareBrand.violetDeep,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.slide,
    required this.notificationAccess,
    required this.requestingNotifications,
    required this.onLocation,
    required this.onNotifications,
    required this.onFinish,
  });

  final OnboardingSlide slide;
  final NotificationAccess? notificationAccess;
  final bool requestingNotifications;
  final Future<void> Function(LocationAccess access) onLocation;
  final Future<void> Function(NotificationAccess access) onNotifications;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    switch (slide.kind) {
      case OnboardingSlideKind.location:
        return _LocationActions(onLocation: onLocation);
      case OnboardingSlideKind.notifications:
        return _NotificationActions(
          access: notificationAccess,
          requesting: requestingNotifications,
          onNotifications: onNotifications,
        );
      case OnboardingSlideKind.background:
        return FilledButton(
          key: const Key('onboarding-finish'),
          onPressed: onFinish,
          child: const Text('Continuer vers CityCare'),
        );
    }
  }
}

class _LocationActions extends StatelessWidget {
  const _LocationActions({required this.onLocation});

  final Future<void> Function(LocationAccess access) onLocation;

  @override
  Widget build(BuildContext context) {
    final locations = LocationScope.of(context);
    return ListenableBuilder(
      listenable: locations,
      builder: (context, _) {
        final access = locations.locationAccess ??
            const LocationAccess(LocationAccessStatus.denied);
        final copy = LocationPermissionCopy.of(access);
        final label = copy.actionLabel ?? 'C’est noté';
        final busy = locations.isRequestingLocationAccess;
        if (access.isGranted) {
          return FilledButton.icon(
            key: const Key('onboarding-allow-location'),
            onPressed: null,
            icon: const Icon(Icons.check),
            label: const Text('Localisation autorisée'),
          );
        }
        return FilledButton.icon(
          key: access.needsAppSettings || access.needsLocationSettings
              ? const Key('onboarding-open-settings')
              : const Key('onboarding-allow-location'),
          onPressed: busy ? null : () => onLocation(access),
          icon: busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(
                  access.needsAppSettings || access.needsLocationSettings
                      ? Icons.settings_outlined
                      : Icons.my_location,
                ),
          label: Text(label),
        );
      },
    );
  }
}

class _NotificationActions extends StatelessWidget {
  const _NotificationActions({
    required this.access,
    required this.requesting,
    required this.onNotifications,
  });

  final NotificationAccess? access;
  final bool requesting;
  final Future<void> Function(NotificationAccess access) onNotifications;

  @override
  Widget build(BuildContext context) {
    final current = access ?? const NotificationAccess(NotificationAccessStatus.denied);
    if (current.isGranted) {
      return FilledButton.icon(
        key: const Key('onboarding-allow-notifications'),
        onPressed: null,
        icon: const Icon(Icons.check),
        label: const Text('Notifications autorisées'),
      );
    }
    final needsSettings = current.needsAppSettings;
    return FilledButton.icon(
      key: needsSettings
          ? const Key('onboarding-open-notification-settings')
          : const Key('onboarding-allow-notifications'),
      onPressed: requesting ? null : () => onNotifications(current),
      icon: requesting
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(needsSettings ? Icons.settings_outlined : Icons.notifications_outlined),
      label: Text(
        needsSettings ? 'Ouvrir les réglages de l’application' : 'Autoriser les notifications',
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: active ? 16 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? CityCareBrand.violet : CityCareBrand.tileBorder,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
