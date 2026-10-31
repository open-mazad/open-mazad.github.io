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
  String sortBy = 'الأقرب انتهاءً';

  @override
  void initState() {
    super.initState();
    settings.addListener(_checkProfileOnboarding);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileOnboarding();
    });
  }

  @override
  void dispose() {
    settings.removeListener(_checkProfileOnboarding);
    super.dispose();
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
        case 'الأقل سعراً':
          return a.currentPrice.compareTo(b.currentPrice);
        case 'الأعلى سعراً':
          return b.currentPrice.compareTo(a.currentPrice);
        case 'الأكثر مزايدات':
          return b.bids.length.compareTo(a.bids.length);
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
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDefault = value == items.first;
    return Expanded(
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
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isDefault ? scheme.onSurfaceVariant : scheme.primary,
            ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isDefault ? FontWeight.normal : FontWeight.bold,
              color: scheme.onSurface,
            ),
            selectedItemBuilder: (context) {
              return items.map((item) {
                final count = countOf(item);
                final isFirst = item == items.first;
                final display = isFirst ? label : '$item ($count)';
                return Row(
                  children: [
                    Icon(icon, size: 14, color: isFirst ? scheme.onSurfaceVariant : scheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isDefault ? FontWeight.w500 : FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            items: items.map((item) {
              final count = countOf(item);
              final isFirst = item == items.first;
              final display = isFirst ? tr('الكل', 'All') : item;
              return DropdownMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: count > 0 ? scheme.primary : scheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: count > 0
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight:
                              count > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: count > 0
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: count > 0
                              ? scheme.onPrimaryContainer
                              : scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
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
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: tr('ترتيب حسب', 'Sort by'),
                onSelected: (val) => setState(() => sortBy = val),
                itemBuilder: (context) => [
                  'الأقرب انتهاءً',
                  'الأقل سعراً',
                  'الأعلى سعراً',
                  'الأكثر مزايدات',
                ].map((s) {
                  return PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        if (sortBy == s) ...[
                          const Icon(Icons.check,
                              size: 18, color: Colors.indigo),
                          const SizedBox(width: 6),
                        ],
                        Text(s),
                      ],
                    ),
                  );
                }).toList(),
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
              ),
              const SizedBox(width: 6),
              _buildFilterDropdown(
                label: tr('المحافظة', 'Gov'),
                icon: Icons.location_on_outlined,
                value: governorateFilter,
                items: const ['الكل', ...governorates],
                countOf: _countForGov,
                onChanged: (val) => setState(() => governorateFilter = val),
              ),
              const SizedBox(width: 6),
              _buildFilterDropdown(
                label: tr('النوع', 'Type'),
                icon: Icons.category_outlined,
                value: category,
                items: const ['الكل', ...categories],
                countOf: _countForCategory,
                onChanged: (val) => setState(() => category = val),
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
          title: Text(titles[tab]),
          actions: [
            IconButton(
              tooltip: tr('المفضلة', 'Watchlist'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesPage()),
              ),
              icon: Badge(
                isLabelVisible: store.favorites.isNotEmpty,
                label: Text('${store.favorites.length}'),
                child: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
              ),
            ),
            IconButton(
              tooltip: tr('رادار البحث الذكي', 'Smart Search Radar'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const RadarAndNotificationsPage(initialTab: 1),
                ),
              ),
              icon: const Icon(Icons.radar),
            ),
            IconButton(
              tooltip: tr('مركز الإشعارات', 'Notifications Center'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const RadarAndNotificationsPage(initialTab: 0),
                ),
              ),
              icon: Badge(
                isLabelVisible: store.unreadNotificationsCount > 0,
                label: Text('${store.unreadNotificationsCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            if (settings.isLoggedIn && settings.isAdmin)
              IconButton(
                tooltip: tr('لوحة تحكم الإدارة', 'Admin Dashboard'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                ),
                icon: const Icon(Icons.admin_panel_settings_outlined),
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
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final favItems =
            store.items.where((i) => store.isFavorite(i.id)).toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(
              favItems.isNotEmpty
                  ? '${tr('المفضلة', 'Watchlist')} (${favItems.length})'
                  : tr('المفضلة', 'Watchlist'),
            ),
            actions: [
              if (favItems.isNotEmpty)
                IconButton(
                  tooltip: tr('مسح الكل', 'Clear All'),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(tr('مسح المفضلة', 'Clear Watchlist')),
                        content: Text(tr(
                            'هل تريد إزالة جميع السلع من قائمة المفضلة؟',
                            'Remove all items from watchlist?')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(tr('إلغاء', 'Cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(tr('مسح', 'Clear')),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      store.clearFavorites();
                    }
                  },
                ),
            ],
          ),
          body: favItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 72,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('قائمة المفضلة فارغة', 'Watchlist is empty'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          tr('اضغط على أيقونة القلب على أي سلعة لحفظها والوصول إليها بسرعة هنا.',
                              'Tap the heart icon on any item to save it here for quick access.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
                      itemCount: favItems.length,
                      itemBuilder: (context, i) =>
                          ItemCard(item: favItems[i]),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

