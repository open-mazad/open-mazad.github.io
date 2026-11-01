part of '../../main.dart';

// ======================= صفحة تفاصيل السلعة =======================

class ItemDetailsPage extends StatefulWidget {
  final Item item;
  const ItemDetailsPage({super.key, required this.item});

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  final amountCtrl = TextEditingController();
  final commentCtrl = TextEditingController();
  int currentImageIndex = 0;
  late final PageController _imagePageCtrl;
  Timer? _imageAutoSlideTimer;

  Item get liveItem => store.items.firstWhere(
        (it) =>
            it.id == widget.item.id ||
            AuctionStore.itemToUuid(it.id) ==
                AuctionStore.itemToUuid(widget.item.id),
        orElse: () => widget.item,
      );

  @override
  void initState() {
    super.initState();
    _imagePageCtrl = PageController();
    _startImageTimer();
  }

  void _startImageTimer() {
    _imageAutoSlideTimer?.cancel();
    _imageAutoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_imagePageCtrl.hasClients) return;
      final validImages = liveItem.imagePaths
          .where((p) => resolveSmartImageProvider(p) != null)
          .toList();
      if (validImages.length <= 1) return;
      final next = (currentImageIndex + 1) % validImages.length;
      _imagePageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _imageAutoSlideTimer?.cancel();
    _imagePageCtrl.dispose();
    amountCtrl.dispose();
    commentCtrl.dispose();
    super.dispose();
  }

  Future<void> submitManualBid() async {
    final loggedIn = await ensureUserLoggedIn(
      context,
      reason: tr(
        'يجب تسجيل الدخول بحسابك أولاً لتقديم مزايدة على هذه السلعة 🔨',
        'Please sign in first to place a bid on this item 🔨',
      ),
    );
    if (!loggedIn || !mounted) return;

    if (settings.needsProfileOnboarding) {
      await showCompleteProfileDialog(context);
      if (!mounted || settings.needsProfileOnboarding) return;
    }
    // منع البائع من المزايدة على سلعته الخاصة
    if (store.isItemSeller(liveItem)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'لا يمكنك المزايدة على سلعتك الخاصة 🚫',
          'You cannot bid on your own item 🚫',
        )),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }
    // منع المزايدة المتتالية (Spam Prevention): التحقق من آخر مزايد
    final lastBidder = liveItem.highestBidder ??
        (liveItem.bids.isNotEmpty ? liveItem.bids.first.bidder : null);
    if (lastBidder != null && store.isUserMe(lastBidder)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'أنت صاحب أعلى مزايدة حالياً 🥇، لا يمكنك المزايدة مجدداً حتى يتجاوز مزايدتك طرف آخر',
          'You are currently the highest bidder 🥇, you cannot bid again until outbid',
        )),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }

    final amount =
        int.tryParse(toLatinDigits(amountCtrl.text.trim()).replaceAll(',', ''));
    if (amount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('اكتب مبلغاً صحيحاً بالأرقام', 'Enter a valid number')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // فحص عدم تجاوز السعر النهائي (إذا كان محدداً من قبل البائع)
    if (liveItem.buyNowPrice != null &&
        liveItem.buyNowPrice! > 0 &&
        amount > liveItem.buyNowPrice!) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'لا يمكن أن يتجاوز مبلغ المزايدة السعر النهائي (${formatPrice(liveItem.buyNowPrice!)}). يمكنك الشراء الفوري بالسعر النهائي.',
          'Bid cannot exceed the final buy-now price (${formatPrice(liveItem.buyNowPrice!)}). You can buy now directly.',
        )),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }

    final error = store.placeBid(liveItem, amount);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? tr('تمت المزايدة بنجاح ✅', 'Bid placed ✅')),
      backgroundColor: error == null ? Colors.green : Colors.red,
    ));
    if (error == null) amountCtrl.clear();
  }

  Future<void> submitComment() async {
    final loggedIn = await ensureUserLoggedIn(
      context,
      reason: tr(
        'يجب تسجيل الدخول أولاً لإضافة تعليق أو استفسار على هذا المزاد 💬',
        'Please sign in to post a comment or inquiry on this auction 💬',
      ),
    );
    if (!loggedIn || !mounted) return;

    final txt = commentCtrl.text.trim();
    if (txt.isEmpty) return;
    final err = store.addComment(liveItem, txt);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    commentCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> showReportDialog() async {
    final item = liveItem;
    final target = store.isItemSeller(item)
        ? (item.highestBidder ?? 'مزايد')
        : item.seller;
    final reasonCtrl = TextEditingController();
    String selectedPreset = 'تخلف عن الدفع وإتمام الشراء بعد الفوز';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report_gmailerrorred, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(tr('إبلاغ عن مخالفة / تخلف عن الدفع',
                      'Report Non-Payment or Fraud'))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tr("الإبلاغ ضد:", "Reporting:")} ${displayName(target)}'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedPreset,
                isExpanded: true,
                items: [
                  'تخلف عن الدفع وإتمام الشراء بعد الفوز',
                  'مزايدة وهمية لرفع السعر (تلاعب)',
                  'مواصفات غير مطابقة للواقع',
                  'سبب آخر',
                ]
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setSt(() => selectedPreset = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('تفاصيل إضافية للإدارة', 'Additional details'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء', 'Cancel')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send),
              label: Text(tr('إرسال البلاغ للإدارة', 'Submit Report')),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final extra = reasonCtrl.text.trim();
      store.submitReport(
        item: item,
        reportedUser: target,
        reason: extra.isEmpty ? selectedPreset : '$selectedPreset - $extra',
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'تم رفع البلاغ إلى لوحة الإدارة لمراجعته واتخاذ إجراء الإنذار أو الحظر 🛡️',
          'Report sent to Admin Dashboard for review 🛡️',
        )),
        backgroundColor: Colors.orange.shade900,
      ));
    }
  }

  Future<void> showEditAuctionDialog() async {
    final item = liveItem;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemPage(itemToEdit: item),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> confirmAcceptHighestBid() async {
    final item = liveItem;
    final topBidder = item.highestBidder;
    if (topBidder == null) return;
    final price = formatPrice(item.currentPrice);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    tr('قبول أعلى مزايدة', 'Accept Highest Bid'))),
          ],
        ),
        content: Text(
          tr(
            'هل توافق على بيع "${item.title}" إلى صاحب أعلى مزايدة ($topBidder) بمبلغ $price؟\n\nسيُعتمد $topBidder فائزاً بالسلعة فوراً.',
            'Accept highest bid of $price from $topBidder for "${item.title}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('تراجع', 'Cancel')),
          ),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle),
            label: Text(
                tr('قبول المزايدة واعتماد البيع', 'Accept Bid & Confirm Sale')),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final err = store.endAuctionAndSellToHighest(item);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            err ?? 'تم قبول أعلى مزايدة وبيع السلعة إلى $topBidder بمبلغ $price ✅'),
        backgroundColor: err == null ? Colors.green.shade700 : Colors.red,
      ));
    }
  }

  Future<void> confirmBuyNow(Item item) async {
    if (item.buyNowPrice == null || item.buyNowPrice! <= 0) return;

    // تقييد عملية الشراء الفوري (Auth Guard)
    final loggedIn = await ensureUserLoggedIn(
      context,
      reason: tr(
        'يجب تسجيل الدخول بحسابك أولاً لتتمكن من استخدام خاصية الشراء الفوري وحسم الصفقة.',
        'You must sign in first to use Buy Now and complete the purchase.',
      ),
    );
    if (!loggedIn || !mounted) return;

    // فحص الحظر الإداري
    if (store.bannedUsers.contains(me) ||
        store.bannedUsers.contains(AuctionStore.userToUuid(me))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('حسابك مجمّد بقرار إداري 🚫', 'Your account is suspended by admin 🚫')),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    // فحص الحظر الشخصي المتبادل بين الطرفين
    if (store.isMutualOrBlockedBetween(item.seller, me)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'لا يمكنك إتمام الشراء الفوري بسبب وجود حظر نشط بينك وبين صاحب هذا المزاد 🚫',
          'Cannot complete buy now due to an active block between you and the seller 🚫',
        )),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    final priceStr = formatPrice(item.buyNowPrice!);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('تأكيد الشراء الفوري', 'Confirm Buy Now'))),
          ],
        ),
        content: Text(
          tr(
            'هل أنت متأكد من رغبتك في شراء "${item.title}" فوراً بالسعر النهائي ($priceStr)؟\n\nسيتم حسم الصفقة وإقفال المزاد وتثبيت فوزك بالسلعة مباشرة.',
            'Are you sure you want to buy "${item.title}" now for $priceStr? The auction will close and you will win immediately.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle),
            label: Text(tr('نعم، شراء فوري الآن ⚡', 'Yes, Buy Now ⚡')),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final err = store.buyNow(item);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? tr('تمت عملية الشراء الفوري وإقفال المزاد بنجاح 🎉', 'Buy Now completed successfully 🎉')),
        backgroundColor: err == null ? Colors.green.shade700 : Colors.red,
      ));
    }
  }

  Future<void> confirmDeleteItem() async {
    final item = liveItem;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('حذف السلعة', 'Delete Item'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          tr(
            'هل تريد حذف السلعة؟',
            'Do you want to delete this listing?',
          ),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('تراجع', 'Cancel')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(tr('حذف', 'Delete')),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    store.deleteItem(item);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(tr('تم حذف السلعة نهائياً 🗑️', 'Listing deleted 🗑️')),
      backgroundColor: Colors.red.shade800,
    ));
  }

  void _showBidderActionsSheet(Item item, Bid bid, bool isTopBid) {
    final bidder = bid.bidder;
    final isMe = store.isUserMe(bidder);
    final isSeller = store.isItemSeller(item);
    final canDelete = isSeller || isMe || settings.isAdmin;
    final isBlocked = store.isUserBlockedByMe(bidder);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      buildUserAvatar(bidder, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName(bidder),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isTopBid) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tr('أعلى مزايدة 👑', 'Top Bid 👑'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${tr("المبلغ:", "Amount:")} ${formatPrice(bid.amount)} • ${ago(bid.time)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          showUserProfileSheet(context, bidder);
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(tr('الملف الشخصي', 'Profile')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline,
                        color: Colors.blue, size: 20),
                  ),
                  title: Text(
                    tr('مراسلة المزايد', 'Message Bidder'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    tr('توجيه فوري لفتح محادثة مباشرة مع صاحب المزايدة',
                        'Open direct chat with bidder'),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleMessageBidder(item, bidder);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline,
                        color: Colors.red.shade700, size: 20),
                  ),
                  title: Text(
                    tr('حذف المزايدة', 'Delete Bid'),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700),
                  ),
                  subtitle: Text(
                    tr('استبعاد وحذف المزايدة المحددة من السجل',
                        'Remove bid from history'),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleDeleteBid(item, bid, canDelete);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.flag_outlined,
                        color: Colors.orange.shade800, size: 20),
                  ),
                  title: Text(
                    tr('إبلاغ عن المزايدة', 'Report Bid'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    tr('رفع تقرير بمخالفة ضد المستخدم أو قيمة المزايدة',
                        'Submit violation report against user or bid value'),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleReportBidder(item, bid);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isBlocked ? Colors.teal : Colors.purple)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBlocked ? Icons.lock_open : Icons.block,
                      color: isBlocked ? Colors.teal : Colors.purple,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isBlocked
                        ? tr('إلغاء حظر المزايد', 'Unblock Bidder')
                        : tr('حظر المزايد من الإعلان', 'Block Bidder from Listing'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isBlocked ? Colors.teal : Colors.purple,
                    ),
                  ),
                  subtitle: Text(
                    isBlocked
                        ? tr('إلغاء الحظر والسماح له بتقديم عروض مجدداً',
                            'Unblock and allow user to bid again')
                        : tr('حظر حساب المزايد نهائياً من تقديم أي عروض مستقبلية على الإعلان',
                            'Block user permanently from making future bids'),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleBlockBidder(item, bidder, isBlocked);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMessageBidder(Item item, String bidder) async {
    if (store.isUserMe(bidder)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('لا يمكنك مراسلة نفسك 🚫', 'You cannot message yourself 🚫')),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }

    final loggedIn = await ensureUserLoggedIn(
      context,
      reason: tr(
        'يجب تسجيل الدخول لمراسلة هذا المزايد 💬',
        'Please sign in to message this bidder 💬',
      ),
    );
    if (!loggedIn || !mounted) return;

    if (store.isMutualOrBlockedBetween(bidder, me)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'لا يمكنك مراسلة هذا المستخدم بسبب وجود حظر نشط بينكما 🚫',
          'Cannot message this user due to an active block 🚫',
        )),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatPage(
          item: item,
          otherParty: bidder,
        ),
      ),
    );
  }

  Future<void> _handleDeleteBid(Item item, Bid bid, bool canDelete) async {
    final loggedIn = await ensureUserLoggedIn(
      context,
      reason: tr(
        'يجب تسجيل الدخول أولاً لإجراء هذا التعديل',
        'Please sign in first',
      ),
    );
    if (!loggedIn || !mounted) return;

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'صاحب الإعلان فقط (أو صاحب المزايدة) يمكنه حذف واستبعاد هذه المزايدة 🚫',
          'Only the seller or bidder can delete this bid 🚫',
        )),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('تأكيد حذف المزايدة', 'Confirm Delete Bid'))),
          ],
        ),
        content: Text(
          tr(
            'هل أنت متأكد من رغبتك في استبعاد وحذف المزايدة بقيمة (${formatPrice(bid.amount)}) المقدمة من "${displayName(bid.bidder)}"؟\n\nسيتم تحديث السعر وصاحب أعلى مزايدة تلقائياً.',
            'Are you sure you want to delete bid (${formatPrice(bid.amount)}) by "${displayName(bid.bidder)}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: Text(tr('نعم، حذف واستبعاد', 'Yes, Delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final err = await store.deleteBid(item, bid);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(
            'تم حذف المزايدة واستبعادها من السجل بنجاح 🗑️',
            'Bid deleted successfully 🗑️',
          )),
          backgroundColor: Colors.green.shade700,
        ));
      }
    }
  }

  Future<void> _handleReportBidder(Item item, Bid bid) async {
    final bidder = bid.bidder;
    if (store.isUserMe(bidder)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('لا يمكنك الإبلاغ عن نفسك 🚫', 'You cannot report yourself 🚫')),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }

    final loggedIn = await ensureUserLoggedIn(
      context,
      reason: tr(
        'يجب تسجيل الدخول لرفع بلاغ للإدارة 🚨',
        'Please sign in to submit a report 🚨',
      ),
    );
    if (!loggedIn || !mounted) return;

    final reasonCtrl = TextEditingController();
    String selectedPreset = 'مزايدة وهمية لرفع السعر (تلاعب)';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report_gmailerrorred, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr('إبلاغ عن مزايدة / مستخدم', 'Report Bid or User')),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tr("المشكو في حقه:", "Reported user:")} ${displayName(bidder)}'),
              const SizedBox(height: 4),
              Text(
                '${tr("قيمة المزايدة:", "Bid amount:")} ${formatPrice(bid.amount)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedPreset,
                isExpanded: true,
                items: [
                  'مزايدة وهمية لرفع السعر (تلاعب)',
                  'مزايدة غير جادة أو تعجيزية',
                  'حساب مشبوه أو احتيالي',
                  'تخلف عن التواصل أو السداد',
                  'سبب آخر',
                ]
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setSt(() => selectedPreset = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('تفاصيل إضافية للإدارة', 'Additional details'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء', 'Cancel')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send),
              label: Text(tr('إرسال البلاغ للإدارة', 'Submit Report')),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final extra = reasonCtrl.text.trim();
      final fullReason =
          'مزايدة بقيمة ${formatPrice(bid.amount)}: ${extra.isEmpty ? selectedPreset : "$selectedPreset - $extra"}';
      store.submitReport(
        item: item,
        reportedUser: bidder,
        reason: fullReason,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'تم رفع البلاغ إلى لوحة الإدارة لمراجعته واتخاذ إجراء الإنذار أو الحظر 🛡️',
          'Report sent to Admin Dashboard for review 🛡️',
        )),
        backgroundColor: Colors.orange.shade900,
      ));
    }
  }

  Future<void> _handleBlockBidder(Item item, String bidder, bool isCurrentlyBlocked) async {
    if (store.isUserMe(bidder)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('لا يمكنك حظر حسابك الخاص 🚫', 'You cannot block yourself 🚫')),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }

    final loggedIn = await ensureUserLoggedIn(
      context,
      reason: tr(
        'يجب تسجيل الدخول لإدارة الحظر',
        'Please sign in to manage blocks',
      ),
    );
    if (!loggedIn || !mounted) return;

    if (isCurrentlyBlocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_open, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('إلغاء حظر المزايد', 'Unblock Bidder'))),
            ],
          ),
          content: Text(
            tr(
              'هل تريد إلغاء حظر "${displayName(bidder)}"؟\nسيتمكن المستخدم من المزايدة على إعلاناتك ومراسلتك مجدداً.',
              'Do you want to unblock "${displayName(bidder)}"?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('نعم، إلغاء الحظر', 'Yes, Unblock')),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        store.unblockUser(bidder);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('تم إلغاء حظر المزايد بنجاح', 'Bidder unblocked successfully')),
          backgroundColor: Colors.teal,
        ));
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.block, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('حظر المزايد من الإعلان', 'Block Bidder from Listing'))),
            ],
          ),
          content: Text(
            tr(
              'هل تريد حظر "${displayName(bidder)}" نهائياً؟\n\n• سيتم حظر المزايد نهائياً من تقديم أي عروض أو مزايدات مستقبلية على هذا الإعلان وكافة إعلاناتك.\n• لن يتمكن من استخدام الشراء الفوري أو التعليق أو مراسلتك.',
              'Are you sure you want to block "${displayName(bidder)}"? They will be prevented from bidding on any of your items.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء', 'Cancel')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.block),
              label: Text(tr('نعم، حظر المزايد 🚫', 'Yes, Block 🚫')),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        store.blockUser(bidder);
        if (item.autoBids.containsKey(bidder)) {
          item.autoBids.remove(bidder);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(
            'تم حظر المزايد بنجاح ومنعه نهائياً من تقديم أي عروض مستقبلية 🚫',
            'Bidder blocked from making future bids 🚫',
          )),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  Widget banner(String text, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      );

  Widget statBox(String label, String value) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _buildMediaGallery(Item item, ColorScheme scheme) {
    final validImages = item.imagePaths
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (validImages.isEmpty) {
      return Stack(
        children: [
          Container(
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(categoryIcon(item.category),
                    size: 64, color: scheme.onPrimaryContainer),
                const SizedBox(height: 8),
                Text(
                  item.category,
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (item.videoPath != null)
            Positioned(
              bottom: 10,
              left: 10,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(tr('الفيديو المرفق للسلعة 🎬', 'Attached Video 🎬')),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill,
                              size: 72, color: Colors.indigo),
                          const SizedBox(height: 8),
                          Text(item.videoPath!.split(RegExp(r'[/\\]')).last),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(tr('إغلاق', 'Close'))),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.play_circle_fill),
                label: Text(tr('تشغيل الفيديو المرفق', 'Play Attached Video')),
              ),
            ),
        ],
      );
    }

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            controller: _imagePageCtrl,
            itemCount: validImages.length,
            onPageChanged: (idx) => setState(() => currentImageIndex = idx),
            itemBuilder: (context, idx) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenImageViewer(
                    images: validImages,
                    initialIndex: idx,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: buildSmartImage(
                  validImages[idx],
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          if (validImages.length > 1)
            Positioned(
              bottom: 10,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${currentImageIndex + 1} / ${validImages.length}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (item.videoPath != null)
            Positioned(
              bottom: 10,
              left: 12,
              child: FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.videocam, size: 18),
                label: Text(tr('فيديو مرفق', 'Video Attached')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDealContactCard(Item item, String winner) {
    final otherPerson = store.isItemSeller(item) ? winner : item.seller;

    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.green.shade400, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: Colors.green.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('بطاقة إتمام الصفقة والتواصل المباشر',
                        'Deal Completion & Direct Contact'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${store.isItemSeller(item) ? tr("الفائز بالمزاد:", "Winner:") : tr("البائع:", "Seller:")} ${displayName(otherPerson)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Text(
              '${tr("طريقة التسليم المتفق عليها:", "Delivery:")} ${item.deliveryMethod} (${item.location} - ${item.area})',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                  onPressed: () async {
                    final loggedIn = await ensureUserLoggedIn(
                      context,
                      reason: tr(
                        'يجب تسجيل الدخول لمراسلة البائع وبدء المحادثة 💬',
                        'Please sign in to chat with the seller 💬',
                      ),
                    );
                    if (!loggedIn || !context.mounted) return;
                    if (store.isMutualOrBlockedBetween(otherPerson, me)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr(
                            'لا يمكن بدء محادثة بسبب وجود حظر نشط بين الطرفين 🚫',
                            'Cannot start chat due to an active block between both parties 🚫',
                          )),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DirectChatPage(
                          item: item,
                          otherParty: otherPerson,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: Text(tr('محادثة داخل التطبيق', 'In-App Chat')),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: showReportDialog,
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: Text(tr('إبلاغ عن تخلف عن الدفع', 'Report Non-Payer')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget actionSection(Item item) {
    // 1. إذا كان المزاد مجدولاً ولم يبدأ بعد
    if (item.isScheduled) {
      final reminded = store.isRemindMeSet(item);
      return Card(
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.orange.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.schedule, size: 42, color: Colors.deepOrange),
              const SizedBox(height: 8),
              Text(
                tr('هذا المزاد مجدول وسيبدأ خلال:',
                    'Scheduled Auction Starts In:'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                formatDuration(item.timeUntilStart),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      reminded ? Colors.teal : Colors.orange.shade800,
                ),
                onPressed: () {
                  store.toggleRemindMe(item);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(reminded
                        ? tr('تم إلغاء التذكير', 'Reminder cancelled')
                        : tr('سنرسل لك إشعاراً فور انطلاق المزاد 🔔',
                            'We will notify you as soon as the auction starts 🔔')),
                  ));
                },
                icon: Icon(reminded
                    ? Icons.notifications_active
                    : Icons.notification_add_outlined),
                label: Text(reminded
                    ? tr('التذكير مفعّل عند البدء ✅', 'Reminder Active ✅')
                    : tr('ذكّرني عند البدء 🔔', 'Remind Me When It Starts 🔔')),
              ),
            ],
          ),
        ),
      );
    }

    // 2. إذا كان المزاد منتهياً أو ملغياً
    if (item.isEnded) {
      final winner = item.highestBidder;
      final price = formatPrice(item.currentPrice);
      Widget resultBanner;

      if (item.isCancelled) {
        resultBanner = banner(
          tr('🚫 تم إلغاء هذا المزاد من قِبل البائع دون بيع السلعة.',
              '🚫 This auction was cancelled by the seller.'),
          Colors.red.shade700,
        );
      } else if (item.isEndedEarlyBySeller) {
        if (winner == me) {
          resultBanner = banner(
            '🎉 مبروك! وافق البائع على سعرك وأرسى المزاد عليك بمبلغ $price',
            Colors.green.shade700,
          );
        } else if (store.isItemSeller(item)) {
          resultBanner = banner(
            '🤝 قمت بإنهاء المزاد مبكراً وبيع السلعة إلى "$winner" بمبلغ $price',
            Colors.green.shade700,
          );
        } else {
          resultBanner = banner(
            '🤝 انتهى المزاد مبكراً: وافق البائع على عرض "$winner" بمبلغ $price',
            Colors.teal.shade700,
          );
        }
      } else if (winner == null) {
        resultBanner = banner(
            tr('انتهى المزاد بدون أي مزايدات.', 'Auction ended with no bids.'),
            Colors.blueGrey);
      } else if (winner == me) {
        resultBanner = banner(
            '🎉 مبروك! فزت بهذه السلعة بمبلغ $price', Colors.green.shade700);
      } else {
        resultBanner =
            banner('انتهى المزاد. الفائز: $winner بمبلغ $price', Colors.orange);
      }

      return Column(
        children: [
          resultBanner,
          if (!item.isCancelled &&
              winner != null &&
              (winner == me || store.isItemSeller(item))) ...[
            const SizedBox(height: 12),
            _buildDealContactCard(item, winner),
          ],
          if (store.isItemSeller(item)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                store.deleteItem(item);
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                messenger.showSnackBar(
                  SnackBar(
                      content: Text(tr('تم حذف السلعة من قائمتك 🗑️',
                          'Item removed from your list 🗑️'))),
                );
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(
                  tr('حذف هذه السلعة من قائمتي', 'Delete from my listings')),
            ),
          ],
        ],
      );
    }

    // 3. إذا كان المستخدم هو صاحب السلعة (البائع)، لا نعرض بطاقة المزايدة أو تنبيه البائع
    if (store.isItemSeller(item)) {
      return const SizedBox.shrink();
    }

    // 4. المشتري: تقديم مزايدة تصاعدية
    final current = item.currentPrice;
    final lastBidder = item.highestBidder ??
        (item.bids.isNotEmpty ? item.bids.first.bidder : null);
    final isMeHighestBidder = lastBidder != null && store.isUserMe(lastBidder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // السعر النهائي (إذا كان محدداً من قبل البائع) يظهر كزر وليبل أنيق فوق حقل المزايدة
        if (item.buyNowPrice != null && item.buyNowPrice! > 0 && !item.isEnded) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade600, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(Icons.flash_on, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('السعر النهائي المعتمد:', 'Final Fixed Price:'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatPrice(item.buyNowPrice!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.isScheduled)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => confirmBuyNow(item),
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: Text(
                      tr('شراء فوري', 'Buy Now'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
        Text(
          item.bids.isEmpty
              ? '${tr("أدخل مبلغ مزايدتك (سعر البداية", "Starting bid")} ${formatPrice(item.startPrice)}):'
              : '${tr("أدخل مبلغ مزايدتك (أعلى من", "Enter your bid above")} ${formatPrice(current)}):',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: amountCtrl,
          enabled: !isMeHighestBidder,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: tr('مبلغ مزايدتك (دينار)', 'Your Bid Amount (IQD)'),
            helperText: (item.buyNowPrice != null && item.buyNowPrice! > 0)
                ? '${tr("الحد الأقصى للمزايدة هو السعر النهائي:", "Max bid is final price:")} ${formatPrice(item.buyNowPrice!)}'
                : null,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.gavel),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final step in [1000, 5000, 10000, 50000])
              if (item.buyNowPrice == null ||
                  item.buyNowPrice! <= 0 ||
                  (current + step) <= item.buyNowPrice!)
                ActionChip(
                  label: Text('+$step (${formatPrice(current + step)})'),
                  onPressed: isMeHighestBidder
                      ? null
                      : () => amountCtrl.text = '${current + step}',
                ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isMeHighestBidder ? null : submitManualBid,
            icon: Icon(isMeHighestBidder ? Icons.lock : Icons.gavel),
            label: Text(
              isMeHighestBidder
                  ? tr('أنت صاحب أعلى مزايدة حالياً 🥇', 'You are highest bidder 🥇')
                  : tr('زايد الآن', 'Place Bid Now'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final item = store.items.firstWhere(
          (it) =>
              it.id == widget.item.id ||
              AuctionStore.itemToUuid(it.id) ==
                  AuctionStore.itemToUuid(widget.item.id),
          orElse: () => widget.item,
        );
        final isFav = store.isFavorite(item.id);
        final sellerRating = store.getUserRating(item.seller);
        final visibleAttributes = item.attributes.entries
            .where((e) =>
                !e.key.startsWith('_') &&
                !e.key.toLowerCase().contains('buy_now_price') &&
                e.value.trim().isNotEmpty)
            .toList();

        // التحقق الصارم من رمز PIN (PIN Validation Guard)
        if (item.isPrivate && !store.isPrivateUnlocked(item)) {
          final pinInputCtrl = TextEditingController();
          return Scaffold(
            appBar: AppBar(
              title: Text(tr('غرفة مزاد خاصة', 'Private Auction')),
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock, size: 56, color: Colors.amber),
                          const SizedBox(height: 16),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(
                              'هذا المزاد مقفل برمز PIN سري. يرجى إدخال الرمز المصرح به من البائع لعرض التفاصيل والمزايدة:',
                              'This auction is PIN-protected. Enter the PIN code provided by seller to view details and bid:',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: pinInputCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tr('رمز PIN السري', 'PIN Code'),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.key),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                final loggedIn = await ensureUserLoggedIn(
                                  context,
                                  reason: tr(
                                    'يجب تسجيل الدخول أولاً لتتمكن من فك قفل هذا المزاد الخاص 🔒',
                                    'Please sign in to unlock this private auction 🔒',
                                  ),
                                );
                                if (!loggedIn || !mounted) return;

                                if (store.unlockPrivateItem(item, pinInputCtrl.text)) {
                                  setState(() {});
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(tr('رمز PIN غير صحيح ❌', 'Invalid PIN code ❌')),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.lock_open),
                              label: Text(tr('فك القفل والدخول', 'Unlock Auction')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: tr('مشاركة المزاد', 'Share Listing'),
                icon: const Icon(Icons.share),
                onPressed: () => showShareDialog(context, item),
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null,
                ),
                tooltip: isFav
                    ? tr('إزالة من المفضلة', 'Remove from Watchlist')
                    : tr('حفظ بالمفضلة', 'Save to Watchlist'),
                onPressed: () => store.toggleFavorite(item.id),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: tr('خيارات إضافية', 'More Options'),
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      showEditAuctionDialog();
                      break;
                    case 'launch':
                      final messenger = ScaffoldMessenger.of(context);
                      await store.launchAuctionNow(item);
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(
                        content: Text(tr(
                            'تم إطلاق وبدء المزاد الآن بنجاح 🚀',
                            'Auction launched and started now 🚀')),
                        backgroundColor: Colors.teal.shade800,
                      ));
                      break;
                    case 'accept':
                      confirmAcceptHighestBid();
                      break;
                    case 'report':
                      showReportDialog();
                      break;
                    case 'delete':
                      confirmDeleteItem();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (store.isItemSeller(item) && !item.isEnded)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 20, color: Colors.indigo),
                          const SizedBox(width: 10),
                          Text(tr('تعديل المزاد', 'Edit Auction')),
                        ],
                      ),
                    ),
                  if (store.isItemSeller(item) && item.bids.isNotEmpty && !item.isEnded)
                    PopupMenuItem(
                      value: 'accept',
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                          const SizedBox(width: 10),
                          Text(
                            tr('قبول أعلى مزايدة', 'Accept Highest Bid'),
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  if (store.isItemSeller(item) || settings.isAdmin)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          const SizedBox(width: 10),
                          Text(
                            tr('حذف السلعة', 'Delete Item'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  if (item.seller != me)
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 20, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Text(tr('إبلاغ عن مخالفة', 'Report Issue')),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  // 1. معرض صور السلعة الرئيسي
                  _buildMediaGallery(item, scheme),
                  const SizedBox(height: 16),

                  // 2. بطاقة السعر الحالي والوقت المتبقي في الصدارة
                  Card(
                    color: scheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              statBox(
                                tr('السعر الحالي', 'Current Price'),
                                formatPrice(item.currentPrice),
                              ),
                              statBox(
                                item.isScheduled
                                    ? tr('يبدأ خلال', 'Starts In')
                                    : tr('الوقت المتبقي', 'Time Left'),
                                item.isCancelled
                                    ? tr('ملغي', 'Cancelled')
                                    : (item.isEndedEarlyBySeller
                                        ? tr('تم الإرساء', 'Settled')
                                        : (item.isScheduled
                                            ? formatDuration(item.timeUntilStart)
                                            : formatDuration(item.timeLeft))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. عنوان / اسم السلعة
                  Text(
                    item.title,
                    style:
                        const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // 3. الشارات والبيانات التعريفية (حالة السلعة، طريقة التسليم، والتصنيف الأساسي)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: Icon(categoryIcon(item.category), size: 16),
                        label: Text(item.category),
                      ),
                      Chip(
                        avatar: const Icon(Icons.verified_outlined, size: 16),
                        label: Text(item.condition),
                      ),
                      if (item.deliveryMethod.trim().isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.local_shipping_outlined, size: 16),
                          label: Text(item.deliveryMethod.trim()),
                        ),
                      if (item.isPrivate)
                        Chip(
                          avatar: const Icon(Icons.lock, size: 16),
                          label: Text(tr('غرفة خاصة برمز PIN', 'Private PIN Room')),
                        ),
                      if (item.extensionsCount > 0)
                        Chip(
                          avatar: const Icon(Icons.more_time, size: 16),
                          label: Text(tr(
                              'تمديد تلقائي (${item.extensionsCount})',
                              'Auto-extended (${item.extensionsCount})')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. المواصفات الخاصة بالفئة والحقول الذكية
                  if (visibleAttributes.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(categoryIcon(item.category),
                                    size: 18, color: scheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${tr("المواصفات الخاصة بفئة", "Category Specs:")} (${item.category})',
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            for (final entry in visibleAttributes)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(entry.key,
                                        style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 13)),
                                    Flexible(
                                      child: Text(
                                        entry.value,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. تفاصيل ووصف السلعة المكتوب
                  Card(
                    elevation: 0,
                    color: scheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                tr('تفاصيل وإعلان السلعة', 'Item Description'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Text(
                            item.description,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. كارت معلومات البائع (يختفي إذا كان المستخدم هو البائع نفسه)
                  if (!store.isItemSeller(item)) ...[
                    Card(
                      elevation: 0,
                      color: scheme.surfaceContainerLow,
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        onTap: () => showUserProfileSheet(context, item.seller),
                        leading: buildUserAvatar(item.seller, radius: 22),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${tr("البائع:", "Seller:")} ${displayName(item.seller)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, color: Colors.amber, size: 15),
                            Text(
                              sellerRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '📍 ${item.location} - ${item.area}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: (settings.isLoggedIn && !store.isItemSeller(item))
                            ? FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () async {
                                  final otherPerson = item.seller;
                                  final loggedIn = await ensureUserLoggedIn(
                                    context,
                                    reason: tr(
                                      'يجب تسجيل الدخول لمراسلة البائع وبدء المحادثة 💬',
                                      'Please sign in to chat with the seller 💬',
                                    ),
                                  );
                                  if (!loggedIn || !context.mounted) return;
                    if (store.isMutualOrBlockedBetween(otherPerson, me)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr(
                            'لا يمكن بدء محادثة بسبب وجود حظر نشط بين الطرفين 🚫',
                            'Cannot start chat due to an active block between both parties 🚫',
                          )),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                      return;
                    }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DirectChatPage(
                                        item: item,
                                        otherParty: item.seller,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chat_bubble_outline, size: 15),
                                label: Text(tr('مراسلة', 'Chat'),
                                    style: const TextStyle(fontSize: 12)),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),

                  // 7. قسم المزايدة وإدخال مبالغ المزايدة
                  actionSection(item),
                  const SizedBox(height: 24),

                  // 8. سجل المزايدات العلنية
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('سجل المزايدات العلنية', 'Public Bid History'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${item.bids.length} ${tr("مزايدة", "bids")}',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              if (item.bids.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: Text(tr('لا توجد مزايدات بعد. كن أول من يزايد!',
                          'No bids yet. Be the first to bid!'))),
                )
              else
                ...() {
                  final sortedBids = List<Bid>.from(item.bids)..sort((a, b) {
                    final cmp = b.amount.compareTo(a.amount);
                    if (cmp != 0) return cmp;
                    return b.time.compareTo(a.time);
                  });
                  return sortedBids.asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final b = entry.value;
                      final isTopBid = index == 0;
                      final isMe = store.isUserMe(b.bidder);
                      return Card(
                        elevation: isTopBid ? 1.5 : 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isTopBid
                                ? Colors.amber.shade400
                                : scheme.outlineVariant.withValues(alpha: 0.6),
                            width: isTopBid ? 1.4 : 1,
                          ),
                        ),
                        color: isTopBid
                            ? Colors.amber.withValues(alpha: 0.05)
                            : scheme.surfaceContainerLowest,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showBidderActionsSheet(item, b, isTopBid),
                          hoverColor: scheme.primary.withValues(alpha: 0.08),
                          splashColor: scheme.primary.withValues(alpha: 0.16),
                          highlightColor: scheme.primary.withValues(alpha: 0.05),
                          mouseCursor: SystemMouseCursors.click,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                buildUserAvatar(
                                  b.bidder,
                                  radius: 20,
                                  badge: isTopBid
                                      ? Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.amber,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.emoji_events,
                                              size: 11, color: Colors.brown),
                                        )
                                      : (b.isAuto
                                          ? Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.indigo,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.auto_mode,
                                                  size: 11, color: Colors.white),
                                            )
                                          : null),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              displayName(b.bidder),
                                              style: TextStyle(
                                                fontWeight: isTopBid
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: scheme.primaryContainer,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tr('أنت', 'You'),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: scheme.onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (isTopBid) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: Colors.amber.shade400),
                                              ),
                                              child: Text(
                                                tr('أعلى مزايدة 👑', 'Top Bid 👑'),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.brown.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (b.isAuto) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.indigo.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: Colors.indigo.shade200),
                                              ),
                                              child: Text(
                                                tr('تلقائية ⚡', 'Auto ⚡'),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.indigo,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        ago(b.time),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatPrice(b.amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isTopBid
                                            ? Colors.green.shade800
                                            : scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tr('خيارات', 'Options'),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }(),

              const Divider(height: 32),

              // قسم التعليقات والاستفسارات المباشرة (Live Q&A)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('التعليقات والاستفسارات المباشرة 💬',
                        'Live Q&A & Comments 💬'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('${item.comments.length}',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              if (item.comments.isEmpty)
                Text(
                  tr('لا توجد استفسارات بعد. اسأل البائع مباشرة هنا!',
                      'No questions yet. Ask the seller directly!'),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                )
              else
                for (final c in item.comments)
                  Card(
                    elevation: 0,
                    color: scheme.surfaceContainerLowest,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      leading: buildUserAvatar(c.author, radius: 16),
                      title: Row(
                        children: [
                          Text(displayName(c.author),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (c.author == item.seller) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(tr('البائع', 'Seller'),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.black87)),
                            ),
                          ],
                          const Spacer(),
                          Text(ago(c.time),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      subtitle: Text(c.text),
                    ),
                  ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      decoration: InputDecoration(
                        hintText: tr('اكتب سؤالك أو تعليقك للبائع...',
                            'Write a question or comment...'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: submitComment,
                    icon: const Icon(Icons.send, size: 16),
                    label: Text(tr('إرسال', 'Send')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  },
);
}
}

// ======================= عارض الصور بملء الشاشة مع التكبير والتصغير =======================

class FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late int _currentIndex;
  late final PageController _pageCtrl;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: tr('إغلاق', 'Close'),
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(
              fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.images.length > 1) ...[
            IconButton(
              tooltip: tr('السابق', 'Previous'),
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 20, color: Colors.white),
              onPressed: _currentIndex > 0
                  ? () => _pageCtrl.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            IconButton(
              tooltip: tr('التالي', 'Next'),
              icon: const Icon(Icons.arrow_forward_ios,
                  size: 20, color: Colors.white),
              onPressed: _currentIndex < widget.images.length - 1
                  ? () => _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
          ],
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
        itemCount: widget.images.length,
        onPageChanged: (idx) {
          setState(() {
            _currentIndex = idx;
            _isZoomed = false;
          });
        },
        itemBuilder: (context, idx) {
          return _ZoomableImagePage(
            imageUrl: widget.images[idx],
            onZoomChanged: (zoomed) {
              if (_isZoomed != zoomed) {
                setState(() => _isZoomed = zoomed);
              }
            },
          );
        },
      ),
    );
  }
}

class _ZoomableImagePage extends StatefulWidget {
  final String imageUrl;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImagePage({
    required this.imageUrl,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage> {
  final TransformationController _transformCtrl = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformCtrl.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (_isZoomed != zoomed) {
      setState(() => _isZoomed = zoomed);
      widget.onZoomChanged(zoomed);
    }
  }

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransformChanged);
    _transformCtrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    if (scale > 1.05) {
      // إعادة التكبير إلى الوضع الطبيعي
      _transformCtrl.value = Matrix4.identity();
    } else {
      // تكبير فوري على موضع النقر المزدوج
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final x = -position.dx * 1.5;
      final y = -position.dy * 1.5;
      _transformCtrl.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(2.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: SizedBox.expand(
        child: InteractiveViewer(
          transformationController: _transformCtrl,
          clipBehavior: Clip.none,
          minScale: 1.0,
          maxScale: 6.0,
          panEnabled: _isZoomed,
          scaleEnabled: true,
          boundaryMargin: _isZoomed
              ? const EdgeInsets.all(double.infinity)
              : EdgeInsets.zero,
          child: SizedBox.expand(
            child: Center(
              child: buildSmartImage(
                widget.imageUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


