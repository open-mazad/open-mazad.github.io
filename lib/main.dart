import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/auction_models.dart';
import 'services/auction_helpers.dart';
import 'screens/live/live_camera_widget.dart';
import 'settings_page.dart';

// تصدير النماذج والمساعدات حتى تتاح في أي شاشة تستورد main.dart
export 'models/auction_models.dart';
export 'services/auction_helpers.dart';

// ربط الأجزاء المقسمة (Parts)
part 'services/auction_store.dart';
part 'widgets/item_card.dart';
part 'widgets/share_dialog.dart';
part 'screens/tabs/home_page.dart';
part 'screens/details/item_details_page.dart';
part 'screens/details/user_profile_sheet.dart';
part 'screens/create/add_item_page.dart';
part 'screens/live/live_stream_page.dart';
part 'screens/chat/direct_chat_page.dart';
part 'screens/radar/radar_and_notifications_page.dart';
part 'screens/admin/admin_dashboard_page.dart';
part 'screens/admin/supabase_cloud_setup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (settings.isCloudConfigured) {
    try {
      await Supabase.initialize(
        url: settings.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: settings.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialize error: $e');
    }
  }
  await settings.initAuth();
  store.initRealtime();
  runApp(const AuctionApp());
}

// ======================= ثوابت ومساعدات =======================

/// معرّف أو اسم المستخدم الحالي (ديناميكي من Supabase Auth)
String get me => settings.isLoggedIn
    ? (settings.userId ?? 'أنا')
    : 'أنا';

/// اسم الشخص للعرض: اسمي الحقيقي إن سجّلت حساباً، وإلا الاسم المحفوظ
String displayName(String who) {
  if (who == me ||
      who == 'أنا' ||
      (settings.userId != null && who == settings.userId)) {
    return settings.fullName.isEmpty ? tr('أنا', 'Me') : settings.fullName;
  }
  return store.userDisplayNames[who] ?? who;
}

// ======================= التطبيق =======================

class AuctionApp extends StatelessWidget {
  const AuctionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Open Mazad',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        themeMode: settings.themeMode,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final width = mq.size.width;

          // معايير التحجيم العالمية المتجاوبة (Responsive Material 3 Scale):
          // - شاشات صغيرة جداً (< 350dp): تصغير الخطوط والأيقونات بنسبة تناسب الشاشة (0.86)
          // - شاشات صغيرة ومتوسطة (350 - 410dp): حجم طبيعي مريح (0.95 - 1.0)
          // - شاشات كبيرة وفابلت (410 - 600dp): تكبير طفيف متناسق (1.04)
          // - شاشات التابلت والشاشات الكبيرة (> 600dp): 1.08
          double fontScale = 1.0;
          double iconSize = 24.0;

          if (width < 340) {
            fontScale = 0.86;
            iconSize = 20.0;
          } else if (width < 380) {
            fontScale = 0.94;
            iconSize = 22.0;
          } else if (width > 600 && width < 900) {
            fontScale = 1.06;
            iconSize = 26.0;
          } else if (width >= 900) {
            fontScale = 1.08;
            iconSize = 26.0;
          }

          final responsiveMQ = mq.copyWith(
            textScaler: TextScaler.linear(fontScale),
          );

          return MediaQuery(
            data: responsiveMQ,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: IconTheme(
                data: IconThemeData(size: iconSize),
                child: child!,
              ),
            ),
          );
        },
        home: const HomePage(),
      ),
    );
  }
}
