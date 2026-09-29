import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nok_ai/engine.dart';

const config = AiConfig(
  autoModel: false,
  provider: 'OpenAI',
  endpoint: 'https://api.openai.com/v1',
  model: 'gpt-4.1-mini',
  key: 'test-secret',
);
const reply =
    'data: {"choices":[{"delta":{"content":"OK"}}]}\n\ndata: [DONE]\n\n';
AiClient client(int status, String body) => AiClient(
  clientFactory: () => MockClient((_) async => http.Response(body, status)),
);
Matcher failure(String text) =>
    isA<AiFailure>().having((e) => e.message, 'message', contains(text));
void main() {
  test(
    'connection test uses actual OpenAI streaming payload without history',
    () async {
      final ai = AiClient(
        clientFactory: () => MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.openai.com/v1/chat/completions',
          );
          expect(request.headers['Authorization'], 'Bearer test-secret');
          final body = jsonDecode(request.body) as Map;
          expect(body['max_completion_tokens'], 64);
          expect(body.containsKey('max_tokens'), false);
          expect(body['stream'], true);
          expect(body['messages'], [
            {'role': 'system', 'content': 'Reply briefly.'},
            {'role': 'user', 'content': 'Reply with OK.'},
          ]);
          return http.Response(reply, 200);
        }),
      );
      await ai.testConnection(config);
    },
  );
  test('complete endpoint does not duplicate suffix', () {
    for (final provider in ['OpenAI', 'OpenRouter']) {
      final base = providers[provider]!.$1;
      expect(
        AiClient.requestUri(
          AiConfig(
            autoModel: false,
            provider: provider,
            endpoint: '$base/chat/completions/',
          ),
        ).toString(),
        '$base/chat/completions',
      );
    }
  });
  test(
    'OpenAI rejects foreign endpoint before transmitting credentials',
    () async {
      var sent = false;
      final ai = AiClient(
        clientFactory: () => MockClient((_) async {
          sent = true;
          return http.Response(reply, 200);
        }),
      );
      await expectLater(
        ai.testConnection(
          const AiConfig(
            autoModel: false,
            provider: 'OpenAI',
            endpoint: 'https://example.com/v1',
            model: 'gpt-4.1-mini',
            key: 'test-secret',
          ),
        ),
        throwsA(failure('official')),
      );
      expect(sent, false);
    },
  );
  test(
    'quota, rate limit, credits and authentication are distinguished',
    () async {
      await expectLater(
        client(
          429,
          '{"error":{"code":"insufficient_quota"}}',
        ).testConnection(config),
        throwsA(failure('quota')),
      );
      await expectLater(
        client(429, '{}').testConnection(config),
        throwsA(failure('Rate limit')),
      );
      await expectLater(
        client(402, '{}').testConnection(config),
        throwsA(failure('credits')),
      );
      await expectLater(
        client(401, '{}').testConnection(config),
        throwsA(failure('revoked')),
      );
    },
  );
  test('400 includes actionable details and redacts credentials', () async {
    final error = AiClient.responseFailure(
      400,
      jsonEncode({
        'error': {
          'message':
              'Unsupported parameter max_tokens test-secret sk-other-secret Bearer another-secret',
          'param': 'max_tokens',
          'code': 'unsupported_parameter',
        },
      }),
      secret: 'test-secret',
    );
    expect(error.message, contains('Unsupported parameter'));
    expect(error.message, contains('param: max_tokens'));
    for (final secret in ['test-secret', 'sk-other-secret', 'another-secret']) {
      expect(error.message, isNot(contains(secret)));
    }
    await expectLater(
      client(
        400,
        '{"error":{"message":"Unsupported model"}}',
      ).testConnection(config),
      throwsA(failure('Unsupported model')),
    );
  });
  test('empty stream cannot report successful connection', () async {
    await expectLater(
      client(200, 'data: [DONE]\n\n').testConnection(config),
      throwsA(failure('No text')),
    );
  });
  test('OpenRouter supplies usable default model and max_tokens', () async {
    final provider = providers['OpenRouter']!;
    final ai = AiClient(
      clientFactory: () => MockClient((r) async {
        final body = jsonDecode(r.body);
        expect(body['model'], 'openrouter/free');
        expect(body['max_tokens'], 64);
        return http.Response(reply, 200);
      }),
    );
    await ai.testConnection(
      AiConfig(
        autoModel: false,
        provider: 'OpenRouter',
        endpoint: provider.$1,
        model: provider.$2,
        key: 'test-secret',
      ),
    );
  });
  test('mid-stream errors retain sanitized provider explanation', () async {
    await expectLater(
      client(
        200,
        'data: {"error":{"code":400,"message":"Bad model test-secret"}}\n\n',
      ).testConnection(config),
      throwsA(failure('Bad model [hidden]')),
    );
  });
  test('invalid key formatting is rejected locally', () async {
    await expectLater(
      client(200, reply).testConnection(
        const AiConfig(
          autoModel: false,
          provider: 'OpenAI',
          endpoint: 'https://api.openai.com/v1',
          model: 'gpt-4.1-mini',
          key: 'Bearer test-secret',
        ),
      ),
      throwsA(failure('without spaces')),
    );
  });
}
