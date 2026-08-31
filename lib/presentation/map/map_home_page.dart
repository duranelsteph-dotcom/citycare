import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../alerts/alert_controller.dart';
import '../alerts/alert_scope.dart';
import '../auth/auth_scope.dart';
import '../cases/case_controller.dart';
import '../cases/case_pages.dart';
import '../cases/case_scope.dart';
import '../circles/circle_controller.dart';
import '../circles/circle_invite_page.dart';
import '../circles/circle_scope.dart';
import '../circles/create_circle_sheet.dart';
import '../circles/join_circle_page.dart';
import '../family/family_controller.dart';
import '../family/family_scope.dart';
import '../family/link_child_page.dart';
import '../location/emergency_page.dart';
import '../location/location_controller.dart';
import '../location/location_map.dart';
import '../location/location_scope.dart';
import '../location/position_pages.dart';
import 'member_sheet.dart';
import '../notifications/notification_controller.dart';
import '../notifications/notification_scope.dart';
import '../notifications/notifications_page.dart';
import '../marketplace/marketplace_page.dart';
import '../prevention/prevention_page.dart';
import '../profile/subscription_page.dart';
import '../risk/risk_zone_controller.dart';
import '../risk/risk_zone_scope.dart';
import '../shell/role_home_page.dart';
import '../trackers/kit_copy.dart';
import '../alerts/sos_pages.dart';
import '../zones/parent_zones_hub.dart';
import '../zones/zone_controller.dart';
import '../zones/zone_pages.dart';
import '../zones/zone_scope.dart';

/// Accueil carte : moitié carte, moitié liste (split Life360).
///
/// Parent / proche : pastilles des jeunes liés déjà autorisés.
/// Jeune : sa dernière position + zones si le contrôleur les a déjà.
class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  String? _selectedMemberId;
  double? _focusLatitude;
  double? _focusLongitude;
  int _focusGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    final role = AuthScope.of(context).user?.role;
    final locations = LocationScope.of(context);
    final circles = CircleScope.of(context);
    NotificationScope.of(context).load();
    if (role == UserRole.young) {
      final family = FamilyScope.of(context);
      ZoneScope.of(context).loadMine();
      RiskZoneScope.of(context).load();
      await family.loadForYoung();
      if (!mounted) {
        return;
      }
      await circles.load();
      if (!mounted) {
        return;
      }
      await locations.loadMyShares();
      if (!mounted) {
        return;
      }
      await locations.watchMine();
      return;
    }
    if (role == UserRole.authority) {
      AlertScope.of(context).loadMineAsGuardian();
      CaseScope.of(context).loadMineAsGuardian();
      RiskZoneScope.of(context).load();
      await circles.load();
      return;
    }
    if (role == UserRole.parent || role == UserRole.relative) {
      final family = FamilyScope.of(context);
      await family.loadForGuardian();
      if (!mounted) {
        return;
      }
      await circles.load();
      if (!mounted) {
        return;
      }
      await locations.loadReceivedShares();
      if (!mounted) {
        return;
      }
      final ids = <String>{
        ...family.active.map((link) => link.youngPersonId),
        ...locations.receivedShares.where((share) => share.isActive).map((share) => share.youngPersonId),
        ...circles.members
            .where((member) => member.youngPersonId != null && (member.canViewLocation))
            .map((member) => member.youngPersonId!),
      };
      await locations.loadFamilyLatest(ids);
      if (!mounted) {
        return;
      }
      // GPS de cet appareil : pastille « moi » (nom + durée) sur la carte.
      await locations.tryCurrentFix();
    }
  }

  void _openMenu() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoleHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final family = FamilyScope.of(context);
    final circles = CircleScope.of(context);
    final locations = LocationScope.of(context);
    final zones = ZoneScope.of(context);
    final risk = RiskZoneScope.of(context);
    final alerts = AlertScope.of(context);
    final cases = CaseScope.of(context);
    final inbox = NotificationScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([family, circles, locations, zones, risk, alerts, cases, inbox]),
      builder: (context, _) {
        final circleSelected = circles.selected != null;
        final members = user.role == UserRole.young
            ? (circleSelected
                ? mapMembersForCircle(
                    user: user,
                    members: circles.members,
                    locations: locations,
                    alerts: alerts.items,
                    inbox: inbox.items,
                  )
                : mapMembersForYoung(
                    user: user,
                    family: family,
                    locations: locations,
                    alerts: alerts.items,
                    inbox: inbox.items,
                  ))
            : (circleSelected
                ? mapMembersForCircle(
                    user: user,
                    members: circles.members,
                    locations: locations,
                    alerts: alerts.items,
                    inbox: inbox.items,
                  )
                : mapMembersForGuardian(
                    family: family,
                    locations: locations,
                    alerts: alerts.items,
                    inbox: inbox.items,
                  ));
        final selectedCare = members
            .where((member) => member.id == _selectedMemberId)
            .map((member) => member.displayCare)
            .whereType<CareStatus>()
            .where((status) => status.visible)
            .firstOrNull;
        // Split net Life360 : carte en haut, liste en bas, même flex.
        final showMembers = user.role == UserRole.young ||
            user.role == UserRole.parent ||
            user.role == UserRole.relative;
        return Column(
          children: [
            Expanded(
              key: const Key('map-home-map-half'),
              flex: 1,
              child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: _map(
                      user: user,
                      family: family,
                      circles: circles,
                      locations: locations,
                      zones: zones,
                      risk: risk,
                      alerts: alerts,
                      inbox: inbox,
                      selectedCare: selectedCare,
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: SingleChildScrollView(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MapTopBar(
                          circles: circles,
                          unread: inbox.unreadCount,
                          onNotifications: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
                          ),
                          onPrevention: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const PreventionPage()),
                          ),
                          onMenu: _openMenu,
                          onRefresh: locations.isBusy ? null : _refresh,
                          onCreateCircle: () => showCreateCircleSheet(context),
                          onJoinCircle: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const JoinCirclePage()),
                          ),
                          onInvite: circles.selected == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => const CircleInvitePage()),
                                  ),
                          onLeave: circles.selected == null
                              ? null
                              : () => _confirmLeave(circles),
                        ),
                        if (locations.isBusy) const LinearProgressIndicator(minHeight: 2),
                        _OfflineBanner(locations: locations, alerts: alerts),
                        _ShareBanners(locations: locations),
                        _AnomalyBanner(inbox: inbox),
                        _EmergencyBanner(user: user, alerts: alerts, cases: cases),
                      ],
                    ),
                    ),
                  ),
                ],
              ),
              ),
            ),
            if (showMembers)
              Expanded(
                key: const Key('map-home-list-half'),
                flex: 1,
                child: ClipRect(
                child: MapMembersSheet(
                  members: members,
                  selectedId: _selectedMemberId,
                  onSelect: (member) => _onMemberTap(member: member, locations: locations),
                  onOpenDetail: (member) => _openMemberDetail(member),
                  onLinkChild: user.role == UserRole.young
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const JoinCirclePage()),
                          )
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const LinkChildPage()),
                          ),
                  emptyTitle: circleSelected
                      ? 'Aucun autre membre'
                      : (user.role == UserRole.young ? 'Aucun contact de confiance' : 'Aucun jeune rattaché'),
                  emptySubtitle: circleSelected
                      ? 'Invitez un proche avec le code du cercle'
                      : (user.role == UserRole.young
                          ? 'Les gardiens apparaîtront ici, avec le statut de partage.'
                          : 'Code ou invitation par téléphone'),
                  headline: circles.selected?.name ?? 'Groupe de confiance',
                  shortcuts: _shortcuts(user: user, circles: circles),
                ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _onMemberTap({
    required MapMemberRow member,
    required LocationController locations,
  }) {
    var lat = member.latitude;
    var lng = member.longitude;
    if (member.kind == MapMemberKind.self && lat == null) {
      lat = locations.unsyncedFix?.latitude;
      lng = locations.unsyncedFix?.longitude;
    }
    setState(() {
      _selectedMemberId = member.id;
      if (lat != null && lng != null) {
        _focusLatitude = lat;
        _focusLongitude = lng;
        _focusGeneration += 1;
      }
    });
    // Sans pastille : on ouvre le détail déjà existant (position / trajectoire).
    if (lat == null && member.canOpenDetail) {
      _openMemberDetail(member);
    }
  }

  void _openMemberDetail(MapMemberRow member) {
    if (member.kind == MapMemberKind.self) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MyPositionPage()),
      );
      return;
    }
    final youngPersonId = member.youngPersonId;
    if (youngPersonId == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChildPositionPage(
          youngPersonId: youngPersonId,
          displayName: member.name,
        ),
      ),
    );
  }

  Future<void> _confirmLeave(CircleController circles) async {
    final circle = circles.selected;
    if (circle == null) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quitter ${circle.name} ?'),
        content: const Text(
          'Vous quittez le cercle seulement. Les liens de confiance (GuardianLink) '
          'restent en place s’ils sont encore utiles.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Quitter')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await circles.leave(circle.id);
    }
  }

  List<MapShortcutAction> _shortcuts({
    required UserAccount user,
    required CircleController circles,
  }) {
    final isYoung = user.role == UserRole.young;
    final isGuardian = user.role == UserRole.parent || user.role == UserRole.relative;
    final isAuthority = user.role == UserRole.authority;
    final isRelative = user.role == UserRole.relative;
    return [
      if (isAuthority) ...[
        MapShortcutAction(
          id: 'treat-alerts',
          icon: Icons.sos,
          label: 'Traiter les alertes',
          subtitle: 'SOS reçus',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const GuardianAlertsPage(title: 'Traiter les alertes'),
            ),
          ),
        ),
        MapShortcutAction(
          id: 'follow-cases',
          icon: Icons.folder_open_outlined,
          label: 'Suivre les dossiers',
          subtitle: 'Évolution',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CasesPage(title: 'Évolution des dossiers'),
            ),
          ),
        ),
        MapShortcutAction(
          id: 'search-notices',
          icon: Icons.person_search,
          label: 'Avis de recherche',
          subtitle: 'Consulter',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CasesPage(title: 'Avis de recherche'),
            ),
          ),
        ),
      ],
      if (isRelative || user.role == UserRole.parent)
        MapShortcutAction(
          id: 'new-notice',
          icon: Icons.campaign_outlined,
          label: 'Nouveau avis',
          subtitle: 'De recherche',
          onTap: () => startMissingPersonDeclaration(context),
        ),
      MapShortcutAction(
        id: 'invite',
        icon: Icons.person_add_alt_1_outlined,
        label: 'Inviter',
        subtitle: 'Code cercle',
        onTap: () {
          if (circles.selected != null) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CircleInvitePage()),
            );
            return;
          }
          if (isYoung) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const JoinCirclePage()),
            );
            return;
          }
          showCreateCircleSheet(context);
        },
      ),
      MapShortcutAction(
        id: 'zones',
        icon: Icons.shield_outlined,
        label: 'Zones',
        subtitle: 'Sécurité',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => isGuardian ? const ParentZonesHubPage() : const SafetyZonesPage(),
            ),
          );
        },
      ),
      MapShortcutAction(
        id: 'prevention',
        icon: Icons.menu_book_outlined,
        label: 'Prévention',
        subtitle: 'Conseils',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PreventionPage()),
        ),
      ),
      MapShortcutAction(
        id: 'marketplace',
        icon: Icons.storefront_outlined,
        label: 'Boutique',
        subtitle: 'Kits GPS',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MarketplacePage()),
        ),
      ),
      MapShortcutAction(
        id: 'subscription',
        icon: Icons.workspace_premium_outlined,
        label: 'Abonnement',
        subtitle: '12 000 FCFA',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SubscriptionPage()),
        ),
      ),
      if (isYoung)
        MapShortcutAction(
          id: 'sos',
          icon: Icons.sos,
          label: 'SOS',
          subtitle: 'Demander de l’aide',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SosPage()),
          ),
        )
      else
        MapShortcutAction(
          id: 'position',
          icon: Icons.share_location_outlined,
          label: 'Position',
          subtitle: 'Ma pastille',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MyPositionPage()),
          ),
        ),
    ];
  }

  Widget _map({
    required UserAccount user,
    required FamilyController family,
    required CircleController circles,
    required LocationController locations,
    required ZoneController zones,
    required RiskZoneController risk,
    required AlertController alerts,
    required NotificationController inbox,
    CareStatus? selectedCare,
  }) {
    if (user.role == UserRole.young) {
      return LocationMapView(
        latitude: locations.mapLatitude,
        longitude: locations.mapLongitude,
        accuracyMeters: locations.unsyncedFix?.accuracy ?? locations.latest?.accuracy,
        isStale: locations.mapPointIsStale,
        isUnsynced: locations.hasUnsyncedLocations,
        isLastKnownOnly: locations.mapUsesLastKnownOnly,
        careStatus: selectedCare ??
            careStatusForMember(
              point: locations.latest,
              youngPersonId: user.youngPersonId,
              alerts: alerts.items,
              inbox: inbox.items,
              isSelf: true,
              locations: locations,
            ),
        pins: mapPinsForYoung(
          user: user,
          locations: locations,
          selectedId: _selectedMemberId,
          alerts: alerts.items,
          inbox: inbox.items,
        ),
        focusLatitude: _focusLatitude,
        focusLongitude: _focusLongitude,
        focusGeneration: _focusGeneration,
        circles: [
          for (final zone in zones.zones)
            MapCircle(
              latitude: zone.latitude,
              longitude: zone.longitude,
              radiusMeters: zone.radiusMeters,
              isActive: zone.isActive,
            ),
          for (final zone in risk.zones)
            MapCircle(
              latitude: zone.latitude,
              longitude: zone.longitude,
              radiusMeters: zone.radiusMeters,
              isActive: zone.isActive,
              isRisk: true,
            ),
        ],
      );
    }

    final selfPin = mapPinForSelf(
      user: user,
      locations: locations,
      selectedId: _selectedMemberId,
      alerts: alerts.items,
      inbox: inbox.items,
    );
    final others = circles.selected != null
        ? mapPinsForCircle(
            user: user,
            members: circles.members,
            locations: locations,
            selectedId: _selectedMemberId,
            alerts: alerts.items,
            inbox: inbox.items,
          )
        : mapPinsForGuardian(
            family: family,
            locations: locations,
            selectedId: _selectedMemberId,
            alerts: alerts.items,
            inbox: inbox.items,
          );
    return LocationMapView(
      latitude: locations.mapLatitude,
      longitude: locations.mapLongitude,
      accuracyMeters: locations.unsyncedFix?.accuracy ?? locations.latest?.accuracy,
      isStale: locations.mapPointIsStale,
      isUnsynced: locations.hasUnsyncedLocations,
      isLastKnownOnly: locations.mapUsesLastKnownOnly,
      careStatus: selectedCare,
      pins: [
        if (selfPin != null) selfPin,
        ...others.where((pin) => pin.id != selfPin?.id),
      ],
      focusLatitude: _focusLatitude,
      focusLongitude: _focusLongitude,
      focusGeneration: _focusGeneration,
    );
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
    required this.circles,
    required this.unread,
    required this.onNotifications,
    required this.onPrevention,
    required this.onMenu,
    required this.onRefresh,
    required this.onCreateCircle,
    required this.onJoinCircle,
    this.onInvite,
    this.onLeave,
  });

  final CircleController circles;
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onPrevention;
  final VoidCallback onMenu;
  final VoidCallback? onRefresh;
  final VoidCallback onCreateCircle;
  final VoidCallback onJoinCircle;
  final VoidCallback? onInvite;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CityCareBrand.violet.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: _CircleSelector(
                circles: circles,
                onCreate: onCreateCircle,
                onJoin: onJoinCircle,
                onInvite: onInvite,
                onLeave: onLeave,
              ),
            ),
            IconButton(
              tooltip: 'Actualiser',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Conseils de prévention',
              onPressed: onPrevention,
              icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotifications,
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_outlined, color: Colors.white),
              ),
            ),
            IconButton(
              key: const Key('shell-more'),
              tooltip: 'Toutes les fonctions',
              onPressed: onMenu,
              icon: const Icon(Icons.menu, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleSelector extends StatelessWidget {
  const _CircleSelector({
    required this.circles,
    required this.onCreate,
    required this.onJoin,
    this.onInvite,
    this.onLeave,
  });

  final CircleController circles;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback? onInvite;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final selected = circles.selected;
    return PopupMenuButton<String>(
      key: const Key('circle-selector'),
      tooltip: 'Choisir un cercle',
      onSelected: (value) {
        if (value == '_create') {
          onCreate();
          return;
        }
        if (value == '_join') {
          onJoin();
          return;
        }
        if (value == '_invite') {
          onInvite?.call();
          return;
        }
        if (value == '_leave') {
          onLeave?.call();
          return;
        }
        final match = circles.circles.where((item) => item.id == value).firstOrNull;
        if (match != null) {
          circles.select(match);
        }
      },
      itemBuilder: (context) => [
        for (final circle in circles.circles)
          PopupMenuItem(
            value: circle.id,
            child: Text(circle.name),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '_create', child: Text('Créer un cercle')),
        const PopupMenuItem(value: '_join', child: Text('Rejoindre un cercle')),
        if (onInvite != null) const PopupMenuItem(value: '_invite', child: Text('Partager le code')),
        if (onLeave != null) const PopupMenuItem(value: '_leave', child: Text('Quitter le cercle')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Flexible(
              child: Text(
                selected?.name ?? (circles.circles.isEmpty ? 'Créer un cercle' : 'Mes cercles'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const Icon(Icons.expand_more, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.locations, required this.alerts});

  final LocationController locations;
  final AlertController alerts;

  @override
  Widget build(BuildContext context) {
    final pending = locations.queue.pendingCount;
    // File non vide : jamais un état « synchronisé ».
    if (pending == 0) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      child: ListTile(
        dense: true,
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
  }
}

class _ShareBanners extends StatelessWidget {
  const _ShareBanners({required this.locations});

  final LocationController locations;

  @override
  Widget build(BuildContext context) {
    final shares = locations.receivedShares.where((share) => share.isActive).toList();
    if (shares.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final share in shares)
          Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
            child: ListTile(
              dense: true,
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
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.user, required this.alerts, required this.cases});

  final UserAccount user;
  final AlertController alerts;
  final CaseController cases;

  @override
  Widget build(BuildContext context) {
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
    return Material(
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.94),
      child: ListTile(
        dense: true,
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
  }
}

class _AnomalyBanner extends StatelessWidget {
  const _AnomalyBanner({required this.inbox});

  final NotificationController inbox;

  @override
  Widget build(BuildContext context) {
    final note = inbox.recentAnomaly;
    if (note == null) {
      return const SizedBox.shrink();
    }
    final name = note.youngDisplayName;
    final who = name == null || name.isEmpty ? '' : ' · $name';
    return Material(
      key: const Key('map-anomaly-banner'),
      color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.94),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error),
        title: Text('Anomalie détectée$who'),
        subtitle: const Text(
          'Règles métier, pas de ML. Ce n’est pas un kidnapping confirmé. '
          'Dernière position connue, pas actuelle.',
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
        ),
      ),
    );
  }
}

