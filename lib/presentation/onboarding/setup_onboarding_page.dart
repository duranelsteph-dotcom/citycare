import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../data/datasources/place_draft_store.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/zone_repository.dart';
import '../auth/auth_scope.dart';
import '../family/family_scope.dart';
import '../location/location_map.dart';
import '../location/location_scope.dart';
import '../marketplace/marketplace_page.dart';
import '../trackers/kit_page.dart';
import '../widgets/citycare_logo.dart';
import '../zones/zone_scope.dart';
import 'onboarding_scope.dart';
import 'setup_illustrations.dart';

/// Wizard visuel post-permissions : traceur, GPS, maison, nouveau lieu.
class SetupOnboardingPage extends StatefulWidget {
  const SetupOnboardingPage({super.key, PlaceDraftStore? drafts});

  @override
  State<SetupOnboardingPage> createState() => _SetupOnboardingPageState();
}

class _SetupOnboardingPageState extends State<SetupOnboardingPage> {
  final _drafts = PlaceDraftStore();
  int _step = 0;
  double _lat = kDefaultMapCenter.latitude;
  double _lng = kDefaultMapCenter.longitude;
  double _radius = 150;
  bool _homeConfirmed = false;
  bool _locating = false;
  final _placeName = TextEditingController();
  String _placeKind = 'school';

  static const _kinds = <(String, String)>[
    ('school', 'École'),
    ('work', 'Travail'),
    ('other', 'Autre'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryLocate());
  }

  @override
  void dispose() {
    _placeName.dispose();
    super.dispose();
  }

  Future<void> _tryLocate() async {
    setState(() => _locating = true);
    try {
      final locations = LocationScope.of(context);
      await locations.requestLocationAccess();
      final fix = await locations.tryCurrentFix();
      if (!mounted || fix == null) {
        return;
      }
      setState(() {
        _lat = fix.latitude;
        _lng = fix.longitude;
      });
    } catch (_) {
      // Yaoundé reste le centre par défaut — pas une position inventée.
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _finish() => OnboardingScope.of(context).markSetupSeen();

  void _next() => setState(() => _step += 1);

  Future<void> _savePlace({required String name, required String kind, required double radius}) async {
    final draft = PlaceDraft(
      name: name,
      latitude: _lat,
      longitude: _lng,
      radiusMeters: radius,
      kind: kind,
    );
    await _drafts.upsert(draft);
    if (!mounted) {
      return;
    }
    final user = AuthScope.of(context).user;
    final family = FamilyScope.maybeOf(context);
    String? youngId = user?.youngPersonId;
    if (youngId == null && user?.role == UserRole.parent) {
      youngId = family?.active.where((link) => link.canManageZones).firstOrNull?.youngPersonId;
    }
    if (youngId == null) {
      return;
    }
    final zones = ZoneScope.of(context);
    await zones.create(
      SafetyZoneDraft(
        name: name,
        latitude: _lat,
        longitude: _lng,
        radiusMeters: radius,
        schedules: [
          for (var day = 0; day < 7; day++)
            ScheduleDraft(weekday: day, startTime: '00:00', endTime: '23:59'),
        ],
      ),
      youngPersonId: youngId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('setup-onboarding-page'),
      backgroundColor: CityCareBrand.violet,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  const CityCareLogoMark(size: 36, monochromeColor: Colors.white),
                  const SizedBox(width: 8),
                  const CityCareWordmark(fontSize: 20, onBrand: true),
                  const Spacer(),
                  TextButton(
                    key: const Key('setup-skip'),
                    onPressed: _finish,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Passer'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(CityCareBrand.radiusXl)),
                clipBehavior: Clip.antiAlias,
                child: _stepBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _TileStep(
          onYes: _next,
          onNo: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MarketplacePage()),
            );
            if (mounted) {
              setState(() => _step = 2);
            }
          },
        );
      case 1:
        return _ConnectStep(
          onContinue: () => setState(() => _step = 2),
          onOpenKit: () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const KitPage()));
          },
        );
      case 2:
        return _LocationStep(
          locating: _locating,
          onAllow: _tryLocate,
          onContinue: _next,
        );
      case 3:
        return _HomeStep(
          lat: _lat,
          lng: _lng,
          radius: _radius,
          locating: _locating,
          confirmed: _homeConfirmed,
          onMapTap: (lat, lng) => setState(() {
            _lat = lat;
            _lng = lng;
          }),
          onRadius: (value) => setState(() => _radius = value),
          onConfirm: () async {
            setState(() => _homeConfirmed = true);
            await _savePlace(name: 'Maison', kind: 'home', radius: _radius);
            if (mounted) {
              _next();
            }
          },
          onReject: _next,
        );
      default:
        return _PlaceStep(
          lat: _lat,
          lng: _lng,
          kind: _placeKind,
          name: _placeName,
          onKind: (kind) => setState(() {
            _placeKind = kind;
            if (kind == 'school' && _placeName.text.isEmpty) {
              _placeName.text = 'École';
            }
            if (kind == 'work' && _placeName.text.isEmpty) {
              _placeName.text = 'Travail';
            }
          }),
          onMapTap: (lat, lng) => setState(() {
            _lat = lat;
            _lng = lng;
          }),
          onSkip: _finish,
          onSave: () async {
            final name = _placeName.text.trim().isEmpty
                ? (_placeKind == 'school' ? 'École' : _placeKind == 'work' ? 'Travail' : 'Lieu')
                : _placeName.text.trim();
            await _savePlace(name: name, kind: _placeKind, radius: 250);
            if (mounted) {
              await _finish();
            }
          },
        );
    }
  }
}

class _TileStep extends StatelessWidget {
  const _TileStep({required this.onYes, required this.onNo});

  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      hero: const SetupHeroCard(
        scene: SetupScene.tile,
        photoAsset: 'assets/images/prevention/veille_famille.png',
      ),
      titleKey: 'setup-tile-title',
      title: 'Avez-vous un traceur ?',
      body:
          'Un traceur Bluetooth (type Tile) ou un kit CityCare aide à retrouver '
          'un sac, un enfant, un proche. Ce n’est pas un bracelet magique : '
          'il parle au serveur quand il est allumé.',
      actions: [
        FilledButton(
          key: const Key('setup-tile-yes'),
          onPressed: onYes,
          child: const Text('Oui, j’en ai un'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('setup-tile-no'),
          onPressed: onNo,
          child: const Text('Non, voir la boutique'),
        ),
      ],
    );
  }
}

class _ConnectStep extends StatelessWidget {
  const _ConnectStep({required this.onContinue, required this.onOpenKit});

  final VoidCallback onContinue;
  final VoidCallback onOpenKit;

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      hero: const SetupHeroCard(
        scene: SetupScene.connect,
        photoAsset: 'assets/images/prevention/tranquillite_famille.png',
      ),
      titleKey: 'setup-connect-title',
      title: 'Le connecter',
      body:
          'Branchez le traceur ou allumez le kit, puis enregistrez-le dans '
          'CityCare. L’app ne parle pas au Bluetooth du Tile : le kit envoie '
          'sa position au serveur. Vous pourrez le faire plus tard dans Profil.',
      actions: [
        FilledButton(
          key: const Key('setup-connect-kit'),
          onPressed: onOpenKit,
          child: const Text('Enregistrer un kit'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('setup-connect-later'),
          onPressed: onContinue,
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.locating,
    required this.onAllow,
    required this.onContinue,
  });

  final bool locating;
  final VoidCallback onAllow;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final access = LocationScope.of(context).locationAccess;
    final granted = access?.isGranted == true;
    return ListenableBuilder(
      listenable: LocationScope.of(context),
      builder: (context, _) {
        return _SetupScaffold(
          hero: const SetupHeroCard(
            scene: SetupScene.location,
            photoAsset: 'assets/images/prevention/trajet_connu.png',
          ),
          titleKey: 'setup-location-title',
          title: 'Partager votre position ?',
          body:
              'CityCare relève la position de ce téléphone pour la carte, '
              'un SOS, et pour proposer votre maison. Ce n’est pas un suivi '
              'en continu. Sans cette autorisation, la carte restera sur Yaoundé.',
          actions: [
            FilledButton.icon(
              key: const Key('setup-allow-location'),
              onPressed: granted || locating ? null : onAllow,
              icon: granted ? const Icon(Icons.check) : const Icon(Icons.my_location),
              label: Text(granted ? 'Localisation autorisée' : 'Autoriser la localisation'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('setup-location-continue'),
              onPressed: onContinue,
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );
  }
}

class _HomeStep extends StatelessWidget {
  const _HomeStep({
    required this.lat,
    required this.lng,
    required this.radius,
    required this.locating,
    required this.confirmed,
    required this.onMapTap,
    required this.onRadius,
    required this.onConfirm,
    required this.onReject,
  });

  final double lat;
  final double lng;
  final double radius;
  final bool locating;
  final bool confirmed;
  final void Function(double lat, double lng) onMapTap;
  final ValueChanged<double> onRadius;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            children: [
              const SetupHeroCard(
                scene: SetupScene.home,
                photoAsset: 'assets/images/prevention/tranquillite_famille.png',
                height: 140,
              ),
              const SizedBox(height: 16),
              const Text(
                key: Key('setup-home-title'),
                'Est-ce bien votre maison ?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: CityCareBrand.titleInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                locating
                    ? 'Recherche de la position du téléphone…'
                    : 'Le pin est la dernière position connue, ou Yaoundé si le GPS n’a pas répondu. '
                        'Touchez la carte pour ajuster. Ce n’est pas un suivi en direct.',
                style: const TextStyle(color: CityCareBrand.mutedText, height: 1.4),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: CityCareBrand.borderRadiusMd,
                child: SizedBox(
                  height: 200,
                  child: LocationMapView(
                    latitude: lat,
                    longitude: lng,
                    circles: [MapCircle(latitude: lat, longitude: lng, radiusMeters: radius)],
                    onTap: onMapTap,
                  ),
                ),
              ),
              Text('Rayon : ${radius.round()} m'),
              Slider(
                min: 50,
                max: 400,
                value: radius,
                onChanged: onRadius,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const Key('setup-home-yes'),
                onPressed: confirmed ? null : onConfirm,
                child: Text(confirmed ? 'Maison enregistrée' : 'Oui, c’est ma maison'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('setup-home-no'),
                onPressed: onReject,
                child: const Text('Ce n’est pas ici'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceStep extends StatelessWidget {
  const _PlaceStep({
    required this.lat,
    required this.lng,
    required this.kind,
    required this.name,
    required this.onKind,
    required this.onMapTap,
    required this.onSkip,
    required this.onSave,
  });

  final double lat;
  final double lng;
  final String kind;
  final TextEditingController name;
  final ValueChanged<String> onKind;
  final void Function(double lat, double lng) onMapTap;
  final VoidCallback onSkip;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            children: [
              const SetupHeroCard(
                scene: SetupScene.place,
                photoAsset: 'assets/images/prevention/trajet_connu.png',
                height: 140,
              ),
              const SizedBox(height: 16),
              const Text(
                key: Key('setup-place-title'),
                'Ajouter un nouveau lieu',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: CityCareBrand.titleInk,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'École, travail ou un autre endroit sûr. Un parent pourra '
                'ensuite l’appliquer comme zone de sécurité de l’enfant.',
                style: TextStyle(color: CityCareBrand.mutedText, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in _SetupOnboardingPageState._kinds)
                    ChoiceChip(
                      key: Key('setup-place-kind-${item.$1}'),
                      label: Text(item.$2),
                      selected: kind == item.$1,
                      onSelected: (_) => onKind(item.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('setup-place-name'),
                controller: name,
                style: const TextStyle(color: CityCareBrand.titleInk, fontWeight: FontWeight.w600),
                cursorColor: CityCareBrand.violet,
                decoration: const InputDecoration(labelText: 'Nom du lieu'),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: CityCareBrand.borderRadiusMd,
                child: SizedBox(
                  height: 180,
                  child: LocationMapView(
                    latitude: lat,
                    longitude: lng,
                    circles: [MapCircle(latitude: lat, longitude: lng, radiusMeters: 250)],
                    onTap: onMapTap,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const Key('setup-place-save'),
                onPressed: onSave,
                child: const Text('Enregistrer ce lieu'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('setup-place-skip'),
                onPressed: onSkip,
                child: const Text('Plus tard'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupScaffold extends StatelessWidget {
  const _SetupScaffold({
    required this.hero,
    required this.titleKey,
    required this.title,
    required this.body,
    required this.actions,
  });

  final Widget hero;
  final String titleKey;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        hero,
        const SizedBox(height: 20),
        Text(
          title,
          key: Key(titleKey),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: CityCareBrand.titleInk,
          ),
        ),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(color: Color(0xFF616161), height: 1.45, fontSize: 15)),
        const SizedBox(height: 24),
        ...actions,
      ],
    );
  }
}
