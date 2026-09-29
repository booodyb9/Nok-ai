import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nok_ai/engine.dart';

void main() {
  test('reject insecure endpoints', () {
    expect(
      () => AiClient.requestUri(
        const AiConfig(endpoint: 'http://example.com/v1', key: 'secret'),
      ),
      throwsA(isA<AiFailure>()),
    );
  });
  test('Ollama loopback and Azure deployment URI', () {
    expect(
      AiClient.requestUri(
        const AiConfig(
          provider: 'Ollama',
          endpoint: 'http://127.0.0.1:11434/v1',
          model: 'local',
        ),
      ).path,
      '/v1/chat/completions',
    );
    expect(
      AiClient.requestUri(
        const AiConfig(
          provider: 'Azure OpenAI',
          endpoint:
              'https://test.openai.azure.com/openai/deployments/test/chat/completions?api-version=2024-10-21',
        ),
      ).queryParameters['api-version'],
      '2024-10-21',
    );
  });
  test('provider image payloads', () {
    final image = Attachment(
      'x.png',
      'image/png',
      Uint8List.fromList([1, 2, 3]),
    );
    final messages = [Message('user', 'read')];
    expect(
      AiClient.payload(
        messages,
        image,
        false,
      ).single['content'][1]['image_url']['url'],
      'data:image/png;base64,AQID',
    );
    expect(
      AiClient.payload(
        messages,
        image,
        true,
      ).single['content'][1]['source']['data'],
      'AQID',
    );
  });
  test('Arabic history and tool mode survive restore', () {
    final c = Conversation(
      id: '1',
      title: 'أهلًا',
      mode: 'teacher',
      messages: [Message('user', 'مرحبا', file: 'a.png')],
    );
    final restored = Conversation.fromJson(jsonDecode(jsonEncode(c.toJson())));
    expect(restored.messages.single.text, 'مرحبا');
    expect(restored.mode, 'teacher');
    expect(jsonEncode(c.toJson()).contains('base64'), false);
  });
  test('disabled memory excluded from prompts', () {
    final p = Preferences(memory: 'PRIVATE_MEMORY', memoryEnabled: false);
    expect(systemPrompt(p, 'chat').contains('PRIVATE_MEMORY'), false);
    p.memoryEnabled = true;
    expect(systemPrompt(p, 'chat').contains('PRIVATE_MEMORY'), true);
  });
}
