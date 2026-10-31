import 'package:flutter_test/flutter_test.dart';
import 'package:muzaid/main.dart';
import 'package:muzaid/settings_page.dart';

void main() {
  setUp(() {
    settings.userId = 'user_me_uuid';
    settings.firstName = 'أحمد';
    settings.secondName = 'العراقي';
  });

  tearDownAll(() {
    store.dispose();
  });

  group('Auction Editing & Addendum Tests', () {
    test('Scheduled auction allows full editing of details before publishing', () async {
      final scheduledItem = Item(
        id: 'test_sched_1',
        title: 'سيارة مجدولة قديمة',
        description: 'الوصف القديم',
        category: 'السيارات والمركبات',
        seller: 'أنا',
        startPrice: 1000000,
        startTime: DateTime.now().add(const Duration(hours: 2)),
        endTime: DateTime.now().add(const Duration(days: 2)),
      );
      store.items.add(scheduledItem);

      expect(scheduledItem.isScheduled, isTrue);

      await store.updateItemDetails(
        item: scheduledItem,
        title: 'سيارة حديثة بعد التعديل',
        description: 'الوصف المعدل بالكامل',
        startPrice: 1500000,
        location: 'البصرة',
        condition: 'جديد بالكرتون',
        category: 'السيارات والمركبات',
      );

      final updated = store.items.firstWhere((it) => it.id == 'test_sched_1');
      expect(updated.title, equals('سيارة حديثة بعد التعديل'));
      expect(updated.description, equals('الوصف المعدل بالكامل'));
      expect(updated.startPrice, equals(1500000));
      expect(updated.location, equals('البصرة'));
    });

    test('Published auction restricts editing to appending information addendum', () async {
      final publishedItem = Item(
        id: 'test_pub_1',
        title: 'مزاد منشور نشط',
        description: 'الوصف الأصلي الثابت',
        category: 'أجهزة وإلكترونيات',
        seller: 'أنا',
        startPrice: 500000,
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 5)),
      );
      store.items.add(publishedItem);

      expect(publishedItem.isScheduled, isFalse);

      await store.appendItemInformation(
        publishedItem,
        'تم فحص الجهاز وهو يعمل بنسبة 100% مع ضمان شهر كامل.',
      );

      final updated = store.items.firstWhere((it) => it.id == 'test_pub_1');
      expect(updated.title, equals('مزاد منشور نشط'));
      expect(updated.description, contains('الوصف الأصلي الثابت'));
      expect(updated.description, contains('📌 [تحديث معلومات من البائع'));
      expect(updated.description, contains('تم فحص الجهاز وهو يعمل بنسبة 100%'));
    });
  });

  group('Direct Chat, Unread Counter & Online Status Tests', () {
    test('Unread badge clears instantly when markConversationAsRead is called', () {
      final item = Item(
        id: 'item_chat_1',
        title: 'سلعة المحادثة',
        description: 'وصف',
        category: 'عام',
        seller: 'بائع_تجريبي',
        startPrice: 50000,
        endTime: DateTime.now().add(const Duration(hours: 2)),
      );
      store.items.add(item);

      final msg1 = DirectMessage(
        'بائع_تجريبي',
        'أنا',
        'مرحباً بك، هل السلعة متوفرة؟',
        DateTime.now().subtract(const Duration(minutes: 10)),
        id: 'msg_test_unread_1',
        isRead: false,
      );

      store.directChats.putIfAbsent(item.id, () => []).add(msg1);

      // Verify unread count is 1
      expect(store.unreadDirectMessagesCount, greaterThanOrEqualTo(1));

      // Mark conversation as read
      store.markConversationAsRead(item.id, 'بائع_تجريبي');

      // Unread count must be 0
      expect(msg1.isRead, isTrue);
      final unreadForParty = store.getDirectMessages(item.id).where((m) => !store.isUserMe(m.sender) && !m.isRead);
      expect(unreadForParty.isEmpty, isTrue);
    });

    test('Historical messages do not falsely mark a user as online', () {
      const otherUser = 'مستخدم_قديم';

      // Record activity from 1 hour ago
      store.recordUserActivity(
        otherUser,
        activityTime: DateTime.now().subtract(const Duration(hours: 1)),
      );

      // User must be OFFLINE
      expect(store.isUserOnline(otherUser), isFalse);

      // Record activity right now
      store.recordUserActivity(
        otherUser,
        activityTime: DateTime.now(),
      );

      // User must now be ONLINE
      expect(store.isUserOnline(otherUser), isTrue);
    });
  });
}
