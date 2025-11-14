import 'dart:convert';

class ReferralRecord {
  final String username;
  final String? code;
  final DateTime? usedAt;

  const ReferralRecord({required this.username, this.code, this.usedAt});

  ReferralRecord copyWith({String? username, String? code, DateTime? usedAt}) {
    return ReferralRecord(
      username: username ?? this.username,
      code: code ?? this.code,
      usedAt: usedAt ?? this.usedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      if (code != null && code!.isNotEmpty) 'code': code,
      if (usedAt != null) 'usedAt': usedAt!.toIso8601String(),
    };
  }

  static ReferralRecord fromJson(dynamic value) {
    if (value is ReferralRecord) {
      return value;
    }
    if (value is String) {
      return ReferralRecord(username: value);
    }
    if (value is Map) {
      final map = value.map((key, dynamic v) => MapEntry(key.toString(), v));
      final username = map['username']?.toString() ?? map['name']?.toString();
      final code = map['code']?.toString();
      final usedAtRaw = map['usedAt']?.toString();
      final usedAt = usedAtRaw != null && usedAtRaw.isNotEmpty
          ? DateTime.tryParse(usedAtRaw)
          : null;
      return ReferralRecord(
        username: username ?? 'Unknown',
        code: code?.isEmpty == true ? null : code,
        usedAt: usedAt,
      );
    }
    return ReferralRecord(username: value?.toString() ?? 'Unknown');
  }

  static List<ReferralRecord> decodeList(String source) {
    if (source.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is List) {
        return decoded.map(ReferralRecord.fromJson).toList();
      }
    } catch (_) {
      // Ignore decoding issues and fall back to empty list
    }
    return const [];
  }

  static String encodeList(List<ReferralRecord> records) {
    final encoded = records.map((record) => record.toJson()).toList();
    return jsonEncode(encoded);
  }
}
