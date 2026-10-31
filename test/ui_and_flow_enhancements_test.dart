import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzaid/main.dart';
import 'package:muzaid/settings_page.dart';

void main() {
  setUp(() {
    settings.userId = 'tester_1';
    settings.phone = '07701234567';
    settings.firstName = 'أحمد';
    settings.secondName = 'علي';
    settings.thirdName = 'الكرخي';
    settings.governorate = 'بغداد';
    settings.district = 'المنصور';
    settings.needsProfileOnboarding = false;
  });

  tearDown(() {
    store.stopTimers();
  });

  tearDownAll(() {
    store.dispose();
  });

  group('1. Header Navigation & Unified Screen Tests', () {
    testWidgets('Header displays Radar, Notifications, and Favorites with independent navigation', (tester) async {
      await tester.pumpWidget(const AuctionApp());
      await tester.pumpAndSettle();

      // Ensure the three top icons are present in the AppBar
      final radarFinder = find.byTooltip('رادار البحث الذكي');
      final notifFinder = find.byTooltip('مركز الإشعارات');
      final favFinder = find.byTooltip('المفضلة');

      expect(radarFinder, findsOneWidget);
      expect(notifFinder, findsOneWidget);
      expect(favFinder, findsOneWidget);

      // Tap on Favorites icon -> should open RadarAndNotificationsPage on Tab 2 (المفضلة)
      await tester.tap(favFinder);
      await tester.pumpAndSettle();

      expect(find.text('مركز المتابعة الذكي'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);

      // Verify the 3 tabs in the unified interface
      final tabBarFinder = find.byType(TabBar);
      expect(find.descendant(of: tabBarFinder, matching: find.textContaining('الرادار')), findsOneWidget);
      expect(find.descendant(of: tabBarFinder, matching: find.textContaining('الإشعارات')), findsOneWidget);
      expect(find.descendant(of: tabBarFinder, matching: find.textContaining('المفضلة')), findsOneWidget);

      // Return to home
      await tester.pageBack();
      await tester.pumpAndSettle();

      store.stopTimers();
    });
  });

  group('2. Iraqi Governorates and Dynamic Districts Linking', () {
    test('districtsForGovernorate returns matching districts for Baghdad, Basra, and Dhi Qar', () {
      final baghdadDistricts = districtsForGovernorate('بغداد');
      expect(baghdadDistricts.contains('المنصور'), isTrue);
      expect(baghdadDistricts.contains('الكرادة'), isTrue);

      final basraDistricts = districtsForGovernorate('البصرة');
      expect(basraDistricts.contains('الزبير'), isTrue);
      expect(basraDistricts.contains('القرنة'), isTrue);
      expect(basraDistricts.contains('المنصور'), isFalse);

      final dhiQarDistricts = districtsForGovernorate('ذي قار');
      expect(dhiQarDistricts.contains('الناصرية'), isTrue);
      expect(dhiQarDistricts.contains('الشطرة'), isTrue);
      expect(dhiQarDistricts.contains('الزبير'), isFalse);
    });
  });

  group('3. Create Listing Pricing & Optional Buy Now Price', () {
    test('Item model serializes and deserializes buyNowPrice', () {
      final item = Item(
        id: 'test_item_bn',
        title: 'سيارة تجريبية',
        description: 'وصف تجريبي',
        category: 'سيارات ومركبات',
        seller: 'أنا',
        startPrice: 5000000,
        buyNowPrice: 7000000,
        endTime: DateTime.now().add(const Duration(days: 2)),
      );

      final json = item.toJson();
      expect(json['buyNowPrice'], 7000000);

      final decoded = Item.fromJson(json);
      expect(decoded.buyNowPrice, 7000000);
    });
  });

  group('4. Profile Location Visibility in Settings', () {
    testWidgets('Main settings screen hides standalone location badge', (tester) async {
      await tester.pumpWidget(const AuctionApp());
      await tester.pumpAndSettle();

      // Navigate to Settings Tab (index 4)
      final settingsLabel = find.text('الإعدادات');
      await tester.tap(settingsLabel);
      await tester.pumpAndSettle();

      // Main settings screen should display edit profile button, but NOT the old location badge
      expect(find.text('تعديل الملف الشخصي'), findsOneWidget);
      // There shouldn't be a location Chip on the settings overview
      final locationIconInChip = find.descendant(
        of: find.byType(Chip),
        matching: find.byIcon(Icons.location_on_outlined),
      );
      expect(locationIconInChip, findsNothing);
      store.stopTimers();
    });
  });

  group('5. Expanded Categories, Dynamic Fields & PIN Hint Removal', () {
    test('Categories list is expanded with comprehensive categories and matching fields', () {
      expect(categories.length, greaterThanOrEqualTo(15));
      expect(categories.contains('عقارات وأراضي'), isTrue);
      expect(categories.contains('ذهب ومجوهرات'), isTrue);
      expect(categories.contains('ألعاب فيديو وترفيه'), isTrue);
      expect(categories.contains('مواشي وأغنام'), isTrue);

      for (final cat in categories) {
        final icon = categoryIcon(cat);
        expect(icon, isNotNull);
        final fields = dynamicFieldsForCategory(cat);
        expect(fields, isNotEmpty);
      }
    });

    testWidgets('Create Auction page has empty category by default and displays guidance text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AddItemPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('اختر التصنيف'), findsOneWidget);
      expect(find.text('عقارات وأراضي'), findsNothing);
      store.stopTimers();
    });
  });

  group('6. Sorting Component & Default State', () {
    testWidgets('Home page displays sort icon without text label initially', (tester) async {
      await tester.pumpWidget(const AuctionApp());
      await tester.pumpAndSettle();

      // Sort button initially shows sort icon without any label text
      final sortIconFinder = find.byIcon(Icons.sort);
      expect(sortIconFinder, findsOneWidget);
      expect(find.text('الأحدث'), findsNothing);
      store.stopTimers();
    });
  });

  group('7. Anti-Spam Bidding & Leader Validation', () {
    test('Current highest bidder cannot place consecutive bids', () {
      final testItem = Item(
        id: 'anti_spam_test_1',
        title: 'سلعة تجربة المزايدة',
        description: 'وصف',
        category: 'إلكترونيات وأجهزة',
        seller: 'بائع_آخر',
        startPrice: 100000,
        endTime: DateTime.now().add(const Duration(hours: 2)),
      );
      store.items.removeWhere((i) => i.id == testItem.id);
      store.items.add(testItem);

      // First bid by current user (me)
      final bid1Error = store.placeBid(testItem, 110000);
      expect(bid1Error, isNull);
      expect(testItem.highestBidder, me);

      // Immediate consecutive bid by the same user should be blocked
      final bid2Error = store.placeBid(testItem, 120000);
      expect(bid2Error, isNotNull);
      expect(bid2Error, contains('أعلى مزايدة'));
    });
  });

  group('8. Profile Access Control & Web Persistence', () {
    test('Unauthorized user cannot edit another users profile', () async {
      settings.userId = 'user_owner_123';
      settings.isAdmin = false;

      final result = await settings.updateProfile(
        const ProfileData('علي', 'حسين', 'كاظم', 'بغداد', null),
        targetUserId: 'different_user_999',
      );

      expect(result, isNotNull);
      expect(result, contains('غير مصرح'));
    });
  });

  group('9. Admin Dashboard, Deduplication, Role Badges & Auth Flow Tests', () {
    test('allKnownUsers deduplicates account IDs', () {
      final users = store.allKnownUsers;
      final uniqueUsers = <String>{};
      final duplicates = <String>[];
      for (final u in users) {
        if (!uniqueUsers.add(u)) {
          duplicates.add(u);
        }
      }
      expect(duplicates, isEmpty, reason: 'Duplicate users found: $duplicates');
    });

    test('isUserAdmin identifies admin roles properly', () {
      settings.userId = 'tester_admin_id';
      settings.isAdmin = true;
      expect(store.isUserAdmin(settings.userId!), isTrue);
      expect(store.isUserAdmin('07700000000'), isTrue);

      settings.isAdmin = false;
      store.adminUserNames.clear();
      expect(store.isUserAdmin('random_regular_user_xyz'), isFalse);
    });

    testWidgets('Home page centers governorate picker dialog', (tester) async {
      await tester.pumpWidget(const AuctionApp());
      await tester.pumpAndSettle();

      // Find the governorate button
      final govFinder = find.text('المحافظة');
      expect(govFinder, findsOneWidget);

      await tester.tap(govFinder);
      await tester.pumpAndSettle();

      // Verify the centered dialog appeared
      expect(find.text('اختر المحافظة'), findsOneWidget);
      expect(find.text('ابحث عن محافظة...'), findsOneWidget);

      // Select Baghdad
      final baghdadFinder = find.text('بغداد');
      expect(baghdadFinder, findsOneWidget);
      await tester.tap(baghdadFinder);
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('اختر المحافظة'), findsNothing);
      store.stopTimers();
    });
  });

  group('10. Bottom Navigation Bar & Form Validation Tests', () {
    testWidgets('Home page does not use floatingActionButton and has integrated Add Auction destination', (tester) async {
      await tester.pumpWidget(const AuctionApp());
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.floatingActionButton, isNull);

      final navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);
      expect(find.text('أضف مزاداً'), findsOneWidget);
      store.stopTimers();
    });

    testWidgets('Add item page strictly enforces all 5 mandatory fields before saving', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AddItemPage()));
      await tester.pumpAndSettle();

      final initialItemsCount = store.items.length;

      // Tap publish button without filling fields
      final publishBtn = find.text('انشر وابدأ المزاد الآن');
      expect(publishBtn, findsOneWidget);
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      // Ensure no item was created
      expect(store.items.length, equals(initialItemsCount));

      // Error messages for mandatory fields appear
      expect(find.textContaining('يرجى إضافة صورة واحدة على الأقل'), findsOneWidget);
      expect(find.textContaining('يرجى اختيار تصنيف السلعة'), findsOneWidget);
      expect(find.textContaining('يرجى كتابة عنوان الإعلان'), findsWidgets);
      expect(find.textContaining('يرجى كتابة تفاصيل ووصف السلعة'), findsWidgets);
      expect(find.textContaining('يرجى إدخال سعر بداية المزاد'), findsWidgets);
    });
  });

  group('11. Timing, Duration & Seller Actions / Buy Now Tests', () {
    testWidgets('Seller menu contains only 3 actions: Edit, Accept, Delete', (tester) async {
      final myItem = Item(
        id: 'seller_test_item',
        title: 'سلعة تجريبية',
        description: 'وصف السلعة',
        category: 'إلكترونيات وأجهزة',
        seller: me,
        startPrice: 10000,
        startTime: DateTime.now().subtract(const Duration(minutes: 10)),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        buyNowPrice: 25000,
      );
      myItem.bids.add(Bid('مزايد_آخر', 12000, DateTime.now()));
      store.items.insert(0, myItem);

      await tester.pumpWidget(MaterialApp(home: ItemDetailsPage(item: myItem)));
      await tester.pumpAndSettle();

      // Open more options menu
      final popupMenuFinder = find.byType(PopupMenuButton<String>);
      expect(popupMenuFinder, findsOneWidget);
      await tester.tap(popupMenuFinder);
      await tester.pumpAndSettle();

      // Exactly 3 seller options
      expect(find.text('تعديل المزاد'), findsOneWidget);
      expect(find.text('قبول أعلى مزايدة'), findsOneWidget);
      expect(find.text('حذف السلعة'), findsOneWidget);
      expect(find.textContaining('المصافحة'), findsNothing);
      expect(find.textContaining('إطلاق'), findsNothing);

      store.items.removeWhere((i) => i.id == 'seller_test_item');
    });

    test('buyNow requires authentication and completes instant purchase for logged-in user', () {
      final prevUserId = settings.userId;
      settings.userId = null;

      final item = Item(
        id: 'buy_now_item',
        title: 'آيفون 15',
        description: 'جديد',
        category: 'إلكترونيات وأجهزة',
        seller: 'بائع_آخر',
        startPrice: 50000,
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        buyNowPrice: 80000,
      );
      store.items.insert(0, item);

      // Unauthenticated buyNow fails
      final unauthErr = store.buyNow(item);
      expect(unauthErr, isNotNull);
      expect(item.isEndedEarlyBySeller, isFalse);

      // Authenticated buyNow succeeds
      settings.userId = 'auth_buyer_123';
      final okErr = store.buyNow(item);
      expect(okErr, isNull);
      expect(item.currentPrice, equals(80000));
      expect(item.highestBidder, equals(me));
      expect(item.isEndedEarlyBySeller, isTrue);

      store.items.removeWhere((i) => i.id == 'buy_now_item');
      settings.userId = prevUserId;
    });

    testWidgets('ItemCard displays 4 levels on right and 3 levels on left with anonymous bids count', (tester) async {
      final cardItem = Item(
        id: 'duck_card_test',
        title: 'بطة',
        description: 'بطة بيضاء',
        category: 'طيور وحيوانات',
        seller: 'بائع_الطيور',
        startPrice: 20000,
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        endTime: DateTime.now().add(const Duration(hours: 23, minutes: 31, seconds: 49)),
        location: 'البصرة',
        area: 'المدينة',
      );
      cardItem.bids.add(Bid('حساب تجريبي', 25000, DateTime.now()));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ItemCard(item: cardItem)),
      ));
      await tester.pumpAndSettle();

      // Right Column: Title, Green Price, Location, Anonymous Bids Count
      expect(find.text('بطة'), findsOneWidget);
      expect(find.text('25,000 دينار'), findsOneWidget);
      expect(find.text('البصرة - المدينة'), findsOneWidget);
      expect(find.text('1 مزايدة'), findsOneWidget);
      // Ensure bidder identity is NOT shown
      expect(find.textContaining('حساب تجريبي'), findsNothing);

      // Left Column: Heart, Timer
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      // Non-seller, non-participant has no status badge
      expect(find.text('سلعتك'), findsNothing);
      expect(find.text('أنت الأعلى'), findsNothing);
      expect(find.text('تم تجاوزك'), findsNothing);
    });

    testWidgets('ItemCard status badge displays correctly for seller, leader, and outbid user', (tester) async {
      final prevUserId = settings.userId;
      settings.userId = 'my_test_user';

      // 1. Seller Item -> Blue 'سلعتك'
      final myItem = Item(
        id: 'item_mine',
        title: 'سلعتي الخاصة',
        description: 'وصف',
        category: 'إلكترونيات وأجهزة',
        seller: me,
        startPrice: 10000,
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        location: 'بغداد',
        area: 'الكرخ',
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ItemCard(item: myItem))));
      await tester.pumpAndSettle();
      expect(find.text('سلعتك'), findsOneWidget);

      // 2. Leader Item -> Green 'أنت الأعلى'
      final leadItem = Item(
        id: 'item_leading',
        title: 'سلعة متصدرها',
        description: 'وصف',
        category: 'إلكترونيات وأجهزة',
        seller: 'بائع_آخر',
        startPrice: 10000,
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        location: 'بغداد',
        area: 'الكرخ',
      );
      leadItem.bids.add(Bid(me, 15000, DateTime.now()));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ItemCard(item: leadItem))));
      await tester.pumpAndSettle();
      expect(find.text('أنت الأعلى'), findsOneWidget);

      // 3. Outbid Item -> Red 'تم تجاوزك'
      final outbidItem = Item(
        id: 'item_outbid',
        title: 'سلعة متجاوزة',
        description: 'وصف',
        category: 'إلكترونيات وأجهزة',
        seller: 'بائع_آخر',
        startPrice: 10000,
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        location: 'بغداد',
        area: 'الكرخ',
      );
      outbidItem.bids.add(Bid('طرف_آخر', 20000, DateTime.now()));
      outbidItem.bids.add(Bid(me, 15000, DateTime.now().subtract(const Duration(minutes: 1))));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ItemCard(item: outbidItem))));
      await tester.pumpAndSettle();
      expect(find.text('تم تجاوزك'), findsOneWidget);

      settings.userId = prevUserId;
    });

    testWidgets('ItemDetailsPage enforces PIN protection guard for non-owners', (tester) async {
      final pinItem = Item(
        id: 'pin_protected_item',
        title: 'مزاد سري مقفل',
        description: 'تفاصيل سرية للغاية',
        category: 'نوادر وتحف',
        seller: 'بائع_خاص',
        startPrice: 500000,
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        endTime: DateTime.now().add(const Duration(hours: 5)),
        location: 'بغداد',
        area: 'المنصور',
        pinCode: '9876',
      );
      store.items.add(pinItem);

      await tester.pumpWidget(MaterialApp(home: ItemDetailsPage(item: pinItem)));
      await tester.pumpAndSettle();

      // Enforces PIN guard screen
      expect(find.text('غرفة مزاد خاصة'), findsOneWidget);
      expect(find.text('فك القفل والدخول'), findsOneWidget);
      // Details must not be visible yet
      expect(find.text('تفاصيل سرية للغاية'), findsNothing);

      // Entering incorrect PIN fails
      await tester.enterText(find.byType(TextField), '1111');
      await tester.tap(find.text('فك القفل والدخول'));
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل سرية للغاية'), findsNothing);

      // Entering correct PIN unlocks item details
      await tester.enterText(find.byType(TextField), '9876');
      await tester.tap(find.text('فك القفل والدخول'));
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل سرية للغاية'), findsOneWidget);

      store.items.removeWhere((i) => i.id == 'pin_protected_item');
    });
  });
}
