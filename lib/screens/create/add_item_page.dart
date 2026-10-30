part of '../../main.dart';

// ======================= صفحة إضافة سلعة للمزاد =======================

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final formKey = GlobalKey<FormState>();
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final areaCtrl = TextEditingController(text: 'المركز');
  final pinCtrl = TextEditingController();

  /// متحكمات الحقول الذكية المخصصة حسب الفئة
  final Map<String, TextEditingController> attrCtrls = {};

  String category = categories.first;
  String condition = conditions.first;
  String location = governorates.first;
  String deliveryMethod = deliveryMethods.first;
  int durationIndex = 3;
  int scheduleDelayIndex = 0; // 0: يبدأ فوراً, 1: بعد دقيقتين, 2: بعد ساعة, 3: غداً
  bool isPrivateAuction = false;
  bool enableLiveStream = false;

  final List<XFile> pickedImages = [];
  final picker = ImagePicker();

  static const durationLabels = [
    'دقيقتان (للتجربة)',
    'ساعة',
    '6 ساعات',
    'يوم',
    '3 أيام',
    'أسبوع',
  ];
  static const durationValues = [
    Duration(minutes: 2),
    Duration(hours: 1),
    Duration(hours: 6),
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
  ];

  static const scheduleLabels = [
    'يبدأ فوراً (الآن)',
    'بعد دقيقتين (للتجربة)',
    'بعد ساعة',
    'غداً',
  ];
  static const scheduleValues = [
    Duration.zero,
    Duration(minutes: 2),
    Duration(hours: 1),
    Duration(days: 1),
  ];

  @override
  void initState() {
    super.initState();
    if (settings.governorate.isNotEmpty) {
      location = settings.governorate;
    }
    _syncAttrControllers();
  }

  void _syncAttrControllers() {
    for (final label in dynamicFieldsForCategory(category)) {
      attrCtrls.putIfAbsent(label, () => TextEditingController());
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    areaCtrl.dispose();
    pinCtrl.dispose();
    for (final c in attrCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pickMultipleImages() async {
    try {
      final imgs = await picker.pickMultiImage(imageQuality: 85);
      if (imgs.isNotEmpty) {
        setState(() => pickedImages.addAll(imgs));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اختيار الصور: $e')),
        );
      }
    }
  }

  Future<void> pickFromCamera() async {
    try {
      final img =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (img != null) {
        setState(() => pickedImages.add(img));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التقاط الصورة: $e')),
        );
      }
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;

    final startPrice = int.parse(toLatinDigits(priceCtrl.text.trim()));
    if (isPrivateAuction && pinCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            tr('أدخل رمز PIN للمزاد الخاص', 'Enter a PIN for private auction')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final attrs = <String, String>{};
    for (final label in dynamicFieldsForCategory(category)) {
      final val = attrCtrls[label]?.text.trim() ?? '';
      if (val.isNotEmpty) attrs[label] = val;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final portableImages = <String>[];
    for (final x in pickedImages) {
      portableImages.add(await xFileToPortableImage(x));
    }

    store.addItem(
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim(),
      category: category,
      startPrice: startPrice,
      duration: durationValues[durationIndex],
      startDelay: scheduleValues[scheduleDelayIndex],
      condition: condition,
      location: location,
      area: areaCtrl.text.trim().isEmpty ? 'المركز' : areaCtrl.text.trim(),
      deliveryMethod: deliveryMethod,
      imagePaths: portableImages,
      attributes: attrs,
      pinCode: isPrivateAuction ? pinCtrl.text.trim() : null,
      isLiveStreaming: enableLiveStream,
    );

    if (!mounted) return;
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(scheduleDelayIndex == 0
            ? tr('تمت إضافة السلعة وبدأ المزاد بنجاح ✅',
                'Auction listed and started ✅')
            : tr('تمت جدولة المزاد في قسم "قريباً" بنجاح ⏳',
                'Auction scheduled in Upcoming ⏳')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDynamicFields = dynamicFieldsForCategory(category);

    return Scaffold(
      appBar:
          AppBar(title: Text(tr('إضافة إعلان مزاد جديد', 'Create New Auction'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // قسم إضافة الصور والكاميرا
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('صور السلعة (يدعم إضافة عدة صور أو التقاط بالكاميرا)',
                        'Item Photos (Multiple Photos or Camera)'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (pickedImages.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: pickedImages.length,
                        itemBuilder: (context, idx) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: buildSmartImage(
                                    pickedImages[idx].path,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () => setState(
                                      () => pickedImages.removeAt(idx)),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: pickMultipleImages,
                        icon: const Icon(Icons.photo_library_outlined,
                            size: 18),
                        label: Text(tr('إضافة عدة صور', 'Add Photos')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: pickFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: Text(tr('كاميرا', 'Camera')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // اختيار الفئة أولاً لتتغير الحقول الذكية تلقائياً
            Text(tr('الفئة (تتغير الحقول الذكية تلقائياً حسب اختيارك)', 'Category'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    avatar: Icon(categoryIcon(c), size: 16),
                    label: Text(c),
                    selected: category == c,
                    onSelected: (_) => setState(() {
                      category = c;
                      _syncAttrControllers();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: tr('عنوان الإعلان / اسم السلعة', 'Auction Title'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? tr('اكتب عنوان الإعلان', 'Enter title')
                  : null,
            ),
            const SizedBox(height: 12),

            // الحقول الذكية المخصصة للفئة المختارة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(categoryIcon(category),
                          size: 18, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Text(
                        '${tr("الحقول المخصصة لفئة:", "Dynamic Fields for:")} $category',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final fieldLabel in currentDynamicFields) ...[
                    TextFormField(
                      controller: attrCtrls[fieldLabel],
                      decoration: InputDecoration(
                        labelText: fieldLabel,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    tr('الوصف التفصيلي للسلعة', 'Detailed Description'),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText:
                    tr('سعر بداية المزاد (دينار)', 'Starting Price (IQD)'),
                helperText: tr(
                    'الزيادة مفتوحة للمزايدين بأي مبلغ أعلى من السعر الحالي',
                    'Open bidding increments above current price'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                final n = int.tryParse(toLatinDigits(v ?? ''));
                return (n == null || n <= 0)
                    ? tr('اكتب سعراً صحيحاً', 'Enter a valid price')
                    : null;
              },
            ),
            const SizedBox(height: 16),

            // الموقع وطريقة التسليم
            Text(tr('الموقع وطريقة التسليم', 'Location & Delivery Method'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: location,
                    decoration: InputDecoration(
                      labelText: tr('المحافظة', 'Governorate'),
                      border: const OutlineInputBorder(),
                    ),
                    items: governorates
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => location = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: areaCtrl,
                    decoration: InputDecoration(
                      labelText: tr('المنطقة / القضاء', 'Area / District'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final dm in deliveryMethods)
                  ChoiceChip(
                    avatar: const Icon(Icons.local_shipping_outlined, size: 16),
                    label: Text(dm),
                    selected: deliveryMethod == dm,
                    onSelected: (_) => setState(() => deliveryMethod = dm),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Text(tr('حالة السلعة', 'Condition'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final cond in conditions)
                  ChoiceChip(
                    label: Text(cond),
                    selected: condition == cond,
                    onSelected: (_) => setState(() => condition = cond),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // وقت انطلاق المزاد (فوري أو مجدول)
            Text(tr('موعد بدء المزاد (المزادات المجدولة)', 'Auction Start Time'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < scheduleLabels.length; i++)
                  ChoiceChip(
                    avatar: Icon(
                        i == 0 ? Icons.bolt : Icons.schedule, size: 16),
                    label: Text(scheduleLabels[i]),
                    selected: scheduleDelayIndex == i,
                    onSelected: (_) => setState(() => scheduleDelayIndex = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Text(tr('مدة المزاد', 'Auction Duration'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < durationLabels.length; i++)
                  ChoiceChip(
                    label: Text(durationLabels[i]),
                    selected: durationIndex == i,
                    onSelected: (_) => setState(() => durationIndex = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // المزادات الخاصة برمز PIN + البث المباشر
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.lock, color: Colors.amber),
                      title: Text(tr('مزاد خاص مغلق برمز سري (PIN Code)',
                          'Private Auction Room (PIN Code)')),
                      subtitle: Text(tr(
                          'لا يزايد فيه إلا من يملك رمز PIN أو رابط الدعوة',
                          'Only users with the PIN code can enter and bid')),
                      value: isPrivateAuction,
                      onChanged: (v) => setState(() => isPrivateAuction = v),
                    ),
                    if (isPrivateAuction)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: TextFormField(
                          controller: pinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                tr('رمز الدخول السري (مثال: 1234)', 'PIN Code'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.key),
                          ),
                        ),
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.videocam, color: Colors.red),
                      title: Text(tr('تفعيل غرفة البث المباشر للمزاد 🔴',
                          'Enable Live Stream Broadcast 🔴')),
                      subtitle: Text(tr(
                          'يتيح لك فتح الكاميرا وعرض السلعة مباشرة مع المزايدات الحية',
                          'Broadcast live video with real-time bidding overlay')),
                      value: enableLiveStream,
                      onChanged: (v) => setState(() => enableLiveStream = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: save,
              icon: const Icon(Icons.gavel),
              label: Text(
                scheduleDelayIndex == 0
                    ? tr('انشر وابدأ المزاد الآن', 'Publish & Start Auction')
                    : tr('جدولة المزاد في قسم "قريباً" ⏳',
                        'Schedule Auction ⏳'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  ),
);
}
}
