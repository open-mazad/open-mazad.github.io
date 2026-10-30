part of '../../main.dart';

// ======================= 5. مركز الإشعارات ورادار البحث الذكي =======================

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
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text(tr('الإشعارات والرادار الذكي', 'Alerts & Smart Radar')),
            actions: [
              if (store.notifications.isNotEmpty)
                TextButton(
                  onPressed: store.markAllNotificationsRead,
                  child: Text(tr('قراءة الكل', 'Mark all read')),
                ),
            ],
            bottom: TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.notifications_active_outlined),
                  text:
                      '${tr("الإشعارات", "Notifications")} (${store.unreadNotificationsCount})',
                ),
                Tab(
                  icon: const Icon(Icons.radar),
                  text:
                      '${tr("رادار البحث", "Search Radar")} (${store.savedSearchKeywords.length})',
                ),
              ],
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: TabBarView(
                children: [
                  // التبويب الأول: مركز الإشعارات
              store.notifications.isEmpty
                  ? Center(
                      child: Text(tr('لا توجد إشعارات حالياً', 'No notifications yet')))
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

              // التبويب الثاني: رادار البحث المحفوظ
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.radar, color: Colors.indigo, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr(
                                'أضف كلمات مفتاحية للسلع التي تبحث عنها (مثل: "آيفون 16"، "رولكس"، "مرسيدس"، "عقار"). سيقوم الرادار بتنبيهك فور عرض أي مزاد يطابقها!',
                                'Save keywords (e.g. "iPhone", "Rolex", "Villa"). You will get an instant notification as soon as a matching auction is listed!',
                              ),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87),
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
                    const SizedBox(height: 16),
                    Text(
                      tr('الكلمات المراقبة حالياً:', 'Active Monitored Keywords:'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
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
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
}

