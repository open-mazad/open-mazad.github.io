part of '../../main.dart';

// ======================= الصفحة الرئيسية =======================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  late final PageController _homePageCtrl;
  String query = '';
  String category = 'الكل';
  String governorateFilter = 'الكل';
  String statusFilter = 'الكل'; // 'الكل', 'جارية 🔴', 'قريباً ⏳', 'بث مباشر 🎥', 'خاصة 🔒'
  String sortBy = 'الأحدث';
  bool _hasSelectedSort = false;

  int _tabToPageIndex(int tabIndex) {
    if (tabIndex >= 3) return tabIndex - 1;
    if (tabIndex <= 1) return tabIndex;
    return 0;
  }

  int _pageIndexToTabIndex(int pageIndex) {
    if (pageIndex >= 2) return pageIndex + 1;
    return pageIndex;
  }

  void _goToTab(int targetTab) {
    if (targetTab == tab && _homePageCtrl.hasClients && _homePageCtrl.page?.round() == _tabToPageIndex(targetTab)) {
      return;
    }
    setState(() {
      tab = targetTab;
      query = '';
    });
    globalActiveTabNotifier.value = targetTab;
    final targetPage = _tabToPageIndex(targetTab);
    if (_homePageCtrl.hasClients && _homePageCtrl.page?.round() != targetPage) {
      _homePageCtrl.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

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
        globalActiveTabNotifier.value = targetIndex;
      }
    }
    _homePageCtrl = PageController(initialPage: _tabToPageIndex(tab));
    globalActiveTabNotifier.addListener(_onGlobalTabChanged);
    settings.addListener(_onSettingsAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileOnboarding();
    });
  }

  void _onGlobalTabChanged() {
    final nextTab = globalActiveTabNotifier.value;
    if (mounted && nextTab >= 0 && nextTab < 5 && tab != nextTab) {
      setState(() => tab = nextTab);
      final targetPage = _tabToPageIndex(nextTab);
      if (_homePageCtrl.hasClients && _homePageCtrl.page?.round() != targetPage) {
        _homePageCtrl.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _homePageCtrl.dispose();
    globalActiveTabNotifier.removeListener(_onGlobalTabChanged);
    settings.removeListener(_onSettingsAuthChanged);
    super.dispose();
  }

  int myBidsSubTab = 0; // 0: الكل, 1: مزايداتي, 2: سلعي

  void _onSettingsAuthChanged() {
    if (!mounted) return;
    _checkProfileOnboarding();
    final returnTab = LocalStorageHelper.read('auth_return_tab');
    if (returnTab != null) {
      LocalStorageHelper.delete('auth_return_tab');
      final targetIndex = int.tryParse(returnTab);
      if (targetIndex != null && targetIndex >= 0 && targetIndex < 5) {
        _goToTab(targetIndex);
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
        tr('الرئيسية', 'Home'),
        tr('الرسائل', 'Messages'),
        tr('أضف مزاداً', 'List Auction'),
        tr('المزايدات', 'Bids & Auctions'),
        tr('ملفي', 'My Profile'),
      ];

  List<Item> getVisibleItems({required bool isMyBidsTab}) {
    Iterable<Item> list = store.items;

    if (isMyBidsTab) {
      // تبويب المزايدات المدمج:
      // 0: الكل (مزايداتي وسلعي والمفضلة)
      // 1: مزايداتي (التي شارك بها المستخدم)
      // 3: المفضلة (التي أضافها للمفضلة)
      // 2: سلعي (التي طرحها للبيع)
      if (myBidsSubTab == 1) {
        list = list.where((i) => i.bids.any((b) => b.bidder == me || store.isUserMe(b.bidder)));
      } else if (myBidsSubTab == 2) {
        list = list.where((i) => i.seller == me || store.isItemSeller(i));
      } else if (myBidsSubTab == 3) {
        list = list.where((i) => store.isFavorite(i.id));
      } else {
        list = list.where((i) =>
            i.seller == me ||
            store.isItemSeller(i) ||
            store.isFavorite(i.id) ||
            i.bids.any((b) => b.bidder == me || store.isUserMe(b.bidder)));
      }
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
      if (isMyBidsTab && myBidsSubTab == 0) {
        // الكل: مرتبة زمنياً حسب تاريخ الإضافة/النشر (الأحدث أولاً)
        return b.startTime.compareTo(a.startTime);
      }
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

  List<Item> visibleItems() => getVisibleItems(isMyBidsTab: tab == 3);

  Widget _buildItemsList({required bool isMyBidsTab}) {
    final list = getVisibleItems(isMyBidsTab: isMyBidsTab);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMyBidsTab
                  ? (myBidsSubTab == 2
                      ? Icons.inventory_2_outlined
                      : (myBidsSubTab == 3
                          ? Icons.favorite_border
                          : Icons.gavel_outlined))
                  : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isMyBidsTab
                  ? (myBidsSubTab == 2
                      ? tr(
                          'لم تقم بإضافة أي سلعة بعد\nاضغط على (أضف مزاداً) لعرض سلعك للبيع',
                          'You have not listed any items yet.',
                        )
                      : myBidsSubTab == 3
                          ? tr(
                              'قائمة المفضلة فارغة\nاضغط على أيقونة القلب على أي سلعة لإضافتها هنا',
                              'Watchlist is empty. Tap the heart icon on any item to save it here.',
                            )
                          : myBidsSubTab == 1
                              ? tr(
                                  'لم تشارك في أي مزايدة بعد\nتصفح المزادات وشارك في المزايدة لتظهر هنا',
                                  'No bids yet. Browse items and place bids to see them here.',
                                )
                              : tr(
                                  'لا توجد مشاركات أو سلع حتى الآن\nابدأ بالمزايدة أو اعرض سلعة جديدة',
                                  'No bids or listings yet. Start bidding or list an item.',
                                ))
                  : tr('لا توجد عناصر مطابقة للبحث',
                      'No matching items found'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
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
    final isDefault = value == items.first || (items.first == 'الكل' && value == 'كل المحافظات');
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
            final isSelected = item == value || (isFirst && (value == 'كل المحافظات' || value == 'الكل'));
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
              // زر وقائمة الفرز: متناسق تماماً مع ألوان التطبيق وثيم البطاقات
              Builder(
                builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
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

                  final isDefault = !_hasSelectedSort;

                  return PopupMenuButton<String>(
                    position: PopupMenuPosition.under,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: scheme.outlineVariant),
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
                              Icon(Icons.check, size: 16, color: scheme.primary),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              s,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? scheme.primary : scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDefault
                            ? scheme.surfaceContainerLow
                            : scheme.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDefault ? scheme.outlineVariant : scheme.primary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sort,
                            size: 18,
                            color: isDefault ? scheme.onSurfaceVariant : scheme.primary,
                          ),
                          if (_hasSelectedSort) ...[
                            const SizedBox(width: 4),
                            Text(
                              sortBy,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ],
                        ],
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
              // القائمة المنسدلة للمحافظة: متناسقة تماماً مع النوع والحالة
              _buildFilterDropdown(
                label: tr('المحافظة', 'Gov'),
                icon: Icons.location_on_outlined,
                value: governorateFilter,
                items: const ['الكل', ...governorates],
                countOf: _countForGov,
                onChanged: (val) => setState(() => governorateFilter = val),
                maxVisibleItems: 8,
              ),
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
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final navColor = isDark ? Colors.white : Colors.black;
        final unselectedNavColor = isDark ? Colors.white70 : Colors.black87;

        return Scaffold(
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
                    Text(
                      tr('المزاد المفتوح', 'Open Mazad'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
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
            // 3. اليسار: الإعدادات (استبدال موقع المفضلة السابق)
            IconButton(
              tooltip: tr('الإعدادات', 'Settings'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: PageView(
          controller: _homePageCtrl,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (pageIndex) {
            final newTab = _pageIndexToTabIndex(pageIndex);
            if (tab != newTab) {
              setState(() {
                tab = newTab;
                query = '';
              });
              globalActiveTabNotifier.value = newTab;
            }
          },
          children: [
            _KeepAlivePage(
              child: Column(
                children: [
                  searchArea(),
                  Expanded(child: _buildItemsList(isMyBidsTab: false)),
                ],
              ),
            ),
            _KeepAlivePage(
              child: MessagesInboxView(
                onGoToSettings: () => _goToTab(4),
              ),
            ),
            _KeepAlivePage(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 0,
                          label: Text(tr('الكل', 'All')),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text(tr('مزايداتي', 'My Bids')),
                        ),
                        ButtonSegment(
                          value: 3,
                          label: Text(
                            store.favorites.isNotEmpty
                                ? '${tr('المفضلة', 'Favorites')} (${store.favorites.length})'
                                : tr('المفضلة', 'Favorites'),
                          ),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text(tr('سلعي', 'My Listings')),
                        ),
                      ],
                      selected: {myBidsSubTab},
                      onSelectionChanged: (set) => setState(() => myBidsSubTab = set.first),
                    ),
                  ),
                  Expanded(child: _buildItemsList(isMyBidsTab: true)),
                ],
              ),
            ),
            _KeepAlivePage(
              child: MyProfileView(
                onGoToSettings: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 56,
            indicatorColor: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.08),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? navColor : unselectedNavColor,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 21,
                color: selected ? navColor : unselectedNavColor,
              );
            }),
          ),
          child: NavigationBar(
            height: 56,
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            selectedIndex: tab,
            onDestinationSelected: (i) {
              if (i == 2) {
                if (!settings.isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr('سجّل الدخول أولاً من ملفي',
                          'Sign in from My Profile first'))));
                  _goToTab(4);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddItemPage()),
                );
                return;
              }
              _goToTab(i);
            },
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: unselectedNavColor),
                selectedIcon: Icon(Icons.home, color: navColor),
                label: tr('الرئيسية', 'Home'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: store.unreadDirectMessagesCount > 0,
                  label: Text('${store.unreadDirectMessagesCount}'),
                  child: Icon(Icons.chat_bubble_outline, color: unselectedNavColor),
                ),
                selectedIcon: Badge(
                  isLabelVisible: store.unreadDirectMessagesCount > 0,
                  label: Text('${store.unreadDirectMessagesCount}'),
                  child: Icon(Icons.chat_bubble, color: navColor),
                ),
                label: tr('الرسائل', 'Messages'),
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: navColor, size: 22),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: navColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: isDark ? Colors.black : Colors.white, size: 22),
                ),
                label: tr('أضف مزاداً', 'Add Auction'),
              ),
              NavigationDestination(
                icon: Icon(Icons.gavel_outlined, color: unselectedNavColor),
                selectedIcon: Icon(Icons.gavel, color: navColor),
                label: tr('المزايدات', 'Bids & Auctions'),
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: unselectedNavColor),
                selectedIcon: Icon(Icons.person, color: navColor),
                label: tr('ملفي', 'My Profile'),
              ),
            ],
          ),
        ),
      );
    },
  );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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

