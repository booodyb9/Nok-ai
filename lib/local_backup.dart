import 'dart:convert';
import 'dart:typed_data';

import 'engine.dart';

/// A portable chat-only backup. Provider credentials and attachment bytes are
/// deliberately outside this format.
class LocalBackup {
  static const maxBytes = 10 * 1024 * 1024;
  static const maxConversations = 60;
  final List<Conversation> conversations;
  const LocalBackup(this.conversations);

  static Uint8List encode(List<Conversation> conversations) {
    if (conversations.length > maxConversations) {
      throw const FormatException('Maximum 60 conversations per backup');
    }
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'nok-chat-backup',
          'version': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'conversations': conversations.map((c) => c.toJson()).toList(),
        }),
      ),
    );
    if (bytes.length > maxBytes) {
      throw const FormatException('Maximum backup size is 10 MB');
    }
    // Never produce a file that our importer would reject.
    decode(bytes);
    return bytes;
  }

  static LocalBackup decode(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Maximum backup size is 10 MB');
    }
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map<String, dynamic> ||
        raw['format'] != 'nok-chat-backup' ||
        raw['version'] != 1) {
      throw const FormatException('Not a supported NOK chat backup');
    }
    final rows = raw['conversations'];
    if (rows is! List || rows.length > maxConversations) {
      throw const FormatException('Invalid conversation count');
    }
    final ids = <String>{};
    final result = <Conversation>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic> ||
          !_text(row['id'], 128) ||
          !_text(row['title'], 100000) ||
          !_text(row['mode'] ?? 'chat', 100) ||
          !ids.add(row['id'] as String)) {
        throw const FormatException('Invalid or duplicate conversation');
      }
      final messages = row['messages'];
      if (messages is! List || messages.length > 10000) {
        throw const FormatException('Invalid messages');
      }
      for (final message in messages) {
        if (message is! Map<String, dynamic> ||
            !['user', 'assistant'].contains(message['role']) ||
            message['text'] is! String ||
            (message['file'] != null && !_text(message['file'], 4096))) {
          throw const FormatException('Invalid message');
        }
      }
      result.add(Conversation.fromJson(row));
    }
    return LocalBackup(result);
  }

  static bool _text(Object? value, int max) =>
      value is String && value.isNotEmpty && value.length <= max;
}
