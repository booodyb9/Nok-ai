import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nok_ai/engine.dart';
import 'package:nok_ai/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  Completer<void>? speaking;
  setUp(() {
    calls.clear();
    speaking = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak' && speaking != null) await speaking!.future;
      return 1;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (_) async => true,
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'portable voice preparation applies language, speed and volume without Android queue mode',
    () async {
      final voice = VoiceService();
      await voice.prepare(Preferences(rate: .6, volume: .3));
      expect(calls.any((c) => c.method == 'setQueueMode'), isFalse);
      expect(
        calls.firstWhere((c) => c.method == 'setSpeechRate').arguments,
        .6,
      );
      expect(calls.firstWhere((c) => c.method == 'setVolume').arguments, .3);
      expect(
        calls.firstWhere((c) => c.method == 'awaitSpeakCompletion').arguments,
        true,
      );
    },
  );
  test('Android uses flush mode because Dart serializes speech', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await VoiceService().prepare(Preferences());
    expect(calls.firstWhere((c) => c.method == 'setQueueMode').arguments, 0);
  });
  test(
    'short first sentence does not hold subsequent sentences in buffer',
    () async {
      final voice = VoiceService();
      await voice.prepare(Preferences());
      voice.add('أهلًا. الجملة الثانية واضحة.');
      await voice.queue;
      expect(calls.where((c) => c.method == 'speak').length, 2);
      expect(voice.buffer, isEmpty);
    },
  );
  test('stop discards queued sentences after active speech', () async {
    final voice = VoiceService();
    await voice.prepare(Preferences());
    speaking = Completer<void>();
    voice.add('First sentence. Second sentence.');
    await Future<void>.delayed(Duration.zero);
    final pending = voice.queue;
    await voice.stop();
    speaking!.complete();
    await pending;
    expect(calls.where((c) => c.method == 'speak').length, 1);
  });
  test(
    'read waits for speech completion before camera can schedule another frame',
    () async {
      final voice = VoiceService();
      speaking = Completer<void>();
      var finished = false;
      final reading = voice
          .read('Hello.', Preferences())
          .then((_) => finished = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(finished, isFalse);
      speaking!.complete();
      await reading;
      expect(finished, isTrue);
    },
  );
}
