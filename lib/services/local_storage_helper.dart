import 'dart:convert';
import 'local_storage_stub.dart'
    if (dart.library.html) 'local_storage_web.dart';

class LocalStorageHelper {
  static String? read(String key) => getStorageItem(key);
  static void write(String key, String value) => setStorageItem(key, value);
  static void delete(String key) => removeStorageItem(key);

  static Set<String> getSet(String key) {
    try {
      final raw = read(key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => '$e').toSet();
      }
    } catch (_) {}
    return {};
  }

  static void saveSet(String key, Iterable<String> items) {
    try {
      write(key, jsonEncode(items.toList()));
    } catch (_) {}
  }

  static Set<String> getDeletedConversationKeys() => getSet('muzaid_deleted_convs');
  static void saveDeletedConversationKeys(Iterable<String> keys) => saveSet('muzaid_deleted_convs', keys);

  static Set<String> getDeletedMessageIds() => getSet('muzaid_deleted_msg_ids');
  static void saveDeletedMessageIds(Iterable<String> ids) => saveSet('muzaid_deleted_msg_ids', ids);

  static Set<String> getBlockedUsers() => getSet('muzaid_blocked_users');
  static void saveBlockedUsers(Iterable<String> users) => saveSet('muzaid_blocked_users', users);
}
