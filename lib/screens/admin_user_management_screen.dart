import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/glass_widgets.dart';
import '../services/user_account_service.dart';
import 'login_screen.dart';

class AdminUserManagementScreen extends StatefulWidget {
  final String username;
  final String? displayName;
  final String? userId;
  final String? profileBase64;
  final String? rawAccountKey;
  final String? accountScope;
  
  const AdminUserManagementScreen({
    super.key,
    required this.username,
    this.displayName,
    this.userId,
    this.profileBase64,
    this.rawAccountKey,
    this.accountScope,
  });

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  String get _accountScope => (widget.accountScope ?? 'growth').toLowerCase();
  bool get _isGlobalAccount => _accountScope == 'global';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Helper to check if this user is the currently logged-in user
  Future<bool> _isCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isGlobalAccount) {
      final storedGlobal =
          prefs.getString('global_user_name') ??
          prefs.getString('Global_user_name');
      if (storedGlobal == null) {
        return false;
      }
      final trimmedStored = storedGlobal.trim();
      if (trimmedStored.isEmpty) {
        return false;
      }

      final candidates = <String>{
        widget.username.trim(),
        (widget.displayName ?? '').trim(),
      };

      final rawKey = widget.rawAccountKey?.trim();
      if (rawKey != null && rawKey.isNotEmpty) {
        candidates.add(rawKey);
        final lower = rawKey.toLowerCase();
        if (lower.endsWith('_global')) {
          final base = rawKey.substring(0, rawKey.length - '_global'.length).trim();
          if (base.isNotEmpty) {
            candidates.add(base);
          }
        }
      }

      return candidates.any((value) => value.isNotEmpty && value.trim() == trimmedStored);
    }

    final currentUserName = prefs.getString('growth_user_name');
    if (currentUserName == null) {
      return false;
    }
    return currentUserName.trim() == widget.username.trim();
  }
  
  // Helper to sync user-specific data to global keys if current user
  Future<void> _syncToGlobalIfCurrentUser(String key, dynamic value) async {
    if (!await _isCurrentUser()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_isGlobalAccount) {
      final suffix = key.replaceFirst(RegExp(r'^(global|Global|GLOBAL)_'), '');
      final targets = <String>{
        'global_$suffix',
        'Global_$suffix',
        'GLOBAL_$suffix',
      };
      for (final target in targets) {
        await _writeValueForKey(prefs, target, value);
      }
      return;
    }

    await _writeValueForKey(prefs, key, value);
  }

  List<String> _nameVariants() {
    final variants = <String>{};

    void addVariant(String? value) {
      if (value == null) {
        return;
      }
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return;
      }
      variants.add(trimmed);

      final lower = trimmed.toLowerCase();
      variants.add(lower);

      if (trimmed.endsWith('_global')) {
        final base = trimmed.substring(0, trimmed.length - '_global'.length).trim();
        if (base.isNotEmpty) {
          addVariant(base);
        }
      }
    }

    addVariant(widget.username);
    addVariant(widget.displayName);
    addVariant(widget.rawAccountKey);
    if (_userData.isNotEmpty) {
      addVariant(_userData['username'] as String?);
      addVariant(_userData['displayName'] as String?);
      addVariant(_userData['rawKey'] as String?);
    }

    return variants.toList();
  }

  String _normalizeBaseName(String? raw) {
    if (raw == null) {
      return '';
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('_global')) {
      return trimmed.substring(0, trimmed.length - '_global'.length).trim();
    }
    return trimmed;
  }

  Set<String> _scopedBaseNames() {
    final bases = <String>{};
    for (final variant in _nameVariants()) {
      final normalized = _normalizeBaseName(variant);
      if (normalized.isEmpty) {
        continue;
      }
      bases.add(normalized);
      bases.add(normalized.toLowerCase());
    }
    return bases;
  }

  List<String> _scopedKeys(
    String suffix, {
    required bool includeLegacyFallback,
  }) {
    final keys = <String>{};
    final trimmedSuffix = suffix.trim();
    if (trimmedSuffix.isEmpty) {
      return const <String>[];
    }

    Iterable<String> globalKeyForms(String base) sync* {
      yield '${base}_global_$trimmedSuffix';
      yield '${base}_Global_$trimmedSuffix';
      yield '${base}_GLOBAL_$trimmedSuffix';
    }

    for (final base in _scopedBaseNames()) {
      final trimmed = base.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (_isGlobalAccount) {
        keys.addAll(globalKeyForms(trimmed));
        if (includeLegacyFallback) {
          keys.add('${trimmed}_$trimmedSuffix');
        }
      } else {
        keys.add('${trimmed}_$trimmedSuffix');
        if (includeLegacyFallback) {
          keys.addAll(globalKeyForms(trimmed));
        }
      }
    }
    return keys.toList();
  }

  bool get _hasLinkedAuthAccount {
    final authId = _userData['authUserId'] as String?;
    return authId != null && authId.trim().isNotEmpty;
  }

  Future<void> _writeValueForKey(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _setValueForVariants(
    SharedPreferences prefs,
    String suffix,
    dynamic value,
  ) async {
    final keys = _scopedKeys(
      suffix,
      includeLegacyFallback: false,
    );
    for (final key in keys) {
      await _writeValueForKey(prefs, key, value);
    }
  }

  Future<void> _removeValueForVariants(
    SharedPreferences prefs,
    String suffix, {
    bool? includeLegacyFallback,
  }) async {
    final keys = _scopedKeys(
      suffix,
      includeLegacyFallback: includeLegacyFallback ?? _isGlobalAccount,
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  String _deriveDisplayName(SharedPreferences prefs) {
    final forwarded = widget.displayName?.trim();
    if (forwarded != null && forwarded.isNotEmpty) {
      return forwarded;
    }

    final raw = widget.username.trim();
    if (raw.isEmpty) {
      return raw;
    }

    final lower = raw.toLowerCase();
    if (lower == 'global') {
      final stored = prefs.getString('global_user_name') ??
          prefs.getString('Global_user_name');
      if (stored != null && stored.trim().isNotEmpty) {
        return stored.trim();
      }
    }

    if (lower.endsWith('_global')) {
      final base = raw.substring(0, raw.length - '_global'.length).trim();
      if (base.isNotEmpty) {
        return base;
      }
    }

    final candidates = <String?>[
      prefs.getString('${raw}_global_display_name'),
      prefs.getString('${raw}_display_name'),
      prefs.getString('${raw}_global_name'),
      prefs.getString('${raw}_name'),
      prefs.getString('${raw}_profile_name'),
      prefs.getString('${raw}_full_name'),
      prefs.getString('${raw}_global_user_name'),
      prefs.getString('${raw}_user_name'),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return raw;
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final isCurrentUser = await _isCurrentUser();
    final displayName = _deriveDisplayName(prefs);

    double? readDouble(String suffix) {
      final keys = _scopedKeys(
        suffix,
        includeLegacyFallback: false,
      );
      for (final key in keys) {
        final value = prefs.getDouble(key);
        if (value != null) {
          return value;
        }
        final intValue = prefs.getInt(key);
        if (intValue != null) {
          return intValue.toDouble();
        }
        final stringValue = prefs.getString(key);
        if (stringValue != null && stringValue.trim().isNotEmpty) {
          final parsed = double.tryParse(stringValue.trim());
          if (parsed != null) {
            return parsed;
          }
        }
      }
      return null;
    }

    int? readInt(String suffix) {
      final keys = _scopedKeys(
        suffix,
        includeLegacyFallback: false,
      );
      for (final key in keys) {
        final value = prefs.getInt(key);
        if (value != null) {
          return value;
        }
        final doubleValue = prefs.getDouble(key);
        if (doubleValue != null) {
          return doubleValue.toInt();
        }
        final stringValue = prefs.getString(key);
        if (stringValue != null && stringValue.trim().isNotEmpty) {
          final parsed = int.tryParse(stringValue.trim());
          if (parsed != null) {
            return parsed;
          }
        }
      }
      return null;
    }

    bool? readBool(String suffix) {
      final keys = _scopedKeys(
        suffix,
        includeLegacyFallback: false,
      );
      for (final key in keys) {
        final value = prefs.getBool(key);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    String? readString(String suffix) {
      final keys = _scopedKeys(
        suffix,
        includeLegacyFallback: false,
      );
      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    // Load user data - use scoped keys first, with scoped fallbacks for the active program
    final balance = readDouble('balance') ??
        (isCurrentUser
            ? (_isGlobalAccount
                ? prefs.getDouble('global_total_balance') ??
                    prefs.getDouble('Global_total_balance') ??
                    prefs.getDouble('GLOBAL_total_balance') ??
                    0.0
                : prefs.getDouble('total_balance') ?? 0.0)
            : 0.0);
    final activeDays = readInt('active_days') ??
        (isCurrentUser
            ? (_isGlobalAccount
                ? prefs.getInt('global_active_days') ??
                    prefs.getInt('Global_active_days') ??
                    prefs.getInt('GLOBAL_active_days') ??
                    0
                : prefs.getInt('active_days') ?? 0)
            : 0);
    final currentInvestment = readDouble('approved_investment') ??
        (isCurrentUser
            ? (_isGlobalAccount
                ? prefs.getDouble('global_approved_investment') ??
                    prefs.getDouble('Global_approved_investment') ??
                    prefs.getDouble('GLOBAL_approved_investment') ??
                    0.0
                : prefs.getDouble('approved_investment') ?? 0.0)
            : 0.0);
    final pendingInvestment = readDouble('pending_investment_amount') ??
        (isCurrentUser
            ? (_isGlobalAccount
                ? prefs.getDouble('global_pending_investment_amount') ??
                    prefs.getDouble('Global_pending_investment_amount') ??
                    prefs.getDouble('GLOBAL_pending_investment_amount') ??
                    0.0
                : prefs.getDouble('pending_investment_amount') ?? 0.0)
            : 0.0);
    final isVerified = readBool('verified') ?? false;
    final isDisabled = readBool('disabled') ?? false;
    final isSuspended = readBool('suspended') ?? false;

    // Get user ID and phone
    final providedUserId = widget.userId?.trim();
    String? detectedId = providedUserId;
    detectedId ??= readString('user_id');
    detectedId ??= readString('userId');
    detectedId ??= readString('id');
    final userID = detectedId ??
        (isCurrentUser
            ? (_isGlobalAccount
                ? prefs.getString('global_user_id') ??
          prefs.getString('Global_user_id') ??
          prefs.getString('GLOBAL_user_id') ??
                    'N/A'
                : prefs.getString('growth_user_id') ?? 'N/A')
            : 'N/A');

    String? detectedPhone = readString('phone');
    detectedPhone ??= readString('user_phone');
    detectedPhone ??= readString('phone_number');
    final phone = detectedPhone ??
        (isCurrentUser
            ? (_isGlobalAccount
                ? prefs.getString('global_user_phone') ??
          prefs.getString('Global_user_phone') ??
          prefs.getString('GLOBAL_user_phone') ??
                    'N/A'
                : prefs.getString('growth_user_phone') ?? 'N/A')
            : 'N/A');

    String? profileBase64 = widget.profileBase64;
    profileBase64 ??= readString('profile_picture');
    if ((profileBase64 == null || profileBase64.isEmpty) && isCurrentUser) {
      if (_isGlobalAccount) {
        profileBase64 = prefs.getString('global_profile_picture') ??
            prefs.getString('Global_profile_picture') ??
            prefs.getString('GLOBAL_profile_picture');
      } else {
        profileBase64 = prefs.getString('profile_picture') ??
            prefs.getString('growth_profile_picture');
      }
    }

    UserAccount? matchedAuthAccount;
    try {
      final authUsers = await UserAccountService.instance.getAllUsers();
      final trimmedAuthId = widget.userId?.trim() ?? '';

      if (trimmedAuthId.isNotEmpty) {
        for (final account in authUsers) {
          if (account.id == trimmedAuthId) {
            matchedAuthAccount = account;
            break;
          }
        }
      }

      if (matchedAuthAccount == null) {
        final targetNames = <String>{
          widget.username.trim().toLowerCase(),
          (widget.displayName ?? '').trim().toLowerCase(),
          displayName.trim().toLowerCase(),
        }..removeWhere((value) => value.isEmpty);

        for (final account in authUsers) {
          final accountName = account.name.trim().toLowerCase();
          if (targetNames.contains(accountName)) {
            matchedAuthAccount = account;
            break;
          }
        }
      }
    } catch (_) {
      matchedAuthAccount = null;
    }

    Uint8List? profileBytes;
    if (profileBase64 != null && profileBase64.isNotEmpty) {
      try {
        profileBytes = base64Decode(profileBase64);
      } catch (_) {
        profileBytes = null;
        profileBase64 = null;
      }
    }

    setState(() {
      _userData = {
        'balance': balance,
        'activeDays': activeDays,
        'currentInvestment': currentInvestment,
        'pendingInvestment': pendingInvestment,
        'isVerified': isVerified,
        'isDisabled': isDisabled,
        'isSuspended': isSuspended,
        'userID': userID,
        'phone': phone,
        'username': widget.username,
        'rawKey': widget.rawAccountKey ?? widget.username,
        'displayName': displayName,
        'profileBase64': profileBase64 ?? '',
        'profilePicture': profileBytes,
        'scope': _accountScope,
        'authUserId': matchedAuthAccount?.id ?? '',
        'authUserEmail': matchedAuthAccount?.email ?? '',
        'authUserName': matchedAuthAccount?.name ?? '',
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolvedDisplayName =
        (_userData['displayName'] as String?) ??
            widget.displayName ??
            widget.username;
  final titleText = _isGlobalAccount
    ? 'Manage Global: $resolvedDisplayName'
    : 'Manage Growth: $resolvedDisplayName';
    return Scaffold(
      backgroundColor: const Color(0xFF0A2472),
      appBar: AppBar(
    title:
      Text(titleText, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A2472),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh user data',
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadUserData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Status Card
                  _buildUserStatusCard(),
                  const SizedBox(height: 20),
                  // Account Actions
                  _buildAccountActions(),
                  const SizedBox(height: 20),
                  // Balance Management
                  _buildBalanceManagement(),
                  const SizedBox(height: 20),
                  // Investment Management
                  _buildInvestmentManagement(),
                ],
              ),
            ),
    );
  }

  Widget _buildUserStatusCard() {
    final isVerified = _userData['isVerified'] as bool;
    final isDisabled = _userData['isDisabled'] as bool;
    final isSuspended = _userData['isSuspended'] as bool;
    final balance = _userData['balance'] as double;
    final activeDays = _userData['activeDays'] as int;
    final currentInvestment = _userData['currentInvestment'] as double;
  final pendingInvestment = _userData['pendingInvestment'] as double;
    final userID = _userData['userID'] as String;
    final phone = _userData['phone'] as String;
    final authEmail = (_userData['authUserEmail'] as String?) ?? '';
  final profileBytes = _userData['profilePicture'] as Uint8List?;
    final displayName = (_userData['displayName'] as String?) ??
        widget.displayName ??
        widget.username;
    final dailyEarnings = currentInvestment * 0.0286; // 2.86% daily

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current User Indicator
          FutureBuilder<bool>(
            future: _isCurrentUser(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == true) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text(
                        '🟢 Currently Logged In - Changes Apply in Real-Time',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.withAlpha((0.3 * 255).round()),
                backgroundImage:
                    profileBytes != null ? MemoryImage(profileBytes) : null,
                child: profileBytes == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : widget.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $userID',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                        fontSize: 12,
                      ),
                    ),
                    if (phone != 'N/A')
                      Text(
                        phone,
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.6 * 255).round()),
                          fontSize: 12,
                        ),
                      ),
                    if (authEmail.isNotEmpty)
                      Text(
                        authEmail,
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.6 * 255).round()),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('Verified', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        if (isSuspended)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pause_circle, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('Suspended', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        if (isDisabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.block, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('Disabled', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          // Financial Overview - 4 cards in 2x2 grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Balance', '₦₲${balance.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatItem('Active Days', '$activeDays', Icons.calendar_today, Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Current Investment', '\$${currentInvestment.toStringAsFixed(0)}', Icons.trending_up, Colors.purple),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatItem('Daily Earnings', '\$${dailyEarnings.toStringAsFixed(2)}', Icons.attach_money, Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingInvestment > 0)
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Pending Investment', '\$${pendingInvestment.toStringAsFixed(0)}', Icons.pending, Colors.orange),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.08 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withAlpha((0.2 * 255).round())),
              ),
              child: const Text(
                'No pending investments on record',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions() {
    final isVerified = _userData['isVerified'] as bool;
    final isDisabled = _userData['isDisabled'] as bool;
    final isSuspended = _userData['isSuspended'] as bool;
    final hasAuthAccount = _hasLinkedAuthAccount;
    final linkedEmail = (_userData['authUserEmail'] as String?) ?? '';
    final linkedName = (_userData['authUserName'] as String?) ?? '';

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                'Account Actions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 2x2 Grid Layout for Action Buttons
          Column(
            children: [
              // Top Row - 2 buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: isVerified ? 'Unverify Account' : 'Verify Account',
                      icon: Icons.verified_user,
                      color: Colors.blue,
                      onPressed: () => _toggleVerification(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      label: isSuspended ? 'Unsuspend Account' : 'Suspend Account',
                      icon: Icons.pause_circle,
                      color: Colors.orange,
                      onPressed: () => _toggleSuspension(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Bottom Row - 2 buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: isDisabled ? 'Enable Account' : 'Disable Account',
                      icon: Icons.block,
                      color: Colors.red,
                      onPressed: () => _toggleDisable(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Reset Investment',
                      icon: Icons.restart_alt,
                      color: Colors.purple,
                      onPressed: () => _resetInvestment(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Set Login Password',
                      icon: Icons.password,
                      color: Colors.teal,
                      onPressed:
                          hasAuthAccount ? _showAdminPasswordResetDialog : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Force Logout',
                      icon: Icons.logout,
                      color: Colors.redAccent,
                      onPressed: hasAuthAccount ? _forceLogoutUser : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (hasAuthAccount)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Linked login account: '
                '${linkedEmail.isNotEmpty ? linkedEmail : linkedName}',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.6 * 255).round()),
                  fontSize: 12,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'No login account detected for this profile. Password and logout tools are disabled.',
                style: TextStyle(
                  color: Colors.orange.withAlpha((0.9 * 255).round()),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled
            ? color.withAlpha((0.25 * 255).round())
            : color.withAlpha((0.12 * 255).round()),
        foregroundColor: isEnabled ? Colors.white : Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildBalanceManagement() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.green),
              SizedBox(width: 12),
              Text(
                'Balance Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Add Money',
                  icon: Icons.add_circle,
                  color: Colors.green,
                  onPressed: () => _adjustBalance(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'Remove Money',
                  icon: Icons.remove_circle,
                  color: Colors.red,
                  onPressed: () => _adjustBalance(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Reset Clock-In',
                  icon: Icons.refresh,
                  color: Colors.cyan,
                  onPressed: () => _resetClockIn(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'Add Active Day',
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                  onPressed: () => _addActiveDay(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Clear All Global Data',
            icon: Icons.delete_sweep,
            color: Colors.red.shade800,
            onPressed: () => _clearAllData(),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentManagement() {
    final currentInvestment = _userData['currentInvestment'] as double;
    final pendingInvestment = _userData['pendingInvestment'] as double;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Colors.purple),
              SizedBox(width: 12),
              Text(
                'Investment Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withAlpha((0.3 * 255).round())),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Investment:', style: TextStyle(color: Colors.white70)),
                    Text(
                      '\$${currentInvestment.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (currentInvestment <= 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No active investment assigned',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                if (pendingInvestment > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pending Investment:', style: TextStyle(color: Colors.orange)),
                      Text(
                        '\$${pendingInvestment.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ]
                else ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No pending investment requests',
                      style: TextStyle(
                        color: Colors.orange.withAlpha((0.7 * 255).round()),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            label: 'Reset & Unlock All Investment Plans',
            icon: Icons.lock_open,
            color: Colors.purple,
            onPressed: () => _resetInvestment(),
          ),
        ],
      ),
    );
  }

  // Action Methods

  Future<void> _toggleVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final currentValue = _userData['isVerified'] as bool;
    final newValue = !currentValue;
    
    // Save to user-specific key
    await _setValueForVariants(prefs, 'verified', newValue);
    
    await _syncToGlobalIfCurrentUser('user_verified', newValue);
    
    setState(() {
      _userData['isVerified'] = newValue;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newValue ? '✅ Account verified successfully' : '❌ Account unverified'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleSuspension() async {
    final prefs = await SharedPreferences.getInstance();
    final currentValue = _userData['isSuspended'] as bool;
    final newValue = !currentValue;
    
    // Save to user-specific key
    await _setValueForVariants(prefs, 'suspended', newValue);

    await _syncToGlobalIfCurrentUser('user_suspended', newValue);
    
    setState(() {
      _userData['isSuspended'] = newValue;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newValue ? '⏸️ Account suspended' : '▶️ Account unsuspended'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleDisable() async {
    final prefs = await SharedPreferences.getInstance();
    final currentValue = _userData['isDisabled'] as bool;
    final newValue = !currentValue;
    
    // Save to user-specific key
    await _setValueForVariants(prefs, 'disabled', newValue);

    await _syncToGlobalIfCurrentUser('user_disabled', newValue);
    
    setState(() {
      _userData['isDisabled'] = newValue;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newValue ? '🚫 Account disabled' : '✅ Account enabled'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _adjustBalance(bool isAdding) async {
    final controller = TextEditingController();
    
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAdding ? 'Add Money' : 'Remove Money',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter amount',
            hintStyle: TextStyle(color: Colors.white.withAlpha((0.5 * 255).round())),
            prefixText: '₦₲ ',
            prefixStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            filled: true,
            fillColor: Colors.white.withAlpha((0.1 * 255).round()),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(context, value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: isAdding ? Colors.green : Colors.red,
            ),
            child: Text(isAdding ? 'Add' : 'Remove'),
          ),
        ],
      ),
    );

    if (amount != null && amount > 0) {
      final prefs = await SharedPreferences.getInstance();
      final currentBalance = _userData['balance'] as double;
      final newBalance = isAdding ? currentBalance + amount : currentBalance - amount;
      
      if (newBalance < 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot remove more than current balance'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      await _setValueForVariants(prefs, 'balance', newBalance);
      
      // Sync to global if this is the current user
      await _syncToGlobalIfCurrentUser('total_balance', newBalance);
      
      setState(() {
        _userData['balance'] = newBalance;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdding 
              ? 'Added ₦₲${amount.toStringAsFixed(2)} successfully' 
              : 'Removed ₦₲${amount.toStringAsFixed(2)} successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _resetClockIn() async {
    final confirmed = await _showConfirmDialog(
      'Reset Clock-In',
      'This will reset the clock-in status for this user. Continue?',
    );
    
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove user-specific clock-in keys
      await _removeValueForVariants(prefs, 'last_clock_in');
      await _removeValueForVariants(prefs, 'clock_in_start_time');
      
      // Set flag to indicate this is an admin reset - no penalty should be applied
      await _setValueForVariants(prefs, 'admin_clock_reset', true);
      
      // Sync to global if this is the current user
      if (await _isCurrentUser()) {
        await prefs.remove('clock_in_start');
        await prefs.remove('last_clock_in_date');
        await prefs.remove('global_clock_in_start');
        await prefs.remove('global_last_clock_in_date');
        await prefs.setBool('admin_clock_reset', true);
        await prefs.setBool('global_admin_clock_reset', true);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Clock-in reset successfully (no penalty will be applied)'),
          backgroundColor: Colors.cyan,
        ),
      );
    }
  }

  Future<void> _addActiveDay() async {
    final prefs = await SharedPreferences.getInstance();
    final currentDays = _userData['activeDays'] as int;
    await _setValueForVariants(prefs, 'active_days', currentDays + 1);
    
    // Sync to global if this is the current user
    await _syncToGlobalIfCurrentUser('active_days', currentDays + 1);
    
    setState(() {
      _userData['activeDays'] = currentDays + 1;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added 1 active day successfully'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _resetInvestment() async {
    final confirmed = await _showConfirmDialog(
      'Reset Investment',
      'This will reset and unlock all investment plans for this user. Continue?',
    );
    
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove user-specific investment keys
      // Strip join-specific data without touching the sibling program's keys.
      await _removeValueForVariants(
        prefs,
        'approved_investment',
        includeLegacyFallback: false,
      );
      await _removeValueForVariants(
        prefs,
        'pending_investment_amount',
        includeLegacyFallback: false,
      );
      await _removeValueForVariants(
        prefs,
        'pending_investment',
        includeLegacyFallback: false,
      );
      await _removeValueForVariants(
        prefs,
        'pending_upload_amount',
        includeLegacyFallback: false,
      );
      await _removeValueForVariants(
        prefs,
        'pending_upload_timestamp',
        includeLegacyFallback: false,
      );
      
      // Sync to global if this is the current user
      if (await _isCurrentUser()) {
        if (_isGlobalAccount) {
          // Clear the active Global join entry while preserving Growth balances.
          const variants = ['global', 'Global', 'GLOBAL'];
          for (final prefix in variants) {
            await prefs.remove('${prefix}_approved_investment');
            await prefs.remove('${prefix}_pending_investment_amount');
            await prefs.remove('${prefix}_pending_upload_amount');
            await prefs.remove('${prefix}_pending_upload_timestamp');
          }
        } else {
          // Growth join data lives on the base keys.
          await prefs.remove('approved_investment');
          await prefs.remove('pending_investment_amount');
          await prefs.remove('pending_upload_amount');
          await prefs.remove('pending_upload_timestamp');
        }
      }
      
      setState(() {
        _userData['currentInvestment'] = 0.0;
        _userData['pendingInvestment'] = 0.0;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Investment reset successfully - All plans unlocked'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  Future<void> _showAdminPasswordResetDialog() async {
    final authUserId = (_userData['authUserId'] as String?)?.trim();
    if (authUserId == null || authUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No linked login account found for this user.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final authEmail = (_userData['authUserEmail'] as String?) ?? '';
    final authName = (_userData['authUserName'] as String?) ?? widget.username;
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isProcessing = false;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0D4D3D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Set Login Password',
                style: TextStyle(color: Colors.white),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (authEmail.isNotEmpty || authName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          authEmail.isNotEmpty
                              ? 'Account: $authEmail'
                              : 'Account: $authName',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setDialogState(() => obscureNew = !obscureNew);
                          },
                        ),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Enter a new password';
                        }
                        if (trimmed.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setDialogState(() => obscureConfirm = !obscureConfirm);
                          },
                        ),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Confirm the password';
                        }
                        if (trimmed != newPasswordController.text.trim()) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            isProcessing = true;
                            errorMessage = null;
                          });

                          final success = await UserAccountService.instance.adminUpdatePassword(
                            userId: authUserId,
                            newPassword: newPasswordController.text.trim(),
                          );

                          if (!dialogContext.mounted) {
                            return;
                          }

                          if (success) {
                            final navigator = Navigator.of(dialogContext);
                            if (navigator.canPop()) {
                              navigator.pop(true);
                            }
                            return;
                          }

                          setDialogState(() {
                            isProcessing = false;
                            errorMessage = 'Unable to update password. Please try again.';
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    newPasswordController.dispose();
    confirmController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login password updated successfully.'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Future<void> _forceLogoutUser() async {
    final authUserId = (_userData['authUserId'] as String?)?.trim();
    if (authUserId == null || authUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No linked login account found for this user.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final authName = (_userData['authUserName'] as String?) ?? widget.username;
    final confirmed = await _showConfirmDialog(
      'Force Logout',
      'This will sign the user out and send them back to the login page. Continue?',
    );

    if (confirmed != true) {
      return;
    }

    final userService = UserAccountService.instance;
    final isAuthCurrent = userService.currentUser?.id == authUserId;
    final success = await userService.adminForceLogout(authUserId);

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign the user out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (isAuthCurrent) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signed out ${authName.isNotEmpty ? authName : 'the user'} successfully.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    if (!_isGlobalAccount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Global reset tools are only available inside a Global Income profile.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await _showConfirmDialog(
      'Reset Global Income Settings',
      'This clears pending approvals, locks, and verification flags for this Global Income user. Balances, earnings, and all Growth program data remain untouched. Continue?',
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    Future<void> removeScopedSuffix(String suffix) async {
      final keys = _scopedKeys(
        suffix,
        includeLegacyFallback: false,
      );
      for (final key in keys) {
        final normalized = key.toLowerCase();
        if (normalized.contains('_global_')) {
          await prefs.remove(key);
        }
      }
    }

    const scopedSuffixes = <String>[
      'approved_investment',
      'pending_investment',
      'pending_investment_amount',
      'pending_upload',
      'pending_upload_amount',
      'pending_upload_timestamp',
      'clock_in_start_time',
      'last_clock_in',
      'last_clock_in_date',
      'admin_clock_reset',
      'verified',
      'disabled',
      'suspended',
      'user_verified',
      'user_disabled',
      'user_suspended',
      'has_redeemed_referral',
      'redeemed_from_code',
      'referred_by',
    ];

    for (final suffix in scopedSuffixes) {
      await removeScopedSuffix(suffix);
    }

    Future<void> removeGlobalAggregate(String suffix) async {
      const variants = ['global', 'Global', 'GLOBAL'];
      for (final prefix in variants) {
        final key = '${prefix}_$suffix';
        final normalized = key.toLowerCase();
        if (normalized.contains('balance') || normalized.contains('earning')) {
          continue;
        }
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
        }
      }
    }

    if (await _isCurrentUser()) {
      const directGlobalSuffixes = <String>[
        'approved_investment',
        'pending_investment',
        'pending_investment_amount',
        'pending_upload',
        'pending_upload_amount',
        'pending_upload_timestamp',
        'clock_in_start',
        'last_clock_in_date',
        'admin_clock_reset',
        'user_verified',
        'user_disabled',
        'user_suspended',
      ];

      for (final suffix in directGlobalSuffixes) {
        await removeGlobalAggregate(suffix);
      }
    }

    await _loadUserData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Global Income settings cleared. Financial records remain intact.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
