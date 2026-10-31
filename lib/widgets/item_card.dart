part of '../main.dart';

// ======================= بطاقة السلعة =======================

class ItemCard extends StatelessWidget {
  final Item item;
  const ItemCard({super.key, required this.item});

  Widget _buildImage(ColorScheme scheme) {
    const double size = 90;
    if (item.imagePaths.isNotEmpty &&
        resolveSmartImageProvider(item.imagePaths.first) != null) {
      return Builder(
        builder: (context) => GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenImageViewer(
                  images: item.imagePaths,
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: Stack(
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
          ),
        ),
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
    final isFav = store.isFavorite(item.id);
    final isMyItem = store.isItemSeller(item);
    final isLeader = item.highestBidder != null && store.isUserMe(item.highestBidder!);
    final didBid = item.bids.any((b) => store.isUserMe(b.bidder));

    String? badge;
    Color? badgeColor;

    if (item.isCancelled) {
      badge = tr('ملغي', 'Cancelled');
      badgeColor = Colors.grey;
    } else if (isMyItem) {
      // سلعة خاصة بالمستخدم: تظهر الشارة باللون الأزرق فقط وبنص صريح سلعتك
      badge = tr('سلعتك', 'Your Item');
      badgeColor = const Color(0xFF1976D2);
    } else if (isLeader) {
      // المستخدم هو المتصدر: تظهر الشارة باللون الأخضر وبنص أنت الأعلى
      badge = tr('أنت الأعلى', 'Leading');
      badgeColor = const Color(0xFF388E3C);
    } else if (didBid) {
      // تجاوز المزايدة: تتحول الشارة للون الأحمر وبنص تم تجاوزك
      badge = tr('تم تجاوزك', 'Outbid');
      badgeColor = const Color(0xFFD32F2F);
    }

    // سجل عدد المزايدات بدون كشف هوية أي مزايد
    final bidsCountText = item.bids.isEmpty
        ? tr('0 مزايدة', '0 bids')
        : '${item.bids.length} ${tr("مزايدة", "bids")}';

    final locationText = item.area.isNotEmpty && item.area != 'المركز'
        ? '${item.location} - ${item.area}'
        : item.location;

    final timerColor = item.isEnded
        ? Colors.grey
        : (item.isScheduled ? Colors.orange.shade800 : const Color(0xFFE57373));

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
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الصورة المصغرة (Thumbnail): على أقصى اليمين، بإطار مربع بزوايا منحنية (12px)
                  _buildImage(scheme),
                  const SizedBox(width: 12),

                  // الجهة اليمنى: توزيع متوازن ومسافات متساوية بين: اسم السلعة، السعر، الموقع، وعدد المزايدات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // المستوى 1: اسم السلعة
                        Row(
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // المستوى 2: السعر الحالي (بنفس حجم وبروز اسم السلعة وبلون أخضر مميز)
                        Text(
                          formatPrice(item.currentPrice),
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),

                        // المستوى 3: الموقع الجغرافي (بخط فرعي مصغر)
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
                        const SizedBox(height: 5),

                        // المستوى 4: سجل عدد المزايدات (بنفس حجم الخط الفرعي المصغر وبدون كشف هوية المزايد)
                        Row(
                          children: [
                            Icon(
                              Icons.gavel,
                              size: 13,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                bidsCountText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // الجهة اليسرى: 3 مستويات رأسية متناسقة (أيقونة المفضلة، عداد الوقت، شارة الحالة)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // الأعلى: أيقونة المفضلة (القلب)
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

                      // المنتصف: عداد الوقت التنازلي مع أيقونة الساعة
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isScheduled
                                ? Icons.schedule
                                : Icons.timer_outlined,
                            size: 13,
                            color: timerColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.isCancelled
                                ? tr('ملغي', 'Cancelled')
                                : (item.isScheduled
                                    ? formatDuration(item.timeUntilStart)
                                    : formatDuration(item.timeLeft)),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: timerColor,
                            ),
                          ),
                        ],
                      ),

                      // الأسفل: شارة الحالة (أزرق: سلعتك / أخضر: أنت الأعلى / أحمر: تم تجاوزك)
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 22),
                    ],
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

