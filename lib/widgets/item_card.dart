part of '../main.dart';

// ======================= بطاقة السلعة =======================

class ItemCard extends StatelessWidget {
  final Item item;
  const ItemCard({super.key, required this.item});

  Widget _buildImage(ColorScheme scheme) {
    if (item.imagePaths.isNotEmpty &&
        resolveSmartImageProvider(item.imagePaths.first) != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: buildSmartImage(
              item.imagePaths.first,
              width: 76,
              height: 76,
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
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(categoryIcon(item.category),
          size: 30, color: scheme.onPrimaryContainer),
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

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => _openItem(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(scheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.isPrivate) ...[
                          const Icon(Icons.lock,
                              size: 15, color: Colors.amber),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatPrice(item.currentPrice),
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (item.bids.isNotEmpty)
                          Text(
                            '(${tr("البداية:", "Start:")} ${formatPrice(item.startPrice)})',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        if (item.buyNowPrice != null && item.buyNowPrice! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade600, width: 0.8),
                            ),
                            child: Text(
                              '${tr("شراء فوري:", "Buy Now:")} ${formatPrice(item.buyNowPrice!)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.bids.length} ${tr("مزايدة", "bids")} • ${item.location} (${item.area}) • ${item.deliveryMethod}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (item.videoPath != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.videocam_outlined,
                              size: 14, color: Colors.indigo),
                          const SizedBox(width: 4),
                          Text(tr('فيديو مرفق', 'Attached Video'),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.indigo)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : Colors.grey,
                      size: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => store.toggleFavorite(item.id),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isScheduled
                            ? Icons.schedule
                            : Icons.timer_outlined,
                        size: 14,
                        color: item.isEnded
                            ? Colors.grey
                            : (item.isScheduled
                                ? Colors.orange.shade800
                                : scheme.error),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.isCancelled
                            ? tr('ملغي', 'Cancelled')
                            : (item.isScheduled
                                ? formatDuration(item.timeUntilStart)
                                : formatDuration(item.timeLeft)),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.isEnded
                              ? Colors.grey
                              : (item.isScheduled
                                  ? Colors.orange.shade800
                                  : scheme.error),
                        ),
                      ),
                    ],
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

