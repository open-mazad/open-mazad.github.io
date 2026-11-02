part of '../../main.dart';

// ======================= واجهة "ملفي" الشاملة (My Profile View) =======================

class MyProfileView extends StatefulWidget {
  final VoidCallback? onGoToSettings;
  const MyProfileView({super.key, this.onGoToSettings});

  @override
  State<MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<MyProfileView> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([settings, store]),
      builder: (context, _) {
        if (!settings.isLoggedIn) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_pin,
                              size: 64, color: scheme.primary),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr('الملف الشخصي', 'My Profile'),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr(
                            'سجّل الدخول لعرض تقييمك، ومتابعة مزايداتك وسلعك، وتعديل بيانات ملفك الشخصي.',
                            'Sign in to view your rating, track your bids and listings, and manage your profile.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () async {
                            final err = await settings.signInWithGoogle();
                            if (err != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
                          },
                          icon: const Icon(Icons.login),
                          label: Text(tr('تسجيل الدخول عبر Google',
                              'Sign in with Google')),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
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

        // بيانات المستخدم المسجل
        final userMe = me;
        final myName = settings.fullName.isNotEmpty
            ? settings.fullName
            : (displayName(userMe).isNotEmpty ? displayName(userMe) : tr('مستخدم', 'User'));
        final avgRating = store.getUserRating(userMe);
        final reviews = store.getUserReviews(userMe);
        final phone = settings.phone;
        final isPhone = RegExp(r'^0?7\d{9}$').hasMatch(phone);
        final phoneDisplay = isPhone
            ? '+964 ${phone.startsWith('0') ? phone.substring(1) : phone}'
            : phone;

        // المزادات التي شارك بها المستخدم
        final myBidsItems = store.items.where((i) {
          return i.bids.any((b) => b.bidder == userMe || store.isUserMe(b.bidder));
        }).toList();

        // المزادات التي يملكها المستخدم
        final myListedItems = store.items.where((i) {
          return i.seller == userMe || store.isItemSeller(i);
        }).toList();

        return RefreshIndicator(
          onRefresh: () => store.pullFromSupabase(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // 1. كارت الملف الشخصي العلوي
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildUserAvatar(userMe, radius: 36),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        myName,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified,
                                        color: Colors.blueAccent, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (phoneDisplay.isNotEmpty)
                                  Text(
                                    phoneDisplay,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                // التقييم بالنجوم
                                InkWell(
                                  onTap: () => showUserProfileSheet(context, userMe),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 20),
                                        const SizedBox(width: 4),
                                        Text(
                                          avgRating > 0
                                              ? avgRating.toStringAsFixed(1)
                                              : tr('جديد', 'New'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        Text(
                                          ' (${reviews.length} ${tr('تقييم', 'reviews')})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_ios,
                                            size: 11,
                                            color: scheme.onSurfaceVariant),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // زر تعديل الملف الشخصي
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfilePage()),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: Text(tr('تعديل الملف الشخصي', 'Edit Profile')),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. إحصائيات سريعة
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: tr('سلعي المعروضة', 'My Listings'),
                      value: '${myListedItems.length}',
                      icon: Icons.inventory_2_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: tr('التقييم', 'Rating'),
                      value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '5.0',
                      icon: Icons.star_rounded,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: tr('التقييمات', 'Reviews'),
                      value: '${reviews.length}',
                      icon: Icons.rate_review_outlined,
                      color: Colors.indigoAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 3. قسم "سلعي المعروضة" ثابت ودائم
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(
                      tr('سلعي المعروضة للبيع', 'My Listed Items'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${myListedItems.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              if (myListedItems.isEmpty)
                _buildEmptySection(
                  icon: Icons.inventory_2_outlined,
                  text: tr(
                    'لم تقم بإضافة أي سلعة للبيع بعد.\nاضغط على (أضف مزاداً) لعرض أول سلعة لك.',
                    'No listed items yet. Add an auction to start selling.',
                  ),
                )
              else
                for (final item in myListedItems)
                  _buildUserListingCard(context, item),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySection({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListingCard(BuildContext context, Item item) {
    final isEnded = item.isEnded;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ItemDetailsPage(item: item)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: item.imagePaths.isNotEmpty
                      ? buildSmartImage(
                          item.imagePaths.first,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.inventory_2, size: 24),
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
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tr('السعر الحالي:', 'Current Price:')} ${formatPrice(item.currentPrice)} • (${item.bids.length} ${tr('مزايدة', 'bids')})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isEnded ? Colors.grey : Colors.green)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isEnded
                            ? tr('منتهي', 'Ended')
                            : tr('مزاد نشط الآن 🟢', 'Active 🟢'),
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
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
