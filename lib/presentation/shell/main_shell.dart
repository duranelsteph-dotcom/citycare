import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../alerts/alert_controller.dart';
import '../alerts/alert_scope.dart';
import '../alerts/hold_sos_fab.dart';
import '../alerts/sos_pages.dart';
import '../auth/auth_scope.dart';
import '../auth/role_capabilities.dart';
import '../auth/role_labels.dart';
import '../cases/case_pages.dart';
import '../cases/case_scope.dart';
import '../circles/circle_invite_page.dart';
import '../circles/circle_scope.dart';
import '../circles/create_circle_sheet.dart';
import '../circles/join_circle_page.dart';
import '../family/children_page.dart';
import '../family/family_controller.dart';
import '../family/family_scope.dart';
import '../family/guardians_page.dart';
import '../family/pairing_page.dart';
import '../family/young_profile_page.dart';
import '../location/background_share_tile.dart';
import '../location/history_page.dart';
import '../location/location_controller.dart';
import '../location/location_scope.dart';
import '../map/care_status.dart';
import '../map/map_home_page.dart';
import '../notifications/notification_controller.dart';
import '../notifications/notification_scope.dart';
import '../notifications/notifications_page.dart';
import '../marketplace/marketplace_page.dart';
import '../prevention/prevention_page.dart';
import '../profile/delete_account_dialog.dart';
import '../profile/profile_photo.dart';
import '../profile/subscription_page.dart';
import '../profile/subscription_scope.dart';
import '../risk/risk_zone_pages.dart';
import '../trackers/kit_page.dart';
import '../zones/parent_zones_hub.dart';
import 'role_home_page.dart';

/// Coquille post-auth : carte centrale + barre d’onglets fixe.
///
/// Accueil = carte. Membres / Alertes / Boutique / Profil réutilisent
/// les pages déjà en place. Le SOS rouge reste visible sur tous les onglets.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

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
      CircleScope.of(context).load();
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

  void _openSos(UserRole role) {
    if (role == UserRole.young) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SosPage()),
      );
      return;
    }
    setState(() => _index = 2);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final isYoung = user.role == UserRole.young;
    return Scaffold(
      key: const Key('main-shell'),
      body: IndexedStack(
        index: _index,
        children: [
          const MapHomePage(),
          isYoung ? const GuardiansPage() : const ChildrenPage(),
          isYoung ? const NotificationsPage() : const GuardianAlertsPage(),
          const MarketplacePage(),
          _ProfileTab(user: user),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: roleShowsSos(user.role)
          ? HoldSosFab(
              role: user.role,
              onShortPress: () => _openSos(user.role),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        key: const Key('main-shell-nav'),
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        selectedItemColor: CityCareBrand.violet,
        unselectedItemColor: CityCareBrand.mutedText,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Membres',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alertes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Boutique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}


/// Extrait profil + déconnexion. Les écrans complets restent en push.
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user});

  final UserAccount user;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final locations = LocationScope.of(context);
    final alerts = AlertScope.of(context);
    final inbox = NotificationScope.of(context);
    final family = FamilyScope.of(context);
    final isYoung = user.role == UserRole.young;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CityCareBrand.violet,
        foregroundColor: Colors.white,
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: auth.logout,
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CityCareBrand.spaceMd,
          CityCareBrand.spaceMd,
          CityCareBrand.spaceMd,
          120,
        ),
        children: [
          Center(child: ProfilePhotoButton(user: user)),
          const SizedBox(height: CityCareBrand.spaceMd),
          Text(
            'Bonjour ${user.fullName}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: CityCareBrand.titleInk),
          ),
          const SizedBox(height: 4),
          Text(
            roleLabel(user.role),
            style: const TextStyle(color: CityCareBrand.lime, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: CityCareBrand.spaceSm),
          Text(
            roleHomeMessage(user.role),
            style: const TextStyle(color: CityCareBrand.mutedText, height: 1.4, fontSize: 14),
          ),
          const SizedBox(height: CityCareBrand.spaceMd),
          ListenableBuilder(
            listenable: Listenable.merge([locations, alerts, inbox, family]),
            builder: (context, _) {
              final status = isYoung
                  ? careStatusForMember(
                      point: locations.latest,
                      youngPersonId: user.youngPersonId,
                      alerts: alerts.items,
                      inbox: inbox.items,
                      isSelf: true,
                      locations: locations,
                    )
                  : _guardianGroupCare(family: family, locations: locations, alerts: alerts, inbox: inbox);
              if (status == null || !status.visible) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: CityCareBrand.spaceMd),
                child: CareStatusBadge(status: status, compact: false, showDisclaimer: true),
              );
            },
          ),
          BackgroundShareTile(
            subtitle: isYoung
                ? 'Opt-in. SOS, zones de sécurité, proches autorisés. '
                    'Android affiche une notification persistante.'
                : 'Si vous partagez votre propre position : SOS, zones, '
                    'proches autorisés. Notification persistante sur Android.',
          ),
          if (user.role == UserRole.authority) ...[
            ListTile(
              key: const Key('profile-authority-alerts'),
              leading: const Icon(Icons.sos),
              title: const Text('Traiter les alertes'),
              subtitle: const Text('SOS reçus — pas un kidnapping confirmé'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GuardianAlertsPage(title: 'Traiter les alertes'),
                ),
              ),
            ),
            ListTile(
              key: const Key('profile-authority-cases'),
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Suivre l’évolution des dossiers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CasesPage(title: 'Évolution des dossiers'),
                ),
              ),
            ),
            ListTile(
              key: const Key('profile-authority-notices'),
              leading: const Icon(Icons.person_search),
              title: const Text('Consulter les avis de recherche'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CasesPage(title: 'Avis de recherche'),
                ),
              ),
            ),
          ],
          if (user.role == UserRole.relative)
            ListTile(
              key: const Key('profile-relative-new-notice'),
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('Nouveau avis de recherche'),
              subtitle: const Text('Déclarer une disparition'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => startMissingPersonDeclaration(context),
            ),
          const SizedBox(height: CityCareBrand.spaceMd),
          ListTile(
            key: const Key('profile-subscription'),
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Abonnement annuel'),
            subtitle: Text(
              SubscriptionScope.maybeOf(context)?.current.isActive == true
                  ? 'Statut : Actif — 12 000 FCFA / an (paiement démo)'
                  : '12 000 FCFA / an (XAF) — paiement démo, aucun débit carte',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SubscriptionPage()),
            ),
          ),
          if (!isYoung)
            ListTile(
              key: const Key('profile-parent-zones'),
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Zones de sécurité des enfants'),
              subtitle: const Text('Maison, école, rayon — vous les définissez'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ParentZonesHubPage()),
              ),
            ),
          if (isYoung) ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Mon profil'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const YoungProfilePage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.watch),
              title: const Text('Mon kit IoT'),
              subtitle: const Text('Le kit parle au serveur, pas à l’app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const KitPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.pin),
              title: const Text('Code de rattachement'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PairingPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historique des déplacements'),
              subtitle: const Text('Liste de trajets — pas un rapport de conduite'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
              ),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.apps_outlined),
            title: const Text('Toutes les fonctions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RoleHomePage()),
            ),
          ),
          ListTile(
            key: const Key('profile-marketplace'),
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Boutique'),
            subtitle: const Text('Kits GPS et traceurs — commande sans paiement réel'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MarketplacePage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Prévention'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PreventionPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.report_gmailerrorred_outlined),
            title: const Text('Zones à risque'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RiskZonesPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_search),
            title: const Text('Dossiers de disparition'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CasesPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Mes cercles'),
            subtitle: const Text('Regrouper des proches — sans remplacer les liens de confiance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showCreateCircleSheet(context),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Rejoindre un cercle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const JoinCirclePage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Partager le code du cercle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CircleInvitePage()),
            ),
          ),
          const SizedBox(height: CityCareBrand.spaceMd),
          OutlinedButton.icon(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
          const SizedBox(height: CityCareBrand.spaceSm),
          TextButton(
            key: const Key('profile-delete-account'),
            style: TextButton.styleFrom(foregroundColor: CityCareBrand.sos),
            onPressed: auth.isBusy ? null : () => showDeleteAccountDialog(context),
            child: const Text('Supprimer mon compte'),
          ),
        ],
      ),
    );
  }
}

CareStatus? _guardianGroupCare({
  required FamilyController family,
  required LocationController locations,
  required AlertController alerts,
  required NotificationController inbox,
}) {
  return worstCareStatus([
    for (final link in family.active)
      careStatusForMember(
        point: locations.familyLatest[link.youngPersonId],
        youngPersonId: link.youngPersonId,
        alerts: alerts.items,
        inbox: inbox.items,
      ),
  ]);
}
