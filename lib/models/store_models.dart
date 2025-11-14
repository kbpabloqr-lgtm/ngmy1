import 'package:flutter/material.dart';

enum PrizeType { money, item }

enum PrizeLimitPeriod { week, month }

extension PrizeLimitPeriodLabel on PrizeLimitPeriod {
  String get label => switch (this) {
        PrizeLimitPeriod.week => 'Per Week',
        PrizeLimitPeriod.month => 'Per Month',
      };

  String get shortLabel => switch (this) {
        PrizeLimitPeriod.week => 'week',
        PrizeLimitPeriod.month => 'month',
      };
}

class PrizeSegment {
  PrizeSegment({
    required this.id,
    required this.label,
    required this.type,
    this.moneyAmount = 0,
    this.itemName,
    this.image,
    this.weight = 1,
    required this.color,
    this.betAmount = 0, // Amount user must bet to target this specific item
    this.isTryAgain = false,
    this.tryAgainMessage = 'Try again!',
    this.tryAgainPenalty = 35.0, // Percentage penalty for Try Again (default 35%)
    this.winLimitCount,
    this.winLimitPeriod,
  });

  final String id;
  String label;
  PrizeType type;
  double moneyAmount; // used when type == money
  String? itemName; // used when type == item
  String? image; // optional image url or local path for item
  double weight; // relative chance weight
  Color color;
  double betAmount; // Amount required to bet on this specific item (0 = not bettable)
  bool isTryAgain; // True if this is a "Try Again" segment
  String tryAgainMessage; // Custom message for Try Again outcome
  double tryAgainPenalty; // Percentage of wallet to deduct on Try Again (0-100)
  int? winLimitCount; // Optional high-value prize limit count
  PrizeLimitPeriod? winLimitPeriod; // Optional high-value prize limit period

  static const Object _sentinel = Object();

  PrizeSegment copyWith({
    String? label,
    PrizeType? type,
    double? moneyAmount,
    String? itemName,
    String? image,
    double? weight,
    Color? color,
    double? betAmount,
    bool? isTryAgain,
    String? tryAgainMessage,
    double? tryAgainPenalty,
    Object? winLimitCount = _sentinel,
    Object? winLimitPeriod = _sentinel,
  }) {
    return PrizeSegment(
      id: id,
      label: label ?? this.label,
      type: type ?? this.type,
      moneyAmount: moneyAmount ?? this.moneyAmount,
      itemName: itemName ?? this.itemName,
      image: image ?? this.image,
      weight: weight ?? this.weight,
      color: color ?? this.color,
      betAmount: betAmount ?? this.betAmount,
      isTryAgain: isTryAgain ?? this.isTryAgain,
      tryAgainMessage: tryAgainMessage ?? this.tryAgainMessage,
      tryAgainPenalty: tryAgainPenalty ?? this.tryAgainPenalty,
      winLimitCount: winLimitCount == _sentinel
          ? this.winLimitCount
          : winLimitCount as int?,
      winLimitPeriod: winLimitPeriod == _sentinel
          ? this.winLimitPeriod
          : winLimitPeriod as PrizeLimitPeriod?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type == PrizeType.money ? 'money' : 'item',
      'moneyAmount': moneyAmount,
      'itemName': itemName,
      'image': image,
      'weight': weight,
      // Ignore deprecation warning - color.value is still the most reliable way to serialize Color
      // ignore: deprecated_member_use
      'colorValue': color.value,
      'betAmount': betAmount,
      'isTryAgain': isTryAgain,
      'tryAgainMessage': tryAgainMessage,
      'tryAgainPenalty': tryAgainPenalty,
      'winLimitCount': winLimitCount,
      'winLimitPeriod': winLimitPeriod?.name,
    };
  }
  
  factory PrizeSegment.fromJson(Map<String, dynamic> json) {
    PrizeLimitPeriod? parsePeriod(String? raw) {
      if (raw == null) return null;
      for (final period in PrizeLimitPeriod.values) {
        if (period.name == raw) {
          return period;
        }
      }
      return null;
    }
    return PrizeSegment(
      id: json['id'] as String,
      label: json['label'] as String,
      type: json['type'] == 'money' ? PrizeType.money : PrizeType.item,
      moneyAmount: (json['moneyAmount'] as num?)?.toDouble() ?? 0.0,
      itemName: json['itemName'] as String?,
      image: json['image'] as String?,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      color: Color(json['colorValue'] as int? ?? json['color'] as int? ?? 0xFF000000),
      betAmount: (json['betAmount'] as num?)?.toDouble() ?? 0.0,
      isTryAgain: json['isTryAgain'] as bool? ?? false,
      tryAgainMessage: json['tryAgainMessage'] as String? ?? 'Try again!',
      tryAgainPenalty: (json['tryAgainPenalty'] as num?)?.toDouble() ?? 35.0,
      winLimitCount: (json['winLimitCount'] as num?)?.toInt(),
      winLimitPeriod: parsePeriod(json['winLimitPeriod'] as String?),
    );
  }
}

class ItemWin {
  ItemWin({
    required this.id,
    required this.itemName,
    required this.userId,
    required this.timestamp,
    this.fulfilled = false,
  });

  final String id;
  final String itemName;
  final String userId;
  final DateTime timestamp;
  bool fulfilled;
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemName': itemName,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'fulfilled': fulfilled,
    };
  }
  
  factory ItemWin.fromJson(Map<String, dynamic> json) {
    return ItemWin(
      id: json['id'] as String,
      itemName: json['itemName'] as String,
      userId: json['userId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fulfilled: json['fulfilled'] as bool? ?? false,
    );
  }
}

enum RequestStatus { pending, approved, rejected }

class DepositRequest {
  DepositRequest({
    required this.id,
    required this.userId,
    required this.amount,
    required this.screenshotPath,
    required this.timestamp,
    this.status = RequestStatus.pending,
    this.adminComment,
  });

  final String id;
  final String userId;
  final double amount;
  final String screenshotPath;
  final DateTime timestamp;
  RequestStatus status;
  String? adminComment;
  
  // Check if request is expired (older than 3 days)
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inDays >= 3;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'screenshotPath': screenshotPath,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
      'adminComment': adminComment,
    };
  }
  
  factory DepositRequest.fromJson(Map<String, dynamic> json) {
    RequestStatus statusFromString(String status) {
      switch (status) {
        case 'approved':
          return RequestStatus.approved;
        case 'rejected':
          return RequestStatus.rejected;
        default:
          return RequestStatus.pending;
      }
    }
    
    return DepositRequest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      amount: (json['amount'] as num).toDouble(),
      screenshotPath: json['screenshotPath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: statusFromString(json['status'] as String),
      adminComment: json['adminComment'] as String?,
    );
  }
}

class WithdrawRequest {
  WithdrawRequest({
    required this.id,
    required this.userId,
    required this.amount,
    required this.cashAppTag,
    required this.timestamp,
    this.status = RequestStatus.pending,
  });

  final String id;
  final String userId;
  final double amount;
  final String cashAppTag;
  final DateTime timestamp;
  RequestStatus status;
  
  // Check if request is expired (older than 3 days)
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inDays >= 3;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'cashAppTag': cashAppTag,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
    };
  }
  
  factory WithdrawRequest.fromJson(Map<String, dynamic> json) {
    RequestStatus statusFromString(String status) {
      switch (status) {
        case 'approved':
          return RequestStatus.approved;
        case 'rejected':
          return RequestStatus.rejected;
        default:
          return RequestStatus.pending;
      }
    }
    
    return WithdrawRequest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      amount: (json['amount'] as num).toDouble(),
      cashAppTag: json['cashAppTag'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: statusFromString(json['status'] as String),
    );
  }
}

class ShipmentRequest {
  ShipmentRequest({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.fullName,
    required this.address,
    required this.city,
    required this.zipCode,
    required this.timestamp,
    this.status = RequestStatus.pending,
  });

  final String id;
  final String userId;
  final String itemName;
  final String fullName;
  final String address;
  final String city;
  final String zipCode;
  final DateTime timestamp;
  RequestStatus status;
  
  // Check if request is expired (older than 3 days)
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inDays >= 3;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'itemName': itemName,
      'fullName': fullName,
      'address': address,
      'city': city,
      'zipCode': zipCode,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
    };
  }
  
  factory ShipmentRequest.fromJson(Map<String, dynamic> json) {
    RequestStatus statusFromString(String status) {
      switch (status) {
        case 'approved':
          return RequestStatus.approved;
        case 'rejected':
          return RequestStatus.rejected;
        default:
          return RequestStatus.pending;
      }
    }
    
    return ShipmentRequest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      itemName: json['itemName'] as String,
      fullName: json['fullName'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      zipCode: json['zipCode'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: statusFromString(json['status'] as String),
    );
  }
}

// Spin history to track each user's spin
class SpinHistory {
  SpinHistory({
    required this.id,
    required this.username,
    required this.segmentLabel,
    required this.isWin,
    required this.moneyAmount,
    required this.betAmount,
    required this.timestamp,
    this.itemName,
  });

  final String id;
  final String username;
  final String segmentLabel;
  final bool isWin; // true if won money/item, false if lost (Try Again)
  final double moneyAmount; // Money won or lost
  final double betAmount; // Amount user bet
  final DateTime timestamp;
  final String? itemName; // Item name if won item

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'segmentLabel': segmentLabel,
      'isWin': isWin,
      'moneyAmount': moneyAmount,
      'betAmount': betAmount,
      'timestamp': timestamp.toIso8601String(),
      'itemName': itemName,
    };
  }

  factory SpinHistory.fromJson(Map<String, dynamic> json) {
    return SpinHistory(
      id: json['id'] as String,
      username: json['username'] as String,
      segmentLabel: json['segmentLabel'] as String,
      isWin: json['isWin'] as bool,
      moneyAmount: (json['moneyAmount'] as num?)?.toDouble() ?? 0.0,
      betAmount: (json['betAmount'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      itemName: json['itemName'] as String?,
    );
  }
}

class StoreUser {
  StoreUser({
    required this.userId,
    required this.username,
    required this.walletBalance,
    required this.itemsWon,
    required this.createdAt,
  });

  final String userId; // Unique ID (e.g., "NGMY00001")
  final String username;
  double walletBalance;
  final Map<String, int> itemsWon;
  final DateTime createdAt;
}

