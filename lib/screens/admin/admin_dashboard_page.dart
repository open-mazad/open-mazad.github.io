part of '../../main.dart';

// ======================= 6. لوحة تحكم الإدارة ونظام البلاغات المطور =======================

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final TextEditingController _itemSearchCtrl = TextEditingController();
  final TextEditingController _userSearchCtrl = TextEditingController();
  String _itemSearchQuery = '';
  String _userSearchQuery = '';

  @override
  void dispose() {
    _itemSearchCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, settings]),
        builder: (context, _) {
          final totalAuctions = store.items.length;
          final activeAuctions =
              store.items.where((i) => !i.isEnded && !i.isScheduled).length;
          final scheduledAuctions =
              store.items.where((i) => i.isScheduled).length;
          final endedAuctions =
              store.items.where((i) => i.isEnded).length;
          final privateAuctions =
              store.items.where((i) => i.isPrivate).length;
          final totalBidsVolume = store.items.fold<int>(
              0, (sum, i) => sum + (i.bids.isEmpty ? 0 : i.currentPrice));

          // تصفية الإعلانات في تبويب الإعلانات
          final filteredItems = store.items.where((item) {
            final q = _itemSearchQuery.trim().toLowerCase();
            if (q.isEmpty) return true;
            final matchTitle = item.title.toLowerCase().contains(q);
            final matchCategory = item.category.toLowerCase().contains(q);
            final matchPrice = '${item.currentPrice}'.contains(q) || '${item.startPrice}'.contains(q);
            final matchSeller = displayName(item.seller).toLowerCase().contains(q);
            return matchTitle || matchCategory || matchPrice || matchSeller;
          }).toList();

          // تصفية وقائمة المستخدمين الفريدة (Deduplicated Users)
          final filteredUsers = store.allKnownUsers.where((user) {
            final q = _userSearchQuery.trim().toLowerCase();
            if (q.isEmpty) return true;
            final name = displayName(user).toLowerCase();
            final raw = user.toLowerCase();
            final phone = (AuctionStore.userPhones[user] ?? '').toLowerCase();
            return name.contains(q) || raw.contains(q) || phone.contains(q);
          }).toList();

          return Scaffold(
            appBar: AppBar(
              title: Text(tr('لوحة تحكم الإدارة والإحصائيات 🛡️',
                  'Admin Dashboard & Analytics 🛡️')),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.analytics_outlined),
                    text: tr('معلومات المزادات', 'Auction Stats'),
                  ),
                  Tab(
                    icon: const Icon(Icons.report_problem_outlined),
                    text:
                        '${tr("البلاغات", "Reports")} (${store.reports.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.inventory_2_outlined),
                    text: '${tr("الإعلانات", "Listings")} ($totalAuctions)',
                  ),
                  Tab(
                    icon: const Icon(Icons.people_alt_outlined),
                    text: '${tr("المستخدمون والحظر", "Users & Bans")} (${store.allKnownUsers.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.cloud_sync_outlined),
                    text: tr('قاعدة البيانات', 'Database'),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // التبويب 1: معلومات المزادات والإحصائيات العامة
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      tr('المؤشرات الحيوية للمنصة', 'Platform Vital Metrics'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _adminStatCard(
                          tr('إجمالي المزادات', 'Total Auctions'),
                          '$totalAuctions',
                          Icons.gavel,
                          Colors.indigo,
                        ),
                        _adminStatCard(
                          tr('مزادات جارية الآن', 'Active Auctions'),
                          '$activeAuctions',
                          Icons.play_circle_fill,
                          Colors.green,
                        ),
                        _adminStatCard(
                          tr('مزادات قادمة (مجدولة)', 'Scheduled'),
                          '$scheduledAuctions',
                          Icons.schedule,
                          Colors.orange,
                        ),
                        _adminStatCard(
                          tr('حجم المزايدات التراكمي', 'Total Bid Volume'),
                          formatPrice(totalBidsVolume),
                          Icons.payments,
                          Colors.teal,
                        ),
                        _adminStatCard(
                          tr('مزادات مكتملة ومنتهية', 'Ended Auctions'),
                          '$endedAuctions',
                          Icons.check_circle_outline,
                          Colors.blueGrey,
                        ),
                        _adminStatCard(
                          tr('مزادات برمز سري (خاصة)', 'Private Auctions'),
                          '$privateAuctions',
                          Icons.lock_outline,
                          Colors.deepPurple,
                        ),
                        _adminStatCard(
                          tr('إجمالي البلاغات الواردة', 'Total Reports'),
                          '${store.reports.length}',
                          Icons.flag_outlined,
                          Colors.red,
                        ),
                        _adminStatCard(
                          tr('المستخدمون المحظورون', 'Banned Users'),
                          '${store.bannedUsers.length}',
                          Icons.block,
                          Colors.redAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.security, color: Colors.teal),
                                const SizedBox(width: 8),
                                Text(
                                  tr('حالة أمان وسرعة المزامنة', 'Sync & Security Status'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.storage, color: Colors.blue),
                              title: Text(tr('التخزين المحلي المستقر', 'Local Storage Persistence')),
                              subtitle: Text(tr('مفعّل ويعمل تلقائياً لكافة الجلسات والبيانات', 'Active & saving all state automatically')),
                              trailing: const Icon(Icons.check_circle, color: Colors.green),
                            ),
                            ListTile(
                              dense: true,
                              leading: Icon(
                                settings.isCloudConfigured ? Icons.cloud_done : Icons.cloud_off,
                                color: settings.isCloudConfigured ? Colors.green : Colors.grey,
                              ),
                              title: Text(tr('المزامنة السحابية الفورية (Realtime)', 'Supabase Cloud Realtime')),
                              subtitle: Text(settings.isCloudConfigured
                                  ? tr('متصل بقنوات البث اللحظي السحابية', 'Connected to cloud realtime channels')
                                  : tr('غير متصل بالسحابة (يعمل محلياً)', 'Offline / Local only')),
                              trailing: Icon(
                                settings.isCloudConfigured ? Icons.check_circle : Icons.warning_amber,
                                color: settings.isCloudConfigured ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // التبويب 2: سجل البلاغات والشكاوى
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.report_problem_outlined, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          tr('سجل البلاغات والشكاوى الواردة', 'Reports & Complaints Log'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (store.reports.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 48, color: Colors.teal),
                                const SizedBox(height: 8),
                                Text(
                                  tr('لا توجد بلاغات أو شكاوى حالياً ✅', 'No reports or complaints at this time ✅'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      for (final rep in store.reports)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      rep.isResolved
                                          ? Icons.check_circle
                                          : Icons.warning_amber_rounded,
                                      color: rep.isResolved
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${tr("المبلَّغ عنه:", "Reported:")} ${displayName(rep.reportedUser)} • ${rep.itemTitle}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        rep.isResolved
                                            ? tr('تمت المعالجة ✅', 'Resolved')
                                            : tr('قيد المراجعة ⏳', 'Pending'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('${tr("السبب:", "Reason:")} ${rep.reason}'),
                                Text(
                                  '${tr("المبلِّغ:", "By:")} ${displayName(rep.reporter)} • ${ago(rep.time)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                if (!rep.isResolved) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () =>
                                            store.warnUser(rep.reportedUser, rep.id),
                                        icon: const Icon(Icons.warning_amber, size: 16),
                                        label: Text(tr('توجيه إنذار ⚠️', 'Issue Warning')),
                                      ),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                            backgroundColor: Colors.red.shade700),
                                        onPressed: () =>
                                            store.banUser(rep.reportedUser, rep.id),
                                        icon: const Icon(Icons.block, size: 16),
                                        label: Text(tr('حظر وتجميد الحساب 🚫', 'Ban Account 🚫')),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                  ],
                ),

                // التبويب 3: إدارة ومتابعة الإعلانات (مع البحث وDeep Linking)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      child: TextField(
                        controller: _itemSearchCtrl,
                        decoration: InputDecoration(
                          hintText: tr('ابحث باسم السلعة، السعر، أو الفئة...', 'Search by title, price, or category...'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _itemSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _itemSearchCtrl.clear();
                                    setState(() => _itemSearchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        onChanged: (val) => setState(() => _itemSearchQuery = val),
                      ),
                    ),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Text(tr('لا توجد إعلانات مطابقة للبحث', 'No listings match your search')),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, i) {
                                final item = filteredItems[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      child: Icon(categoryIcon(item.category), size: 20),
                                    ),
                                    title: Text(
                                      item.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${tr("البائع:", "Seller:")} ${displayName(item.seller)} • ${formatPrice(item.currentPrice)} • ${item.category}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: tr('حذف الإعلان نهائياً', 'Delete Listing'),
                                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                                          onPressed: () async {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text(tr('حذف الإعلان', 'Delete Listing')),
                                                content: Text(tr(
                                                  'هل أنت متأكد من حذف إعلان "${item.title}" نهائياً من المنصة؟',
                                                  'Are you sure you want to delete "${item.title}" permanently?',
                                                )),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: Text(tr('إلغاء', 'Cancel')),
                                                  ),
                                                  FilledButton(
                                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: Text(tr('حذف', 'Delete')),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok == true) {
                                              store.deleteItem(item);
                                            }
                                          },
                                        ),
                                        const Icon(Icons.chevron_right, size: 20),
                                      ],
                                    ),
                                    // الربط المباشر بصفحة تفاصيل السلعة (Deep Linking)
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ItemDetailsPage(item: item),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // التبويب 4: إدارة المستخدمين والحظر (مع تمييز المشرفين وإلغاء التكرار والبحث)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      child: TextField(
                        controller: _userSearchCtrl,
                        decoration: InputDecoration(
                          hintText: tr('ابحث باسم المستخدم أو رقمه...', 'Search user by name or phone...'),
                          prefixIcon: const Icon(Icons.person_search),
                          suffixIcon: _userSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _userSearchCtrl.clear();
                                    setState(() => _userSearchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        onChanged: (val) => setState(() => _userSearchQuery = val),
                      ),
                    ),
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? Center(
                              child: Text(tr('لا يوجد مستخدمون مطابقون', 'No users found matching query')),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, i) {
                                final user = filteredUsers[i];
                                final isBanned = store.bannedUsers.contains(user);
                                final warns = store.userWarnings[user] ?? 0;
                                final rating = store.getUserRating(user);
                                final isAdmin = store.isUserAdmin(user);
                                final isCurrent = user == me;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text(displayName(user).characters.first),
                                    ),
                                    title: Text(
                                      '${displayName(user)} ${isCurrent ? tr("(حسابك)", "(You)") : ""}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '⭐ ${rating.toStringAsFixed(1)} • ${tr("الإنذارات:", "Warnings:")} $warns',
                                    ),
                                    trailing: isAdmin
                                        // استثناء المسؤولين من زري الإنذار والحظر ووضع شارة مسؤول ثابتة
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.teal),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.shield, size: 14, color: Colors.teal),
                                                const SizedBox(width: 4),
                                                Text(
                                                  tr('مسؤول / Admin', 'Admin'),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                onPressed: () => store.warnUser(user, null),
                                                child: Text(tr('+ إنذار', '+ Warn')),
                                              ),
                                              FilledButton.tonal(
                                                style: FilledButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  visualDensity: VisualDensity.compact,
                                                  backgroundColor: isBanned
                                                      ? Colors.green.shade100
                                                      : Colors.red.shade100,
                                                ),
                                                onPressed: () => store.toggleBanUser(user),
                                                child: Text(
                                                  isBanned
                                                      ? tr('فك الحظر ✅', 'Unban')
                                                      : tr('حظر 🚫', 'Ban'),
                                                  style: TextStyle(
                                                    color: isBanned
                                                        ? Colors.green.shade900
                                                        : Colors.red.shade900,
                                                  ),
                                                ),
                                              ),
                                              if (!isCurrent)
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                  tooltip: tr('حذف المستخدم نهائياً', 'Delete User'),
                                                  onPressed: () async {
                                                    final ok = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: Text(tr('حذف حساب المستخدم', 'Delete Account')),
                                                        content: Text(tr(
                                                          'هل أنت متأكد من حذف حساب "${displayName(user)}" نهائياً من قاعدة البيانات والتطبيق؟',
                                                          'Are you sure you want to delete "${displayName(user)}" permanently?',
                                                        )),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(ctx, false),
                                                            child: Text(tr('إلغاء', 'Cancel')),
                                                          ),
                                                          FilledButton(
                                                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                            onPressed: () => Navigator.pop(ctx, true),
                                                            child: Text(tr('حذف نهائي', 'Delete')),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (ok == true) {
                                                      await store.deleteUser(user);
                                                    }
                                                  },
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

                // التبويب 5: قاعدة البيانات والربط السحابي (Supabase)
                const SupabaseCloudSetupPage(embedded: true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _adminStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
