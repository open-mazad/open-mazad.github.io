part of '../../main.dart';

// ======================= الصفحة الرئيسية =======================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  String query = '';
  String category = 'الكل';
  String governorateFilter = 'الكل';
  String statusFilter = 'الكل'; // 'الكل', 'جارية 🔴', 'قريباً ⏳', 'بث مباشر 🎥', 'خاصة 🔒'
  String sortBy = 'الأحدث';
  bool _hasSelectedSort = false;

  @override
  void initState() {
    super.initState();
    // استعادة مسار التوجيه بعد إتمام تسجيل الدخول (العودة إلى شاشة الإعدادات)
    final returnTab = LocalStorageHelper.read('auth_return_tab');
    if (returnTab != null) {
      LocalStorageHelper.delete('auth_return_tab');
      final targetIndex = int.tryParse(returnTab);
      if (targetIndex != null && targetIndex >= 0 && targetIndex < 5) {
        tab = targetIndex;
      }
    }
    settings.addListener(_onSettingsAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileOnboarding();
    });
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsAuthChanged);
    super.dispose();
  }

  void _onSettingsAuthChanged() {
    if (!mounted) return;
    _checkProfileOnboarding();
    final returnTab = LocalStorageHelper.read('auth_return_tab');
    if (returnTab != null) {
      LocalStorageHelper.delete('auth_return_tab');
      final targetIndex = int.tryParse(returnTab);
      if (targetIndex != null && targetIndex >= 0 && targetIndex < 5) {
        setState(() => tab = targetIndex);
      }
    }
  }

  void _checkProfileOnboarding() {
    if (!mounted) return;
    if (settings.isLoggedIn && settings.needsProfileOnboarding) {
      showCompleteProfileDialog(context);
    }
  }

  List<String> get titles => [
        tr('المزاد المفتوح', 'Open Mazad'),
        tr('الرسائل', 'Messages'),
        tr('مزايداتي', 'My Bids'),
        tr('سلعي', 'My Listings'),
        tr('الإعدادات', 'Settings'),
      ];

  List<Item> visibleItems() {
    Iterable<Item> list = store.items;

    if (tab == 2) {
      list = list.where((i) => i.bids.any((b) => b.bidder == me));
    } else if (tab == 3) {
      list = list.where((i) => i.seller == me || store.isItemSeller(i));
    } else {
      list = list.where((i) {
        final matchCat = category == 'الكل' || i.category == category;
        final matchGov =
            governorateFilter == 'الكل' ||
            governorateFilter == 'كل المحافظات' ||
            i.location == governorateFilter;
        final q = query.trim();
        final matchQ = q.isEmpty ||
            i.title.contains(q) ||
            i.description.contains(q) ||
            i.area.contains(q);

        bool matchStatus = true;
        if (statusFilter == 'جارية 🔴') {
          matchStatus = !i.isEnded && !i.isScheduled;
        } else if (statusFilter == 'قريباً ⏳') {
          matchStatus = i.isScheduled;
        } else if (statusFilter == 'خاصة 🔒') {
          matchStatus = i.isPrivate;
        }
        return matchCat && matchGov && matchQ && matchStatus;
      });
    }

    final result = list.toList();

    result.sort((a, b) {
      if (a.isEnded != b.isEnded) return a.isEnded ? 1 : -1;
      switch (sortBy) {
        case 'الأحدث':
          return b.startTime.compareTo(a.startTime);
        case 'الأقدم':
          return a.startTime.compareTo(b.startTime);
        case 'الأقل سعراً':
          return a.currentPrice.compareTo(b.currentPrice);
        case 'الأعلى سعراً':
          return b.currentPrice.compareTo(a.currentPrice);
        case 'الأكثر مزايدة':
        case 'الأكثر مزايدات':
          return b.bids.length.compareTo(a.bids.length);
        case 'الأقل مزايدة':
          return a.bids.length.compareTo(b.bids.length);
        case 'الأبعد انتهاءً':
          return b.endTime.compareTo(a.endTime);
        case 'الأقرب انتهاءً':
        default:
          return a.endTime.compareTo(b.endTime);
      }
    });

    return result;
  }

  int _countForStatus(String st) {
    switch (st) {
      case 'جارية 🔴':
        return store.items.where((i) => !i.isEnded && !i.isScheduled).length;
      case 'قريباً ⏳':
        return store.items.where((i) => i.isScheduled).length;
      case 'خاصة 🔒':
        return store.items.where((i) => i.isPrivate).length;
      case 'الكل':
      default:
        return store.items.length;
    }
  }

  int _countForGov(String g) {
    if (g == 'الكل' || g == 'كل المحافظات') return store.items.length;
    return store.items.where((i) => i.location == g).length;
  }

  int _countForCategory(String c) {
    if (c == 'الكل') return store.items.length;
    return store.items.where((i) => i.category == c).length;
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required int Function(String item) countOf,
    required ValueChanged<String> onChanged,
    int? maxVisibleItems,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDefault = value == items.first;
    final totalCount = countOf(value);
    final displayLabel = isDefault ? label : '$value ($totalCount)';

    return Expanded(
      child: PopupMenuButton<String>(
        position: PopupMenuPosition.under,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        constraints: BoxConstraints(
          minWidth: 185,
          maxWidth: 280,
          maxHeight: maxVisibleItems != null ? (maxVisibleItems * 44.0) : double.infinity,
        ),
        onSelected: (val) => onChanged(val),
        itemBuilder: (context) {
          return items.map((item) {
            final count = countOf(item);
            final isFirst = item == items.first;
            final isSelected = item == value;
            final display = isFirst ? tr('الكل', 'All') : item;

            return PopupMenuItem<String>(
              value: item,
              height: 42,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected
                        ? scheme.primary
                        : (count > 0 ? scheme.primary : scheme.outline),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      display,
                      softWrap: false,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : (count > 0 ? FontWeight.w500 : FontWeight.normal),
                        color: isSelected ? scheme.primary : (count > 0 ? scheme.onSurface : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primaryContainer
                          : (count > 0 ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? scheme.onPrimaryContainer
                            : (count > 0 ? scheme.onSurfaceVariant : scheme.outline),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDefault
                ? scheme.surfaceContainerLow
                : scheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDefault ? scheme.outlineVariant : scheme.primary,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isDefault ? scheme.onSurfaceVariant : scheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isDefault ? FontWeight.w500 : FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: isDefault ? scheme.onSurfaceVariant : scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // فلتر المحافظة المتوسط: فتح قائمة منسدلة متمركزة رأسياً وأفقياً بدقة
  Widget _buildCenteredGovernorateDropdown() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDefault = governorateFilter == 'الكل' || governorateFilter == 'كل المحافظات';
    final totalCount = _countForGov(governorateFilter);
    final displayLabel = isDefault ? tr('المحافظة', 'Gov') : '$governorateFilter ($totalCount)';

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showCenteredGovernorateModal(context),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDefault
                ? scheme.surfaceContainerLow
                : scheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDefault ? scheme.outlineVariant : scheme.primary,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: isDefault ? scheme.onSurfaceVariant : scheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isDefault ? FontWeight.w500 : FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: isDefault ? scheme.onSurfaceVariant : scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCenteredGovernorateModal(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allGovs = ['الكل', ...governorates];
    String searchFilter = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredGovs = searchFilter.trim().isEmpty
                ? allGovs
                : allGovs.where((g) => g.contains(searchFilter.trim())).toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 340,
                  maxHeight: 460,
                ),
                child: Material(
                  elevation: 8,
                  color: theme.scaffoldBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 20, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tr('اختر المحافظة', 'Select Governorate'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: TextField(
                          onChanged: (val) => setModalState(() => searchFilter = val),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: tr('ابحث عن محافظة...', 'Search governorate...'),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 12),
                      Flexible(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: filteredGovs.length,
                          itemBuilder: (context, idx) {
                            final gov = filteredGovs[idx];
                            final count = _countForGov(gov);
                            final isSelected = gov == governorateFilter;
                            final display = gov == 'الكل' ? tr('الكل', 'All') : gov;

                            return InkWell(
                              onTap: () {
                                setState(() => governorateFilter = gov);
                                Navigator.pop(dialogCtx);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                color: isSelected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: isSelected
                                          ? scheme.primary
                                          : (count > 0 ? scheme.primary : scheme.outline),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        display,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : (count > 0 ? FontWeight.w500 : FontWeight.normal),
                                          color: isSelected
                                              ? scheme.primary
                                              : (count > 0 ? scheme.onSurface : scheme.onSurfaceVariant),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? scheme.primaryContainer
                                            : (count > 0 ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? scheme.onPrimaryContainer
                                              : (count > 0 ? scheme.onSurfaceVariant : scheme.outline),
                                        ),
                                      ),
                                    ),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget searchArea() {
    final hasActiveFilters = statusFilter != 'الكل' ||
        (governorateFilter != 'الكل' && governorateFilter != 'كل المحافظات') ||
        category != 'الكل';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: tr('ابحث عن سلعة، عقار، سيارة، منطقة...',
                        'Search items, cars, real estate...'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // زر وقائمة الفرز: خلفية سوداء ثابتة، بدون إطار ونص افتراضياً، وبإطار أبيض ونص بعد الاختيار
              Builder(
                builder: (context) {
                  const sortOptions = [
                    'الأحدث',
                    'الأقدم',
                    'الأقل سعراً',
                    'الأعلى سعراً',
                    'الأكثر مزايدة',
                    'الأقل مزايدة',
                    'الأقرب انتهاءً',
                    'الأبعد انتهاءً',
                  ];

                  return Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: Colors.black,
                      popupMenuTheme: const PopupMenuThemeData(
                        color: Colors.black,
                        surfaceTintColor: Colors.transparent,
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      position: PopupMenuPosition.under,
                      elevation: 6,
                      color: Colors.black,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white24, width: 1),
                      ),
                      tooltip: tr('ترتيب حسب', 'Sort by'),
                      onSelected: (val) => setState(() {
                        sortBy = val;
                        _hasSelectedSort = true;
                      }),
                      itemBuilder: (context) => sortOptions.map((s) {
                        final isSelected = sortBy == s;
                        return PopupMenuItem(
                          value: s,
                          height: 40,
                          child: Row(
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                s,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        height: 40,
                        padding: EdgeInsets.symmetric(
                          horizontal: _hasSelectedSort ? 10 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: _hasSelectedSort
                              ? Border.all(color: Colors.white, width: 1)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 18, color: Colors.white),
                            if (_hasSelectedSort) ...[
                              const SizedBox(width: 4),
                              Text(
                                sortBy,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // صف القوائم المنسدلة الثلاث مع عداد المزادات بجانب كل خيار
          Row(
            children: [
              _buildFilterDropdown(
                label: tr('الحالة', 'Status'),
                icon: Icons.bolt,
                value: statusFilter,
                items: const [
                  'الكل',
                  'جارية 🔴',
                  'قريباً ⏳',
                  'خاصة 🔒',
                ],
                countOf: _countForStatus,
                onChanged: (val) => setState(() => statusFilter = val),
                maxVisibleItems: null, // يتناسب تلقائياً مع خياراته الأربعة دون فرض 8 حقول
              ),
              const SizedBox(width: 6),
              // القائمة المنسدلة للمحافظة: متمركزة أفقياً وعمودياً بدقة في وسط الشاشة
              _buildCenteredGovernorateDropdown(),
              const SizedBox(width: 6),
              _buildFilterDropdown(
                label: tr('النوع', 'Type'),
                icon: Icons.category_outlined,
                value: category,
                items: const ['الكل', ...categories],
                countOf: _countForCategory,
                onChanged: (val) => setState(() => category = val),
                maxVisibleItems: 8, // حد أقصى 8 حقول مع تفعيل التمرير
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: tr('إعادة ضبط الفلاتر', 'Reset filters'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    statusFilter = 'الكل';
                    governorateFilter = 'الكل';
                    category = 'الكل';
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined,
                      size: 20, color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, settings]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: tab == 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        color: Colors.white,
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 28,
                          width: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.gavel_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(titles[tab]),
                  ],
                )
              : Text(titles[tab]),
          actions: [
            if (settings.isLoggedIn && settings.isAdmin)
              IconButton(
                tooltip: tr('لوحة تحكم الإدارة', 'Admin Dashboard'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                ),
                icon: const Icon(Icons.admin_panel_settings_outlined),
              ),
            // 1. اليمين: رادار البحث الذكي
            IconButton(
              tooltip: tr('رادار البحث الذكي', 'Smart Search Radar'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const RadarAndNotificationsPage(initialTab: 0),
                ),
              ),
              icon: const Icon(Icons.radar),
            ),
            // 2. المنتصف: الإشعارات
            IconButton(
              tooltip: tr('مركز الإشعارات', 'Notifications Center'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const RadarAndNotificationsPage(initialTab: 1),
                ),
              ),
              icon: Badge(
                isLabelVisible: store.unreadNotificationsCount > 0,
                label: Text('${store.unreadNotificationsCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            // 3. اليسار: المفضلة (أيقونة القلب)
            IconButton(
              tooltip: tr('المفضلة', 'Watchlist'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const RadarAndNotificationsPage(initialTab: 2),
                ),
              ),
              icon: Badge(
                isLabelVisible: store.favorites.isNotEmpty,
                label: Text('${store.favorites.length}'),
                child: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
              ),
            ),
          ],
        ),
        body: tab == 4
            ? const SettingsPage()
            : tab == 1
                ? MessagesInboxView(
                    onGoToSettings: () => setState(() => tab = 4),
                  )
                : Column(
                    children: [
                      if (tab == 0) searchArea(),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final list = visibleItems();
                            if (list.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      tab == 2
                                          ? Icons.gavel_outlined
                                          : Icons.inventory_2_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      tab == 2
                                          ? tr(
                                              'لم تشارك في أي مزايدة بعد\nتصفح المزادات وشارك في المزايدة لتظهر هنا',
                                              'No bids yet. Browse items and place bids to see them here.',
                                            )
                                          : tab == 3
                                              ? tr(
                                                  'لم تقم بإضافة أي سلعة بعد\nاضغط على (أضف مزاداً) لعرض سلعك للبيع',
                                                  'You have not listed any items yet.',
                                                )
                                              : tr('لا توجد عناصر مطابقة للبحث',
                                                  'No matching items found'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 15, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                              itemCount: list.length,
                              itemBuilder: (context, i) => ItemCard(item: list[i]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
        floatingActionButton: (tab == 1 || tab == 4)
            ? null
            : FloatingActionButton.extended(
                onPressed: () {
                  if (!settings.isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr('سجّل الدخول أولاً من الإعدادات',
                            'Sign in from Settings first'))));
                    setState(() => tab = 4);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddItemPage()),
                  );
                },
                icon: const Icon(Icons.add),
                label: Text(tr('أضف مزاداً', 'List Auction')),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() {
            tab = i;
            query = '';
          }),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront),
              label: tr('المزادات', 'Auctions'),
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: store.unreadDirectMessagesCount > 0,
                label: Text('${store.unreadDirectMessagesCount}'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: Badge(
                isLabelVisible: store.unreadDirectMessagesCount > 0,
                label: Text('${store.unreadDirectMessagesCount}'),
                child: const Icon(Icons.chat_bubble),
              ),
              label: tr('الرسائل', 'Messages'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.gavel_outlined),
              selectedIcon: const Icon(Icons.gavel),
              label: tr('مزايداتي', 'My Bids'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: tr('سلعي', 'My Listings'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: tr('الإعدادات', 'Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= صفحة المفضلة (Favorites Page) =======================

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RadarAndNotificationsPage(initialTab: 2);
  }
}

