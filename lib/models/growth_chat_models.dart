import 'dart:convert';

enum GrowthChatScope { growth, global, familyTree, store }

enum GrowthChatMessageType { text, image, voice }

enum GrowthChatCallType { voice, video }

GrowthChatScope growthChatScopeFromString(String raw) {
  switch (raw) {
    case 'global':
      return GrowthChatScope.global;
    case 'familyTree':
    case 'family_tree':
      return GrowthChatScope.familyTree;
    case 'store':
      return GrowthChatScope.store;
    case 'growth':
    default:
      return GrowthChatScope.growth;
  }
}

extension GrowthChatScopeLabel on GrowthChatScope {
  String get studioLabel {
    switch (this) {
      case GrowthChatScope.global:
        return 'Global Income Studio';
      case GrowthChatScope.growth:
        return 'Growth Income Studio';
      case GrowthChatScope.familyTree:
        return 'Family Tree Studio';
      case GrowthChatScope.store:
        return 'NGMY Store Studio';
    }
  }

  String get broadcastTitle {
    switch (this) {
      case GrowthChatScope.global:
        return 'Global Studio Broadcast';
      case GrowthChatScope.growth:
        return 'Growth Studio Broadcast';
      case GrowthChatScope.familyTree:
        return 'Family Tree Broadcast';
      case GrowthChatScope.store:
        return 'NGMY Store Broadcast';
    }
  }

  String get shortLabel {
    switch (this) {
      case GrowthChatScope.global:
        return 'Global';
      case GrowthChatScope.growth:
        return 'Growth';
      case GrowthChatScope.familyTree:
        return 'Family Tree';
      case GrowthChatScope.store:
        return 'NGMY Store';
    }
  }
}

GrowthChatMessageType growthChatMessageTypeFromString(String raw) {
  switch (raw) {
    case 'image':
      return GrowthChatMessageType.image;
    case 'voice':
      return GrowthChatMessageType.voice;
    case 'text':
    default:
      return GrowthChatMessageType.text;
  }
}

GrowthChatCallType growthChatCallTypeFromString(String raw) {
  switch (raw) {
    case 'video':
      return GrowthChatCallType.video;
    case 'voice':
    default:
      return GrowthChatCallType.voice;
  }
}

class GrowthChatParticipant {
  GrowthChatParticipant({
    required this.userId,
    required this.displayName,
    this.canCreateGroups = false,
    this.isAdmin = false,
  });

  final String userId;
  final String displayName;
  final bool canCreateGroups;
  final bool isAdmin;

  GrowthChatParticipant copyWith({
    String? displayName,
    bool? canCreateGroups,
    bool? isAdmin,
  }) {
    return GrowthChatParticipant(
      userId: userId,
      displayName: displayName ?? this.displayName,
      canCreateGroups: canCreateGroups ?? this.canCreateGroups,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'canCreateGroups': canCreateGroups,
      'isAdmin': isAdmin,
    };
  }

  factory GrowthChatParticipant.fromJson(Map<String, dynamic> json) {
    return GrowthChatParticipant(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Member',
      canCreateGroups: json['canCreateGroups'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }
}

const Object _unset = Object();

class GrowthChatMessage {
  GrowthChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.imagePath,
    this.voicePath,
    this.voiceDurationMillis,
    required this.timestamp,
    this.deletedAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String senderName;
  final GrowthChatMessageType type;
  final String content;
  final String? imagePath;
  final String? voicePath;
  final int? voiceDurationMillis;
  final DateTime timestamp;
  final DateTime? deletedAt;

  GrowthChatMessage copyWith({
    String? content,
    String? imagePath,
    Object? voicePath = _unset,
    Object? voiceDurationMillis = _unset,
    DateTime? timestamp,
    String? senderName,
    DateTime? deletedAt,
  }) {
    return GrowthChatMessage(
      id: id,
      threadId: threadId,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      type: type,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      voicePath:
          identical(voicePath, _unset) ? this.voicePath : voicePath as String?,
      voiceDurationMillis: identical(voiceDurationMillis, _unset)
          ? this.voiceDurationMillis
          : voiceDurationMillis as int?,
      timestamp: timestamp ?? this.timestamp,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'threadId': threadId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'content': content,
      'imagePath': imagePath,
      'voicePath': voicePath,
      'voiceDurationMillis': voiceDurationMillis,
      'timestamp': timestamp.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory GrowthChatMessage.fromJson(Map<String, dynamic> json) {
    final deletedRaw = json['deletedAt'] as String?;
    return GrowthChatMessage(
      id: json['id'] as String? ?? '',
      threadId: json['threadId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Member',
      type: growthChatMessageTypeFromString(json['type'] as String? ?? 'text'),
      content: json['content'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      voicePath: json['voicePath'] as String?,
      voiceDurationMillis: json['voiceDurationMillis'] as int?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      deletedAt: deletedRaw == null || deletedRaw.isEmpty
          ? null
          : DateTime.tryParse(deletedRaw),
    );
  }
}

class GrowthChatCallRecord {
  GrowthChatCallRecord({
    required this.id,
    required this.threadId,
    required this.initiatorId,
    required this.initiatorName,
    required this.type,
    required this.timestamp,
    this.notes,
  });

  final String id;
  final String threadId;
  final String initiatorId;
  final String initiatorName;
  final GrowthChatCallType type;
  final DateTime timestamp;
  final String? notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'threadId': threadId,
      'initiatorId': initiatorId,
      'initiatorName': initiatorName,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }

  factory GrowthChatCallRecord.fromJson(Map<String, dynamic> json) {
    return GrowthChatCallRecord(
      id: json['id'] as String? ?? '',
      threadId: json['threadId'] as String? ?? '',
      initiatorId: json['initiatorId'] as String? ?? '',
      initiatorName: json['initiatorName'] as String? ?? 'Member',
      type: growthChatCallTypeFromString(json['type'] as String? ?? 'voice'),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      notes: json['notes'] as String?,
    );
  }
}

class GrowthChatThread {
  GrowthChatThread({
    required this.id,
    required this.scope,
    required this.isGroup,
    this.isBroadcast = false,
    this.isLocked = false,
    this.lockedUntil,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
    required this.messages,
    required this.callHistory,
  });

  final String id;
  final GrowthChatScope scope;
  final bool isGroup;
  final bool isBroadcast;
  final bool isLocked;
  final DateTime? lockedUntil;
  final String title;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GrowthChatParticipant> participants;
  final List<GrowthChatMessage> messages;
  final List<GrowthChatCallRecord> callHistory;

  GrowthChatThread copyWith({
    String? title,
    DateTime? updatedAt,
    bool? isBroadcast,
    bool? isLocked,
    Object? lockedUntil = _unset,
    List<GrowthChatParticipant>? participants,
    List<GrowthChatMessage>? messages,
    List<GrowthChatCallRecord>? callHistory,
  }) {
    return GrowthChatThread(
      id: id,
      scope: scope,
      isGroup: isGroup,
      isBroadcast: isBroadcast ?? this.isBroadcast,
      isLocked: isLocked ?? this.isLocked,
      lockedUntil: identical(lockedUntil, _unset)
          ? this.lockedUntil
          : lockedUntil as DateTime?,
      title: title ?? this.title,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      callHistory: callHistory ?? this.callHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'scope': scope.name,
      'isGroup': isGroup,
      'isBroadcast': isBroadcast,
      'isLocked': isLocked,
      'lockedUntil': lockedUntil?.toIso8601String(),
      'title': title,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'callHistory': callHistory.map((c) => c.toJson()).toList(),
    };
  }

  factory GrowthChatThread.fromJson(Map<String, dynamic> json) {
    final participantList = (json['participants'] as List<dynamic>? ?? [])
        .map((entry) =>
            GrowthChatParticipant.fromJson(entry as Map<String, dynamic>))
        .toList();

    final messageList = (json['messages'] as List<dynamic>? ?? [])
        .map((entry) =>
            GrowthChatMessage.fromJson(entry as Map<String, dynamic>))
        .toList();

    final callList = (json['callHistory'] as List<dynamic>? ?? [])
        .map((entry) =>
            GrowthChatCallRecord.fromJson(entry as Map<String, dynamic>))
        .toList();

    return GrowthChatThread(
      id: json['id'] as String? ?? '',
      scope: growthChatScopeFromString(json['scope'] as String? ?? 'growth'),
      isGroup: json['isGroup'] as bool? ?? false,
      isBroadcast: json['isBroadcast'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      lockedUntil: DateTime.tryParse(json['lockedUntil'] as String? ?? ''),
      title: json['title'] as String? ?? 'Conversation',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      participants: participantList,
      messages: messageList,
      callHistory: callList,
    );
  }
}

String encodeGrowthThreads(List<GrowthChatThread> threads) {
  final serializable = threads.map((thread) => thread.toJson()).toList();
  return jsonEncode(serializable);
}

List<GrowthChatThread> decodeGrowthThreads(String raw) {
  try {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
            (entry) => GrowthChatThread.fromJson(entry as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return <GrowthChatThread>[];
  }
}
