import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../alerts/alert_scope.dart';
import '../alerts/sos_pages.dart';
import '../auth/auth_scope.dart';
import '../auth/role_labels.dart';
import '../cases/case_pages.dart';
import '../cases/case_scope.dart';
import '../family/children_page.dart';
import '../family/family_scope.dart';
import '../family/guardians_page.dart';
import '../family/link_child_page.dart';
import '../family/pairing_page.dart';
import '../family/young_profile_page.dart';
import '../location/emergency_page.dart';
import '../location/location_scope.dart';
import '../location/position_pages.dart';
import '../notifications/notification_scope.dart';
import '../notifications/notifications_page.dart';
import '../prevention/prevention_page.dart';
import '../risk/risk_zone_pages.dart';
import '../trackers/kit_copy.dart';
import '../trackers/kit_page.dart';
import '../widgets/citycare_logo.dart';
import '../zones/zone_pages.dart';

class RoleHomePage extends StatefulWidget {
  const RoleHomePage({super.key});

  @override
  State<RoleHomePage> createState() => _RoleHomePageState();
}

class _RoleHomePageState extends State<RoleHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      NotificationScope.of(context).load();
      await LocationScope.of(context).flushPending();
      if (!mounted) {
        return;
      }
      await AlertScope.of(context).flushPending();
      if (!mounted) {
        return;
      }
      final role = AuthScope.of(context).user?.role;
      if (role == UserRole.young) {
        AlertScope.of(context).loadMineAsYoung();
        CaseScope.of(context).loadMineAsYoung();
      } else if (role == UserRole.parent || role == UserRole.relative) {
        FamilyScope.of(context).loadForGuardian();
        AlertScope.of(context).loadMineAsGuardian();
        CaseScope.of(context).loadMineAsGuardian();
        LocationScope.of(context).loadReceivedShares();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final inbox = NotificationScope.of(context);
    final alerts = AlertScope.of(context);
    final locations = LocationScope.of(context);
    final cases = CaseScope.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: CityCareBrand.spaceMd,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CityCareLogoMark(size: 30),
            const SizedBox(width: CityCareBrand.spaceSm + 2),
            CityCareWordmark(fontSize: 20, accentColor: Theme.of(context).colorScheme.primary),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Conseils de prévention',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PreventionPage()),
            ),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: _SosFab(role: user.role),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CityCareBrand.spaceMd,
          CityCareBrand.spaceMd,
          CityCareBrand.spaceMd,
          // Marge basse généreuse : le bouton SOS flottant ne doit jamais
          // recouvrir la dernière entrée de la liste.
          96,
        ),
        children: [
          _HomeHeader(user: user),
          const SizedBox(height: CityCareBrand.spaceMd),
          ListenableBuilder(
            listenable: Listenable.merge([locations, alerts]),
            builder: (context, _) {
              final pending = locations.queue.pendingCount;
              if (pending == 0) {
                return const SizedBox.shrink();
              }
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: Text('$pending élément(s) en attente hors ligne'),
                  subtitle: const Text(
                    'Horodatage du téléphone conservé — pas Last Write Wins. '
                    'Un SOS n’est pas encore transmis aux contacts.',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await locations.flushPending();
                      await alerts.flushPending();
                    },
                    child: const Text('Réessayer'),
                  ),
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: locations,
            builder: (context, _) {
              final shares = locations.receivedShares.where((share) => share.isActive).toList();
              if (shares.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  for (final share in shares)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.share_location),
                        title: Text('Partage limité · ${share.youngDisplayName ?? 'Jeune'}'),
                        subtitle: Text(
                          'Jusqu’à ${knownClock(share.expiresAt)} — dernière position connue, pas un GPS continu.',
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChildPositionPage(
                              youngPersonId: share.youngPersonId,
                              displayName: share.youngDisplayName ?? 'Jeune',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          ListenableBuilder(
            listenable: Listenable.merge([alerts, cases]),
            builder: (context, _) {
              final openSos = alerts.items.where((item) => item.isOpen).firstOrNull ?? alerts.openSos;
              final openCase = cases.items.where((item) => item.isOpen).firstOrNull;
              final youngPersonId = openSos?.youngPersonId ?? openCase?.youngPersonId ?? user.youngPersonId;
              final displayName = openSos?.youngDisplayName ?? openCase?.youngDisplayName ?? user.fullName;
              if (youngPersonId == null || (openSos == null && openCase == null && user.role != UserRole.young)) {
                return const SizedBox.shrink();
              }
              if (user.role == UserRole.young && openSos == null && openCase == null) {
                return const SizedBox.shrink();
              }
              return Card(
                child: ListTile(
                  leading: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
                  title: const Text('MODE URGENCE'),
                  subtitle: const Text('Dernière position connue, pas un suivi en direct, pas un kidnapping confirmé'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EmergencyModePage(
                        youngPersonId: youngPersonId,
                        displayName: displayName,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: inbox,
            builder: (context, _) {
              final unread = inbox.unreadCount;
              return _HomeTile(
                icon: Icons.notifications_outlined,
                badgeCount: unread,
                title: 'Notifications',
                subtitle: 'Inbox in-app, plus push FCM si configuré — pas un kidnapping confirmé',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
                ),
              );
            },
          ),
          _HomeTile(
            icon: Icons.report_gmailerrorred_outlined,
            accent: CityCareBrand.amberDark,
            title: 'Zones à risque',
            subtitle: 'Prévention à l’entrée — pas un kidnapping',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RiskZonesPage()),
            ),
          ),
          if (user.role == UserRole.young) ...[
            const _HomeSectionTitle('Demander de l’aide'),
            _HomeTile(
              icon: Icons.sos,
              accent: CityCareBrand.sos,
              title: 'SOS',
              subtitle: 'Demander de l’aide — pas un kidnapping confirmé',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SosPage()),
              ),
            ),
            const _HomeSectionTitle('Mon kit et mon compte'),
            _HomeTile(
              icon: Icons.watch,
              title: 'Mon kit IoT',
              subtitle: 'Le kit parle au serveur, pas à l’app',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const KitPage()),
              ),
            ),
            _HomeTile(
              icon: Icons.person_outline,
              title: 'Mon profil',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const YoungProfilePage()),
              ),
            ),
            _HomeTile(
              icon: Icons.pin,
              title: 'Code de rattachement',
              subtitle: 'À donner à un parent ou un proche',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PairingPage()),
              ),
            ),
            _HomeTile(
              icon: Icons.groups_outlined,
              title: 'Mes contacts de confiance',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GuardiansPage()),
              ),
            ),
            const _HomeSectionTitle('Ma position et mes zones'),
            _HomeTile(
              icon: Icons.my_location,
              title: 'Ma position',
              subtitle: 'GPS de ce téléphone, sur la carte',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MyPositionPage()),
              ),
            ),
            _HomeTile(
              icon: Icons.shield_outlined,
              accent: CityCareBrand.safe,
              title: 'Mes zones de sécurité',
              subtitle: 'Consultation seulement — le parent les définit',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SafetyZonesPage()),
              ),
            ),
            const _HomeSectionTitle('Disparition'),
            _HomeTile(
              icon: Icons.person_search,
              title: 'Dossiers de disparition',
              subtitle: 'Dossier me concernant — pas un kidnapping confirmé',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CasesPage()),
              ),
            ),
          ],
          if (user.role == UserRole.parent || user.role == UserRole.relative) ...[
            const _HomeSectionTitle('Demandes d’aide'),
            _HomeTile(
              icon: Icons.sos,
              accent: CityCareBrand.sos,
              title: 'Alertes SOS',
              subtitle: 'Demandes d’aide du jeune — pas un kidnapping confirmé',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GuardianAlertsPage()),
              ),
            ),
            const _HomeSectionTitle('Ma famille'),
            _HomeTile(
              icon: Icons.family_restroom,
              title: 'Mes enfants / jeunes',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ChildrenPage()),
              ),
            ),
            _HomeTile(
              icon: Icons.link,
              title: 'Rattacher un jeune',
              subtitle: 'Code ou invitation par téléphone',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LinkChildPage()),
              ),
            ),
            _HomeTile(
              icon: Icons.shield_outlined,
              accent: CityCareBrand.safe,
              title: 'Zones de sécurité',
              subtitle: 'École, maison, jours et heures',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ChildrenPage()),
              ),
            ),
            const _HomeSectionTitle('Disparition'),
            _HomeTile(
              icon: Icons.person_search,
              title: 'Dossiers de disparition',
              subtitle: 'Déclarer une disparition — pas un kidnapping confirmé',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CasesPage()),
              ),
            ),
          ],
          const _HomeSectionTitle('Comprendre et prévenir'),
          _HomeTile(
            icon: Icons.menu_book_outlined,
            accent: CityCareBrand.secondary,
            title: 'Prévention',
            subtitle: 'Trois réflexes contre l’enlèvement — à lire avec l’enfant',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PreventionPage()),
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête d'accueil : identité de marque, salutation et rôle en un coup d'œil.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.user});

  final UserAccount user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CityCareBrand.spaceMd + 2),
      decoration: const BoxDecoration(
        gradient: CityCareBrand.brandGradient,
        borderRadius: CityCareBrand.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CityCareLogoMark(size: 44, monochromeColor: Colors.white),
              const SizedBox(width: CityCareBrand.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour ${user.fullName}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roleLabel(user.role),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CityCareBrand.spaceMd),
          Text(
            roleHomeMessage(user.role),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), height: 1.4, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Titre de regroupement : découpe la liste en intentions ("Demander de
/// l'aide", "Ma position"…) pour qu'on trouve sans lire tous les libellés.
class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CityCareBrand.spaceXs,
        CityCareBrand.spaceMd,
        CityCareBrand.spaceXs,
        CityCareBrand.spaceSm,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

/// Entrée de navigation de l'accueil : grande cible tactile, icône colorée
/// selon la gravité, sous-titre qui dit ce que la fonction ne fait pas.
class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.accent,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? accent;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    final leading = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: CityCareBrand.borderRadiusSm,
      ),
      child: Icon(icon, color: color, size: 22),
    );
    final text = subtitle;
    return Card(
      child: ListTile(
        leading: badgeCount > 0
            ? Badge(label: Text('$badgeCount'), child: leading)
            : leading,
        title: Text(title),
        subtitle: text == null ? null : Text(text),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

/// Bouton d'urgence flottant.
///
/// Il reste visible pendant le défilement : en situation de panique, on ne
/// doit pas avoir à chercher où appuyer. Le libellé diffère du titre des
/// entrées de liste pour ne pas créer deux cibles portant le même nom.
class _SosFab extends StatelessWidget {
  const _SosFab({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    if (role == UserRole.young) {
      return FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SosPage()),
        ),
        icon: const Icon(Icons.sos, size: 28),
        label: const Text('Alerte SOS'),
        tooltip: 'Demander de l’aide immédiatement',
      );
    }
    if (role == UserRole.parent || role == UserRole.relative) {
      return FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const GuardianAlertsPage()),
        ),
        icon: const Icon(Icons.notifications_active_outlined, size: 26),
        label: const Text('Voir les alertes'),
        tooltip: 'Demandes d’aide reçues',
      );
    }
    return const SizedBox.shrink();
  }
}
