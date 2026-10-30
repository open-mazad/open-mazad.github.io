part of '../../main.dart';

// ======================= 6. لوحة تحكم الإدارة ونظام البلاغات =======================

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final totalAuctions = store.items.length;
          final activeAuctions =
              store.items.where((i) => !i.isEnded && !i.isScheduled).length;
          final scheduledAuctions =
              store.items.where((i) => i.isScheduled).length;
          final totalBidsVolume = store.items.fold<int>(
              0, (sum, i) => sum + (i.bids.isEmpty ? 0 : i.currentPrice));

          return Scaffold(
            appBar: AppBar(
              title: Text(tr('لوحة تحكم الإدارة والبلاغات 🛡️',
                  'Admin Dashboard & Reports 🛡️')),
              actions: [
                IconButton(
                  tooltip: tr('قاعدة البيانات السحابية (Supabase)',
                      'Supabase Cloud Setup'),
                  icon: const Icon(Icons.cloud_sync_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupabaseCloudSetupPage(),
                      ),
                    );
                  },
                ),
              ],
              bottom: TabBar(
                tabs: [
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
                    text: tr('المستخدمون والحظر', 'Users & Bans'),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // التبويب 1: الإحصائيات والبلاغات
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _adminStatCard(
                            tr('إجمالي المزادات', 'Total Auctions'),
                            '$totalAuctions',
                            Icons.gavel,
                            Colors.indigo),
                        _adminStatCard(
                            tr('مزادات جارية', 'Active Now'),
                            '$activeAuctions',
                            Icons.play_circle_fill,
                            Colors.green),
                        _adminStatCard(
                            tr('قريباً (مجدولة)', 'Scheduled'),
                            '$scheduledAuctions',
                            Icons.schedule,
                            Colors.orange),
                        _adminStatCard(
                            tr('حجم المزايدات', 'Bid Volume'),
                            formatPrice(totalBidsVolume),
                            Icons.payments,
                            Colors.teal),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tr('سجل البلاغات والمتخلفين عن الدفع والشراء',
                          'Reports & Payment Defaulters'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (store.reports.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('لا توجد بلاغات حالياً')),
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        rep.isResolved
                                            ? tr('تمت المعالجة', 'Resolved')
                                            : tr('قيد المراجعة', 'Pending'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('${tr("السبب:", "Reason:")} ${rep.reason}'),
                                Text(
                                  '${tr("المبلِّغ:", "By:")} ${displayName(rep.reporter)} • ${ago(rep.time)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                                if (!rep.isResolved) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () =>
                                            store.warnUser(rep.reportedUser, rep.id),
                                        icon: const Icon(Icons.warning_amber,
                                            size: 16),
                                        label: Text(
                                            tr('توجيه إنذار ⚠️', 'Issue Warning')),
                                      ),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                            backgroundColor: Colors.red.shade700),
                                        onPressed: () =>
                                            store.banUser(rep.reportedUser, rep.id),
                                        icon: const Icon(Icons.block, size: 16),
                                        label: Text(tr('حظر وتجميد الحساب 🚫',
                                            'Ban Account 🚫')),
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

                // التبويب 2: إدارة الإعلانات
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: store.items.length,
                  itemBuilder: (context, i) {
                    final item = store.items[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(categoryIcon(item.category)),
                        title: Text(item.title),
                        subtitle: Text(
                            '${tr("البائع:", "Seller:")} ${displayName(item.seller)} • ${formatPrice(item.currentPrice)}'),
                        trailing: IconButton(
                          tooltip: tr('حذف الإعلان نهائياً', 'Delete Listing'),
                          icon: const Icon(Icons.delete_forever,
                              color: Colors.red),
                          onPressed: () => store.deleteItem(item),
                        ),
                      ),
                    );
                  },
                ),

                // التبويب 3: إدارة المستخدمين والحظر
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final user in store.allKnownUsers)
                      Builder(
                        builder: (context) {
                          final isBanned = store.bannedUsers.contains(user);
                          final warns = store.userWarnings[user] ?? 0;
                          final rating = store.getUserRating(user);
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(displayName(user).characters.first),
                              ),
                              title: Text(
                                  '${displayName(user)} ${user == me ? tr("(حسابك)", "(You)") : ""}'),
                              subtitle: Text(
                                  '⭐ ${rating.toStringAsFixed(1)} • ${tr("الإنذارات:", "Warnings:")} $warns'),
                              trailing: Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () =>
                                        store.warnUser(user, null),
                                    child: Text(tr('+ إنذار', '+ Warn')),
                                  ),
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: isBanned
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                    ),
                                    onPressed: () =>
                                        store.toggleBanUser(user),
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
                                  if (user != me)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      tooltip: tr(
                                          'حذف المستخدم نهائياً', 'Delete User'),
                                      onPressed: () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(tr('حذف حساب المستخدم',
                                                'Delete Account')),
                                            content: Text(tr(
                                              'هل أنت متأكد من حذف حساب "${displayName(user)}" نهائياً من قاعدة البيانات والتطبيق؟',
                                              'Are you sure you want to delete "${displayName(user)}" permanently?',
                                            )),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child:
                                                    Text(tr('إلغاء', 'Cancel')),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                    backgroundColor: Colors.red),
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text(
                                                    tr('حذف نهائي', 'Delete')),
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
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _adminStatCard(
      String label, String value, IconData icon, Color color) {
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
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

