part of '../main.dart';

// ======================= المخزن الشامل (AuctionStore) =======================

class AuctionStore extends ChangeNotifier {
  final List<Item> items = [];
  final Set<String> favorites = {};
  final Set<String> unlockedPrivateItems = {};
  final List<String> savedSearchKeywords = [];
  final List<AppNotification> notifications = [];
  final List<FraudReport> reports = [];
  final Map<String, List<DirectMessage>> directChats = {};
  final Map<String, List<UserReview>> userReviews = {};
  final Map<String, int> userWarnings = {};
  final Set<String> bannedUsers = {};
  final Map<String, String> userDisplayNames = {};
  final Map<String, String> userPhones = {};

  Timer? _timer;
  Timer? _pollingSafetyTimer;
  StreamSubscription? _itemsSub;
  StreamSubscription? _bidsSub;
  StreamSubscription? _messagesSub;
  StreamSubscription? _profilesSub;
  bool _hasInitialSynced = false;

  int _nextId = 100;

  bool isSyncingCloud = false;
  String? lastSyncStatus;
  DateTime? lastSyncTime;
  static const String _storeFilePath = 'muzaida_store.json';

  SupabaseClient? get supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  AuctionStore() {
    if (!_loadFromDisk()) {
      _seed();
      _saveToDisk();
    }
    settings.openAdminDashboard = (ctx) {
      Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    };
    settings.openSavedRadar = (ctx) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
            builder: (_) => const RadarAndNotificationsPage(initialTab: 1)),
      );
    };
    settings.openCloudSetup = (ctx) {
      Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const SupabaseCloudSetupPage()),
      );
    };
    settings.onAuthChanged = () {
      notifyListeners();
      if (settings.isCloudConfigured) {
        initRealtime();
      }
    };
    if (settings.isCloudConfigured) {
      initRealtime();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkScheduledAuctions();
      notifyListeners();
    });
  }

  /// تفعيل قنوات البث المباشر اللحظي (Supabase Realtime)
  /// تضمن مزامنة لحظية بالملي ثانية لأي إضافة، تعديل، أو حذف
  void initRealtime() {
    final client = supabaseClient;
    if (client == null) {
      pullFromSupabase();
      return;
    }

    _itemsSub?.cancel();
    _bidsSub?.cancel();
    _messagesSub?.cancel();
    _profilesSub?.cancel();

    try {
      // 1. مزامنة المستخدمين وصلاحية الأدمن (is_admin) لحظياً
      _profilesSub = client.from('profiles').stream(primaryKey: ['id']).listen((rows) {
        _applyProfilesStream(rows);
      }, onError: (e) {
        debugPrint('Profiles stream error: $e');
      });

      // 2. مزامنة المزادات لحظياً (إضافة وحذف وتعديل بالكامل)
      _itemsSub = client.from('items').stream(primaryKey: ['id']).listen((rows) {
        _applyItemsStream(rows);
      }, onError: (e) {
        debugPrint('Items stream error: $e');
      });

      // 3. مزامنة المزايدات وتحديث الأسعار لحظياً
      _bidsSub = client.from('bids').stream(primaryKey: ['id']).listen((rows) {
        _applyBidsStream(rows);
      }, onError: (e) {
        debugPrint('Bids stream error: $e');
      });

      // 4. مزامنة التعليقات والرسائل الخاصة لحظياً
      _messagesSub = client.from('messages').stream(primaryKey: ['id']).listen((rows) {
        _applyMessagesStream(rows);
      }, onError: (e) {
        debugPrint('Messages stream error: $e');
      });
    } catch (e) {
      debugPrint('Realtime stream setup error: $e');
    }

    // جلب أولي كامل
    pullFromSupabase(silent: true);

    // مؤقت أمان إضافي للتحديث الدوري (كل 4 ثوانٍ) لضمان الدقة المطلقة
    _pollingSafetyTimer?.cancel();
    _pollingSafetyTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (settings.isCloudConfigured) {
        pullFromSupabase(silent: true);
      }
    });
  }

  Map<String, dynamic> _exportStoreJson() => {
        'nextId': _nextId,
        'items': items.map((i) => i.toJson()).toList(),
        'favorites': favorites.toList(),
        'unlockedPrivateItems': unlockedPrivateItems.toList(),
        'savedSearchKeywords': savedSearchKeywords,
        'reports': reports.map((r) => r.toJson()).toList(),
        'directChats': directChats.map(
          (k, v) => MapEntry(k, v.map((m) => m.toJson()).toList()),
        ),
        'userReviews': userReviews.map(
          (k, v) => MapEntry(k, v.map((r) => r.toJson()).toList()),
        ),
        'userWarnings': userWarnings,
        'bannedUsers': bannedUsers.toList(),
      };

  void _importStoreJson(Map<String, dynamic> data) {
    _nextId = (data['nextId'] as num?)?.toInt() ?? 100;
    if (data['items'] is List) {
      items
        ..clear()
        ..addAll(
          (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Item.fromJson),
        );
    }
    if (data['favorites'] is List) {
      favorites
        ..clear()
        ..addAll((data['favorites'] as List).map((e) => '$e'));
    }
    if (data['unlockedPrivateItems'] is List) {
      unlockedPrivateItems
        ..clear()
        ..addAll((data['unlockedPrivateItems'] as List).map((e) => '$e'));
    }
    if (data['savedSearchKeywords'] is List) {
      savedSearchKeywords
        ..clear()
        ..addAll((data['savedSearchKeywords'] as List).map((e) => '$e'));
    }
    if (data['reports'] is List) {
      reports
        ..clear()
        ..addAll(
          (data['reports'] as List)
              .whereType<Map<String, dynamic>>()
              .map(FraudReport.fromJson),
        );
    }
    if (data['directChats'] is Map) {
      directChats.clear();
      (data['directChats'] as Map).forEach((k, v) {
        if (v is List) {
          directChats['$k'] = v
              .whereType<Map<String, dynamic>>()
              .map(DirectMessage.fromJson)
              .toList();
        }
      });
    }
    if (data['userReviews'] is Map) {
      userReviews.clear();
      (data['userReviews'] as Map).forEach((k, v) {
        if (v is List) {
          userReviews['$k'] = v
              .whereType<Map<String, dynamic>>()
              .map(UserReview.fromJson)
              .toList();
        }
      });
    }
    if (data['userWarnings'] is Map) {
      userWarnings.clear();
      (data['userWarnings'] as Map).forEach((k, v) {
        if (v is num) userWarnings['$k'] = v.toInt();
      });
    }
    if (data['bannedUsers'] is List) {
      bannedUsers
        ..clear()
        ..addAll((data['bannedUsers'] as List).map((e) => '$e'));
    }
  }

  void _saveToDisk() {
    if (kIsWeb) return;
    try {
      final f = resolveLocalStoreFile(_storeFilePath);
      f?.writeAsStringSync(jsonEncode(_exportStoreJson()));
    } catch (_) {}
  }

  bool _loadFromDisk() {
    if (kIsWeb) return false;
    try {
      final f = resolveLocalStoreFile(_storeFilePath);
      if (f == null || !f.existsSync()) return false;
      final data = jsonDecode(f.readAsStringSync());
      if (data is! Map<String, dynamic>) return false;
      _importStoreJson(data);
      return items.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _persistAndSync() {
    _saveToDisk();
    if (settings.isCloudConfigured) {
      pushToSupabase();
    }
    notifyListeners();
  }

  void resetToDemoData() {
    items.clear();
    favorites.clear();
    unlockedPrivateItems.clear();
    notifications.clear();
    reports.clear();
    directChats.clear();
    userReviews.clear();
    userWarnings.clear();
    bannedUsers.clear();
    _seed();
    _persistAndSync();
  }

  /// يولد UUID v4 عشوائي قياسي مطابق لقواعد بيانات PostgreSQL
  static String generateUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

  /// يحوّل أي معرّف نصي إلى UUID قياسي متوافق مع PostgreSQL (xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx)
  static String _toUuid(String input) {
    final trimmed = input.trim();
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(trimmed)) return trimmed.toLowerCase();

    final bytes = List<int>.filled(16, 0);
    final units = utf8.encode(trimmed);
    for (int i = 0; i < units.length; i++) {
      final idx = i % 16;
      bytes[idx] = (bytes[idx] * 31 + units[i] + i * 17) & 0xFF;
    }
    for (int round = 0; round < 32; round++) {
      final idx = round % 16;
      bytes[idx] =
          (bytes[idx] ^ ((bytes[(idx + 5) % 16] * 37 + round * 13) & 0xFF)) &
              0xFF;
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 1
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

  /// يتأكد من مطابقة المعرّف لـ UUID المزاد سواء كان مولداً حديثاً أو مجلوباً من السحابة
  static String itemToUuid(String id) {
    final trimmed = id.trim();
    if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(trimmed)) {
      return trimmed.toLowerCase();
    }
    return _toUuid('item_$trimmed');
  }

  /// يتأكد من مطابقة معرّف المستخدم لـ UUID
  static String userToUuid(String u) {
    if (u == me && settings.userId != null && settings.userId!.isNotEmpty) {
      return settings.userId!;
    }
    final trimmed = u.trim();
    if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(trimmed)) {
      return trimmed.toLowerCase();
    }
    return _toUuid('user_$trimmed');
  }

  Future<void> _ensureProfileExists(String userUuid, String userName) async {
    final client = supabaseClient;
    if (client == null) return;
    try {
      final isMeUser = userName == me;
      await client.from('profiles').upsert({
        'id': userUuid,
        'phone': getUserPhone(userName),
        'first_name': isMeUser && settings.firstName.trim().isNotEmpty
            ? settings.firstName.trim()
            : userName,
        'second_name': isMeUser && settings.secondName.trim().isNotEmpty
            ? settings.secondName.trim()
            : '-',
        'third_name': isMeUser && settings.thirdName.trim().isNotEmpty
            ? settings.thirdName.trim()
            : '-',
        'governorate': isMeUser && settings.governorate.trim().isNotEmpty
            ? settings.governorate.trim()
            : 'بغداد',
        'photo_url': isMeUser ? settings.cloudPhotoUrl : null,
        'rating': double.parse(getUserRating(userName).toStringAsFixed(1)),
        'is_banned': bannedUsers.contains(userName),
      }, onConflict: 'id');
    } catch (_) {}
  }

  // ----------------------- معالجات البث اللحظي (Realtime Stream Handlers) -----------------------

  void _applyProfilesStream(List<Map<String, dynamic>> rows) {
    final myUuid = settings.userId ?? userToUuid(me);
    for (final row in rows) {
      final id = '${row['id'] ?? ''}';
      final firstName = '${row['first_name'] ?? ''}'.trim();
      final secondName = '${row['second_name'] ?? ''}'.trim();
      final full = [firstName, if (secondName != '-') secondName]
          .where((s) => s.isNotEmpty)
          .join(' ');
      final name = (id == myUuid) ? me : (full.isNotEmpty ? full : 'مستخدم');
      userDisplayNames[id] = full.isNotEmpty ? full : name;
      final ph = '${row['phone'] ?? ''}'.trim();
      if (ph.isNotEmpty) {
        userPhones[id] = ph;
        userPhones[name] = ph;
      }
      if (row['is_banned'] == true) {
        bannedUsers.add(name);
      } else {
        bannedUsers.remove(name);
      }

      // مزامنة حالة الآدمن لحظياً إذا تم تغييرها في قاعدة البيانات
      final isAdm = row['is_admin'];
      final bool isAdminVal = isAdm == true || isAdm == 'true' || isAdm == 1;
      if (settings.isLoggedIn &&
          (id == myUuid || (settings.phone.isNotEmpty && ph == settings.phone.trim()))) {
        if (settings.isAdmin != isAdminVal) {
          settings.isAdmin = isAdminVal;
          settings.save();
          settings.notifyListeners();
        }
      }
    }
    notifyListeners();
  }

  void _applyItemsStream(List<Map<String, dynamic>> rows) {
    _hasInitialSynced = true;

    // إذا حُذفت جميع السلع في السحابة
    if (rows.isEmpty) {
      if (items.isNotEmpty) {
        items.clear();
        _saveToDisk();
        notifyListeners();
      }
      return;
    }

    final existingBids = <String, List<Bid>>{};
    final existingComments = <String, List<AuctionComment>>{};
    final existingAutoBids = <String, Map<String, int>>{};
    for (final it in items) {
      existingBids[it.id] = List.from(it.bids);
      existingComments[it.id] = List.from(it.comments);
      existingAutoBids[it.id] = Map.from(it.autoBids);
    }

    final loadedItems = <Item>[];
    for (final row in rows) {
      final itemId = '${row['id'] ?? ''}';
      final sellerUuid = '${row['seller_id'] ?? ''}';
      final sellerName = userDisplayNames[sellerUuid] ?? 'مستخدم';

      final rawAttrs = <String, String>{};
      if (row['attributes'] is Map) {
        (row['attributes'] as Map).forEach((k, v) {
          rawAttrs['$k'] = '$v';
        });
      }
      final area = rawAttrs.remove('_area') ?? 'المركز';
      final isLive = rawAttrs.remove('_live') == '1';

      final imgs = <String>[];
      if (row['images'] is List) {
        for (final img in row['images'] as List) {
          imgs.add('$img');
        }
      }

      final item = Item(
        id: itemId,
        title: '${row['title'] ?? ''}',
        description: '${row['description'] ?? ''}',
        category: '${row['category'] ?? 'إلكترونيات وأجهزة'}',
        seller: sellerName,
        condition: '${row['condition'] ?? 'شبه جديد'}',
        location: '${row['location'] ?? 'بغداد'}',
        area: area,
        deliveryMethod: '${row['delivery_method'] ?? 'استلام باليد'}',
        startPrice: (row['start_price'] as num?)?.toInt() ?? 1000,
        startTime: parseToLocal(row['start_time'],
            fallback: DateTime.now().subtract(const Duration(minutes: 1))),
        endTime: parseToLocal(row['end_time'],
            fallback: DateTime.now().add(const Duration(days: 1))),
        imagePaths: imgs,
        videoPath: row['video_url'] as String?,
        attributes: rawAttrs,
        pinCode: row['pin_code'] as String?,
        isEndedEarlyBySeller: row['is_ended_early'] as bool? ?? false,
        isCancelled: row['is_cancelled'] as bool? ?? false,
        isLiveStreaming: isLive,
      );

      if (existingBids.containsKey(itemId)) {
        item.bids.addAll(existingBids[itemId]!);
      }
      if (existingComments.containsKey(itemId)) {
        item.comments.addAll(existingComments[itemId]!);
      }
      if (existingAutoBids.containsKey(itemId)) {
        item.autoBids.addAll(existingAutoBids[itemId]!);
      }

      loadedItems.add(item);
    }

    items.clear();
    items.addAll(loadedItems);
    _saveToDisk();
    notifyListeners();
  }

  void _applyBidsStream(List<Map<String, dynamic>> rows) {
    final bidsByItem = <String, List<Bid>>{};
    for (final b in rows) {
      final itemId = '${b['item_id'] ?? ''}';
      final bidderUuid = '${b['bidder_id'] ?? ''}';
      final bidderName = userDisplayNames[bidderUuid] ?? 'مزايد';
      final amount = (b['amount'] as num?)?.toInt() ?? 0;
      final time = parseToLocal(b['created_at']);
      final isAuto = b['is_auto'] as bool? ?? false;
      bidsByItem.putIfAbsent(itemId, () => []).add(Bid(bidderName, amount, time, isAuto: isAuto));
    }

    for (final item in items) {
      if (bidsByItem.containsKey(item.id)) {
        item.bids.clear();
        final list = bidsByItem[item.id]!;
        list.sort((a, b) => b.time.compareTo(a.time));
        item.bids.addAll(list);
      }
    }
    notifyListeners();
  }

  void _applyMessagesStream(List<Map<String, dynamic>> rows) {
    final commentsByItem = <String, List<AuctionComment>>{};
    final newDirectChats = <String, List<DirectMessage>>{};

    for (final m in rows) {
      final itemId = '${m['item_id'] ?? ''}';
      final senderUuid = '${m['sender_id'] ?? ''}';
      final sender = userDisplayNames[senderUuid] ?? 'مستخدم';
      final receiverUuid = m['receiver_id'] as String?;
      final text = '${m['content'] ?? ''}';
      final time = parseToLocal(m['created_at']);

      if (receiverUuid == null || receiverUuid.isEmpty) {
        commentsByItem.putIfAbsent(itemId, () => []).add(AuctionComment(sender, text, time));
      } else {
        final receiver = userDisplayNames[receiverUuid] ?? 'مستخدم';
        newDirectChats.putIfAbsent(itemId, () => []).add(DirectMessage(sender, receiver, text, time));
      }
    }

    for (final item in items) {
      if (commentsByItem.containsKey(item.id)) {
        item.comments.clear();
        item.comments.addAll(commentsByItem[item.id]!);
      }
    }
    directChats.clear();
    directChats.addAll(newDirectChats);
    notifyListeners();
  }

  Future<(int, String)> _upsertRows(
    String baseUrl,
    String table,
    String onConflict,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return (200, '[]');
    try {
      await Supabase.instance.client.from(table).upsert(rows);
      return (200, '[]');
    } catch (e) {
      if (kIsWeb) return (500, '$e');
      try {
        final uri = Uri.parse('$baseUrl/rest/v1/$table?on_conflict=$onConflict');
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final req = await client.postUrl(uri);
        final key = settings.supabaseAnonKey.trim();
        req.headers.set('apikey', key);
        if (key.startsWith('eyJ')) {
          req.headers.set('Authorization', 'Bearer $key');
        }
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('Prefer', 'resolution=merge-duplicates');
        req.add(utf8.encode(jsonEncode(rows)));
        final res = await req.close();
        final resBody = await res.transform(utf8.decoder).join();
        client.close();
        return (res.statusCode, resBody);
      } catch (err) {
        return (500, '$err');
      }
    }
  }

  Future<(int, String)> _fetchRows(String baseUrl, String pathAndQuery) async {
    try {
      final tableName = pathAndQuery.split('?').first;
      final res = await Supabase.instance.client.from(tableName).select();
      return (200, jsonEncode(res));
    } catch (e) {
      if (kIsWeb) return (500, '$e');
      try {
        final uri = Uri.parse('$baseUrl/rest/v1/$pathAndQuery');
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final req = await client.getUrl(uri);
        final key = settings.supabaseAnonKey.trim();
        req.headers.set('apikey', key);
        if (key.startsWith('eyJ')) {
          req.headers.set('Authorization', 'Bearer $key');
        }
        final res = await req.close();
        final resBody = await res.transform(utf8.decoder).join();
        client.close();
        return (res.statusCode, resBody);
      } catch (err) {
        return (500, '$err');
      }
    }
  }

  /// رفع ومزامنة البيانات مع الجداول الـ 5 في قاعدة بيانات Supabase السحابية:
  /// (profiles, items, bids, auto_bids, messages)
  Future<String?> pushToSupabase() async {
    if (!settings.isCloudConfigured) {
      return tr('الرجاء إدخال رابط ومفتاح Supabase أولاً',
          'Please configure Supabase URL & Anon Key first');
    }
    isSyncingCloud = true;
    notifyListeners();
    try {
      final baseUrl = settings.supabaseUrl
          .replaceAll(RegExp(r'/rest/v1/?$'), '')
          .replaceAll(RegExp(r'/$'), '');

      // 1. جمع كافة المستخدمين وبناء صفوف جدول profiles
      final usersSet = <String>{...allKnownUsers};
      for (final item in items) {
        usersSet.add(item.seller);
        for (final b in item.bids) {
          usersSet.add(b.bidder);
        }
        for (final c in item.comments) {
          usersSet.add(c.author);
        }
        for (final entry in item.autoBids.keys) {
          usersSet.add(entry);
        }
      }
      for (final chatList in directChats.values) {
        for (final m in chatList) {
          usersSet.add(m.sender);
          usersSet.add(m.receiver);
        }
      }

      final profileRows = <Map<String, dynamic>>[];
      for (final u in usersSet) {
        final isMeUser = u == me;
        profileRows.add({
          'id': userToUuid(u),
          'phone': getUserPhone(u),
          'first_name': isMeUser && settings.firstName.trim().isNotEmpty
              ? settings.firstName.trim()
              : u,
          'second_name': isMeUser && settings.secondName.trim().isNotEmpty
              ? settings.secondName.trim()
              : '-',
          'third_name': isMeUser && settings.thirdName.trim().isNotEmpty
              ? settings.thirdName.trim()
              : '-',
          'governorate': isMeUser && settings.governorate.trim().isNotEmpty
              ? settings.governorate.trim()
              : 'بغداد',
          'photo_url': isMeUser ? settings.cloudPhotoUrl : null,
          'rating': double.parse(getUserRating(u).toStringAsFixed(1)),
          'is_banned': bannedUsers.contains(u),
        });
      }

      final (profCode, profBody) =
          await _upsertRows(baseUrl, 'profiles', 'id', profileRows);
      if (profCode < 200 || profCode >= 300) {
        isSyncingCloud = false;
        lastSyncStatus = 'profiles HTTP $profCode: $profBody';
        notifyListeners();
        return lastSyncStatus;
      }

      // 2. بناء صفوف جدول المزادات items
      final itemRows = <Map<String, dynamic>>[];
      final bidRows = <Map<String, dynamic>>[];
      final autoBidRows = <Map<String, dynamic>>[];
      final messageRows = <Map<String, dynamic>>[];

      for (final item in items) {
        final itemUuid = itemToUuid(item.id);
        final attrsWithMeta = <String, String>{
          ...item.attributes,
          '_area': item.area,
          '_live': item.isLiveStreaming ? '1' : '0',
        };
        itemRows.add({
          'id': itemUuid,
          'seller_id': userToUuid(item.seller),
          'title': item.title,
          'description': item.description,
          'category': item.category,
          'condition': item.condition,
          'location': item.location,
          'delivery_method': item.deliveryMethod,
          'attributes': attrsWithMeta,
          'images': item.imagePaths,
          'video_url': item.videoPath,
          'start_price': item.startPrice,
          'current_price': item.currentPrice,
          'highest_bidder_id': item.highestBidder == null
              ? null
              : userToUuid(item.highestBidder!),
          'start_time': toIsoUtc(item.startTime),
          'end_time': toIsoUtc(item.endTime),
          'pin_code': item.pinCode,
          'is_ended_early': item.isEndedEarlyBySeller,
          'is_cancelled': item.isCancelled,
        });

        // 3. بناء صفوف جدول bids
        for (final b in item.bids) {
          bidRows.add({
            'id': _toUuid(
                'bid_${itemUuid}_${b.bidder}_${b.amount}_${b.time.millisecondsSinceEpoch}'),
            'item_id': itemUuid,
            'bidder_id': userToUuid(b.bidder),
            'amount': b.amount,
            'is_auto': b.isAuto,
            'created_at': toIsoUtc(b.time),
          });
        }

        // 4. بناء صفوف جدول auto_bids
        item.autoBids.forEach((bidder, maxLim) {
          autoBidRows.add({
            'item_id': itemUuid,
            'bidder_id': userToUuid(bidder),
            'max_limit': maxLim,
          });
        });

        // 5. بناء صفوف جدول messages (التعليقات العامة: receiver_id = null)
        for (final c in item.comments) {
          messageRows.add({
            'id': _toUuid(
                'msg_pub_${itemUuid}_${c.author}_${c.time.millisecondsSinceEpoch}'),
            'item_id': itemUuid,
            'sender_id': userToUuid(c.author),
            'receiver_id': null,
            'content': c.text,
            'created_at': toIsoUtc(c.time),
          });
        }
      }

      // إضافة رسائل الدردشة الخاصة (receiver_id محدد) إلى جدول messages
      directChats.forEach((itemId, msgs) {
        final itemUuid = itemToUuid(itemId);
        final itemExists = items.any((i) => i.id == itemId || itemToUuid(i.id) == itemUuid);
        if (!itemExists) return;
        for (final m in msgs) {
          messageRows.add({
            'id': _toUuid(
                'msg_dm_${itemUuid}_${m.sender}_${m.receiver}_${m.time.millisecondsSinceEpoch}'),
            'item_id': itemUuid,
            'sender_id': userToUuid(m.sender),
            'receiver_id': userToUuid(m.receiver),
            'content': m.text,
            'created_at': toIsoUtc(m.time),
          });
        }
      });

      final (itemsCode, itemsBody) =
          await _upsertRows(baseUrl, 'items', 'id', itemRows);
      if (itemsCode < 200 || itemsCode >= 300) {
        isSyncingCloud = false;
        lastSyncStatus = 'items HTTP $itemsCode: $itemsBody';
        notifyListeners();
        return lastSyncStatus;
      }

      final (bidsCode, bidsBody) =
          await _upsertRows(baseUrl, 'bids', 'id', bidRows);
      if (bidsCode < 200 || bidsCode >= 300) {
        isSyncingCloud = false;
        lastSyncStatus = 'bids HTTP $bidsCode: $bidsBody';
        notifyListeners();
        return lastSyncStatus;
      }

      final (autoCode, autoBody) = await _upsertRows(
          baseUrl, 'auto_bids', 'item_id,bidder_id', autoBidRows);
      if (autoCode < 200 || autoCode >= 300) {
        isSyncingCloud = false;
        lastSyncStatus = 'auto_bids HTTP $autoCode: $autoBody';
        notifyListeners();
        return lastSyncStatus;
      }

      final (msgCode, msgBody) =
          await _upsertRows(baseUrl, 'messages', 'id', messageRows);
      if (msgCode < 200 || msgCode >= 300) {
        isSyncingCloud = false;
        lastSyncStatus = 'messages HTTP $msgCode: $msgBody';
        notifyListeners();
        return lastSyncStatus;
      }

      // 6. مزامنة التقييمات (reviews) والبلاغات (reports) إن وُجدت الجداول
      final reviewRows = <Map<String, dynamic>>[];
      userReviews.forEach((targetUser, revs) {
        for (final r in revs) {
          reviewRows.add({
            'id': _toUuid(
                'rev_${targetUser}_${r.reviewer}_${r.time.millisecondsSinceEpoch}'),
            'target_user_id': _toUuid('user_$targetUser'),
            'reviewer_id': _toUuid('user_${r.reviewer}'),
            'stars': r.stars,
            'comment': r.comment,
            'created_at': toIsoUtc(r.time),
          });
        }
      });
      if (reviewRows.isNotEmpty) {
        await _upsertRows(baseUrl, 'reviews', 'id', reviewRows);
      }

      final reportRows = <Map<String, dynamic>>[];
      for (final rep in reports) {
        reportRows.add({
          'id': _toUuid('rep_${rep.id}'),
          'reporter_id': _toUuid('user_${rep.reporter}'),
          'reported_user_id': _toUuid('user_${rep.reportedUser}'),
          'item_id': items.any((i) => i.id == rep.itemId)
              ? _toUuid('item_${rep.itemId}')
              : null,
          'item_title': rep.itemTitle,
          'reason': rep.reason,
          'is_resolved': rep.isResolved,
          'created_at': toIsoUtc(rep.time),
        });
      }
      if (reportRows.isNotEmpty) {
        await _upsertRows(baseUrl, 'reports', 'id', reportRows);
      }

      isSyncingCloud = false;
      lastSyncTime = DateTime.now();
      lastSyncStatus = tr(
        'تمت مزامنة قاعدة البيانات الكاملة بنجاح ✅',
        'Synced complete database successfully ✅',
      );
      notifyListeners();
      return null;
    } catch (e) {
      isSyncingCloud = false;
      lastSyncStatus = '$e';
      notifyListeners();
      return '$e';
    }
  }

  /// جلب أحدث البيانات من الجداول الـ 5 في سحابة Supabase وحفظها محلياً
  Future<String?> pullFromSupabase({bool silent = false}) async {
    if (!settings.isCloudConfigured) {
      return tr('الرجاء إدخال رابط ومفتاح Supabase أولاً',
          'Please configure Supabase URL & Anon Key first');
    }
    if (!silent) {
      isSyncingCloud = true;
      notifyListeners();
    } else {
      isSyncingCloud = true;
    }
    try {
      final baseUrl = settings.supabaseUrl
          .replaceAll(RegExp(r'/rest/v1/?$'), '')
          .replaceAll(RegExp(r'/$'), '');

      final (profCode, profBody) =
          await _fetchRows(baseUrl, 'profiles?select=*');
      if (profCode < 200 || profCode >= 300) {
        isSyncingCloud = false;
        lastSyncStatus = 'profiles HTTP $profCode: $profBody';
        notifyListeners();
        return lastSyncStatus;
      }

      final (itemsCode, itemsBody) =
          await _fetchRows(baseUrl, 'items?select=*&order=created_at.asc');
      if (itemsCode < 200 || itemsCode >= 300) {
        isSyncingCloud = false;
        lastSyncStatus = 'items HTTP $itemsCode: $itemsBody';
        notifyListeners();
        return lastSyncStatus;
      }

      final (bidsCode, bidsBody) =
          await _fetchRows(baseUrl, 'bids?select=*&order=created_at.desc');
      final (autoCode, autoBody) =
          await _fetchRows(baseUrl, 'auto_bids?select=*');
      final (msgCode, msgBody) =
          await _fetchRows(baseUrl, 'messages?select=*&order=created_at.asc');

      // خريطة معرف المستخدم UUID -> اسم المستخدم ورقم الهاتف
      final userUuidToName = <String, String>{};
      final myUuid = settings.userId ?? _toUuid('user_$me');
      final profList = jsonDecode(profBody);
      if (profList is List) {
        bannedUsers.clear();
        for (final row in profList.whereType<Map<String, dynamic>>()) {
          final id = '${row['id'] ?? ''}';
          final firstName = '${row['first_name'] ?? ''}'.trim();
          final secondName = '${row['second_name'] ?? ''}'.trim();
          final full = [firstName, if (secondName != '-') secondName]
              .where((s) => s.isNotEmpty)
              .join(' ');
          final name = (id == myUuid)
              ? me
              : (full.isNotEmpty ? full : 'مستخدم');
          userUuidToName[id] = name;
          userDisplayNames[id] = full.isNotEmpty ? full : name;
          final ph = '${row['phone'] ?? ''}'.trim();
          if (ph.isNotEmpty) {
            userPhones[id] = ph;
            userPhones[name] = ph;
          }
          if (row['is_banned'] == true) {
            bannedUsers.add(name);
          }
        }
      }

      final itemsList = jsonDecode(itemsBody);
      if (itemsList is List && itemsList.isNotEmpty) {
        final loadedItems = <Item>[];
        final byId = <String, Item>{};

        for (final row in itemsList.whereType<Map<String, dynamic>>()) {
          final itemId = '${row['id'] ?? ''}';
          final sellerUuid = '${row['seller_id'] ?? ''}';
          final sellerName = userUuidToName[sellerUuid] ?? 'مستخدم';

          final rawAttrs = <String, String>{};
          if (row['attributes'] is Map) {
            (row['attributes'] as Map).forEach((k, v) {
              rawAttrs['$k'] = '$v';
            });
          }
          final area = rawAttrs.remove('_area') ?? 'المركز';
          final isLive = rawAttrs.remove('_live') == '1';

          final imgs = <String>[];
          if (row['images'] is List) {
            for (final img in row['images'] as List) {
              imgs.add('$img');
            }
          }

          final item = Item(
            id: itemId,
            title: '${row['title'] ?? ''}',
            description: '${row['description'] ?? ''}',
            category: '${row['category'] ?? 'إلكترونيات وأجهزة'}',
            seller: sellerName,
            condition: '${row['condition'] ?? 'شبه جديد'}',
            location: '${row['location'] ?? 'بغداد'}',
            area: area,
            deliveryMethod: '${row['delivery_method'] ?? 'استلام باليد'}',
            startPrice: (row['start_price'] as num?)?.toInt() ?? 1000,
            startTime: parseToLocal(row['start_time'],
                fallback: DateTime.now().subtract(const Duration(minutes: 1))),
            endTime: parseToLocal(row['end_time'],
                fallback: DateTime.now().add(const Duration(days: 1))),
            imagePaths: imgs,
            videoPath: row['video_url'] as String?,
            attributes: rawAttrs,
            pinCode: row['pin_code'] as String?,
            isEndedEarlyBySeller: row['is_ended_early'] as bool? ?? false,
            isCancelled: row['is_cancelled'] as bool? ?? false,
            isLiveStreaming: isLive,
          );
          loadedItems.add(item);
          byId[itemId] = item;
        }

        if (bidsCode >= 200 && bidsCode < 300) {
          final bidsList = jsonDecode(bidsBody);
          if (bidsList is List) {
            for (final b in bidsList.whereType<Map<String, dynamic>>()) {
              final item = byId['${b['item_id'] ?? ''}'];
              if (item == null) continue;
              final bidderName =
                  userUuidToName['${b['bidder_id'] ?? ''}'] ?? 'مزايد';
              item.bids.add(
                Bid(
                  bidderName,
                  (b['amount'] as num?)?.toInt() ?? 0,
                  parseToLocal(b['created_at']),
                  isAuto: b['is_auto'] as bool? ?? false,
                ),
              );
            }
          }
        }

        if (autoCode >= 200 && autoCode < 300) {
          final autoList = jsonDecode(autoBody);
          if (autoList is List) {
            for (final a in autoList.whereType<Map<String, dynamic>>()) {
              final item = byId['${a['item_id'] ?? ''}'];
              if (item == null) continue;
              final bidderName =
                  userUuidToName['${a['bidder_id'] ?? ''}'] ?? 'مزايد';
              item.autoBids[bidderName] =
                  (a['max_limit'] as num?)?.toInt() ?? 0;
            }
          }
        }

        if (msgCode >= 200 && msgCode < 300) {
          final msgList = jsonDecode(msgBody);
          if (msgList is List) {
            directChats.clear();
            for (final m in msgList.whereType<Map<String, dynamic>>()) {
              final itemId = '${m['item_id'] ?? ''}';
              final item = byId[itemId];
              final sender =
                  userUuidToName['${m['sender_id'] ?? ''}'] ?? 'مستخدم';
              final receiverUuid = m['receiver_id'] as String?;
              final text = '${m['content'] ?? ''}';
              final time = parseToLocal(m['created_at']);

              if (receiverUuid == null || receiverUuid.isEmpty) {
                item?.comments.add(AuctionComment(sender, text, time));
              } else {
                final receiver = userUuidToName[receiverUuid] ?? 'مستخدم';
                directChats
                    .putIfAbsent(itemId, () => [])
                    .add(DirectMessage(sender, receiver, text, time));
              }
            }
          }
        }

        _hasInitialSynced = true;
        items.clear();
        items.addAll(loadedItems);
        _saveToDisk();
      } else if (itemsList is List && itemsList.isEmpty && _hasInitialSynced) {
        items.clear();
        _saveToDisk();
      }

      isSyncingCloud = false;
      lastSyncTime = DateTime.now();
      lastSyncStatus = tr(
        'تم الجلب من جداول Supabase الـ 5 بنجاح ✅',
        'Pulled from all 5 Supabase tables successfully ✅',
      );
      notifyListeners();
      return null;
    } catch (e) {
      isSyncingCloud = false;
      lastSyncStatus = '$e';
      notifyListeners();
      return '$e';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollingSafetyTimer?.cancel();
    _itemsSub?.cancel();
    _bidsSub?.cancel();
    _messagesSub?.cancel();
    _profilesSub?.cancel();
    super.dispose();
  }

  void _checkScheduledAuctions() {
    final now = DateTime.now();
    for (final item in items) {
      if (!item.notifiedStart && !now.isBefore(item.startTime)) {
        item.notifiedStart = true;
        if (item.remindMeUsers.contains(me)) {
          _pushNotification(
            title: tr('🔔 بدأ المزاد المجدول الآن!', '🔔 Scheduled Auction Started!'),
            body: tr('انطلق المزاد على "${item.title}"، يمكنك المزايدة الآن.',
                '"${item.title}" is now open for bidding.'),
            icon: Icons.alarm_on,
            color: Colors.green,
            itemId: item.id,
          );
        }
      }
    }
  }

  void _pushNotification({
    required String title,
    required String body,
    IconData icon = Icons.notifications,
    Color color = Colors.indigo,
    String? itemId,
  }) {
    notifications.insert(
      0,
      AppNotification(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        body: body,
        time: DateTime.now(),
        icon: icon,
        color: color,
        itemId: itemId,
      ),
    );
  }

  int get unreadNotificationsCount =>
      notifications.where((n) => !n.isRead).length;

  void markNotificationRead(String id) {
    for (final n in notifications) {
      if (n.id == id) n.isRead = true;
    }
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void addSearchRadarKeyword(String kw) {
    if (!savedSearchKeywords.contains(kw)) {
      savedSearchKeywords.add(kw);
      _persistAndSync();
    }
  }

  void removeSearchRadarKeyword(String kw) {
    savedSearchKeywords.remove(kw);
    _persistAndSync();
  }

  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    if (favorites.contains(id)) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }
    _persistAndSync();
  }

  bool isRemindMeSet(Item item) => item.remindMeUsers.contains(me);

  void toggleRemindMe(Item item) {
    if (item.remindMeUsers.contains(me)) {
      item.remindMeUsers.remove(me);
    } else {
      item.remindMeUsers.add(me);
    }
    _persistAndSync();
  }

  bool isPrivateUnlocked(Item item) =>
      !item.isPrivate ||
      item.seller == me ||
      unlockedPrivateItems.contains(item.id);

  bool unlockPrivateItem(Item item, String enteredPin) {
    if (item.pinCode?.trim() == enteredPin.trim()) {
      unlockedPrivateItems.add(item.id);
      _persistAndSync();
      return true;
    }
    return false;
  }

  void _seed() {
    // تبدأ المنصة نظيفة تماماً دون سلع تجريبية افتراضية
    items.clear();
    favorites.clear();
    notifications.clear();
    reports.clear();
    directChats.clear();
    userReviews.clear();
    userWarnings.clear();
    bannedUsers.clear();
  }

  // ======================= منطق المزايدة (مفتوحة الزيادة + تلقائية + منع القنص) =======================

  /// يرجع نص الخطأ إن فشلت المزايدة، أو null إن نجحت
  String? placeBid(Item item, int amount) {
    if (!settings.isLoggedIn) {
      return tr('سجّل حساباً من الإعدادات أولاً',
          'Please register an account in Settings first');
    }
    if (bannedUsers.contains(me)) {
      return tr(
        'حسابك مجمّد من المزايدة بسبب مخالفة شروط الجدية أو التخلف عن الدفع 🚫',
        'Your account is suspended from bidding due to policy violation 🚫',
      );
    }
    if (item.isScheduled) {
      return tr('هذا المزاد مجدول ولم يبدأ بعد',
          'This auction is scheduled and has not started yet');
    }
    if (item.isEnded) return tr('انتهى هذا المزاد', 'This auction has ended');
    if (item.seller == me) {
      return tr('لا يمكنك المزايدة على سلعتك', 'You cannot bid on your own item');
    }
    if (!isPrivateUnlocked(item)) {
      return tr('هذا المزاد خاص، أدخل رمز PIN أولاً',
          'Private auction: enter PIN code first');
    }
    if (item.highestBidder == me) {
      return tr('أنت صاحب أعلى مزايدة بالفعل',
          'You are already the highest bidder');
    }
    // خطوة الزيادة مفتوحة: أي رقم أعلى من السعر الحالي (أو >= سعر البداية لأول مزايد)
    if (item.bids.isEmpty && amount < item.startPrice) {
      return tr(
        'المبلغ أقل من سعر البداية (${formatPrice(item.startPrice)})',
        'Bid must be at least the starting price (${formatPrice(item.startPrice)})',
      );
    }
    if (item.bids.isNotEmpty && amount <= item.currentPrice) {
      return tr(
        'يجب أن يكون المبلغ أعلى من السعر الحالي (${formatPrice(item.currentPrice)})',
        'Bid must be higher than current price (${formatPrice(item.currentPrice)})',
      );
    }

    final previousLeader = item.highestBidder;

    // إذا زايد يدوياً بمبلغ يتجاوز سقف مزايدته التلقائية، نلغي السقف السابق
    if ((item.autoBids[me] ?? 0) <= amount) {
      item.autoBids.remove(me);
    }

    // تمديد تلقائي في الدقيقة الأخيرة (Anti-Sniping)
    if (item.timeLeft < const Duration(minutes: 1)) {
      item.endTime = item.endTime.add(const Duration(minutes: 1));
      item.extensionsCount++;
    }

    final newBid = Bid(me, amount, DateTime.now());
    item.bids.insert(0, newBid);

    // رد المزايدين التلقائيين الآخرين (إن وجدوا)
    _resolveCounterAutoBids(item, currentBidder: me);

    if (previousLeader != null &&
        previousLeader != item.highestBidder &&
        previousLeader == me) {
      _pushNotification(
        title: tr('⚠️ تم تجاوز مزايدتك!', '⚠️ You have been outbid!'),
        body: tr('تم تجاوز مزايدتك على "${item.title}"',
            'Someone outbid you on "${item.title}"'),
        icon: Icons.trending_up,
        color: Colors.redAccent,
        itemId: item.id,
      );
    }

    _persistAndSync();
    _recordBidToCloud(item, newBid);
    return null;
  }

  /// تفعيل أو تحديث المزايدة التلقائية (Auto-Bid)
  String? setAutoBid(Item item, int maxLimit) {
    if (!settings.isLoggedIn) {
      return tr('سجّل حساباً من الإعدادات أولاً',
          'Please register an account in Settings first');
    }
    if (bannedUsers.contains(me)) {
      return tr('حسابك مجمّد من المزايدة 🚫', 'Your account is suspended 🚫');
    }
    if (item.isScheduled) {
      return tr('المزاد لم يبدأ بعد', 'Auction has not started yet');
    }
    if (item.isEnded) return tr('انتهى هذا المزاد', 'This auction has ended');
    if (item.seller == me) {
      return tr('لا يمكنك المزايدة على سلعتك', 'You cannot bid on your own item');
    }
    if (maxLimit <= item.currentPrice && item.bids.isNotEmpty) {
      return tr(
        'الحد الأقصى يجب أن يكون أعلى من السعر الحالي (${formatPrice(item.currentPrice)})',
        'Max auto-bid must be higher than ${formatPrice(item.currentPrice)}',
      );
    }
    if (item.bids.isEmpty && maxLimit < item.startPrice) {
      return tr(
        'الحد الأقصى يجب أن يكون على الأقل ${formatPrice(item.startPrice)}',
        'Max auto-bid must be at least ${formatPrice(item.startPrice)}',
      );
    }

    item.autoBids[me] = maxLimit;

    if (item.timeLeft < const Duration(minutes: 1)) {
      item.endTime = item.endTime.add(const Duration(minutes: 1));
      item.extensionsCount++;
    }

    _resolveBids(item, triggerUser: me);
    _persistAndSync();
    return null;
  }

  void cancelAutoBid(Item item) {
    item.autoBids.remove(me);
    _persistAndSync();
  }

  void _resolveBids(Item item, {required String triggerUser}) {
    if (item.highestBidder == triggerUser) return;

    final myLimit = item.autoBids[triggerUser]!;

    String? competitor;
    int competitorLimit = 0;
    for (final entry in item.autoBids.entries) {
      if (entry.key != triggerUser && entry.value > competitorLimit) {
        competitor = entry.key;
        competitorLimit = entry.value;
      }
    }

    final nextStepPrice = item.bids.isEmpty
        ? item.startPrice
        : min(myLimit, item.currentPrice + item.autoBidStep);

    if (competitor == null || competitorLimit <= item.currentPrice) {
      if (nextStepPrice <= myLimit) {
        item.bids.insert(
          0,
          Bid(triggerUser, nextStepPrice, DateTime.now(), isAuto: true),
        );
      }
    } else {
      if (myLimit > competitorLimit) {
        if (competitorLimit > item.currentPrice) {
          item.bids.insert(
            0,
            Bid(competitor, competitorLimit, DateTime.now(), isAuto: true),
          );
        }
        final winningBid =
            min(myLimit, item.currentPrice + item.autoBidStep);
        item.bids.insert(
          0,
          Bid(triggerUser, winningBid, DateTime.now(), isAuto: true),
        );
        item.autoBids.remove(competitor);
      } else {
        item.bids.insert(
          0,
          Bid(triggerUser, myLimit, DateTime.now(), isAuto: true),
        );
        item.autoBids.remove(triggerUser);
        if (item.currentPrice < competitorLimit) {
          final counter =
              min(competitorLimit, item.currentPrice + item.autoBidStep);
          item.bids.insert(
            0,
            Bid(competitor, counter, DateTime.now(), isAuto: true),
          );
        }
      }
    }
  }

  void _resolveCounterAutoBids(Item item, {required String currentBidder}) {
    String? topAutoUser;
    int topAutoLimit = 0;

    for (final entry in item.autoBids.entries) {
      if (entry.key != currentBidder && entry.value > topAutoLimit) {
        topAutoUser = entry.key;
        topAutoLimit = entry.value;
      }
    }

    if (topAutoUser != null && topAutoLimit > item.currentPrice) {
      final counterAmount =
          min(topAutoLimit, item.currentPrice + item.autoBidStep);
      item.bids.insert(
        0,
        Bid(topAutoUser, counterAmount, DateTime.now(), isAuto: true),
      );
      if (currentBidder == me) {
        _pushNotification(
          title: tr('⚡ رد تلقائي من مزايد آخر', '⚡ Auto-Bid Countered You'),
          body: tr(
            'قام نظام المزايدة التلقائية للمستخدم "$topAutoUser" بتجاوز مزايدتك على "${item.title}".',
            '"$topAutoUser" auto-bid countered your bid on "${item.title}".',
          ),
          icon: Icons.auto_mode,
          color: Colors.orange,
          itemId: item.id,
        );
      }
    }
  }

  /// إنهاء المزاد مبكراً من قِبل البائع والبيع لأعلى مزايد حالي
  String? endAuctionAndSellToHighest(Item item) {
    if (item.seller != me) {
      return tr('هذا الإجراء متاح لصاحب السلعة فقط', 'Only seller can do this');
    }
    if (item.isEnded) return tr('انتهى هذا المزاد بالفعل', 'Already ended');
    if (item.bids.isEmpty) {
      return tr('لا توجد أي مزايدات حالياً لإرساء المزاد عليها',
          'No bids to accept yet');
    }

    item.isEndedEarlyBySeller = true;
    item.isLiveStreaming = false;
    item.endTime = DateTime.now();
    item.autoBids.clear();

    _pushNotification(
      title: tr('🤝 تم إرساء المزاد وإتمام البيع', '🤝 Auction Settled & Sold'),
      body: tr(
        'تم بيع "${item.title}" إلى ${item.highestBidder} بمبلغ ${formatPrice(item.currentPrice)}.',
        'Sold "${item.title}" to ${item.highestBidder} for ${formatPrice(item.currentPrice)}.',
      ),
      icon: Icons.handshake,
      color: Colors.green,
      itemId: item.id,
    );

    _persistAndSync();
    _updateItemStatusInCloud(item);
    return null;
  }

  /// إلغاء المزاد من قِبل البائع دون بيع السلعة
  String? cancelAuction(Item item) {
    if (item.seller != me) {
      return tr('هذا الإجراء متاح لصاحب السلعة فقط', 'Only seller can do this');
    }
    if (item.isEnded) return tr('المزاد منتهٍ بالفعل', 'Already ended');

    item.isCancelled = true;
    item.isLiveStreaming = false;
    item.endTime = DateTime.now();
    item.autoBids.clear();
    _persistAndSync();
    _updateItemStatusInCloud(item);
    return null;
  }

  void adminCancelItem(Item item) {
    item.isCancelled = true;
    item.isLiveStreaming = false;
    item.endTime = DateTime.now();
    item.autoBids.clear();
    _persistAndSync();
    _updateItemStatusInCloud(item);
  }

  /// إطلاق وبدء المزاد المجدول فوراً لصاحب المزاد
  Future<void> launchAuctionNow(Item item) async {
    item.startTime = DateTime.now().subtract(const Duration(seconds: 10));
    item.notifiedStart = true;
    _saveToDisk();
    notifyListeners();

    if (settings.isCloudConfigured) {
      try {
        final client = supabaseClient;
        if (client != null) {
          final itemUuid = itemToUuid(item.id);
          await client.from('items').update({
            'start_time': toIsoUtc(item.startTime),
            'end_time': toIsoUtc(item.endTime),
          }).eq('id', itemUuid);
        }
      } catch (e) {
        debugPrint('Launch auction error: $e');
      }
    }
  }

  /// تعديل بيانات المزاد قبل انطلاقه
  Future<void> updateItemDetails({
    required Item item,
    required String title,
    required String description,
    required int startPrice,
    required String location,
    required String condition,
  }) async {
    final idx = items.indexWhere((it) => it.id == item.id);
    if (idx != -1) {
      final updated = Item(
        id: item.id,
        title: title.isNotEmpty ? title : item.title,
        description: description.isNotEmpty ? description : item.description,
        category: item.category,
        seller: item.seller,
        startPrice: startPrice > 0 ? startPrice : item.startPrice,
        startTime: item.startTime,
        endTime: item.endTime,
        condition: condition,
        location: location,
        area: item.area,
        deliveryMethod: item.deliveryMethod,
        imagePaths: item.imagePaths,
        videoPath: item.videoPath,
        attributes: item.attributes,
        pinCode: item.pinCode,
        isEndedEarlyBySeller: item.isEndedEarlyBySeller,
        isCancelled: item.isCancelled,
        isLiveStreaming: item.isLiveStreaming,
        liveViewers: item.liveViewers,
        extensionsCount: item.extensionsCount,
        notifiedStart: item.notifiedStart,
      );
      updated.bids.addAll(item.bids);
      updated.comments.addAll(item.comments);
      updated.autoBids.addAll(item.autoBids);
      items[idx] = updated;
    }
    _saveToDisk();
    notifyListeners();

    if (settings.isCloudConfigured) {
      try {
        final client = supabaseClient;
        if (client != null) {
          final itemUuid = itemToUuid(item.id);
          await client.from('items').update({
            'title': title.isNotEmpty ? title : item.title,
            'description':
                description.isNotEmpty ? description : item.description,
            'start_price': startPrice > 0 ? startPrice : item.startPrice,
            'current_price': item.bids.isEmpty
                ? (startPrice > 0 ? startPrice : item.startPrice)
                : item.currentPrice,
            'location': location,
            'condition': condition,
          }).eq('id', itemUuid);
        }
      } catch (e) {
        debugPrint('Update item details error: $e');
      }
    }
  }

  void deleteItem(Item item) {
    final deletedUuid = itemToUuid(item.id);
    items.removeWhere((i) => i.id == item.id || i.id == deletedUuid);
    favorites.remove(item.id);
    favorites.remove(deletedUuid);
    _saveToDisk();
    notifyListeners();
    _deleteItemFromCloud(deletedUuid);
  }

  Future<void> _deleteItemFromCloud(String itemUuid) async {
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client != null) {
        await client.from('items').delete().eq('id', itemUuid);
      }
    } catch (_) {}
    if (!kIsWeb) {
      try {
        final baseUrl = settings.supabaseUrl
            .replaceAll(RegExp(r'/rest/v1/?$'), '')
            .replaceAll(RegExp(r'/$'), '');
        final uri = Uri.parse('$baseUrl/rest/v1/items?id=eq.$itemUuid');
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);
        final req = await client.deleteUrl(uri);
        final key = settings.supabaseAnonKey.trim();
        req.headers.set('apikey', key);
        if (key.startsWith('eyJ')) {
          req.headers.set('Authorization', 'Bearer $key');
        }
        final res = await req.close();
        await res.drain<void>();
        client.close();
      } catch (_) {}
    }
  }

  /// محاكاة مزايدة من مشتري خارجي
  String? simulateBuyerBid(Item item) {
    if (item.isEnded || item.isScheduled) return null;
    const sampleBuyers = ['أحمد', 'سارة', 'مصطفى', 'نور', 'حيدر', 'مريم'];
    final currentTop = item.highestBidder;
    final available =
        sampleBuyers.where((b) => b != currentTop).toList(growable: false);
    final buyer = available[item.bids.length % available.length];
    final amount = item.bids.isEmpty
        ? item.startPrice
        : item.currentPrice + item.autoBidStep;

    final prevLeader = item.highestBidder;

    if (item.timeLeft < const Duration(minutes: 1)) {
      item.endTime = item.endTime.add(const Duration(minutes: 1));
      item.extensionsCount++;
    }

    final newBid = Bid(buyer, amount, DateTime.now());
    item.bids.insert(0, newBid);
    _resolveCounterAutoBids(item, currentBidder: buyer);

    if (prevLeader == me && item.highestBidder != me) {
      _pushNotification(
        title: tr('⚠️ تم تجاوز مزايدتك (Outbid)!', '⚠️ Outbid Alert!'),
        body: tr(
          'زايد "$buyer" بمبلغ ${formatPrice(item.currentPrice)} على "${item.title}".',
          '"$buyer" bid ${formatPrice(item.currentPrice)} on "${item.title}".',
        ),
        icon: Icons.trending_up,
        color: Colors.redAccent,
        itemId: item.id,
      );
    }

    _persistAndSync();
    _recordBidToCloud(item, newBid);
    return buyer;
  }

  void addItem({
    required String title,
    required String description,
    required String category,
    required int startPrice,
    required Duration duration,
    Duration startDelay = Duration.zero,
    String condition = 'شبه جديد',
    String location = 'بغداد',
    String area = 'المركز',
    String deliveryMethod = 'استلام باليد',
    List<String> imagePaths = const [],
    String? videoPath,
    Map<String, String> attributes = const {},
    String? pinCode,
    bool isLiveStreaming = false,
  }) {
    final now = DateTime.now();
    final isImmediate = startDelay == Duration.zero || startDelay.isNegative;
    final start = isImmediate
        ? now.subtract(const Duration(seconds: 10))
        : now.add(startDelay);
    final newUuid = generateUuid();
    final newItem = Item(
      id: newUuid,
      title: title,
      description: description,
      category: category,
      seller: me,
      startPrice: startPrice,
      startTime: start,
      endTime: isImmediate ? now.add(duration) : start.add(duration),
      notifiedStart: isImmediate,
      condition: condition,
      location: location,
      area: area,
      deliveryMethod: deliveryMethod,
      imagePaths: imagePaths,
      videoPath: videoPath,
      attributes: attributes,
      pinCode: pinCode,
      isLiveStreaming: isLiveStreaming,
    );
    items.insert(0, newItem);

    // فحص رادار البحث الذكي للكلمات المفتاحية المحفوظة
    for (final kw in savedSearchKeywords) {
      if (title.contains(kw) ||
          description.contains(kw) ||
          category.contains(kw)) {
        _pushNotification(
          title: tr('📡 تطابق في رادار البحث الذكي!', '📡 Smart Search Radar Match!'),
          body: tr(
            'تمت إضافة مزاد يطابق اهتمامك "$kw": $title',
            'New auction matching "$kw": $title',
          ),
          icon: Icons.radar,
          color: Colors.indigo,
          itemId: newItem.id,
        );
      }
    }

    _persistAndSync();
    _uploadItemToCloud(newItem);
  }

  // ======================= التعليقات، المحادثات، التقييمات، والبلاغات =======================

  void addComment(Item item, String text) {
    final comment = AuctionComment(me, text, DateTime.now());
    item.comments.add(comment);
    _persistAndSync();
    _recordCommentToCloud(item, comment);
  }

  List<DirectMessage> getDirectMessages(String itemId) =>
      directChats.putIfAbsent(itemId, () => []);

  void sendDirectMessage(Item item, String otherParty, String text) {
    final list = getDirectMessages(item.id);
    list.add(DirectMessage(me, otherParty, text, DateTime.now()));
    _persistAndSync();
    _recordDirectMessageToCloud(item.id, otherParty, text);

    // رد تفاعلي تلقائي فقط للبائعين التجريبيين (لا يعمل مع المستخدمين الحقيقيين)
    const demoSellers = {'علي', 'زينب', 'حسن', 'ليلى', 'كرار'};
    if (demoSellers.contains(otherParty)) {
      Future.delayed(const Duration(seconds: 1), () {
        list.add(DirectMessage(
          otherParty,
          me,
          tr('أهلاً بك! السلعة متوفرة وبحالة ممتازة، وأنا جاهز لأي استفسار أو معاينة.',
              'Hello! The item is available in great condition, feel free to ask anything.'),
          DateTime.now(),
        ));
        _persistAndSync();
      });
    }
  }

  void clearFavorites() {
    favorites.clear();
    _persistAndSync();
    notifyListeners();
  }

  bool isItemSeller(Item item) {
    if (item.seller == me) return true;
    if (settings.userId != null && settings.userId!.isNotEmpty) {
      final sellerUuid = userToUuid(item.seller);
      if (sellerUuid == settings.userId) return true;
    }
    if (settings.phone.isNotEmpty) {
      final ph = getUserPhone(item.seller);
      if (ph == settings.phone) return true;
    }
    return false;
  }

  Future<void> setLiveStreamStatus(Item item, bool isLive) async {
    item.isLiveStreaming = isLive;
    _persistAndSync();
    notifyListeners();
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client != null) {
        final itemUuid = itemToUuid(item.id);
        final attrsWithMeta = <String, String>{
          ...item.attributes,
          '_area': item.area,
          '_live': isLive ? '1' : '0',
        };
        await client.from('items').update({
          'attributes': attrsWithMeta,
        }).eq('id', itemUuid);
        debugPrint('Directly updated live stream in Supabase for item ${item.id} -> isLive=$isLive');
      }
    } catch (e) {
      debugPrint('Direct live update error: $e');
    }
  }

  List<ChatConversation> getMyConversations() {
    final Map<String, ChatConversation> convs = {};
    for (final entry in directChats.entries) {
      final itemId = entry.key;
      final item = items.firstWhere(
        (i) => i.id == itemId || itemToUuid(i.id) == itemId,
        orElse: () => Item(
          id: itemId,
          title: 'مزاد سابق',
          description: '',
          category: 'عام',
          seller: 'مستخدم',
          startPrice: 0,
          startTime: DateTime.now(),
          endTime: DateTime.now(),
        ),
      );

      for (final msg in entry.value) {
        if (msg.sender == me || msg.receiver == me) {
          final otherParty = (msg.sender == me) ? msg.receiver : msg.sender;
          final key = '${itemId}_$otherParty';
          final existing = convs[key];
          final count = (existing?.totalMessages ?? 0) + 1;
          if (existing == null || msg.time.isAfter(existing.lastMessage.time)) {
            convs[key] = ChatConversation(
              item: item,
              otherParty: otherParty,
              lastMessage: msg,
              totalMessages: count,
            );
          } else {
            convs[key] = ChatConversation(
              item: existing.item,
              otherParty: existing.otherParty,
              lastMessage: existing.lastMessage,
              totalMessages: count,
            );
          }
        }
      }
    }
    final list = convs.values.toList();
    list.sort((a, b) => b.lastMessage.time.compareTo(a.lastMessage.time));
    return list;
  }

  int get totalMessagesCount {
    int total = 0;
    for (final list in directChats.values) {
      total += list.where((m) => m.sender == me || m.receiver == me).length;
    }
    return total;
  }

  // ----------------------- دوال الحفظ المباشر في السحابة (Cloud Direct Actions) -----------------------

  Future<void> _recordBidToCloud(Item item, Bid bid) async {
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client != null) {
        final bidderUuid = userToUuid(bid.bidder);
        await _ensureProfileExists(bidderUuid, bid.bidder);
        final itemUuid = itemToUuid(item.id);
        await client.from('bids').insert({
          'id': generateUuid(),
          'item_id': itemUuid,
          'bidder_id': bidderUuid,
          'amount': bid.amount,
          'is_auto': bid.isAuto,
          'created_at': toIsoUtc(bid.time),
        });
        await client.from('items').update({
          'current_price': item.currentPrice,
          'highest_bidder_id': bidderUuid,
          'end_time': toIsoUtc(item.endTime),
        }).eq('id', itemUuid);
        return;
      }
    } catch (e) {
      debugPrint('Cloud record bid error: $e');
    }
  }

  Future<void> _recordCommentToCloud(Item item, AuctionComment comment) async {
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client != null) {
        final senderUuid = userToUuid(comment.author);
        await _ensureProfileExists(senderUuid, comment.author);
        final itemUuid = itemToUuid(item.id);
        await client.from('messages').insert({
          'id': generateUuid(),
          'item_id': itemUuid,
          'sender_id': senderUuid,
          'receiver_id': null,
          'content': comment.text,
          'created_at': toIsoUtc(comment.time),
        });
        return;
      }
    } catch (e) {
      debugPrint('Cloud record comment error: $e');
    }
  }

  Future<void> _recordDirectMessageToCloud(
      String itemId, String otherParty, String text) async {
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client != null) {
        final senderUuid = userToUuid(me);
        final receiverUuid = userToUuid(otherParty);
        await _ensureProfileExists(senderUuid, me);
        await _ensureProfileExists(receiverUuid, otherParty);
        final itemUuid = itemToUuid(itemId);
        await client.from('messages').insert({
          'id': generateUuid(),
          'item_id': itemUuid,
          'sender_id': senderUuid,
          'receiver_id': receiverUuid,
          'content': text,
          'created_at': toIsoUtc(DateTime.now()),
        });
        return;
      }
    } catch (e) {
      debugPrint('Cloud record direct message error: $e');
    }
  }

  Future<void> _updateItemStatusInCloud(Item item) async {
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client != null) {
        final itemUuid = itemToUuid(item.id);
        await client.from('items').update({
          'is_ended_early': item.isEndedEarlyBySeller,
          'is_cancelled': item.isCancelled,
          'end_time': toIsoUtc(item.endTime),
        }).eq('id', itemUuid);
      }
    } catch (e) {
      debugPrint('Cloud update item status error: $e');
    }
  }

  Future<void> _uploadItemToCloud(Item item) async {
    if (!settings.isCloudConfigured) return;
    try {
      final sellerUuid = userToUuid(item.seller);
      await _ensureProfileExists(sellerUuid, item.seller);
      final attrsWithMeta = <String, String>{
        ...item.attributes,
        '_area': item.area,
        '_live': item.isLiveStreaming ? '1' : '0',
      };
      final client = supabaseClient;
      if (client != null) {
        await client.from('items').upsert({
          'id': item.id,
          'seller_id': sellerUuid,
          'title': item.title,
          'description': item.description,
          'category': item.category,
          'condition': item.condition,
          'location': item.location,
          'delivery_method': item.deliveryMethod,
          'attributes': attrsWithMeta,
          'images': item.imagePaths,
          'video_url': item.videoPath,
          'start_price': item.startPrice,
          'current_price': item.currentPrice,
          'highest_bidder_id': null,
          'start_time': toIsoUtc(item.startTime),
          'end_time': toIsoUtc(item.endTime),
          'pin_code': item.pinCode,
          'is_ended_early': item.isEndedEarlyBySeller,
          'is_cancelled': item.isCancelled,
        });
        return;
      }
    } catch (e) {
      debugPrint('Direct upload item error: $e');
    }
    pushToSupabase();
  }

  String getUserPhone(String user) {
    if (user == me && settings.phone.isNotEmpty) return settings.phone;
    final realPhone = userPhones[user] ?? userPhones[_toUuid('user_$user')];
    if (realPhone != null && realPhone.isNotEmpty) return realPhone;
    final hash = (user.hashCode.abs() % 9000000) + 1000000;
    return '+964770$hash';
  }

  List<UserReview> getUserReviews(String user) =>
      userReviews.putIfAbsent(user, () => []);

  double getUserRating(String user) {
    final list = getUserReviews(user);
    if (list.isEmpty) return 4.8;
    final sum = list.fold<int>(0, (s, r) => s + r.stars);
    return sum / list.length;
  }

  void addReview(String targetUser, int stars, String comment) {
    final list = getUserReviews(targetUser);
    list.insert(0, UserReview(me, stars, comment, DateTime.now()));
    _persistAndSync();
  }

  void submitReport({
    required Item item,
    required String reportedUser,
    required String reason,
  }) {
    reports.insert(
      0,
      FraudReport(
        id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
        reporter: me,
        reportedUser: reportedUser,
        itemId: item.id,
        itemTitle: item.title,
        reason: reason,
        time: DateTime.now(),
      ),
    );
    _persistAndSync();
  }

  void warnUser(String user, String? reportId) {
    userWarnings[user] = (userWarnings[user] ?? 0) + 1;
    if (reportId != null) {
      for (final r in reports) {
        if (r.id == reportId) r.isResolved = true;
      }
    }
    if ((userWarnings[user] ?? 0) >= 3) {
      bannedUsers.add(user);
    }
    _persistAndSync();
  }

  void banUser(String user, String? reportId) {
    bannedUsers.add(user);
    if (reportId != null) {
      for (final r in reports) {
        if (r.id == reportId) r.isResolved = true;
      }
    }
    _persistAndSync();
  }

  void toggleBanUser(String user) {
    if (bannedUsers.contains(user)) {
      bannedUsers.remove(user);
    } else {
      bannedUsers.add(user);
    }
    _persistAndSync();
  }

  Future<void> deleteUser(String user) async {
    final userUuid = userToUuid(user);
    bannedUsers.remove(user);
    userWarnings.remove(user);
    userDisplayNames.remove(user);
    userDisplayNames.remove(userUuid);
    userPhones.remove(user);
    userPhones.remove(userUuid);

    // حذف أي مزادات تابعة لهذا المستخدم
    items.removeWhere((it) => it.seller == user || userToUuid(it.seller) == userUuid);

    _saveToDisk();
    notifyListeners();

    if (settings.isCloudConfigured) {
      try {
        final client = supabaseClient;
        if (client != null) {
          await client.from('profiles').delete().eq('id', userUuid);
        }
      } catch (e) {
        debugPrint('Delete user from cloud error: $e');
      }
    }
  }

  List<String> get allKnownUsers {
    final set = <String>{me};
    // إضافة المستخدمين الفعليين من قاعدة البيانات فقط
    for (final name in userDisplayNames.values) {
      if (name.isNotEmpty && name != 'مستخدم') set.add(name);
    }
    for (final i in items) {
      if (i.seller.isNotEmpty) set.add(i.seller);
      for (final b in i.bids) {
        if (b.bidder.isNotEmpty) set.add(b.bidder);
      }
    }
    const dummyNames = {'علي', 'زينب', 'حسن', 'ليلى', 'سمير_متلاعب'};
    set.removeWhere((u) => dummyNames.contains(u) && !items.any((i) => i.seller == u));
    return set.toList();
  }
}

final store = AuctionStore();

