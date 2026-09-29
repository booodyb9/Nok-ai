import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nok_ai/engine.dart';
import 'package:nok_ai/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('NotoSansArabic');
    loader.addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugin.csdcorp.com/speech_to_text'),
          (_) async => true,
        );
  });
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('Arabic home and navigation fit $width px', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppState();
      await s.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => s)],
          child: const NokApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('مرحبًا، أنا NOK'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/nok-robot.png'),
          tester.element(find.byType(Shell)),
        ),
      );
      await tester.pumpAndSettle();
      if (width == 390) {
        await expectLater(
          find.byType(NokApp),
          matchesGoldenFile('goldens/home_ar_390.png'),
        );
      }
      await tester.tap(find.text('الأدوات').last);
      await tester.pumpAndSettle();
      expect(find.text('المعلم الذكي'), findsOneWidget);
      await tester.tap(find.text('المعلم الذكي'));
      await tester.pumpAndSettle();
      expect(find.text('ربط الذكاء الاصطناعي'), findsOneWidget);
      await tester.tap(find.text('الإعدادات').last);
      await tester.pumpAndSettle();
      expect(find.text('Gemini'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('large English text fits 360 px', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = AppState();
    await s.init();
    s.prefs.scale = 1.4;
    s.prefs.arabic = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => s)],
        child: const NokApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
