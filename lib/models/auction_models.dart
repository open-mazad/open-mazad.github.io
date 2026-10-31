import 'package:flutter/material.dart';

class Bid {
  final String bidder;
  final int amount;
  final DateTime time;
  final bool isAuto;

  Bid(
    this.bidder,
    this.amount,
    this.time, {
    this.isAuto = false,
  });

  Map<String, dynamic> toJson() => {
        'bidder': bidder,
        'amount': amount,
        'time': time.toUtc().toIso8601String(),
        'isAuto': isAuto,
      };

  factory Bid.fromJson(Map<String, dynamic> j) => Bid(
        j['bidder'] as String? ?? '',
        (j['amount'] as num?)?.toInt() ?? 0,
        DateTime.tryParse(j['time'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        isAuto: j['isAuto'] as bool? ?? false,
      );
}

class AuctionComment {
  final String author;
  final String text;
  final DateTime time;
  AuctionComment(this.author, this.text, this.time);

  Map<String, dynamic> toJson() => {
        'author': author,
        'text': text,
        'time': time.toUtc().toIso8601String(),
      };

  factory AuctionComment.fromJson(Map<String, dynamic> j) => AuctionComment(
        j['author'] as String? ?? '',
        j['text'] as String? ?? '',
        DateTime.tryParse(j['time'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class DirectMessage {
  final String id; // client_msg_id ثابت وفريد لمنع التكرار أو ضياع الرسائل المتشابهة
  final String sender;
  final String receiver;
  final String? senderId;
  final String? receiverId;
  final String text;
  final DateTime time;
  bool isDelivered;
  bool isRead;

  DirectMessage(
    this.sender,
    this.receiver,
    this.text,
    this.time, {
    String? id,
    this.senderId,
    this.receiverId,
    this.isDelivered = false,
    this.isRead = false,
  }) : id = (id != null && id.isNotEmpty)
            ? id
            : 'msg_${time.microsecondsSinceEpoch}_${sender.hashCode.abs()}_${text.hashCode.abs()}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'receiver': receiver,
        if (senderId != null) 'senderId': senderId,
        if (receiverId != null) 'receiverId': receiverId,
        'text': text,
        'time': time.toUtc().toIso8601String(),
        'isDelivered': isDelivered,
        'isRead': isRead,
      };

  factory DirectMessage.fromJson(Map<String, dynamic> j) => DirectMessage(
        j['sender'] as String? ?? '',
        j['receiver'] as String? ?? '',
        j['text'] as String? ?? '',
        DateTime.tryParse(j['time'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        id: j['id'] as String?,
        senderId: j['senderId'] as String?,
        receiverId: j['receiverId'] as String?,
        isDelivered: j['isDelivered'] as bool? ?? false,
        isRead: j['isRead'] as bool? ?? false,
      );
}

class ChatConversation {
  final Item item;
  final String otherParty;
  final String? otherPartyUuid;
  final DirectMessage lastMessage;
  final int totalMessages;
  final int unreadCount;

  const ChatConversation({
    required this.item,
    required this.otherParty,
    this.otherPartyUuid,
    required this.lastMessage,
    this.totalMessages = 1,
    this.unreadCount = 0,
  });
}

class UserReview {
  final String reviewer;
  final int stars;
  final String comment;
  final DateTime time;
  UserReview(this.reviewer, this.stars, this.comment, this.time);

  Map<String, dynamic> toJson() => {
        'reviewer': reviewer,
        'stars': stars,
        'comment': comment,
        'time': time.toUtc().toIso8601String(),
      };

  factory UserReview.fromJson(Map<String, dynamic> j) => UserReview(
        j['reviewer'] as String? ?? '',
        (j['stars'] as num?)?.toInt() ?? 5,
        j['comment'] as String? ?? '',
        (DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now())
            .toLocal(),
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final IconData icon;
  final Color color;
  final String? itemId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.icon = Icons.notifications,
    this.color = Colors.indigo,
    this.itemId,
    this.isRead = false,
  });
}

class FraudReport {
  final String id;
  final String reporter;
  final String reportedUser;
  final String itemId;
  final String itemTitle;
  final String reason;
  final DateTime time;
  bool isResolved;

  FraudReport({
    required this.id,
    required this.reporter,
    required this.reportedUser,
    required this.itemId,
    required this.itemTitle,
    required this.reason,
    required this.time,
    this.isResolved = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporter': reporter,
        'reportedUser': reportedUser,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'reason': reason,
        'time': time.toUtc().toIso8601String(),
        'isResolved': isResolved,
      };

  factory FraudReport.fromJson(Map<String, dynamic> j) => FraudReport(
        id: j['id'] as String? ?? '',
        reporter: j['reporter'] as String? ?? '',
        reportedUser: j['reportedUser'] as String? ?? '',
        itemId: j['itemId'] as String? ?? '',
        itemTitle: j['itemTitle'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        time: (DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now())
            .toLocal(),
        isResolved: j['isResolved'] as bool? ?? false,
      );
}

class Item {
  final String id;
  final String title;
  final String description;
  final String category;
  final String seller;
  final String condition;
  final String location;
  final String area;
  final String deliveryMethod;
  final int startPrice;
  DateTime startTime;
  DateTime endTime;

  /// تعدد الصور + الفيديو القصير
  final List<String> imagePaths;
  final String? videoPath;

  /// الحقول المخصصة الذكية حسب الفئة
  final Map<String, String> attributes;

  /// رمز PIN للمزادات الخاصة المغلقة
  final String? pinCode;

  bool isEndedEarlyBySeller;
  bool isCancelled;
  bool isLiveStreaming;
  int liveViewers;
  int extensionsCount;
  bool notifiedStart;

  /// المستخدمون الذين طلبوا تذكيرهم عند بدء المزاد المجدول
  final Set<String> remindMeUsers = {};

  /// مزايدات تلقائية مسجلة: bidder -> maxLimit
  final Map<String, int> autoBids = {};

  /// المزايدات: الأحدث أولاً
  final List<Bid> bids = [];

  /// التعليقات والاستفسارات المباشرة
  final List<AuctionComment> comments = [];

  Item({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.seller,
    required this.startPrice,
    required this.endTime,
    DateTime? startTime,
    this.condition = 'شبه جديد',
    this.location = 'بغداد',
    this.area = 'المنصور',
    this.deliveryMethod = 'استلام باليد',
    this.imagePaths = const [],
    this.videoPath,
    this.attributes = const {},
    this.pinCode,
    this.isEndedEarlyBySeller = false,
    this.isCancelled = false,
    this.isLiveStreaming = false,
    this.liveViewers = 0,
    this.extensionsCount = 0,
    this.notifiedStart = true,
  }) : startTime = startTime ?? DateTime.now().subtract(const Duration(minutes: 1));

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'seller': seller,
        'condition': condition,
        'location': location,
        'area': area,
        'deliveryMethod': deliveryMethod,
        'startPrice': startPrice,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'imagePaths': imagePaths,
        'videoPath': videoPath,
        'attributes': attributes,
        'pinCode': pinCode,
        'isEndedEarlyBySeller': isEndedEarlyBySeller,
        'isCancelled': isCancelled,
        'isLiveStreaming': isLiveStreaming,
        'liveViewers': liveViewers,
        'extensionsCount': extensionsCount,
        'notifiedStart': notifiedStart,
        'remindMeUsers': remindMeUsers.toList(),
        'autoBids': autoBids,
        'bids': bids.map((b) => b.toJson()).toList(),
        'comments': comments.map((c) => c.toJson()).toList(),
      };

  factory Item.fromJson(Map<String, dynamic> j) {
    final item = Item(
      id: j['id'] as String? ?? '0',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      category: j['category'] as String? ?? 'إلكترونيات وأجهزة',
      seller: j['seller'] as String? ?? '',
      condition: j['condition'] as String? ?? 'شبه جديد',
      location: j['location'] as String? ?? 'بغداد',
      area: j['area'] as String? ?? 'المركز',
      deliveryMethod: j['deliveryMethod'] as String? ?? 'استلام باليد',
      startPrice: (j['startPrice'] as num?)?.toInt() ?? 1000,
      startTime: DateTime.tryParse(j['startTime'] as String? ?? '')?.toLocal() ??
          DateTime.now().subtract(const Duration(minutes: 1)),
      endTime: DateTime.tryParse(j['endTime'] as String? ?? '')?.toLocal() ??
          DateTime.now().add(const Duration(days: 1)),
      imagePaths: (j['imagePaths'] as List?)?.map((e) => '$e').toList() ?? const [],
      videoPath: j['videoPath'] as String?,
      attributes: (j['attributes'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
      pinCode: j['pinCode'] as String?,
      isEndedEarlyBySeller: j['isEndedEarlyBySeller'] as bool? ?? false,
      isCancelled: j['isCancelled'] as bool? ?? false,
      isLiveStreaming: j['isLiveStreaming'] as bool? ?? false,
      liveViewers: (j['liveViewers'] as num?)?.toInt() ?? 0,
      extensionsCount: (j['extensionsCount'] as num?)?.toInt() ?? 0,
      notifiedStart: j['notifiedStart'] as bool? ?? true,
    );
    if (j['remindMeUsers'] is List) {
      item.remindMeUsers.addAll((j['remindMeUsers'] as List).map((e) => '$e'));
    }
    if (j['autoBids'] is Map) {
      (j['autoBids'] as Map).forEach((k, v) {
        if (v is num) item.autoBids['$k'] = v.toInt();
      });
    }
    if (j['bids'] is List) {
      for (final b in j['bids'] as List) {
        if (b is Map<String, dynamic>) item.bids.add(Bid.fromJson(b));
      }
    }
    if (j['comments'] is List) {
      for (final c in j['comments'] as List) {
        if (c is Map<String, dynamic>) {
          item.comments.add(AuctionComment.fromJson(c));
        }
      }
    }
    return item;
  }

  bool get isPrivate => pinCode != null && pinCode!.trim().isNotEmpty;

  bool get isScheduled =>
      !isCancelled && DateTime.now().isBefore(startTime.toLocal());

  Duration get timeUntilStart =>
      isScheduled ? startTime.toLocal().difference(DateTime.now()) : Duration.zero;

  Bid? get topBid {
    if (bids.isEmpty) return null;
    Bid highest = bids.first;
    for (int i = 1; i < bids.length; i++) {
      if (bids[i].amount > highest.amount) {
        highest = bids[i];
      }
    }
    return highest;
  }

  int get currentPrice =>
      (isCancelled || topBid == null) ? startPrice : topBid!.amount;

  String? get highestBidder =>
      (isCancelled || topBid == null) ? null : topBid!.bidder;

  bool get isEnded =>
      isCancelled ||
      isEndedEarlyBySeller ||
      (!isScheduled && !DateTime.now().isBefore(endTime.toLocal()));

  Duration get timeLeft =>
      (isEnded || isScheduled) ? Duration.zero : endTime.toLocal().difference(DateTime.now());

  /// خطوة الزيادة مفتوحة: يقبل أي مبلغ أعلى من السعر الحالي (أو يساوي سعر البداية إن لم تكن هناك مزايدات)
  int get minBid => bids.isEmpty ? startPrice : currentPrice + 1;

  /// خطوة مقترحة للمزايدة التلقائية (Auto-Bid) لمنع الزيادة بدينار واحد فقط في التنافس الآلي
  int get autoBidStep {
    final step = ((currentPrice * 0.02) / 1000).ceil() * 1000;
    return step < 1000 ? 1000 : step;
  }
}
