import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/brand.dart';
import 'citycare_logo.dart';
import 'prevention_illustrations.dart';

/// Une diapositive du carrousel d’accueil (prévention, ton rassurant).
class PreventionSlide {
  const PreventionSlide({
    required this.asset,
    required this.title,
    required this.semanticLabel,
    required this.fallbackScene,
  });

  final String asset;
  final String title;
  final String semanticLabel;
  final PreventionScene fallbackScene;
}

/// Carrousel hero : photo plein cadre, dégradé violet, titre, logo CityCare.
///
/// Lecture auto toutes les 5 s, swipe, pastilles discrètes.
/// Le minuteur est coupé sous [TestWidgetsFlutterBinding] pour que
/// `pumpAndSettle` des tests ne tourne pas en boucle.
class PreventionCarousel extends StatefulWidget {
  const PreventionCarousel({
    super.key,
    this.autoPlay = true,
    this.interval = const Duration(seconds: 5),
    this.height,
  });

  final bool autoPlay;
  final Duration interval;
  final double? height;

  /// Slide 1 : réunion parent / enfant. Slides 2–3 : trajet connu, veille familiale.
  static const slides = <PreventionSlide>[
    PreventionSlide(
      asset: 'assets/images/prevention/tranquillite_famille.png',
      title: 'Gagnez en tranquillité grâce à la meilleure application veillant à la sécurité de tous',
      semanticLabel:
          'Photo : une mère sourit à la caméra en serrant son enfant '
          'qui porte un sac à dos, scène de retrouvailles.',
      fallbackScene: PreventionScene.knownRoute,
    ),
    PreventionSlide(
      asset: 'assets/images/prevention/trajet_connu.png',
      title: 'Un trajet connu, main dans la main, pour rentrer l’esprit plus léger',
      semanticLabel:
          'Photo : une mère et son enfant marchent ensemble vers l’école, '
          'main dans la main, sur un chemin habituel.',
      fallbackScene: PreventionScene.knownRoute,
    ),
    PreventionSlide(
      asset: 'assets/images/prevention/veille_famille.png',
      title: 'Une famille connectée, c’est plus de calme — et une alerte plus vite',
      semanticLabel:
          'Photo : une famille réunie regarde un téléphone ensemble, '
          'ambiance calme et rassurante.',
      fallbackScene: PreventionScene.raiseAlert,
    ),
  ];

  @override
  State<PreventionCarousel> createState() => _PreventionCarouselState();
}

class _PreventionCarouselState extends State<PreventionCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  /// Évite qu’un [Timer.periodic] empêche `pumpAndSettle` de se terminer.
  bool get _isWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  bool get _shouldAutoPlay => widget.autoPlay && !_isWidgetTest;

  @override
  void initState() {
    super.initState();
    // Fraction < 1 : les cartes voisines dépassent légèrement, comme un carrousel.
    _controller = PageController(viewportFraction: 0.90);
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_shouldAutoPlay) {
      return;
    }
    _timer = Timer.periodic(widget.interval, (_) => _goNext());
  }

  void _goNext() {
    if (!mounted || !_controller.hasClients) {
      return;
    }
    final next = (_index + 1) % PreventionCarousel.slides.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _restartTimer();
  }

  void _goTo(int index) {
    if (!_controller.hasClients || index == _index) {
      return;
    }
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = PreventionCarousel.slides;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final rawHeight = widget.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : width * 1.55);
        final height = rawHeight.clamp(320.0, 2400.0);
        return SizedBox(
          height: height,
          width: width,
          child: Stack(
            children: [
              PageView.builder(
                key: const Key('prevention-carousel'),
                controller: _controller,
                onPageChanged: _onPageChanged,
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  return _HeroSlide(
                    slide: slides[index],
                    titleKey: Key('prevention-title-$index'),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < slides.length; i++)
                      _Dot(
                        key: Key('prevention-dot-$i'),
                        active: i == _index,
                        onTap: () => _goTo(i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Carte hero : photo, fondu violet, titre blanc, logo CityCare, pastilles.
class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.slide,
    required this.titleKey,
  });

  final PreventionSlide slide;
  final Key titleKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: ClipRRect(
        borderRadius: CityCareBrand.borderRadiusXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: slide.semanticLabel,
              image: true,
              child: Image.asset(
                slide.asset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stack) {
                  return ColoredBox(
                    color: CityCareBrand.heroViolet,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: PreventionIllustration(
                        scene: slide.fallbackScene,
                        height: 220,
                        onDarkSurface: true,
                      ),
                    ),
                  );
                },
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: CityCareBrand.heroPhotoFade),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              child: Column(
                children: [
                  const Spacer(flex: 58),
                  Text(
                    slide.title,
                    key: titleKey,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Spacer(flex: 6),
                  const _SlideBrandMark(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Monogramme + wordmark `citycare`, blanc, en bas de carte.
class _SlideBrandMark extends StatelessWidget {
  const _SlideBrandMark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CityCareLogoMark(size: 30, monochromeColor: Colors.white, showBadge: false),
        SizedBox(width: 10),
        CityCareWordmark(fontSize: 22, onBrand: true),
      ],
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
          duration: const Duration(milliseconds: 250),
          width: active ? 16 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
