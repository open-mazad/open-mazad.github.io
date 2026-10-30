part of '../../main.dart';

// ======================= 2. المحادثة الخاصة داخل التطبيق + واتساب =======================

class DirectChatPage extends StatefulWidget {
  final Item item;
  final String otherParty;
  const DirectChatPage({
    super.key,
    required this.item,
    required this.otherParty,
  });

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage> {
  final textCtrl = TextEditingController();

  @override
  void dispose() {
    textCtrl.dispose();
    super.dispose();
  }

  void send() {
    final txt = textCtrl.text.trim();
    if (txt.isEmpty) return;
    store.sendDirectMessage(widget.item, widget.otherParty, txt);
    textCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final phone = store.getUserPhone(widget.otherParty);
    final isDealClosed = item.isEnded &&
        item.highestBidder != null &&
        (item.seller == me || item.highestBidder == me);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final msgs = store.getDirectMessages(item.id);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName(widget.otherParty),
                    style: const TextStyle(fontSize: 16)),
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: tr('تقييم الطرف الآخر', 'Rate User'),
                icon: const Icon(Icons.star_rate_rounded, color: Colors.amber),
                onPressed: () => showUserProfileSheet(context, widget.otherParty),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  // شريط واتساب ورقم الهاتف عند الفوز وإتمام الصفقة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: isDealClosed
                    ? Colors.green.shade50
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Icon(
                      isDealClosed ? Icons.verified : Icons.chat_bubble_outline,
                      color: isDealClosed ? Colors.green.shade700 : Colors.indigo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDealClosed
                                ? tr('بيانات الاتصال المباشر لإتمام التسليم:',
                                    'Direct Contact for Delivery:')
                                : tr('محادثة مباشرة بخصوص السلعة',
                                    'Direct inquiry about this item'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            isDealClosed
                                ? '${tr("رقم الهاتف:", "Phone:")} $phone (${tr("واتساب متاح", "WhatsApp Available")})'
                                : tr('يظهر رقم الهاتف والانتقال لواتساب تلقائياً فور الفوز بالمزاد',
                                    'Phone & WhatsApp unlock automatically upon winning'),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (isDealClosed)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: 'https://wa.me/$phone?text=${Uri.encodeComponent("مرحباً، أتواصل معك بخصوص مزاد: ${item.title}")}'));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(tr(
                                'تم نسخ رابط ورقم واتساب ($phone) - جاهز للمراسلة المباشرة 💬',
                                'WhatsApp link & number ($phone) copied!')),
                            backgroundColor: Colors.green.shade700,
                          ));
                        },
                        icon: const Icon(Icons.phone_in_talk, size: 16),
                        label: Text(tr('واتساب', 'WhatsApp')),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: msgs.isEmpty
                    ? Center(
                        child: Text(
                          tr('ابدأ المحادثة مع ${displayName(widget.otherParty)} للاستفسار عن السلعة أو التسليم.',
                              'Start chatting with ${displayName(widget.otherParty)}.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: msgs.length,
                        itemBuilder: (context, i) {
                          final m = msgs[i];
                          final isMe = m.sender == me;
                          return Align(
                            alignment: isMe
                                ? AlignmentDirectional.centerStart
                                : AlignmentDirectional.centerEnd,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.indigo.shade600
                                    : Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.text,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ago(m.time),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textCtrl,
                          decoration: InputDecoration(
                            hintText: tr('اكتب رسالتك...', 'Type a message...'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) => send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
}
}

