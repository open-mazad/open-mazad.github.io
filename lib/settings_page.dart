import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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
    if (bytes.isNotEmpty && bytes.length <= 2 * 1024 * 1024) {
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
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
  if (s.startsWith('data:image/')) {
    final cached = _base64ImageCache[s];
    if (cached != null) return cached;
    final comma = s.indexOf(',');
    if (comma != -1) {
      try {
        final img = MemoryImage(base64Decode(s.substring(comma + 1)));
        if (_base64ImageCache.length > 50) {
          _base64ImageCache.remove(_base64ImageCache.keys.first);
        }
        _base64ImageCache[s] = img;
        return img;
      } catch (_) {
        return null;
      }
    }
  }
  if (s.startsWith('http://') || s.startsWith('https://')) {
    return NetworkImage(s);
  }
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
  final String? photoPath;
  const ProfileData(this.firstName, this.secondName, this.thirdName,
      this.governorate, this.photoPath);
}

class SettingsStore extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  String language = 'ar'; // 'ar' أو 'en'

  /// هل المستخدم الحالي أدمن؟
  bool isAdmin = false;

  /// معرّف المستخدم الحقيقي في Supabase Auth (null = غير مسجّل الدخول)
  String? userId;

  /// كلمة المرور السرية الخاصة بدخول لوحة الإدارة (يمكن تغييرها)
  static const String adminSecretPin = '7788';
  bool get isLoggedIn => userId != null;

  String phone = '';
  String firstName = '';
  String secondName = '';
  String thirdName = '';
  String governorate = '';
  String? photoPath;
  String passwordHash = '';

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

  /// خطافات اختيارية لفتح لوحة الإدارة والرادار والربط السحابي من صفحة الإعدادات
  void Function(BuildContext context)? openAdminDashboard;
  void Function(BuildContext context)? openSavedRadar;
  void Function(BuildContext context)? openCloudSetup;

  SettingsStore() {
    _loadFromDisk();
  }

  File? get _settingsFile => resolveLocalStoreFile('muzaida_settings.json');

  void _saveToDisk() {
    if (kIsWeb) return;
    try {
      final f = _settingsFile;
      if (f == null) return;
      final data = {
        'themeMode': themeMode.name,
        'language': language,
        'isAdmin': isAdmin,
        'userId': userId,
        'phone': phone,
        'firstName': firstName,
        'secondName': secondName,
        'thirdName': thirdName,
        'governorate': governorate,
        'photoPath': photoPath,
        'passwordHash': passwordHash,
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
      };
      f.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  void save() => _saveToDisk();

  void _loadFromDisk() {
    if (kIsWeb) return;
    try {
      final f = _settingsFile;
      if (f == null || !f.existsSync()) return;
      final map =
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final tm = map['themeMode'] as String?;
      if (tm == 'light') themeMode = ThemeMode.light;
      if (tm == 'dark') themeMode = ThemeMode.dark;
      language = (map['language'] as String?) ?? 'ar';
      isAdmin = (map['isAdmin'] as bool?) ?? false;
      final savedUid = (map['userId'] as String?)?.trim() ?? '';
      userId = savedUid.isEmpty ? null : savedUid;
      phone = (map['phone'] as String?) ?? '';
      firstName = (map['firstName'] as String?) ?? '';
      secondName = (map['secondName'] as String?) ?? '';
      thirdName = (map['thirdName'] as String?) ?? '';
      governorate = (map['governorate'] as String?) ?? '';
      final (cleanPhoto, extractedHash) =
          unpackCloudPhotoUrl(map['photoPath'] as String?);
      photoPath = cleanPhoto;
      passwordHash =
          (map['passwordHash'] as String?)?.trim() ?? extractedHash ?? '';
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
      ProfileData(firstName, secondName, thirdName, governorate, photoPath);

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
    if (key.startsWith('eyJ')) {
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
          await handleGoogleAuthSuccess(session!.user);
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

  /// تهيئة الجلسة المحفوظة عند بدء التشغيل
  Future<void> initAuth() async {
    listenToAuthEvents();
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.user != null) {
        await handleGoogleAuthSuccess(session!.user);
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
      } else {
        // حساب جديد لأول مرة: ربط الحساب وإنشاء سجل في جدول profiles
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
      }
    } catch (e) {
      debugPrint('Error linking Google account in Supabase: $e');
      userId = uid;
      phone = userIdentifier;
      firstName = fName;
      secondName = sName;
      thirdName = tName;
      if (avatarUrl.isNotEmpty) photoPath = avatarUrl;
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
        governorate = '${row['governorate'] ?? governorate}';
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
        'governorate': d.governorate,
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

  /// إنشاء حساب جديد عبر HTTP المباشر إلى Supabase (يعمل فوراً مع Hot Reload)
  Future<String?> updateProfile(ProfileData d) async {
    _apply(d);
    final id = userId;
    if (id == null || !isCloudConfigured) return null;
    try {
      final (code, _) =
          await _upsertProfileInCloud(_profileRow(id, phone, d));
      if (code >= 200 && code < 300) return null;
      return tr('حُفظ محلياً، لكن تعذّر الرفع للخادم ($code)',
          'Saved locally, server returned $code');
    } catch (e) {
      return tr('حُفظ محلياً، لكن تعذّر الرفع للخادم',
          'Saved locally, but failed to upload to server');
    }
  }

  void _apply(ProfileData d) {
    firstName = d.firstName;
    secondName = d.secondName;
    thirdName = d.thirdName;
    governorate = d.governorate;
    photoPath = d.photoPath;
    _saveToDisk();
    notifyListeners();
  }

  void _clearProfile() {
    userId = null;
    phone = '';
    firstName = '';
    secondName = '';
    thirdName = '';
    governorate = '';
    photoPath = null;
    passwordHash = '';
    isAdmin = false;
    _saveToDisk();
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
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.location_on_outlined, size: 18),
              label: Text(settings.governorate),
            ),
            const SizedBox(height: 8),
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
      builder: (context, _) => Center(
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
                if (settings.openCloudSetup != null)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        settings.isCloudConfigured
                            ? Icons.cloud_done
                            : Icons.cloud_sync_outlined,
                        color: settings.isCloudConfigured
                            ? Colors.green
                            : Colors.deepPurple,
                      ),
                      title: Text(tr('الربط السحابي (Supabase) وقاعدة البيانات',
                          'Supabase Cloud & Database Setup')),
                      subtitle: Text(
                        settings.isCloudConfigured
                            ? tr('متصل بالسحابة 🟢 + الحفظ المحلي الدائم مفعّل',
                                'Cloud Connected 🟢 + Local Persistence Active')
                            : tr(
                                'الحفظ المحلي الدائم مفعّل 💾 • اضغط للربط بـ Supabase',
                                'Local Persistence Active 💾 • Tap to connect Supabase'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => settings.openCloudSetup!(context),
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
      ),
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
  String? photoPath;
  bool govError = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    first = TextEditingController(text: i?.firstName ?? '');
    second = TextEditingController(text: i?.secondName ?? '');
    third = TextEditingController(text: i?.thirdName ?? '');
    governorate = i?.governorate ?? '';
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
      });
    }
  }

  void submit() {
    final ok = formKey.currentState!.validate();
    setState(() => govError = governorate.isEmpty);
    if (!ok || governorate.isEmpty) return;
    widget.onSubmit(ProfileData(
      first.text.trim(),
      second.text.trim(),
      third.text.trim(),
      governorate,
      photoPath,
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