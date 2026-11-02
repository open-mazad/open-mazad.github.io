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
        final isVerified = store.isUserVerified(userMe);

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
                        children: [
                          buildUserAvatar(userMe, radius: 34),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    myName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified,
                                      color: Colors.blueAccent, size: 19),
                                ],
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

              const SizedBox(height: 16),

              // 2. قسم التقييمات والآراء (Customer Reviews)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_outlined, size: 20, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      tr('تقييمات وآراء المتعاملين', 'Customer Reviews'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            avgRating > 0
                                ? '${avgRating.toStringAsFixed(1)} (${reviews.length})'
                                : tr('0 تقييم', '0 reviews'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              if (reviews.isEmpty)
                _buildEmptySection(
                  icon: Icons.rate_review_outlined,
                  text: tr(
                    'لا توجد أي تقييمات مسجلة لك حتى الآن.\nستظهر تقييمات المشترين وآراؤهم هنا فور إتمام أول معاملة بيع أو شراء.',
                    'No reviews yet. Customer reviews will appear here after completed transactions.',
                  ),
                )
              else
                for (final review in reviews)
                  _buildReviewCard(context, review),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(BuildContext context, UserReview review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                buildUserAvatar(review.reviewer, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName(review.reviewer),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        formatRelativeTime(review.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: i < review.stars
                          ? Colors.amber
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review.comment,
                style: const TextStyle(fontSize: 13),
              ),
            ],
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
}
