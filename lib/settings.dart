import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'engine.dart';
import 'services.dart';
import 'main.dart' show Glass, blue, confirm;
import 'vision.dart';

class SettingsPage extends ConsumerWidget {
  final VoidCallback onVoice;
  const SettingsPage({super.key, required this.onVoice});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    void change(VoidCallback f) {
      f();
      s.savePrefs();
    }

    Widget heading(String ar, String en) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        s.tr(ar, en),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          s.tr('الإعدادات', 'Settings'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Image.asset(
              'assets/images/nok-robot.png',
              width: 80,
              height: 90,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NOK',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: blue,
                    ),
                  ),
                  Text(s.tr('اضبط مساعدك على راحتك', 'Make NOK feel like you')),
                ],
              ),
            ),
          ],
        ),
        heading('الذكاء الاصطناعي', 'Artificial intelligence'),
        Glass(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProviderPage()),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: blue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.config.provider,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      s.config.ready
                          ? s.config.model
                          : s.tr(
                              'أضف المفتاح للبدء',
                              'Add a key to get started',
                            ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        heading('المساعد والصوت', 'Assistant & voice'),
        Glass(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: Text(s.tr('قراءة الرد صوتيًا', 'Read replies aloud')),
                subtitle: Text(
                  s.tr(
                    'يبدأ مع وصول أول جملة',
                    'Starts with the first complete sentence',
                  ),
                ),
                value: s.prefs.speak,
                onChanged: (v) => change(() => s.prefs.speak = v),
              ),
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: Text(s.tr('جرّب صوت NOK', 'Test NOK’s voice')),
                onTap: onVoice,
              ),
              ListTile(
                title: Text(s.tr('سرعة الكلام', 'Speech speed')),
                subtitle: Slider(
                  value: s.prefs.rate,
                  min: .25,
                  max: .7,
                  divisions: 9,
                  onChanged: (v) => change(() => s.prefs.rate = v),
                ),
              ),
              ListTile(
                title: Text(s.tr('مستوى الصوت', 'Volume')),
                subtitle: Slider(
                  value: s.prefs.volume,
                  onChanged: (v) => change(() => s.prefs.volume = v),
                ),
              ),
            ],
          ),
        ),
        heading('المظهر وإمكانية الوصول', 'Appearance & accessibility'),
        Glass(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: Text(s.tr('الوضع الداكن', 'Dark appearance')),
                value: s.prefs.dark,
                onChanged: (v) => change(() => s.prefs.dark = v),
              ),
              SwitchListTile(
                title: Text(s.tr('واجهة مبسطة', 'Simplified home')),
                value: s.prefs.simple,
                onChanged: (v) => change(() => s.prefs.simple = v),
              ),
              SwitchListTile(
                title: Text(s.tr('تقليل الحركة', 'Reduce motion')),
                value: s.prefs.reducedMotion,
                onChanged: (v) => change(() => s.prefs.reducedMotion = v),
              ),
              ListTile(
                title: Text(s.tr('حجم النص', 'Text size')),
                subtitle: Slider(
                  value: s.prefs.scale,
                  min: 1,
                  max: 1.4,
                  divisions: 4,
                  label: '${(s.prefs.scale * 100).round()}%',
                  onChanged: (v) => change(() => s.prefs.scale = v),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(s.tr('اللغة', 'Language')),
                trailing: Text(s.prefs.arabic ? 'العربية' : 'English'),
                onTap: () => change(() => s.prefs.arabic = !s.prefs.arabic),
              ),
              ListTile(
                leading: const Icon(Icons.accessibility_new),
                title: Text(s.tr('مساعد الشاشة', 'Screen guide')),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScreenGuidePage()),
                ),
              ),
            ],
          ),
        ),
        heading('الخصوصية والذاكرة', 'Privacy & memory'),
        Glass(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: Text(s.tr('ذاكرة NOK', 'NOK memory')),
                subtitle: Text(
                  s.tr(
                    'التفضيلات التي تختار حفظها بنفسك',
                    'Preferences you choose to save',
                  ),
                ),
                value: s.prefs.memoryEnabled,
                onChanged: (v) => change(() => s.prefs.memoryEnabled = v),
              ),
              ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: Text(s.tr('تعديل الذاكرة', 'Edit memory')),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MemoryPage()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(
                  s.tr('الحساب والنسخة السحابية', 'Account & cloud backup'),
                ),
                subtitle: Text(
                  CloudService.enabled
                      ? (CloudService.user?.email ??
                            s.tr('سجّل الدخول', 'Sign in'))
                      : s.tr(
                          'لم يُربط Firebase بعد',
                          'Firebase is not connected yet',
                        ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountPage()),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: Text(
                  s.tr('مسح بيانات الجهاز', 'Clear device data'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  if (await confirm(
                        context,
                        s.tr(
                          'حذف المحادثات والذاكرة والمفتاح من الجهاز؟',
                          'Delete device chats, memory, and API key?',
                        ),
                        s,
                      ) ==
                      true) {
                    await s.clear();
                  }
                },
              ),
            ],
          ),
        ),
        heading('حول NOK', 'About NOK'),
        Text(
          s.tr(
            'الإصدار 0.1.1 · نسخة أولية\nالطلبات والمرفقات تُرسل إلى مزودك المختار. المحادثات محفوظة على الجهاز، والنسخة السحابية اختيارية.',
            'Version 0.1.1 · Early build\nRequests and attachments go to your chosen provider. Chats are stored on-device; cloud backup is optional.',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class ProviderPage extends ConsumerStatefulWidget {
  const ProviderPage({super.key, this.client});
  final AiClient? client;
  @override
  ConsumerState<ProviderPage> createState() => _ProviderPageState();
}

class _ProviderPageState extends ConsumerState<ProviderPage> {
  late String provider;
  late final TextEditingController key, model, endpoint;
  bool reveal = false, busy = false, automatic = true;
  List<ModelOption> availableModels = [];
  String? error, connectionResult;
  late final AiClient connection;
  @override
  void initState() {
    super.initState();
    final c = ref.read(appProvider).config;
    connection = widget.client ?? AiClient();
    automatic = c.autoModel;
    provider = c.provider;
    key = TextEditingController(text: c.key);
    model = TextEditingController(
      text: c.provider == 'OpenRouter' && c.model.isEmpty
          ? providers['OpenRouter']!.$2
          : c.model,
    );
    endpoint = TextEditingController(text: c.endpoint);
  }

  @override
  void dispose() {
    connection.cancel();
    key.dispose();
    model.dispose();
    endpoint.dispose();
    super.dispose();
  }

  AiConfig currentConfig() => AiConfig(
    provider: provider,
    endpoint: endpoint.text.trim(),
    model: model.text.trim(),
    key: key.text.trim(),
    autoModel: automatic,
  );

  void clearResult(String _) => setState(() {
    error = null;
    connectionResult = null;
    availableModels = [];
  });

  Future<AiConfig> resolveSelection() async {
    final c = currentConfig();
    if (!automatic) return c;
    final models = await connection.catalog.list(c);
    if (!mounted) throw const AiFailure('تم الإلغاء / Cancelled');
    setState(() {
      availableModels = models;
      model.text = models.first.id;
    });
    return currentConfig();
  }

  Future<void> refreshModels() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      connectionResult = null;
    });
    try {
      final models = await connection.catalog.list(
        currentConfig(),
        refresh: true,
      );
      if (mounted) {
        setState(() {
          availableModels = models;
          model.text = models.first.id;
          connectionResult = ref
              .read(appProvider)
              .tr(
                'تم اختيار ${model.text}. اختبر الاتصال للتأكد من استجابته.',
                'Selected ${model.text}. Test the connection to verify it responds.',
              );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AiFailure
              ? e.message
              : 'تعذر جلب النماذج؛ يمكنك الاختيار يدويًا / Could not discover models; manual selection is available',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> testConnection() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      connectionResult = null;
    });
    try {
      final c = await resolveSelection();
      await connection.testConnection(c);
      if (mounted && connection.lastModel != null) {
        model.text = connection.lastModel!;
      }
      if (mounted) {
        setState(
          () => connectionResult = ref
              .read(appProvider)
              .tr(
                'نجح الاتصال بالنموذج ${model.text}. اضغط حفظ لاستخدامه.',
                'Model ${model.text} responded successfully. Save to use these settings.',
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AiFailure
              ? e.message
              : 'تعذر قراءة رد المزود / Could not read provider response',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr('مزود الذكاء الاصطناعي', 'AI provider'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            s.tr(
              'اختار مزودك وأضف مفتاحك. يُحفظ المفتاح بأمان على أندرويد.',
              'Choose a provider and add your key. Android stores the key securely.',
            ),
          ),
          if (kIsWeb)
            Text(
              s.tr(
                'معاينة الويب: المفتاح مؤقت للجلسة، وقد يمنع المزود طلبات المتصفح.',
                'Web preview: keys last only for this session; provider CORS rules may block browser requests.',
              ),
            ),
          const SizedBox(height: 22),
          DropdownButtonFormField<String>(
            initialValue: provider,
            decoration: InputDecoration(labelText: s.tr('المزود', 'Provider')),
            items: providers.keys
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: busy
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      provider = v;
                      availableModels = [];
                      endpoint.text = providers[v]!.$1;
                      model.text = providers[v]!.$2;
                      key.clear();
                      error = null;
                      connectionResult = null;
                    });
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: key,
            enabled: !busy,
            onChanged: clearResult,
            obscureText: !reveal,
            autocorrect: false,
            enableSuggestions: false,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: s.tr('مفتاح API', 'API key'),
              suffixIcon: IconButton(
                tooltip: s.tr('إظهار أو إخفاء', 'Show or hide'),
                onPressed: () => setState(() => reveal = !reveal),
                icon: Icon(
                  reveal
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              s.tr('اختيار النموذج تلقائيًا', 'Automatic model selection'),
            ),
            subtitle: Text(
              s.tr(
                'يجلب نماذج المزود عند الحفظ أو اختبار الاتصال.',
                'Discovers provider models when saving or testing.',
              ),
            ),
            value: automatic,
            onChanged: busy
                ? null
                : (value) => setState(() {
                    automatic = value;
                    error = null;
                    connectionResult = null;
                  }),
          ),
          if (automatic)
            OutlinedButton.icon(
              onPressed: busy ? null : refreshModels,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                s.tr('تحديث النموذج تلقائيًا', 'Refresh automatic selection'),
              ),
            ),
          if (!automatic && availableModels.isNotEmpty)
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: s.tr('النماذج المكتشفة', 'Discovered models'),
              ),
              items: availableModels
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.id, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (id) {
                      if (id != null) {
                        setState(() {
                          model.text = id;
                          error = null;
                          connectionResult = null;
                        });
                      }
                    },
            ),
          TextField(
            controller: model,
            readOnly: automatic,
            enabled: !busy,
            onChanged: clearResult,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: s.tr('النموذج المختار', 'Selected model'),
              helperText: automatic
                  ? s.tr(
                      'يتحدد تلقائيًا عند الحفظ أو الاختبار',
                      'Selected automatically on save or test',
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: endpoint,
            enabled: !busy,
            onChanged: clearResult,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'API endpoint'),
          ),
          const SizedBox(height: 14),
          Text(
            s.tr(
              'الاختيار التلقائي يستخدم قائمة المزود، لكن الاستجابة تعتمد على رصيدك وصلاحياتك. Azure يحتاج رابط Deployment كاملًا؛ Ollama يحتاج خادمًا متاحًا ونموذجًا مثبتًا. يمكنك إيقاف الاختيار التلقائي للتحديد يدويًا.',
              'Automatic selection uses the provider catalog; access and credits still apply. Azure needs a full deployment URL; Ollama needs a reachable server with installed models. Turn off automatic selection to choose manually.',
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          Text(
            s.tr(
              'الاختبار يرسل طلبًا قصيرًا وقد يستهلك رصيدًا. عند عطل مؤقت نحاول حتى 3 مرات. لا يرسل الاختبار محادثاتك أو ذاكرتك.',
              'The test sends a small request and may use credits. Temporary failures allow up to 3 attempts. The test sends no chat history or memory.',
            ),
            style: const TextStyle(fontSize: 13),
          ),
          if (provider == 'OpenAI')
            Text(
              s.tr(
                'فوترة OpenAI API منفصلة عن اشتراك ChatGPT.',
                'OpenAI API billing is separate from a ChatGPT subscription.',
              ),
            ),
          if (provider == 'OpenRouter')
            Text(
              s.tr(
                'نفضّل النماذج المجانية إن كانت متاحة في قائمتك، مع مراعاة حدود الاستخدام والتوفر.',
                'Free models are preferred when present in your catalog, subject to usage limits and availability.',
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : testConnection,
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: Text(s.tr('اختبار الاتصال', 'Test connection')),
          ),
          if (connectionResult != null)
            Text(connectionResult!, semanticsLabel: connectionResult),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                      connectionResult = null;
                    });
                    try {
                      final c = await resolveSelection();
                      if (!mounted) return;
                      if (!c.ready) {
                        throw const AiFailure(
                          'أكمل البيانات المطلوبة / Complete required fields',
                        );
                      }
                      await s.saveConfig(c);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        setState(
                          () => error = e is AiFailure
                              ? e.message
                              : s.tr(
                                  'تعذر حفظ المفتاح بأمان.',
                                  'Could not save key securely.',
                                ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            icon: const Icon(Icons.check),
            label: Text(s.tr('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }
}

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});
  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  late final TextEditingController text;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: ref.read(appProvider).prefs.memory);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr('ذاكرة NOK', 'NOK memory'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            s.tr(
              'اكتب اسمك وتفضيلاتك وأسلوب الرد اللي تحبه. تقدر تعدّل أو تمسح كل شيء.',
              'Save your name, preferences, and response style. You can edit or erase them any time.',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: text,
            minLines: 8,
            maxLines: 16,
            maxLength: 3000,
            decoration: InputDecoration(
              hintText: s.tr(
                'اسمي عبده وأحب الردود المختصرة بالمصري.',
                'I prefer short, step-by-step replies.',
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              s.prefs.memory = text.text.trim();
              await s.savePrefs();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(s.tr('حفظ الذاكرة', 'Save memory')),
          ),
        ],
      ),
    );
  }
}

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final email = TextEditingController(), password = TextEditingController();
  bool register = false, busy = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() => message = ref.read(appProvider).tr('تم بنجاح', 'Done'));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => message = e.code);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = ref
              .read(appProvider)
              .tr(
                'تعذرت العملية. راجع الاتصال وإعدادات الحساب.',
                'Could not complete. Check connection and account setup.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr('الحساب والمزامنة', 'Account & backup'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!CloudService.enabled) ...[
            const Icon(Icons.cloud_off_outlined, size: 55, color: blue),
            const SizedBox(height: 22),
            Text(
              s.tr(
                'لم يتم ربط Firebase بعد. تسجيل الدخول والنسخ السحابي يحتاجان إعداد مشروعك. النسخة الحالية تحفظ المحادثات على الجهاز وتستخدم مفتاح مزودك.',
                'Firebase is not connected yet. Sign-in and cloud backup require your project configuration. Device storage and your AI provider key work independently.',
              ),
            ),
          ] else if (CloudService.user == null) ...[
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: s.tr('البريد الإلكتروني', 'Email'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: s.tr('كلمة المرور', 'Password'),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => run(
                      () => CloudService.login(
                        email.text.trim(),
                        password.text,
                        register,
                      ),
                    ),
              child: Text(
                register
                    ? s.tr('إنشاء حساب', 'Create account')
                    : s.tr('تسجيل الدخول', 'Sign in'),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() => register = !register),
              child: Text(
                register
                    ? s.tr('لديّ حساب', 'I have an account')
                    : s.tr('حساب جديد', 'New account'),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => run(
                      () => FirebaseAuth.instance.sendPasswordResetEmail(
                        email: email.text.trim(),
                      ),
                    ),
              child: Text(s.tr('نسيت كلمة المرور', 'Reset password')),
            ),
          ] else ...[
            Text(CloudService.user!.email ?? ''),
            const SizedBox(height: 14),
            Text(
              s.tr(
                'النسخ هنا يدوي عند الضغط فقط. مفاتيح AI لا تُرفع.',
                'Backup is manual. AI keys are never included.',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : () => run(() => CloudService.backup(s)),
              child: Text(s.tr('حفظ نسخة سحابية', 'Back up now')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: busy ? null : () => run(() => CloudService.restore(s)),
              child: Text(
                s.tr(
                  'استعادة المحادثات الناقصة',
                  'Restore missing conversations',
                ),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => run(() => FirebaseAuth.instance.signOut()),
              child: Text(s.tr('تسجيل الخروج', 'Sign out')),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (await confirm(
                            context,
                            s.tr(
                              'حذف البيانات السحابية؟',
                              'Delete cloud data?',
                            ),
                            s,
                          ) ==
                          true) {
                        await run(CloudService.deleteData);
                      }
                    },
              child: Text(
                s.tr('حذف البيانات السحابية', 'Delete cloud data'),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
          if (busy) const LinearProgressIndicator(),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(message!),
            ),
        ],
      ),
    );
  }
}
