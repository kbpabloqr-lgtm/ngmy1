import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

enum TransactionStatus { pending, completed, rejected }

enum TransactionCategory { deposit, withdraw, game }

class BettingHistoryEntry {
  BettingHistoryEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.isCredit,
    required this.category,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.status = TransactionStatus.completed,
    this.receiptBytes,
    this.receiptName,
  });

  final String id;
  final String title;
  final double amount;
  final bool isCredit;
  final TransactionCategory category;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  TransactionStatus status;
  final Uint8List? receiptBytes;
  final String? receiptName;

  BettingHistoryEntry copyWith({
    TransactionStatus? status,
    Uint8List? receiptBytes,
    String? receiptName,
  }) {
    return BettingHistoryEntry(
      id: id,
      title: title,
      amount: amount,
      isCredit: isCredit,
      category: category,
      icon: icon,
      color: color,
      timestamp: timestamp,
      status: status ?? this.status,
      receiptBytes: receiptBytes ?? this.receiptBytes,
      receiptName: receiptName ?? this.receiptName,
    );
  }

  // Serialize to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'isCredit': isCredit,
      'category': category.name,
      'iconCodePoint': icon.codePoint,
      // ignore: deprecated_member_use
      'colorValue': color.value,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'receiptBytes': receiptBytes != null ? base64Encode(receiptBytes!) : null,
      'receiptName': receiptName,
    };
  }

  // Deserialize from JSON
  factory BettingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return BettingHistoryEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      isCredit: json['isCredit'] as bool,
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => TransactionCategory.game,
      ),
      icon: IconData(
        json['iconCodePoint'] as int,
        fontFamily: 'MaterialIcons',
      ),
      color: Color(json['colorValue'] as int),
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.completed,
      ),
      receiptBytes: json['receiptBytes'] != null
          ? base64Decode(json['receiptBytes'] as String)
          : null,
      receiptName: json['receiptName'] as String?,
    );
  }
}
