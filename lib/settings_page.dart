import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:math';

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

  /// إعدادات بوابة Meta WhatsApp Cloud API الرسمية
  static const String defaultWhatsAppApiUrl =
      'https://graph.facebook.com/v21.0/1425077907354994/messages';
  static const String defaultWhatsAppApiToken =
      'EAAUiPWrVU9wBSywbcctKXtUA5tNlbLa2o86acmOWFtM8KHCbqMnqHSMBowc0PTaJUTU5G7rl2ESsUqgdRaTV24Cuc3hZA0WsPO9FFMTSVZAgzsZAp8ztYA5qGZCcq2zYkZC9NntzKrYupYF8miUmFgrmpWnoPP2vw8RxAREAIX1MOnt3IrUcxqqHu5Rd6biha8IUI6yRNJi19jOZCvnhY6NrAkD8vAkXsTPAXiOH3YmJtSyqZBdXthQPZAPx8a3ZAx8BKnUbercJu5OZC6DvM1fc4kAnhDWC1iWjItjs7mSbz1';
  static const String defaultWhatsAppPhoneNumberId = '1425077907354994';
  static const String defaultWhatsAppWabaId = '1794801205134341';
  static const String defaultWhatsAppTemplateName = 'otp';
  static const String defaultWhatsAppTemplateLang = 'ar';

  String whatsappApiUrl = defaultWhatsAppApiUrl;
  String whatsappApiToken = defaultWhatsAppApiToken;
  String whatsappPhoneNumberId = defaultWhatsAppPhoneNumberId;
  String whatsappWabaId = defaultWhatsAppWabaId;
  String whatsappTemplateName = defaultWhatsAppTemplateName;
  String whatsappTemplateLang = defaultWhatsAppTemplateLang;

  bool get isWhatsAppGatewayConfigured =>
      whatsappApiUrl.trim().isNotEmpty && whatsappApiToken.trim().isNotEmpty;

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
        'whatsappApiUrl': whatsappApiUrl,
        'whatsappApiToken': whatsappApiToken,
        'whatsappPhoneNumberId': whatsappPhoneNumberId,
        'whatsappWabaId': whatsappWabaId,
        'whatsappTemplateName': whatsappTemplateName,
        'whatsappTemplateLang': whatsappTemplateLang,
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

      final loadedPhoneId =
          (map['whatsappPhoneNumberId'] as String?)?.trim() ?? '';
      whatsappPhoneNumberId =
          loadedPhoneId.isEmpty ? defaultWhatsAppPhoneNumberId : loadedPhoneId;

      final loadedWaUrl = (map['whatsappApiUrl'] as String?)?.trim() ?? '';
      whatsappApiUrl = sanitizeMetaUrl(loadedWaUrl, whatsappPhoneNumberId);

      final loadedWaToken = (map['whatsappApiToken'] as String?)?.trim() ?? '';
      whatsappApiToken = (loadedWaToken.isEmpty || loadedWaToken.length < 50)
          ? defaultWhatsAppApiToken
          : loadedWaToken;

      final loadedWabaId = (map['whatsappWabaId'] as String?)?.trim() ?? '';
      whatsappWabaId = loadedWabaId.isEmpty ? defaultWhatsAppWabaId : loadedWabaId;

      final loadedTemplate =
          (map['whatsappTemplateName'] as String?)?.trim() ?? '';
      whatsappTemplateName =
          loadedTemplate.isEmpty ? defaultWhatsAppTemplateName : loadedTemplate;

      final loadedLang =
          (map['whatsappTemplateLang'] as String?)?.trim() ?? '';
      whatsappTemplateLang =
          loadedLang.isEmpty ? defaultWhatsAppTemplateLang : loadedLang;
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

  /// يتأكد من صحة رابط الـ Endpoint لـ Meta Cloud API ويضيف بادئة الرابط الرسمي تلقائياً إن أُدخل الـ Phone ID فقط
  static String sanitizeMetaUrl(String input, [String? phoneId]) {
    final clean = input.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    final pid = clean.isNotEmpty
        ? clean
        : (phoneId != null && phoneId.trim().isNotEmpty
            ? phoneId.trim()
            : defaultWhatsAppPhoneNumberId);
    return 'https://graph.facebook.com/v21.0/$pid/messages';
  }

  void saveWhatsAppGateway({
    required String apiUrl,
    required String apiToken,
    String? phoneNumberId,
    String? wabaId,
    String? templateName,
    String? templateLang,
  }) {
    if (phoneNumberId != null && phoneNumberId.trim().isNotEmpty) {
      whatsappPhoneNumberId = phoneNumberId.trim();
    }
    whatsappApiUrl = sanitizeMetaUrl(apiUrl, whatsappPhoneNumberId);
    whatsappApiToken =
        apiToken.trim().isEmpty ? defaultWhatsAppApiToken : apiToken.trim();
    if (wabaId != null && wabaId.trim().isNotEmpty) {
      whatsappWabaId = wabaId.trim();
    }
    if (templateName != null && templateName.trim().isNotEmpty) {
      whatsappTemplateName = templateName.trim();
    }
    if (templateLang != null && templateLang.trim().isNotEmpty) {
      whatsappTemplateLang = templateLang.trim();
    }
    _saveToDisk();
    notifyListeners();
  }

  /// يحوّل الرقم العراقي (07XXXXXXXXX) إلى الصيغة الدولية للواتساب (9647XXXXXXXXX)
  static String phoneToWhatsAppIntl(String phone07) {
    final clean = phone07.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('07')) return '964${clean.substring(1)}';
    if (clean.startsWith('964')) return clean;
    return '964$clean';
  }

  /// نص رسالة كود التحقق المرسلة عبر واتساب (إنشاء حساب أو استعادة كلمة المرور)
  String buildWhatsAppOtpMessage(String code, {bool isPasswordReset = false}) {
    if (isPasswordReset) {
      return '🔐 *Open Mazad*\nرمز استعادة وتغيير كلمة المرور لحسابك هو: *$code*\nأدخل هذا الرمز في التطبيق لتعيين كلمة المرور الجديدة.';
    }
    return '🟢 *Open Mazad*\nرمز التحقق لتأكيد رقم هاتفك وإنشاء حسابك هو: *$code*\nلا تشارك هذا الرمز مع أي شخص.';
  }

  /// يرسل رمز التحقق (OTP) إلى رقم الهاتف عبر Meta WhatsApp Cloud API (قالب رسائل Template)
  Future<(bool sentViaGateway, String statusNote)> sendWhatsAppOtp({
    required String phone07,
    required String code,
    bool isPasswordReset = false,
  }) async {
    final intlPhone = phoneToWhatsAppIntl(phone07);

    // التحقق التلقائي وتصحيح الرابط حتى لو وُضع Phone Number ID بدلاً من الرابط الكامل
    whatsappApiUrl = sanitizeMetaUrl(whatsappApiUrl, whatsappPhoneNumberId);

    if (isWhatsAppGatewayConfigured) {
      try {
        final uri = Uri.parse(whatsappApiUrl.trim());

        // دالة مساعدة لإرسال طلب POST إلى Meta Graph API
        Future<(int code, String body)> postMeta(
            Map<String, dynamic> payload) async {
          final client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 12);
          final req = await client.postUrl(uri);
          req.headers.set('Content-Type', 'application/json');
          req.headers.set('Authorization', 'Bearer ${whatsappApiToken.trim()}');
          req.add(utf8.encode(jsonEncode(payload)));
          final res = await req.close();
          final body = await res.transform(utf8.decoder).join();
          client.close();
          return (res.statusCode, body);
        }

        final tName = whatsappTemplateName.trim().isEmpty
            ? defaultWhatsAppTemplateName
            : whatsappTemplateName.trim();
        final tLang = whatsappTemplateLang.trim().isEmpty
            ? defaultWhatsAppTemplateLang
            : whatsappTemplateLang.trim();

        Map<String, dynamic> buildPayload(
            List<Map<String, dynamic>>? components) {
          final tmpl = <String, dynamic>{
            'name': tName,
            'language': {'code': tLang},
          };
          if (components != null && components.isNotEmpty) {
            tmpl['components'] = components;
          }
          return {
            'messaging_product': 'whatsapp',
            'recipient_type': 'individual',
            'to': intlPhone,
            'type': 'template',
            'template': tmpl,
          };
        }

        // محاولة أولية بحسب نوع القالب
        List<Map<String, dynamic>>? initialComponents;
        if (tName.toLowerCase() == 'hello_world') {
          initialComponents = null; // hello_world لا يقبل components
        } else {
          initialComponents = [
            {
              'type': 'body',
              'parameters': [
                {'type': 'text', 'text': code},
              ],
            },
          ];
        }

        var (statusCode, resBody) =
            await postMeta(buildPayload(initialComponents));

        // إذا عاد خطأ يطلب زر نسخ الكود أو لا يدعم المعلمات
        if (statusCode < 200 || statusCode >= 300) {
          final lower = resBody.toLowerCase();
          if (lower.contains('button') || lower.contains('component')) {
            final authWithButton = [
              {
                'type': 'body',
                'parameters': [
                  {'type': 'text', 'text': code},
                ],
              },
              {
                'type': 'button',
                'sub_type': 'url',
                'index': '0',
                'parameters': [
                  {'type': 'text', 'text': code},
                ],
              },
            ];
            final retryRes = await postMeta(buildPayload(authWithButton));
            if (retryRes.$1 >= 200 && retryRes.$1 < 300) {
              statusCode = retryRes.$1;
              resBody = retryRes.$2;
            }
          } else if (lower.contains('variable parameters') ||
              lower.contains('does not have parameters')) {
            final retryRes = await postMeta(buildPayload(null));
            if (retryRes.$1 >= 200 && retryRes.$1 < 300) {
              statusCode = retryRes.$1;
              resBody = retryRes.$2;
            }
          }
        }

        if (statusCode >= 200 && statusCode < 300) {
          return (
            true,
            'تم إرسال رمز التحقق إلى واتساب الرقم +$intlPhone عبر Meta WhatsApp Cloud API بنجاح ✅',
          );
        } else {
          debugPrint('Meta WhatsApp Cloud API Error ($statusCode): $resBody');
          String errorDetail = '';
          try {
            final errJson = jsonDecode(resBody);
            final errObj = errJson['error'];
            if (errObj is Map) {
              final details = errObj['error_data']?['details'] as String?;
              final msg = errObj['message'] as String?;
              if (details != null && details.isNotEmpty) {
                errorDetail = details;
              } else if (msg != null && msg.isNotEmpty) {
                errorDetail = msg;
              }
            }
          } catch (_) {}

          return (
            false,
            errorDetail.isNotEmpty
                ? 'تنبيه Meta API: $errorDetail'
                : 'فشل الإرسال عبر Meta WhatsApp Cloud API (كود $statusCode)',
          );
        }
      } catch (e) {
        debugPrint('Meta WhatsApp Exception: $e');
        return (
          false,
          'تعذر الاتصال بـ Meta WhatsApp Cloud API: $e',
        );
      }
    }

    return (
      false,
      'لم يتم ضبط بوابة Meta WhatsApp Cloud API بعد',
    );
  }

  /// يتحقق مسبقاً من عدم تسجيل رقم الهاتف في جدول profiles قبل إرسال كود الواتساب
  Future<String?> checkPhoneAvailable(String phone07) async {
    if (!isCloudConfigured) return null;
    try {
      final checkUri = Uri.parse(
          '$_cleanBaseUrl/rest/v1/profiles?phone=eq.$phone07&select=id,first_name');
      final checkClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final checkReq = await checkClient.getUrl(checkUri);
      _attachSupabaseHeaders(checkReq);
      final checkRes = await checkReq.close();
      final checkBody = await checkRes.transform(utf8.decoder).join();
      checkClient.close();

      if (checkRes.statusCode >= 200 && checkRes.statusCode < 300) {
        final existing = jsonDecode(checkBody);
        if (existing is List && existing.isNotEmpty) {
          return tr(
            'رقم الهاتف هذا مسجّل مسبقاً، انتقل لتبويب (تسجيل الدخول)',
            'This phone number is already registered, please use Sign In',
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// يتحقق من وجود رقم الهاتف في جدول profiles قبل إرسال كود استعادة كلمة المرور
  Future<String?> checkPhoneRegisteredForReset(String phone07) async {
    if (!isCloudConfigured) {
      return tr('الرجاء التأكد من إعدادات الربط السحابي أولاً',
          'Please check cloud configuration first');
    }
    try {
      final checkUri = Uri.parse(
          '$_cleanBaseUrl/rest/v1/profiles?phone=eq.$phone07&select=id,first_name');
      final checkClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final checkReq = await checkClient.getUrl(checkUri);
      _attachSupabaseHeaders(checkReq);
      final checkRes = await checkReq.close();
      final checkBody = await checkRes.transform(utf8.decoder).join();
      checkClient.close();

      if (checkRes.statusCode >= 200 && checkRes.statusCode < 300) {
        final existing = jsonDecode(checkBody);
        if (existing is List && existing.isNotEmpty) {
          return null; // الرقم مسجّل وموجود
        }
        return tr(
          'رقم الهاتف هذا غير مسجّل في التطبيق، تأكد من الرقم أو أنشئ حساباً جديداً',
          'This phone number is not registered. Check the number or create a new account.',
        );
      }
      return tr('تعذّر التحقق من الرقم (${checkRes.statusCode})',
          'Failed to verify phone (${checkRes.statusCode})');
    } catch (e) {
      return tr('تعذّر الاتصال بالخادم: $e', 'Connection error: $e');
    }
  }

  // ======================= تسجيل الدخول الحقيقي (Supabase REST & Auth API) =======================

  String get _cleanBaseUrl => supabaseUrl
      .trim()
      .replaceAll(RegExp(r'/rest/v1/?$'), '')
      .replaceAll(RegExp(r'/$'), '');

  /// يحوّل رقم الهاتف (07XXXXXXXXX) إلى بريد داخلي يستخدمه Supabase Auth
  static String phoneToAuthEmail(String phone07) =>
      '964${phone07.substring(1)}@muzaida.app';

  /// يولّد UUID ثابتاً ومتوافقاً مع PostgreSQL من رقم الهاتف عند الحاجة
  static String phoneToUuid(String phone07) {
    final bytes = List<int>.filled(16, 0);
    final units = utf8.encode('muzaida_phone_$phone07');
    for (int i = 0; i < units.length; i++) {
      final idx = i % 16;
      bytes[idx] = (bytes[idx] * 31 + units[i] + i * 17) & 0xFF;
    }
    for (int round = 0; round < 32; round++) {
      final idx = round % 16;
      bytes[idx] =
          (bytes[idx] ^ ((bytes[(idx + 5) % 16] * 37 + round * 13) & 0xFF)) &
              0xFF;
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

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
  Future<String?> signUp({
    required String phone07,
    required String password,
    required ProfileData data,
  }) async {
    try {
      // 1. فحص ما إذا كان رقم الهاتف مسجلاً مسبقاً في جدول profiles
      final checkUri = Uri.parse(
          '$_cleanBaseUrl/rest/v1/profiles?phone=eq.$phone07&select=id,first_name');
      final checkClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final checkReq = await checkClient.getUrl(checkUri);
      _attachSupabaseHeaders(checkReq);
      final checkRes = await checkReq.close();
      final checkBody = await checkRes.transform(utf8.decoder).join();
      checkClient.close();

      if (checkRes.statusCode >= 200 && checkRes.statusCode < 300) {
        final existing = jsonDecode(checkBody);
        if (existing is List && existing.isNotEmpty) {
          return tr(
            'رقم الهاتف هذا مسجّل مسبقاً، انتقل لتبويب (تسجيل الدخول)',
            'This phone number is already registered, please use Sign In',
          );
        }
      }

      // 2. محاولة التسجيل في Supabase Auth (auth.users)
      String resolvedUserId = phoneToUuid(phone07);
      try {
        final authUri = Uri.parse('$_cleanBaseUrl/auth/v1/signup');
        final authClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final authReq = await authClient.postUrl(authUri);
        _attachSupabaseHeaders(authReq);
        authReq.headers.set('Content-Type', 'application/json');
        authReq.add(utf8.encode(jsonEncode({
          'email': phoneToAuthEmail(phone07),
          'password': password,
          'data': {
            'phone': phone07,
            'first_name': data.firstName,
            'governorate': data.governorate,
          },
        })));
        final authRes = await authReq.close();
        final authBody = await authRes.transform(utf8.decoder).join();
        authClient.close();
        if (authRes.statusCode >= 200 && authRes.statusCode < 300) {
          final decoded = jsonDecode(authBody);
          if (decoded is Map) {
            final uid = decoded['id'] ??
                (decoded['user'] is Map ? decoded['user']['id'] : null);
            if (uid is String && uid.isNotEmpty) {
              resolvedUserId = uid;
            }
          }
        }
      } catch (_) {}

      final pwHash = computePasswordHash(phone07, password);

      // 3. حفظ الحساب في جدول public.profiles في Supabase
      final (code, body) = await _upsertProfileInCloud(
        _profileRow(resolvedUserId, phone07, data, pwHash: pwHash),
      );
      if (code < 200 || code >= 300) {
        return 'خطأ من قاعدة البيانات ($code): $body';
      }

      userId = resolvedUserId;
      phone = phone07;
      passwordHash = pwHash;
      _apply(data);
      await _loadProfile();
      _saveToDisk();
      notifyListeners();
      onAuthChanged?.call();
      return null;
    } catch (e) {
      return tr('تعذّر الاتصال بالخادم: $e', 'Connection error: $e');
    }
  }

  /// تسجيل الدخول برقم الهاتف وكلمة المرور عبر HTTP المباشر إلى Supabase
  Future<String?> signIn({
    required String phone07,
    required String password,
  }) async {
    try {
      // 1. البحث عن الحساب في جدول public.profiles برقم الهاتف
      Map<String, dynamic>? row;
      try {
        row = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('phone', phone07)
            .maybeSingle();
      } catch (_) {}

      if (row == null && !kIsWeb) {
        final uri = Uri.parse(
            '$_cleanBaseUrl/rest/v1/profiles?phone=eq.$phone07&select=*&limit=1');
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final req = await client.getUrl(uri);
        _attachSupabaseHeaders(req);
        final res = await req.close();
        final body = await res.transform(utf8.decoder).join();
        client.close();

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final list = jsonDecode(body);
          if (list is List && list.isNotEmpty) {
            row = list.first as Map<String, dynamic>;
          }
        }
      }

      if (row == null) {
        return tr(
          'هذا الرقم غير مسجّل بعد، انتقل لتبويب (حساب جديد) لإنشاء حسابك',
          'Phone number not found. Switch to Create Account tab first.',
        );
      }

      final (cleanPhoto, storedHash) =
          unpackCloudPhotoUrl(row['photo_url'] as String?);
      final enteredHash = computePasswordHash(phone07, password);

      if (storedHash != null && storedHash.isNotEmpty) {
        if (enteredHash != storedHash) {
          return tr('كلمة المرور غير صحيحة', 'Incorrect password');
        }
      } else if (!kIsWeb) {
        // حساب قديم لم تُحفظ فيه بصمة كلمة المرور بعد: نتحقق من Supabase Auth إن وُجد
        try {
          final authUri =
              Uri.parse('$_cleanBaseUrl/auth/v1/token?grant_type=password');
          final authClient = HttpClient()
            ..connectionTimeout = const Duration(seconds: 8);
          final authReq = await authClient.postUrl(authUri);
          _attachSupabaseHeaders(authReq);
          authReq.headers.set('Content-Type', 'application/json');
          authReq.add(utf8.encode(jsonEncode({
            'email': phoneToAuthEmail(phone07),
            'password': password,
          })));
          final authRes = await authReq.close();
          final authBody = await authRes.transform(utf8.decoder).join();
          authClient.close();
          if (authRes.statusCode == 400 &&
              authBody.toLowerCase().contains('invalid login credentials')) {
            return tr('كلمة المرور غير صحيحة', 'Incorrect password');
          }
        } catch (_) {}
      }

      userId = '${row['id'] ?? phoneToUuid(phone07)}';
      phone = '${row['phone'] ?? phone07}';
      firstName = '${row['first_name'] ?? ''}';
      secondName = '${row['second_name'] ?? ''}';
      final third = '${row['third_name'] ?? ''}';
      thirdName = third == '-' ? '' : third;
      governorate = '${row['governorate'] ?? ''}';
      photoPath = cleanPhoto;
      passwordHash = storedHash ?? enteredHash;
      final isAdm = row['is_admin'];
      isAdmin = isAdm == true ||
          isAdm == 'true' ||
          isAdm == 1 ||
          phone == '07700000000' ||
          phone == '+9647700000000';
      _saveToDisk();
      notifyListeners();
      onAuthChanged?.call();
      return null;
    } catch (e) {
      return tr('تعذّر الاتصال بالخادم: $e', 'Connection error: $e');
    }
  }

  /// تعيين كلمة مرور جديدة بعد تأكيد كود الواتساب (نسيان كلمة المرور) وتسجيل الدخول فوراً
  Future<String?> resetPasswordWithOtp({
    required String phone07,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse(
          '$_cleanBaseUrl/rest/v1/profiles?phone=eq.$phone07&select=*&limit=1');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(uri);
      _attachSupabaseHeaders(req);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return 'خطأ من الخادم (${res.statusCode}): $body';
      }

      final list = jsonDecode(body);
      if (list is! List || list.isEmpty) {
        return tr('رقم الهاتف غير مسجّل في التطبيق',
            'Phone number is not registered');
      }

      final row = list.first as Map<String, dynamic>;
      final (cleanPhoto, _) = unpackCloudPhotoUrl(row['photo_url'] as String?);
      final newHash = computePasswordHash(phone07, newPassword);
      final resolvedId = '${row['id'] ?? phoneToUuid(phone07)}';
      final fName = '${row['first_name'] ?? ''}';
      final sName = '${row['second_name'] ?? ''}';
      final tRaw = '${row['third_name'] ?? ''}';
      final tName = tRaw == '-' ? '' : tRaw;
      final gov = '${row['governorate'] ?? 'بغداد'}';
      final data = ProfileData(fName, sName, tName, gov, cleanPhoto);

      final (upCode, upBody) = await _upsertProfileInCloud(
        _profileRow(resolvedId, phone07, data, pwHash: newHash),
      );
      if (upCode < 200 || upCode >= 300) {
        return 'تعذّر حفظ كلمة المرور الجديدة ($upCode): $upBody';
      }

      userId = resolvedId;
      phone = phone07;
      passwordHash = newHash;
      _apply(data);
      await _loadProfile();
      _saveToDisk();
      notifyListeners();
      onAuthChanged?.call();
      return null;
    } catch (e) {
      return tr('تعذّر الاتصال بالخادم: $e', 'Connection error: $e');
    }
  }

  /// تعديل الملف الشخصي محلياً وفي جدول profiles
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
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => _handleGoogleSignIn(context),
                    icon: _buildGoogleGIcon(),
                    label: Text(tr('تسجيل الدخول', 'Sign In')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AuthPage(initialTab: 0)),
                    ),
                    icon: const Icon(Icons.phone_android_outlined),
                    label: Text(tr('برقم الهاتف', 'Phone / SMS')),
                  ),
                ),
              ],
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
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.chat_rounded,
                        color: Color(0xFF25D366)),
                    title: const Text('بوابة Meta WhatsApp Cloud API الرسمية'),
                    subtitle: Text(settings.isWhatsAppGatewayConfigured
                        ? 'متصل عبر Meta Graph API v21.0 🟢 • اضغط لضبط القالب واختبار الإرسال'
                        : 'اضغط للربط بـ Meta WhatsApp Cloud API واختبار الإرسال'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showWhatsAppGatewayDialog(context),
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

// ======================= صفحة تسجيل الدخول وإنشاء الحساب الحقيقي (AuthPage) =======================

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthPage(initialTab: 1);
}

class AuthPage extends StatefulWidget {
  final int initialTab; // 0 = تسجيل دخول، 1 = إنشاء حساب
  const AuthPage({super.key, this.initialTab = 0});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // تسجيل الدخول
  final _signInPhoneCtrl = TextEditingController();
  final _signInPassCtrl = TextEditingController();
  bool _signInObscure = true;
  bool _signInLoading = false;
  String? _signInError;

  // نسيان كلمة المرور - 3 خطوات (0 = إدخال الرقم، 1 = إدخال الكود، 2 = إدخال الرمز الجديد)
  bool _forgotMode = false;
  int _forgotStep = 0;
  final _forgotPhoneCtrl = TextEditingController();
  final _forgotOtpCtrl = TextEditingController();
  final _forgotNewPassCtrl = TextEditingController();
  final _forgotNewPassConfirmCtrl = TextEditingController();
  bool _forgotObscure = true;
  bool _forgotLoading = false;
  String? _forgotNormalizedPhone;
  String? _forgotGeneratedOtp;
  String? _forgotWhatsAppNote;
  bool _forgotSentViaGateway = false;
  String? _forgotError;

  // إنشاء الحساب - 3 خطوات (0 = الهاتف وكلمة المرور، 1 = تأكيد رمز واتساب، 2 = البيانات الشخصية)
  int _signUpStep = 0;
  final _signUpPhoneCtrl = TextEditingController();
  final _signUpPassCtrl = TextEditingController();
  final _signUpPassConfirmCtrl = TextEditingController();
  final _signUpOtpCtrl = TextEditingController();
  bool _signUpObscure = true;
  bool _signUpLoading = false;
  String? _signUpNormalizedPhone;
  String? _signUpError;
  String? _generatedOtpCode;
  String? _whatsAppStatusNote;
  bool _sentViaCloudGateway = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    if (settings.phone.isNotEmpty) {
      _signInPhoneCtrl.text = settings.phone;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _signInPhoneCtrl.dispose();
    _signInPassCtrl.dispose();
    _forgotPhoneCtrl.dispose();
    _forgotOtpCtrl.dispose();
    _forgotNewPassCtrl.dispose();
    _forgotNewPassConfirmCtrl.dispose();
    _signUpPhoneCtrl.dispose();
    _signUpPassCtrl.dispose();
    _signUpPassConfirmCtrl.dispose();
    _signUpOtpCtrl.dispose();
    super.dispose();
  }

  /// توليد رمز تحقق عشوائي من 6 أرقام
  String _generateSixDigitOtp() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  /// تحويل أي صيغة لرقم الهاتف العراقي إلى صيغة 07XXXXXXXXX
  String? _normalizePhone(String raw) {
    var d = toLatinDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('964')) d = '0${d.substring(3)}';
    if (d.length == 10 && d.startsWith('7')) d = '0$d';
    return RegExp(r'^07\d{9}$').hasMatch(d) ? d : null;
  }

  Future<void> _handleSignIn() async {
    final phone = _normalizePhone(_signInPhoneCtrl.text);
    final pass = _signInPassCtrl.text;
    if (phone == null) {
      setState(() => _signInError =
          tr('اكتب رقماً عراقياً صحيحاً، مثال: 07701234567', 'Enter valid Iraqi phone number (e.g. 07701234567)'));
      return;
    }
    if (pass.isEmpty) {
      setState(() => _signInError =
          tr('أدخل كلمة المرور', 'Enter your password'));
      return;
    }
    setState(() {
      _signInLoading = true;
      _signInError = null;
    });

    final err = await settings.signIn(phone07: phone, password: pass);
    if (!mounted) return;
    setState(() => _signInLoading = false);

    if (err != null) {
      setState(() => _signInError = err);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            tr('أهلاً بك يا ${settings.fullName}! تم تسجيل الدخول بنجاح 🟢',
                'Welcome ${settings.fullName}! Logged in successfully 🟢'),
          ),
        ),
      );
    }
  }

  Future<void> _handleSignUpStep1() async {
    final phone = _normalizePhone(_signUpPhoneCtrl.text);
    final pass = _signUpPassCtrl.text;
    final passConfirm = _signUpPassConfirmCtrl.text;

    if (phone == null) {
      setState(() => _signUpError = tr(
          'اكتب رقماً عراقياً صحيحاً، مثال: 07701234567',
          'Enter valid Iraqi phone number (07701234567)'));
      return;
    }
    if (pass.length < 6) {
      setState(() => _signUpError = tr(
          'كلمة المرور يجب أن تكون 6 خانات على الأقل',
          'Password must be at least 6 characters'));
      return;
    }
    if (pass != passConfirm) {
      setState(() => _signUpError =
          tr('كلمتا المرور غير متطابقتين', 'Passwords do not match'));
      return;
    }

    setState(() {
      _signUpLoading = true;
      _signUpError = null;
    });

    // فحص مسبق لعدم تكرار الرقم في قاعدة البيانات قبل إرسال رمز الواتساب
    final existingErr = await settings.checkPhoneAvailable(phone);
    if (!mounted) return;
    if (existingErr != null) {
      setState(() {
        _signUpLoading = false;
        _signUpError = existingErr;
      });
      return;
    }

    final otp = _generateSixDigitOtp();
    final (viaGateway, note) = await settings.sendWhatsAppOtp(
      phone07: phone,
      code: otp,
    );
    if (!mounted) return;

    setState(() {
      _signUpLoading = false;
      _signUpNormalizedPhone = phone;
      _generatedOtpCode = otp;
      _sentViaCloudGateway = viaGateway;
      _whatsAppStatusNote = note;
      _signUpOtpCtrl.clear();
      _signUpError = null;
      _signUpStep = 1; // الانتقال إلى خطوة تأكيد رمز الواتساب
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF128C7E),
        content: Text(
          tr(
            '💬 تم إرسال رمز التحقق المكون من 6 أرقام إلى واتساب الرقم $phone',
            '💬 6-digit verification code sent to WhatsApp ($phone)',
          ),
        ),
      ),
    );
  }

  Future<void> _resendWhatsAppOtp() async {
    final phone = _signUpNormalizedPhone;
    if (phone == null) return;
    final otp = _generateSixDigitOtp();
    setState(() {
      _signUpLoading = true;
      _signUpError = null;
    });
    final (viaGateway, note) = await settings.sendWhatsAppOtp(
      phone07: phone,
      code: otp,
    );
    if (!mounted) return;
    setState(() {
      _signUpLoading = false;
      _generatedOtpCode = otp;
      _sentViaCloudGateway = viaGateway;
      _whatsAppStatusNote = note;
      _signUpOtpCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF128C7E),
        content: Text(
          tr('🔄 تم إعادة إرسال رمز تحقق جديد إلى واتساب',
              '🔄 New verification code sent to WhatsApp'),
        ),
      ),
    );
  }

  void _handleVerifyWhatsAppOtp() {
    final entered =
        toLatinDigits(_signUpOtpCtrl.text).replaceAll(RegExp(r'[^0-9]'), '');
    if (entered.length != 6) {
      setState(() => _signUpError = tr(
          'أدخل رمز التحقق المكون من 6 أرقام المرسل إلى واتساب',
          'Enter the 6-digit verification code sent to WhatsApp'));
      return;
    }
    if (entered != _generatedOtpCode) {
      setState(() => _signUpError = tr(
          'رمز التحقق غير صحيح، تأكد من الرمز المرسل إلى واتساب',
          'Invalid verification code, please check your WhatsApp message'));
      return;
    }

    setState(() {
      _signUpError = null;
      _signUpStep = 2; // الانتقال إلى خطوة البيانات الشخصية بعد تأكيد الرقم
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        content: Text(
          tr('✅ تم تأكيد رقم الهاتف عبر واتساب بنجاح! أكمل بياناتك الشخصية',
              '✅ Phone number verified via WhatsApp! Complete your profile'),
        ),
      ),
    );
  }

  void _showWhatsAppGatewayDialog() =>
      showWhatsAppGatewayDialog(context, () => setState(() {}));

  Future<void> _handleSignUpComplete(ProfileData data) async {
    final phone = _signUpNormalizedPhone!;
    final pass = _signUpPassCtrl.text;

    setState(() {
      _signUpLoading = true;
      _signUpError = null;
    });

    final err = await settings.signUp(
      phone07: phone,
      password: pass,
      data: data,
    );
    if (!mounted) return;
    setState(() => _signUpLoading = false);

    if (err != null) {
      setState(() {
        _signUpError = err;
        _signUpStep = 0; // العودة للخطوة الأولى لإظهار الخطأ وتصحيحه
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade700, content: Text(err)),
      );
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            tr('تم إنشاء حسابك وتفعيله بنجاح! أهلاً بك في Open Mazad 🎉',
                'Account created successfully! Welcome to Open Mazad 🎉'),
          ),
        ),
      );
    }
  }

  // ======================= نسيان كلمة المرور (3 خطوات عبر واتساب) =======================

  Future<void> _handleForgotStep1SendOtp() async {
    final phone = _normalizePhone(_forgotPhoneCtrl.text);
    if (phone == null) {
      setState(() => _forgotError = tr(
          'اكتب رقماً عراقياً صحيحاً، مثال: 07701234567',
          'Enter valid Iraqi phone number (07701234567)'));
      return;
    }

    setState(() {
      _forgotLoading = true;
      _forgotError = null;
    });

    final regErr = await settings.checkPhoneRegisteredForReset(phone);
    if (!mounted) return;
    if (regErr != null) {
      setState(() {
        _forgotLoading = false;
        _forgotError = regErr;
      });
      return;
    }

    final otp = _generateSixDigitOtp();
    final (viaGateway, note) = await settings.sendWhatsAppOtp(
      phone07: phone,
      code: otp,
      isPasswordReset: true,
    );
    if (!mounted) return;

    setState(() {
      _forgotLoading = false;
      _forgotNormalizedPhone = phone;
      _forgotGeneratedOtp = otp;
      _forgotSentViaGateway = viaGateway;
      _forgotWhatsAppNote = note;
      _forgotOtpCtrl.clear();
      _forgotError = null;
      _forgotStep = 1; // الانتقال لإدخال الكود
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF128C7E),
        content: Text(
          tr(
            '💬 تم إرسال كود استعادة كلمة المرور إلى واتساب الرقم $phone',
            '💬 Password reset code sent to WhatsApp ($phone)',
          ),
        ),
      ),
    );
  }

  void _handleForgotStep2VerifyOtp() {
    final entered =
        toLatinDigits(_forgotOtpCtrl.text).replaceAll(RegExp(r'[^0-9]'), '');
    if (entered.length != 6) {
      setState(() => _forgotError = tr(
          'أدخل كود التحقق المكون من 6 أرقام المرسل إلى واتساب',
          'Enter the 6-digit code sent to WhatsApp'));
      return;
    }
    if (entered != _forgotGeneratedOtp) {
      setState(() => _forgotError = tr(
          'الكود غير صحيح، تأكد من الرمز المرسل إلى واتساب',
          'Invalid code, please check your WhatsApp message'));
      return;
    }

    setState(() {
      _forgotError = null;
      _forgotNewPassCtrl.clear();
      _forgotNewPassConfirmCtrl.clear();
      _forgotStep = 2; // الانتقال لإدخال الرمز (كلمة المرور) الجديد
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        content: Text(
          tr('✅ تم تأكيد الكود! أدخل الآن كلمة المرور الجديدة',
              '✅ Code verified! Enter your new password now'),
        ),
      ),
    );
  }

  Future<void> _handleForgotStep3SavePassword() async {
    final phone = _forgotNormalizedPhone;
    if (phone == null) return;
    final newPass = _forgotNewPassCtrl.text;
    final confirmPass = _forgotNewPassConfirmCtrl.text;

    if (newPass.length < 6) {
      setState(() => _forgotError = tr(
          'الرمز الجديد يجب أن يكون 6 خانات على الأقل',
          'New password must be at least 6 characters'));
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _forgotError =
          tr('كلمتا المرور غير متطابقتين', 'Passwords do not match'));
      return;
    }

    setState(() {
      _forgotLoading = true;
      _forgotError = null;
    });

    final err = await settings.resetPasswordWithOtp(
      phone07: phone,
      newPassword: newPass,
    );
    if (!mounted) return;
    setState(() => _forgotLoading = false);

    if (err != null) {
      setState(() => _forgotError = err);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            tr('🔐 تم تغيير كلمة المرور وتسجيل دخولك بنجاح!',
                '🔐 Password updated and logged in successfully!'),
          ),
        ),
      );
    }
  }

  Widget _buildForgotPasswordView() {
    final intlPhone =
        SettingsStore.phoneToWhatsAppIntl(_forgotNormalizedPhone ?? '');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                if (_forgotStep > 0) {
                  _forgotStep--;
                } else {
                  _forgotMode = false;
                }
                _forgotError = null;
              }),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                _forgotStep == 0
                    ? tr('العودة لتسجيل الدخول', 'Back to Sign In')
                    : tr('رجوع للخطوة السابقة', 'Previous Step'),
              ),
            ),
            const Spacer(),
            if (_forgotStep == 1)
              TextButton.icon(
                onPressed: _showWhatsAppGatewayDialog,
                icon: const Icon(Icons.settings_suggest_outlined,
                    size: 18, color: Color(0xFF128C7E)),
                label: Text(
                  tr('بوابة API', 'WhatsApp API'),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF128C7E)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // الخطوة 1: إدخال رقم الهاتف وإرسال كود الاستعادة
        if (_forgotStep == 0) ...[
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFF128C7E),
            child: Icon(Icons.lock_reset_rounded, size: 38, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            tr('استعادة كلمة المرور عبر واتساب',
                'Reset Password via WhatsApp'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            tr('الخطوة 1 من 3: أدخل رقم هاتفك المسجّل في التطبيق لإرسال كود الاستعادة إلى واتساب',
                'Step 1 of 3: Enter your registered phone number to receive a reset code on WhatsApp'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _forgotPhoneCtrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف المسجّل',
              hintText: '07701234567',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _handleForgotStep1SendOtp(),
          ),
          if (_forgotError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 20, color: Colors.red.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _forgotError!,
                      style:
                          TextStyle(fontSize: 12.5, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _forgotLoading ? null : _handleForgotStep1SendOtp,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
            icon: _forgotLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.chat_rounded),
            label: Text(
              tr('إرسال كود الاستعادة إلى واتساب 💬',
                  'Send Reset Code to WhatsApp 💬'),
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],

        // الخطوة 2: إدخال الكود المرسل إلى واتساب
        if (_forgotStep == 1) ...[
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFF25D366),
            child: Icon(Icons.verified_user_rounded,
                size: 36, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            tr('تأكيد كود استعادة كلمة المرور',
                'Verify Password Reset Code'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'الخطوة 2 من 3: أدخل الكود المكون من 6 أرقام المرسل إلى واتساب الرقم\n+$intlPhone ($_forgotNormalizedPhone)',
              'Step 2 of 3: Enter the 6-digit code sent to WhatsApp\n+$intlPhone ($_forgotNormalizedPhone)',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCF8C6).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF25D366).withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mark_chat_unread_rounded,
                        color: Color(0xFF075E54), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _forgotSentViaGateway
                            ? tr('تم الإرسال عبر بوابة واتساب السحابية 🟢',
                                'Sent via WhatsApp Cloud Gateway 🟢')
                            : tr('رسالة واتساب المرسلة إلى +$intlPhone 💬',
                                'WhatsApp Message to +$intlPhone 💬'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF075E54),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_forgotWhatsAppNote != null)
                  Text(
                    _forgotWhatsAppNote!,
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _forgotOtpCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              labelText: tr('كود التحقق المكون من 6 أرقام',
                  '6-Digit Verification Code'),
              hintText: '••••••',
              prefixIcon: const Icon(Icons.verified_user_outlined,
                  color: Color(0xFF128C7E)),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _handleForgotStep2VerifyOtp(),
          ),
          if (_forgotError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 20, color: Colors.red.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _forgotError!,
                      style:
                          TextStyle(fontSize: 12.5, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _handleForgotStep2VerifyOtp,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              tr('تأكيد الكود وإدخال الرمز الجديد ✅',
                  'Verify Code & Enter New Password ✅'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _forgotLoading ? null : _handleForgotStep1SendOtp,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(tr('إعادة إرسال الكود عبر واتساب',
                  'Resend Code via WhatsApp')),
            ),
          ),
        ],

        // الخطوة 3: إدخال الرمز (كلمة المرور) الجديد
        if (_forgotStep == 2) ...[
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFF128C7E),
            child: Icon(Icons.password_rounded, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            tr('تعيين الرمز الجديد للحساب', 'Set New Password'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'الخطوة 3 من 3: تم تأكيد الرقم $_forgotNormalizedPhone بنجاح، أدخل الآن الرمز الجديد لحسابك',
              'Step 3 of 3: Phone $_forgotNormalizedPhone verified! Enter your new password',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _forgotNewPassCtrl,
            obscureText: _forgotObscure,
            decoration: InputDecoration(
              labelText: tr('الرمز / كلمة المرور الجديدة (6 خانات على الأقل)',
                  'New Password (min 6 characters)'),
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_forgotObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _forgotObscure = !_forgotObscure),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _forgotNewPassConfirmCtrl,
            obscureText: _forgotObscure,
            decoration: InputDecoration(
              labelText:
                  tr('تأكيد الرمز / كلمة المرور الجديدة', 'Confirm New Password'),
              prefixIcon: const Icon(Icons.lock_reset),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _handleForgotStep3SavePassword(),
          ),
          if (_forgotError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 20, color: Colors.red.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _forgotError!,
                      style:
                          TextStyle(fontSize: 12.5, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _forgotLoading ? null : _handleForgotStep3SavePassword,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
            icon: _forgotLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              tr('حفظ الرمز الجديد وتسجيل الدخول 🔐',
                  'Save New Password & Sign In 🔐'),
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignInTab() {
    if (_forgotMode) {
      return _buildForgotPasswordView();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        Icon(Icons.lock_open_rounded,
            size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          tr('تسجيل الدخول إلى حسابك', 'Sign In to Your Account'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          tr('سجّل الدخول بحساب Google أو رقم هاتفك العراقي',
              'Sign in with Google account or your Iraqi phone number'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            _handleGoogleSignIn(context);
          },
          icon: _buildGoogleGIcon(),
          label: Text(
            tr('المتابعة بحساب Google', 'Continue with Google'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                tr('أو برقم الهاتف', 'Or with phone'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _signInPhoneCtrl,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'رقم الهاتف',
            hintText: '07701234567',
            prefixIcon: Icon(Icons.phone_android),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _signInPassCtrl,
          obscureText: _signInObscure,
          decoration: InputDecoration(
            labelText: tr('كلمة المرور', 'Password'),
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_signInObscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _signInObscure = !_signInObscure),
            ),
          ),
          onSubmitted: (_) => _handleSignIn(),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _forgotMode = true;
                _forgotStep = 0;
                _forgotError = null;
                if (_signInPhoneCtrl.text.trim().isNotEmpty) {
                  _forgotPhoneCtrl.text = _signInPhoneCtrl.text.trim();
                }
              });
            },
            icon: const Icon(Icons.lock_reset_rounded,
                size: 18, color: Color(0xFF128C7E)),
            label: Text(
              tr('نسيت كلمة المرور؟ استعادتها عبر واتساب 💬',
                  'Forgot Password? Reset via WhatsApp 💬'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF128C7E),
              ),
            ),
          ),
        ),
        if (_signInError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: Colors.red.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _signInError!,
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _signInLoading ? null : _handleSignIn,
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
          child: _signInLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(tr('دخول', 'Sign In'),
                  style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => _tabCtrl.animateTo(1),
            child: Text(tr('ليس لديك حساب بعد؟ اضغط لإنشاء حساب',
                "Don't have an account? Sign Up")),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpTab() {
    // الخطوة 3 من 3: إدخال البيانات الشخصية بعد تأكيد رقم الواتساب
    if (_signUpStep == 2) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF25D366).withValues(alpha: 0.14),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _signUpStep = 1),
                  tooltip: tr('رجوع', 'Back'),
                ),
                const Icon(Icons.verified_rounded,
                    color: Color(0xFF128C7E), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(
                      'الخطوة 3 من 3 • تم تأكيد الرقم عبر واتساب: $_signUpNormalizedPhone',
                      'Step 3 of 3 • WhatsApp Verified: $_signUpNormalizedPhone',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _signUpLoading
                ? const Center(child: CircularProgressIndicator())
                : ProfileEditor(
                    submitLabel:
                        tr('إتمام التسجيل والبدء ✅', 'Complete Sign Up ✅'),
                    onSubmit: _handleSignUpComplete,
                  ),
          ),
        ],
      );
    }

    // الخطوة 2 من 3: تأكيد الرقم عبر رمز الواتساب (OTP)
    if (_signUpStep == 1) {
      final intlPhone =
          SettingsStore.phoneToWhatsAppIntl(_signUpNormalizedPhone ?? '');
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _signUpStep = 0;
                  _signUpError = null;
                }),
                tooltip: tr('تغيير الرقم', 'Change Number'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showWhatsAppGatewayDialog,
                icon: const Icon(Icons.settings_suggest_outlined,
                    size: 18, color: Color(0xFF128C7E)),
                label: Text(
                  tr('بوابة API', 'WhatsApp API'),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF128C7E)),
                ),
              ),
            ],
          ),
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFF25D366),
            child: Icon(Icons.chat_rounded, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            tr('تأكيد رقم الهاتف عبر واتساب', 'Verify Phone via WhatsApp'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'الخطوة 2 من 3: أرسلنا رمز تحقق مكوناً من 6 أرقام إلى واتساب الرقم\n+$intlPhone ($_signUpNormalizedPhone)',
              'Step 2 of 3: We sent a 6-digit verification code to WhatsApp\n+$intlPhone ($_signUpNormalizedPhone)',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // بطاقة معاينة إشعار رسالة الواتساب المرسلة مع زر تعبئة تلقائية وفتح واتساب
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCF8C6).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF25D366).withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mark_chat_unread_rounded,
                        color: Color(0xFF075E54), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sentViaCloudGateway
                            ? tr('تم الإرسال عبر بوابة واتساب السحابية 🟢',
                                'Sent via WhatsApp Cloud Gateway 🟢')
                            : tr('رسالة واتساب المرسلة إلى +$intlPhone 💬',
                                'WhatsApp Message to +$intlPhone 💬'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF075E54),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_whatsAppStatusNote != null)
                  Text(
                    _whatsAppStatusNote!,
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 20),
          TextField(
            controller: _signUpOtpCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              labelText: tr('رمز التحقق المكون من 6 أرقام',
                  '6-Digit Verification Code'),
              hintText: '••••••',
              prefixIcon:
                  const Icon(Icons.verified_user_outlined, color: Color(0xFF128C7E)),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _handleVerifyWhatsAppOtp(),
          ),
          if (_signUpError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 20, color: Colors.red.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _signUpError!,
                      style:
                          TextStyle(fontSize: 12.5, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _signUpLoading ? null : _handleVerifyWhatsAppOtp,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              tr('تأكيد الرمز والمتابعة للبيانات الشخصية ✅',
                  'Verify Code & Continue ✅'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _signUpLoading ? null : _resendWhatsAppOtp,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(tr('إعادة إرسال الرمز عبر واتساب',
                    'Resend Code via WhatsApp')),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _signUpStep = 0;
                  _signUpError = null;
                }),
                child: Text(tr('تعديل الرقم', 'Edit Number')),
              ),
            ],
          ),
        ],
      );
    }

    // الخطوة 1 من 3: إدخال رقم الهاتف وكلمة المرور وإرسال كود الواتساب
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        Icon(Icons.person_add_rounded,
            size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          tr('إنشاء حساب جديد في Open Mazad', 'Create New Account in Open Mazad'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          tr('الخطوة 1 من 3: أدخل رقم هاتفك العراقي لتأكيده برسالة عبر واتساب',
              'Step 1 of 3: Enter your Iraqi phone number to verify via WhatsApp'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _signUpPhoneCtrl,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'رقم الهاتف العراقي (المرتبط بواتساب)',
            hintText: '07701234567',
            prefixIcon: Icon(Icons.phone_android),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _signUpPassCtrl,
          obscureText: _signUpObscure,
          decoration: InputDecoration(
            labelText: tr('كلمة المرور (6 خانات على الأقل)',
                'Password (min 6 characters)'),
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_signUpObscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _signUpObscure = !_signUpObscure),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _signUpPassConfirmCtrl,
          obscureText: _signUpObscure,
          decoration: InputDecoration(
            labelText: tr('تأكيد كلمة المرور', 'Confirm Password'),
            prefixIcon: const Icon(Icons.lock_reset),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _handleSignUpStep1(),
        ),
        if (_signUpError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: Colors.red.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _signUpError!,
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _signUpLoading ? null : _handleSignUpStep1,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF128C7E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(14),
          ),
          icon: _signUpLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.chat_rounded),
          label: Text(
            tr('إرسال رمز التأكيد إلى واتساب 💬',
                'Send Verification Code to WhatsApp 💬'),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => _tabCtrl.animateTo(0),
            child: Text(tr('لديك حساب بالفعل؟ تسجيل الدخول',
                'Already have an account? Sign In')),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('الحساب وتسجيل الدخول', 'Account & Sign In')),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              icon: const Icon(Icons.login),
              text: tr('تسجيل الدخول', 'Sign In'),
            ),
            Tab(
              icon: const Icon(Icons.person_add),
              text: tr('حساب جديد', 'Create Account'),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildSignInTab(),
                _buildSignUpTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= نافذة إعدادات واختبار Meta WhatsApp Cloud API =======================

void showWhatsAppGatewayDialog(BuildContext context, [VoidCallback? onSaved]) {
  final urlCtrl = TextEditingController(
      text: SettingsStore.sanitizeMetaUrl(
          settings.whatsappApiUrl, settings.whatsappPhoneNumberId));
  final tokenCtrl = TextEditingController(text: settings.whatsappApiToken);
  final phoneIdCtrl =
      TextEditingController(text: settings.whatsappPhoneNumberId);
  final wabaIdCtrl = TextEditingController(text: settings.whatsappWabaId);
  final templateCtrl =
      TextEditingController(text: settings.whatsappTemplateName);
  final langCtrl = TextEditingController(text: settings.whatsappTemplateLang);
  final testPhoneCtrl = TextEditingController(
      text: settings.phone.isNotEmpty ? settings.phone : '07700000000');

  bool isTesting = false;
  String? testResult;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'بوابة Meta WhatsApp Cloud API الرسمية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified,
                          color: Color(0xFF128C7E), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم تفعيل الربط عبر Meta WhatsApp Cloud API (Graph API v21.0) باستخدام قوالب الرسائل المعتمدة (Template Message).',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF075E54)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'API Endpoint (Graph API v21.0)',
                    hintText:
                        'https://graph.facebook.com/v21.0/{Phone_ID}/messages',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneIdCtrl,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number ID',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          if (val.trim().isNotEmpty &&
                              urlCtrl.text.contains('graph.facebook.com')) {
                            urlCtrl.text =
                                'https://graph.facebook.com/v21.0/${val.trim()}/messages';
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: wabaIdCtrl,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'WABA ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tokenCtrl,
                  textDirection: TextDirection.ltr,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Bearer Access Token (Meta Graph API)',
                    hintText: 'EAAUiPWrVU9w...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: templateCtrl,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'اسم القالب (Template Name)',
                          hintText: 'otp أو hello_world',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: langCtrl,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'اللغة (Code)',
                          hintText: 'ar أو en_US',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'اختبار إرسال قالب تجريبي (Live Test):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: testPhoneCtrl,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف للتجربة (07XXXXXXXX)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF128C7E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      onPressed: isTesting
                          ? null
                          : () async {
                              setDialogState(() {
                                isTesting = true;
                                testResult = null;
                              });

                              // حفظ مؤقت لتجربة القيم المكتوبة حالياً
                              settings.saveWhatsAppGateway(
                                apiUrl: urlCtrl.text,
                                apiToken: tokenCtrl.text,
                                phoneNumberId: phoneIdCtrl.text,
                                wabaId: wabaIdCtrl.text,
                                templateName: templateCtrl.text,
                                templateLang: langCtrl.text,
                              );

                              final (success, note) =
                                  await settings.sendWhatsAppOtp(
                                phone07: testPhoneCtrl.text.trim(),
                                code: '123456',
                              );

                              setDialogState(() {
                                isTesting = false;
                                testResult = note;
                              });
                            },
                      icon: isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('اختبار'),
                    ),
                  ],
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: testResult!.contains('بنجاح')
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: testResult!.contains('بنجاح')
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Text(
                      testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: testResult!.contains('بنجاح')
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          FilledButton(
            onPressed: () {
              settings.saveWhatsAppGateway(
                apiUrl: urlCtrl.text,
                apiToken: tokenCtrl.text,
                phoneNumberId: phoneIdCtrl.text,
                wabaId: wabaIdCtrl.text,
                templateName: templateCtrl.text,
                templateLang: langCtrl.text,
              );
              Navigator.pop(ctx);
              onSaved?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'تم حفظ إعدادات Meta WhatsApp Cloud API بنجاح ✅'),
                ),
              );
            },
            child: const Text('حفظ الإعدادات'),
          ),
        ],
      ),
    ),
  );
}

