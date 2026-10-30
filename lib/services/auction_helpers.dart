import 'package:flutter/material.dart';
import '../settings_page.dart';

const categories = [
  'عقارات',
  'سيارات ومركبات',
  'مقتنيات نادرة',
  'أرقام مميزة',
  'إلكترونيات وأجهزة',
  'إكسسوارات وساعات',
  'أثاث ومنزل',
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
      return ['المساحة (م²)', 'المنطقة / الحي', 'نوع الطابو'];
    case 'سيارات ومركبات':
      return ['الموديل وسنة الصنع', 'الممشى (كم)', 'حالة البدي والمحرك'];
    case 'مقتنيات نادرة':
      return ['العمر / الحقبة الزمنية', 'شهادة الأصالة / المصدر', 'درجة الندرة'];
    case 'أرقام مميزة':
      return ['نوع الرقم (هاتف / لوحة مركبة)', 'الفئة أو الشبكة', 'آلية التحويل'];
    case 'إلكترونيات وأجهزة':
      return ['الماركة والموديل', 'السعة / المواصفات', 'حالة الضمان والملحقات'];
    case 'إكسسوارات وساعات':
      return ['الماركة', 'المعدن / الخامة', 'العلبة والملحقات'];
    case 'أثاث ومنزل':
      return ['الأبعاد / القياس', 'الخامة / الخشب', 'عدد القطع'];
    default:
      return ['النوع / الماركة', 'مواصفات إضافية'];
  }
}

IconData categoryIcon(String c) {
  switch (c) {
    case 'عقارات':
      return Icons.apartment;
    case 'سيارات ومركبات':
      return Icons.directions_car;
    case 'مقتنيات نادرة':
      return Icons.diamond_outlined;
    case 'أرقام مميزة':
      return Icons.pin_outlined;
    case 'إلكترونيات وأجهزة':
      return Icons.devices;
    case 'إكسسوارات وساعات':
      return Icons.watch;
    case 'أثاث ومنزل':
      return Icons.chair;
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
