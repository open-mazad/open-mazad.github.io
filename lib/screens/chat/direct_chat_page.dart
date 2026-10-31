part of '../../main.dart';

// ======================= 2. المحادثة الخاصة الاحترافية داخل التطبيق =======================

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
  int _visibleLimit = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.markConversationAsRead(widget.item.id, widget.otherParty);
    });
  }

  @override
  void dispose() {
    textCtrl.dispose();
    super.dispose();
  }

  void send() {
    final txt = textCtrl.text.trim();
    if (txt.isEmpty) return;
    if (store.isUserBlocked(widget.otherParty)) return;
    store.sendDirectMessage(widget.item, widget.otherParty, txt);
    textCtrl.clear();
    setState(() {});
  }

  Future<void> sendImage() async {
    if (store.isUserBlocked(widget.otherParty)) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 75,
      );
      if (picked != null) {
        final portable = await xFileToPortableImage(picked);
        store.sendDirectMessage(
            widget.item, widget.otherParty, '[image:$portable]');
        if (mounted) setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('تعذر اختيار الصورة', 'Failed to pick image'))),
      );
    }
  }

  Future<void> sendLocation() async {
    if (store.isUserBlocked(widget.otherParty)) return;
    String selectedGov = settings.governorate.isNotEmpty
        ? settings.governorate
        : (governorates.contains(widget.item.location)
            ? widget.item.location
            : governorates.first);
    final landmarkCtrl = TextEditingController(
        text: widget.item.area.isNotEmpty && widget.item.area != 'الكل'
            ? widget.item.area
            : '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: Colors.redAccent, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    tr('إرسال موقع اللقاء / التسليم',
                        'Share Delivery Location'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedGov,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('المحافظة', 'Governorate'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.map_outlined),
                ),
                items: governorates
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setSt(() => selectedGov = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: landmarkCtrl,
                decoration: InputDecoration(
                  labelText: tr(
                      'المنطقة أو النقطة الدالة (مثال: المنصور، قرب مول بغداد)',
                      'Area or Landmark'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.send_rounded),
                  label:
                      Text(tr('إرسال الموقع للمحادثة 📍', 'Send Location 📍')),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final landmark = landmarkCtrl.text.trim();
      final locText =
          landmark.isNotEmpty ? '$selectedGov - $landmark' : selectedGov;
      store.sendDirectMessage(
          widget.item, widget.otherParty, '[location:$locText]');
      if (mounted) setState(() {});
    }
    landmarkCtrl.dispose();
  }

  Widget _buildMessageContent(DirectMessage m, bool isMe) {
    if (m.text.startsWith('[image:') && m.text.endsWith(']')) {
      final imgUrl = m.text.substring(7, m.text.length - 1);
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenImageViewer(images: [imgUrl]),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
            color: Colors.black12,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                buildSmartImage(imgUrl,
                    fit: BoxFit.cover, width: 240, height: 180),
                Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (m.text.startsWith('[location:') && m.text.endsWith(']')) {
      final loc = m.text.substring(10, m.text.length - 1);
      return Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? Colors.white38 : Colors.grey.shade400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('موقع التسليم المتفق عليه 📍', 'Agreed Location 📍'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white70 : Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isMe
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      m.text,
      style: TextStyle(
        color: isMe
            ? Colors.white
            : Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }

  Future<void> _showReportDialog(Item item, String otherName) async {
    final reasonCtrl = TextEditingController();
    String selectedPreset = 'تخلف عن الدفع أو عدم الجدية في الشراء';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report_gmailerrorred, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('إبلاغ عن المستخدم', 'Report User'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tr("المبلَّغ عنه:", "Reported user:")} $otherName',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedPreset,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  'تخلف عن الدفع أو عدم الجدية في الشراء',
                  'إساءة لفظية أو إزعاج في المحادثة',
                  'محاولة احتيال أو طلب تحويل خارجي مشبوه',
                  'انتحال شخصية أو بيانات مزيفة',
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
                  labelText: tr('تفاصيل إضافية (اختياري)', 'Additional details (optional)'),
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
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send),
              label: Text(tr('إرسال البلاغ', 'Submit Report')),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final extra = reasonCtrl.text.trim();
      final fullReason =
          extra.isEmpty ? selectedPreset : '$selectedPreset — $extra';
      store.reportUser(
        reportedUser: widget.otherParty,
        reason: fullReason,
        itemId: item.id,
        itemTitle: item.title,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم إرسال البلاغ للإدارة بنجاح 🛡️',
              'Report submitted to administration 🛡️')),
          backgroundColor: Colors.orange.shade900,
        ),
      );
    }
  }

  Future<void> _confirmToggleBlock(String otherName, bool currentlyBlocked) async {
    if (currentlyBlocked) {
      store.unblockUser(widget.otherParty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم إلغاء حظر $otherName ✅', 'Unblocked $otherName ✅')),
          backgroundColor: Colors.teal.shade700,
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('حظر المستخدم', 'Block User'))),
          ],
        ),
        content: Text(
          tr(
            'هل أنت متأكد من حظر "$otherName"؟ لن يتمكن من إرسال رسائل لك أو المزايدة على سلعك حتى تقوم بإلغاء الحظر.',
            'Are you sure you want to block "$otherName"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('تراجع', 'Cancel')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.block),
            label: Text(tr('تأكيد الحظر', 'Block')),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      store.blockUser(widget.otherParty);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم حظر $otherName 🚫', '$otherName blocked 🚫')),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _confirmDeleteConversation(Item item, String otherName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('حذف المحادثة', 'Delete Conversation'))),
          ],
        ),
        content: Text(
          tr(
            'هل تريد حذف هذه المحادثة مع "$otherName" بالكامل؟',
            'Delete this entire conversation with "$otherName"?',
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
            label: Text(tr('حذف المحادثة', 'Delete')),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      store.deleteConversation(item.id, widget.otherParty);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم حذف المحادثة 🗑️', 'Conversation deleted 🗑️')),
        ),
      );
    }
  }

  void _showMessageActions(Item item, DirectMessage m, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.indigo),
              title: Text(tr('نسخ نص الرسالة', 'Copy Message Text')),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.text));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('تم نسخ النص 📋', 'Text copied 📋')),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  tr('حذف الرسالة', 'Delete Message'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  store.deleteSingleMessage(item.id, m);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('تم حذف الرسالة 🗑️', 'Message deleted 🗑️')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        final isDealClosed = item.isEnded &&
            item.highestBidder != null &&
            (store.isUserMe(item.seller) ||
                store.isUserMe(item.highestBidder!));

        final allMsgs = store.getDirectMessages(item.id);
        final otherUuid = AuctionStore.userToUuid(widget.otherParty);
        final otherName = displayName(widget.otherParty);
        final isBlocked = store.isUserBlocked(widget.otherParty);

        final msgs = allMsgs.where((m) {
          final isMeSender = store.isUserMe(m.sender);
          final isMeReceiver = store.isUserMe(m.receiver);
          final isOtherSender = m.sender == widget.otherParty ||
              AuctionStore.userToUuid(m.sender) == otherUuid ||
              displayName(m.sender) == otherName;
          final isOtherReceiver = m.receiver == widget.otherParty ||
              AuctionStore.userToUuid(m.receiver) == otherUuid ||
              displayName(m.receiver) == otherName;

          return (isMeSender && isOtherReceiver) ||
              (isMeReceiver && isOtherSender);
        }).toList();

        // إذا وصلت رسالة غير مقروءة أثناء فتح الصفحة، نعلّمها كمقروءة فوراً
        if (msgs.any((m) => !store.isUserMe(m.sender) && !m.isRead)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              store.markConversationAsRead(item.id, widget.otherParty);
            }
          });
        }

        final hasOlder = msgs.length > _visibleLimit;
        final visibleMsgs = hasOlder
            ? msgs.sublist(msgs.length - _visibleLimit)
            : msgs;

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: () => showUserProfileSheet(context, widget.otherParty),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          otherName,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBlocked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr('محظور', 'Blocked'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: tr('ملف وتقييم المستخدم', 'User Profile & Rating'),
                icon: const Icon(Icons.star_rate_rounded, color: Colors.amber),
                onPressed: () => showUserProfileSheet(context, widget.otherParty),
              ),
              PopupMenuButton<String>(
                tooltip: tr('خيارات المحادثة', 'Chat Options'),
                onSelected: (value) {
                  if (value == 'report') {
                    _showReportDialog(item, otherName);
                  } else if (value == 'block') {
                    _confirmToggleBlock(otherName, isBlocked);
                  } else if (value == 'delete') {
                    _confirmDeleteConversation(item, otherName);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Text(tr('إبلاغ عن المستخدم', 'Report User')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(
                          isBlocked ? Icons.lock_open : Icons.block,
                          color: isBlocked ? Colors.teal : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(isBlocked
                            ? tr('إلغاء حظر المستخدم', 'Unblock User')
                            : tr('حظر المستخدم', 'Block User')),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          tr('حذف المحادثة', 'Delete Conversation'),
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
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: isDealClosed
                        ? Colors.green.shade50
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Row(
                      children: [
                        Icon(
                          isDealClosed
                              ? Icons.verified
                              : Icons.chat_bubble_outline,
                          color: isDealClosed
                              ? Colors.green.shade700
                              : Colors.indigo,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDealClosed
                                    ? tr('محادثة إتمام الصفقة والتسليم بين الطرفين',
                                        'Deal Completion & Direct Chat')
                                    : tr('محادثة مباشرة بخصوص السلعة',
                                        'Direct inquiry about this item'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                isDealClosed
                                    ? tr('يمكنكم التنسيق واستلام السلعة عبر هذه المحادثة الفورية بكل أمان',
                                        'Coordinate delivery directly via this chat safely')
                                    : tr('اضغط مطولاً على أي رسالة للنسخ أو الحذف، أو استخدم القائمة العلوية للحظر والإبلاغ',
                                        'Long press any message to copy or delete'),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visibleMsgs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                tr('ابدأ المحادثة مع $otherName للاستفسار عن السلعة أو التنسيق.',
                                    'Start chatting with $otherName.'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount:
                                visibleMsgs.length + (hasOlder ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (hasOlder && i == 0) {
                                final remaining =
                                    msgs.length - _visibleLimit;
                                return Center(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _visibleLimit += 30;
                                        });
                                      },
                                      icon: const Icon(Icons.history,
                                          size: 16),
                                      label: Text(
                                        tr('تحميل الرسائل الأقدم ($remaining)',
                                            'Load older messages ($remaining)'),
                                        style:
                                            const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final m =
                                  visibleMsgs[hasOlder ? i - 1 : i];
                              final isMe = store.isUserMe(m.sender);
                              return Align(
                                alignment: isMe
                                    ? AlignmentDirectional.centerStart
                                    : AlignmentDirectional.centerEnd,
                                child: GestureDetector(
                                  onLongPress: () =>
                                      _showMessageActions(item, m, isMe),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildMessageContent(m, isMe),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              ago(m.time),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isMe
                                                    ? Colors.white70
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 5),
                                              if (!m.isDelivered)
                                                const Icon(
                                                  Icons.access_time,
                                                  size: 12,
                                                  color: Colors.white70,
                                                )
                                              else if (m.isRead)
                                                Icon(
                                                  Icons.done_all,
                                                  size: 15,
                                                  color: Colors
                                                      .lightBlueAccent
                                                      .shade100,
                                                )
                                              else
                                                const Icon(
                                                  Icons.done,
                                                  size: 14,
                                                  color: Colors.white70,
                                                ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    child: isBlocked
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            color: Colors.red.shade50,
                            child: Row(
                              children: [
                                Icon(Icons.block,
                                    color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tr('لقد قمت بحظر هذا المستخدم. ألغِ الحظر لإرسال رسائل.',
                                        'You blocked this user. Unblock to send messages.'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _confirmToggleBlock(otherName, true),
                                  child: Text(tr('إلغاء الحظر', 'Unblock')),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: tr('إرسال صورة', 'Send Photo'),
                                  icon: const Icon(Icons.add_photo_alternate_outlined,
                                      color: Colors.indigo),
                                  onPressed: sendImage,
                                ),
                                IconButton(
                                  tooltip: tr('إرسال موقع التسليم', 'Send Location'),
                                  icon: const Icon(Icons.location_on_outlined,
                                      color: Colors.redAccent),
                                  onPressed: sendLocation,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: textCtrl,
                                    decoration: InputDecoration(
                                      hintText: tr('اكتب رسالتك...',
                                          'Type a message...'),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
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

// ======================= صفحة قائمة الرسائل والمحادثات (Messages Inbox) =======================

class MessagesInboxView extends StatefulWidget {
  final VoidCallback? onGoToSettings;
  const MessagesInboxView({super.key, this.onGoToSettings});

  @override
  State<MessagesInboxView> createState() => _MessagesInboxViewState();
}

class _MessagesInboxViewState extends State<MessagesInboxView> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  String _formatLastMessage(String text) {
    if (text.startsWith('[image:') && text.endsWith(']')) {
      return tr('📷 صورة', '📷 Photo');
    }
    if (text.startsWith('[location:') && text.endsWith(']')) {
      final loc = text.substring(10, text.length - 1);
      return '📍 $loc';
    }
    return text;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!settings.isLoggedIn) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(20),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.indigo),
                  const SizedBox(height: 16),
                  Text(
                    tr('الرسائل والمحادثات المباشرة',
                        'Direct Messages & Inquiries'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('سجّل الدخول بحساب Google للدردشة مع البائعين والمشترين ومتابعة صفقاتك.',
                        'Sign in to chat with buyers and sellers and track your deals.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      if (widget.onGoToSettings != null) {
                        widget.onGoToSettings!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsPage()),
                        );
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: Text(tr('تسجيل الدخول من الإعدادات',
                        'Go to Settings to Sign In')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        var convs = store.getMyConversations();
        final q = _searchQuery.trim().toLowerCase();
        if (q.isNotEmpty) {
          convs = convs.where((c) {
            return c.otherParty.toLowerCase().contains(q) ||
                displayName(c.otherParty).toLowerCase().contains(q) ||
                c.item.title.toLowerCase().contains(q) ||
                c.lastMessage.text.toLowerCase().contains(q);
          }).toList();
        }

        return RefreshIndicator(
          onRefresh: () => store.pullFromSupabase(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  // شريط البحث في المحادثات
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: tr('ابحث في الرسائل أو أسماء البائعين...',
                            'Search messages or users...'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),

                  // قائمة المحادثات
                  Expanded(
                    child: convs.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                  height: MediaQuery.of(context).size.height *
                                      0.18),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 72,
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? tr('لا توجد محادثات تطابق بحثك',
                                              'No matching conversations')
                                          : tr('لا توجد رسائل بعد',
                                              'No messages yet'),
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32),
                                      child: Text(
                                        _searchQuery.isNotEmpty
                                            ? tr(
                                                'جرّب كتابة اسم شخص آخر أو سلعة أخرى.',
                                                'Try a different user or item name.')
                                            : tr(
                                                'ابدأ محادثة مع أي بائع عبر الضغط على زر (مراسلة) في صفحة تفاصيل أي مزاد.',
                                                'Start a chat with any seller via the (Chat) button on item details.'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: convs.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, indent: 72),
                            itemBuilder: (context, i) {
                              final conv = convs[i];
                              final isLastFromMe =
                                  store.isUserMe(conv.lastMessage.sender);
                              final otherName = displayName(conv.otherParty);
                              final item = conv.item;
                              final unread = conv.unreadCount;
                              final isBlocked =
                                  store.isUserBlocked(conv.otherParty);

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                leading: buildUserAvatar(
                                  conv.otherParty,
                                  radius: 26,
                                  badge: unread > 0
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade600,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$unread',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              otherName,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: unread > 0
                                                    ? FontWeight.w900
                                                    : FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isBlocked) ...[
                                            const SizedBox(width: 6),
                                            Icon(Icons.block,
                                                size: 14,
                                                color: Colors.red.shade700),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(
                                      ago(conv.lastMessage.time),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: unread > 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: unread > 0
                                            ? Colors.green.shade700
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            categoryIcon(item.category),
                                            size: 12,
                                            color: scheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: scheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (isLastFromMe) ...[
                                          Icon(
                                            !conv.lastMessage.isDelivered
                                                ? Icons.access_time
                                                : (conv.lastMessage.isRead
                                                    ? Icons.done_all
                                                    : Icons.done),
                                            size: 14,
                                            color: conv.lastMessage.isRead
                                                ? Colors.blue
                                                : scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            isLastFromMe
                                                ? '${tr("أنت:", "You:")} ${_formatLastMessage(conv.lastMessage.text)}'
                                                : _formatLastMessage(conv.lastMessage.text),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: unread > 0
                                                  ? scheme.onSurface
                                                  : (isLastFromMe
                                                      ? scheme.onSurfaceVariant
                                                      : scheme.onSurface),
                                              fontWeight: unread > 0
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (val) {
                                    if (val == 'read') {
                                      store.markConversationAsRead(
                                          conv.item.id, conv.otherParty);
                                    } else if (val == 'block') {
                                      if (isBlocked) {
                                        store.unblockUser(conv.otherParty);
                                      } else {
                                        store.blockUser(conv.otherParty);
                                      }
                                    } else if (val == 'delete') {
                                      store.deleteConversation(
                                          conv.item.id, conv.otherParty);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    if (unread > 0)
                                      PopupMenuItem(
                                        value: 'read',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.done_all,
                                                size: 18, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text(tr('تعليم كمقروء',
                                                'Mark as Read')),
                                          ],
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'block',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isBlocked
                                                ? Icons.lock_open
                                                : Icons.block,
                                            size: 18,
                                            color: isBlocked
                                                ? Colors.teal
                                                : Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(isBlocked
                                              ? tr('إلغاء الحظر', 'Unblock')
                                              : tr('حظر المستخدم',
                                                  'Block User')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline,
                                              size: 18, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text(
                                            tr('حذف المحادثة',
                                                'Delete Conversation'),
                                            style: const TextStyle(
                                                color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  store.markConversationAsRead(
                                      conv.item.id, conv.otherParty);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DirectChatPage(
                                        item: conv.item,
                                        otherParty: conv.otherParty,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
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
