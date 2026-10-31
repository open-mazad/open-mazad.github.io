part of '../main.dart';

// ======================= 4. قائمة مشاركة المزاد الذكية =======================

void showShareQrDialog(BuildContext context, Item item) => showShareDialog(context, item);

void showShareDialog(BuildContext context, Item item) {
  final scheme = Theme.of(context).colorScheme;
  final shareUrl = 'https://open-mazad.github.io/#/item/${item.id}';
  final shareText =
      '🔨 مزاد علني على منصة المزاد المفتوح: ${item.title}\n💰 السعر الحالي: ${formatPrice(item.currentPrice)}\n📍 الموقع: ${item.location} - ${item.area}\n🔗 رابط المزاد: $shareUrl${item.isPrivate ? "\n🔒 رمز PIN الخاص: ${item.pinCode}" : ""}';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.share, color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  tr('مشاركة المزاد', 'Share Listing'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // بطاقة المعاينة الذكية للسلعة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: item.imagePaths.isNotEmpty
                          ? buildSmartImage(
                              item.imagePaths.first,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: scheme.primaryContainer,
                              child: Icon(categoryIcon(item.category),
                                  color: scheme.primary),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tr("السعر الحالي:", "Current:")} ${formatPrice(item.currentPrice)}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📍 ${item.location} - ${item.area}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (item.isPrivate) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 16, color: Colors.brown),
                    const SizedBox(width: 6),
                    Text(
                      '${tr("رمز الدخول الخاص:", "Private PIN:")} ${item.pinCode}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.brown.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // رابط المشاركة القابل للنسخ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shareUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // زري الإجراء الذكيين: نسخ الرابط + مشاركة عبر...
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr(
                            'تم نسخ رابط المزاد إلى الحافظة بنجاح 📋',
                            'Auction link copied to clipboard 📋')),
                      ));
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(tr('نسخ الرابط', 'Copy Link')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final shared = await systemSharePlatform(
                        title: item.title,
                        text: shareText,
                        url: shareUrl,
                      );
                      if (!shared) {
                        Clipboard.setData(ClipboardData(text: shareText));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(tr(
                                'تم نسخ تفاصيل ورابط المزاد للمشاركة 📋',
                                'Auction details copied for sharing 📋')),
                          ));
                        }
                      }
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(tr('مشاركة عبر...', 'Share via...')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
