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
  final Set<String> _deletedConversationKeys = {};
  final Set<String> _deletedMessageIds = {};
  final Map<String, DateTime> _userLastActiveMap = {};
  /// خريطة باتجاه واحد فقط: UUID -> الاسم الكامل للعرض
  static final Map<String, String> userDisplayNames = {};
  /// خريطة معاكسة مستقلة: الاسم الكامل -> UUID لمنع تداخل الأسماء مع المعرّفات
  static final Map<String, String> nameToUuidMap = {};
  static final Map<String, String> userPhones = {};
  /// خريطة صور المستخدمين الشخصية (سحابية / Base64)
  static final Map<String, String> userPhotos = {};

  Timer? _timer;
  Timer? _pollingSafetyTimer;
  StreamSubscription? _itemsSub;
  StreamSubscription? _bidsSub;
  StreamSubscription? _messagesSub;
  StreamSubscription? _profilesSub;
  StreamSubscription? _reportsSub;
  RealtimeChannel? _chatBroadcastChannel;
  bool _hasInitialSynced = false;
  final Set<String> adminUserNames = {};

  int _nextId = 100;

  bool isSyncingCloud = false;
  String? lastSyncStatus;
  DateTime? lastSyncTime;
  static const String _storeFilePath = 'muzaida_store.json';

  String get _cleanBaseUrl => settings.supabaseUrl
      .replaceAll(RegExp(r'/rest/v1/?$'), '')
      .replaceAll(RegExp(r'/$'), '');

  SupabaseClient? get supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  AuctionStore() {
    _deletedConversationKeys.addAll(LocalStorageHelper.getDeletedConversationKeys());
    _deletedMessageIds.addAll(LocalStorageHelper.getDeletedMessageIds());
    bannedUsers.addAll(LocalStorageHelper.getBlockedUsers());

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
    settings.getBlockedUsersCount = () => myBlockedUsersList.length;
    settings.openBlockedUsers = (ctx) => showBlockedUsersSheet(ctx);
    settings.onProfileUpdated = (id, name, photo) {
      userDisplayNames[id] = name;
      userDisplayNames[settings.phone] = name;
      nameToUuidMap[name] = id;
      if (photo != null && photo.isNotEmpty) {
        userPhotos[id] = photo;
        userPhotos[settings.phone] = photo;
        userPhotos[name] = photo;
      }
      notifyListeners();
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
    _reportsSub?.cancel();

    try {
      // 1. مزامنة المستخدمين وصلاحية الأدمن (is_admin) لحظياً
      _profilesSub = client.from('profiles').stream(primaryKey: ['id']).listen((rows) {
        _applyProfilesStream(rows);
      }, onError: (e) {
        debugPrint('Profiles stream error: $e');
      });

      // 2. مزامنة البلاغات والشكاوى لحظياً
      _reportsSub = client.from('reports').stream(primaryKey: ['id']).listen((rows) {
        _applyReportsStream(rows);
      }, onError: (e) {
        debugPrint('Reports stream error: $e');
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

      // 5. قناة البث المباشر الفوري عبر WebSockets للمراسلة اللحظية
      try {
        _chatBroadcastChannel?.unsubscribe();
        _chatBroadcastChannel = client.channel('open_mazad_chat').onBroadcast(
          event: 'dm',
          callback: (payload) {
            try {
              final raw = payload['msg'];
              if (raw is Map) {
                final msg = DirectMessage.fromJson(Map<String, dynamic>.from(raw));
                final rawItemId = '${payload['itemId']}';
                if (isUserMe(msg.sender)) return;
                final myUuid = userToUuid(me);
                if (!isUserMe(msg.receiver) && userToUuid(msg.receiver) != myUuid) return;
                _mergeIncomingDirectMessage(rawItemId, msg);
                recordUserActivity(msg.sender, activityTime: msg.time);
                notifyListeners();
              }
            } catch (e) {
              debugPrint('Realtime broadcast parse error: $e');
            }
          },
        )..subscribe();
      } catch (e) {
        debugPrint('Broadcast channel setup error: $e');
      }
    } catch (e) {
      debugPrint('Realtime stream setup error: $e');
    }

    // جلب أولي كامل
    pullFromSupabase(silent: true);

    // مؤقت أمان خفيف في الخلفية (كل 15 ثانية) بينما يعتمد التحديث الفوري على قنوات Realtime
    _pollingSafetyTimer?.cancel();
    _pollingSafetyTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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

  /// يتأكد من مطابقة معرّف المستخدم لـ UUID بالاعتماد على خريطة منفصلة (nameToUuidMap)
  static String userToUuid(String u) {
    if (u == me && settings.userId != null && settings.userId!.isNotEmpty) {
      return settings.userId!;
    }
    final trimmed = u.trim();
    if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(trimmed)) {
      return trimmed.toLowerCase();
    }
    if (nameToUuidMap.containsKey(trimmed)) {
      return nameToUuidMap[trimmed]!.toLowerCase();
    }
    for (final entry in userDisplayNames.entries) {
      if (entry.value.trim().toLowerCase() == trimmed.toLowerCase()) {
        if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(entry.key)) {
          return entry.key.toLowerCase();
        }
      }
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

  bool isUserMe(String identifier) {
    if (identifier.isEmpty) return false;
    if (identifier == me || identifier == 'أنا') return true;
    if (settings.userId != null &&
        settings.userId!.isNotEmpty &&
        identifier == settings.userId) {
      return true;
    }
    if (settings.fullName.isNotEmpty && identifier == settings.fullName) {
      return true;
    }
    if (userToUuid(me) == identifier) return true;
    return false;
  }

  Future<void> _ensureItemExists(Item item) async {
    final client = supabaseClient;
    if (client == null) return;
    try {
      final sellerUuid = userToUuid(item.seller);
      await _ensureProfileExists(sellerUuid, item.seller);
      final itemUuid = itemToUuid(item.id);
      final attrsWithMeta = <String, String>{
        ...item.attributes,
        '_area': item.area,
        '_live': item.isLiveStreaming ? '1' : '0',
      };
      await client.from('items').upsert({
        'id': itemUuid,
        'seller_id': sellerUuid,
        'title': item.title,
        'description': item.description,
        'category': item.category,
        'condition': item.condition.isEmpty ? 'ممتازة' : item.condition,
        'location': item.location.isEmpty ? 'بغداد' : item.location,
        'delivery_method':
            item.deliveryMethod.isEmpty ? 'يداً بيد' : item.deliveryMethod,
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
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Ensure item in cloud error: $e');
    }
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
      if (full.isNotEmpty) nameToUuidMap[full] = id;
      final ph = '${row['phone'] ?? ''}'.trim();
      if (ph.isNotEmpty) {
        userPhones[id] = ph;
        userPhones[name] = ph;
      }
      final rawPhoto = '${row['photo_url'] ?? ''}'.trim();
      final (cleanPhoto, _) = SettingsStore.unpackCloudPhotoUrl(rawPhoto);
      if (cleanPhoto != null && cleanPhoto.isNotEmpty) {
        userPhotos[id] = cleanPhoto;
        userPhotos[name] = cleanPhoto;
        if (full.isNotEmpty) userPhotos[full] = cleanPhoto;
      }
      if (row['is_banned'] == true) {
        bannedUsers.add(name);
      } else {
        bannedUsers.remove(name);
      }

      // مزامنة حالة الآدمن لحظياً إذا تم تغييرها في قاعدة البيانات
      final isAdm = row['is_admin'];
      final bool isAdminVal = isAdm == true || isAdm == 'true' || isAdm == 1;
      if (isAdminVal) {
        adminUserNames.add(id);
        if (name.isNotEmpty) adminUserNames.add(name);
        if (full.isNotEmpty) adminUserNames.add(full);
      } else {
        adminUserNames.remove(id);
        adminUserNames.remove(name);
        adminUserNames.remove(full);
      }
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

  void _applyReportsStream(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final repId = '${row['id'] ?? ''}';
      final reporterUuid = '${row['reporter_id'] ?? ''}';
      final reportedUuid = '${row['reported_user_id'] ?? ''}';
      final reporterName = userDisplayNames[reporterUuid] ?? reporterUuid;
      final reportedName = userDisplayNames[reportedUuid] ?? reportedUuid;
      final itemId = '${row['item_id'] ?? ''}';
      final itemTitle = '${row['item_title'] ?? 'سلعة'}';
      final reason = '${row['reason'] ?? ''}';
      final isResolved = row['is_resolved'] == true;
      final time = parseToLocal(row['created_at']);

      final idx = reports.indexWhere((r) => r.id == repId || itemToUuid(r.id) == repId);
      if (idx >= 0) {
        reports[idx].isResolved = isResolved;
      } else {
        reports.insert(
          0,
          FraudReport(
            id: repId,
            reporter: reporterName,
            reportedUser: reportedName,
            itemId: itemId,
            itemTitle: itemTitle,
            reason: reason,
            time: time,
            isResolved: isResolved,
          ),
        );
      }
    }
    _saveToDisk();
    notifyListeners();
  }

  bool isUserAdmin(String user) {
    if ((user == me || isUserMe(user)) && settings.isAdmin) return true;
    final ph = userPhones[user] ?? userPhones[userToUuid(user)];
    if (ph == '07700000000' || ph == '+9647700000000') return true;
    if (user == '07700000000' || user == '+9647700000000') return true;
    final uuid = userToUuid(user);
    if (adminUserNames.contains(user) || adminUserNames.contains(uuid)) return true;
    return false;
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
        list.sort((a, b) {
          final cmp = b.amount.compareTo(a.amount);
          if (cmp != 0) return cmp;
          return b.time.compareTo(a.time);
        });
        item.bids.addAll(list);
      }
    }
    notifyListeners();
  }

  void _applyMessagesStream(List<Map<String, dynamic>> rows) {
    final commentsByItem = <String, List<AuctionComment>>{};
    final newDirectChats = <String, List<DirectMessage>>{};

    for (final m in rows) {
      final msgId = '${m['id'] ?? ''}';
      final itemId = '${m['item_id'] ?? ''}';
      final senderUuid = '${m['sender_id'] ?? ''}';
      final receiverUuid = m['receiver_id'] as String?;
      final text = '${m['content'] ?? ''}';
      final time = parseToLocal(m['created_at']);

      if (receiverUuid == null || receiverUuid.isEmpty) {
        final sender = isUserMe(senderUuid)
            ? me
            : (userDisplayNames[senderUuid] ?? 'مستخدم');
        commentsByItem
            .putIfAbsent(itemId, () => [])
            .add(AuctionComment(sender, text, time));
      } else {
        // الخصوصية: لا نستقبل إلا الرسائل التي يكون المستخدم الحالي طرفاً فيها (مرسلاً أو مستقبلاً)
        if (!isUserMe(senderUuid) && !isUserMe(receiverUuid)) continue;
        recordUserActivity(senderUuid, activityTime: time);
        final sender = isUserMe(senderUuid)
            ? me
            : (userDisplayNames[senderUuid] ?? senderUuid);
        final receiver = isUserMe(receiverUuid)
            ? me
            : (userDisplayNames[receiverUuid] ?? receiverUuid);

        if (isConversationOrMessageDeleted(
          rawItemId: itemId,
          msgId: msgId,
          sender: sender,
          receiver: receiver,
        )) {
          continue;
        }

        final existingList = directChats[itemId] ?? directChats[_normalizeItemKey(itemId)] ?? [];
        final existingMsg = existingList.where((em) => em.id == msgId).firstOrNull;
        final bool isMsgRead = isUserMe(senderUuid) ||
            (m['is_read'] == true) ||
            (existingMsg != null && existingMsg.isRead);

        newDirectChats.putIfAbsent(itemId, () => []).add(
              DirectMessage(
                sender,
                receiver,
                text,
                time,
                id: msgId,
                senderId: senderUuid,
                receiverId: receiverUuid,
                isDelivered: true,
                isRead: isMsgRead,
              ),
            );
      }
    }

    for (final item in items) {
      if (commentsByItem.containsKey(item.id)) {
        item.comments.clear();
        item.comments.addAll(commentsByItem[item.id]!);
      }
    }
    for (final entry in newDirectChats.entries) {
      for (final msg in entry.value) {
        _mergeIncomingDirectMessage(entry.key, msg);
      }
    }
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
        final jwt = settings.activeJwtToken;
        if (jwt != null && jwt.isNotEmpty) {
          req.headers.set('Authorization', 'Bearer $jwt');
        } else if (key.startsWith('eyJ')) {
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
        final jwt = settings.activeJwtToken;
        if (jwt != null && jwt.isNotEmpty) {
          req.headers.set('Authorization', 'Bearer $jwt');
        } else if (key.startsWith('eyJ')) {
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
        final it = items.cast<Item?>().firstWhere(
            (i) => i!.id == itemId || itemToUuid(i.id) == itemUuid,
            orElse: () => null);
        if (it == null && !itemRows.any((r) => r['id'] == itemUuid)) {
          itemRows.add({
            'id': itemUuid,
            'seller_id': userToUuid(me),
            'title': 'محادثة مزاد',
            'description': 'محادثة مباشرة بين مستخدمين',
            'category': 'عام',
            'condition': 'ممتازة',
            'location': 'بغداد',
            'delivery_method': 'يداً بيد',
            'attributes': <String, String>{},
            'images': <String>[],
            'video_url': null,
            'start_price': 0,
            'current_price': 0,
            'highest_bidder_id': null,
            'start_time': toIsoUtc(DateTime.now()),
            'end_time': toIsoUtc(DateTime.now().add(const Duration(days: 30))),
            'pin_code': null,
            'is_ended_early': false,
            'is_cancelled': false,
          });
        }
        for (final m in msgs) {
          messageRows.add({
            'id': itemToUuid(m.id),
            'item_id': itemUuid,
            'sender_id': m.senderId ?? userToUuid(m.sender),
            'receiver_id': m.receiverId ?? userToUuid(m.receiver),
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
          if (full.isNotEmpty) nameToUuidMap[full] = id;
          final ph = '${row['phone'] ?? ''}'.trim();
          if (ph.isNotEmpty) {
            userPhones[id] = ph;
            userPhones[name] = ph;
          }
          final rawPhoto = '${row['photo_url'] ?? ''}'.trim();
          final (cleanPhoto, _) = SettingsStore.unpackCloudPhotoUrl(rawPhoto);
          if (cleanPhoto != null && cleanPhoto.isNotEmpty) {
            userPhotos[id] = cleanPhoto;
            userPhotos[name] = cleanPhoto;
            if (full.isNotEmpty) userPhotos[full] = cleanPhoto;
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
            for (final it in loadedItems) {
              it.bids.sort((a, b) {
                final cmp = b.amount.compareTo(a.amount);
                if (cmp != 0) return cmp;
                return b.time.compareTo(a.time);
              });
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
            for (final m in msgList.whereType<Map<String, dynamic>>()) {
              final msgId = '${m['id'] ?? ''}';
              final itemId = '${m['item_id'] ?? ''}';
              final item = byId[itemId];
              final senderUuid = '${m['sender_id'] ?? ''}';
              final receiverUuid = m['receiver_id'] as String?;
              final text = '${m['content'] ?? ''}';
              final time = parseToLocal(m['created_at']);

              if (receiverUuid == null || receiverUuid.isEmpty) {
                final sender = isUserMe(senderUuid)
                    ? me
                    : (userUuidToName[senderUuid] ?? 'مستخدم');
                if (item != null &&
                    !item.comments.any((c) =>
                        c.author == sender &&
                        c.text == text &&
                        c.time.difference(time).abs().inSeconds < 10)) {
                  item.comments.add(AuctionComment(sender, text, time));
                }
              } else {
                // الخصوصية: لا نستقبل إلا الرسائل التي يكون المستخدم الحالي طرفاً فيها
                if (!isUserMe(senderUuid) && !isUserMe(receiverUuid)) continue;
                final sender = isUserMe(senderUuid)
                    ? me
                    : (userUuidToName[senderUuid] ?? senderUuid);
                final receiver = isUserMe(receiverUuid)
                    ? me
                    : (userUuidToName[receiverUuid] ?? receiverUuid);
                final existingList = directChats[itemId] ?? directChats[_normalizeItemKey(itemId)] ?? [];
                final existingMsg = existingList.where((em) => em.id == msgId).firstOrNull;
                final bool isMsgRead = isUserMe(senderUuid) ||
                    (m['is_read'] == true) ||
                    (existingMsg != null && existingMsg.isRead);

                _mergeIncomingDirectMessage(
                  itemId,
                  DirectMessage(
                    sender,
                    receiver,
                    text,
                    time,
                    id: msgId,
                    senderId: senderUuid,
                    receiverId: receiverUuid,
                    isDelivered: true,
                    isRead: isMsgRead,
                  ),
                );
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

      // جلب سجل البلاغات والشكاوى وتحديثها
      try {
        final (repCode, repBody) =
            await _fetchRows(baseUrl, 'reports?select=*&order=created_at.desc');
        if (repCode >= 200 && repCode < 300) {
          final repList = jsonDecode(repBody);
          if (repList is List && repList.isNotEmpty) {
            _applyReportsStream(List<Map<String, dynamic>>.from(
                repList.whereType<Map<String, dynamic>>()));
          }
        }
      } catch (err) {
        debugPrint('Fetch reports error: $err');
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

  void stopTimers() {
    _timer?.cancel();
    _pollingSafetyTimer?.cancel();
    _itemsSub?.cancel();
    _bidsSub?.cancel();
    _messagesSub?.cancel();
    _profilesSub?.cancel();
    _reportsSub?.cancel();
    _chatBroadcastChannel?.unsubscribe();
  }

  @override
  void dispose() {
    stopTimers();
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
  String? placeBid(Item itemParam, int amount) {
    final item = items.firstWhere(
      (it) => it.id == itemParam.id || itemToUuid(it.id) == itemToUuid(itemParam.id),
      orElse: () => itemParam,
    );
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
    // التحقق من آخر مزايد ومنع المزايدة المتتالية (Spam Prevention)
    final lastBidder = item.highestBidder ??
        (item.bids.isNotEmpty ? item.bids.first.bidder : null);
    if (lastBidder != null && isUserMe(lastBidder)) {
      return tr(
        'أنت صاحب أعلى مزايدة حالياً 🥇، لا يمكنك المزايدة مجدداً حتى يتجاوزك مزايد آخر',
        'You are already the highest bidder 🥇, you cannot bid again until outbid',
      );
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
    item.bids.sort((a, b) {
      final cmp = b.amount.compareTo(a.amount);
      if (cmp != 0) return cmp;
      return b.time.compareTo(a.time);
    });

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
  String? setAutoBid(Item itemParam, int maxLimit) {
    final item = items.firstWhere(
      (it) => it.id == itemParam.id || itemToUuid(it.id) == itemToUuid(itemParam.id),
      orElse: () => itemParam,
    );
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

  /// تعديل بيانات المزاد قبل انطلاقه / نشره بالكامل
  Future<void> updateItemDetails({
    required Item item,
    required String title,
    required String description,
    required int startPrice,
    required String location,
    required String condition,
    String? category,
    String? area,
    String? deliveryMethod,
    List<String>? imagePaths,
    Map<String, String>? attributes,
    String? pinCode,
    int? buyNowPrice,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final idx = items.indexWhere((it) => it.id == item.id || itemToUuid(it.id) == itemToUuid(item.id));
    if (idx != -1) {
      final updated = Item(
        id: item.id,
        title: title.isNotEmpty ? title : item.title,
        description: description.isNotEmpty ? description : item.description,
        category: (category != null && category.isNotEmpty) ? category : item.category,
        seller: item.seller,
        startPrice: startPrice > 0 ? startPrice : item.startPrice,
        startTime: startTime ?? item.startTime,
        endTime: endTime ?? item.endTime,
        condition: condition.isNotEmpty ? condition : item.condition,
        location: location.isNotEmpty ? location : item.location,
        area: (area != null && area.isNotEmpty) ? area : item.area,
        deliveryMethod: (deliveryMethod != null && deliveryMethod.isNotEmpty) ? deliveryMethod : item.deliveryMethod,
        imagePaths: imagePaths ?? item.imagePaths,
        videoPath: item.videoPath,
        attributes: attributes ?? item.attributes,
        pinCode: pinCode ?? item.pinCode,
        buyNowPrice: buyNowPrice ?? item.buyNowPrice,
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
          final attrsWithMeta = <String, String>{
            ...(attributes ?? item.attributes),
            '_area': (area != null && area.isNotEmpty) ? area : item.area,
            '_live': item.isLiveStreaming ? '1' : '0',
          };
          await client.from('items').update({
            'title': title.isNotEmpty ? title : item.title,
            'description':
                description.isNotEmpty ? description : item.description,
            'category': (category != null && category.isNotEmpty) ? category : item.category,
            'start_price': startPrice > 0 ? startPrice : item.startPrice,
            'current_price': item.bids.isEmpty
                ? (startPrice > 0 ? startPrice : item.startPrice)
                : item.currentPrice,
            'location': location.isNotEmpty ? location : item.location,
            'condition': condition.isNotEmpty ? condition : item.condition,
            'delivery_method': (deliveryMethod != null && deliveryMethod.isNotEmpty) ? deliveryMethod : item.deliveryMethod,
            'attributes': jsonEncode(attrsWithMeta),
            'image_urls': imagePaths ?? item.imagePaths,
            if (startTime != null) 'start_time': toIsoUtc(startTime),
            if (endTime != null) 'end_time': toIsoUtc(endTime),
          }).eq('id', itemUuid);
        }
      } catch (e) {
        debugPrint('Update item details error: $e');
      }
    }
  }

  /// إضافة معلومات وملحق إضافي للمزاد بعد نشره (تقييد التعديل لمنع التلاعب)
  Future<void> appendItemInformation(Item item, String additionalInfo) async {
    final trimmed = additionalInfo.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final timeStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final addition = '\n\n📌 [تحديث معلومات من البائع - $timeStr]:\n$trimmed';

    final idx = items.indexWhere((it) => it.id == item.id || itemToUuid(it.id) == itemToUuid(item.id));
    if (idx != -1) {
      final current = items[idx];
      final newDesc = '${current.description}$addition';
      final updated = Item(
        id: current.id,
        title: current.title,
        description: newDesc,
        category: current.category,
        seller: current.seller,
        startPrice: current.startPrice,
        startTime: current.startTime,
        endTime: current.endTime,
        condition: current.condition,
        location: current.location,
        area: current.area,
        deliveryMethod: current.deliveryMethod,
        imagePaths: current.imagePaths,
        videoPath: current.videoPath,
        attributes: current.attributes,
        pinCode: current.pinCode,
        isEndedEarlyBySeller: current.isEndedEarlyBySeller,
        isCancelled: current.isCancelled,
        isLiveStreaming: current.isLiveStreaming,
        liveViewers: current.liveViewers,
        extensionsCount: current.extensionsCount,
        notifiedStart: current.notifiedStart,
      );
      updated.bids.addAll(current.bids);
      updated.comments.addAll(current.comments);
      updated.autoBids.addAll(current.autoBids);
      items[idx] = updated;

      _saveToDisk();
      notifyListeners();

      if (settings.isCloudConfigured) {
        try {
          final client = supabaseClient;
          if (client != null) {
            final itemUuid = itemToUuid(item.id);
            await client.from('items').update({
              'description': newDesc,
            }).eq('id', itemUuid);
          }
        } catch (e) {
          debugPrint('Append item info error: $e');
        }
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
    int? buyNowPrice,
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
      buyNowPrice: buyNowPrice,
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

  void addComment(Item itemParam, String text) {
    final item = items.firstWhere(
      (it) => it.id == itemParam.id || itemToUuid(it.id) == itemToUuid(itemParam.id),
      orElse: () => itemParam,
    );
    final comment = AuctionComment(me, text, DateTime.now());
    item.comments.add(comment);
    _persistAndSync();
    _recordCommentToCloud(item, comment);
  }

  String _normalizeItemKey(String itemId) {
    for (final it in items) {
      if (it.id == itemId || itemToUuid(it.id) == itemId) {
        return it.id;
      }
    }
    return itemId;
  }

  bool isConversationOrMessageDeleted({
    required String rawItemId,
    String? msgId,
    String? sender,
    String? receiver,
  }) {
    if (msgId != null && _deletedMessageIds.contains(msgId)) return true;
    final itemKey = _normalizeItemKey(rawItemId);
    final targetUuid = itemToUuid(rawItemId);

    if (_deletedConversationKeys.contains(rawItemId) ||
        _deletedConversationKeys.contains(itemKey) ||
        _deletedConversationKeys.contains(targetUuid)) {
      return true;
    }

    final other = (sender != null && isUserMe(sender))
        ? receiver
        : sender;
    if (other != null && other.isNotEmpty) {
      final oUuid = userToUuid(other);
      final oDisp = displayName(other);
      final checks = [
        '$itemKey:$other',
        '$itemKey:$oUuid',
        '$itemKey:$oDisp',
        '$targetUuid:$other',
        '$targetUuid:$oUuid',
        '$targetUuid:$oDisp',
        '$rawItemId:$other',
        '$rawItemId:$oUuid',
        '$rawItemId:$oDisp',
        other,
        oUuid,
      ];
      for (final c in checks) {
        if (_deletedConversationKeys.contains(c)) return true;
      }
    }
    return false;
  }

  void recordUserActivity(String? user, {DateTime? activityTime}) {
    if (user == null || user.isEmpty) return;
    if (isUserMe(user)) return;
    final actTime = activityTime ?? DateTime.now();
    // إذا كان التوقيت قديماً بأكثر من 3 دقائق نتجاهله لكي لا تصبح الرسائل القديمة نشاطاً حالياً
    if (DateTime.now().difference(actTime).inMinutes.abs() > 3) return;
    _userLastActiveMap[user] = actTime;
    final uUuid = userToUuid(user);
    if (uUuid.isNotEmpty) _userLastActiveMap[uUuid] = actTime;
    final dName = displayName(user);
    if (dName.isNotEmpty) _userLastActiveMap[dName] = actTime;
  }

  bool isUserOnline(String? user) {
    if (user == null || user.isEmpty) return false;
    if (isUserMe(user)) return false;
    final checks = [user, userToUuid(user), displayName(user)];
    final now = DateTime.now();
    for (final c in checks) {
      final last = _userLastActiveMap[c];
      if (last != null && now.difference(last).inMinutes < 3) {
        return true;
      }
    }
    return false;
  }

  List<String> get myBlockedUsersList {
    final list = <String>{};
    for (final u in bannedUsers) {
      final name = displayName(u);
      if (name.isNotEmpty && !name.contains('-') && name != 'مستخدم') {
        list.add(name);
      } else if (u.isNotEmpty && !u.contains('-') && u != 'مستخدم') {
        list.add(u);
      }
    }
    return list.toList();
  }

  void _mergeIncomingDirectMessage(String rawItemId, DirectMessage msg) {
    if (isConversationOrMessageDeleted(
      rawItemId: rawItemId,
      msgId: msg.id,
      sender: msg.sender,
      receiver: msg.receiver,
    )) {
      return;
    }
    recordUserActivity(msg.sender, activityTime: msg.time);

    final key = _normalizeItemKey(rawItemId);
    final list = directChats.putIfAbsent(key, () => []);

    // 1. مطابقة فورية ودقيقة عبر client_msg_id (id) لمنع التكرار دون حذف الرسائل المتشابهة
    final idxById = list.indexWhere((em) => em.id == msg.id);
    if (idxById != -1) {
      list[idxById].isDelivered = true;
      return;
    }

    // 2. مطابقة احتياطية فقط للرسائل المحلية القديمة التي ليس لها UUID قياسي
    final existingIdx = list.indexWhere((em) {
      if (!em.id.startsWith('msg_')) return false;
      final sameSender = (em.sender == msg.sender ||
          userToUuid(em.sender) == userToUuid(msg.sender) ||
          displayName(em.sender) == displayName(msg.sender));
      final sameReceiver = (em.receiver == msg.receiver ||
          userToUuid(em.receiver) == userToUuid(msg.receiver) ||
          displayName(em.receiver) == displayName(msg.receiver));
      final sameText = em.text == msg.text;
      final sameTime = em.time.difference(msg.time).abs().inSeconds < 5;
      return sameSender && sameReceiver && sameText && sameTime;
    });
    if (existingIdx != -1) {
      list[existingIdx].isDelivered = true;
      return;
    }

    list.add(msg);
    list.sort((a, b) => a.time.compareTo(b.time));

    // إذا وصلت رسالة من الطرف الآخر بعد رسائلي السابقة، تُعلَم رسائلي السابقة كمقروءة (✓✓)
    if (!isUserMe(msg.sender)) {
      for (final m in list) {
        if (isUserMe(m.sender) && m.time.isBefore(msg.time)) {
          m.isDelivered = true;
          m.isRead = true;
        }
      }
    }
  }

  List<DirectMessage> getDirectMessages(String itemId) {
    final key = _normalizeItemKey(itemId);
    final list = directChats.putIfAbsent(key, () => []);
    final altKey = itemToUuid(itemId);
    if (altKey != key && directChats.containsKey(altKey)) {
      final altList = directChats[altKey]!;
      for (final m in altList) {
        if (!list.any((x) => x.id == m.id)) {
          list.add(m);
        }
      }
      list.sort((a, b) => a.time.compareTo(b.time));
    }
    return list;
  }

  void sendDirectMessage(Item itemParam, String otherParty, String text) {
    final item = items.firstWhere(
      (it) => it.id == itemParam.id || itemToUuid(it.id) == itemToUuid(itemParam.id),
      orElse: () => itemParam,
    );
    if (isUserBlocked(otherParty)) return;

    // استعادة المحادثة وإلغاء وسم الحذف إذا بادر المستخدم بالإرسال مجدداً
    final itemKey = _normalizeItemKey(item.id);
    final targetUuid = itemToUuid(item.id);
    final otherUuid = userToUuid(otherParty);
    final otherDisp = displayName(otherParty);
    _deletedConversationKeys.removeAll([
      '$itemKey:$otherParty',
      '$itemKey:$otherUuid',
      '$itemKey:$otherDisp',
      '$targetUuid:$otherParty',
      '$targetUuid:$otherUuid',
      '$targetUuid:$otherDisp',
      '${item.id}:$otherParty',
      '${item.id}:$otherUuid',
      item.id,
      itemKey,
      targetUuid,
    ]);
    LocalStorageHelper.saveDeletedConversationKeys(_deletedConversationKeys);

    final senderUuid = userToUuid(me);
    final receiverUuid = userToUuid(otherParty);
    final msg = DirectMessage(
      me,
      otherParty,
      text,
      DateTime.now(),
      id: generateUuid(),
      senderId: senderUuid,
      receiverId: receiverUuid,
      isDelivered: false,
      isRead: false,
    );

    final list = getDirectMessages(item.id);
    list.add(msg);
    _saveToDisk();
    notifyListeners();
    try {
      _chatBroadcastChannel?.sendBroadcastMessage(
        event: 'dm',
        payload: {
          'itemId': item.id,
          'msg': msg.toJson(),
        },
      );
    } catch (_) {}
    _recordDirectMessageToCloud(item, otherParty, msg);
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
        (i) => i.id == itemId || itemToUuid(i.id) == itemToUuid(itemId),
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
        if (isConversationOrMessageDeleted(
          rawItemId: itemId,
          msgId: msg.id,
          sender: msg.sender,
          receiver: msg.receiver,
        )) {
          continue;
        }

        if (isUserMe(msg.sender) || isUserMe(msg.receiver)) {
          final rawOtherParty = isUserMe(msg.sender) ? msg.receiver : msg.sender;
          final cleanOther = displayName(rawOtherParty);
          final canonUserUuid = userToUuid(rawOtherParty);
          final canonItemUuid = itemToUuid(item.id);
          final key = '${canonItemUuid}_$canonUserUuid';

          final isUnread = !isUserMe(msg.sender) && !msg.isRead;
          final existing = convs[key];
          final newCount = (existing?.totalMessages ?? 0) + 1;
          final newUnread = (existing?.unreadCount ?? 0) + (isUnread ? 1 : 0);

          final finalOtherParty = (cleanOther != 'مستخدم' && !cleanOther.startsWith('user_'))
              ? cleanOther
              : (existing?.otherParty ?? cleanOther);

          if (existing == null || msg.time.isAfter(existing.lastMessage.time)) {
            convs[key] = ChatConversation(
              item: item,
              otherParty: finalOtherParty,
              lastMessage: msg,
              totalMessages: newCount,
              unreadCount: newUnread,
            );
          } else {
            convs[key] = ChatConversation(
              item: existing.item,
              otherParty: (finalOtherParty != 'مستخدم') ? finalOtherParty : existing.otherParty,
              lastMessage: existing.lastMessage,
              totalMessages: newCount,
              unreadCount: newUnread,
            );
          }
        }
      }
    }
    final list = convs.values.toList();
    list.sort((a, b) => b.lastMessage.time.compareTo(a.lastMessage.time));
    return list;
  }

  int get unreadDirectMessagesCount {
    int total = 0;
    for (final conv in getMyConversations()) {
      total += conv.unreadCount;
    }
    return total;
  }

  void markConversationAsRead(String itemId, String otherParty) {
    bool changed = false;
    final otherUuid = userToUuid(otherParty);
    final targetItemUuid = itemToUuid(itemId);
    final itemKey = _normalizeItemKey(itemId);
    final otherDisp = displayName(otherParty);

    for (final entry in directChats.entries) {
      final isItemMatch = entry.key == itemId ||
          entry.key == itemKey ||
          itemToUuid(entry.key) == targetItemUuid ||
          _normalizeItemKey(entry.key) == itemKey;
      if (isItemMatch) {
        for (final m in entry.value) {
          if (!isUserMe(m.sender)) {
            final isSenderOther = m.sender == otherParty ||
                m.senderId == otherParty ||
                m.senderId == otherUuid ||
                userToUuid(m.sender) == otherUuid ||
                displayName(m.sender) == otherDisp ||
                displayName(m.sender) == displayName(otherParty);
            if (isSenderOther && !m.isRead) {
              m.isRead = true;
              changed = true;
            }
          }
        }
      }
    }
    if (changed) {
      _saveToDisk();
      notifyListeners();
    }
    _syncConversationReadToCloud(itemId, otherParty);
  }

  Future<void> _syncConversationReadToCloud(String itemId, String otherParty) async {
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client != null) {
        final itemUuid = itemToUuid(itemId);
        final myUuid = settings.userId ?? userToUuid(me);
        final otherUuid = userToUuid(otherParty);
        await client
            .from('messages')
            .update({'is_read': true})
            .eq('item_id', itemUuid)
            .eq('receiver_id', myUuid)
            .eq('sender_id', otherUuid);
      }
    } catch (_) {}
  }

  Future<void> pollMessagesForChat(String rawItemId) async {
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client == null) return;
      final itemUuid = itemToUuid(rawItemId);
      final myUuid = settings.userId ?? userToUuid(me);
      final rows = await client
          .from('messages')
          .select('*')
          .eq('item_id', itemUuid)
          .or('sender_id.eq.$myUuid,receiver_id.eq.$myUuid')
          .order('created_at', ascending: true);
      if (rows.isNotEmpty) {
        _applyMessagesStream(List<Map<String, dynamic>>.from(rows));
      }
    } catch (_) {}
  }

  void deleteConversation(String itemId, String otherParty) {
    final otherUuid = userToUuid(otherParty);
    final otherDisp = displayName(otherParty);
    final itemKey = _normalizeItemKey(itemId);
    final targetItemUuid = itemToUuid(itemId);

    // تسجيل مفاتيح الحذف لمنع عودة المحادثة بعد الريفريش أو السحب من السحابة
    _deletedConversationKeys.addAll([
      '$itemId:$otherParty',
      '$itemId:$otherUuid',
      '$itemId:$otherDisp',
      '$itemKey:$otherParty',
      '$itemKey:$otherUuid',
      '$itemKey:$otherDisp',
      '$targetItemUuid:$otherParty',
      '$targetItemUuid:$otherUuid',
      '$targetItemUuid:$otherDisp',
    ]);
    LocalStorageHelper.saveDeletedConversationKeys(_deletedConversationKeys);

    final keysToRemove = <String>[];
    for (final entry in directChats.entries) {
      if (entry.key == itemId || entry.key == itemKey || itemToUuid(entry.key) == targetItemUuid) {
        entry.value.removeWhere((m) {
          final isTarget = m.sender == otherParty ||
              userToUuid(m.sender) == otherUuid ||
              displayName(m.sender) == otherDisp ||
              m.receiver == otherParty ||
              userToUuid(m.receiver) == otherUuid ||
              displayName(m.receiver) == otherDisp;
          if (isTarget) {
            _deletedMessageIds.add(m.id);
            return true;
          }
          return false;
        });
        if (entry.value.isEmpty) {
          keysToRemove.add(entry.key);
        }
      }
    }
    for (final k in keysToRemove) {
      directChats.remove(k);
    }
    LocalStorageHelper.saveDeletedMessageIds(_deletedMessageIds);
    _saveToDisk();
    notifyListeners();

    // حذف أحادي الطرف (Soft Delete per user):
    // لا نحذف السجلات من جدول messages في السحابة حتى تظل المحادثة محفوظة وظاهرة لدى الطرف الآخر.
    // يتم إخفاؤها فقط لدى المستخدم الحالي عبر تسجيلها في مفاتيح الحذف المحلية المسجلة.
  }

  void deleteItemDirectChat(String itemId) {
    final itemKey = _normalizeItemKey(itemId);
    final targetItemUuid = itemToUuid(itemId);

    _deletedConversationKeys.addAll([itemId, itemKey, targetItemUuid]);
    LocalStorageHelper.saveDeletedConversationKeys(_deletedConversationKeys);

    directChats.remove(itemId);
    directChats.remove(itemKey);
    directChats.remove(targetItemUuid);
    _saveToDisk();
    notifyListeners();

    if (settings.isCloudConfigured) {
      try {
        final itemUuid = itemToUuid(itemId);
        supabaseClient?.from('messages').delete().eq('item_id', itemUuid).ignore();
      } catch (_) {}
    }
  }

  void deleteSingleMessage(String itemId, DirectMessage msg) {
    _deletedMessageIds.add(msg.id);
    LocalStorageHelper.saveDeletedMessageIds(_deletedMessageIds);

    for (final entry in directChats.entries) {
      if (entry.key == itemId || itemToUuid(entry.key) == itemToUuid(itemId)) {
        entry.value.removeWhere((m) =>
            m.id == msg.id ||
            (m.sender == msg.sender &&
                m.text == msg.text &&
                m.time.isAtSameMomentAs(msg.time)));
      }
    }
    _saveToDisk();
    notifyListeners();
    if (settings.isCloudConfigured) {
      try {
        supabaseClient
            ?.from('messages')
            .delete()
            .eq('id', itemToUuid(msg.id))
            .ignore();
      } catch (_) {}
    }
  }

  void blockUser(String user) {
    bannedUsers.add(user);
    final mapped = userDisplayNames[user];
    if (mapped != null) bannedUsers.add(mapped);
    bannedUsers.add(userToUuid(user));
    LocalStorageHelper.saveBlockedUsers(bannedUsers);
    _persistAndSync();
  }

  void unblockUser(String user) {
    bannedUsers.remove(user);
    final mapped = userDisplayNames[user];
    if (mapped != null) bannedUsers.remove(mapped);
    bannedUsers.remove(userToUuid(user));
    LocalStorageHelper.saveBlockedUsers(bannedUsers);
    _persistAndSync();
  }

  bool isUserBlocked(String user) {
    if (bannedUsers.contains(user)) return true;
    final mapped = userDisplayNames[user];
    if (mapped != null && bannedUsers.contains(mapped)) return true;
    return bannedUsers.contains(userToUuid(user));
  }

  void reportUser({
    required String reportedUser,
    required String reason,
    String? itemId,
    String? itemTitle,
  }) {
    final newRep = FraudReport(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      reporter: me,
      reportedUser: displayName(reportedUser),
      itemId: itemId ?? '',
      itemTitle: itemTitle ?? 'محادثة مباشرة',
      reason: reason,
      time: DateTime.now(),
    );
    reports.insert(0, newRep);
    _persistAndSync();
    _recordReportToCloud(newRep);
  }

  Future<void> _recordReportToCloud(FraudReport rep) async {
    if (!settings.isCloudConfigured) return;
    try {
      final client = supabaseClient;
      if (client == null) return;
      await client.from('reports').upsert({
        'id': itemToUuid(rep.id),
        'reporter_id': userToUuid(rep.reporter),
        'reported_user_id': userToUuid(rep.reportedUser),
        'item_id': rep.itemId.isNotEmpty ? itemToUuid(rep.itemId) : null,
        'item_title': rep.itemTitle,
        'reason': rep.reason,
        'is_resolved': rep.isResolved,
        'created_at': toIsoUtc(rep.time),
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Cloud report record error: $e');
    }
  }

  int get totalMessagesCount {
    int total = 0;
    for (final list in directChats.values) {
      total += list.where((m) => isUserMe(m.sender) || isUserMe(m.receiver)).length;
    }
    return total;
  }

  // ----------------------- دوال الحفظ المباشر في السحابة (Cloud Direct Actions) -----------------------

  Future<void> _recordBidToCloud(Item item, Bid bid) async {
    if (!settings.isCloudConfigured) return;
    try {
      final bidderUuid = userToUuid(bid.bidder);
      await _ensureProfileExists(bidderUuid, bid.bidder);
      await _ensureItemExists(item);
      final itemUuid = itemToUuid(item.id);
      final client = supabaseClient;
      if (client != null) {
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
      final senderUuid = userToUuid(comment.author);
      await _ensureProfileExists(senderUuid, comment.author);
      await _ensureItemExists(item);
      final itemUuid = itemToUuid(item.id);
      final client = supabaseClient;
      if (client != null) {
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
      Item item, String otherParty, DirectMessage msg) async {
    if (!settings.isCloudConfigured) return;
    final senderUuid = msg.senderId ?? userToUuid(me);
    final receiverUuid = msg.receiverId ?? userToUuid(otherParty);
    final itemUuid = itemToUuid(item.id);
    final msgUuid = itemToUuid(msg.id);

    final msgRow = {
      'id': msgUuid,
      'item_id': itemUuid,
      'sender_id': senderUuid,
      'receiver_id': receiverUuid,
      'content': msg.text,
      'created_at': toIsoUtc(msg.time),
    };

    try {
      await _ensureProfileExists(senderUuid, me);
      await _ensureProfileExists(receiverUuid, otherParty);
      await _ensureItemExists(item);

      final client = supabaseClient;
      if (client != null) {
        await client.from('messages').upsert(msgRow, onConflict: 'id');
        // تحديث جداول المحادثات المنفصلة الاحترافية إن كانت مفعلة في قاعدة البيانات
        try {
          final sellerUuid = userToUuid(item.seller);
          final buyerUuid =
              (senderUuid == sellerUuid) ? receiverUuid : senderUuid;
          final convId = _toUuid('conv_${itemUuid}_$buyerUuid');
          await client.from('conversations').upsert({
            'id': convId,
            'item_id': itemUuid,
            'buyer_id': buyerUuid,
            'seller_id': sellerUuid,
            'last_message_at': toIsoUtc(msg.time),
            'last_message_preview': msg.text,
          }, onConflict: 'id');
          await client.from('conversation_members').upsert([
            {
              'conversation_id': convId,
              'user_id': senderUuid,
              'last_read_at': toIsoUtc(msg.time),
            },
            {
              'conversation_id': convId,
              'user_id': receiverUuid,
            },
          ]);
          await client.from('direct_messages').upsert({
            'id': msgUuid,
            'conversation_id': convId,
            'sender_id': senderUuid,
            'client_msg_id': msgUuid,
            'body': msg.text,
            'type': 'text',
            'created_at': toIsoUtc(msg.time),
          }, onConflict: 'client_msg_id');
        } catch (_) {}

        msg.isDelivered = true;
        _saveToDisk();
        notifyListeners();
        return;
      }
      final (code, _) =
          await _upsertRows(_cleanBaseUrl, 'messages', 'id', [msgRow]);
      if (code >= 200 && code < 300) {
        msg.isDelivered = true;
        _saveToDisk();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Cloud record direct message error: $e');
      try {
        final (code, _) =
            await _upsertRows(_cleanBaseUrl, 'messages', 'id', [msgRow]);
        if (code >= 200 && code < 300) {
          msg.isDelivered = true;
          _saveToDisk();
          notifyListeners();
        }
      } catch (httpErr) {
        debugPrint('Fallback HTTP direct message error: $httpErr');
      }
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
          'id': itemToUuid(item.id),
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
    final realPhone = userPhones[user] ?? userPhones[userToUuid(user)];
    if (realPhone != null && realPhone.isNotEmpty) return realPhone;
    final uUuid = userToUuid(user).replaceAll('-', '');
    final short = uUuid.length >= 8 ? uUuid.substring(0, 8) : uUuid;
    return '+96477$short';
  }

  String? getUserPhoto(String user) {
    if (isUserMe(user)) {
      final p = settings.photoPath;
      if (p != null && p.isNotEmpty) return p;
    }
    final direct = userPhotos[user];
    if (direct != null && direct.isNotEmpty) return direct;
    final byUuid = userPhotos[userToUuid(user)];
    if (byUuid != null && byUuid.isNotEmpty) return byUuid;
    final byName = userPhotos[displayName(user)];
    if (byName != null && byName.isNotEmpty) return byName;
    return null;
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
    final rep = FraudReport(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      reporter: me,
      reportedUser: reportedUser,
      itemId: item.id,
      itemTitle: item.title,
      reason: reason,
      time: DateTime.now(),
    );
    reports.insert(0, rep);
    _persistAndSync();
    _recordReportToCloud(rep);
  }

  void warnUser(String user, String? reportId) {
    userWarnings[user] = (userWarnings[user] ?? 0) + 1;
    if (reportId != null) {
      for (final r in reports) {
        if (r.id == reportId) r.isResolved = true;
      }
      if (settings.isCloudConfigured) {
        try {
          supabaseClient?.from('reports').update({'is_resolved': true}).eq('id', itemToUuid(reportId)).ignore();
        } catch (_) {}
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
      if (settings.isCloudConfigured) {
        try {
          supabaseClient?.from('reports').update({'is_resolved': true}).eq('id', itemToUuid(reportId)).ignore();
        } catch (_) {}
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

  /// قائمة المستخدمين الفريدين بدون تكرار الحسابات والمعرفات (Deduplicated Users)
  List<String> get allKnownUsers {
    final seenKeys = <String>{};
    final seenDisplays = <String>{};
    final result = <String>[];

    void addCandidate(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == 'مستخدم' || trimmed == '؟') return;
      final uuid = userToUuid(trimmed);
      final disp = displayName(trimmed).trim();
      final finalDisp = disp.isNotEmpty ? disp : trimmed;

      if (!seenKeys.add(uuid)) return;
      if (!seenDisplays.add(finalDisp)) return;
      result.add(finalDisp);
    }

    addCandidate(me);
    for (final name in userDisplayNames.values) {
      addCandidate(name);
    }
    for (final i in items) {
      if (i.seller.isNotEmpty) addCandidate(i.seller);
      for (final b in i.bids) {
        if (b.bidder.isNotEmpty) addCandidate(b.bidder);
      }
    }
    const dummyNames = {'علي', 'زينب', 'حسن', 'ليلى', 'سمير_متلاعب'};
    result.removeWhere((u) => dummyNames.contains(u) && !items.any((i) => i.seller == u));
    return result;
  }
}

final store = AuctionStore();

