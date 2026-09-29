import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'engine.dart';

class VoiceService {
  final speech = SpeechToText();
  final tts = FlutterTts();
  bool initialized = false;
  String buffer = '';
  int generation = 0;
  Completer<void> cancellation = Completer<void>();
  Object? speechFailure;
  Future<void> queue = Future.value();
  Future<bool> listen(
    Preferences p,
    void Function(String, bool) result,
    void Function(String) status,
    void Function(String) error,
  ) async {
    await stop();
    if (!initialized) {
      initialized = await speech.initialize(
        onStatus: status,
        onError: (e) => error(e.errorMsg),
      );
    }
    if (!initialized) return false;
    final locales = (await speech.locales())
        .where((l) => l.localeId.startsWith(p.arabic ? 'ar' : 'en'))
        .toList();
    if (locales.isEmpty) {
      error('language_unavailable');
      return false;
    }
    await speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: locales.first.localeId,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (r) => result(r.recognizedWords, r.finalResult),
    );
    return true;
  }

  Future<void> prepare(Preferences p) async {
    final token = ++generation;
    if (!cancellation.isCompleted) cancellation.complete();
    cancellation = Completer<void>();
    speechFailure = null;
    buffer = '';
    queue = Future.value();
    await speech.stop();
    await tts.stop();
    if (token != generation) throw StateError('Speech cancelled');
    final language = p.arabic ? 'ar' : 'en-US';
    if (await tts.isLanguageAvailable(language) != true) {
      throw StateError('Speech language unavailable');
    }
    await tts.setLanguage(language);
    await tts.setSpeechRate(p.rate);
    await tts.setVolume(p.volume);
    // Dart owns the queue on every platform; queue mode is Android-only.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await tts.setQueueMode(0);
    }
    await tts.awaitSpeakCompletion(true);
    if (token != generation) throw StateError('Speech cancelled');
  }

  void add(String chunk) {
    buffer += chunk;
    while (true) {
      final match = RegExp(r'[.!?؟\n]').firstMatch(buffer);
      if (match == null) break;
      final text = buffer.substring(0, match.end).trim();
      buffer = buffer.substring(match.end);
      if (text.isNotEmpty) _enqueue(text);
    }
    if (buffer.length > 200) {
      final cut = buffer.lastIndexOf(' ', 200);
      final end = cut > 0 ? cut : 200;
      _enqueue(buffer.substring(0, end));
      buffer = buffer.substring(end).trimLeft();
    }
  }

  void _enqueue(String text) {
    final token = generation;
    final cancelled = cancellation.future;
    queue = queue
        .then((_) async {
          if (token == generation) {
            await Future.any<void>([
              tts
                  .speak(text.replaceAll(RegExp(r'[*#`_]'), ''))
                  .then<void>((_) {}),
              cancelled,
            ]).timeout(const Duration(seconds: 60));
          }
        })
        .catchError((Object error) {
          if (token == generation) speechFailure = error;
        });
  }

  void finish() {
    if (buffer.trim().isNotEmpty) _enqueue(buffer);
    buffer = '';
  }

  Future<void> read(String text, Preferences p) async {
    await prepare(p);
    add(text);
    finish();
    await queue;
    if (speechFailure != null) throw StateError('Speech playback failed');
  }

  Future<void> stop() async {
    generation++;
    if (!cancellation.isCompleted) cancellation.complete();
    buffer = '';
    queue = Future.value();
    await speech.stop();
    await tts.stop();
  }

  Future<void> dispose() async {
    generation++;
    if (!cancellation.isCompleted) cancellation.complete();
    await speech.cancel();
    await tts.stop();
  }
}

class CloudService {
  static bool enabled = false;
  static Future<void> init() async {
    const key = String.fromEnvironment('FIREBASE_API_KEY'),
        app = String.fromEnvironment('FIREBASE_APP_ID'),
        project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (key.isEmpty || app.isEmpty || project.isEmpty) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: key,
          appId: app,
          projectId: project,
          messagingSenderId: String.fromEnvironment(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
          storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        ),
      );
      enabled = true;
    } catch (_) {
      enabled = false;
    }
  }

  static User? get user => enabled ? FirebaseAuth.instance.currentUser : null;
  static Future<void> login(
    String email,
    String password,
    bool register,
  ) async {
    if (register) {
      final r = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await r.user?.sendEmailVerification();
    } else {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  static Future<void> backup(AppState s) async {
    final uid = user?.uid;
    if (uid == null) throw StateError('Sign in first');
    final root = FirebaseFirestore.instance.collection('users').doc(uid);
    final batch = FirebaseFirestore.instance.batch();
    batch.set(root, {
      'preferences': s.prefs.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final c in s.conversations.take(60)) {
      batch.set(root.collection('conversations').doc(c.id), c.toJson());
    }
    await batch.commit();
  }

  static Future<void> restore(AppState s) async {
    final uid = user?.uid;
    if (uid == null) throw StateError('Sign in first');
    final docs = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('conversations')
        .limit(60)
        .get();
    final ids = s.conversations.map((c) => c.id).toSet();
    s.conversations.addAll(
      docs.docs
          .where((d) => !ids.contains(d.id))
          .map((d) => Conversation.fromJson(d.data())),
    );
    s.conversations.sort((a, b) => b.id.compareTo(a.id));
    await s.persist();
    await s.savePrefs();
  }

  static Future<void> deleteData() async {
    final uid = user?.uid;
    if (uid == null) return;
    final root = FirebaseFirestore.instance.collection('users').doc(uid);
    while (true) {
      final docs = await root.collection('conversations').limit(400).get();
      if (docs.docs.isEmpty) break;
      final b = FirebaseFirestore.instance.batch();
      for (final d in docs.docs) {
        b.delete(d.reference);
      }
      await b.commit();
    }
    await root.delete();
  }
}
