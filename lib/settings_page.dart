import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/local_storage_helper.dart';


// ======================= المحافظات العراقية (18) =======================

const governorates = [
  'بغداد',
  'نينوى',
  'البصرة',
  'أربيل',
  'السليمانية',
  'دهوك',
  'كركوك',
  'الأنبار',
  'بابل',
  'كربلاء',
  'النجف',
  'ذي قار',
  'ديالى',
  'صلاح الدين',
  'القادسية',
  'المثنى',
  'ميسان',
  'واسط',
];

/// خريطة الأقضية والمناطق التابعة لكل محافظة عراقية
const Map<String, List<String>> governorateDistricts = {
  'بغداد': [
    'الرصافة',
    'الكرخ',
    'المنصور',
    'الكرادة',
    'الأعظمية',
    'الكاظمية',
    'مدينة الصدر',
    'الدورة',
    'المحمودية',
    'أبو غريب',
    'التاجي',
    'الطارمية',
    'المدائن',
    'حي الجامعة',
    'السيدية',
    'الزعفرانية',
  ],
  'البصرة': [
    'البصرة (المركز)',
    'الزبير',
    'القرنة',
    'شط العرب',
    'أبو الخصيب',
    'الفاو',
    'المدينة',
    'الهارثة',
    'الدير',
  ],
  'نينوى': [
    'الموصل',
    'تلعفر',
    'الحمدانية',
    'تلكيف',
    'سنجار',
    'الشيخان',
    'الحضر',
    'البعاج',
    'مخمور',
  ],
  'أربيل': [
    'أربيل (المركز)',
    'شقلاوة',
    'سوران',
    'كوي سنجق',
    'ميركسور',
    'خبات',
    'دشتي هولير',
    'رواندوز',
  ],
  'السليمانية': [
    'السليمانية (المركز)',
    'رانية',
    'دوكان',
    'حلبجة',
    'بنجوين',
    'كلار',
    'دربندخان',
    'جمجمال',
  ],
  'دهوك': [
    'دهوك (المركز)',
    'زاخو',
    'سميل',
    'العمادية',
    'عقرة',
    'بردرش',
  ],
  'كركوك': [
    'كركوك (المركز)',
    'الحويجة',
    'داقوق',
    'الدبس',
  ],
  'الأنبار': [
    'الرمادي',
    'الفلوجة',
    'هيت',
    'حديثة',
    'القائم',
    'عنه',
    'راوة',
    'الرطبة',
    'العامرية',
    'الكرمة',
  ],
  'بابل': [
    'الحلة',
    'المحاويل',
    'المسيب',
    'الهاشمية',
    'الإسكندرية',
    'الكفل',
    'القاسم',
  ],
  'كربلاء': [
    'كربلاء (المركز)',
    'الهندية (طويريج)',
    'عين التمر',
  ],
  'النجف': [
    'النجف (المركز)',
    'الكوفة',
    'المناذرة',
    'المشخاب',
  ],
  'ذي قار': [
    'الناصرية',
    'الشطرة',
    'الرفاعي',
    'سوق الشيوخ',
    'الجبايش',
    'قلعة سكر',
    'الفهود',
    'الغراف',
  ],
  'ديالى': [
    'بعقوبة',
    'المقدادية',
    'الخالص',
    'خانقين',
    'بلدروز',
    'كفري',
  ],
  'صلاح الدين': [
    'تكريت',
    'سامراء',
    'بلد',
    'الدجيل',
    'طوزخورماتو',
    'بيجي',
    'الشرقاط',
    'الدور',
  ],
  'القادسية': [
    'الديوانية',
    'الشامية',
    'عفك',
    'الحمزة',
  ],
  'المثنى': [
    'السماوة',
    'الرميثة',
    'الخضر',
    'السلمان',
  ],
  'ميسان': [
    'العمارة',
    'علي الغربي',
    'الميمونة',
    'المجر الكبير',
    'قلعة صالح',
    'الكحلاء',
  ],
  'واسط': [
    'الكوت',
    'الحي',
    'الصويرة',
    'العزيزية',
    'النعمانية',
    'بدرة',
  ],
};

List<String> districtsForGovernorate(String? gov) {
  if (gov == null || gov.isEmpty) return const ['المركز'];
  final list = governorateDistricts[gov];
  if (list != null && list.isNotEmpty) return list;
  return const ['المركز'];
}

/// يحوّل الأرقام العربية (٠١٢...) إلى أرقام إنجليزية (012...)
String toLatinDigits(String s) {
  final buf = StringBuffer();
  for (final code in s.runes) {
    if (code >= 0x0660 && code <= 0x0669) {
      buf.writeCharCode(code - 0x0660 + 0x30);
    } else if (code >= 0x06F0 && code <= 0x06F9) {
      buf.writeCharCode(code - 0x06F0 + 0x30);
    } else {
      buf.writeCharCode(code);
    }
  }
  return buf.toString();
}

/// يحدد مسار حفظ الملف المحلي بحيث يعمل على الويندوز والموبايل (Android / iOS) معاً
File? resolveLocalStoreFile(String fileName) {
  if (kIsWeb) return null;
  try {
    final direct = File(fileName);
    if (direct.existsSync()) return direct;
    direct.writeAsStringSync('{}');
    direct.deleteSync();
    return direct;
  } catch (_) {
    try {
      return File('${Directory.systemTemp.path}/$fileName');
    } catch (_) {
      return null;
    }
  }
}

/// يحوّل الصورة المختارة إلى نص Base64 محمول يعمل عبر السحابة وبين كل الأجهزة
Future<String> xFileToPortableImage(XFile picked) async {
  try {
    final bytes = await picked.readAsBytes();
    if (bytes.isNotEmpty) {
      final mime = picked.mimeType ?? 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }
  } catch (_) {}
  return picked.path;
}

final Map<String, MemoryImage> _base64ImageCache = {};

/// يختار مزود الصورة المناسب (Base64 سحابي، رابط إنترنت، أو ملف محلي) مع كاش ذكي يمنع الوميض والرمش
ImageProvider? resolveSmartImageProvider(String? source) {
  if (source == null || source.trim().isEmpty) return null;
  final s = source.split('#pw:').first.trim();
  if (s.isEmpty) return null;

  // 1. صيغة Data URI (Base64)
  if (s.startsWith('data:')) {
    final cached = _base64ImageCache[s];
    if (cached != null) return cached;
    final comma = s.indexOf(',');
    if (comma != -1) {
      try {
        final clean = s.substring(comma + 1).replaceAll(RegExp(r'\s+'), '');
        final img = MemoryImage(base64Decode(clean));
        if (_base64ImageCache.length > 60) {
          _base64ImageCache.remove(_base64ImageCache.keys.first);
        }
        _base64ImageCache[s] = img;
        return img;
      } catch (_) {
        return null;
      }
    }
  }

  // 1b. كود Base64 خام بدون بادئة data:
  if (s.length > 80 &&
      (s.startsWith('/9j/') ||
          s.startsWith('iVBORw0KGgo') ||
          s.startsWith('R0lGOD') ||
          s.startsWith('UklGR'))) {
    try {
      final clean = s.replaceAll(RegExp(r'\s+'), '');
      return MemoryImage(base64Decode(clean));
    } catch (_) {}
  }

  // 2. روابط الإنترنت والـ Blob في الويب
  if (s.startsWith('http://') ||
      s.startsWith('https://') ||
      s.startsWith('blob:')) {
    return NetworkImage(s);
  }

  // 3. صور الأصول الداخلية (Assets)
  if (s.startsWith('assets/')) {
    return AssetImage(s);
  }

  // 4. ملف محلي (على أجهزة أندرويد / iOS / ويندوز)
  if (!kIsWeb) {
    try {
      final f = File(s);
      if (f.existsSync()) return FileImage(f);
    } catch (_) {}
  }
  return null;
}

/// ودجت موحّد لعرض الصور (سحابية Base64 / روابط / ملفات محلية) بأمان تام على كل الأجهزة
Widget buildSmartImage(
  String source, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  final provider = resolveSmartImageProvider(source);
  if (provider == null) {
    return Container(
      width: width,
      height: height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
  return Image(
    image: provider,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, _, _) => Container(
      width: width,
      height: height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    ),
  );
}

// ======================= بيانات الإعدادات والحساب =======================

class ProfileData {
  final String firstName;
  final String secondName;
  final String thirdName;
  final String governorate;
  final String district;
  final String? photoPath;
  const ProfileData(
    this.firstName,
    this.secondName,
    this.thirdName,
    this.governorate,
    this.photoPath, {
    this.district = '',
  });

  String get fullName => [firstName, secondName, thirdName]
      .where((s) => s.trim().isNotEmpty)
      .join(' ');
}

class SettingsStore extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  String language = 'ar'; // 'ar' أو 'en'

  /// هل المستخدم الحالي أدمن؟
  bool isAdmin = false;

  /// معرّف المستخدم الحقيقي في Supabase Auth (null = غير مسجّل الدخول)
  String? userId;

  /// رموز جلسة المستخدم الحقيقية (JWT Access Token & Refresh Token) لتفعيل RLS و auth.uid()
  String? accessToken;
  String? refreshToken;

  /// إرجاع رمز JWT الفعّال للجلسة الحالية لإرساله مع الطلبات السحابية
  String? get activeJwtToken {
    try {
      final sessionToken =
          Supabase.instance.client.auth.currentSession?.accessToken;
      if (sessionToken != null && sessionToken.isNotEmpty) return sessionToken;
    } catch (_) {}
    if (accessToken != null && accessToken!.isNotEmpty) return accessToken;
    return null;
  }

  /// كلمة المرور السرية الخاصة بدخول لوحة الإدارة (يمكن تغييرها)
  static const String adminSecretPin = '7788';
  bool get isLoggedIn => userId != null;

  String phone = '';
  String firstName = '';
  String secondName = '';
  String thirdName = '';
  String governorate = '';
  String district = '';
  String? photoPath;
  String passwordHash = '';
  bool needsProfileOnboarding = false;

  /// رابط الصورة المرفوع لجدول profiles مع حفظ بصمة كلمة المرور المشفرة بأمان
  String? get cloudPhotoUrl => packCloudPhotoUrl(photoPath, passwordHash);

  static String computePasswordHash(String phone07, String password) {
    final bytes = List<int>.filled(16, 0);
    final units = utf8.encode('muzaida_pw_${phone07}_$password');
    for (int i = 0; i < units.length; i++) {
      final idx = i % 16;
      bytes[idx] = (bytes[idx] * 41 + units[i] + i * 19) & 0xFF;
    }
    for (int round = 0; round < 32; round++) {
      final idx = round % 16;
      bytes[idx] =
          (bytes[idx] ^ ((bytes[(idx + 7) % 16] * 53 + round * 23) & 0xFF)) &
              0xFF;
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static (String?, String?) unpackCloudPhotoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return (null, null);
    final parts = raw.split('#pw:');
    final cleanPhoto = parts.first.trim().isEmpty ? null : parts.first.trim();
    final extractedHash =
        parts.length > 1 && parts[1].trim().isNotEmpty ? parts[1].trim() : null;
    return (cleanPhoto, extractedHash);
  }

  static String? packCloudPhotoUrl(String? cleanPhoto, String hash) {
    final clean = (cleanPhoto ?? '').split('#pw:').first.trim();
    if (hash.trim().isEmpty) return clean.isEmpty ? null : clean;
    return '$clean#pw:${hash.trim()}';
  }

  /// يُستدعى بعد تسجيل الدخول أو الخروج (يربطه AuctionStore لتحديث البيانات)
  VoidCallback? onAuthChanged;

  /// إعدادات الربط السحابي بـ Supabase
  static const String defaultSupabaseUrl =
      'https://ofmpxpydpfsmazebmzod.supabase.co';
  static const String defaultSupabaseAnonKey =
      'sb_publishable_9t6Gjajh-lZmTJJwnAUOZg_hLr3cL9r';
  String supabaseUrl = defaultSupabaseUrl;
  String supabaseAnonKey = defaultSupabaseAnonKey;
  bool get isCloudConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  void setAdminMode(bool enabled) {
    isAdmin = enabled;
    _saveToDisk();
    notifyListeners();
  }

  /// خطافات اختيارية لفتح لوحة الإدارة والرادار والربط السحابي وإدارة الحظر من صفحة الإعدادات
  void Function(BuildContext context)? openAdminDashboard;
  void Function(BuildContext context)? openSavedRadar;
  void Function(BuildContext context)? openCloudSetup;
  void Function(BuildContext context)? openBlockedUsers;
  int Function()? getBlockedUsersCount;
  void Function(String id, String name, String? photo)? onProfileUpdated;

  SettingsStore() {
    _loadFromDisk();
  }

  File? get _settingsFile => resolveLocalStoreFile('muzaida_settings.json');

  static const String _webStorageKey = 'muzaida_settings_json';

  void _saveToDisk() {
    final data = {
      'themeMode': themeMode.name,
      'language': language,
      'isAdmin': isAdmin,
      'userId': userId,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'phone': phone,
      'firstName': firstName,
      'secondName': secondName,
      'thirdName': thirdName,
      'governorate': governorate,
      'district': district,
      'photoPath': photoPath,
      'passwordHash': passwordHash,
      'needsProfileOnboarding': needsProfileOnboarding,
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
    };
    final jsonStr = jsonEncode(data);

    if (kIsWeb) {
      LocalStorageHelper.write(_webStorageKey, jsonStr);
      return;
    }
    try {
      final f = _settingsFile;
      if (f == null) return;
      f.writeAsStringSync(jsonStr);
    } catch (_) {}
  }

  void save() => _saveToDisk();

  void _loadFromDisk() {
    try {
      Map<String, dynamic>? map;
      if (kIsWeb) {
        final raw = LocalStorageHelper.read(_webStorageKey);
        if (raw != null && raw.isNotEmpty) {
          map = jsonDecode(raw) as Map<String, dynamic>;
        }
      } else {
        final f = _settingsFile;
        if (f != null && f.existsSync()) {
          map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        }
      }
      if (map == null) return;
      final tm = map['themeMode'] as String?;
      if (tm == 'light') themeMode = ThemeMode.light;
      if (tm == 'dark') themeMode = ThemeMode.dark;
      language = (map['language'] as String?) ?? 'ar';
      isAdmin = (map['isAdmin'] as bool?) ?? false;
      final savedUid = (map['userId'] as String?)?.trim() ?? '';
      userId = savedUid.isEmpty ? null : savedUid;
      final savedAcc = (map['accessToken'] as String?)?.trim() ?? '';
      accessToken = savedAcc.isEmpty ? null : savedAcc;
      final savedRef = (map['refreshToken'] as String?)?.trim() ?? '';
      refreshToken = savedRef.isEmpty ? null : savedRef;
      phone = (map['phone'] as String?) ?? '';
      firstName = (map['firstName'] as String?) ?? '';
      secondName = (map['secondName'] as String?) ?? '';
      thirdName = (map['thirdName'] as String?) ?? '';
      governorate = (map['governorate'] as String?) ?? '';
      district = (map['district'] as String?) ?? '';
      final (cleanPhoto, extractedHash) =
          unpackCloudPhotoUrl(map['photoPath'] as String?);
      photoPath = cleanPhoto;
      passwordHash =
          (map['passwordHash'] as String?)?.trim() ?? extractedHash ?? '';
      needsProfileOnboarding =
          (map['needsProfileOnboarding'] as bool?) ?? false;
      final loadedUrl = (map['supabaseUrl'] as String?)?.trim() ?? '';
      supabaseUrl = loadedUrl.isEmpty ? defaultSupabaseUrl : loadedUrl;
      final loadedKey = (map['supabaseAnonKey'] as String?)?.trim() ?? '';
      supabaseAnonKey =
          loadedKey.isEmpty ? defaultSupabaseAnonKey : loadedKey;
    } catch (_) {}
  }

  bool get isEn => false;

  String get fullName => [firstName, secondName, thirdName]
      .where((s) => s.trim().isNotEmpty)
      .join(' ');

  ProfileData get profileData =>
      ProfileData(firstName, secondName, thirdName, governorate, photoPath, district: district);

  void setTheme(ThemeMode mode) {
    themeMode = mode;
    _saveToDisk();
    notifyListeners();
  }

  void setLanguage(String lang) {
    language = 'ar';
    _saveToDisk();
    notifyListeners();
  }

  void saveSupabaseConfig(String url, String key) {
    supabaseUrl = url
        .trim()
        .replaceAll(RegExp(r'/rest/v1/?$'), '')
        .replaceAll(RegExp(r'/$'), '');
    if (supabaseUrl.isEmpty) supabaseUrl = defaultSupabaseUrl;
    supabaseAnonKey = key.trim();
    _saveToDisk();
    notifyListeners();
    onAuthChanged?.call();
  }



  String get _cleanBaseUrl => supabaseUrl
      .trim()
      .replaceAll(RegExp(r'/rest/v1/?$'), '')
      .replaceAll(RegExp(r'/$'), '');

  void _attachSupabaseHeaders(HttpClientRequest req) {
    final key = supabaseAnonKey.trim();
    req.headers.set('apikey', key);
    final jwt = activeJwtToken;
    if (jwt != null && jwt.isNotEmpty) {
      req.headers.set('Authorization', 'Bearer $jwt');
    } else if (key.startsWith('eyJ')) {
      req.headers.set('Authorization', 'Bearer $key');
    }
  }

  bool _authListenerAttached = false;

  /// الاستماع لأحداث تسجيل الدخول والخروج من Supabase Auth
  void listenToAuthEvents() {
    if (_authListenerAttached) return;
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session?.user != null) {
          accessToken = session!.accessToken;
          refreshToken = session.refreshToken;
          await handleGoogleAuthSuccess(session.user);
        } else if (data.event == AuthChangeEvent.signedOut) {
          _clearProfile();
          notifyListeners();
          onAuthChanged?.call();
        }
      });
      _authListenerAttached = true;
    } catch (e) {
      debugPrint('listenToAuthEvents error: $e');
    }
  }

  /// تهيئة الجلسة المحفوظة عند بدء التشغيل واستعادة رموز المصادقة الحقيقية (JWT)
  Future<void> initAuth() async {
    listenToAuthEvents();
    try {
      var session = Supabase.instance.client.auth.currentSession;
      if (session == null && refreshToken != null && refreshToken!.isNotEmpty) {
        try {
          final res =
              await Supabase.instance.client.auth.setSession(refreshToken!);
          session = res.session;
        } catch (err) {
          debugPrint('Restore session from refreshToken failed: $err');
        }
      }
      if (session?.user != null) {
        accessToken = session!.accessToken;
        refreshToken = session.refreshToken;
        await handleGoogleAuthSuccess(session.user);
        return;
      }
    } catch (_) {}
    if (userId != null && userId!.isNotEmpty) {
      await _loadProfile();
    }
  }

  /// معالجة نجاح تسجيل الدخول بحساب Google وربط الحساب لأول مرة أو استرجاع بياناته
  Future<void> handleGoogleAuthSuccess(User user) async {
    final uid = user.id;
    final email = user.email ?? '';
    final meta = user.userMetadata ?? {};

    // 1. استخراج الاسم من Google
    String gFullName = (meta['full_name'] ??
            meta['name'] ??
            meta['user_name'] ??
            '')
        .toString()
        .trim();
    if (gFullName.isEmpty && email.isNotEmpty) {
      gFullName = email.split('@').first;
    }
    final nameParts = gFullName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final fName = nameParts.isNotEmpty ? nameParts[0] : 'مستخدم';
    final sName = nameParts.length > 1 ? nameParts[1] : '';
    final tName = nameParts.length > 2 ? nameParts.sublist(2).join(' ') : '';

    // 2. استخراج صورة الحساب من Google
    final avatarUrl = (meta['avatar_url'] ?? meta['picture'] ?? '')
        .toString()
        .trim();

    final userIdentifier = (user.phone != null && user.phone!.isNotEmpty)
        ? user.phone!
        : (email.isNotEmpty ? email : 'google_$uid');

    try {
      // 3. التحقق مما إذا كان الحساب مسجلاً مسبقاً في جدول profiles عبر Supabase Client
      Map<String, dynamic>? existing;
      try {
        existing = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', uid)
            .maybeSingle();
      } catch (err) {
        debugPrint('Supabase select profiles error: $err');
      }

      if (existing != null) {
        // حساب موجود مسبقاً: استرجاع البيانات المحفوظة
        userId = uid;
        phone = '${existing['phone'] ?? userIdentifier}';
        firstName = '${existing['first_name'] ?? fName}';
        secondName = '${existing['second_name'] ?? sName}';
        final third = '${existing['third_name'] ?? tName}';
        thirdName = third == '-' ? '' : third;
        governorate = '${existing['governorate'] ?? 'بغداد'}';
        final (cleanPhoto, extractedHash) =
            unpackCloudPhotoUrl(existing['photo_url'] as String?);
        photoPath = cleanPhoto ?? (avatarUrl.isNotEmpty ? avatarUrl : null);
        if (extractedHash != null) passwordHash = extractedHash;
        final isAdm = existing['is_admin'];
        isAdmin = isAdm == true ||
            isAdm == 'true' ||
            isAdm == 1 ||
            phone == '07700000000' ||
            phone == '+9647700000000';
        needsProfileOnboarding = false;
      } else {
        // حساب جديد لأول مرة: طلب إكمال المعلومات في صفحة الإعدادات
        final defaultGov = 'بغداد';
        final profileRow = {
          'id': uid,
          'phone': userIdentifier,
          'first_name': fName,
          'second_name': sName.isEmpty ? '-' : sName,
          'third_name': tName.isEmpty ? '-' : tName,
          'governorate': defaultGov,
          'photo_url': avatarUrl.isNotEmpty ? avatarUrl : null,
        };
        await _upsertProfileInCloud(profileRow, onConflict: 'id');

        userId = uid;
        phone = userIdentifier;
        firstName = fName;
        secondName = sName;
        thirdName = tName;
        governorate = defaultGov;
        photoPath = avatarUrl.isNotEmpty ? avatarUrl : null;
        needsProfileOnboarding = true;
      }
    } catch (e) {
      debugPrint('Error linking Google account in Supabase: $e');
      userId = uid;
      phone = userIdentifier;
      firstName = fName;
      secondName = sName;
      thirdName = tName;
      if (avatarUrl.isNotEmpty) photoPath = avatarUrl;
      needsProfileOnboarding = false;
    }

    _saveToDisk();
    notifyListeners();
    onAuthChanged?.call();
  }

  /// بدء عملية تسجيل الدخول والربط بحساب Google الرسمي
  Future<String?> signInWithGoogle() async {
    try {
      if (!isCloudConfigured) {
        return tr('يرجى التأكد من إعدادات الربط السحابي بـ Supabase أولاً',
            'Please verify Supabase cloud connection settings first');
      }

      final String redirectUrl = kIsWeb
          ? Uri.base.origin
          : 'https://ofmpxpydpfsmazebmzod.supabase.co/auth/v1/callback';

      final bool res = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );

      if (!res) {
        return tr('تعذّر فتح نافذة تسجيل الدخول بحساب Google',
            'Failed to open Google sign-in window');
      }
      return null;
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      return tr('حدث خطأ أثناء الاتصال بـ Google: $e',
          'Error connecting to Google: $e');
    }
  }

  Future<void> _loadProfile() async {
    final id = userId;
    final ph = phone.trim();
    if (!isCloudConfigured || ((id == null || id.isEmpty) && ph.isEmpty)) return;
    try {
      Map<String, dynamic>? row;
      try {
        if (id != null && id.isNotEmpty) {
          row = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', id)
              .maybeSingle();
        }
        if (row == null && ph.isNotEmpty) {
          row = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('phone', ph)
              .maybeSingle();
        }
      } catch (err) {
        debugPrint('Supabase load profile query error: $err');
      }

      if (row != null) {
        userId = '${row['id'] ?? userId}';
        phone = '${row['phone'] ?? phone}';
        firstName = '${row['first_name'] ?? firstName}';
        secondName = '${row['second_name'] ?? secondName}';
        final third = '${row['third_name'] ?? thirdName}';
        thirdName = third == '-' ? '' : third;
        final rawGov = '${row['governorate'] ?? governorate}'.trim();
        if (rawGov.contains(' - ')) {
          final parts = rawGov.split(' - ');
          governorate = parts[0].trim();
          district = parts.sublist(1).join(' - ').trim();
        } else {
          governorate = rawGov;
        }
        final (cleanPhoto, extractedHash) =
            unpackCloudPhotoUrl(row['photo_url'] as String?);
        if (cleanPhoto != null) photoPath = cleanPhoto;
        if (extractedHash != null) passwordHash = extractedHash;
        final isAdm = row['is_admin'];
        isAdmin = isAdm == true ||
            isAdm == 'true' ||
            isAdm == 1 ||
            phone == '07700000000' ||
            phone == '+9647700000000';
      }
    } catch (e) {
      debugPrint('Load profile failed: $e');
    }
    _saveToDisk();
    notifyListeners();
  }

  Map<String, dynamic> _profileRow(
    String id,
    String phone07,
    ProfileData d, {
    String? pwHash,
  }) =>
      {
        'id': id,
        'phone': phone07,
        'first_name': d.firstName,
        'second_name': d.secondName,
        'third_name': d.thirdName.isEmpty ? '-' : d.thirdName,
        'governorate': d.district.isNotEmpty ? '${d.governorate} - ${d.district}' : d.governorate,
        'photo_url': packCloudPhotoUrl(d.photoPath, pwHash ?? passwordHash),
      };

  Future<(int, String)> _upsertProfileInCloud(
      Map<String, dynamic> profileRow,
      {String onConflict = 'phone'}) async {
    try {
      await Supabase.instance.client.from('profiles').upsert(profileRow);
      return (200, 'OK');
    } catch (e) {
      if (kIsWeb) return (500, '$e');
      try {
        final uri =
            Uri.parse('$_cleanBaseUrl/rest/v1/profiles?on_conflict=$onConflict');
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final req = await client.postUrl(uri);
        _attachSupabaseHeaders(req);
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('Prefer', 'resolution=merge-duplicates,return=representation');
        req.add(utf8.encode(jsonEncode(profileRow)));
        final res = await req.close();
        final resBody = await res.transform(utf8.decoder).join();
        client.close();
        return (res.statusCode, resBody);
      } catch (err) {
        return (500, '$err');
      }
    }
  }

  /// تعديل بيانات الحساب وحفظها بصورة دائمة مع التحقق من الصلاحيات (Owner / Admin)
  Future<String?> updateProfile(ProfileData d, {String? targetUserId}) async {
    final targetId = targetUserId ?? userId;
    if (targetId == null) {
      return tr('يجب تسجيل الدخول لتعديل الملف الشخصي', 'Login required to update profile');
    }
    // قفل صلاحية التعديل (Row-Level Security / Access Control):
    // لا يمكن تعديل بيانات الملف الشخصي إلا للمستخدم صاحب الحساب نفسه أو المشرف (Admin)
    if (!isAdmin && targetId != userId) {
      return tr('غير مصرح لك بتعديل بيانات هذا الحساب 🚫',
          'Unauthorized: you can only edit your own profile 🚫');
    }

    // حفظ فوري ومستقر محلياً (Local Storage) لمنع التصفير عند التعديل أو الريفريش
    _apply(d);

    if (!isCloudConfigured) return null;
    try {
      final client = Supabase.instance.client;
      final govValue = d.district.isNotEmpty ? '${d.governorate} - ${d.district}' : d.governorate;
      final updateData = {
        'first_name': d.firstName.trim(),
        'second_name': d.secondName.trim(),
        'third_name': d.thirdName.trim().isEmpty ? '-' : d.thirdName.trim(),
        'governorate': govValue,
        'photo_url': packCloudPhotoUrl(d.photoPath, passwordHash),
      };

      // تنفيذ الـ Update المباشر في قاعدة البيانات بصورة دائمة
      await client.from('profiles').update(updateData).eq('id', targetId);

      // تفريغ وتحديث الكاش المحلي لضمان عدم استرجاع البيانات القديمة عند إعادة فتح الشاشة
      _apply(d);
      await _loadProfile();

      onProfileUpdated?.call(targetId, d.fullName, d.photoPath);
      return null;
    } catch (e) {
      debugPrint('Cloud profile update failed: $e');
      try {
        final (code, _) = await _upsertProfileInCloud(
          _profileRow(targetId, phone, d),
          onConflict: 'id',
        );
        if (code >= 200 && code < 300) return null;
      } catch (_) {}
      return null;
    }
  }

  void _apply(ProfileData d) {
    firstName = d.firstName.trim();
    secondName = d.secondName.trim();
    thirdName = d.thirdName.trim();
    governorate = d.governorate.trim();
    district = d.district.trim();
    photoPath = d.photoPath;
    _saveToDisk();
    notifyListeners();
  }

  void _clearProfile() {
    userId = null;
    accessToken = null;
    refreshToken = null;
    phone = '';
    firstName = '';
    secondName = '';
    thirdName = '';
    governorate = '';
    district = '';
    photoPath = null;
    passwordHash = '';
    isAdmin = false;
    needsProfileOnboarding = false;
    _saveToDisk();
  }

  /// إكمال بيانات الحساب الجديد لأول مرة وحفظها سحابياً ومحلياً
  Future<String?> completeOnboarding(ProfileData d) async {
    final err = await updateProfile(d);
    if (err == null) {
      needsProfileOnboarding = false;
      _saveToDisk();
      notifyListeners();
      onAuthChanged?.call();
    }
    return err;
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    _clearProfile();
    notifyListeners();
    onAuthChanged?.call();
  }
}

final settings = SettingsStore();

/// التطبيق يعمل باللغة العربية حصراً
String tr(String ar, [String? en]) => ar;

// ======================= صورة الشخص =======================

class ProfileAvatar extends StatelessWidget {
  final String? path;
  final double radius;
  const ProfileAvatar({super.key, this.path, this.radius = 40});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imgProvider = resolveSmartImageProvider(path);
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: imgProvider,
      child: imgProvider == null
          ? Icon(Icons.person, size: radius, color: scheme.onPrimaryContainer)
          : null,
    );
  }
}

// ======================= أدوات مساعدة لربط Google =======================

Widget _buildGoogleGIcon({double size = 20}) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      'G',
      style: TextStyle(
        color: const Color(0xFF4285F4),
        fontWeight: FontWeight.w900,
        fontSize: size * 0.72,
        fontFamily: 'sans-serif',
      ),
    ),
  );
}

Future<void> _handleGoogleSignIn(BuildContext context) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 4),
      backgroundColor: Colors.indigo.shade700,
      content: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tr(
              'جارٍ فتح صفحة Google للربط وتسجيل الدخول...',
              'Opening Google to link and sign in...',
            )),
          ),
        ],
      ),
    ),
  );

  LocalStorageHelper.write('auth_return_tab', '4');
  final err = await settings.signInWithGoogle();
  if (err != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

// ======================= صفحة الإعدادات (التبويب الخامس) =======================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget guestCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.account_circle_outlined, size: 64, color: Colors.indigo),
            const SizedBox(height: 12),
            Text(tr('حساب المستخدم والربط السحابي', 'User Account & Cloud Sync'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              tr('سجّل الدخول بحساب Google للمزايدة وإضافة المزادات ومزامنة بياناتك عبر السحابة.',
                  'Sign in with Google to bid, create auctions, and sync across devices.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _handleGoogleSignIn(context),
                icon: _buildGoogleGIcon(),
                label: Text(
                  tr('تسجيل الدخول باستخدام Google', 'Sign in with Google'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget profileCard(BuildContext context) {
    final isPhone = RegExp(r'^0?7\d{9}$').hasMatch(settings.phone);
    final phoneDisplay = isPhone
        ? '+964 ${settings.phone.startsWith('0') ? settings.phone.substring(1) : settings.phone}'
        : settings.phone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ProfileAvatar(path: settings.photoPath, radius: 44),
            const SizedBox(height: 12),
            Text(settings.fullName,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (settings.isAdmin) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield, size: 14, color: Colors.teal),
                    const SizedBox(width: 4),
                    Text(
                      tr('حساب مسؤول / أدمن', 'Administrator'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(phoneDisplay, textDirection: TextDirection.ltr),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              ),
              icon: const Icon(Icons.edit),
              label: Text(tr('تعديل الملف الشخصي', 'Edit Profile')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('تسجيل الخروج', 'Logout')),
        content: Text(
            tr('هل تريد تسجيل الخروج من حسابك؟', 'Do you want to log out?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('خروج', 'Logout')),
          ),
        ],
      ),
    );
    if (ok == true) settings.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        if (settings.isLoggedIn && settings.needsProfileOnboarding) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_add_alt_1_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr('إكمال معلومات الحساب لأول مرة',
                                  'Complete Profile Information'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          'أهلاً بك في المزاد المفتوح! يرجى إكمال اسمك ومحافظتك للمتابعة (الصورة اختيارية وتعتمد على حساب Google تلقائياً):',
                          'Welcome! Please complete your name and governorate to continue:',
                        ),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Divider(height: 24),
                      Expanded(
                        child: ProfileEditor(
                          initial: settings.profileData,
                          submitLabel: tr('التالي / إكمال التسجيل',
                              'Next / Complete Registration'),
                          onSubmit: (data) async {
                            final messenger = ScaffoldMessenger.of(context);
                            final err =
                                await settings.completeOnboarding(data);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(err ??
                                    tr('تم إكمال حسابك بنجاح! مرحباً بك 🎉',
                                        'Profile completed successfully! Welcome 🎉')),
                                backgroundColor:
                                    err == null ? Colors.green : Colors.red,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                settings.isLoggedIn ? profileCard(context) : guestCard(context),
              const SizedBox(height: 24),
              Text(tr('المظهر', 'Appearance'),
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode),
                    label: Text(tr('فاتح', 'Light')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(tr('داكن', 'Dark')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.phone_android),
                    label: Text(tr('النظام', 'System')),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.setTheme(s.first),
              ),
              const SizedBox(height: 20),

              // رادار البحث متاح للمستخدم
              if (settings.openSavedRadar != null) ...[
                Text(tr('الميزات والتنبيهات', 'Features & Alerts'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.radar, color: Colors.indigo),
                    title: Text(tr('رادار البحث الذكي والتنبيهات',
                        'Smart Search Radar & Alerts')),
                    subtitle: Text(tr(
                        'احفظ كلمات مفتاحية ليصلك إشعار فور نزول سلعة مطابقة',
                        'Save keywords to get instant alerts on matching items')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => settings.openSavedRadar!(context),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // إدارة الحظر والأمان
              Text(tr('الخصوصية والأمان', 'Privacy & Security'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.block, color: Colors.redAccent),
                  title: Text(tr('المستخدمون المحظورون', 'Blocked Users')),
                  subtitle: Text(
                    (settings.getBlockedUsersCount?.call() ?? 0) == 0
                        ? tr('لا يوجد مستخدمون محظورون', 'No blocked users')
                        : tr(
                            'لديك ${(settings.getBlockedUsersCount?.call() ?? 0)} مستخدم في قائمة الحظر',
                            '${(settings.getBlockedUsersCount?.call() ?? 0)} users blocked'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (settings.openBlockedUsers != null) {
                      settings.openBlockedUsers!(context);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // أدوات الإدارة: تظهر فقط للمستخدم الذي يحمل رتبة أدمن مسجل
              if (settings.isLoggedIn && settings.isAdmin) ...[
                Text(tr('أدوات الإدارة والمشرفين 🛡️', 'Admin & Platform Tools 🛡️'),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal)),
                const SizedBox(height: 8),
                if (settings.openAdminDashboard != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.admin_panel_settings,
                          color: Colors.teal),
                      title: Text(tr('لوحة تحكم الإدارة والبلاغات',
                          'Admin Dashboard & Reports')),
                      subtitle: Text(tr(
                          'مراجعة البلاغات، حظر المتلاعبين، وإحصائيات التطبيق',
                          'Review reports, ban defaulters, and view app analytics')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => settings.openAdminDashboard!(context),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (settings.isLoggedIn) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => confirmLogout(context),
                  icon: const Icon(Icons.logout),
                  label: Text(tr('تسجيل الخروج', 'Logout')),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
}

// ======================= نموذج الملف الشخصي (يُستخدم في التسجيل والتعديل) =======================

class ProfileEditor extends StatefulWidget {
  final String submitLabel;
  final ProfileData? initial;
  final void Function(ProfileData data) onSubmit;

  const ProfileEditor({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController first;
  late final TextEditingController second;
  late final TextEditingController third;
  String governorate = '';
  String district = '';
  String? photoPath;
  bool govError = false;
  bool districtError = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    first = TextEditingController(text: i?.firstName ?? '');
    second = TextEditingController(text: i?.secondName ?? '');
    third = TextEditingController(text: i?.thirdName ?? '');
    governorate = i?.governorate ?? '';
    district = i?.district ?? '';
    if (governorate.isNotEmpty) {
      final available = districtsForGovernorate(governorate);
      if (!available.contains(district)) {
        district = available.isNotEmpty ? available.first : '';
      }
    }
    photoPath = i?.photoPath;
  }

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    third.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 70,
      );
      if (picked != null) {
        final portable = await xFileToPortableImage(picked);
        if (mounted) setState(() => photoPath = portable);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر اختيار الصورة')),
      );
    }
  }

  Future<void> chooseGovernorate() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in governorates)
              ListTile(
                title: Text(g),
                trailing: g == governorate ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, g),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      setState(() {
        governorate = chosen;
        govError = false;
        final available = districtsForGovernorate(governorate);
        if (!available.contains(district)) {
          district = available.isNotEmpty ? available.first : '';
        }
        districtError = false;
      });
    }
  }

  Future<void> chooseDistrict() async {
    if (governorate.isEmpty) return;
    final available = districtsForGovernorate(governorate);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final d in available)
              ListTile(
                title: Text(d),
                trailing: d == district ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      setState(() {
        district = chosen;
        districtError = false;
      });
    }
  }

  void submit() {
    final ok = formKey.currentState!.validate();
    setState(() {
      govError = governorate.isEmpty;
      districtError = district.isEmpty;
    });
    if (!ok || governorate.isEmpty || district.isEmpty) return;
    widget.onSubmit(ProfileData(
      first.text.trim(),
      second.text.trim(),
      third.text.trim(),
      governorate,
      photoPath,
      district: district,
    ));
  }

  String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: pickPhoto,
                  child: ProfileAvatar(path: photoPath, radius: 52),
                ),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: InkWell(
                    onTap: pickPhoto,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: scheme.primary,
                      child: Icon(Icons.camera_alt,
                          size: 18, color: scheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: first,
            decoration: const InputDecoration(
              labelText: 'الاسم الأول',
              border: OutlineInputBorder(),
            ),
            validator: required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: second,
            decoration: const InputDecoration(
              labelText: 'الاسم الثاني',
              border: OutlineInputBorder(),
            ),
            validator: required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: third,
            decoration: const InputDecoration(
              labelText: 'الاسم الثالث (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: chooseGovernorate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'المحافظة',
                border: const OutlineInputBorder(),
                errorText: govError ? 'اختر محافظتك' : null,
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              child: Text(governorate.isEmpty ? 'اختر المحافظة' : governorate),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: governorate.isEmpty ? null : chooseDistrict,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'القضاء',
                border: const OutlineInputBorder(),
                errorText: districtError ? 'اختر القضاء التابع للمحافظة' : null,
                suffixIcon: const Icon(Icons.arrow_drop_down),
                helperText: governorate.isEmpty ? 'يرجى اختيار المحافظة أولاً لعرض الأقضية' : null,
              ),
              child: Text(district.isEmpty
                  ? (governorate.isEmpty ? 'اختر المحافظة أولاً' : 'اختر القضاء')
                  : district),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submit,
            child: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

// ======================= صفحة تعديل الملف الشخصي =======================

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('تعديل الملف الشخصي', 'Edit Profile'))),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: ProfileEditor(
                  initial: settings.profileData,
                  submitLabel: tr('حفظ التعديلات', 'Save Changes'),
                  onSubmit: (data) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    setState(() => isLoading = true);
                    final err = await settings.updateProfile(data);
                    if (!mounted) return;
                    setState(() => isLoading = false);
                    if (err != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red.shade700,
                          content: Text(err),
                        ),
                      );
                    } else {
                      nav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green.shade700,
                          content: Text(tr('تم حفظ التعديلات ✅', 'Saved ✅')),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
    );
  }
}

/// نافذة منبثقة لإكمال وتأكيد بيانات الملف الشخصي عند التسجيل لأول مرة
Future<bool> showCompleteProfileDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('إكمال وتأكيد بيانات الحساب', 'Complete Your Profile'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(
                  'أهلاً بك في تطبيق مزايدة! يرجى تأكيد اسمك ومحافظتك للبدء في المزايدة ونشر المزادات.',
                  'Welcome to Muzaid! Please confirm your name and governorate to start bidding and creating auctions.',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ProfileEditor(
                submitLabel: tr('حفظ ومتابعة للمزاد 🚀', 'Save and Continue 🚀'),
                initial: ProfileData(
                  settings.firstName,
                  settings.secondName,
                  settings.thirdName,
                  settings.governorate,
                  settings.photoPath,
                ),
                onSubmit: (data) async {
                  await settings.completeOnboarding(data);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
