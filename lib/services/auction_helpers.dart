import 'package:flutter/material.dart';
import '../settings_page.dart';

const categories = [
  'عقارات وأراضي',
  'سيارات ومركبات',
  'هواتف وأجهزة ذكية',
  'إلكترونيات وأجهزة',
  'إكسسوارات وساعات',
  'ذهب ومجوهرات',
  'أرقام مميزة',
  'أثاث وديكور منزلي',
  'أجهزة كهربائية ومنزلية',
  'طيور وحيوانات أليفة',
  'معدات وآليات صناعية',
  'مقتنيات وتحف نادرة',
  'أزياء وحقائب وأحذية',
  'ألعاب فيديو وترفيه',
  'مواشي وأغنام',
  'أخرى',
];

const conditions = [
  'جديد بالكرتون',
  'شبه جديد',
  'مستعمل بحالة ممتازة',
  'مستعمل بحالة مقبولة',
];

const deliveryMethods = [
  'استلام باليد',
  'توصيل على حساب البائع',
  'شحن على حساب المشتري',
];

/// الحقول الذكية المخصصة لكل فئة
List<String> dynamicFieldsForCategory(String cat) {
  switch (cat) {
    case 'عقارات':
    case 'عقارات وأراضي':
      return ['المساحة (م²)', 'المنطقة / الحي', 'نوع الطابو'];
    case 'سيارات ومركبات':
      return ['الموديل وسنة الصنع', 'الممشى (كم)', 'حالة البدي والمحرك'];
    case 'هواتف وأجهزة ذكية':
      return ['الماركة والموديل', 'السعة والذاكرة', 'صحة البطارية والملحقات'];
    case 'إلكترونيات وأجهزة':
    case 'إلكترونيات وكمبيوتر':
      return ['الماركة والموديل', 'المواصفات والمعالج', 'حالة الضمان والملحقات'];
    case 'إكسسوارات وساعات':
      return ['الماركة', 'المعدن / الخامة', 'العلبة والشهادة'];
    case 'ذهب ومجوهرات':
      return ['العيار (18/21/24)', 'الوزن التقريبي (غرام)', 'شهادة الفحص / الفاتورة'];
    case 'أرقام مميزة':
      return ['نوع الرقم (هاتف / لوحة مركبة)', 'الشبكة أو الفئة', 'آلية التحويل'];
    case 'أثاث ومنزل':
    case 'أثاث وديكور منزلي':
      return ['الأبعاد / القياس', 'الخامة / نوع الخشب', 'عدد القطع'];
    case 'أجهزة كهربائية ومنزلية':
      return ['نوع الجهاز والماركة', 'فترة الاستخدام', 'حالة العمل والضمان'];
    case 'طيور وحيوانات أليفة':
      return ['النوع والسلالة', 'العمر واللقاحات', 'الملحقات والقفص'];
    case 'معدات وآليات صناعية':
      return ['النوع والموديل', 'ساعات العمل / القدرة', 'بلد الصنع والحالة'];
    case 'مقتنيات نادرة':
    case 'مقتنيات وتحف نادرة':
      return ['العمر / الحقبة الزمنية', 'شهادة الأصالة / المصدر', 'درجة الندرة'];
    case 'أزياء وحقائب وأحذية':
      return ['الماركة الأصلية', 'المقاس / القياس', 'الحالة والملحقات'];
    case 'ألعاب فيديو وترفيه':
      return ['نوع الجهاز (PS5/Xbox/PC)', 'السعة والملحقات', 'الألعاب المرفقة'];
    case 'مواشي وأغنام':
      return ['النوع (أغنام/أبقار/خيول)', 'العدد والوزن التقريبي', 'العمر والحالة الصحية'];
    default:
      return ['النوع / الماركة', 'مواصفات إضافية'];
  }
}

IconData categoryIcon(String c) {
  switch (c) {
    case 'عقارات':
    case 'عقارات وأراضي':
      return Icons.apartment;
    case 'سيارات ومركبات':
      return Icons.directions_car;
    case 'هواتف وأجهزة ذكية':
      return Icons.phone_iphone;
    case 'إلكترونيات وأجهزة':
    case 'إلكترونيات وكمبيوتر':
      return Icons.devices;
    case 'إكسسوارات وساعات':
      return Icons.watch;
    case 'ذهب ومجوهرات':
      return Icons.diamond_outlined;
    case 'أرقام مميزة':
      return Icons.pin_outlined;
    case 'أثاث ومنزل':
    case 'أثاث وديكور منزلي':
      return Icons.chair;
    case 'أجهزة كهربائية ومنزلية':
      return Icons.kitchen;
    case 'طيور وحيوانات أليفة':
      return Icons.pets;
    case 'معدات وآليات صناعية':
      return Icons.precision_manufacturing;
    case 'مقتنيات نادرة':
    case 'مقتنيات وتحف نادرة':
      return Icons.history_edu;
    case 'أزياء وحقائب وأحذية':
      return Icons.checkroom;
    case 'ألعاب فيديو وترفيه':
      return Icons.sports_esports;
    case 'مواشي وأغنام':
      return Icons.agriculture;
    default:
      return Icons.sell;
  }
}

String formatPrice(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$buf ${tr("دينار", "IQD")}';
}

String formatDuration(Duration d) {
  if (d.inSeconds <= 0) return tr('انتهى', 'Ended');
  if (d.inDays >= 1) {
    return tr('${d.inDays} يوم و ${d.inHours % 24} س',
        '${d.inDays}d ${d.inHours % 24}h');
  }
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

String ago(DateTime t) {
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return tr('الآن', 'Just now');
  if (d.inHours < 1) {
    return tr('منذ ${d.inMinutes} دقيقة', '${d.inMinutes}m ago');
  }
  if (d.inDays < 1) return tr('منذ ${d.inHours} ساعة', '${d.inHours}h ago');
  return tr('منذ ${d.inDays} يوم', '${d.inDays}d ago');
}

/// يحوّل التاريخ إلى صيغة UTC ISO متوافقة تماماً مع خوادم Supabase لتفادي مشكلة فرق الساعات (توقيت العراق UTC+3)
String toIsoUtc(DateTime dt) => dt.toUtc().toIso8601String();

/// يقرأ التاريخ من Supabase ويحوّله فوراً إلى التوقيت المحلي للمستخدم
DateTime parseToLocal(dynamic val, {DateTime? fallback}) {
  if (val == null) return fallback ?? DateTime.now();
  final str = '$val'.trim();
  if (str.isEmpty) return fallback ?? DateTime.now();
  final parsed = DateTime.tryParse(str);
  if (parsed == null) return fallback ?? DateTime.now();
  return parsed.toLocal();
}
