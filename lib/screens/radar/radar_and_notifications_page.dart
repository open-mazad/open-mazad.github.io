part of '../../main.dart';

// ======================= 5. الواجهة الموحدة: الرادار الذكي، الإشعارات والمفضلة =======================

class RadarAndNotificationsPage extends StatefulWidget {
  final int initialTab;
  const RadarAndNotificationsPage({super.key, this.initialTab = 0});

  @override
  State<RadarAndNotificationsPage> createState() =>
      _RadarAndNotificationsPageState();
}

class _RadarAndNotificationsPageState extends State<RadarAndNotificationsPage> {
  final keywordCtrl = TextEditingController();

  @override
  void dispose() {
    keywordCtrl.dispose();
    super.dispose();
  }

  void addKeyword() {
    final kw = keywordCtrl.text.trim();
    if (kw.isEmpty) return;
    store.addSearchRadarKeyword(kw);
    keywordCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final favItems =
              store.items.where((i) => store.isFavorite(i.id)).toList();

          return Scaffold(
            appBar: AppBar(
              title: Text(tr('مركز المتابعة الذكي', 'Tracking Center')),
              actions: [
                if (store.notifications.isNotEmpty)
                  TextButton(
                    onPressed: store.markAllNotificationsRead,
                    child: Text(tr('قراءة الإشعارات', 'Read All Alerts')),
                  ),
                if (favItems.isNotEmpty)
                  IconButton(
                    tooltip: tr('مسح المفضلة', 'Clear Watchlist'),
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
              bottom: TabBar(
                isScrollable: false,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.radar),
                    text:
                        '${tr("الرادار", "Radar")} (${store.savedSearchKeywords.length})',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: store.unreadNotificationsCount > 0,
                      label: Text('${store.unreadNotificationsCount}'),
                      child: const Icon(Icons.notifications_active_outlined),
                    ),
                    text:
                        '${tr("الإشعارات", "Alerts")} (${store.unreadNotificationsCount})',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: favItems.isNotEmpty,
                      label: Text('${favItems.length}'),
                      child: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
                    ),
                    text:
                        '${tr("المفضلة", "Watchlist")} (${favItems.length})',
                  ),
                ],
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: TabBarView(
                  children: [
                    // =================== التبويب 0: رادار البحث الذكي ===================
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.indigo.shade100),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.radar, color: Colors.indigo, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tr(
                                    'أضف كلمات مفتاحية للسلع التي تبحث عنها (مثل: "آيفون 16"، "رولكس"، "مرسيدس"، "عقار"). سيقوم الرادار بتنبيهك فور عرض أي مزاد يطابقها!',
                                    'Save keywords (e.g. "iPhone", "Rolex", "Villa"). You will get an instant notification as soon as a matching auction is listed!',
                                  ),
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.4, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: keywordCtrl,
                                decoration: InputDecoration(
                                  hintText: tr('مثال: آيفون، رولكس، تويوتا...',
                                      'e.g. iPhone, Rolex, BMW...'),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.search),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => addKeyword(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: addKeyword,
                              icon: const Icon(Icons.add_alert),
                              label: Text(tr('تفعيل رادار', 'Add Alert')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr('الكلمات المراقبة حالياً بالرادار:', 'Active Radar Keywords:'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        if (store.savedSearchKeywords.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                tr('لم تقم بتفعيل أي كلمات مراقبة بعد.', 'No radar keywords yet.'),
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final kw in store.savedSearchKeywords)
                                InputChip(
                                  avatar: const Icon(Icons.notifications_active,
                                      size: 16, color: Colors.indigo),
                                  label: Text(kw),
                                  onDeleted: () =>
                                      store.removeSearchRadarKeyword(kw),
                                ),
                            ],
                          ),
                      ],
                    ),

                    // =================== التبويب 1: مركز الإشعارات ===================
                    store.notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none,
                                    size: 64, color: scheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  tr('لا توجد إشعارات حالياً', 'No notifications yet'),
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: store.notifications.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final n = store.notifications[i];
                              return ListTile(
                                tileColor: n.isRead
                                    ? null
                                    : Colors.indigo.withValues(alpha: 0.08),
                                leading: CircleAvatar(
                                  backgroundColor: n.color.withValues(alpha: 0.15),
                                  child: Icon(n.icon, color: n.color),
                                ),
                                title: Text(
                                  n.title,
                                  style: TextStyle(
                                    fontWeight:
                                        n.isRead ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text('${n.body}\n${ago(n.time)}'),
                                isThreeLine: true,
                                onTap: () {
                                  store.markNotificationRead(n.id);
                                  if (n.itemId != null) {
                                    final target = store.items
                                        .where((it) => it.id == n.itemId)
                                        .firstOrNull;
                                    if (target != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ItemDetailsPage(item: target),
                                        ),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),

                    // =================== التبويب 2: المفضلة ===================
                    favItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  size: 64,
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  tr('قائمة المفضلة فارغة', 'Watchlist is empty'),
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    tr(
                                      'اضغط على أيقونة القلب على أي سلعة لحفظها والوصول إليها بسرعة هنا.',
                                      'Tap the heart icon on any item to save it here for quick access.',
                                    ),
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
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
                            itemCount: favItems.length,
                            itemBuilder: (context, i) =>
                                ItemCard(item: favItems[i]),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
