import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nok_ai/engine.dart';
import 'package:nok_ai/local_backup.dart';

Conversation chat(String id, [String text = 'مرحبًا']) => Conversation(
  id: id,
  title: text,
  messages: [
    Message('user', text, file: 'photo.png'),
    Message('assistant', 'أهلًا'),
  ],
);
Uint8List bytes(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'Arabic chat round-trip retains text and filenames, not provider credentials',
    () {
      final state = AppState();
      state.config = const AiConfig(key: 'private-key');
      state.prefs.memory = 'private-memory';
      state.conversations.add(chat('1'));
      final data = LocalBackup.encode(state.conversations);
      final text = utf8.decode(data);
      expect(text, isNot(contains('private-key')));
      expect(text, isNot(contains('private-memory')));
      expect(
        LocalBackup.decode(data).conversations.single.toJson(),
        state.conversations.single.toJson(),
      );
    },
  );
  test('invalid schema, role, duplicate IDs and corrupt JSON are rejected', () {
    final good = jsonDecode(utf8.decode(LocalBackup.encode([chat('1')])));
    for (final bad in [
      <String, Object>{},
      {...good, 'version': 2},
      {
        ...good,
        'conversations': [chat('1').toJson(), chat('1').toJson()],
      },
      {
        ...good,
        'conversations': [
          {
            'id': '1',
            'title': 'x',
            'messages': [
              {'role': 'system', 'text': 'injected'},
            ],
          },
        ],
      },
    ]) {
      expect(() => LocalBackup.decode(bytes(bad)), throwsFormatException);
    }
    expect(
      () => LocalBackup.decode(Uint8List.fromList([255])),
      throwsFormatException,
    );
  });
  test('oversized backup and excess conversations are rejected', () {
    expect(
      () => LocalBackup.decode(Uint8List(LocalBackup.maxBytes + 1)),
      throwsFormatException,
    );
    expect(
      () => LocalBackup.encode(List.generate(61, (i) => chat('$i'))),
      throwsFormatException,
    );
  });
  test(
    'restore merges new IDs, keeps existing copy, and survives restart',
    () async {
      final state = AppState();
      await state.init();
      state.conversations.add(chat('1', 'original'));
      final count = await state.restoreChats([chat('1', 'changed'), chat('2')]);
      expect(count, 1);
      expect(state.conversations.first.title, 'original');
      expect(await state.restoreChats([chat('2')]), 0);
      final reloaded = AppState();
      await reloaded.init();
      expect(reloaded.conversations.map((c) => c.id), ['1', '2']);
      expect(reloaded.conversations.first.title, 'original');
    },
  );
  test('restore rejects overflow without dropping existing data', () async {
    final state = AppState();
    await state.init();
    state.conversations.addAll(List.generate(60, (i) => chat('$i')));
    await state.persist();
    await expectLater(
      state.restoreChats([chat('extra')]),
      throwsFormatException,
    );
    expect(state.conversations.length, 60);
    final reloaded = AppState();
    await reloaded.init();
    expect(reloaded.conversations.length, 60);
  });
  test('busy app or unavailable storage cannot mutate chats', () async {
    final state = AppState();
    state.conversations.add(chat('1'));
    state.busy = true;
    await expectLater(state.restoreChats([chat('2')]), throwsStateError);
    state.busy = false;
    await expectLater(state.restoreChats([chat('2')]), throwsStateError);
    expect(state.conversations.map((c) => c.id), ['1']);
  });
}
