import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'engine.dart';
import 'local_backup.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool busy = false;
  String? result;
  Future<void> run(Future<String?> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      result = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => result = message);
    } catch (e) {
      if (mounted) {
        final s = ref.read(appProvider);
        setState(
          () => result = s.tr(
            'تعذرت العملية. استخدم ملف NOK صالحًا لا يتجاوز 10 ميجابايت، وبحد أقصى 60 محادثة إجمالًا. لم تُحذف محادثاتك.',
            'Could not complete. Use a valid NOK backup up to 10 MB and 60 total chats. Your existing chats were not deleted.',
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
      appBar: AppBar(title: Text(s.tr('نسخة المحادثات', 'Chat backup'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            s.tr(
              'احفظ محادثاتك في ملف واسترجعها على جهاز آخر، بدون حساب أو إنترنت.',
              'Save chats to a file and restore them on another device, without an account or internet.',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.tr(
              'الملف يحتوي نص المحادثات وأسماء المرفقات فقط. لا يشمل مفاتيح API أو ملفات الصور أو إعداداتك. الملف غير مشفّر؛ احفظه في مكان خاص.',
              'The file contains chat text and attachment names only. API keys, attachment files and settings are excluded. It is not encrypted; store it privately.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save_alt),
            label: Text(s.tr('حفظ نسخة في ملف', 'Save backup file')),
            onPressed: busy || s.busy
                ? null
                : () => run(() async {
                    final bytes = LocalBackup.encode(s.conversations);
                    final uri = await FilePicker.saveFile(
                      fileName:
                          'NOK-chats-${DateTime.now().millisecondsSinceEpoch}.json',
                      bytes: bytes,
                      mimeType: 'application/json',
                    );
                    return uri == null
                        ? null
                        : s.tr('تم حفظ نسخة المحادثات.', 'Chat backup saved.');
                  }),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.restore),
            label: Text(s.tr('استعادة من ملف', 'Restore from file')),
            onPressed: busy || s.busy
                ? null
                : () => run(() async {
                    final file = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    if (file == null || !mounted) return null;
                    final size = await file.length();
                    if (size == null || size > LocalBackup.maxBytes) {
                      throw const FormatException('Backup too large');
                    }
                    final backup = LocalBackup.decode(await file.readAsBytes());
                    if (!mounted) return null;
                    if (!context.mounted) return null;
                    final approved = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        title: Text(
                          s.tr('استعادة المحادثات؟', 'Restore chats?'),
                        ),
                        content: Text(
                          s.tr(
                            'الملف يحتوي ${backup.conversations.length} محادثة. سنضيف المحادثات الجديدة ونحتفظ بالنسخ الموجودة عند تكرارها.',
                            'This file contains ${backup.conversations.length} chats. New chats will be added; existing copies are kept for duplicate IDs.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, false),
                            child: Text(s.tr('إلغاء', 'Cancel')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: Text(s.tr('استعادة', 'Restore')),
                          ),
                        ],
                      ),
                    );
                    if (approved != true || !mounted) return null;
                    final count = await s.restoreChats(backup.conversations);
                    return s.tr(
                      'تمت إضافة $count محادثة.',
                      'Added $count chats.',
                    );
                  }),
          ),
          if (s.busy)
            Text(
              s.tr(
                'انتظر انتهاء الرد الحالي أولًا.',
                'Wait for the current response to finish.',
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Semantics(liveRegion: true, child: Text(result!)),
            ),
        ],
      ),
    );
  }
}
