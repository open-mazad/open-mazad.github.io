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

  /// الحظر الإداري الشامل للمنصة (Admin Banned Accounts)
  static Set<String> getBannedUsers() {
    final set = getSet('muzaid_admin_banned_users');
    if (set.isNotEmpty) return set;
    return {};
  }
  static void saveBannedUsers(Iterable<String> users) => saveSet('muzaid_admin_banned_users', users);

  /// قائمة المستخدمين الموثقين من الإدارة (Admin Verified Users)
  static Set<String> getVerifiedUsers() {
    final set = getSet('muzaid_admin_verified_users');
    if (set.isNotEmpty) return set;
    return {};
  }
  static void saveVerifiedUsers(Iterable<String> users) => saveSet('muzaid_admin_verified_users', users);

  /// قائمة الحظر الشخصية لكل مستخدم (Personal User-to-User Blocks)
  static Set<String> getUserBlockedUsers(String userId) {
    final cleanId = userId.trim();
    final key = cleanId.isEmpty ? 'muzaid_user_blocks_default' : 'muzaid_user_blocks_$cleanId';
    final raw = read(key);
    if (raw != null) {
      return getSet(key);
    }
    // استعادة قائمة الحظر الشخصية السابقة إن وُجدت ولم يُعيّن مفتاح مخصص بعد
    final legacy = getSet('muzaid_blocked_users');
    if (legacy.isNotEmpty) return legacy;
    return {};
  }
  static void saveUserBlockedUsers(String userId, Iterable<String> users) {
    final cleanId = userId.trim();
    final key = cleanId.isEmpty ? 'muzaid_user_blocks_default' : 'muzaid_user_blocks_$cleanId';
    saveSet(key, users);
    // تحديث القائمة العامة السابقة لتتطابق تماماً وتمنع أي استرجاع عشوائي للمحظورين
    saveSet('muzaid_blocked_users', users);
  }

  static Set<String> getBlockedUsers() => getSet('muzaid_blocked_users');
  static void saveBlockedUsers(Iterable<String> users) => saveSet('muzaid_blocked_users', users);
}
