part of '../../main.dart';

// ======================= 3. ملف التقييمات والسمعة وعرض السلع =======================

void showUserProfileSheet(BuildContext context, String username) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => UserProfileSheet(username: username),
  );
}

class UserProfileSheet extends StatefulWidget {
  final String username;
  const UserProfileSheet({super.key, required this.username});

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  int activeTab = 0; // 0: السلع المعروضة, 1: التقييمات
  int selectedStars = 5;
  final reviewCtrl = TextEditingController();
  bool _initializedMyReview = false;

  @override
  void dispose() {
    reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> submitReview({required bool isUpdate}) async {
    final loggedIn = await ensureUserLoggedIn(
      context,
      reason: tr(
        'يجب تسجيل الدخول بحسابك أولاً لتقييم المستخدم وإضافة مراجعة ⭐',
        'Please sign in to rate this user and leave a review ⭐',
      ),
    );
    if (!loggedIn || !mounted) return;

    final comment = reviewCtrl.text.trim();
    if (comment.isEmpty) return;
    store.addReview(widget.username, selectedStars, comment);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isUpdate
          ? tr('تم تحديث تقييمك بنجاح ⭐', 'Review updated successfully ⭐')
          : tr('تمت إضافة تقييمك بنجاح ⭐', 'Review submitted successfully ⭐')),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.username;
    final mq = MediaQuery.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final avg = store.getUserRating(u);
        final reviews = store.getUserReviews(u);
        final warnings = store.userWarnings[u] ?? 0;
        final isBanned = store.bannedUsers.contains(u);
        final isMe = store.isUserMe(u);
        final hasDeal = store.hasTransactionBetween(u, me);
        final myReview = reviews.where((r) => store.isUserMe(r.reviewer)).firstOrNull;

        if (!_initializedMyReview && myReview != null) {
          _initializedMyReview = true;
          selectedStars = myReview.stars;
          reviewCtrl.text = myReview.comment;
        }

        // السلع والمزادات المعروضة بواسطة هذا المستخدم
        final userListings = store.items.where((it) {
          return it.seller == u ||
              store.isSameUser(it.seller, u) ||
              (isMe && store.isItemSeller(it));
        }).toList();

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mq.size.height * 0.85,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: mq.viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. رأس الملف التعريفي للمستخدم
                  Row(
                    children: [
                      buildUserAvatar(u, radius: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName(u),
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (store.isUserVerified(u))
                                  const Icon(Icons.verified,
                                      color: Colors.blue, size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '${avg.toStringAsFixed(1)} (${reviews.length} ${tr("تقييم", "reviews")})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '• ${userListings.length} ${tr("سلعة معروضة", "items listed")}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isBanned)
                        Chip(
                          backgroundColor: Colors.red.shade100,
                          label: Text(tr('محظور 🚫', 'Banned 🚫'),
                              style: const TextStyle(color: Colors.red)),
                        )
                      else if (warnings > 0)
                        Chip(
                          backgroundColor: Colors.orange.shade100,
                          label: Text(
                              tr('إنذارات: $warnings ⚠️', 'Warnings: $warnings ⚠️'),
                              style: TextStyle(color: Colors.orange.shade900)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. أزرار التبديل بين السلع والتقييمات
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: Text(
                            '${tr("السلع المعروضة", "Listings")} (${userListings.length})'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: Text(
                            '${tr("التقييمات والآراء", "Reviews")} (${reviews.length})'),
                      ),
                    ],
                    selected: {activeTab},
                    onSelectionChanged: (set) =>
                        setState(() => activeTab = set.first),
                  ),
                  const SizedBox(height: 14),

                  // 3. المحتوى حسب التبويب المختار
                  if (activeTab == 0) ...[
                    // تبويب السلع المعروضة للبيع
                    if (userListings.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              tr(
                                'لا توجد سلع معروضة حالياً لهذا المستخدم.',
                                'No items listed by this user yet.',
                              ),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final it in userListings)
                        _buildUserListingCard(context, it),
                  ] else ...[
                    // تبويب آراء وتقييمات المتعاملين
                    if (reviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          tr('لا توجد مراجعات مكتوبة بعد.', 'No reviews yet.'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      for (final r in reviews)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_pin,
                              color: Color(0xFF2F80ED)),
                          title: Row(
                            children: [
                              Text(displayName(r.reviewer),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              for (int i = 0; i < r.stars; i++)
                                const Icon(Icons.star_rounded,
                                    size: 15, color: Colors.amber),
                            ],
                          ),
                          subtitle: Text(r.comment),
                          trailing: Text(ago(r.time),
                              style: const TextStyle(fontSize: 11)),
                        ),

                    // قسم إضافة/تعديل التقييم
                    if (!isMe) ...[
                      const Divider(height: 24),
                      if (!hasDeal) ...[
                        // تنبيه عدم وجود صفقة بيع/شراء
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr(
                                    '🔒 التقييم متاح فقط بعد إتمام معاملة بيع أو شراء بينكما لضمان مصداقية التقييمات.',
                                    '🔒 Reviews are only allowed after a completed buy or sell transaction.',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // حقل التقييم المتاح لوجود معاملة
                        Text(
                          myReview != null
                              ? tr('تعديل تقييمك لهذا المستخدم ⭐',
                                  'Update your review for this user ⭐')
                              : tr('أضف تقييمك لهذا المستخدم ⭐',
                                  'Rate this user ⭐'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            for (int s = 1; s <= 5; s++)
                              IconButton(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    setState(() => selectedStars = s),
                                icon: Icon(
                                  s <= selectedStars
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: Colors.amber,
                                  size: 28,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: reviewCtrl,
                                decoration: InputDecoration(
                                  hintText: tr('اكتب تجربتك في التعامل...',
                                      'Write your review...'),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () =>
                                  submitReview(isUpdate: myReview != null),
                              child: Text(myReview != null
                                  ? tr('تحديث', 'Update')
                                  : tr('إرسال', 'Post')),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserListingCard(BuildContext context, Item item) {
    final isEnded = item.isEnded;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ItemDetailsPage(item: item)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 58,
                  height: 58,
                  color: Colors.grey.withValues(alpha: 0.15),
                  child: item.imagePaths.isNotEmpty
                      ? buildSmartImage(
                          item.imagePaths.first,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(item.currentPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF2F80ED),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isEnded
                      ? Colors.grey.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isEnded
                      ? tr('منتهي', 'Ended')
                      : (item.isScheduled
                          ? tr('قريباً', 'Upcoming')
                          : tr('جارٍ 🔴', 'Live 🔴')),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isEnded ? Colors.grey : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

