import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../core/config/api_config.dart';
import '../../domain/entities/alerts.dart';
import '../../domain/entities/circle.dart';
import '../../domain/entities/identity.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import '../family/family_controller.dart';
import '../location/location_controller.dart';
import '../location/maps/map_data.dart';
import 'care_status.dart';
import 'freshness.dart';

export 'care_status.dart';
export 'freshness.dart';

/// Ligne affichable dans le panneau membres de la carte (pas l’onglet Membres).
class MapMemberRow {
  const MapMemberRow({
    required this.id,
    required this.name,
    required this.kind,
    this.photoUrl,
    this.point,
    this.sharingOn,
    this.youngPersonId,
    this.canOpenDetail = false,
    this.care,
  });

  final String id;
  final String name;
  final MapMemberKind kind;
  final String? photoUrl;
  final TrackerLocation? point;
  final bool? sharingOn;
  final String? youngPersonId;
  final bool canOpenDetail;

  /// Statut unifié. Null = calculé depuis le point, sauf gardien (pas de pastille).
  final CareStatus? care;

  CareStatus? get displayCare {
    if (kind == MapMemberKind.guardian) {
      return care;
    }
    return care ?? resolveCareStatus(point: point);
  }

  bool get hasPin => point != null;

  double? get latitude => point?.latitude;

  double? get longitude => point?.longitude;
}

enum MapMemberKind { self, young, guardian, limitedShare }

/// Initiales pour l’avatar (pas de photo inventée).
String memberInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  String firstChar(String value) => value.substring(0, 1).toUpperCase();
  if (parts.length == 1) {
    return firstChar(parts.first);
  }
  return '${firstChar(parts.first)}${firstChar(parts.last)}';
}

/// Partage / GPS / hors-ligne — pas un suivi en direct.
String memberStatusLabel({
  required bool? sharingOn,
  required TrackerLocation? point,
}) {
  final parts = <String>[];
  if (sharingOn != null) {
    parts.add(sharingOn ? 'Partage on' : 'Partage off');
  }
  if (point == null) {
    parts.add('Hors ligne');
  } else if (point.isStale) {
    parts.add('Hors ligne');
  } else {
    parts.add('GPS');
  }
  return parts.join(' · ');
}

/// Batterie kit uniquement (libellé distinct du téléphone).
String? kitBatteryLabel(TrackerLocation? point) {
  if (point == null || point.source != LocationSource.iot || point.batteryLevel == null) {
    return null;
  }
  return 'Batterie kit : ${point.batteryLevel} %';
}

/// Batterie téléphone : seulement si le point l’a déjà. Jamais 100 % inventé.
String? phoneBatteryLabel(TrackerLocation? point) {
  if (point == null || point.source != LocationSource.phone || point.batteryLevel == null) {
    return null;
  }
  return 'Batterie : ${point.batteryLevel} %';
}

/// Kit ou téléphone selon [TrackerLocation.source]. Null si inconnue.
String? memberBatteryLabel(TrackerLocation? point) {
  return kitBatteryLabel(point) ?? phoneBatteryLabel(point);
}

/// Membres du cercle sélectionné.
///
/// Le cercle groupe des comptes. Une pastille / position n'apparaît que si
/// [CircleMember.canViewLocation] (GuardianLink déjà vrai) ou un partage limité
/// existe déjà — le cercle n'accorde rien de nouveau.
List<MapMemberRow> mapMembersForCircle({
  required UserAccount user,
  required List<CircleMember> members,
  required LocationController locations,
  Iterable<Alert> alerts = const [],
  Iterable<AppNotification> inbox = const [],
}) {
  final rows = <MapMemberRow>[];
  for (final member in members) {
    if (member.userId == user.id) {
      rows.add(
        MapMemberRow(
          id: 'self-${user.id}',
          name: member.fullName,
          kind: MapMemberKind.self,
          photoUrl: member.photoUrl ?? user.photoUrl,
          point: user.role == UserRole.young ? locations.latest : null,
          sharingOn: member.canViewLocation || locations.shares.any((share) => share.isActive),
          youngPersonId: member.youngPersonId ?? user.youngPersonId,
          canOpenDetail: user.role == UserRole.young,
          care: user.role == UserRole.young
              ? careStatusForMember(
                  point: user.role == UserRole.young ? locations.latest : null,
                  youngPersonId: member.youngPersonId ?? user.youngPersonId,
                  alerts: alerts,
                  inbox: inbox,
                  isSelf: true,
                  locations: locations,
                )
              : CareStatus.hidden,
        ),
      );
      continue;
    }
    final youngId = member.youngPersonId;
    final share = youngId == null ? null : locations.receivedShareFor(youngId);
    final allowed = member.canViewLocation || share != null;
    if (youngId != null && (user.role == UserRole.parent || user.role == UserRole.relative)) {
      rows.add(
        MapMemberRow(
          id: 'young-$youngId',
          name: member.fullName,
          kind: share != null ? MapMemberKind.limitedShare : MapMemberKind.young,
          photoUrl: member.photoUrl,
          point: allowed ? locations.familyLatest[youngId] : null,
          sharingOn: allowed,
          youngPersonId: youngId,
          canOpenDetail: allowed,
          care: careStatusForMember(
            point: allowed ? locations.familyLatest[youngId] : null,
            youngPersonId: youngId,
            alerts: alerts,
            inbox: inbox,
          ),
        ),
      );
    } else {
      rows.add(
        MapMemberRow(
          id: 'member-${member.userId}',
          name: member.fullName,
          kind: MapMemberKind.guardian,
          photoUrl: member.photoUrl,
          sharingOn: member.canViewLocation,
          canOpenDetail: false,
        ),
      );
    }
  }
  return rows;
}

/// Pastilles du cercle : uniquement si GuardianLink.can_view_location ou partage.
List<MapPin> mapPinsForCircle({
  required UserAccount user,
  required List<CircleMember> members,
  required LocationController locations,
  String? selectedId,
  Iterable<Alert> alerts = const [],
  Iterable<AppNotification> inbox = const [],
}) {
  if (user.role == UserRole.young) {
    return mapPinsForYoung(
      user: user,
      locations: locations,
      selectedId: selectedId,
      alerts: alerts,
      inbox: inbox,
    );
  }
  final pins = <MapPin>[];
  for (final member in members) {
    if (member.userId == user.id) {
      continue;
    }
    final youngId = member.youngPersonId;
    if (youngId == null) {
      continue;
    }
    final share = locations.receivedShareFor(youngId);
    if (!member.canViewLocation && share == null) {
      continue;
    }
    final point = locations.familyLatest[youngId];
    if (point == null) {
      continue;
    }
    pins.add(
      _pinFromPoint(
        id: 'young-$youngId',
        name: member.fullName,
        point: point,
        isSelected: selectedId == 'young-$youngId',
        photoUrl: member.photoUrl,
        care: careStatusForMember(
          point: point,
          youngPersonId: youngId,
          alerts: alerts,
          inbox: inbox,
        ),
      ),
    );
  }
  return pins;
}

/// Construit la liste parent / proche : jeunes liés + partages limités.
List<MapMemberRow> mapMembersForGuardian({
  required FamilyController family,
  required LocationController locations,
  Iterable<Alert> alerts = const [],
  Iterable<AppNotification> inbox = const [],
}) {
  final rows = <MapMemberRow>[];
  final seen = <String>{};
  for (final link in family.active) {
    seen.add(link.youngPersonId);
    final share = locations.receivedShareFor(link.youngPersonId);
    rows.add(
      MapMemberRow(
        id: 'young-${link.youngPersonId}',
        name: link.youngDisplayName ?? 'Jeune',
        kind: share != null ? MapMemberKind.limitedShare : MapMemberKind.young,
        photoUrl: link.youngPhotoUrl,
        point: locations.familyLatest[link.youngPersonId],
        sharingOn: link.canViewLocation || share != null,
        youngPersonId: link.youngPersonId,
        canOpenDetail: true,
        care: careStatusForMember(
          point: locations.familyLatest[link.youngPersonId],
          youngPersonId: link.youngPersonId,
          alerts: alerts,
          inbox: inbox,
        ),
      ),
    );
  }
  for (final share in locations.receivedShares) {
    if (!share.isActive || seen.contains(share.youngPersonId)) {
      continue;
    }
    seen.add(share.youngPersonId);
    rows.add(
      MapMemberRow(
        id: 'share-${share.youngPersonId}',
        name: share.youngDisplayName ?? 'Jeune',
        kind: MapMemberKind.limitedShare,
        photoUrl: null,
        point: locations.familyLatest[share.youngPersonId],
        sharingOn: true,
        youngPersonId: share.youngPersonId,
        canOpenDetail: true,
        care: careStatusForMember(
          point: locations.familyLatest[share.youngPersonId],
          youngPersonId: share.youngPersonId,
          alerts: alerts,
          inbox: inbox,
        ),
      ),
    );
  }
  return rows;
}

/// Construit la liste jeune : soi + gardiens (statut de partage, pas leur GPS).
List<MapMemberRow> mapMembersForYoung({
  required UserAccount user,
  required FamilyController family,
  required LocationController locations,
  Iterable<Alert> alerts = const [],
  Iterable<AppNotification> inbox = const [],
}) {
  final selfPoint = locations.latest;
  final rows = <MapMemberRow>[
    MapMemberRow(
      id: 'self-${user.id}',
      name: user.fullName,
      kind: MapMemberKind.self,
      photoUrl: family.youngProfile?.photoUrl ?? user.photoUrl,
      point: selfPoint,
      sharingOn: family.active.any((link) => link.canViewLocation) ||
          locations.shares.any((share) => share.isActive),
      youngPersonId: user.youngPersonId,
      canOpenDetail: true,
      care: careStatusForMember(
        point: selfPoint,
        youngPersonId: user.youngPersonId,
        alerts: alerts,
        inbox: inbox,
        isSelf: true,
        locations: locations,
      ),
    ),
  ];
  for (final link in family.active) {
    rows.add(
      MapMemberRow(
        id: 'guardian-${link.id}',
        name: link.guardianName ?? 'Contact',
        kind: MapMemberKind.guardian,
        sharingOn: link.canViewLocation,
        canOpenDetail: false,
      ),
    );
  }
  return rows;
}

MapPin _pinFromPoint({
  required String id,
  required String name,
  required TrackerLocation point,
  required bool isSelected,
  String? photoUrl,
  CareStatus? care,
}) {
  final resolved = care ?? resolveCareStatus(point: point);
  return MapPin(
    id: id,
    latitude: point.latitude,
    longitude: point.longitude,
    label: name,
    isSelected: isSelected,
    isStale: locationLooksStale(isStale: point.isStale, ageSeconds: point.ageSeconds),
    ageSeconds: point.ageSeconds,
    photoUrl: photoUrl,
    batteryCaption: memberBatteryLabel(point),
    careLevel: resolved.level,
  );
}

/// Pastilles parent / proche : jeunes liés déjà autorisés, pas le parent.
List<MapPin> mapPinsForGuardian({
  required FamilyController family,
  required LocationController locations,
  String? selectedId,
  Iterable<Alert> alerts = const [],
  Iterable<AppNotification> inbox = const [],
}) {
  final pins = <MapPin>[];
  final seen = <String>{};
  for (final link in family.active) {
    final point = locations.familyLatest[link.youngPersonId];
    if (point == null) {
      continue;
    }
    seen.add(link.youngPersonId);
    pins.add(
      _pinFromPoint(
        id: 'young-${link.youngPersonId}',
        name: link.youngDisplayName ?? 'Jeune',
        point: point,
        isSelected: selectedId == 'young-${link.youngPersonId}',
        photoUrl: link.youngPhotoUrl,
        care: careStatusForMember(
          point: point,
          youngPersonId: link.youngPersonId,
          alerts: alerts,
          inbox: inbox,
        ),
      ),
    );
  }
  for (final share in locations.receivedShares) {
    if (!share.isActive || seen.contains(share.youngPersonId)) {
      continue;
    }
    final point = locations.familyLatest[share.youngPersonId];
    if (point == null) {
      continue;
    }
    pins.add(
      _pinFromPoint(
        id: 'share-${share.youngPersonId}',
        name: share.youngDisplayName ?? 'Jeune',
        point: point,
        isSelected: selectedId == 'share-${share.youngPersonId}',
        care: careStatusForMember(
          point: point,
          youngPersonId: share.youngPersonId,
          alerts: alerts,
          inbox: inbox,
        ),
      ),
    );
  }
  return pins;
}

/// Pastille « moi » : nom + durée, seulement si une position existe déjà.
///
/// Fix téléphone local ou dernier point serveur. Jamais de coordonnées inventées.
MapPin? mapPinForSelf({
  required UserAccount user,
  required LocationController locations,
  String? selectedId,
  Iterable<Alert> alerts = const [],
  Iterable<AppNotification> inbox = const [],
}) {
  final unsynced = locations.unsyncedFix;
  final latest = locations.latest;
  final latitude = unsynced?.latitude ?? latest?.latitude;
  final longitude = unsynced?.longitude ?? latest?.longitude;
  if (latitude == null || longitude == null) {
    return null;
  }
  final care = careStatusForMember(
    point: latest,
    youngPersonId: user.youngPersonId,
    alerts: alerts,
    inbox: inbox,
    isSelf: true,
    locations: locations,
  );
  if (unsynced != null) {
    final age = DateTime.now().toUtc().difference(unsynced.timestamp.toUtc()).inSeconds;
    return MapPin(
      id: 'self-${user.id}',
      latitude: latitude,
      longitude: longitude,
      label: user.fullName,
      isSelected: selectedId == 'self-${user.id}',
      isStale: false,
      ageSeconds: age < 0 ? 0 : age,
      photoUrl: user.photoUrl,
      careLevel: care.level,
    );
  }
  return _pinFromPoint(
    id: 'self-${user.id}',
    name: user.fullName,
    point: latest!,
    isSelected: selectedId == 'self-${user.id}',
    photoUrl: user.photoUrl,
    care: care,
  );
}

/// Pastille jeune : soi uniquement (les gardiens n’ont pas de GPS inventé).
List<MapPin> mapPinsForYoung({
  required UserAccount user,
  required LocationController locations,
  String? selectedId,
  Iterable<Alert> alerts = const [],
  Iterable<AppNotification> inbox = const [],
}) {
  final pin = mapPinForSelf(
    user: user,
    locations: locations,
    selectedId: selectedId,
    alerts: alerts,
    inbox: inbox,
  );
  return pin == null ? const [] : [pin];
}

/// Raccourci blanc du panneau carte (icône violette, texte violet).
class MapShortcutAction {
  const MapShortcutAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final String id;
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

/// Panneau bas style Life360 : liste des membres sur la carte.
///
/// Ne remplace pas l’onglet Membres : complément pour recentrer / ouvrir le détail.
class MapMembersSheet extends StatelessWidget {
  const MapMembersSheet({
    super.key,
    required this.members,
    required this.selectedId,
    required this.onSelect,
    this.onOpenDetail,
    this.onLinkChild,
    this.emptyTitle = 'Aucun jeune rattaché',
    this.emptySubtitle = 'Code ou invitation par téléphone',
    this.headline = 'Groupe de confiance',
    this.shortcuts = const [],
  });

  final List<MapMemberRow> members;
  final String? selectedId;
  final ValueChanged<MapMemberRow> onSelect;
  final ValueChanged<MapMemberRow>? onOpenDetail;
  final VoidCallback? onLinkChild;
  final String emptyTitle;
  final String emptySubtitle;
  final String headline;
  final List<MapShortcutAction> shortcuts;

  @override
  Widget build(BuildContext context) {
    // Panneau fixe : la hauteur vient du parent (moitié d’écran), pas d’un sheet 1/3.
    return Material(
      key: const Key('map-member-sheet'),
      elevation: 10,
      color: CityCareBrand.violet,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(CityCareBrand.radiusLg)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Dernière position connue — pas un suivi en direct.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                if (members.isEmpty)
                  ListTile(
                    key: const Key('map-member-empty'),
                    leading: const Icon(Icons.link, color: Colors.white),
                    title: Text(emptyTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(emptySubtitle, style: const TextStyle(color: Colors.white70)),
                    onTap: onLinkChild,
                  )
                else
                  for (final member in members)
                    Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: _MemberTile(
                        member: member,
                        selected: member.id == selectedId,
                        onSelect: () => onSelect(member),
                        onOpenDetail: member.canOpenDetail && onOpenDetail != null
                            ? () => onOpenDetail!(member)
                            : null,
                      ),
                    ),
                if (shortcuts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Raccourcis',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _ShortcutGrid(actions: shortcuts),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.actions});

  final List<MapShortcutAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      key: const Key('map-shortcut-grid'),
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        for (final action in actions)
          Material(
            key: Key('map-shortcut-${action.id}'),
            color: Colors.white,
            elevation: 1,
            shadowColor: Colors.black26,
            borderRadius: CityCareBrand.borderRadiusMd,
            child: InkWell(
              borderRadius: CityCareBrand.borderRadiusMd,
              onTap: action.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(action.icon, color: CityCareBrand.violet, size: 26),
                    const Spacer(),
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CityCareBrand.violet,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (action.subtitle != null)
                      Text(
                        action.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF7B1FA2), fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.selected,
    required this.onSelect,
    this.onOpenDetail,
  });

  final MapMemberRow member;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final battery = memberBatteryLabel(member.point);
    final isGuardian = member.kind == MapMemberKind.guardian;
    final care = member.displayCare;
    final status = isGuardian
        ? (member.sharingOn == true ? 'Partage on' : 'Partage off')
        : memberStatusLabel(sharingOn: member.sharingOn, point: member.point);
    final freshness = isGuardian ? null : memberFreshnessLabel(member.point);
    return ListTile(
      key: Key('map-member-${member.id}'),
      selected: selected,
      selectedTileColor: CityCareBrand.lavender.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: CityCareBrand.borderRadiusMd),
      leading: ProfileMemberAvatar(name: member.name, photoUrl: member.photoUrl),
      title: Text(member.kind == MapMemberKind.self ? 'Ma position' : member.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (member.kind == MapMemberKind.self) Text(member.name),
          if (care != null && care.visible) ...[
            const SizedBox(height: 4),
            CareStatusBadge(status: care),
            const SizedBox(height: 2),
          ],
          Text(status),
          if (freshness != null) Text(freshness),
          if (battery != null) Text(battery),
        ],
      ),
      isThreeLine: true,
      trailing: onOpenDetail == null
          ? (member.hasPin ? Icon(Icons.place_outlined, color: scheme.primary) : null)
          : IconButton(
              tooltip: 'Position et trajectoire',
              onPressed: onOpenDetail,
              icon: const Icon(Icons.chevron_right),
            ),
      onTap: onSelect,
    );
  }
}

/// Avatar du sheet : photo réseau si [photoUrl], sinon initiales.
class ProfileMemberAvatar extends StatelessWidget {
  const ProfileMemberAvatar({super.key, required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = memberInitials(name);
    final photo = ApiConfig.resolveMediaUrl(photoUrl);
    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: CityCareBrand.lavender,
        backgroundImage: NetworkImage(photo),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      backgroundColor: CityCareBrand.lavender,
      foregroundColor: CityCareBrand.violet,
      child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
