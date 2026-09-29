part of 'engine.dart';

class ModelOption {
  final String id;
  final bool images, pdf, free;
  const ModelOption(
    this.id, {
    this.images = false,
    this.pdf = false,
    this.free = false,
  });
}

class ModelCatalog {
  ModelCatalog({required this.clientFactory});
  final http.Client Function() clientFactory;
  http.Client? _active;
  int _generation = 0;
  AiConfig? _cachedConfig;
  DateTime? _cachedAt;
  List<ModelOption> _cached = [];

  void prefer(String id) {
    final at = _cached.indexWhere((m) => m.id == id);
    if (at > 0) _cached.insert(0, _cached.removeAt(at));
  }

  void cancel() {
    _generation++;
    _active?.close();
    _active = null;
  }

  Future<List<ModelOption>> list(
    AiConfig config, {
    bool refresh = false,
  }) async {
    if (config.endpoint.isEmpty ||
        (config.provider != 'Ollama' && config.key.isEmpty)) {
      throw const AiFailure(
        'أضف المفتاح وعنوان المزود أولًا / Enter provider key and endpoint first',
      );
    }
    if (RegExp(r'\s').hasMatch(config.key)) {
      throw const AiFailure(
        'الصق المفتاح فقط بدون مسافات أو Bearer / Paste only the key without spaces or Bearer',
      );
    }
    final chat = AiClient.requestUri(config);
    if (config.provider == 'Azure OpenAI') {
      final at = chat.pathSegments.indexOf('deployments');
      if (at >= 0 &&
          at + 1 < chat.pathSegments.length &&
          chat.pathSegments[at + 1].isNotEmpty) {
        // Azure deployment capabilities cannot be inferred from its custom name.
        return [ModelOption(chat.pathSegments[at + 1])];
      }
      throw const AiFailure(
        'Azure: أدخل رابط Deployment الكامل لاستخراج اسمه تلقائيًا، أو اختره يدويًا / Supply a full deployment URL or select the deployment manually',
      );
    }
    if (!refresh &&
        _cachedConfig?.provider == config.provider &&
        _cachedConfig?.endpoint == config.endpoint &&
        _cachedConfig?.key == config.key &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 10)) {
      return List.of(_cached);
    }
    final generation = _generation;
    final client = clientFactory();
    _active = client;
    try {
      var uri = chat.replace(
        path: chat.path.replaceFirst(
          RegExp(r'/(chat/completions|messages)$'),
          '/models',
        ),
      );
      final headers = <String, String>{'Accept': 'application/json'};
      if (config.provider == 'Gemini') {
        uri = chat.replace(
          path: chat.path.replaceFirst(
            RegExp(r'/openai/chat/completions$'),
            '/models',
          ),
          queryParameters: {'pageSize': '1000'},
        );
        headers['x-goog-api-key'] = config.key;
      } else if (config.provider == 'Claude') {
        headers.addAll({
          'x-api-key': config.key,
          'anthropic-version': '2023-06-01',
        });
        uri = uri.replace(queryParameters: {'limit': '100'});
      } else if (config.key.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${config.key}';
      }
      if (config.provider == 'OpenRouter') {
        uri = uri.replace(path: '${uri.path}/user');
      }
      final options = <ModelOption>[];
      for (var page = 0; page < 5; page++) {
        if (generation != _generation) {
          throw const AiFailure('تم الإلغاء / Cancelled');
        }
        final response = await client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw AiClient.responseFailure(
            response.statusCode,
            response.body,
            secret: config.key,
          );
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        options.addAll(parse(config.provider, decoded));
        final token = decoded['nextPageToken'];
        if (config.provider == 'Gemini' &&
            token is String &&
            token.isNotEmpty) {
          uri = uri.replace(
            queryParameters: {'pageSize': '1000', 'pageToken': token},
          );
        } else if (config.provider == 'Claude' &&
            decoded['has_more'] == true &&
            decoded['last_id'] is String) {
          uri = uri.replace(
            queryParameters: {
              'limit': '100',
              'after_id': decoded['last_id'] as String,
            },
          );
        } else {
          break;
        }
      }
      if (generation != _generation) {
        throw const AiFailure('تم الإلغاء / Cancelled');
      }
      var unique = {for (final m in options) m.id: m}.values.toList();
      // Never switch from a free OpenRouter candidate to a paid fallback.
      if (config.provider == 'OpenRouter' && unique.any((m) => m.free)) {
        unique = unique.where((m) => m.free).toList();
      }
      unique.sort((a, b) {
        final rank = score(
          config.provider,
          b,
        ).compareTo(score(config.provider, a));
        return rank != 0 ? rank : b.id.compareTo(a.id);
      });
      if (unique.isEmpty) {
        throw const AiFailure(
          'لم يُرجع المزود نماذج محادثة متوافقة. راجع حسابك أو اختر يدويًا / No compatible chat models returned; check account or select manually',
        );
      }
      _cachedConfig = config;
      _cachedAt = DateTime.now();
      _cached = unique;
      return List.of(unique);
    } on TimeoutException {
      throw const AiFailure(
        'انتهت مهلة جلب النماذج / Model discovery timed out',
      );
    } on http.ClientException {
      throw const AiFailure(
        'تعذر جلب النماذج؛ راجع الاتصال أو اختر يدويًا / Model discovery connection failed; check network or select manually',
      );
    } on FormatException {
      throw const AiFailure(
        'رد قائمة النماذج غير صالح / Invalid model list response',
      );
    } finally {
      client.close();
      if (identical(_active, client)) _active = null;
    }
  }

  static List<ModelOption> parse(String provider, Map<String, dynamic> json) {
    final raw = json[provider == 'Gemini' ? 'models' : 'data'];
    if (raw is! List) return [];
    final result = <ModelOption>[];
    for (final item in raw.whereType<Map>()) {
      final value = item[provider == 'Gemini' ? 'name' : 'id'];
      if (value is! String || value.isEmpty) continue;
      final id = value.replaceFirst(RegExp(r'^models/'), '');
      final name = id.toLowerCase();
      if (RegExp(
        r'embed|rerank|moderation|whisper|tts|transcri|realtime|audio|imagen|dall-e|image-generation|image-preview|text-to-image|(^|/)sora|(^|/)veo',
      ).hasMatch(name)) {
        continue;
      }
      if (provider == 'Gemini' &&
          (!(item['supportedGenerationMethods'] is List &&
                  (item['supportedGenerationMethods'] as List).contains(
                    'generateContent',
                  )) ||
              !name.startsWith('gemini-'))) {
        continue;
      }
      if (provider == 'OpenAI' &&
          (!name.startsWith('gpt-') ||
              RegExp(
                r'codex|search|instruct|image|pro($|-)|gpt-3',
              ).hasMatch(name))) {
        continue;
      }
      if (provider == 'Claude' && !name.startsWith('claude-')) continue;
      if (provider == 'Qwen' && !name.startsWith('qwen')) continue;
      var vision =
          provider == 'Gemini' ||
          provider == 'Claude' ||
          (provider == 'OpenAI' &&
              RegExp(r'^gpt-(4o|4\.1|[5-9])').hasMatch(name)) ||
          ((provider == 'Qwen' || provider == 'Ollama') &&
              RegExp(r'vl|vision|llava|gemma3').hasMatch(name));
      var pdf = provider == 'Claude' || (provider == 'OpenAI' && vision);
      var free = false;
      if (provider == 'OpenRouter') {
        final architecture = item['architecture'];
        if (architecture is! Map) continue;
        final output = architecture['output_modalities'],
            input = architecture['input_modalities'];
        if (output is! List ||
            !output.contains('text') ||
            input is! List ||
            !input.contains('text')) {
          continue;
        }
        vision = input.contains('image');
        pdf = input.contains('file');
        final pricing = item['pricing'];
        free =
            id == 'openrouter/free' ||
            name.endsWith(':free') ||
            (pricing is Map &&
                num.tryParse('${pricing['prompt']}') == 0 &&
                num.tryParse('${pricing['completion']}') == 0);
      }
      result.add(ModelOption(id, images: vision, pdf: pdf, free: free));
    }
    return result;
  }

  static int score(String provider, ModelOption model) {
    final n = model.id.toLowerCase();
    var score = 0;
    if (model.images) score += 15;
    if (model.free) score += 100;
    if (n == 'openrouter/free') score += 200;
    if (RegExp(r'preview|experimental|exp-|beta').hasMatch(n)) score -= 40;
    if (RegExp(r'flash|mini|haiku|turbo|deepseek-chat').hasMatch(n)) {
      score += 40;
    }
    if (n.contains('lite') || n.contains('nano')) score -= 10;
    if (n.contains('reasoner') || n.contains('thinking')) score -= 20;
    if (model.id == providers[provider]?.$2) score += 5;
    return score;
  }
}
