part of '../../main.dart';

// ======================= 3. ملف التقييمات والسمعة والإبلاغ =======================

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
  int selectedStars = 5;
  final reviewCtrl = TextEditingController();

  @override
  void dispose() {
    reviewCtrl.dispose();
    super.dispose();
  }

  void submitReview() {
    final comment = reviewCtrl.text.trim();
    if (comment.isEmpty) return;
    store.addReview(widget.username, selectedStars, comment);
    reviewCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('تمت إضافة تقييمك بنجاح ⭐', 'Review submitted ⭐')),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.username;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final avg = store.getUserRating(u);
        final reviews = store.getUserReviews(u);
        final warnings = store.userWarnings[u] ?? 0;
        final isBanned = store.bannedUsers.contains(u);

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              Text(
                                displayName(u),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              if (!isBanned && warnings == 0)
                                const Icon(Icons.verified,
                                    color: Colors.blue, size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${avg.toStringAsFixed(1)} (${reviews.length} ${tr("تقييم", "reviews")})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
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
                const Divider(height: 24),
                Text(tr('آراء وتقييمات المتعاملين', 'User Reviews'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (reviews.isEmpty)
                  Text(tr('لا توجد مراجعات مكتوبة بعد.', 'No reviews yet.'),
                      style: const TextStyle(color: Colors.grey))
                else
                  for (final r in reviews.take(4))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_pin, color: Colors.indigo),
                      title: Row(
                        children: [
                          Text(displayName(r.reviewer),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          for (int i = 0; i < r.stars; i++)
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                        ],
                      ),
                      subtitle: Text(r.comment),
                      trailing: Text(ago(r.time),
                          style: const TextStyle(fontSize: 11)),
                    ),
                if (u != me) ...[
                  const Divider(height: 24),
                  Text(tr('أضف تقييمك لهذا المستخدم', 'Rate this user'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      for (int s = 1; s <= 5; s++)
                        IconButton(
                          onPressed: () => setState(() => selectedStars = s),
                          icon: Icon(
                            s <= selectedStars ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
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
                        onPressed: submitReview,
                        child: Text(tr('إرسال', 'Post')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

