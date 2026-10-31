part of '../main.dart';

// ======================= بطاقة السلعة =======================

class ItemCard extends StatelessWidget {
  final Item item;
  const ItemCard({super.key, required this.item});

  Widget _buildImage(ColorScheme scheme) {
    const double size = 90;
    if (item.imagePaths.isNotEmpty &&
        resolveSmartImageProvider(item.imagePaths.first) != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: buildSmartImage(
              item.imagePaths.first,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          if (item.imagePaths.length > 1)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${item.imagePaths.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      );
    }
    return _fallbackAvatar(scheme);
  }

  Widget _fallbackAvatar(ColorScheme scheme) {
    const double size = 90;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(categoryIcon(item.category),
          size: 34, color: scheme.onSurfaceVariant),
    );
  }

  Future<void> _openItem(BuildContext context) async {
    if (item.isPrivate && !store.isPrivateUnlocked(item)) {
      final ctrl = TextEditingController();
      final unlocked = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      tr('غرفة مزاد خاصة برمز PIN', 'Private PIN Auction'))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(
                'هذا المزاد مغلق للمدعوين فقط. أدخل الرمز السري (PIN) للدخول والمزايدة:',
                'This auction is private. Enter the PIN code to enter:',
              )),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (store.unlockPrivateItem(item, ctrl.text)) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr('رمز PIN غير صحيح ❌', 'Invalid PIN ❌')),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              child: Text(tr('دخول الغرفة', 'Unlock')),
            ),
          ],
        ),
      );
      if (unlocked != true || !context.mounted) return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ItemDetailsPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iBid = item.bids.any((b) => b.bidder == me);
    final isFav = store.isFavorite(item.id);

    String? badge;
    Color badgeColor = Colors.grey;

    if (item.isCancelled) {
      badge = tr('ملغي 🚫', 'Cancelled 🚫');
      badgeColor = Colors.red.shade700;
    } else if (item.isScheduled) {
      badge = tr('قريباً ⏳', 'Upcoming ⏳');
      badgeColor = Colors.orange.shade800;
    } else if (item.isEndedEarlyBySeller) {
      badge = item.highestBidder == me
          ? tr('فزت بموافقة البائع 🎉', 'Won (Seller Approved) 🎉')
          : '${tr("تم البيع", "Sold")} (${item.highestBidder}) 🤝';
      badgeColor = Colors.green.shade700;
    } else if (item.isEnded) {
      badge = item.highestBidder == me
          ? tr('فزت 🎉', 'You Won 🎉')
          : tr('انتهى', 'Ended');
      badgeColor = item.highestBidder == me ? Colors.green : Colors.grey;
    } else if (item.seller == me) {
      badge = item.bids.isEmpty
          ? tr('سلعتك (بدون عروض)', 'Your Item (No bids)')
          : '${tr("سلعتك • الأعلى:", "Yours • Top:")} ${item.highestBidder}';
      badgeColor = Colors.indigo;
    } else if (item.highestBidder == me) {
      badge = tr('أنت الأعلى 👍', 'Leading 👍');
      badgeColor = Colors.green;
    } else if (iBid) {
      badge = tr('تم تجاوزك ⚠️', 'Outbid ⚠️');
      badgeColor = Colors.redAccent;
    }

    // ملخص المزايدات للسطر الرابع
    String bidsSummary;
    if (item.bids.isNotEmpty) {
      final topBidder = item.highestBidder != null ? displayName(item.highestBidder!) : '';
      bidsSummary = '${item.bids.length} ${tr("مزايدة", "bids")} • $topBidder (${tr("أعلى مزايدة", "Top Bid")})';
    } else if (item.seller == me) {
      bidsSummary = tr('سلعتك (بدون عروض)', 'Your Item (No bids)');
    } else {
      bidsSummary = tr('0 مزايدة • بدون عروض', '0 bids • No bids');
    }

    final locationText = item.area.isNotEmpty && item.area != 'المركز'
        ? '${item.location} - ${item.area}'
        : item.location;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _openItem(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // الصورة المصغرة (Thumbnail): على أقصى اليمين، بإطار مربع بزوايا منحنية (12px)
                _buildImage(scheme),
                const SizedBox(width: 12),

                // منطقة البيانات (Flex-Column): تشغل المساحة المتبقية على يسار الصورة ومقسمة إلى 4 مستويات رأسية
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // الصف الأول: عنوان السلعة بخط عريض على اليمين، يقابله زر المفضلة على أقصى اليسار
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.isPrivate) ...[
                                  const Icon(Icons.lock, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : Colors.grey.shade400,
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => store.toggleFavorite(item.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // الصف الثاني: السعر الحالي بخط بارز ولون أخضر مميز على اليمين، يقابله العداد التنازلي مع أيقونة الساعة على أقصى اليسار
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            formatPrice(item.currentPrice),
                            style: const TextStyle(
                              color: Color(0xFF4CAF50), // لون أخضر بارز ومميز
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.isCancelled
                                    ? tr('ملغي', 'Cancelled')
                                    : (item.isScheduled
                                        ? formatDuration(item.timeUntilStart)
                                        : formatDuration(item.timeLeft)),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: item.isEnded
                                      ? Colors.grey
                                      : (item.isScheduled
                                          ? Colors.orange.shade800
                                          : const Color(0xFFE57373)), // لون أحمر/وردي متناسق
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                item.isScheduled
                                    ? Icons.schedule
                                    : Icons.timer_outlined,
                                size: 15,
                                color: item.isEnded
                                    ? Colors.grey
                                    : (item.isScheduled
                                        ? Colors.orange.shade800
                                        : const Color(0xFFE57373)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // الصف الثالث: الموقع الجغرافي بتنسيق (أيقونة الموقع + المحافظة - المنطقة/القضاء)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // الصف الرابع: ملخص المزايدات بخط فرعي أصغر بتنسيق: [عدد] مزايدة • [اسم المستخدم] (أعلى مزايدة)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bidsSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
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
    );
  }
}

