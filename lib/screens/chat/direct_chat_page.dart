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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDealClosed = item.isEnded &&
        item.highestBidder != null &&
        (item.seller == me || item.highestBidder == me);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final allMsgs = store.getDirectMessages(item.id);
        final msgs = allMsgs.where((m) =>
            (m.sender == me && m.receiver == widget.otherParty) ||
            (m.sender == widget.otherParty && m.receiver == me) ||
            m.sender == widget.otherParty ||
            m.receiver == widget.otherParty).toList();
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
                                    : tr('تواصل مع البائع للاستفسار عن أي تفاصيل للسلعة',
                                        'Chat directly to ask about item details'),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.indigo),
                  const SizedBox(height: 16),
                  Text(
                    tr('الرسائل والمحادثات المباشرة', 'Direct Messages & Inquiries'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        );
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: Text(tr('تسجيل الدخول من الإعدادات', 'Go to Settings to Sign In')),
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
                        hintText: tr('ابحث في الرسائل أو أسماء البائعين...', 'Search messages or users...'),
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
                        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                              SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 72,
                                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? tr('لا توجد محادثات تطابق بحثك', 'No matching conversations')
                                          : tr('لا توجد رسائل بعد', 'No messages yet'),
                                      style: const TextStyle(
                                          fontSize: 17, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 32),
                                      child: Text(
                                        _searchQuery.isNotEmpty
                                            ? tr('جرّب كتابة اسم شخص آخر أو سلعة أخرى.',
                                                'Try a different user or item name.')
                                            : tr('ابدأ محادثة مع أي بائع عبر الضغط على زر (مراسلة) في صفحة تفاصيل أي مزاد.',
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
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                            itemBuilder: (context, i) {
                              final conv = convs[i];
                              final isLastFromMe = conv.lastMessage.sender == me;
                              final otherName = displayName(conv.otherParty);
                              final item = conv.item;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: scheme.primaryContainer,
                                  foregroundColor: scheme.onPrimaryContainer,
                                  child: Text(
                                    otherName.characters.isNotEmpty
                                        ? otherName.characters.first
                                        : '؟',
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        otherName,
                                        style: const TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      ago(conv.lastMessage.time),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant,
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
                                    Text(
                                      isLastFromMe
                                          ? '${tr("أنت:", "You:")} ${conv.lastMessage.text}'
                                          : conv.lastMessage.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isLastFromMe
                                            ? scheme.onSurfaceVariant
                                            : scheme.onSurface,
                                        fontWeight: isLastFromMe
                                            ? FontWeight.normal
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_left, size: 20),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DirectChatPage(
                                      item: conv.item,
                                      otherParty: conv.otherParty,
                                    ),
                                  ),
                                ),
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

