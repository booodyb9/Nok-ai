import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'engine.dart';
import 'services.dart';
import 'settings.dart';
import 'vision.dart';

const blue = Color(0xff7acfff), background = Color(0xff050c13);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final s = AppState();
  await s.init();
  await CloudService.init();
  runApp(
    ProviderScope(
      overrides: [appProvider.overrideWith((ref) => s)],
      child: const NokApp(),
    ),
  );
}

ThemeData theme(bool dark) => ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoSansArabic',
  brightness: dark ? Brightness.dark : Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff258fce),
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: dark ? blue : const Color(0xff086b9c)),
  scaffoldBackgroundColor: dark ? background : const Color(0xffeef6fc),
  appBarTheme: AppBarTheme(
    backgroundColor: dark ? background : const Color(0xffeef6fc),
    centerTitle: true,
    scrolledUnderElevation: 0,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 16, height: 1.5),
    bodyLarge: TextStyle(fontSize: 17, height: 1.5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 72,
    backgroundColor: dark ? const Color(0xff07111b) : Colors.white,
    indicatorColor: dark ? const Color(0xff17384f) : const Color(0xffceeaff),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
);

class NokApp extends ConsumerWidget {
  const NokApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    return MaterialApp(
      title: 'NOK AI',
      debugShowCheckedModeBanner: false,
      theme: theme(false),
      darkTheme: theme(true),
      themeMode: s.prefs.dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(s.prefs.arabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(s.prefs.scale),
          disableAnimations: s.prefs.reducedMotion,
        ),
        child: child!,
      ),
      home: const Shell(),
    );
  }
}

class Glass extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const Glass({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xff172938), Color(0xff0a141e)]
              : const [Colors.white, Color(0xffdfedf7)],
        ),
        border: Border.all(
          color: dark ? const Color(0xff2c465b) : const Color(0xffbfd6e5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  int tab = 0;
  bool listening = false;
  final input = TextEditingController();
  final voice = VoiceService();
  AppState get s => ref.read(appProvider);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    input.dispose();
    unawaited(voice.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(voice.stop());
      if (mounted) setState(() => listening = false);
    }
  }

  void notice(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  void chat([String mode = 'chat']) {
    s.start(mode);
    setState(() => tab = 1);
  }

  Future<void> send() async {
    if (s.busy || (input.text.trim().isEmpty && s.attachment == null)) return;
    if (!s.config.ready) {
      setState(() => tab = 3);
      notice(s.tr('أضف مفتاح AI من الإعدادات.', 'Add an AI key in Settings.'));
      return;
    }
    final text = input.text;
    input.clear();
    setState(() {
      tab = 1;
      listening = false;
    });
    bool read = s.prefs.speak;
    try {
      if (read) {
        await voice.prepare(s.prefs);
      } else {
        await voice.stop();
      }
    } catch (_) {
      read = false;
      notice(
        s.tr(
          'الصوت غير متاح على الجهاز.',
          'Voice is unavailable on this device.',
        ),
      );
    }
    final voiceToken = voice.generation;
    await s.send(
      text,
      onChunk: read
          ? (chunk) {
              if (voice.generation == voiceToken) voice.add(chunk);
            }
          : null,
    );
    if (read && voice.generation == voiceToken) voice.finish();
  }

  Future<void> listen() async {
    if (listening) {
      await voice.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    setState(() => tab = 1);
    try {
      final ok = await voice.listen(
        s.prefs,
        (text, done) {
          if (!mounted) return;
          input.text = text;
          if (done && mounted) setState(() => listening = false);
        },
        (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => listening = false);
          }
        },
        (_) {
          if (mounted) setState(() => listening = false);
          notice(
            s.tr(
              'راجع إذن الميكروفون واللغة المثبّتة.',
              'Check microphone permission and speech language.',
            ),
          );
        },
      );
      if (mounted) setState(() => listening = ok);
      if (!ok) {
        notice(
          s.tr('التعرف الصوتي غير متاح.', 'Speech recognition is unavailable.'),
        );
      }
    } catch (_) {
      notice(s.tr('تعذر تشغيل الميكروفون.', 'Could not start microphone.'));
    }
  }

  Future<void> image() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        notice(s.tr('الحد 8 ميجابايت.', 'Maximum size: 8 MB.'));
        return;
      }
      s.attach(
        Attachment(
          file.name,
          file.mimeType ??
              (file.name.endsWith('.png') ? 'image/png' : 'image/jpeg'),
          bytes,
        ),
      );
      if (mounted) setState(() => tab = 1);
    } catch (_) {
      notice(s.tr('تعذر فتح الصور.', 'Could not open images.'));
    }
  }

  Future<void> file() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'csv', 'json', 'pdf'],
      );
      if (files.isEmpty) return;
      final f = files.first;
      final size = await f.length();
      if (size == null || size > 8 * 1024 * 1024) {
        notice(s.tr('الحد 8 ميجابايت.', 'Maximum size: 8 MB.'));
        return;
      }
      s.attach(
        Attachment(
          f.name,
          f.extension == 'pdf' ? 'application/pdf' : 'text/plain',
          await f.readAsBytes(),
        ),
      );
      if (mounted) setState(() => tab = 1);
    } catch (_) {
      notice(s.tr('تعذر فتح الملف.', 'Could not open file.'));
    }
  }

  Future<void> search() async {
    String value = '';
    final query = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.tr('ابحث في الإنترنت', 'Search the web')),
        content: TextField(
          autofocus: true,
          onChanged: (v) => value = v,
          onSubmitted: (v) => Navigator.pop(c, v),
          decoration: InputDecoration(
            hintText: s.tr('عاوز تبحث عن إيه؟', 'What are you looking for?'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(s.tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, value),
            child: Text(s.tr('بحث', 'Search')),
          ),
        ],
      ),
    );
    if (query == null || query.trim().isEmpty) return;
    try {
      if (!await launchUrl(
        Uri.https('www.google.com', '/search', {'q': query.trim()}),
        mode: LaunchMode.externalApplication,
      )) {
        notice(s.tr('تعذر فتح المتصفح.', 'Could not open browser.'));
      }
    } catch (_) {
      notice(s.tr('تعذر فتح المتصفح.', 'Could not open browser.'));
    }
  }

  void history() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => Consumer(
        builder: (c, ref, _) {
          final a = ref.watch(appProvider);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(c).height * .7,
              child: Column(
                children: [
                  ListTile(
                    title: Text(a.tr('محادثاتك', 'Your conversations')),
                    trailing: IconButton(
                      tooltip: a.tr('محادثة جديدة', 'New chat'),
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.pop(c);
                        chat();
                      },
                    ),
                  ),
                  Expanded(
                    child: a.conversations.isEmpty
                        ? Center(
                            child: Text(
                              a.tr(
                                'المحادثات هتظهر هنا.',
                                'Your chats will appear here.',
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: a.conversations.length,
                            itemBuilder: (c, i) {
                              final chatItem = a.conversations[i];
                              return ListTile(
                                title: Text(
                                  chatItem.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                leading: const Icon(Icons.chat_bubble_outline),
                                onTap: () {
                                  a.open(chatItem);
                                  Navigator.pop(c);
                                  setState(() => tab = 1);
                                },
                                trailing: IconButton(
                                  tooltip: a.tr('حذف', 'Delete'),
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    if (await confirm(
                                          c,
                                          a.tr(
                                            'حذف المحادثة؟',
                                            'Delete conversation?',
                                          ),
                                          a,
                                        ) ==
                                        true) {
                                      await a.delete(chatItem);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(appProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: switch (tab) {
              0 => home(a),
              1 => conversation(a),
              2 => tools(a),
              _ => SettingsPage(
                onVoice: () async {
                  try {
                    await voice.read(
                      a.tr(
                        'أهلًا، أنا نوك مساعدك الذكي.',
                        'Hello, I am NOK, your AI companion.',
                      ),
                      a.prefs,
                    );
                  } catch (_) {
                    notice(a.tr('تعذر تشغيل الصوت.', 'Speech unavailable.'));
                  }
                },
              ),
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) {
          unawaited(voice.stop());
          setState(() {
            tab = v;
            listening = false;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: a.tr('الرئيسية', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: a.tr('المحادثات', 'Chats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            label: a.tr('الأدوات', 'Tools'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune),
            label: a.tr('الإعدادات', 'Settings'),
          ),
        ],
      ),
    );
  }

  Widget home(AppState a) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
    children: [
      Row(
        children: [
          IconButton(
            onPressed: history,
            tooltip: a.tr('المحادثات السابقة', 'History'),
            icon: const Icon(Icons.menu),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'NOK',
                  style: TextStyle(
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 5,
                    color: blue,
                  ),
                ),
                Text(
                  'YOUR AI COMPANION',
                  style: TextStyle(fontSize: 9, letterSpacing: 2, color: blue),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => tab = 3),
            tooltip: a.tr('الإعدادات', 'Settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      Semantics(
        label: a.tr('نوك المساعد الآلي', 'NOK robot companion'),
        image: true,
        child: SizedBox(
          height: a.prefs.simple ? 220 : 290,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xff173f5d), Colors.transparent],
                    radius: .7,
                  ),
                ),
              ),
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, .8, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    'assets/images/nok-robot.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    cacheWidth: 700,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              Positioned(
                top: 35,
                right: 0,
                child: Text(
                  a.tr('نفكر\nنحل\nننجز معك', 'Think.\nSolve.\nTogether.'),
                  style: const TextStyle(
                    color: blue,
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Text(
        a.tr('مرحبًا، أنا NOK', 'Hello, I’m NOK'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      Text(
        a.tr('مساعدك الذكي لكل شيء', 'Your everyday AI companion'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 18),
      GridView.count(
        crossAxisCount: a.prefs.simple || a.prefs.scale > 1.15 ? 2 : 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: a.prefs.scale > 1.15 ? 1 : .93,
        children: [
          action(
            a,
            Icons.camera_alt_outlined,
            'كاميرا لايف',
            'Live camera',
            'شوف واسمع',
            'See & hear',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraPage()),
            ),
          ),
          action(
            a,
            Icons.mic_none,
            'تحدث الآن',
            'Speak now',
            'أنا بسمعك',
            'I’m listening',
            listen,
          ),
          action(
            a,
            Icons.image_outlined,
            'ارفع صورة',
            'Add image',
            'افهم تفاصيلها',
            'Understand it',
            image,
          ),
          action(
            a,
            Icons.description_outlined,
            'ارفع ملف',
            'Add a file',
            'PDF · TXT',
            'PDF · TXT',
            file,
          ),
          action(
            a,
            Icons.travel_explore,
            'ابحث',
            'Web search',
            'على الإنترنت',
            'Open browser',
            search,
          ),
          action(
            a,
            Icons.accessibility_new,
            'مساعد الشاشة',
            'Screen guide',
            'خطوة بخطوة',
            'Step by step',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScreenGuidePage()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      composer(a),
      const SizedBox(height: 12),
      Text(
        a.tr(
          'أكثر من مساعد… رفيق كل يوم',
          'More than an assistant. Your everyday companion.',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
      ),
    ],
  );
  Widget action(
    AppState a,
    IconData icon,
    String ar,
    String en,
    String subAr,
    String subEn,
    VoidCallback tap,
  ) => Glass(
    onTap: tap,
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 29, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 7),
        Text(
          a.tr(ar, en),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (!a.prefs.simple) ...[
          const SizedBox(height: 3),
          Text(
            a.tr(subAr, subEn),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
          ),
        ],
      ],
    ),
  );
  Widget conversation(AppState a) {
    final messages = a.current?.messages ?? <Message>[];
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: history,
              tooltip: a.tr('السجل', 'History'),
              icon: const Icon(Icons.history),
            ),
            Expanded(
              child: Text(
                a.current?.title ?? a.title(a.mode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: () => chat(),
              tooltip: a.tr('محادثة جديدة', 'New chat'),
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ),
        Expanded(
          child: messages.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(28),
                  children: [
                    const SizedBox(height: 30),
                    const Icon(Icons.auto_awesome, size: 48, color: blue),
                    const SizedBox(height: 20),
                    Text(
                      a.title(a.mode),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      a.tr(
                        'اكتب طلبك أو اضغط الميكروفون. راجع الكلام قبل إرساله.',
                        'Type a request or use the microphone. Review before sending.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!a.config.ready) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => setState(() => tab = 3),
                        icon: const Icon(Icons.key),
                        label: Text(a.tr('ربط الذكاء الاصطناعي', 'Connect AI')),
                      ),
                    ],
                  ],
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (c, i) {
                    final m = messages[messages.length - i - 1];
                    final mine = m.role == 'user';
                    return Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: mine ? 28 : 0,
                        end: mine ? 0 : 18,
                        bottom: 14,
                      ),
                      child: Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mine ? a.tr('أنت', 'You') : 'NOK',
                              style: const TextStyle(
                                fontSize: 12,
                                color: blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (m.file != null)
                              Text(
                                '📎 ${m.file}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            const SizedBox(height: 7),
                            if (m.text.isEmpty)
                              const LinearProgressIndicator()
                            else
                              SelectableText(m.text),
                            if (!mine && m.text.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: a.tr('نسخ', 'Copy'),
                                    icon: const Icon(
                                      Icons.copy_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: m.text),
                                      );
                                      notice(a.tr('تم النسخ', 'Copied'));
                                    },
                                  ),
                                  IconButton(
                                    tooltip: a.tr('قراءة بصوت', 'Read aloud'),
                                    icon: const Icon(
                                      Icons.volume_up_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      try {
                                        await voice.read(m.text, a.prefs);
                                      } catch (_) {
                                        notice(
                                          a.tr(
                                            'تعذر تشغيل الصوت.',
                                            'Speech unavailable.',
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: a.tr('إيقاف الصوت', 'Stop speech'),
                                    icon: const Icon(
                                      Icons.volume_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: voice.stop,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (a.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              a.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (listening)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              a.tr(
                'بسمعك… راجع الكلام واضغط إرسال',
                'Listening… review and send',
              ),
              style: const TextStyle(color: blue),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: composer(a),
        ),
      ],
    );
  }

  Widget composer(AppState a) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (a.attachment != null)
        Row(
          children: [
            if (a.attachment!.image)
              Image.memory(
                a.attachment!.bytes,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                a.attachment!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => a.attach(null),
              tooltip: a.tr('إزالة المرفق', 'Remove attachment'),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xff365a74)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: a.busy
                  ? null
                  : () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (c) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.image_outlined),
                              title: Text(a.tr('صورة', 'Image')),
                              onTap: () {
                                Navigator.pop(c);
                                image();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.description_outlined),
                              title: Text(a.tr('ملف', 'File')),
                              onTap: () {
                                Navigator.pop(c);
                                file();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
              tooltip: a.tr('إرفاق', 'Attach'),
              icon: const Icon(Icons.attach_file, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: input,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: a.tr('اكتب رسالتك…', 'Your message…'),
                  hintStyle: const TextStyle(fontSize: 14),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            IconButton(
              onPressed: a.busy ? null : listen,
              tooltip: a.tr('الميكروفون', 'Microphone'),
              icon: Icon(
                listening ? Icons.mic : Icons.mic_none,
                size: 22,
                color: listening ? Colors.redAccent : null,
              ),
            ),
            IconButton.filled(
              onPressed: a.busy
                  ? () {
                      a.stop();
                      unawaited(voice.stop());
                    }
                  : send,
              tooltip: a.busy
                  ? a.tr('إيقاف الرد', 'Stop response')
                  : a.tr('إرسال', 'Send'),
              icon: Icon(a.busy ? Icons.stop : Icons.arrow_upward, size: 23),
            ),
          ],
        ),
      ),
    ],
  );
  Widget tools(AppState a) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        a.tr('أدواتك الذكية', 'Your AI toolkit'),
        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        a.tr(
          'اختار المهمة، وNOK يساعدك تبدأ.',
          'Choose a task. NOK helps you get started.',
        ),
      ),
      const SizedBox(height: 24),
      for (final key in toolNames.keys.where((k) => k != 'chat'))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Glass(
            onTap: () => chat(key),
            child: Row(
              children: [
                Icon(switch (key) {
                  'teacher' => Icons.school_outlined,
                  'code' => Icons.code,
                  'translate' => Icons.translate,
                  'cv' => Icons.badge_outlined,
                  'email' => Icons.mail_outline,
                  'slides' => Icons.slideshow,
                  'ocr' => Icons.document_scanner_outlined,
                  _ => Icons.auto_awesome,
                }, color: blue),
                const SizedBox(width: 16),
                Expanded(child: Text(a.title(key))),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
    ],
  );
}

Future<bool?> confirm(BuildContext context, String title, AppState s) =>
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(s.tr('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.tr('تأكيد', 'Confirm')),
          ),
        ],
      ),
    );
