import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_family_tree_user_screen.dart';
import 'admin_requests_screen.dart';

class AdminFamilyTreeControlScreen extends StatefulWidget {
  const AdminFamilyTreeControlScreen({super.key});

  @override
  State<AdminFamilyTreeControlScreen> createState() =>
      _AdminFamilyTreeControlScreenState();
}

class _AdminFamilyTreeControlScreenState
    extends State<AdminFamilyTreeControlScreen> {
  List<TimeOfDay> _sessionTimes = const [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 11, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
  ];

  int _sessionDurationMinutes = 40;
  int _sessionIntervalHours = 3;
  bool _enabledWeekdays = true;
  bool _enabledWeekends = false;

  bool _systemEnabled = true;
  bool _maintenanceMode = false;
  bool _autoResetDaily = false;
  bool _enableNotifications = true;

  int _pendingRequests = 0;
  double _totalDeposits = 0.0;
  double _totalWithdrawals = 0.0;

  int _totalUsers = 0;
  double _totalEarnings = 0.0;
  int _activeSessions = 0;

  String _selectedPaymentMethod = 'cashapp';
  late final TextEditingController _cashAppTagController;
  late final TextEditingController _cashAppLinkController;
  late final TextEditingController _cryptoAddressController;
  late final TextEditingController _cryptoWalletLabelController;
  late final TextEditingController _cryptoWalletNoteController;

  @override
  void initState() {
    super.initState();
    _cashAppTagController = TextEditingController(text: r'$NGMYPay');
    _cashAppLinkController = TextEditingController();
    _cryptoAddressController = TextEditingController();
    _cryptoWalletLabelController = TextEditingController();
    _cryptoWalletNoteController = TextEditingController();
    _loadSettings();
  }

  @override
  void deactivate() {
    _saveSettings();
    super.deactivate();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final storedDuration =
        prefs.getInt('family_tree_admin_session_duration') ?? 40;
    final storedInterval =
        prefs.getInt('family_tree_admin_session_interval') ?? 3;

    _sessionDurationMinutes = storedDuration.clamp(40, 120);
    _sessionIntervalHours = storedInterval.clamp(1, 6);

    if (_sessionDurationMinutes != storedDuration) {
      await prefs.setInt(
          'family_tree_admin_session_duration', _sessionDurationMinutes);
    }
    if (_sessionIntervalHours != storedInterval) {
      await prefs.setInt(
          'family_tree_admin_session_interval', _sessionIntervalHours);
    }
    _enabledWeekdays =
        prefs.getBool('family_tree_admin_enabled_weekdays') ?? true;
    _enabledWeekends =
        prefs.getBool('family_tree_admin_enabled_weekends') ?? false;

    _systemEnabled = prefs.getBool('family_tree_admin_system_enabled') ?? true;
    _maintenanceMode =
        prefs.getBool('family_tree_admin_maintenance_mode') ?? false;
    _autoResetDaily =
        prefs.getBool('family_tree_admin_auto_reset_daily') ?? false;
    _enableNotifications =
        prefs.getBool('family_tree_admin_enable_notifications') ?? true;

    final totalSessions = prefs.getInt('family_tree_total_sessions') ?? 5;
    final loadedTimes = <TimeOfDay>[];
    for (var i = 0; i < totalSessions; i++) {
      final hour = prefs.getInt('family_tree_session_${i}_hour');
      final minute = prefs.getInt('family_tree_session_${i}_minute');
      if (hour != null && minute != null) {
        loadedTimes.add(TimeOfDay(hour: hour, minute: minute));
      }
    }
    if (loadedTimes.length == 5) {
      _sessionTimes = loadedTimes;
    }

    await _loadDepositWithdrawalRequests();
    _totalDeposits = prefs.getDouble('family_tree_total_deposits') ?? 0.0;
    _totalWithdrawals = prefs.getDouble('family_tree_total_withdrawals') ?? 0.0;

    _totalUsers = prefs.getInt('total_family_tree_users') ?? 0;
    _totalEarnings = prefs.getDouble('total_family_tree_earnings') ?? 0.0;
    _activeSessions = prefs.getInt('active_family_tree_sessions') ?? 0;

    _selectedPaymentMethod =
        prefs.getString('family_tree_payment_method') ?? 'cashapp';

    final storedCashAppTag = prefs.getString('family_tree_payment_cashapp_tag');
    if (storedCashAppTag != null) {
      _cashAppTagController.text = storedCashAppTag;
    }

    final storedCashAppLink =
        prefs.getString('family_tree_payment_cashapp_link');
    if (storedCashAppLink != null) {
      _cashAppLinkController.text = storedCashAppLink;
    }

    final storedCryptoAddress =
        prefs.getString('family_tree_payment_crypto_address');
    if (storedCryptoAddress != null) {
      _cryptoAddressController.text = storedCryptoAddress;
    }

    final storedCryptoLabel =
        prefs.getString('family_tree_payment_crypto_label');
    if (storedCryptoLabel != null) {
      _cryptoWalletLabelController.text = storedCryptoLabel;
    }

    final storedCryptoNote = prefs.getString('family_tree_payment_crypto_note');
    if (storedCryptoNote != null) {
      _cryptoWalletNoteController.text = storedCryptoNote;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadDepositWithdrawalRequests() async {
    final prefs = await SharedPreferences.getInstance();

    final depositsJson =
        prefs.getString('family_tree_deposit_requests') ?? '[]';
    final List<dynamic> deposits = json.decode(depositsJson);

    final withdrawalsList =
        prefs.getStringList('family_tree_withdrawal_requests') ?? [];
    final investmentProofsList =
        prefs.getStringList('family_tree_payment_proofs') ?? [];

    var pendingCount = 0;
    var totalDeposits = 0.0;
    var totalWithdrawals = 0.0;

    for (final deposit in deposits) {
      if (deposit['status'] == 'pending') {
        pendingCount++;
      } else if (deposit['status'] == 'approved') {
        totalDeposits += (deposit['amount'] as num).toDouble();
      }
    }

    for (final withdrawalStr in withdrawalsList) {
      final withdrawal = json.decode(withdrawalStr);
      if (withdrawal['status'] == 'pending') {
        pendingCount++;
      } else if (withdrawal['status'] == 'approved') {
        totalWithdrawals += (withdrawal['amount'] as num).toDouble();
      }
    }

    for (final proofStr in investmentProofsList) {
      final proof = json.decode(proofStr);
      if (proof['status'] == 'pending') {
        pendingCount++;
      }
    }

    _pendingRequests = pendingCount;
    _totalDeposits = totalDeposits;
    _totalWithdrawals = totalWithdrawals;
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setInt(
          'family_tree_admin_session_duration', _sessionDurationMinutes);
      await prefs.setInt(
          'family_tree_admin_session_interval', _sessionIntervalHours);
      await prefs.setBool(
          'family_tree_admin_enabled_weekdays', _enabledWeekdays);
      await prefs.setBool(
          'family_tree_admin_enabled_weekends', _enabledWeekends);

      for (var i = 0; i < _sessionTimes.length; i++) {
        await prefs.setInt(
            'family_tree_session_${i}_hour', _sessionTimes[i].hour);
        await prefs.setInt(
            'family_tree_session_${i}_minute', _sessionTimes[i].minute);
      }
      await prefs.setInt('family_tree_total_sessions', _sessionTimes.length);

      await prefs.setBool('family_tree_system_enabled', _systemEnabled);
      await prefs.setBool('family_tree_maintenance_mode', _maintenanceMode);
      await prefs.setBool('family_tree_auto_reset_daily', _autoResetDaily);
      await prefs.setBool(
          'family_tree_notifications_enabled', _enableNotifications);

      await prefs.setBool('family_tree_admin_system_enabled', _systemEnabled);
      await prefs.setBool(
          'family_tree_admin_maintenance_mode', _maintenanceMode);
      await prefs.setBool(
          'family_tree_admin_auto_reset_daily', _autoResetDaily);
      await prefs.setBool('admin_enable_notifications', _enableNotifications);

      await prefs.setString(
          'family_tree_payment_method', _selectedPaymentMethod);
      await prefs.setString(
          'family_tree_payment_cashapp_tag', _cashAppTagController.text.trim());
      await prefs.setString('family_tree_payment_cashapp_link',
          _cashAppLinkController.text.trim());
      await prefs.setString('family_tree_payment_crypto_address',
          _cryptoAddressController.text.trim());
      await prefs.setString('family_tree_payment_crypto_label',
          _cryptoWalletLabelController.text.trim());
      await prefs.setString('family_tree_payment_crypto_note',
          _cryptoWalletNoteController.text.trim());

      _showSuccessMessage('Settings saved and synced with Family Tree menu!');
    } catch (e) {
      _showErrorMessage('Error saving settings: $e');
    }
  }

  @override
  void dispose() {
    _cashAppTagController.dispose();
    _cashAppLinkController.dispose();
    _cryptoAddressController.dispose();
    _cryptoWalletLabelController.dispose();
    _cryptoWalletNoteController.dispose();
    super.dispose();
  }

  Future<void> _resetAllUsers() async {
    final confirmed = await _showConfirmationDialog(
      'Reset All Users',
      'This will reset ALL Family Tree user data including balances, investments, statistics, and clock-in history. This cannot be undone. Continue?',
    );

    if (!confirmed) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      final keys = prefs.getKeys().toList();

      await prefs.setDouble('total_family_tree_earnings', 0.0);
      await prefs.setInt('active_family_tree_sessions', 0);
      await prefs.setInt('total_family_tree_users', 0);
      await prefs.setString('family_tree_deposit_requests', '[]');
      await prefs.setStringList('family_tree_withdrawal_requests', []);
      await prefs.setStringList('family_tree_payment_proofs', []);

      for (final key in keys) {
        final matchesFamilyTree = key.contains('family_tree');
        final hasFamilyTreePrefix = key.startsWith('family_tree_');
        final isUserSpecific = key.contains('_family_tree_');

        final isBalanceKey = key.endsWith('_family_tree_balance');
        final isEarningsKey = key.endsWith('_family_tree_total_earnings');

        final isSessionFlag = key.contains('_completed_clock_ins') ||
            key.contains('_missed_clock_ins');

        final isProfileImageKey = key.contains('_family_tree_profile_image');
        final isPhoneKey = key == 'family_tree_user_phone' ||
            key.endsWith('_family_tree_phone');
        final isDisplayNameKey = key == 'family_tree_user_name';
        final isUserIdKey = key == 'family_tree_user_id' ||
            key.endsWith('_family_tree_user_id');
        final shouldPreserveProfile =
            isProfileImageKey || isPhoneKey || isDisplayNameKey || isUserIdKey;

        if ((matchesFamilyTree || hasFamilyTreePrefix || isUserSpecific) &&
            !isBalanceKey &&
            !isEarningsKey) {
          if (shouldPreserveProfile) {
            continue;
          }
          if (isSessionFlag) {
            await prefs.setStringList(key, const <String>[]);
            continue;
          }
          await prefs.remove(key);
        }
      }

      setState(() {
        _totalUsers = 0;
        _totalEarnings = 0.0;
        _activeSessions = 0;
        _totalDeposits = 0.0;
        _totalWithdrawals = 0.0;
        _pendingRequests = 0;
      });

      await _loadDepositWithdrawalRequests();
      _showSuccessMessage(
          'User data reset. Balances and earned totals preserved.');
    } catch (e) {
      _showErrorMessage('Error resetting user data: $e');
    }
  }

  Future<void> _resetStatistics() async {
    final confirmed = await _showConfirmationDialog(
      'Reset Statistics',
      'This will reset earnings and statistics for Family Tree users. Continue?',
    );

    if (!confirmed) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setDouble('total_family_tree_earnings', 0.0);
      await prefs.setInt('active_family_tree_sessions', 0);

      setState(() {
        _totalEarnings = 0.0;
        _activeSessions = 0;
      });

      _showSuccessMessage('Statistics reset successfully!');
    } catch (e) {
      _showErrorMessage('Error resetting statistics: $e');
    }
  }

  Future<void> _broadcastNotification() async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Broadcast Notification',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter notification message...',
            hintStyle: TextStyle(color: Colors.white60),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (message != null && message.isNotEmpty) {
      _showSuccessMessage('Notification broadcasted to all users!');
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showSuccessMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _openUserIdSearchDialog() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Text('Search member by ID or phone',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter member ID or phone number',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white70),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    final trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }

    final results = await _searchUsers(trimmed);
    if (!mounted) {
      return;
    }

    if (results.isEmpty) {
      _showErrorMessage('No members found matching "$trimmed".');
      return;
    }

    if (results.length == 1) {
      await _openFamilyTreeUser(results.first);
      return;
    }

    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: const Color(0xFF0A2472),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Multiple matches for "$trimmed"',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...results.map((userData) {
              final username = userData['username'] ?? 'Unknown';
              final userId = userData['id'] ?? 'Unknown ID';
              final phone = userData['phone'] ?? '';
              return Card(
                color: const Color(0xFF15395B).withValues(alpha: 0.7),
                child: ListTile(
                  title: Text(username,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ID: $userId',
                          style: const TextStyle(color: Colors.white54)),
                      if (phone.isNotEmpty)
                        Text('Phone: $phone',
                            style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(userData),
                ),
              );
            }),
          ],
        ),
      ),
    );

    if (selected != null) {
      await _openFamilyTreeUser(selected);
    }
  }

  Future<List<Map<String, String>>> _searchUsers(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final members = <String, Map<String, String>>{};

    for (final key in prefs.getKeys()) {
      if (key.endsWith('_family_tree_user_id')) {
        final username = key.replaceAll('_family_tree_user_id', '');
        if (username.isEmpty) {
          continue;
        }
        var userId = prefs.getString(key) ?? '';
        if (userId.isEmpty) {
          userId = await _ensureFamilyTreeUserIdFor(username, prefs);
        }
        if (userId.isEmpty) {
          continue;
        }
        final phone = prefs.getString('${username}_family_tree_phone') ?? '';
        members[username] = {
          'username': username,
          'id': userId,
          'phone': phone,
        };
      }
    }

    final currentUserName = prefs.getString('family_tree_user_name');
    final currentUserId = prefs.getString('family_tree_user_id');
    if (currentUserName != null &&
        currentUserName != 'NGMY User' &&
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        !members.containsKey(currentUserName)) {
      final ensuredId = currentUserId.isEmpty
          ? await _ensureFamilyTreeUserIdFor(currentUserName, prefs)
          : currentUserId;
      final currentPhone = prefs.getString('family_tree_user_phone') ?? '';
      members[currentUserName] = {
        'username': currentUserName,
        'id': ensuredId,
        'phone': currentPhone,
      };
    }

    final lowerQuery = query.toLowerCase();
    final normalizedQuery = _normalizePhone(query);
    final matchesById = <String, Map<String, String>>{};

    for (final data in members.values) {
      final username = data['username'] ?? '';
      final id = data['id'] ?? '';
      final phone = data['phone'] ?? '';
      if (id.isEmpty) {
        continue;
      }

      final normalizedPhone = _normalizePhone(phone);
      final matchesUsername = username.toLowerCase().contains(lowerQuery);
      final matchesId = id.toLowerCase().contains(lowerQuery);
      final matchesPhone = normalizedQuery.isNotEmpty
          ? normalizedPhone.contains(normalizedQuery)
          : phone.toLowerCase().contains(lowerQuery);

      if (matchesUsername || matchesId || matchesPhone) {
        final existing = matchesById[id];
        if (existing == null || _preferUserData(existing, data)) {
          matchesById[id] = Map<String, String>.from(data);
        }
      }
    }

    final results = matchesById.values.toList()
      ..sort((a, b) => (a['username'] ?? '').compareTo(b['username'] ?? ''));
    return results;
  }

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (char == '+' && buffer.isEmpty) {
        buffer.write(char);
      } else if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  bool _preferUserData(
      Map<String, String> current, Map<String, String> candidate) {
    final currentUsername = current['username'] ?? '';
    final candidateUsername = candidate['username'] ?? '';
    final currentPhone = _normalizePhone(current['phone'] ?? '');
    final candidatePhone = _normalizePhone(candidate['phone'] ?? '');

    if (currentUsername == candidateUsername) {
      if (currentPhone.isEmpty && candidatePhone.isNotEmpty) {
        return true;
      }
      return false;
    }

    if (currentUsername == 'NGMY User' && candidateUsername != 'NGMY User') {
      return true;
    }
    if (candidateUsername == 'NGMY User' && currentUsername != 'NGMY User') {
      return false;
    }

    if (currentPhone.isEmpty && candidatePhone.isNotEmpty) {
      return true;
    }
    if (candidatePhone.isEmpty && currentPhone.isNotEmpty) {
      return false;
    }

    if (candidateUsername.length != currentUsername.length) {
      return candidateUsername.length > currentUsername.length;
    }

    return candidateUsername.compareTo(currentUsername) > 0;
  }

  Future<void> _openFamilyTreeUser(Map<String, String> userData) async {
    final username = userData['username'];
    if (username == null || username.isEmpty) {
      _showErrorMessage('Unable to open member details. Username missing.');
      return;
    }
    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminFamilyTreeUserScreen(
          username: username,
          userId: userData['id'],
        ),
      ),
    );
  }

  Future<String> _ensureFamilyTreeUserIdFor(
      String username, SharedPreferences prefs) async {
    if (username.isEmpty) {
      return '';
    }
    var existing = prefs.getString('${username}_family_tree_user_id');
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    existing = _generateAdminFamilyTreeUserId(prefs);
    await prefs.setString('${username}_family_tree_user_id', existing);
    return existing;
  }

  String _generateAdminFamilyTreeUserId(SharedPreferences prefs) {
    final existing = <String>{};
    for (final key in prefs.getKeys()) {
      if (key.endsWith('_family_tree_user_id')) {
        final value = prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          existing.add(value);
        }
      }
    }

    final random = math.Random();
    String candidate;
    do {
      final timestamp =
          DateTime.now().millisecondsSinceEpoch.toRadixString(32).toUpperCase();
      final randomPart = random
          .nextInt(0xFFFFF)
          .toRadixString(32)
          .toUpperCase()
          .padLeft(4, '0');
      candidate = 'FT-$timestamp-$randomPart';
    } while (existing.contains(candidate));

    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Family Tree Admin Controls',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.green),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'System Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.white70),
                          tooltip: 'Search member by ID',
                          onPressed: _openUserIdSearchDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Users',
                            _totalUsers.toString(),
                            Colors.blue,
                            Icons.people,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Total Earnings',
                            '₦${_totalEarnings.toStringAsFixed(2)}',
                            Colors.green,
                            Icons.monetization_on,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Active Sessions',
                            _activeSessions.toString(),
                            Colors.orange,
                            Icons.access_time,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'System Status',
                            _systemEnabled ? 'Online' : 'Offline',
                            _systemEnabled ? Colors.green : Colors.red,
                            Icons.power_settings_new,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Instructions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: [
                        _buildPaymentMethodOption(
                          value: 'cashapp',
                          label: 'CashApp Link',
                          icon: Icons.account_balance_wallet,
                        ),
                        _buildPaymentMethodOption(
                          value: 'crypto',
                          label: 'Crypto Wallet',
                          icon: Icons.currency_bitcoin,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_selectedPaymentMethod == 'cashapp') ...[
                      _buildPaymentTextField(
                        label: 'CashApp Tag',
                        controller: _cashAppTagController,
                        hint: r'Enter handle like $NGMYPay',
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentTextField(
                        label: 'CashApp Link (optional)',
                        controller: _cashAppLinkController,
                        hint: r'e.g. https://cash.app/$NGMYPay',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Members can now tap the CashApp tag in their dialog to launch this link. Keep the handle updated so they land on the right payment screen before uploading receipts.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      _buildPaymentTextField(
                        label: 'Wallet Label / Network (optional)',
                        controller: _cryptoWalletLabelController,
                        hint: 'e.g. BTC (Lightning) or USDC (TRC20)',
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentTextField(
                        label: 'Broker / Notes (optional)',
                        controller: _cryptoWalletNoteController,
                        hint: 'e.g. Use Binance or note required memo',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentTextField(
                        label: 'Crypto Wallet Address',
                        controller: _cryptoAddressController,
                        hint: 'Paste the full wallet address',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tell members which asset and network to use, then have them upload their confirmation after sending the crypto.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Timing Controls',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      'Enable Weekday Sessions',
                      'Allow clock-in during Monday-Friday',
                      _enabledWeekdays,
                      (value) => setState(() => _enabledWeekdays = value),
                      Icons.business_center,
                    ),
                    _buildSwitchTile(
                      'Enable Weekend Sessions',
                      'Allow clock-in during Saturday-Sunday',
                      _enabledWeekends,
                      (value) => setState(() => _enabledWeekends = value),
                      Icons.weekend,
                    ),
                    _buildSliderControl(
                      'Session Duration',
                      _sessionDurationMinutes.toDouble(),
                      40,
                      120,
                      (value) => setState(
                          () => _sessionDurationMinutes = value.round()),
                      '$_sessionDurationMinutes min',
                    ),
                    _buildSliderControl(
                      'Gap Between Sessions',
                      _sessionIntervalHours.toDouble(),
                      1,
                      6,
                      (value) =>
                          setState(() => _sessionIntervalHours = value.round()),
                      '$_sessionIntervalHours hr gap',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clock-In Time Slots',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _sessionTimes.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1F33).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF4FC1E9)
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Slot ${i + 1}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _sessionTimes[i].format(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editSessionTime(i),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Deposit & Withdrawal Requests',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            '$_pendingRequests Pending',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Deposits',
                            '₦${_totalDeposits.toStringAsFixed(2)}',
                            Colors.green,
                            Icons.arrow_downward,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Total Withdrawals',
                            '₦${_totalWithdrawals.toStringAsFixed(2)}',
                            Colors.red,
                            Icons.arrow_upward,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _viewPendingRequests,
                            icon: const Icon(Icons.pending_actions,
                                color: Colors.white),
                            label: const Text('View Pending',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _viewTransactionHistory,
                            icon:
                                const Icon(Icons.history, color: Colors.white),
                            label: const Text('History',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Controls',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      'System Enabled',
                      'Master switch for Family Tree system',
                      _systemEnabled,
                      (value) => setState(() => _systemEnabled = value),
                      Icons.power_settings_new,
                    ),
                    _buildSwitchTile(
                      'Maintenance Mode',
                      'Temporarily disable user access',
                      _maintenanceMode,
                      (value) => setState(() => _maintenanceMode = value),
                      Icons.build,
                    ),
                    _buildSwitchTile(
                      'Auto Reset Daily',
                      'Automatically reset sessions at midnight',
                      _autoResetDaily,
                      (value) => setState(() => _autoResetDaily = value),
                      Icons.refresh,
                    ),
                    _buildSwitchTile(
                      'Enable Notifications',
                      'Send notifications to users',
                      _enableNotifications,
                      (value) => setState(() => _enableNotifications = value),
                      Icons.notifications,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      'Reset All Users',
                      'Reset all user accounts and balances',
                      Icons.person_remove,
                      Colors.red,
                      _resetAllUsers,
                    ),
                    _buildActionButton(
                      'Reset Statistics',
                      'Reset earnings and transaction history',
                      Icons.bar_chart_outlined,
                      Colors.orange,
                      _resetStatistics,
                    ),
                    _buildActionButton(
                      'Broadcast Notification',
                      'Send message to all users',
                      Icons.campaign,
                      Colors.blue,
                      _broadcastNotification,
                    ),
                    _buildActionButton(
                      'Export Data',
                      'Export user data and statistics',
                      Icons.download,
                      Colors.green,
                      () => _showSuccessMessage(
                          'Export functionality coming soon!'),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save All Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0E3B43).withValues(alpha: 0.75),
            const Color(0xFF1F6F8B).withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4FC1E9).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value,
      Function(bool) onChanged, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1F33).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF4FC1E9).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderControl(String title, double value, double min, double max,
      Function(double) onChanged, String displayValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1F33).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF4FC1E9).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                displayValue,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            activeColor: Colors.blue,
            inactiveColor: Colors.white.withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption(
      {required String value, required String label, required IconData icon}) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _selectedPaymentMethod = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1F6F8B).withValues(alpha: 0.45)
              : const Color(0xFF0E1F33).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4FC1E9)
                : const Color(0xFF4FC1E9).withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.white70, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFF0E1F33).withValues(alpha: 0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF4FC1E9).withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF4FC1E9).withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF4FC1E9), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, String subtitle, IconData icon,
      Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.2),
          foregroundColor: color,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _viewPendingRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminRequestsScreen(
          system: AdminRequestSystem.familyTree,
        ),
      ),
    );

    await _loadDepositWithdrawalRequests();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _viewTransactionHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminRequestsScreen(
          system: AdminRequestSystem.familyTree,
        ),
      ),
    );

    await _loadDepositWithdrawalRequests();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _editSessionTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _sessionTimes[index],
    );

    if (picked != null) {
      setState(() {
        _sessionTimes[index] = picked;
      });

      await _saveSettings();
    }
  }
}
