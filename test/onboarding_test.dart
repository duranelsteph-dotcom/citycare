import 'package:citycare/presentation/onboarding/onboarding_controller.dart';
import 'package:citycare/presentation/onboarding/onboarding_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('memory store starts incomplete then persists skip', () async {
    final store = MemoryOnboardingStore();
    final controller = OnboardingController(store);
    await controller.load();
    expect(controller.isLoading, isFalse);
    expect(controller.isCompleted, isFalse);

    await controller.markSeen();
    expect(controller.isCompleted, isTrue);
    expect(store.completed, isTrue);

    final again = OnboardingController(store);
    await again.load();
    expect(again.isCompleted, isTrue);
  });

  test('shared preferences flag is written once', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesOnboardingStore();
    expect(await store.readCompleted(), isFalse);
    await store.writeCompleted();
    expect(await store.readCompleted(), isTrue);

    final next = SharedPreferencesOnboardingStore();
    expect(await next.readCompleted(), isTrue);
  });

  test('setup places flag is independent of permissions', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesOnboardingStore();
    expect(await store.readSetupCompleted(), isFalse);
    await store.writeSetupCompleted();
    expect(await store.readSetupCompleted(), isTrue);
    expect(await store.readCompleted(), isFalse);
  });

  test('slides stay honest about background GPS', () {
    expect(OnboardingPage.slides.length, inInclusiveRange(2, 4));
    expect(
      OnboardingPage.slides.map((slide) => slide.kind),
      containsAll([
        OnboardingSlideKind.location,
        OnboardingSlideKind.notifications,
        OnboardingSlideKind.background,
      ]),
    );
    final background = OnboardingPage.slides.singleWhere(
      (slide) => slide.kind == OnboardingSlideKind.background,
    );
    expect(background.body.toLowerCase(), contains('optionnel'));
    expect(background.body.toLowerCase(), contains('arrière-plan'));
    expect(background.body.toLowerCase(), contains('toujours'));
    expect(background.body.toLowerCase(), isNot(contains('pas encore')));
    expect(background.body.toLowerCase(), isNot(contains('déjà actif')));
    expect(background.body, contains('Partage en arrière-plan'));
  });
}
