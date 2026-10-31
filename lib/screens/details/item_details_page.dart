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
    if (settings.needsProfileOnboarding) {
      await showCompleteProfileDialog(context);
      if (!mounted || settings.needsProfileOnboarding) return;
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
    final error = amount == null
        ? tr('اكتب مبلغاً صحيحاً بالأرقام', 'Enter a valid number')
        : store.placeBid(liveItem, amount);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? tr('تمت المزايدة بنجاح ✅', 'Bid placed ✅')),
      backgroundColor: error == null ? Colors.green : Colors.red,
    ));
    if (error == null) amountCtrl.clear();
  }

  void submitComment() {
    final txt = commentCtrl.text.trim();
    if (txt.isEmpty) return;
    store.addComment(liveItem, txt);
    commentCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> showReportDialog() async {
    final item = liveItem;
    final target = item.seller == me
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
            const Icon(Icons.handshake, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    tr('إرساء المزاد والبيع الآن', 'Accept Highest Bid Now'))),
          ],
        ),
        content: Text(
          tr(
            'هل توافق على إيقاف المزاد الآن وبيع "${item.title}" إلى أعلى مزايد حالي ($topBidder) بمبلغ $price؟\n\nسيُعتمد $topBidder فائزاً بالسلعة فوراً.',
            'Stop auction now and sell "${item.title}" to highest bidder ($topBidder) for $price?',
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
                tr('نعم، اعتمد البيع وأنهِ المزاد', 'Yes, Sell & End Auction')),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final err = store.endAuctionAndSellToHighest(item);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            err ?? 'تم إنهاء المزاد وبيع السلعة إلى $topBidder بمبلغ $price ✅'),
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
    final otherPerson = item.seller == me ? winner : item.seller;

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
              '${item.seller == me ? tr("الفائز بالمزاد:", "Winner:") : tr("البائع:", "Seller:")} ${displayName(otherPerson)}',
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DirectChatPage(
                        item: item,
                        otherParty: otherPerson,
                      ),
                    ),
                  ),
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
        } else if (item.seller == me) {
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
              (winner == me || item.seller == me)) ...[
            const SizedBox(height: 12),
            _buildDealContactCard(item, winner),
          ],
          if (item.seller == me) ...[
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

    // 3. إذا كان المستخدم هو البائع والمزاد جارٍ
    if (item.seller == me) {
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
        if (isMeHighestBidder) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, color: Colors.amber.shade900, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(
                      'أنت صاحب أعلى مزايدة حالياً 🥇. لا يمكنك المزايدة مجدداً إلا بعد قيام طرف آخر برفع السعر وتجاوز مزايدتك لمنع التكرار.',
                      'You are currently the highest bidder 🥇. You cannot bid again until another bidder outbids you.',
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          item.bids.isEmpty
              ? '${tr("سعر بداية المزاد:", "Starting Price:")} ${formatPrice(item.startPrice)}'
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
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.gavel),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ActionChip(
              label: Text('+1,000 (${formatPrice(current + 1000)})'),
              onPressed: isMeHighestBidder ? null : () => amountCtrl.text = '${current + 1000}',
            ),
            ActionChip(
              label: Text('+5,000 (${formatPrice(current + 5000)})'),
              onPressed: isMeHighestBidder ? null : () => amountCtrl.text = '${current + 5000}',
            ),
            ActionChip(
              label: Text('+10,000 (${formatPrice(current + 10000)})'),
              onPressed: isMeHighestBidder ? null : () => amountCtrl.text = '${current + 10000}',
            ),
            ActionChip(
              label: Text('+50,000 (${formatPrice(current + 50000)})'),
              onPressed: isMeHighestBidder ? null : () => amountCtrl.text = '${current + 50000}',
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
                  if (item.seller == me && !item.isEnded) ...[
                    if (item.isScheduled)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 20),
                            const SizedBox(width: 10),
                            Text(tr('تعديل كامل تفاصيل الإعلان', 'Edit Full Listing')),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.note_add_outlined, size: 20, color: Colors.indigo),
                            const SizedBox(width: 10),
                            Text(tr('إضافة معلومات للمزاد ➕', 'Add Info to Listing ➕')),
                          ],
                        ),
                      ),
                  ],
                  if (item.seller == me && item.isScheduled)
                    PopupMenuItem(
                      value: 'launch',
                      child: Row(
                        children: [
                          const Icon(Icons.rocket_launch, size: 20, color: Colors.teal),
                          const SizedBox(width: 10),
                          Text(
                            tr('إطلاق وبدء المزاد الآن 🚀', 'Launch Auction Now 🚀'),
                            style: const TextStyle(color: Colors.teal),
                          ),
                        ],
                      ),
                    ),
                  if (item.seller == me && item.bids.isNotEmpty && !item.isEnded)
                    PopupMenuItem(
                      value: 'accept',
                      child: Row(
                        children: [
                          const Icon(Icons.handshake, size: 20, color: Colors.green),
                          const SizedBox(width: 10),
                          Text(
                            tr('قبول أعلى مزايدة وإنهاء المزاد 🤝',
                                'Accept Top Bid & End 🤝'),
                            style: const TextStyle(color: Colors.green),
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
                  if (item.seller == me || settings.isAdmin)
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          statBox(tr('السعر الحالي', 'Current Bid'),
                              formatPrice(item.currentPrice)),
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

                  // 3. الشارات والبيانات التعريفية (حالة السلعة والتصنيف الأساسي)
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
                  if (item.attributes.isNotEmpty) ...[
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
                            for (final entry in item.attributes.entries)
                              if (entry.value.trim().isNotEmpty)
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

                  // 6. كارت معلومات البائع (الاسم، التقييم، وزر المراسلة)
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
                        '📍 ${item.location} - ${item.area} • 🚚 ${item.deliveryMethod}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: item.seller != me
                          ? FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DirectChatPage(
                                    item: item,
                                    otherParty: item.seller,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 15),
                              label: Text(tr('مراسلة', 'Chat'),
                                  style: const TextStyle(fontSize: 12)),
                            )
                          : null,
                    ),
                  ),
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
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        onTap: () => showUserProfileSheet(context, b.bidder),
                        leading: buildUserAvatar(
                          b.bidder,
                          radius: 18,
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
                        title: Row(
                          children: [
                            Text(displayName(b.bidder),
                                style: TextStyle(
                                    fontWeight: isTopBid
                                        ? FontWeight.bold
                                        : FontWeight.w600)),
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
                                child: Text(tr('أعلى مزايدة 👑', 'Top Bid 👑'),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown.shade800)),
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
                                child: Text(tr('تلقائية ⚡', 'Auto ⚡'),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.indigo)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(ago(b.time)),
                        trailing: Text(formatPrice(b.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isTopBid
                                  ? Colors.green.shade800
                                  : scheme.primary,
                            )),
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: tr('إغلاق', 'Close'),
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemBuilder: (context, idx) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              panEnabled: true,
              scaleEnabled: true,
              child: buildSmartImage(
                widget.images[idx],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          );
        },
      ),
    );
  }
}


