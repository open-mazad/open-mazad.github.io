part of '../../main.dart';

// ======================= صفحة إضافة / تعديل إعلان مزاد =======================

class AddItemPage extends StatefulWidget {
  final Item? itemToEdit;
  const AddItemPage({super.key, this.itemToEdit});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final formKey = GlobalKey<FormState>();
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final buyNowPriceCtrl = TextEditingController();
  final areaCtrl = TextEditingController(text: 'المركز');
  final pinCtrl = TextEditingController();
  final additionalInfoCtrl = TextEditingController();

  /// متحكمات الحقول الذكية المخصصة حسب الفئة
  final Map<String, TextEditingController> attrCtrls = {};

  String category = '';
  String condition = conditions.first;
  String location = governorates.first;
  String district = 'المركز';
  String deliveryMethod = deliveryMethods.first;
  int durationIndex = 3;
  int scheduleDelayIndex = 0; // 0: يبدأ فوراً, 1: بعد دقيقتين, 2: بعد ساعة, 3: غداً
  bool isPrivateAuction = false;

  final List<XFile> pickedImages = [];
  final List<String> existingImages = [];
  final picker = ImagePicker();

  bool _autoValidate = false;
  bool _hasImageError = false;
  bool _hasCategoryError = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _imagesSectionKey = GlobalKey();
  final GlobalKey _categorySectionKey = GlobalKey();
  final GlobalKey _titleSectionKey = GlobalKey();
  final GlobalKey _descSectionKey = GlobalKey();
  final GlobalKey _priceSectionKey = GlobalKey();

  DateTime? _lastWarningBannerTime;
  static const Duration _bannerCooldown = Duration(seconds: 5);

  bool get isEditing => widget.itemToEdit != null;
  /// المزاد المنشور (سواء كان جارياً أو مجدولاً): قفل الحقول الحساسة مع السماح بإضافة صور جديدة وتعديل العنوان والفئة
  bool get isPublished => isEditing;

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
    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      titleCtrl.text = item.title;
      descCtrl.text = item.description;
      priceCtrl.text = '${item.startPrice}';
      if (item.buyNowPrice != null && item.buyNowPrice! > 0) {
        buyNowPriceCtrl.text = '${item.buyNowPrice}';
      }
      category = categories.contains(item.category) ? item.category : categories.first;
      condition = conditions.contains(item.condition) ? item.condition : conditions.first;
      location = governorates.contains(item.location) ? item.location : governorates.first;
      final currentDistricts = districtsForGovernorate(location);
      district = item.area.isNotEmpty ? item.area : currentDistricts.first;
      if (!currentDistricts.contains(district)) {
        district = currentDistricts.first;
      }
      areaCtrl.text = district;
      deliveryMethod = deliveryMethods.contains(item.deliveryMethod)
          ? item.deliveryMethod
          : deliveryMethods.first;
      pinCtrl.text = item.pinCode ?? '';
      isPrivateAuction = item.pinCode != null && item.pinCode!.isNotEmpty;
      existingImages.addAll(item.imagePaths);

      for (final e in item.attributes.entries) {
        attrCtrls[e.key] = TextEditingController(text: e.value);
      }
    } else {
      if (settings.governorate.isNotEmpty) {
        location = settings.governorate;
      }
      final currentDistricts = districtsForGovernorate(location);
      if (settings.district.isNotEmpty && currentDistricts.contains(settings.district)) {
        district = settings.district;
      } else {
        district = currentDistricts.first;
      }
      areaCtrl.text = district;
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
    _scrollController.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    buyNowPriceCtrl.dispose();
    areaCtrl.dispose();
    pinCtrl.dispose();
    additionalInfoCtrl.dispose();
    for (final c in attrCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _scrollToFirstError(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  Future<void> pickMultipleImages() async {
    final currentCount = pickedImages.length + existingImages.length;
    if (currentCount >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('الحد الأقصى للصور هو 12 صورة لكل مزاد ⚠️', 'Maximum 12 photos per auction ⚠️')),
      ));
      return;
    }
    try {
      final imgs = await picker.pickMultiImage(imageQuality: 85);
      if (imgs.isNotEmpty) {
        final remainingSlots = 12 - currentCount;
        final toAdd = imgs.take(remainingSlots).toList();
        if (imgs.length > remainingSlots && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('تمت إضافة أول $remainingSlots صور للوصول للحد الأقصى (12 صورة)', 'Added first $remainingSlots photos (max 12)')),
          ));
        }
        setState(() {
          pickedImages.addAll(toAdd);
          _hasImageError = false;
        });
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
    final currentCount = pickedImages.length + existingImages.length;
    if (currentCount >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('الحد الأقصى للصور هو 12 صورة لكل مزاد ⚠️', 'Maximum 12 photos per auction ⚠️')),
      ));
      return;
    }
    try {
      final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (img != null) {
        setState(() {
          pickedImages.add(img);
          _hasImageError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التقاط الصورة: $e')),
        );
      }
    }
  }

  void _showCategoryPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(
                    tr('اختر فئة السلعة', 'Select Category'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: categories.length,
                itemBuilder: (ctx, idx) {
                  final cat = categories[idx];
                  final isSelected = category == cat;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        category = cat;
                        _hasCategoryError = false;
                        _syncAttrControllers();
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.indigo.shade50
                            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.indigo : Colors.grey.withValues(alpha: 0.25),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            categoryIcon(cat),
                            size: 20,
                            color: isSelected ? Colors.indigo : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.indigo : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, size: 16, color: Colors.indigo),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> save() async {
    if (!settings.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('يرجى تسجيل الدخول أولاً للتمكن من إدارة المزاد ⚠️',
            'Please sign in first ⚠️')),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (settings.needsProfileOnboarding) {
      await showCompleteProfileDialog(context);
      if (!mounted || settings.needsProfileOnboarding) return;
    }

    // التحقق من الحقول الإلزامية وعرض التنبيهات الحمراء أسفل كل حقل
    final totalImages = pickedImages.length + existingImages.length;
    final hasImg = totalImages > 0;
    final hasCategory = category.trim().isNotEmpty;

    setState(() {
      _autoValidate = true;
      _hasImageError = !hasImg;
      _hasCategoryError = !hasCategory;
    });

    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid || !hasImg || !hasCategory) {
      // 1. التمرير السلس لنقل التركيز إلى أول حقل غير مستوفٍ للشروط
      if (!hasImg) {
        _scrollToFirstError(_imagesSectionKey);
      } else if (!hasCategory) {
        _scrollToFirstError(_categorySectionKey);
      } else if (titleCtrl.text.trim().isEmpty) {
        _scrollToFirstError(_titleSectionKey);
      } else if (descCtrl.text.trim().isEmpty) {
        _scrollToFirstError(_descSectionKey);
      } else if (priceCtrl.text.trim().isEmpty || (int.tryParse(toLatinDigits(priceCtrl.text).replaceAll(',', '').trim()) ?? 0) <= 0) {
        _scrollToFirstError(_priceSectionKey);
      }

      // 2. إظهار الإشعار العام بأعلى الشاشة حصراً مع تفعيل فاصل زمني (Cooldown/Throttle 5 ثوانٍ) لمنع التكرار
      final now = DateTime.now();
      if (_lastWarningBannerTime == null || now.difference(_lastWarningBannerTime!) >= _bannerCooldown) {
        _lastWarningBannerTime = now;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(
                      'يرجى استيفاء كافة الحقول المطلوبة المحددة باللون الأحمر ⚠️',
                      'Please complete all required fields in red ⚠️',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 130,
              right: 16,
              left: 16,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final priceStr = toLatinDigits(priceCtrl.text.trim()).replaceAll(',', '');
    final startPrice = int.tryParse(priceStr) ?? 0;

    final buyNowStr = toLatinDigits(buyNowPriceCtrl.text.trim()).replaceAll(',', '');
    final buyNowPrice = buyNowStr.isNotEmpty ? int.tryParse(buyNowStr) : null;

    final attrs = <String, String>{};
    for (final label in dynamicFieldsForCategory(category)) {
      final val = attrCtrls[label]?.text.trim() ?? '';
      if (val.isNotEmpty) attrs[label] = val;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final portableImages = <String>[...existingImages];
    for (final x in pickedImages) {
      portableImages.add(await xFileToPortableImage(x));
    }

    if (isEditing) {
      // تعديل المزاد: الحقول القابلة للتعديل هي (الصور الإضافية حتى 12، عنوان الإعلان، وإدارة الغرفة المقفولة PIN)
      // والحقول المقفلة تشغيلياً (الفئة، الوصف، السعر، الموقع، خيارات التسليم) تبقى ثابتة
      final originalItem = widget.itemToEdit!;
      await store.updateItemDetails(
        item: originalItem,
        title: titleCtrl.text.trim(),
        description: originalItem.description,
        startPrice: originalItem.startPrice,
        location: originalItem.location,
        condition: originalItem.condition,
        category: originalItem.category,
        area: originalItem.area,
        deliveryMethod: originalItem.deliveryMethod,
        imagePaths: portableImages,
        attributes: originalItem.attributes,
        pinCode: isPrivateAuction ? pinCtrl.text.trim() : null,
        buyNowPrice: originalItem.buyNowPrice,
      );

      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('تم حفظ تعديلات المزاد بنجاح ✅',
              'Auction details updated successfully ✅')),
          backgroundColor: Colors.teal.shade800,
        ),
      );
    } else {
      // إضافة إعلان جديد
      store.addItem(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        category: category,
        startPrice: startPrice,
        duration: durationValues[durationIndex],
        startDelay: scheduleValues[scheduleDelayIndex],
        condition: condition,
        location: location,
        area: district.isNotEmpty ? district : (areaCtrl.text.trim().isEmpty ? 'المركز' : areaCtrl.text.trim()),
        deliveryMethod: deliveryMethod,
        imagePaths: portableImages,
        attributes: attrs,
        pinCode: isPrivateAuction ? pinCtrl.text.trim() : null,
        buyNowPrice: buyNowPrice,
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
  }

  @override
  Widget build(BuildContext context) {
    final currentDynamicFields = dynamicFieldsForCategory(category);
    final totalImagesCount = pickedImages.length + existingImages.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('المزاد المفتوح', 'Open Mazad')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: formKey,
            autovalidateMode: _autoValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // في حالة تعديل المزاد: تنبيه بالصلاحيات المتاحة
                if (isEditing) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade700, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade900, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('صلاحيات تعديل المزاد 🔒', 'Auction Edit Permissions 🔒'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr(
                                  'لحماية حقوق ومصداقية المزايدات: يمكنك إضافة صور جديدة (حتى 12 صورة)، تعديل عنوان الإعلان، وإدارة رمز الدخول السري (PIN)، مع قفل باقي الحقول كالسعر والموقع وتصنيف الفئة.',
                                  'You can add new photos (up to 12), update title, and manage PIN room. Core fields and category remain locked.',
                                ),
                                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.blue.shade900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1. قسم صور السلعة في الأعلى مع حد بصري فاصل تحته
                Container(
                  key: _imagesSectionKey,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasImageError
                          ? Colors.red.shade400
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: _hasImageError ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, size: 20, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Text(
                            tr('صور السلعة (المعرض والكاميرا) *', 'Item Photos *'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          Text(
                            '$totalImagesCount ${tr("صور", "photos")}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (existingImages.isNotEmpty || pickedImages.isNotEmpty)
                        SizedBox(
                          height: 105,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (int i = 0; i < existingImages.length; i++)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: buildSmartImage(
                                            existingImages[i],
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      if (!isPublished)
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: InkWell(
                                            onTap: () => setState(() => existingImages.removeAt(i)),
                                            child: const CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.black54,
                                              child: Icon(Icons.close, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              for (int i = 0; i < pickedImages.length; i++)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: buildSmartImage(
                                            pickedImages[i].path,
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
                                          onTap: () => setState(() => pickedImages.removeAt(i)),
                                          child: const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.black54,
                                            child: Icon(Icons.close, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (totalImagesCount < 12) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: pickMultipleImages,
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
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
                      if (_hasImageError) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr('يرجى إضافة صورة واحدة على الأقل للسلعة لمعاينتها 📸',
                              'Please add at least one photo 📸'),
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // الحد البصري الفاصل تحت قسم صور السلعة
                const SizedBox(height: 12),
                Divider(
                  thickness: 1.5,
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),

                // 2. اختيار الفئة عبر نافذة منبثقة (Popup / Modal)
                Container(
                  key: _categorySectionKey,
                  decoration: BoxDecoration(
                    color: isEditing
                        ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
                        : (_hasCategoryError
                            ? Colors.red.withValues(alpha: 0.05)
                            : Theme.of(context).colorScheme.surfaceContainerLow),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasCategoryError
                          ? Colors.red.shade600
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: _hasCategoryError ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('تصنيف الفئة *', 'Category *'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _hasCategoryError ? Colors.red.shade700 : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: isEditing ? null : () => _showCategoryPickerModal(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isEditing
                                ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: category.isEmpty ? Colors.grey.shade400 : Colors.indigo.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: category.isEmpty ? Colors.grey.withValues(alpha: 0.1) : Colors.indigo.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  category.isEmpty ? Icons.category_outlined : categoryIcon(category),
                                  color: category.isEmpty ? Colors.grey.shade700 : Colors.indigo,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.isEmpty
                                          ? tr('تصنيف السلعة', 'Item Category')
                                          : tr('الفئة المحددة', 'Selected Category'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      category.isEmpty ? tr('اختر التصنيف', 'Select Category') : category,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: category.isEmpty ? FontWeight.normal : FontWeight.bold,
                                        color: category.isEmpty
                                            ? Colors.grey.shade600
                                            : Colors.indigo,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isEditing)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        tr('مقفول', 'Locked'),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: category.isEmpty ? Colors.grey.withValues(alpha: 0.15) : Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        category.isEmpty ? tr('اختر', 'Choose') : tr('تغيير التصنيف', 'Change'),
                                        style: TextStyle(
                                          color: category.isEmpty ? Theme.of(context).colorScheme.onSurface : Colors.indigo,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 18,
                                        color: category.isEmpty ? Theme.of(context).colorScheme.onSurface : Colors.indigo,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_hasCategoryError) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr('يرجى اختيار تصنيف السلعة قبل النشر *', 'Please select a category before publishing *'),
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. كتلة عنوان الإعلان
                Card(
                  key: _titleSectionKey,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('عنوان الإعلان / اسم السلعة *', 'Auction Title *'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: titleCtrl,
                          enabled: true, // عنوان الإعلان متاح للتعديل دائماً
                          decoration: InputDecoration(
                            hintText: tr('مثال: آيفون 15 برو ماكس 256GB بحالة الوكالة', 'e.g. iPhone 15 Pro Max'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.title),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? tr('يرجى كتابة عنوان الإعلان', 'Please enter auction title')
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. كتلة التفاصيل والوصف + الحقول الذكية المرتبطة بالفئة
                Card(
                  key: _descSectionKey,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('تفاصيل ووصف السلعة *', 'Item Description *'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: descCtrl,
                          enabled: !isPublished,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: tr('اكتب وصفاً مفصلاً ودقيقاً عن حالة السلعة والمرفقات...',
                                'Describe the item details...'),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? tr('يرجى كتابة تفاصيل ووصف السلعة', 'Please enter item description')
                              : null,
                        ),
                        if (currentDynamicFields.isNotEmpty) ...[
                          const SizedBox(height: 14),
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
                                    Icon(categoryIcon(category), size: 18, color: Colors.indigo),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${tr("الحقول الذكية التلقائية لفئة:", "Smart Fields for:")} $category',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                for (final fieldLabel in currentDynamicFields) ...[
                                  TextFormField(
                                    controller: attrCtrls[fieldLabel],
                                    enabled: !isPublished,
                                    decoration: InputDecoration(
                                      labelText: fieldLabel,
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      filled: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. كتلة السعر
                Card(
                  key: _priceSectionKey,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('سعر بداية المزاد (دينار عراقي) *', 'Starting Price (IQD) *'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: priceCtrl,
                          enabled: !isPublished,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: tr('السعر الافتتاحي للمزاد *', 'Starting Price *'),
                            helperText: tr(
                              'حقل إلزامي: الزيادة مفتوحة للمزايدين بأي مبلغ أعلى من هذا السعر',
                              'Mandatory: Bidders can increase above this starting price',
                            ),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.payments_outlined),
                          ),
                          validator: (v) {
                            final clean = toLatinDigits(v ?? '').replaceAll(',', '').trim();
                            if (clean.isEmpty) {
                              return tr('يرجى إدخال سعر بداية المزاد', 'Please enter starting price');
                            }
                            final n = int.tryParse(clean);
                            if (n == null || n <= 0) {
                              return tr('يرجى كتابة سعر صحيح أكبر من صفر', 'Please enter a valid price > 0');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('السعر النهائي / سعر الشراء الفوري (اختياري)', 'Final Price / Buy Now Price (Optional)'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: buyNowPriceCtrl,
                          enabled: !isPublished,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: tr('سعر الشراء الفوري (اختياري)', 'Buy Now Price (Optional)'),
                            helperText: tr(
                              'اختياري: يتيح للمشتري حسم الصفقة فوراً والشراء بهذا السعر دون انتظار نهاية المزاد',
                              'Optional: lets a buyer win immediately at this price',
                            ),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.flash_on_outlined, color: Colors.amber),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final clean = toLatinDigits(v).replaceAll(',', '').trim();
                            final n = int.tryParse(clean);
                            if (n == null || n <= 0) {
                              return tr('يرجى كتابة سعر صحيح أكبر من صفر', 'Enter valid number > 0');
                            }
                            final startClean = toLatinDigits(priceCtrl.text).replaceAll(',', '').trim();
                            final start = int.tryParse(startClean) ?? 0;
                            if (start > 0 && n <= start) {
                              return tr('يجب أن يكون سعر الشراء الفوري أعلى من سعر بداية المزاد',
                                  'Buy now price must be higher than start price');
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 6. كتلة خيارات التسليم والموقع
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('الموقع وخيارات التسليم *', 'Location & Delivery *'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: governorates.contains(location) ? location : governorates.first,
                                decoration: InputDecoration(
                                  labelText: tr('المحافظة *', 'Governorate *'),
                                  border: const OutlineInputBorder(),
                                ),
                                items: governorates
                                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                    .toList(),
                                onChanged: isPublished
                                    ? null
                                    : (v) {
                                        if (v != null) {
                                          setState(() {
                                            location = v;
                                            final available = districtsForGovernorate(location);
                                            if (!available.contains(district)) {
                                              district = available.first;
                                            }
                                            areaCtrl.text = district;
                                          });
                                        }
                                      },
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? tr('يرجى اختيار المحافظة', 'Select governorate')
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('district_$location'),
                                initialValue: districtsForGovernorate(location).contains(district)
                                    ? district
                                    : districtsForGovernorate(location).first,
                                decoration: InputDecoration(
                                  labelText: tr('القضاء *', 'District *'),
                                  border: const OutlineInputBorder(),
                                ),
                                items: districtsForGovernorate(location)
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                    .toList(),
                                onChanged: isPublished
                                    ? null
                                    : (v) {
                                        if (v != null) {
                                          setState(() {
                                            district = v;
                                            areaCtrl.text = v;
                                          });
                                        }
                                      },
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? tr('يرجى اختيار القضاء', 'Select district')
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('طريقة التسليم المعتمدة', 'Delivery Method'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final dm in deliveryMethods)
                              ChoiceChip(
                                avatar: const Icon(Icons.local_shipping_outlined, size: 16),
                                label: Text(dm),
                                selected: deliveryMethod == dm,
                                onSelected: isPublished
                                    ? null
                                    : (_) => setState(() => deliveryMethod = dm),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 7. كتلة حالة السلعة
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('حالة السلعة *', 'Condition *'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final cond in conditions)
                              ChoiceChip(
                                label: Text(cond),
                                selected: condition == cond,
                                onSelected: isPublished
                                    ? null
                                    : (_) => setState(() => condition = cond),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 8. كتلة موعد وتوقيت المزاد
                if (!isPublished) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('موعد انطلاق المزاد', 'Auction Start Time'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < scheduleLabels.length; i++)
                                ChoiceChip(
                                  avatar: Icon(
                                    i == 0 ? Icons.bolt : Icons.schedule,
                                    size: 16,
                                  ),
                                  label: Text(scheduleLabels[i]),
                                  selected: scheduleDelayIndex == i,
                                  onSelected: (_) => setState(() => scheduleDelayIndex = i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            tr('مدة المزاد', 'Auction Duration'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < durationLabels.length; i++)
                                ChoiceChip(
                                  label: Text(durationLabels[i]),
                                  selected: durationIndex == i,
                                  onSelected: (_) => setState(() => durationIndex = i),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 9. كتلة الخيارات الخاصة (مزاد خاص برمز PIN)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.lock_outline, color: Colors.amber),
                          title: Text(
                            tr('مزاد خاص مغلق برمز سري (PIN Code)', 'Private Auction Room (PIN Code)'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            tr('لا يزايد فيه إلا من يملك رمز PIN أو رابط الدعوة',
                                'Only users with the PIN code can enter and bid'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: isPrivateAuction,
                          onChanged: (v) => setState(() => isPrivateAuction = v),
                        ),
                        if (isPrivateAuction)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: TextFormField(
                              controller: pinCtrl,
                              enabled: true, // إمكانية تعيين وتغيير رمز PIN حتى عند تعديل المزاد
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: tr('رمز الدخول السري (PIN Code) *', 'PIN Code *'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.key),
                              ),
                              validator: (v) => (isPrivateAuction && (v == null || v.trim().isEmpty))
                                  ? tr('يرجى إدخال رمز PIN للمزاد الخاص', 'Enter PIN code')
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // زر الإرسال / النشر / الحفظ
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: save,
                  icon: Icon(isEditing ? Icons.save : Icons.gavel),
                  label: Text(
                    isEditing
                        ? tr('حفظ تعديلات المزاد', 'Save Auction Changes')
                        : scheduleDelayIndex == 0
                            ? tr('انشر وابدأ المزاد الآن', 'Publish & Start Auction')
                            : tr('جدولة المزاد في قسم "قريباً" ⏳', 'Schedule Auction ⏳'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
