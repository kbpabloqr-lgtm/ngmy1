import 'package:shared_preferences/shared_preferences.dart';

import '../models/growth_chat_models.dart';

class GrowthDirectoryEntry {
  GrowthDirectoryEntry({
    required this.userId,
    required this.displayName,
    required this.rawKey,
    required this.scope,
    this.phone = '',
    this.profileBase64,
  });

  final String userId;
  final String displayName;
  final String rawKey;
  final GrowthChatScope scope;
  final String phone;
  final String? profileBase64;
}

class GrowthUserDirectory {
  GrowthUserDirectory._();

  static final GrowthUserDirectory instance = GrowthUserDirectory._();

  Future<GrowthDirectoryEntry?> findByIdOrPhone({
    String? userId,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final trimmedId = userId?.trim() ?? '';
    final normalizedPhone = _normalizePhone(phone ?? '');

    if (trimmedId.isNotEmpty) {
      final match = _lookupById(trimmedId, prefs, keys);
      if (match != null) {
        return match;
      }
    }

    if (normalizedPhone.isNotEmpty) {
      final match = _lookupByPhone(normalizedPhone, prefs, keys);
      if (match != null) {
        return match;
      }
    }

    return null;
  }

  GrowthDirectoryEntry? _lookupById(
    String provided,
    SharedPreferences prefs,
    Set<String> keys,
  ) {
    final normalized = provided.trim().toLowerCase();

    for (final key in keys) {
      final value = prefs.getString(key);
      if (value == null) {
        continue;
      }
      final candidate = value.trim();
      if (candidate.isEmpty) {
        continue;
      }
      if (candidate.toLowerCase() != normalized) {
        continue;
      }

      final username = _usernameFromIdKey(key, prefs);
      if (username == null) {
        continue;
      }
      final entry = _entryForUsername(
        username: username,
        prefs: prefs,
        requestedId: candidate,
      );
      if (entry != null) {
        return entry;
      }
    }

    final currentGrowthId = prefs.getString('growth_user_id')?.trim();
    if (currentGrowthId != null && currentGrowthId.toLowerCase() == normalized) {
      final name = prefs.getString('growth_user_name') ?? 'Growth Member';
      final phone = prefs.getString('growth_user_phone') ?? '';
      final profile = prefs.getString('growth_user_profile_picture');
      return GrowthDirectoryEntry(
        userId: currentGrowthId,
        displayName: name.trim().isEmpty ? 'Growth Member' : name.trim(),
        rawKey: name.trim().isEmpty ? 'growth_user' : name.trim(),
        phone: phone.trim(),
        scope: GrowthChatScope.growth,
        profileBase64: profile,
      );
    }

    final currentGlobalId = prefs.getString('global_user_id')?.trim();
    if (currentGlobalId != null && currentGlobalId.toLowerCase() == normalized) {
      final name = prefs.getString('global_user_name') ?? 'Global Member';
      final phone = prefs.getString('global_user_phone') ?? '';
      final profile = prefs.getString('global_user_profile_picture');
      return GrowthDirectoryEntry(
        userId: currentGlobalId,
        displayName: name.trim().isNotEmpty ? name.trim() : 'Global Member',
        rawKey: name.trim().isEmpty ? 'global_user' : name.trim(),
        phone: phone.trim(),
        scope: GrowthChatScope.global,
        profileBase64: profile,
      );
    }

    return null;
  }

  GrowthDirectoryEntry? _lookupByPhone(
    String normalizedPhone,
    SharedPreferences prefs,
    Set<String> keys,
  ) {
    for (final key in keys) {
      if (!_looksLikePhoneKey(key)) {
        continue;
      }
      final value = prefs.getString(key);
      if (value == null) {
        continue;
      }
      final stored = value.trim();
      if (stored.isEmpty) {
        continue;
      }
      final normalizedStored = _normalizePhone(stored);
      if (normalizedStored.isEmpty) {
        continue;
      }
      if (normalizedStored != normalizedPhone) {
        continue;
      }
      final username = _usernameFromPhoneKey(key);
      if (username != null) {
        final entry = _entryForUsername(
          username: username,
          prefs: prefs,
          requestedPhone: stored,
        );
        if (entry != null) {
          return entry;
        }
      }
    }

    final growthPhone = prefs.getString('growth_user_phone')?.trim();
    if (growthPhone != null && _normalizePhone(growthPhone) == normalizedPhone) {
      final id = prefs.getString('growth_user_id')?.trim() ?? '';
      if (id.isNotEmpty) {
        final name = prefs.getString('growth_user_name') ?? 'Growth Member';
        final profile = prefs.getString('growth_user_profile_picture');
        return GrowthDirectoryEntry(
          userId: id,
          displayName: name.trim().isEmpty ? 'Growth Member' : name.trim(),
          rawKey: name.trim().isEmpty ? 'growth_user' : name.trim(),
          phone: growthPhone,
          scope: GrowthChatScope.growth,
          profileBase64: profile,
        );
      }
    }

    final globalPhone = prefs.getString('global_user_phone')?.trim();
    if (globalPhone != null && _normalizePhone(globalPhone) == normalizedPhone) {
      final id = prefs.getString('global_user_id')?.trim() ?? '';
      if (id.isNotEmpty) {
        final name = prefs.getString('global_user_name') ?? 'Global Member';
        final profile = prefs.getString('global_user_profile_picture');
        return GrowthDirectoryEntry(
          userId: id,
          displayName: name.trim().isNotEmpty ? name.trim() : 'Global Member',
          rawKey: name.trim().isEmpty ? 'global_user' : name.trim(),
          phone: globalPhone,
          scope: GrowthChatScope.global,
          profileBase64: profile,
        );
      }
    }

    return null;
  }

  GrowthDirectoryEntry? _entryForUsername({
    required String username,
    required SharedPreferences prefs,
    String? requestedId,
    String? requestedPhone,
  }) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final displayName = _deriveDisplayName(trimmed, prefs);
    final phone = requestedPhone ?? _readPhone(trimmed, prefs);
    final growthId = _readGrowthUserId(trimmed, prefs);
    final globalId = _readGlobalUserId(trimmed, prefs);
  final profile = _resolveProfilePictureBase64(trimmed, prefs);

    var id = requestedId ?? '';
    GrowthChatScope? scope;

    if (id.isEmpty) {
      if (growthId != null) {
        id = growthId;
        scope = GrowthChatScope.growth;
      } else if (globalId != null) {
        id = globalId;
        scope = GrowthChatScope.global;
      }
    } else {
      if (_looksGlobalId(id)) {
        scope = GrowthChatScope.global;
      } else if (_looksGrowthId(id)) {
        scope = GrowthChatScope.growth;
      }
    }

    scope ??= globalId != null ? GrowthChatScope.global : GrowthChatScope.growth;

    if (id.isEmpty) {
      return null;
    }

    return GrowthDirectoryEntry(
      userId: id,
      displayName: displayName.isNotEmpty ? displayName : trimmed,
      rawKey: trimmed,
      phone: phone,
      scope: scope,
      profileBase64: profile,
    );
  }

  String? _usernameFromIdKey(String key, SharedPreferences prefs) {
    if (key.endsWith('_growth_user_id')) {
      return key.substring(0, key.length - '_growth_user_id'.length);
    }
    if (key.endsWith('_global_user_id')) {
      return key.substring(0, key.length - '_global_user_id'.length);
    }
    if (key.endsWith('_user_id')) {
      final username = key.substring(0, key.length - '_user_id'.length);
      final value = prefs.getString(key) ?? '';
      if (_looksGlobalId(value) || _looksGrowthId(value)) {
        return username;
      }
    }
    return null;
  }

  bool _looksLikePhoneKey(String key) {
    final lower = key.toLowerCase();
    return lower.endsWith('_phone') || lower.endsWith('_global_phone');
  }

  String? _usernameFromPhoneKey(String key) {
    if (key.endsWith('_global_phone')) {
      return key.substring(0, key.length - '_global_phone'.length);
    }
    if (key.endsWith('_phone')) {
      return key.substring(0, key.length - '_phone'.length);
    }
    return null;
  }

  String _readPhone(String username, SharedPreferences prefs) {
    final candidates = <String?>[
      prefs.getString('${username}_phone'),
      prefs.getString('${username.toLowerCase()}_phone'),
      prefs.getString('${username}_global_phone'),
      prefs.getString('${username.toLowerCase()}_global_phone'),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return '';
  }

  String _deriveDisplayName(String username, SharedPreferences prefs) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final candidates = <String?>[
      prefs.getString('${trimmed}_global_display_name'),
      prefs.getString('${trimmed}_display_name'),
      prefs.getString('${trimmed}_global_name'),
      prefs.getString('${trimmed}_name'),
      prefs.getString('${trimmed}_profile_name'),
      prefs.getString('${trimmed}_full_name'),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return trimmed;
  }

  String? _readGrowthUserId(String username, SharedPreferences prefs) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final lower = trimmed.toLowerCase();
    final keys = <String>{
      '${trimmed}_growth_user_id',
      '${lower}_growth_user_id',
      '${trimmed}_user_id',
      '${lower}_user_id',
    };

    for (final key in keys) {
      final value = prefs.getString(key);
      if (value == null) {
        continue;
      }
      final normalized = value.trim();
      if (normalized.isEmpty || _looksGlobalId(normalized)) {
        continue;
      }
      return normalized;
    }

    return null;
  }

  String? _readGlobalUserId(String username, SharedPreferences prefs) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final lower = trimmed.toLowerCase();
    final candidates = <String?>[
      prefs.getString('${trimmed}_global_user_id'),
      prefs.getString('${lower}_global_user_id'),
      prefs.getString('${trimmed}_global_userId'),
      prefs.getString('${lower}_global_userId'),
      prefs.getString('Global_user_id'),
      prefs.getString('global_user_id'),
      prefs.getString('${trimmed}_user_id'),
      prefs.getString('${lower}_user_id'),
    ];

    String? fallback;
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final normalized = candidate.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (_looksGlobalId(normalized)) {
        return normalized;
      }
      fallback ??= normalized;
    }

    if (fallback != null && !_looksGrowthId(fallback)) {
      return fallback;
    }

    return null;
  }

  String? _resolveProfilePictureBase64(String username, SharedPreferences prefs) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final candidates = <String?>[
      prefs.getString('${trimmed}_global_profile_picture'),
      prefs.getString('${trimmed}_profile_picture'),
      prefs.getString('${trimmed}_profileImage'),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }

    return null;
  }

  String _normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  bool _looksGlobalId(String value) => value.toUpperCase().startsWith('GI-');
  bool _looksGrowthId(String value) => value.toUpperCase().startsWith('GR-');
}
