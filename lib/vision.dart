import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';

import 'engine.dart';
import 'services.dart';
import 'main.dart' show blue, Glass;

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});
  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  CameraController? camera;
  List<CameraDescription> cameras = [];
  final ai = AiClient();
  final voice = VoiceService();
  bool loading = true, live = false, working = false;
  String? error;
  String description = '';
  Timer? timer;
  int token = 0, lens = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(open());
  }

  Future<void> open() async {
    final id = ++token;
    try {
      cameras = await availableCameras();
      if (!mounted || id != token) return;
      if (cameras.isEmpty) throw CameraException('unavailable', 'No camera');
      final c = CameraController(
        cameras[lens % cameras.length],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      camera = c;
      await c.initialize();
      if (!mounted || id != token) {
        await c.dispose();
        return;
      }
      setState(() {
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted && id == token) {
        final failed = camera;
        camera = null;
        await failed?.dispose();
        if (!mounted || id != token) return;
        setState(() {
          loading = false;
          error = ref
              .read(appProvider)
              .tr(
                'تعذر فتح الكاميرا. راجع الإذن من إعدادات الجهاز.',
                'Camera unavailable. Check permission in device settings.',
              );
        });
      }
    }
  }

  void stop() {
    timer?.cancel();
    timer = null;
    live = false;
    working = false;
    token++;
    ai.cancel();
    unawaited(voice.stop());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      stop();
      final c = camera;
      camera = null;
      unawaited(c?.dispose());
      if (mounted) {
        setState(() {
          loading = true;
          working = false;
        });
      }
    } else if (camera == null) {
      unawaited(open());
    }
  }

  Future<void> analyze() async {
    final c = camera;
    if (working || c == null || !c.value.isInitialized) return;
    final s = ref.read(appProvider);
    if (!s.config.ready) {
      stop();
      setState(
        () => error = s.tr(
          'اربط AI من الإعدادات أولًا.',
          'Connect AI in Settings first.',
        ),
      );
      return;
    }
    final id = ++token;
    setState(() {
      working = true;
      error = null;
    });
    try {
      final photo = await c.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted || id != token) return;
      String result = '';
      await for (final chunk in ai.stream(s.config, systemPrompt(s.prefs, 'chat'), [
        Message(
          'user',
          s.tr(
            'صف الأشياء والنصوص الواضحة أمامي باختصار في جملتين. اذكر عدم اليقين. لا تعطِ إرشادات للمشي أو السلامة.',
            'Describe visible objects and readable text in two short sentences. State uncertainty. Do not give walking or safety directions.',
          ),
        ),
      ], attachment: Attachment('camera.jpg', 'image/jpeg', bytes))) {
        if (!mounted || id != token) return;
        result += chunk;
        setState(() => description = result);
      }
      if (s.prefs.speak && mounted && id == token) {
        await voice.read(result, s.prefs);
      }
    } catch (e) {
      if (mounted && id == token) {
        stop();
        setState(
          () => error = e is AiFailure
              ? e.message
              : s.tr('تعذر تحليل اللقطة.', 'Could not analyze frame.'),
        );
      }
    } finally {
      if (mounted && id == token) {
        setState(() => working = false);
      }
      if (mounted && live && id == token) {
        timer = Timer(const Duration(seconds: 4), analyze);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop();
    unawaited(camera?.dispose());
    unawaited(voice.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr('كاميرا لايف', 'Live camera'))),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : camera?.value.isInitialized == true
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: camera!.value.aspectRatio,
                        child: CameraPreview(camera!),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.no_photography_outlined,
                        size: 60,
                        color: blue,
                      ),
                    ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    error ??
                        (description.isEmpty
                            ? s.tr(
                                'اضغط تحليل. القراءة المتتابعة ترسل لقطات لمزودك كل عدة ثوانٍ؛ الصور لا تُحفظ في المعرض.',
                                'Analyze a scene. Repeated analysis sends frames to your provider every few seconds; images are not saved to your gallery.',
                              )
                            : description),
                  ),
                  if (working) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (!loading && camera == null)
                    FilledButton.icon(
                      onPressed: () {
                        setState(() => loading = true);
                        open();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        s.tr('إعادة محاولة الكاميرا', 'Retry camera'),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: loading || working || live || camera == null
                        ? null
                        : analyze,
                    icon: const Icon(Icons.camera),
                    label: Text(s.tr('تحليل', 'Analyze')),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading || camera == null || (working && !live)
                        ? null
                        : () {
                            if (live) {
                              setState(stop);
                            } else {
                              setState(() => live = true);
                              analyze();
                            }
                          },
                    icon: Icon(
                      live
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                    ),
                    label: Text(
                      live
                          ? s.tr('إيقاف', 'Stop')
                          : s.tr('قراءة متتابعة', 'Repeated analysis'),
                    ),
                  ),
                  IconButton(
                    onPressed: working || live || cameras.length < 2
                        ? null
                        : () async {
                            stop();
                            await camera?.dispose();
                            camera = null;
                            lens++;
                            if (mounted) {
                              setState(() => loading = true);
                              await open();
                            }
                          },
                    tooltip: s.tr('تبديل الكاميرا', 'Switch camera'),
                    icon: const Icon(Icons.cameraswitch_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenGuidePage extends ConsumerStatefulWidget {
  const ScreenGuidePage({super.key});
  @override
  ConsumerState<ScreenGuidePage> createState() => _ScreenGuidePageState();
}

class _ScreenGuidePageState extends ConsumerState<ScreenGuidePage>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('app.nok/screen_guide');
  bool enabled = false;
  String? error;
  bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (!android) return;
    try {
      final v = await channel.invokeMethod<bool>('isEnabled');
      if (mounted) {
        setState(() {
          enabled = v ?? false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = ref
              .read(appProvider)
              .tr(
                'خدمة أندرويد غير متاحة في هذه النسخة.',
                'Android service unavailable in this build.',
              ),
        );
      }
    }
  }

  Future<void> call(String method) async {
    try {
      await channel.invokeMethod(method, {
        'language': ref.read(appProvider).prefs.arabic ? 'ar' : 'en',
        'rate': ref.read(appProvider).prefs.rate,
        'volume': ref.read(appProvider).prefs.volume,
      });
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = ref
              .read(appProvider)
              .tr(
                'تعذر فتح الخدمة. راجع إعدادات إمكانية الوصول.',
                'Could not open service. Check accessibility settings.',
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr('مساعد الشاشة', 'Screen guide'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.accessibility_new, size: 64, color: blue),
          const SizedBox(height: 20),
          Text(
            s.tr('NOK معاك على الشاشة', 'NOK, with you on screen'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Text(
            s.tr(
              'بعد التفعيل من إعدادات أندرويد، تظهر لوحة عائمة لقراءة النص الحالي وتحديد العناصر بمؤشر. القراءة على الجهاز، ومحتوى الشاشة لا يُرسل لمزود AI.',
              'After enabling Android accessibility, a floating panel reads visible text and highlights elements. Reading is on-device; screen content is not sent to an AI provider.',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.tr(
              'حقول كلمات المرور مستثناة. النص داخل الصور والتطبيقات التي تمنع الوصول قد لا يظهر. يمكنك الإيقاف في أي وقت.',
              'Password fields are excluded. Text in images or restricted apps may be unavailable. You can stop at any time.',
            ),
          ),
          const SizedBox(height: 20),
          if (!android)
            Text(
              s.tr(
                'الميزة تعمل في تطبيق أندرويد فقط.',
                'Available in the Android app.',
              ),
            )
          else ...[
            Chip(
              label: Text(
                enabled
                    ? s.tr('الخدمة مفعّلة', 'Service enabled')
                    : s.tr('الخدمة غير مفعّلة', 'Service disabled'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => call(enabled ? 'showGuide' : 'openSettings'),
              child: Text(
                enabled
                    ? s.tr('إظهار لوحة المساعدة', 'Show guide panel')
                    : s.tr(
                        'فتح إعدادات إمكانية الوصول',
                        'Open accessibility settings',
                      ),
              ),
            ),
            TextButton(
              onPressed: () => call('openSettings'),
              child: Text(
                s.tr('إدارة إذن الخدمة', 'Manage service permission'),
              ),
            ),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 24),
          Glass(
            child: Text(
              s.tr(
                'النسخة الحالية: قراءة نص الشاشة ومؤشر العناصر. توجيه AI البصري والتنفيذ التلقائي لم يُفعّلا بعد.',
                'Current build: screen text reading and element highlighting. AI visual guidance and automatic execution are not enabled yet.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
