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
  int scheduleDelayHours = 0; // 0: يبدأ فوراً (الآن)
  int durationDays = 1; // 0 إلى 7 أيام
  int durationHours = 0; // 0 إلى 23 ساعة
  bool isPrivateAuction = false;

  final List<XFile> pickedImages = [];
  final List<String> existingImages = [];
  final picker = ImagePicker();

  bool _autoValidate = false;
  bool _hasImageError = false;
  bool _hasCategoryError = false;
  bool _hasTitleError = false;
  bool _hasDescError = false;
  bool _hasPriceError = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _imagesSectionKey = GlobalKey();
  final GlobalKey _categorySectionKey = GlobalKey();
  final GlobalKey _titleSectionKey = GlobalKey();
  final GlobalKey _descSectionKey = GlobalKey();
  final GlobalKey _priceSectionKey = GlobalKey();

  bool get isEditing => widget.itemToEdit != null;
  /// المزاد المنشور (سواء كان جارياً أو مجدولاً): قفل الحقول الحساسة مع السماح بإضافة صور جديدة وتعديل العنوان والفئة
  bool get isPublished => isEditing;

  static const List<MapEntry<int, String>> scheduleOptions = [
    MapEntry(0, 'يبدأ فوراً (الآن) ⚡'),
    MapEntry(1, 'بعد ساعة واحدة'),
    MapEntry(2, 'بعد ساعتين'),
    MapEntry(4, 'بعد 4 ساعات'),
    MapEntry(6, 'بعد 6 ساعات'),
    MapEntry(12, 'بعد 12 ساعة'),
    MapEntry(24, 'غداً (بعد 24 ساعة)'),
    MapEntry(48, 'بعد يومين (48 ساعة)'),
    MapEntry(72, 'بعد 3 أيام'),
    MapEntry(96, 'بعد 4 أيام'),
    MapEntry(120, 'بعد 5 أيام'),
    MapEntry(144, 'بعد 6 أيام'),
    MapEntry(168, 'بعد أسبوع (7 أيام - الحد الأقصى)'),
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
        if (e.key.startsWith('_') || e.key.toLowerCase().contains('buy_now_price')) continue;
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

    titleCtrl.addListener(() {
      if (_hasTitleError && titleCtrl.text.trim().isNotEmpty) {
        setState(() => _hasTitleError = false);
      }
    });
    descCtrl.addListener(() {
      if (_hasDescError && descCtrl.text.trim().isNotEmpty) {
        setState(() => _hasDescError = false);
      }
    });
    priceCtrl.addListener(() {
      if (_hasPriceError) {
        final clean = toLatinDigits(priceCtrl.text).replaceAll(',', '').trim();
        final n = int.tryParse(clean);
        if (n != null && n > 0) {
          setState(() => _hasPriceError = false);
        }
      }
    });
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
      final imgs = await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
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
      final img = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
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
                            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            categoryIcon(cat),
                            size: 20,
                            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Theme.of(context).colorScheme.primary : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, size: 16, color: Theme.of(context).colorScheme.primary),
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

    // التحقق الصارم من الحقول الإلزامية الخمسة وعرض التنبيهات الحمراء أسفل كل حقل
    final totalImages = pickedImages.length + existingImages.length;
    final hasImg = totalImages > 0;
    final hasCategory = category.trim().isNotEmpty;
    final hasTitle = titleCtrl.text.trim().isNotEmpty;
    final hasDesc = descCtrl.text.trim().isNotEmpty;
    final priceStr = toLatinDigits(priceCtrl.text.trim()).replaceAll(',', '');
    final startPrice = int.tryParse(priceStr) ?? 0;
    final hasPrice = startPrice > 0;

    setState(() {
      _autoValidate = true;
      _hasImageError = !hasImg;
      _hasCategoryError = !hasCategory;
      _hasTitleError = !hasTitle;
      _hasDescError = !hasDesc;
      _hasPriceError = !hasPrice;
    });

    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid || !hasImg || !hasCategory || !hasTitle || !hasDesc || !hasPrice) {
      // التمرير السلس لنقل التركيز إلى أول حقل غير مستوفٍ للشروط
      if (!hasImg) {
        _scrollToFirstError(_imagesSectionKey);
      } else if (!hasCategory) {
        _scrollToFirstError(_categorySectionKey);
      } else if (!hasTitle) {
        _scrollToFirstError(_titleSectionKey);
      } else if (!hasDesc) {
        _scrollToFirstError(_descSectionKey);
      } else if (!hasPrice) {
        _scrollToFirstError(_priceSectionKey);
      }
      return;
    }

    final buyNowStr = toLatinDigits(buyNowPriceCtrl.text.trim()).replaceAll(',', '');
    final buyNowPrice = buyNowStr.isNotEmpty ? int.tryParse(buyNowStr) : null;

    final attrs = <String, String>{};
    for (final label in dynamicFieldsForCategory(category)) {
      final val = attrCtrls[label]?.text.trim() ?? '';
      if (val.isNotEmpty) attrs[label] = val;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final portableImages = <String>[];
    for (final imgStr in existingImages) {
      if (imgStr.startsWith('data:') && imgStr.length > 300000) {
        try {
          final comma = imgStr.indexOf(',');
          if (comma != -1) {
            final rawBytes = base64Decode(imgStr.substring(comma + 1));
            final compressed = compressAndResizeImageBytes(rawBytes, maxDimension: 1080, quality: 75);
            portableImages.add('data:image/jpeg;base64,${base64Encode(compressed)}');
            continue;
          }
        } catch (_) {}
      }
      portableImages.add(imgStr);
    }
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
      final calculatedDuration = Duration(days: durationDays, hours: durationHours);
      final finalDuration = calculatedDuration < const Duration(hours: 1)
          ? const Duration(hours: 1)
          : (calculatedDuration > const Duration(days: 7)
              ? const Duration(days: 7)
              : calculatedDuration);

      store.addItem(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        category: category,
        startPrice: startPrice,
        duration: finalDuration,
        startDelay: Duration(hours: scheduleDelayHours),
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
          content: Text(scheduleDelayHours == 0
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
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // في حالة تعديل المزاد: تنبيه بالصلاحيات المتاحة
                  if (isEditing) ...[
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('صلاحيات تعديل المزاد 🔒', 'Auction Edit Permissions 🔒'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr(
                                      'لحماية حقوق ومصداقية المزايدات: يمكنك إضافة صور جديدة (حتى 12 صورة)، تعديل عنوان الإعلان، وإدارة رمز الدخول السري (PIN)، مع قفل باقي الحقول كالسعر والموقع وتصنيف الفئة.',
                                      'You can add new photos (up to 12), update title, and manage PIN room. Core fields and category remain locked.',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                // 1. قسم صور السلعة في الأعلى مع حد بصري فاصل تحته
                Card(
                  key: _imagesSectionKey,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: _hasImageError
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.shade400, width: 1.5),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
              ),

                // الحد البصري الفاصل تحت قسم صور السلعة
                const SizedBox(height: 4),

                // 2. اختيار الفئة عبر نافذة منبثقة (Popup / Modal)
                Card(
                  key: _categorySectionKey,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: _hasCategoryError
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.shade600, width: 1.5),
                        )
                      : null,
                  child: Padding(
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
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9))
                                  : (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: category.isEmpty
                                    ? (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0))
                                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
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
              ),

                // 3. كتلة عنوان الإعلان
                Card(
                  key: _titleSectionKey,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: _hasTitleError
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.shade600, width: 1.5),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('عنوان الإعلان / اسم السلعة *', 'Auction Title *'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _hasTitleError ? Colors.red.shade700 : null,
                          ),
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
                        if (_hasTitleError) ...[
                          const SizedBox(height: 8),
                          Text(
                            tr('يرجى كتابة عنوان الإعلان / اسم السلعة قبل النشر *', 'Please enter auction title *'),
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. كتلة التفاصيل والوصف + الحقول الذكية المرتبطة بالفئة
                Card(
                  key: _descSectionKey,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: _hasDescError
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.shade600, width: 1.5),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('تفاصيل ووصف السلعة *', 'Item Description *'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _hasDescError ? Colors.red.shade700 : null,
                          ),
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
                        if (_hasDescError) ...[
                          const SizedBox(height: 8),
                          Text(
                            tr('يرجى كتابة تفاصيل ووصف السلعة قبل النشر *', 'Please enter item description *'),
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                        if (currentDynamicFields.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(categoryIcon(category), size: 18, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${tr("الحقول الذكية التلقائية لفئة:", "Smart Fields for:")} $category',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
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

                // 5. كتلة السعر
                Card(
                  key: _priceSectionKey,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: _hasPriceError
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.shade600, width: 1.5),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('سعر بداية المزاد (دينار عراقي) *', 'Starting Price (IQD) *'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _hasPriceError ? Colors.red.shade700 : null,
                        ),
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
                      if (_hasPriceError) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr('يرجى إدخال سعر بداية المزاد برقم صحيح أكبر من صفر *', 'Please enter valid starting price > 0 *'),
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
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

                // 6. كتلة خيارات التسليم والموقع
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
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
                  margin: const EdgeInsets.only(bottom: 14),
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

                // 8. كتلة موعد وتوقيت المزاد
                if (!isPublished) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule, color: Colors.indigo, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                tr('موعد انطلاق المزاد', 'Auction Start Time'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: scheduleDelayHours,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: tr('جدولة انطلاق المزاد', 'Schedule Start Time'),
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(
                                scheduleDelayHours == 0 ? Icons.bolt : Icons.calendar_today_outlined,
                                color: scheduleDelayHours == 0 ? Colors.amber.shade800 : Colors.indigo,
                              ),
                            ),
                            items: scheduleOptions
                                .map((opt) => DropdownMenuItem<int>(
                                      value: opt.key,
                                      child: Text(opt.value),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => scheduleDelayHours = val);
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Icon(Icons.timelapse, color: Colors.indigo, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tr('مدة المزاد (ساعات وأيام - الحد الأقصى 7 أيام)', 'Duration (Hours & Days - Max 7 days)'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: durationDays,
                                  decoration: InputDecoration(
                                    labelText: tr('الأيام *', 'Days *'),
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                                  ),
                                  items: List.generate(8, (d) => d)
                                      .map((d) => DropdownMenuItem<int>(
                                            value: d,
                                            child: Text('$d ${d == 1 ? tr("يوم", "day") : (d == 2 ? tr("يومان", "2 days") : (d > 2 && d < 11 ? tr("أيام", "days") : tr("يوم", "day")))}'),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        durationDays = val;
                                        if (durationDays == 7) {
                                          durationHours = 0; // الحد الأقصى 7 أيام
                                        } else if (durationDays == 0 && durationHours == 0) {
                                          durationHours = 1; // حد أدنى ساعة واحدة
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: durationHours,
                                  decoration: InputDecoration(
                                    labelText: tr('الساعات *', 'Hours *'),
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.access_time),
                                  ),
                                  items: (durationDays == 7
                                          ? [0]
                                          : [0, 1, 2, 3, 4, 6, 8, 12, 18, 23])
                                      .map((h) => DropdownMenuItem<int>(
                                            value: h,
                                            child: Text('$h ${h == 1 ? tr("ساعة", "hour") : (h == 2 ? tr("ساعتان", "2 hours") : (h > 2 && h < 11 ? tr("ساعات", "hours") : tr("ساعة", "hour")))}'),
                                          ))
                                      .toList(),
                                  onChanged: durationDays == 7
                                      ? null
                                      : (val) {
                                          if (val != null) {
                                            setState(() {
                                              durationHours = val;
                                              if (durationDays == 0 && durationHours == 0) {
                                                durationHours = 1;
                                              }
                                            });
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${tr("إجمالي مدة المزاد المحسوبة:", "Total Duration:")} $durationDays ${tr("يوم", "days")} ${tr("و", "and")} $durationHours ${tr("ساعة", "hours")} ${tr("(الحد الأقصى 7 أيام)", "(Max 7 days)")}',
                              style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 9. كتلة الخيارات الخاصة (مزاد خاص برمز PIN)
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
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
                        : scheduleDelayHours == 0
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
    ),
  );
  }
}
