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
import '../circles/circle_scope.dart';
import '../circles/create_circle_sheet.dart';
import '../circles/join_circle_page.dart';
import '../family/children_page.dart';
import '../family/family_scope.dart';
import '../family/guardians_page.dart';
import '../family/link_child_page.dart';
import '../family/pairing_page.dart';
import '../family/young_profile_page.dart';
import '../location/emergency_page.dart';
import '../location/history_page.dart';
import '../location/location_scope.dart';
import '../location/position_pages.dart';
import '../notifications/notification_scope.dart';
import '../notifications/notifications_page.dart';
import '../marketplace/marketplace_page.dart';
import '../prevention/prevention_page.dart';
import '../risk/risk_zone_pages.dart';
import '../trackers/kit_copy.dart';
import '../trackers/kit_page.dart';
import '../zones/parent_zones_hub.dart';
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
      CircleScope.of(context).load();
      final role = AuthScope.of(context).user?.role;
      if (role == UserRole.young) {
        AlertScope.of(context).loadMineAsYoung();
        CaseScope.of(context).loadMineAsYoung();
      } else if (role == UserRole.parent || role == UserRole.relative) {
        FamilyScope.of(context).loadForGuardian();
        AlertScope.of(context).loadMineAsGuardian();
        CaseScope.of(context).loadMineAsGuardian();
        LocationScope.of(context).loadReceivedShares();
      } else if (role == UserRole.authority) {
        AlertScope.of(context).loadMineAsGuardian();
        CaseScope.of(context).loadMineAsGuardian();
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
      key: const Key('toutes-fonctions-page'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: CityCareBrand.violet,
        foregroundColor: Colors.white,
        title: const Text('Toutes les fonctions'),
        actions: [
          IconButton(
            tooltip: 'Conseils de prévention',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PreventionPage()),
            ),
            icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CityCareBrand.spaceMd,
          CityCareBrand.spaceMd,
          CityCareBrand.spaceMd,
          // Marge basse généreuse : le bouton SOS flottant ne doit jamais
          // recouvrir la dernière entrée de la liste.
          120,
        ),
        children: [
          _HomeHeader(user: user),
          const SizedBox(height: CityCareBrand.spaceSm),
          const Text(
            key: Key('toutes-fonctions-intro'),
            'Catalogue groupé par intention. La carte reste l’accueil. '
            'Un SOS n’est pas un kidnapping confirmé.',
            style: TextStyle(color: CityCareBrand.mutedText, height: 1.4, fontSize: 14),
          ),
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
          if (user.role == UserRole.authority) ...[
            const _HomeSectionTitle('Mission autorité'),
            _HomeTile(
              key: const Key('role-home-authority-alerts'),
              icon: Icons.sos,
              accent: CityCareBrand.sos,
              title: 'Traiter les alertes',
              subtitle: 'SOS reçus — pas un kidnapping confirmé',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GuardianAlertsPage(title: 'Traiter les alertes'),
                ),
              ),
            ),
            _HomeTile(
              key: const Key('role-home-authority-cases'),
              icon: Icons.folder_open_outlined,
              title: 'Suivre l’évolution des dossiers',
              subtitle: 'Statuts, recherche, clôture',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CasesPage(title: 'Évolution des dossiers'),
                ),
              ),
            ),
            _HomeTile(
              key: const Key('role-home-authority-notices'),
              icon: Icons.person_search,
              title: 'Consulter les avis de recherche',
              subtitle: 'Avis et dossiers de disparition',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CasesPage(title: 'Avis de recherche'),
                ),
              ),
            ),
          ],
          if (user.role == UserRole.relative) ...[
            const _HomeSectionTitle('Avis de recherche'),
            _HomeTile(
              key: const Key('role-home-relative-new-notice'),
              icon: Icons.campaign_outlined,
              accent: CityCareBrand.sos,
              title: 'Nouveau avis de recherche',
              subtitle: 'Déclarer une disparition — pas un kidnapping confirmé',
              onTap: () => startMissingPersonDeclaration(context),
            ),
          ],
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
            _SosTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SosPage()),
              ),
            ),
            const _HomeSectionTitle('Cercles'),
            _HomeTile(
              icon: Icons.groups_outlined,
              title: 'Créer un cercle',
              subtitle: 'Nommer un groupe — sans remplacer les liens de confiance',
              onTap: () => showCreateCircleSheet(context),
            ),
            _HomeTile(
              icon: Icons.vpn_key_outlined,
              title: 'Rejoindre un cercle',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const JoinCirclePage()),
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
              icon: Icons.history,
              title: 'Historique des déplacements',
              subtitle: 'Liste de trajets — pas un rapport de conduite',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
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
            const _HomeSectionTitle('Cercles'),
            _HomeTile(
              icon: Icons.groups_outlined,
              title: 'Créer un cercle',
              subtitle: 'Nommer un groupe — sans remplacer les liens de confiance',
              onTap: () => showCreateCircleSheet(context),
            ),
            _HomeTile(
              icon: Icons.vpn_key_outlined,
              title: 'Rejoindre un cercle',
              subtitle: 'Code à 6 caractères',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const JoinCirclePage()),
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
              icon: Icons.history,
              title: 'Historique des déplacements',
              subtitle: 'Trajets du jeune autorisé — pas un rapport de conduite',
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
              subtitle: 'Maison, école, rayon — vous les définissez',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ParentZonesHubPage()),
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
          const _HomeSectionTitle('Boutique'),
          _HomeTile(
            icon: Icons.storefront_outlined,
            title: 'Boutique',
            subtitle: 'Kits GPS et traceurs — prix FCFA, commande stub',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MarketplacePage()),
            ),
          ),
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

/// En-tête blanc : salutation + CTA pilule verte (pas un bandeau dégradé).
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.user});

  final UserAccount user;

  @override
  Widget build(BuildContext context) {
    final isYoung = user.role == UserRole.young;
    final isAuthority = user.role == UserRole.authority;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bonjour ${user.fullName}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: CityCareBrand.titleInk),
        ),
        const SizedBox(height: 4),
        Text(
          roleLabel(user.role),
          style: const TextStyle(color: CityCareBrand.lime, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: CityCareBrand.spaceMd),
        Text(
          roleHomeMessage(user.role),
          style: const TextStyle(color: CityCareBrand.mutedText, height: 1.4, fontSize: 14),
        ),
        const SizedBox(height: CityCareBrand.spaceLg),
        FilledButton.icon(
          onPressed: () {
            if (isAuthority) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GuardianAlertsPage(title: 'Traiter les alertes'),
                ),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => isYoung ? const MyPositionPage() : const ChildrenPage(),
              ),
            );
          },
          icon: Icon(
            isAuthority
                ? Icons.sos
                : (isYoung ? Icons.map_outlined : Icons.family_restroom),
          ),
          label: Text(
            isAuthority ? 'Traiter les alertes' : (isYoung ? 'Ouvrir la carte' : 'Voir les enfants'),
          ),
        ),
      ],
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

/// Tuile Benskin : fond blanc, bordure grise, icône verte, pas d’ombre.
class _HomeTile extends StatelessWidget {
  const _HomeTile({
    super.key,
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
    final color = accent ?? CityCareBrand.lime;
    final leading = Icon(icon, color: color, size: 26);
    final text = subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: CityCareBrand.spaceSm),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: CityCareBrand.borderRadiusSm,
          side: const BorderSide(color: CityCareBrand.tileBorder),
        ),
        child: ListTile(
          leading: badgeCount > 0 ? Badge(label: Text('$badgeCount'), child: leading) : leading,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: CityCareBrand.titleInk)),
          subtitle: text == null ? null : Text(text, style: const TextStyle(color: CityCareBrand.mutedText, fontSize: 13)),
          trailing: const Icon(Icons.chevron_right, color: CityCareBrand.mutedText),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Tuile SOS : seule exception rouge, inratable, même libellé « SOS ».
class _SosTile extends StatelessWidget {
  const _SosTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CityCareBrand.spaceSm),
      child: Material(
        color: CityCareBrand.sos,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sos, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'SOS',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

