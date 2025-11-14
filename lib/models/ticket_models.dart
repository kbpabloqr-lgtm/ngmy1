import 'package:flutter/material.dart';

/// Code application status
enum CodeApplicationStatus {
  pending,
  approved,
  rejected,
  expired,
}

/// Code application model
class CodeApplication {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String reason;
  final DateTime appliedAt;
  CodeApplicationStatus status;
  String? approvedCode;
  DateTime? codeExpiryDate;
  String? rejectionReason;

  CodeApplication({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.reason,
    required this.appliedAt,
    this.status = CodeApplicationStatus.pending,
    this.approvedCode,
    this.codeExpiryDate,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'reason': reason,
        'appliedAt': appliedAt.toIso8601String(),
        'status': status.name,
        'approvedCode': approvedCode,
        'codeExpiryDate': codeExpiryDate?.toIso8601String(),
        'rejectionReason': rejectionReason,
      };

  factory CodeApplication.fromJson(Map<String, dynamic> json) => CodeApplication(
        id: json['id'],
        userId: json['userId'],
        userName: json['userName'],
        userEmail: json['userEmail'],
        reason: json['reason'],
        appliedAt: DateTime.parse(json['appliedAt']),
        status: CodeApplicationStatus.values.firstWhere((e) => e.name == json['status']),
        approvedCode: json['approvedCode'],
        codeExpiryDate: json['codeExpiryDate'] != null ? DateTime.parse(json['codeExpiryDate']) : null,
        rejectionReason: json['rejectionReason'],
      );
}

/// Ticket template type
enum TicketTemplateType {
  concert,
  sports,
  conference,
  vip,
  generalAdmission,
  backstage,
  festival,
  theater,
}

/// Ticket template model
class TicketTemplate {
  final String id;
  final String name;
  final TicketTemplateType type;
  final Color primaryColor;
  final Color accentColor;
  final String backgroundImage;
  final bool hasQrCode;
  final List<String> customFields;

  TicketTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundImage,
    this.hasQrCode = true,
    this.customFields = const [],
  });
}

/// Generated ticket/ID model
class GeneratedTicket {
  final String id;
  final String serialNumber; // Unique, cryptographically secure
  final String eventName;
  final String artistName;
  final DateTime eventDate;
  final String venue;
  final String ticketType;
  final double price;
  final String templateId;
  final DateTime createdAt;
  final String createdBy;
  final String qrCodeData;
  final Map<String, String> customData;
  bool isValid;

  GeneratedTicket({
    required this.id,
    required this.serialNumber,
    required this.eventName,
    required this.artistName,
    required this.eventDate,
    required this.venue,
    required this.ticketType,
    required this.price,
    required this.templateId,
    required this.createdAt,
    required this.createdBy,
    required this.qrCodeData,
    this.customData = const {},
    this.isValid = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'serialNumber': serialNumber,
        'eventName': eventName,
        'artistName': artistName,
        'eventDate': eventDate.toIso8601String(),
        'venue': venue,
        'ticketType': ticketType,
        'price': price,
        'templateId': templateId,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'qrCodeData': qrCodeData,
        'customData': customData,
        'isValid': isValid,
      };

  factory GeneratedTicket.fromJson(Map<String, dynamic> json) => GeneratedTicket(
        id: json['id'],
        serialNumber: json['serialNumber'],
        eventName: json['eventName'],
        artistName: json['artistName'],
        eventDate: DateTime.parse(json['eventDate']),
        venue: json['venue'],
        ticketType: json['ticketType'],
        price: json['price'],
        templateId: json['templateId'],
        createdAt: DateTime.parse(json['createdAt']),
        createdBy: json['createdBy'],
        qrCodeData: json['qrCodeData'],
        customData: Map<String, String>.from(json['customData'] ?? {}),
        isValid: json['isValid'] ?? true,
      );
}

/// Access code model
class AccessCode {
  final String code;
  final String userId;
  final DateTime issuedAt;
  final DateTime expiryDate;
  bool isUsed;
  bool isRevoked;

  AccessCode({
    required this.code,
    required this.userId,
    required this.issuedAt,
    required this.expiryDate,
    this.isUsed = false,
    this.isRevoked = false,
  });

  bool get isValid {
    if (isRevoked) return false;
    return DateTime.now().isBefore(expiryDate);
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'userId': userId,
        'issuedAt': issuedAt.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'isUsed': isUsed,
        'isRevoked': isRevoked,
      };

  factory AccessCode.fromJson(Map<String, dynamic> json) => AccessCode(
        code: json['code'],
        userId: json['userId'],
        issuedAt: DateTime.parse(json['issuedAt']),
        expiryDate: DateTime.parse(json['expiryDate']),
        isUsed: json['isUsed'] ?? false,
        isRevoked: json['isRevoked'] ?? false,
      );
}
