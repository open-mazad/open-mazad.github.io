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
  bool _showSafetyTips = true;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = textCtrl.text.trim().isNotEmpty;
    textCtrl.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.markConversationAsRead(widget.item.id, widget.otherParty);
    });
  }

  void _onTextChanged() {
    final has = textCtrl.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    textCtrl.removeListener(_onTextChanged);
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

  Future<void> _pickImage(ImageSource source) async {
    if (store.isUserBlocked(widget.otherParty)) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
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
            content: Text(tr('تعذر التقاط/اختيار الصورة', 'Failed to pick image'))),
      );
    }
  }

  Future<void> _pickVideo({bool gallery = false}) async {
    if (store.isUserBlocked(widget.otherParty)) return;
    try {
      final picked = await ImagePicker().pickVideo(
        source: gallery ? ImageSource.gallery : ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      if (picked != null) {
        store.sendDirectMessage(
            widget.item, widget.otherParty, '[video:مقطع فيديو لمعاينة السلعة]');
        if (mounted) setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('تعذر تسجيل/اختيار الفيديو', 'Failed to pick video'))),
      );
    }
  }

  Future<void> sendLocation() async {
    if (store.isUserBlocked(widget.otherParty)) return;

    // محاولة جلب إحداثيات الـ GPS الحية الفعلية من المتصفح / الجهاز
    final gps = await fetchLiveGpsCoordinates();
    if (gps != null) {
      final lat = gps.$1;
      final lng = gps.$2;
      final mapsUrl = 'https://www.google.com/maps?q=$lat,$lng';
      store.sendDirectMessage(
        widget.item,
        widget.otherParty,
        '[location:📍 موقع حي عبر GPS (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})|$mapsUrl]',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('تم إرسال موقعك الفعلي عبر الـ GPS 📍', 'Live GPS location sent 📍')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
      return;
    }

    String selectedGov = settings.governorate.isNotEmpty
        ? settings.governorate
        : (governorates.contains(widget.item.location)
            ? widget.item.location
            : governorates.first);
    final landmarkCtrl = TextEditingController(
        text: widget.item.area.isNotEmpty && widget.item.area != 'الكل'
            ? widget.item.area
            : '');

    if (!mounted) return;
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
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("$selectedGov $landmark")}';
      store.sendDirectMessage(
          widget.item, widget.otherParty, '[location:$locText|$mapsUrl]');
      if (mounted) setState(() {});
    }
    landmarkCtrl.dispose();
  }

  Future<void> _shareAuctionItem() async {
    if (store.isUserBlocked(widget.otherParty)) return;
    final availableItems = store.items.where((it) => !it.isEnded).toList();
    if (availableItems.isEmpty) {
      availableItems.add(widget.item);
    }

    final selected = await showModalBottomSheet<Item>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined,
                      color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text(
                    tr('اختر إعلاناً / مزاداً للمشاركة',
                        'Select an Auction to Share'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: availableItems.length,
                itemBuilder: (ctx, idx) {
                  final it = availableItems[idx];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: it.imagePaths.isNotEmpty
                            ? buildSmartImage(it.imagePaths.first,
                                fit: BoxFit.cover)
                            : const Icon(Icons.image),
                      ),
                    ),
                    title: Text(it.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(formatPrice(it.currentPrice),
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.send_rounded,
                        size: 20, color: Colors.indigo),
                    onTap: () => Navigator.pop(ctx, it),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      final img =
          selected.imagePaths.isNotEmpty ? selected.imagePaths.first : '';
      store.sendDirectMessage(
          widget.item,
          widget.otherParty,
          '[item_card:${selected.id}|${selected.title}|${selected.currentPrice}|$img]');
      if (mounted) setState(() {});
    }
  }

  Future<void> _shareContactCard() async {
    if (store.isUserBlocked(widget.otherParty)) return;

    // طلب إذن الوصول إلى سجل الهاتف الفعلي للجهاز لاختيار جهة اتصال ومشاركتها
    final deviceContact = await pickPhoneDeviceContact();
    if (deviceContact != null) {
      final cName = deviceContact.$1;
      final cPhone = deviceContact.$2;
      store.sendDirectMessage(
        widget.item,
        widget.otherParty,
        '[contact:$cName|$cPhone]',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('تمت مشاركة جهة الاتصال بنجاح 👤', 'Contact shared successfully 👤')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
      return;
    }

    final myName =
        settings.fullName.isNotEmpty ? settings.fullName : displayName(me);
    final myPhone =
        settings.phone.isNotEmpty ? settings.phone : store.getUserPhone(me);

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.contact_phone, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(tr('مشاركة جهة الاتصال', 'Share Contact Card')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(
                'هل تريد إرسال رقم هاتفك وبياناتك المعتمدة للطرف الآخر للتواصل المباشر؟',
                'Do you want to share your verified phone number with the other party?')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  buildUserAvatar(me, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(myName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(myPhone,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء', 'Cancel'))),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send),
            label: Text(tr('إرسال الآن', 'Send Now')),
          ),
        ],
      ),
    );

    if (ok == true) {
      store.sendDirectMessage(
          widget.item, widget.otherParty, '[contact:$myName|$myPhone]');
      if (mounted) setState(() {});
    }
  }

  Future<void> _recordVoiceNote() async {
    if (store.isUserBlocked(widget.otherParty)) return;
    int seconds = 0;
    Timer? timer;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (ctx.mounted) setSt(() => seconds++);
          });
          return SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tr("جاري التسجيل الصوتي...", "Recording Voice Note...")} 0:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      14,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 4,
                        height: 10 + ((i * 7 + seconds * 11) % 32).toDouble(),
                        decoration: BoxDecoration(
                          color: Colors.indigoAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        onPressed: () {
                          timer?.cancel();
                          Navigator.pop(ctx, false);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(tr('إلغاء', 'Cancel')),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.indigo),
                        onPressed: () {
                          timer?.cancel();
                          Navigator.pop(ctx, true);
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: Text(tr('إرسال التسجيل 🎙️', 'Send Audio 🎙️')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    timer?.cancel();
    if (sent == true) {
      final duration = seconds > 0 ? seconds : 5;
      store.sendDirectMessage(
          widget.item, widget.otherParty, '[audio:$duration]');
      if (mounted) setState(() {});
    }
  }

  void _showAttachmentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _attachmentItem(
              icon: Icons.camera_alt_outlined,
              label: tr('التقط صورة', 'Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            _attachmentItem(
              icon: Icons.videocam_outlined,
              label: tr('سجل فيديو', 'Record Video'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(gallery: false);
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            _attachmentItem(
              icon: Icons.photo_library_outlined,
              label: tr('مكتبة الصور', 'Photo Library'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            _attachmentItem(
              icon: Icons.video_library_outlined,
              label: tr('مكتبة الفيديو', 'Video Library'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(gallery: true);
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            _attachmentItem(
              icon: Icons.assignment_outlined,
              label: tr('شارك الإعلان', 'Share Listing'),
              onTap: () {
                Navigator.pop(ctx);
                _shareAuctionItem();
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            _attachmentItem(
              icon: Icons.location_on_outlined,
              label: tr('الموقع', 'Location'),
              onTap: () {
                Navigator.pop(ctx);
                sendLocation();
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            _attachmentItem(
              icon: Icons.contact_phone_outlined,
              label: tr('جهة اتصال', 'Contact Card'),
              onTap: () {
                Navigator.pop(ctx);
                _shareContactCard();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _attachmentItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            Icon(icon, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  void _makePhoneCall(String name) {
    final phone = store.getUserPhone(widget.otherParty);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone, color: Colors.green),
            const SizedBox(width: 8),
            Text(tr('الاتصال بالطرف الآخر', 'Call Contact')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tr("المستخدم:", "User:")} $name',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (phone.isNotEmpty) ...[
              Text('${tr("رقم الهاتف:", "Phone:")} $phone',
                  style: const TextStyle(
                      fontSize: 15,
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                tr('يمكنك نسخ الرقم أو الاتصال به مباشرة للتنسيق.',
                    'You can copy the number or call directly.'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else ...[
              Text(
                tr('لم يقم المستخدم بإرفاق رقم هاتف موثوق بعد. يمكنك طلب رقم هاتفه داخل المحادثة.',
                    'No verified phone number added yet. You can request it in the chat.'),
                style:
                    const TextStyle(fontSize: 13, color: Colors.redAccent),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('إغلاق', 'Close'))),
          if (phone.isNotEmpty)
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(tr('تم نسخ رقم الهاتف 📋',
                          'Phone number copied 📋'))),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(tr('نسخ الرقم', 'Copy Number')),
            ),
        ],
      ),
    );
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
    if (m.text.startsWith('[video:') && m.text.endsWith(']')) {
      final desc = m.text.substring(7, m.text.length - 1);
      return Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.deepPurple.shade100,
              child: const Icon(Icons.videocam_rounded,
                  color: Colors.deepPurple, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('مقطع فيديو 🎥', 'Video Clip 🎥'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white : Colors.deepPurple.shade900,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (m.text.startsWith('[call:') && m.text.endsWith(']')) {
      final callInfo = m.text.substring(6, m.text.length - 1);
      return Container(
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.teal.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.phone_in_talk, color: Colors.teal, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('مكالمة صوتية داخل التطبيق 📞', 'In-App Voice Call 📞'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white70 : Colors.teal.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    callInfo,
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
    if (m.text.startsWith('[location:') && m.text.endsWith(']')) {
      final raw = m.text.substring(10, m.text.length - 1);
      final parts = raw.split('|');
      final loc = parts[0];
      final mapsUrl = parts.length > 1 ? parts[1] : null;

      return Container(
        constraints: const BoxConstraints(maxWidth: 270),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
            if (mapsUrl != null && mapsUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isMe ? Colors.white24 : Colors.blue.shade50,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: mapsUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('تم نسخ رابط خرائط Google 🗺️', 'Google Maps link copied 🗺️'))),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 14),
                  label: Text(
                    tr('نسخ رابط خرائط Google 🗺️', 'Copy Google Maps link 🗺️'),
                    style: TextStyle(fontSize: 11, color: isMe ? Colors.white : Colors.indigo.shade900),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (m.text.startsWith('[item_card:') && m.text.endsWith(']')) {
      final payload = m.text.substring(11, m.text.length - 1);
      final parts = payload.split('|');
      final itemId = parts.isNotEmpty ? parts[0] : '';
      final itemTitle = parts.length > 1 ? parts[1] : '';
      final itemPrice =
          parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
      final itemImg = parts.length > 3 ? parts[3] : '';

      return Container(
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isMe ? Colors.white38 : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: itemImg.isNotEmpty
                        ? buildSmartImage(itemImg, fit: BoxFit.cover)
                        : const Icon(Icons.gavel, size: 28),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatPrice(itemPrice),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      isMe ? Colors.white24 : Colors.indigo.shade50,
                ),
                onPressed: () {
                  final target = store.items.firstWhere(
                    (it) =>
                        it.id == itemId ||
                        AuctionStore.itemToUuid(it.id) ==
                            AuctionStore.itemToUuid(itemId),
                    orElse: () => widget.item,
                  );
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ItemDetailsPage(item: target)));
                },
                child: Text(
                  tr('معاينة المزاد 🔨', 'View Auction 🔨'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white : Colors.indigo.shade900,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (m.text.startsWith('[contact:') && m.text.endsWith(']')) {
      final payload = m.text.substring(9, m.text.length - 1);
      final parts = payload.split('|');
      final cName = parts.isNotEmpty ? parts[0] : '';
      final cPhone = parts.length > 1 ? parts[1] : '';

      return Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isMe ? Colors.white38 : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.indigo.shade100,
                  child: const Icon(Icons.person,
                      color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        cPhone,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : Colors.indigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: isMe ? Colors.white : Colors.indigo,
                      side: BorderSide(
                          color: isMe
                              ? Colors.white38
                              : Colors.indigo.shade200),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: cPhone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text(tr('تم نسخ الرقم 📋', 'Copied 📋'))),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: Text(tr('نسخ', 'Copy'),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: () => _makePhoneCall(cName),
                    icon: const Icon(Icons.call, size: 14),
                    label: Text(tr('اتصال', 'Call'),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (m.text.startsWith('[audio:') && m.text.endsWith(']')) {
      final sec = m.text.substring(7, m.text.length - 1);
      final durationStr = '0:${sec.padLeft(2, '0')}';
      return Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  isMe ? Colors.white24 : Colors.indigo.shade100,
              child: Icon(
                Icons.play_arrow_rounded,
                color: isMe ? Colors.white : Colors.indigo,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: List.generate(
                9,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 3,
                  height: 8 + ((i * 5) % 18).toDouble(),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white70 : Colors.indigo.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              durationStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.mic,
              size: 15,
              color: isMe ? Colors.white70 : Colors.indigo.shade300,
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

    if (!mounted) return;
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
    if (!mounted) return;
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

  Future<void> _confirmDeleteItemChat(Item item) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('حذف محادثة السلعة', 'Delete Item Chat'))),
          ],
        ),
        content: Text(
          tr(
            'هل تريد حذف المحادثة المباشرة المتعلقة بهذه السلعة فقط نهائياً؟',
            'Delete direct chat for this item permanently?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(tr('حذف المحادثة', 'Delete')),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      store.deleteItemDirectChat(item.id);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم حذف محادثة هذه السلعة نهائياً 🗑️', 'Item chat deleted permanently 🗑️')),
          backgroundColor: Colors.orange.shade800,
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

        final isOnline = store.isUserOnline(widget.otherParty);

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: () => showUserProfileSheet(context, widget.otherParty),
              child: Row(
                children: [
                  Stack(
                    children: [
                      buildUserAvatar(widget.otherParty, radius: 18),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? Colors.greenAccent.shade400
                                : Colors.grey.shade400,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                otherName,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
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
                          isOnline
                              ? tr('متصل الآن 🟢', 'Online now 🟢')
                              : tr('غير متصل ⚪', 'Offline ⚪'),
                          style: TextStyle(
                            fontSize: 11,
                            color: isOnline ? Colors.green.shade600 : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: tr('اتصال صوتي داخل التطبيق', 'In-App Voice Call'),
                icon: const Icon(Icons.call, color: Colors.white70),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InAppVoiceCallScreen(
                        otherParty: widget.otherParty,
                        item: item,
                      ),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                tooltip: tr('خيارات المحادثة', 'Chat Options'),
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onSelected: (value) {
                  if (value == 'profile') {
                    showUserProfileSheet(context, widget.otherParty);
                  } else if (value == 'report') {
                    _showReportDialog(item, otherName);
                  } else if (value == 'block') {
                    _confirmToggleBlock(otherName, isBlocked);
                  } else if (value == 'delete_item') {
                    _confirmDeleteItemChat(item);
                  } else if (value == 'delete') {
                    _confirmDeleteConversation(item, otherName);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 10),
                        Text(tr('الملف الشخصي والتقييم', 'Profile & Rating')),
                      ],
                    ),
                  ),
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
                    value: 'delete_item',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_outlined,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          tr('حذف محادثة هذه السلعة 🗑️', 'Delete this item chat 🗑️'),
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          tr('حذف كل المحادثة ⚠️', 'Delete All Chat ⚠️'),
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
                  // 1. شريط السلعة المثبت بالأعلى (Pinned Auction Bar كما في الصورة)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailsPage(item: item),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatPrice(item.currentPrice),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: item.imagePaths.isNotEmpty
                                  ? buildSmartImage(item.imagePaths.first,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.grey.shade800,
                                      child: const Icon(Icons.image, size: 26, color: Colors.white70),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. صندوق نصائح الأمان المخطط بالأحمر (Red Dashed Safety Box كما في الصورة 2)
                  if (_showSafetyTips)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.shade900.withValues(alpha: 0.6),
                          width: 1.4,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _showSafetyTips = false),
                                child: const Icon(Icons.close, size: 16, color: Colors.grey),
                              ),
                              Row(
                                children: [
                                  Text(
                                    tr('نصائح عامة', 'General Tips'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade900,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.info_rounded,
                                        color: Colors.white, size: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '• ${tr("قم بتفقّد المنتج جيداً قبل شرائه", "Inspect the product well before purchasing")}',
                                  style: TextStyle(fontSize: 12, height: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                                Text(
                                  '• ${tr("لا تقم بإرسال المال مسبقاً", "Do not send money in advance")}',
                                  style: TextStyle(fontSize: 12, height: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                                Text(
                                  '• ${tr("اجتمع في الأماكن العامة فقط", "Meet in public places only")}',
                                  style: TextStyle(fontSize: 12, height: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 3. مؤشر سرعة الرد ومعدل التجاوب (Response Speed كما في الصورة 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00B0FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bolt, size: 13, color: Colors.black),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tr('تجاوب عادي', 'Normal Response'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('عادة ما يتم الرد خلال 19 ساعة', 'Usually replies within 19 hours'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. زر التنبيه عند تخفيض سعر الإعلان (Price Alert Prompt كما في الصورة 2)
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        final alertText = tr(
                          'أريد أن اتلقى تنبيها اذا تم تخفيض سعر هذا الإعلان',
                          'I would like an alert if this item price is lowered',
                        );
                        store.sendDirectMessage(item, widget.otherParty, alertText);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('تم تفعيل التنبيه وإرسال الرسالة للبائع 🏷️', 'Alert request sent to seller 🏷️')),
                            backgroundColor: Colors.teal.shade800,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E2124)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer, size: 15, color: Colors.lightGreen),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tr('أريد أن اتلقى تنبيها اذا تم تخفيض سعر هذا الإعلان', 'Alert me if this price drops'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 6.0),
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                children: [
                                  // زر مشبك المرفقات في أقصى اليسار باللون الأزرق (كما في الصورة 3)
                                  IconButton(
                                    tooltip: tr('إرفاق ملف أو موقع', 'Attach'),
                                    icon: const Icon(Icons.attach_file_rounded,
                                        color: Colors.blueAccent, size: 26),
                                    onPressed: () => _showAttachmentSheet(context),
                                  ),
                                  const SizedBox(width: 4),
                                  // كبسولة إدخال الرسالة مع أيقونات الكاميرا والصوت في اليمين بالداخل (كما في الصورة 3)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF232528)
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Directionality(
                                              textDirection: TextDirection.rtl,
                                              child: TextField(
                                                controller: textCtrl,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 14,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: tr(
                                                      'أرسل رسالة جديدة',
                                                      'Type a new message'),
                                                  hintStyle: TextStyle(
                                                    color: Colors.grey.shade400,
                                                    fontSize: 14,
                                                  ),
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 10),
                                                  isDense: true,
                                                ),
                                                onSubmitted: (_) => send(),
                                              ),
                                            ),
                                          ),
                                          if (!_hasText) ...[
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                              tooltip: tr('التقط صورة', 'Camera'),
                                              icon: const Icon(
                                                  Icons.camera_alt_rounded,
                                                  color: Colors.blueAccent,
                                                  size: 22),
                                              onPressed: () =>
                                                  _pickImage(ImageSource.camera),
                                            ),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                              tooltip:
                                                  tr('تسجيل صوتي', 'Voice Note'),
                                              icon: const Icon(Icons.mic_rounded,
                                                  color: Colors.blueAccent,
                                                  size: 22),
                                              onPressed: _recordVoiceNote,
                                            ),
                                          ] else ...[
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                              onPressed: send,
                                              icon: const Icon(Icons.send_rounded,
                                                  color: Colors.blueAccent,
                                                  size: 22),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
    if (text.startsWith('[video:') && text.endsWith(']')) {
      return tr('🎥 مقطع فيديو', '🎥 Video');
    }
    if (text.startsWith('[location:') && text.endsWith(']')) {
      final loc = text.substring(10, text.length - 1);
      return '📍 $loc';
    }
    if (text.startsWith('[item_card:') && text.endsWith(']')) {
      return tr('🏷️ إعلان مزاد', '🏷️ Auction Listing');
    }
    if (text.startsWith('[contact:') && text.endsWith(']')) {
      return tr('👤 جهة اتصال', '👤 Contact Card');
    }
    if (text.startsWith('[audio:') && text.endsWith(']')) {
      return tr('🎤 رسالة صوتية', '🎤 Voice Note');
    }
    if (text.startsWith('[call:') && text.endsWith(']')) {
      return tr('📞 مكالمة صوتية', '📞 Voice Call');
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
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    buildUserAvatar(
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
                                    if (store.isUserOnline(conv.otherParty))
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent.shade700,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              width: 2.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
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

// ======================= شاشة المكالمة الصوتية داخل التطبيق (In-App Voice Call) =======================

class InAppVoiceCallScreen extends StatefulWidget {
  final String otherParty;
  final Item item;
  const InAppVoiceCallScreen({
    super.key,
    required this.otherParty,
    required this.item,
  });

  @override
  State<InAppVoiceCallScreen> createState() => _InAppVoiceCallScreenState();
}

class _InAppVoiceCallScreenState extends State<InAppVoiceCallScreen> {
  bool _isRinging = true;
  bool _isMuted = false;
  bool _isSpeaker = false;
  int _seconds = 0;
  Timer? _ringTimer;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    // محاكاة رنين المكالمة وتنبيه الطرف الآخر
    _ringTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _isRinging = false;
      });
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    });
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _callTimer?.cancel();
    super.dispose();
  }

  void _endCall() {
    _ringTimer?.cancel();
    _callTimer?.cancel();
    final callText = _isRinging
        ? tr('مكالمة صوتية لم يُرد عليها 📵', 'Missed voice call 📵')
        : '${tr("مكالمة صوتية منتهية 📞", "Ended voice call 📞")} ($_seconds ${tr("ثانية", "sec")})';
    store.sendDirectMessage(widget.item, widget.otherParty, '[call:$callText]');
    store.recordUserActivity(widget.otherParty);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final otherName = displayName(widget.otherParty);
    final durationStr =
        '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF10141A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  tr('مكالمة صوتية داخل التطبيق مشفرة 🔒',
                      'Encrypted in-app voice call 🔒'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                    ),
                  ),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withValues(alpha: 0.25),
                    ),
                  ),
                  buildUserAvatar(widget.otherParty, radius: 46),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              otherName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _isRinging
                    ? Colors.amber.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isRinging ? Colors.amber : Colors.green,
                  width: 1,
                ),
              ),
              child: Text(
                _isRinging
                    ? tr('جارٍ الاتصال وتنبيه الطرف الآخر... 🔔',
                        'Calling and alerting user... 🔔')
                    : '${tr("المكالمة متصلة 🟢", "Call Connected 🟢")} $durationStr',
                style: TextStyle(
                  color: _isRinging ? Colors.amberAccent : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _isMuted
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          foregroundColor:
                              _isMuted ? Colors.black : Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: () => setState(() => _isMuted = !_isMuted),
                        icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isMuted ? tr('مكتوم', 'Muted') : tr('كتم', 'Mute'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(20),
                        ),
                        onPressed: _endCall,
                        icon: const Icon(Icons.call_end, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('إنهاء المكالمة', 'End Call'),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _isSpeaker
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          foregroundColor:
                              _isSpeaker ? Colors.black : Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: () => setState(() => _isSpeaker = !_isSpeaker),
                        icon: Icon(_isSpeaker ? Icons.volume_up : Icons.volume_down),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSpeaker ? tr('مكبر الصوت', 'Speaker') : tr('سماعة', 'Earpiece'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
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
  }
}

// ======================= إدارة المستخدمين المحظورين (Blocked Users Sheet) =======================

void showBlockedUsersSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final blocked = store.myBlockedUsersList;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.block, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(
                      tr('إدارة المستخدمين المحظورين', 'Blocked Users Management'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (blocked.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            tr('قائمة الحظر فارغة - لم تقم بحظر أي مستخدم',
                                'No blocked users. Your block list is empty.'),
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    tr('المستخدمون المحظورون لا يمكنهم مراسلتك أو التعليق على مزاداتك:',
                        'Blocked users cannot chat with you or comment:'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: blocked.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final user = blocked[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal),
                            ),
                            onPressed: () {
                              store.unblockUser(user);
                              setSt(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr('تم إلغاء حظر $user بنجاح', 'Unblocked $user successfully')),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            },
                            child: Text(tr('إلغاء الحظر', 'Unblock')),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
