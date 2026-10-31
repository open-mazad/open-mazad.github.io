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
}
