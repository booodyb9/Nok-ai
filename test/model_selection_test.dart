import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nok_ai/engine.dart';

const reply =
    'data: {"choices":[{"delta":{"content":"OK"}}]}\n\ndata: [DONE]\n\n';
AiConfig config(String provider, {String key = 'test-key'}) => AiConfig(
  provider: provider,
  endpoint: providers[provider]!.$1,
  key: key,
  model: 'stale-model',
);
http.Response jsonResponse(Object body) => http.Response(jsonEncode(body), 200);
Map<String, Object> gemini(String id, {bool chat = true}) => {
  'name': 'models/$id',
  'supportedGenerationMethods': [if (chat) 'generateContent'],
};
void main() {
  test('old configurations migrate to automatic; manual choice persists', () {
    final old = config('Gemini').toJson()..remove('autoModel');
    expect(AiConfig.fromJson(old).autoModel, true);
    old['autoModel'] = false;
    expect(AiConfig.fromJson(old).toJson()['autoModel'], false);
  });
  test(
    'Gemini discovers actual chat models with header auth and pagination',
    () async {
      var calls = 0;
      final ai = AiClient(
        clientFactory: () => MockClient((r) async {
          calls++;
          expect(r.url.path, '/v1beta/models');
          expect(r.url.queryParameters.containsKey('key'), false);
          expect(r.headers['x-goog-api-key'], 'test-key');
          if (calls == 1) {
            return jsonResponse({
              'models': [gemini('embedding-test', chat: false)],
              'nextPageToken': 'next',
            });
          }
          expect(r.url.queryParameters['pageToken'], 'next');
          return jsonResponse({
            'models': [
              gemini('gemini-future-flash'),
              gemini('gemini-future-image-preview'),
            ],
          });
        }),
      );
      final models = await ai.catalog.list(config('Gemini'));
      expect(models.map((m) => m.id), ['gemini-future-flash']);
      expect(models.single.images, true);
      expect(calls, 2);
    },
  );
  test(
    'OpenAI rejects non-chat models and caches per credential with refresh',
    () async {
      var calls = 0;
      final ai = AiClient(
        clientFactory: () => MockClient((r) async {
          calls++;
          expect(r.url.toString(), 'https://api.openai.com/v1/models');
          return jsonResponse({
            'data': [
              for (final id in [
                'text-embedding-3-small',
                'gpt-image-1',
                'gpt-4.1-mini',
                'gpt-5-pro',
                'gpt-realtime',
              ])
                {'id': id},
            ],
          });
        }),
      );
      expect(
        (await ai.catalog.list(config('OpenAI'))).single.id,
        'gpt-4.1-mini',
      );
      await ai.catalog.list(config('OpenAI'));
      expect(calls, 1);
      await ai.catalog.list(config('OpenAI', key: 'changed-key'));
      await ai.catalog.list(
        config('OpenAI', key: 'changed-key'),
        refresh: true,
      );
      expect(calls, 3);
    },
  );
  test('Claude uses native authentication and after_id pagination', () async {
    var calls = 0;
    final ai = AiClient(
      clientFactory: () => MockClient((r) async {
        expect(r.url.path, '/v1/models');
        expect(r.headers['x-api-key'], 'test-key');
        expect(r.headers['anthropic-version'], '2023-06-01');
        if (calls++ == 0) {
          return jsonResponse({
            'data': [
              {'id': 'claude-sonnet-test'},
            ],
            'has_more': true,
            'last_id': 'claude-sonnet-test',
          });
        }
        expect(r.url.queryParameters['after_id'], 'claude-sonnet-test');
        return jsonResponse({
          'data': [
            {'id': 'claude-haiku-test'},
          ],
          'has_more': false,
        });
      }),
    );
    expect(
      (await ai.catalog.list(config('Claude'))).first.id,
      'claude-haiku-test',
    );
    expect(calls, 2);
  });
  for (final entry in {
    'Qwen': ('/compatible-mode/v1/models', 'qwen-plus'),
    'DeepSeek': ('/models', 'deepseek-chat'),
    'Ollama': ('/v1/models', 'llama-local:latest'),
  }.entries) {
    test('${entry.key} discovers available models from its endpoint', () async {
      final ai = AiClient(
        clientFactory: () => MockClient((r) async {
          expect(r.url.path, entry.value.$1);
          expect(
            r.headers['Authorization'],
            entry.key == 'Ollama' ? isNull : 'Bearer test-key',
          );
          return jsonResponse({
            'data': [
              {'id': entry.value.$2},
            ],
          });
        }),
      );
      final models = await ai.catalog.list(
        config(entry.key, key: entry.key == 'Ollama' ? '' : 'test-key'),
      );
      expect(models.single.id, entry.value.$2);
    });
  }
  test(
    'Azure reads exact deployment from URL without model-list requests',
    () async {
      final ai = AiClient(
        clientFactory: () =>
            MockClient((_) async => throw StateError('must not call HTTP')),
      );
      final models = await ai.catalog.list(
        const AiConfig(
          provider: 'Azure OpenAI',
          key: 'test',
          endpoint:
              'https://account.openai.azure.com/openai/deployments/my-custom-deployment/chat/completions?api-version=2024-10-21',
        ),
      );
      expect(models.single.id, 'my-custom-deployment');
      await expectLater(
        ai.catalog.list(
          const AiConfig(
            provider: 'Azure OpenAI',
            key: 'test',
            endpoint: 'https://account.openai.azure.com',
          ),
        ),
        throwsA(isA<AiFailure>()),
      );
    },
  );
  test(
    'OpenRouter uses account catalog and keeps free candidates only',
    () async {
      final ai = AiClient(
        clientFactory: () => MockClient((r) async {
          expect(r.url.path, '/api/v1/models/user');
          return jsonResponse({
            'data': [
              for (final id in ['vendor/paid', 'vendor/vision:free'])
                {
                  'id': id,
                  'architecture': {
                    'input_modalities': ['text', 'image'],
                    'output_modalities': ['text'],
                  },
                  'pricing': {'prompt': '1', 'completion': '1'},
                },
            ],
          });
        }),
      );
      final models = await ai.catalog.list(config('OpenRouter'));
      expect(models.single.id, 'vendor/vision:free');
      expect(models.single.images, true);
    },
  );
  test('invalid or empty catalog never invents a model', () async {
    for (final body in ['invalid-json', '{"data":[]}']) {
      final ai = AiClient(
        clientFactory: () => MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        ai.testConnection(config('OpenAI')),
        throwsA(isA<AiFailure>()),
      );
      expect(ai.lastModel, isNull);
    }
  });
  test(
    '503 retries then changes model; successful fallback is preferred',
    () async {
      final posts = <String>[];
      final ai = AiClient(
        retryDelay: Duration.zero,
        clientFactory: () => MockClient((r) async {
          if (r.method == 'GET') {
            return jsonResponse({
              'data': [
                {'id': 'gpt-4.1-mini'},
                {'id': 'gpt-4.1'},
              ],
            });
          }
          posts.add(jsonDecode(r.body)['model'] as String);
          return posts.length < 3
              ? http.Response('{}', 503)
              : http.Response(reply, 200);
        }),
      );
      await ai.testConnection(config('OpenAI'));
      expect(posts, ['gpt-4.1-mini', 'gpt-4.1-mini', 'gpt-4.1']);
      expect(ai.lastModel, 'gpt-4.1');
      expect((await ai.catalog.list(config('OpenAI'))).first.id, 'gpt-4.1');
    },
  );
  test(
    'missing model falls back but authentication, credits and rate limits do not',
    () async {
      for (final status in [404, 401, 402, 429]) {
        var posts = 0;
        final ai = AiClient(
          retryDelay: Duration.zero,
          clientFactory: () => MockClient((r) async {
            if (r.method == 'GET') {
              return jsonResponse({
                'data': [
                  {'id': 'gpt-4.1-mini'},
                  {'id': 'gpt-4.1'},
                ],
              });
            }
            return ++posts == 1
                ? http.Response('{}', status)
                : http.Response(reply, 200);
          }),
        );
        if (status == 404) {
          await ai.testConnection(config('OpenAI'));
          expect(posts, 2);
        } else {
          await expectLater(
            ai.testConnection(config('OpenAI')),
            throwsA(isA<AiFailure>()),
          );
          expect(posts, 1);
        }
      }
    },
  );
  test('partial response is never replayed after a streaming failure', () async {
    var posts = 0;
    final ai = AiClient(
      retryDelay: Duration.zero,
      clientFactory: () => MockClient((r) async {
        if (r.method == 'GET') {
          return jsonResponse({
            'data': [
              {'id': 'gpt-4.1-mini'},
            ],
          });
        }
        posts++;
        return http.Response(
          'data: {"choices":[{"delta":{"content":"partial"}}]}\n\ndata: {"error":{"code":503,"message":"temporary"}}\n\n',
          200,
        );
      }),
    );
    final chunks = <String>[];
    await expectLater(
      ai
          .stream(config('OpenAI'), 'test', [Message('user', 'test')])
          .forEach(chunks.add),
      throwsA(isA<AiFailure>()),
    );
    expect(chunks, ['partial']);
    expect(posts, 1);
  });
  test(
    'cancel during backoff stops retries and cannot report connection success',
    () async {
      var posts = 0;
      final attempted = Completer<void>();
      final ai = AiClient(
        retryDelay: const Duration(milliseconds: 40),
        clientFactory: () => MockClient((r) async {
          if (r.method == 'GET') {
            return jsonResponse({
              'data': [
                {'id': 'gpt-4.1-mini'},
              ],
            });
          }
          posts++;
          attempted.complete();
          return http.Response('{}', 503);
        }),
      );
      final result = expectLater(
        ai.testConnection(config('OpenAI')),
        throwsA(isA<AiFailure>()),
      );
      await attempted.future;
      ai.cancel();
      await result;
      expect(posts, 1);
    },
  );
  test(
    'image attachments choose a compatible model and reject text-only catalogs',
    () async {
      for (final hasVision in [true, false]) {
        final ai = AiClient(
          clientFactory: () => MockClient((r) async {
            if (r.method == 'GET') {
              return jsonResponse({
                'data': [
                  {'id': 'qwen-plus'},
                  if (hasVision) {'id': 'qwen-vl-plus'},
                ],
              });
            }
            expect(jsonDecode(r.body)['model'], 'qwen-vl-plus');
            return http.Response(reply, 200);
          }),
        );
        final result = ai.stream(
          config('Qwen'),
          'test',
          [Message('user', 'test')],
          attachment: Attachment('test.png', 'image/png', Uint8List(1)),
        ).toList();
        if (hasVision) {
          expect(await result, ['OK']);
        } else {
          await expectLater(result, throwsA(isA<AiFailure>()));
        }
      }
    },
  );
}
