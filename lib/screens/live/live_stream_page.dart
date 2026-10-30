part of '../../main.dart';

// ======================= 1. واجهة البث المباشر للمزاد (Live Stream) =======================

class LiveStreamPage extends StatefulWidget {
  final Item item;
  const LiveStreamPage({super.key, required this.item});

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  final msgCtrl = TextEditingController();
  final bidCtrl = TextEditingController();
  bool isCameraFront = true;
  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.seller == me) {
      widget.item.isLiveStreaming = true;
      store.pushToSupabase();
    } else {
      widget.item.liveViewers++;
      store.pushToSupabase();
    }
  }

  @override
  void dispose() {
    msgCtrl.dispose();
    bidCtrl.dispose();
    if (widget.item.seller == me) {
      widget.item.isLiveStreaming = false;
      store.pushToSupabase();
    } else {
      if (widget.item.liveViewers > 0) {
        widget.item.liveViewers--;
        store.pushToSupabase();
      }
    }
    super.dispose();
  }

  void sendQuickBid(int amount) {
    final err = store.placeBid(widget.item, amount);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? tr('تمت المزايدة في البث المباشر ✅', 'Live bid placed ✅')),
      backgroundColor: err == null ? Colors.green : Colors.red,
      duration: const Duration(seconds: 2),
    ));
  }

  void sendComment() {
    final txt = msgCtrl.text.trim();
    if (txt.isEmpty) return;
    store.addComment(widget.item, txt);
    msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSeller = item.seller == me;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final nextSuggested = item.bids.isEmpty
            ? item.startPrice
            : item.currentPrice + 5000;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                // الكاميرا الحقيقية للبث المباشر للبائع، أو واجهة مشاهدة البث للمشتري
                Positioned.fill(
                  child: buildLiveCameraPreview(
                    isSeller: isSeller,
                    isFront: isCameraFront,
                  ),
                ),

                // الشريط العلوي للبث المباشر بتصميم متجاوب يمنع أي تجاوز للأحجام
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              tr('مباشر', 'LIVE'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              '${item.liveViewers}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer,
                                color: Colors.amber, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              formatDuration(item.timeLeft),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isSeller) ...[
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 34, minHeight: 34),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black45),
                          onPressed: () =>
                              setState(() => isMuted = !isMuted),
                          icon: Icon(
                            isMuted ? Icons.mic_off : Icons.mic,
                            size: 18,
                            color: isMuted ? Colors.redAccent : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 34, minHeight: 34),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black45),
                          onPressed: () =>
                              setState(() => isCameraFront = !isCameraFront),
                          icon: const Icon(Icons.cameraswitch,
                              size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                      ],
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 34, minHeight: 34),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // بطاقة السعر الحالي وأعلى مزايد في البث
                Positioned(
                  top: 68,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.highestBidder == null
                                    ? tr('لا توجد مزايدات بعد - افتح المزاد!',
                                        'No bids yet - start the bidding!')
                                    : tr('أعلى مزايد: ${displayName(item.highestBidder!)}',
                                        'Highest bidder: ${displayName(item.highestBidder!)}'),
                                style: const TextStyle(
                                    color: Colors.amberAccent, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              tr('السعر الحالي', 'Current Bid'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                            Text(
                              formatPrice(item.currentPrice),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // سجل التعليقات والمزايدات اللحظية فوق البث
                Positioned(
                  bottom: isSeller ? 90 : 150,
                  left: 12,
                  right: 80,
                  height: 220,
                  child: ListView(
                    reverse: true,
                    children: [
                      for (final c in item.comments.reversed.take(8))
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${displayName(c.author)}: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: c.author == item.seller
                                        ? Colors.amber
                                        : Colors.lightBlueAccent,
                                  ),
                                ),
                                TextSpan(
                                  text: c.text,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (final b in item.bids.take(5))
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.greenAccent),
                          ),
                          child: Text(
                            '🔨 ${displayName(b.bidder)} زايد بمبلغ ${formatPrice(b.amount)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // الشريط السفلي: مزايدة سريعة + كتابة تعليق حي
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isSeller && !item.isEnded && !item.isScheduled) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green.shade600),
                                onPressed: () => sendQuickBid(nextSuggested),
                                icon: const Icon(Icons.gavel, size: 16),
                                label: Text(
                                    '${tr("زايد", "Bid")} ${formatPrice(nextSuggested)}'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: () =>
                                    sendQuickBid(item.currentPrice + 10000),
                                child: Text('+10,000 ${tr("دينار", "IQD")}'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: () =>
                                    sendQuickBid(item.currentPrice + 25000),
                                child: Text('+25,000 ${tr("دينار", "IQD")}'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: msgCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: tr('اكتب تعليقاً أو سؤالاً في البث...',
                                    'Ask a question in live chat...'),
                                hintStyle:
                                    const TextStyle(color: Colors.white60),
                                filled: true,
                                fillColor: Colors.white12,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => sendComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: sendComment,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

