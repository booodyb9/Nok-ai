import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nok_ai/engine.dart';
import 'package:nok_ai/vision.dart';

class DeniedCamera extends CameraPlatform {
  int attempts = 0;
  @override
  Future<List<CameraDescription>> availableCameras() async {
    attempts++;
    throw CameraException('CameraAccessDenied', 'Denied');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    state = AppState();
    await state.init();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (_) async => true,
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  Widget app(Widget page) => ProviderScope(
    overrides: [appProvider.overrideWith((ref) => state)],
    child: MaterialApp(home: page),
  );

  testWidgets('camera denial shows recovery and disables analysis', (
    tester,
  ) async {
    final original = CameraPlatform.instance;
    final camera = DeniedCamera();
    CameraPlatform.instance = camera;
    addTearDown(() => CameraPlatform.instance = original);
    await tester.pumpWidget(app(const CameraPage()));
    await tester.pumpAndSettle();
    expect(find.text('إعادة محاولة الكاميرا'), findsOneWidget);
    final analyze = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'تحليل'),
    );
    expect(analyze.onPressed, isNull);
    await tester.tap(find.text('إعادة محاولة الكاميرا'));
    await tester.pumpAndSettle();
    expect(camera.attempts, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('screen guide distinguishes unavailable platform', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(app(const ScreenGuidePage()));
    await tester.pumpAndSettle();
    expect(find.text('الميزة تعمل في تطبيق أندرويد فقط.'), findsOneWidget);
    expect(find.text('إظهار لوحة المساعدة'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('Android guide forwards language, rate and volume', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    MethodCall? shown;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app.nok/screen_guide'), (
          call,
        ) async {
          if (call.method == 'isEnabled') return true;
          shown = call;
          return null;
        });
    state.prefs.rate = .6;
    state.prefs.volume = .4;
    await tester.pumpWidget(app(const ScreenGuidePage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('إظهار لوحة المساعدة'));
    await tester.tap(find.text('إظهار لوحة المساعدة'));
    await tester.pumpAndSettle();
    expect(shown?.method, 'showGuide');
    expect(shown?.arguments, {'language': 'ar', 'rate': .6, 'volume': .4});
    debugDefaultTargetPlatformOverride = null;
  });
}
