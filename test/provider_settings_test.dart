import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nok_ai/engine.dart';
import 'package:nok_ai/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ObservedClient extends AiClient {
  ObservedClient({required super.clientFactory});
  int tests = 0;
  @override
  Future<void> testConnection(AiConfig config) async {
    tests++;
    lastModel = config.model;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets(
    'automatic selection, connection indicator and secure save fit a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState();
      await state.init();
      state.config = const AiConfig(key: 'test-key', model: 'outdated-name');
      var gets = 0, posts = 0;
      final ai = ObservedClient(
        clientFactory: () => MockClient((r) async {
          if (r.method == 'GET') {
            gets++;
            return http.Response(
              jsonEncode({
                'models': [
                  {
                    'name': 'models/gemini-future-flash',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
              }),
              200,
            );
          }
          posts++;
          expect(jsonDecode(r.body)['model'], 'gemini-future-flash');
          return http.Response(
            'data: {"choices":[{"delta":{"content":"OK"}}]}\n\ndata: [DONE]\n\n',
            200,
          );
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => state)],
          child: MaterialApp(home: ProviderPage(client: ai)),
        ),
      );
      await tester.pumpAndSettle();
      expect(gets, 0);
      expect(posts, 0);
      final refresh = find.text('تحديث النموذج تلقائيًا');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(gets, 1);
      expect(posts, 0);
      expect(find.text('gemini-future-flash'), findsOneWidget);
      final test = find.text('اختبار الاتصال');
      await tester.scrollUntilVisible(
        test,
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.tap(test);
      await tester.pumpAndSettle();
      expect(ai.tests, 1);
      expect(find.textContaining('نجح الاتصال بالنموذج'), findsOneWidget);
      final save = find.text('حفظ');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(state.config.model, 'gemini-future-flash');
      expect(state.config.autoModel, true);
      expect(gets, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'manual mode leaves chosen model editable without catalog calls',
    (tester) async {
      final state = AppState();
      await state.init();
      state.config = const AiConfig(key: 'test-key');
      final ai = AiClient(
        clientFactory: () =>
            MockClient((_) async => throw StateError('unexpected request')),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => state)],
          child: MaterialApp(home: ProviderPage(client: ai)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'النموذج المختار',
      );
      expect(tester.widget<TextField>(field).readOnly, false);
      await tester.enterText(field, 'custom-model');
      final save = find.text('حفظ');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(state.config.autoModel, false);
      expect(state.config.model, 'custom-model');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
