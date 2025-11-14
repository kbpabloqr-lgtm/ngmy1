import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../widgets/glass_widgets.dart';
import '../widgets/floating_header.dart';
import '../models/payment_proof.dart';
import 'admin_family_tree_user_screen.dart';

class AdminFamilyTreeScreen extends StatefulWidget {
  const AdminFamilyTreeScreen({super.key});

  @override
  State<AdminFamilyTreeScreen> createState() => _AdminFamilyTreeScreenState();
}

class _AdminFamilyTreeScreenState extends State<AdminFamilyTreeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedWorkingDays = {};

  // Clock-in time controls
  List<TimeOfDay> _adminClockInTimes = [
    const TimeOfDay(hour: 8, minute: 0), // 8:00 AM
    const TimeOfDay(hour: 11, minute: 0), // 11:00 AM
    const TimeOfDay(hour: 14, minute: 0), // 2:00 PM
    const TimeOfDay(hour: 17, minute: 0), // 5:00 PM
    const TimeOfDay(hour: 20, minute: 0), // 8:00 PM
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedWorkingDays();
    _loadAdminClockInTimes();
  }

  Future<void> _loadSelectedWorkingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDays =
        prefs.getStringList('family_tree_admin_working_days') ?? [];
    setState(() {
      _selectedWorkingDays = savedDays.toSet();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2472),
      appBar: FloatingHeader(
        title: 'Family Tree Controls',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _buildQuickSearchAction(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Search Section
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'User Account Management',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by username, ID, or phone number...',
                      hintStyle: TextStyle(
                          color: Colors.white.withAlpha((0.5 * 255).round())),
                      prefixIcon:
                          const Icon(Icons.person_search, color: Colors.blue),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon:
                                  const Icon(Icons.clear, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.blue.withAlpha((0.5 * 255).round())),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.blue.withAlpha((0.3 * 255).round())),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildUserSearchResults(),
                  ] else ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.blue.withAlpha((0.3 * 255).round())),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search for a user to manage their account',
                              style: TextStyle(
                                color:
                                    Colors.white.withAlpha((0.9 * 255).round()),
                                fontSize: 13,
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
            const SizedBox(height: 24),
            // Global System Controls
            _buildGlobalControlsSection(),
            const SizedBox(height: 24),
            // Payment Proofs Section
            _buildPaymentProofsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSearchAction() {
    return IconButton(
      icon: const Icon(Icons.search, color: Colors.white70),
      tooltip: 'Quick search by member ID',
      onPressed: _openUserIdSearchDialog,
    );
  }

  Future<void> _openUserIdSearchDialog() async {
    final controller = TextEditingController();
    String? query;
    try {
      query = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF0A2472),
          title: const Text('Search member by ID',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter member ID',
              hintStyle:
                  TextStyle(color: Colors.white.withAlpha((0.5 * 255).round())),
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
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Search'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }

    final trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }

    final results = await _searchUsers(trimmed);
    if (results.isEmpty) {
      _showSnack('No members found matching "$trimmed".',
          color: Colors.redAccent);
      return;
    }

    if (!mounted) {
      return;
    }

    if (results.length == 1) {
      _openFamilyTreeUser(results.first);
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
            Text('Multiple matches for "$trimmed"',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...results.map((userData) {
              final username = userData['username'] ?? 'Unknown';
              final userId = userData['id'] ?? 'Unknown ID';
              return Card(
                color: Colors.white.withAlpha((0.06 * 255).round()),
                child: ListTile(
                  title: Text(username,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text('ID: $userId',
                      style: const TextStyle(color: Colors.white54)),
                  onTap: () => Navigator.of(sheetContext).pop(userData),
                ),
              );
            }),
          ],
        ),
      ),
    );

    if (selected != null) {
      _openFamilyTreeUser(selected);
    }
  }

  void _openFamilyTreeUser(Map<String, String> userData) {
    final username = userData['username'];
    if (username == null || username.isEmpty) {
      _showSnack('Unable to open member details. Username missing.',
          color: Colors.redAccent);
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.push(
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

  Widget _buildUserSearchResults() {
    return FutureBuilder<List<Map<String, String>>>(
      future: _searchUsers(_searchQuery),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final matchedUsers = snapshot.data!;

        if (matchedUsers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.red.withAlpha((0.3 * 255).round())),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_off, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No users found matching "$_searchQuery"',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: matchedUsers.map((userData) {
            final username = userData['username']!;
            final userID = userData['id'] ?? '';
            final phone = userData['phone'] ?? '';

            return Card(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: Colors.blue.withAlpha((0.3 * 255).round())),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withAlpha((0.3 * 255).round()),
                  child: Text(
                    username[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  username,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (userID.isNotEmpty)
                      Text(
                        'ID: $userID',
                        style: TextStyle(
                            color: Colors.white.withAlpha((0.5 * 255).round()),
                            fontSize: 11),
                      ),
                    if (phone.isNotEmpty)
                      Text(
                        'Phone: $phone',
                        style: TextStyle(
                            color: Colors.white.withAlpha((0.5 * 255).round()),
                            fontSize: 11),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios,
                    color: Colors.blue, size: 16),
                onTap: () => _openFamilyTreeUser(userData),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<Map<String, String>>> _searchUsers(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final members = <String, Map<String, String>>{};

    for (final key in allKeys) {
      if (!key.endsWith('_family_tree_user_id')) {
        continue;
      }
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

    final currentUserName = prefs.getString('family_tree_user_name');
    final currentUserID = prefs.getString('family_tree_user_id');
    if (currentUserName != null &&
        currentUserName != 'NGMY User' &&
        currentUserID != null &&
        currentUserID.isNotEmpty &&
        !members.containsKey(currentUserName)) {
      final ensuredId = currentUserID.isEmpty
          ? await _ensureFamilyTreeUserIdFor(currentUserName, prefs)
          : currentUserID;
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

    for (final userData in members.values) {
      final username = userData['username'] ?? '';
      final userId = userData['id'] ?? '';
      final phone = userData['phone'] ?? '';
      if (userId.isEmpty) {
        continue;
      }

      final normalizedPhone = _normalizePhone(phone);
      final matchesUsername = username.toLowerCase().contains(lowerQuery);
      final matchesId = userId.toLowerCase().contains(lowerQuery);
      final matchesPhone = normalizedQuery.isNotEmpty
          ? normalizedPhone.contains(normalizedQuery)
          : phone.toLowerCase().contains(lowerQuery);

      if (matchesUsername || matchesId || matchesPhone) {
        final existing = matchesById[userId];
        if (existing == null || _preferUserRow(existing, userData)) {
          matchesById[userId] = Map<String, String>.from(userData);
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

  bool _preferUserRow(
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

  Future<void> _setWorkingDaysLimit() async {
    if (_selectedWorkingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one working day')),
      );
      return;
    }

    final daysList = _selectedWorkingDays.toList()
      ..sort((a, b) {
        final order = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        return order.indexOf(a).compareTo(order.indexOf(b));
      });

    final daysText = daysList.join(', ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Text('Set Working Days',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Set working days to:\n\n$daysText\n\nUsers will only be able to clock in on these days.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('family_tree_admin_working_days', daysList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Working days set to: $daysText')),
        );
      }
    }
  }

  Future<void> _restartClockInSystem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restart Clock-In System',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'This will clear all clock-in sessions for ALL users.\n\n'
          'This will NOT affect:\n'
          '• User balances\n'
          '• Active days count\n'
          '• Investment plans\n'
          '• 24-hour cycle settings\n\n'
          'Are you sure you want to restart the clock-in system?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restart System'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // Clear ONLY family_tree clock-in related keys for all users
      final keysToRemove = <String>[];
      for (final key in allKeys) {
        if (key.contains('family_tree_last_clock_in') ||
            key.contains('family_tree_clock_in_start_time') ||
            key == 'family_tree_last_clock_in_date' ||
            key == 'family_tree_clock_in_start') {
          keysToRemove.add(key);
        }
      }

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Clock-in system restarted! Cleared ${keysToRemove.length} sessions.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _resetAllStatistics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset Statistics', style: TextStyle(color: Colors.orange)),
          ],
        ),
        content: const Text(
          'This will reset all earnings and statistics for ALL users.\n\n'
          'This will clear:\n'
          '• Today\'s earnings\n'
          '• Yesterday\'s earnings\n'
          '• Completed sessions\n'
          '• Missed sessions\n'
          '• Bandwidth usage\n'
          '• Active days\n'
          '• Last claim data\n\n'
          'Investment amounts and wallet balances will NOT be affected.\n\n'
          'Are you sure you want to continue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset Statistics'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // Clear ALL family_tree statistics and earnings (but NOT investment amounts)
      // This includes BOTH Family Tree internal data AND Home Screen earnings display
      final keysToRemove = <String>[];
      for (final key in allKeys) {
        if (!key.contains('family_tree_')) {
          continue;
        }

        final isInvestmentKey =
            key.contains('_investment') || key.contains('_payment_proof');
        if (isInvestmentKey) {
          continue;
        }

        // Preserve every balance-related key intact.
        if (key.contains('_balance')) {
          continue;
        }

        // Include earnings, sessions, bandwidth, etc.
        final shouldReset = key.contains('_earnings') ||
            key.contains('_completed_clock_ins') ||
            key.contains('_missed_clock_ins') ||
            key.contains('_last_clock_in_date') ||
            key.contains('_last_6am_reset_date') ||
            key.contains('_clock_in_start_time') ||
            key.contains('_last_claim') ||
            key.contains('_bandwidth') ||
            key.contains('_active_days') ||
            key.contains('_income'); // HOME SCREEN income display

        if (shouldReset) {
          keysToRemove.add(key);
        }
      }

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
      content: Text(
        'All statistics reset! Cleared ${keysToRemove.length} records.\nInvestments and balances preserved.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {}); // Refresh the UI
      }
    }
  }

  Future<void> _resetAllInvestments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('DANGER ZONE', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          '⚠️ THIS ACTION CANNOT BE UNDONE ⚠️\n\n'
          'This will permanently delete ALL investment plans for ALL users.\n\n'
          'This will clear:\n'
          '• Approved investments\n'
          '• Pending investments\n'
          '• Payment upload data\n'
          '• All payment proofs\n\n'
          'User balances and clock-in data will NOT be affected.\n\n'
          'Are you absolutely sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE ALL INVESTMENTS'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      // Double confirmation for this dangerous action
      final doubleConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0A2472),
          title: const Text('Final Confirmation',
              style: TextStyle(color: Colors.red)),
          content: const Text(
            'This is your last chance to cancel.\n\n'
            'Type "DELETE" to confirm you want to reset all investments.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm Delete'),
            ),
          ],
        ),
      );

      if (doubleConfirmed == true) {
        final prefs = await SharedPreferences.getInstance();
        final allKeys = prefs.getKeys();

        // Clear ONLY family_tree investment-related keys for all users
        final keysToRemove = <String>[];
        for (final key in allKeys) {
          if (key.contains('family_tree_approved_investment') ||
              key.contains('family_tree_pending_investment') ||
              key.contains('family_tree_pending_upload') ||
              key == 'family_tree_approved_investment' ||
              key == 'family_tree_pending_investment_amount' ||
              key == 'family_tree_payment_proofs') {
            keysToRemove.add(key);
          }
        }

        for (final key in keysToRemove) {
          await prefs.remove(key);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'All investments reset! Cleared ${keysToRemove.length} records.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() {}); // Refresh the UI
        }
      }
    }
  }

  Widget _buildGlobalControlsSection() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.purple),
              const SizedBox(width: 12),
              const Text(
                'Global System Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Working Days Limit Control
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Working Days',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose which days users can clock in',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                // Day Selection Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDayButton('Monday'),
                    _buildDayButton('Tuesday'),
                    _buildDayButton('Wednesday'),
                    _buildDayButton('Thursday'),
                    _buildDayButton('Friday'),
                    _buildDayButton('Saturday'),
                    _buildDayButton('Sunday'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _setWorkingDaysLimit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: Text(
                      _selectedWorkingDays.isEmpty
                          ? 'Select Days to Continue'
                          : 'Save Working Days (${_selectedWorkingDays.length} selected)',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Restart Clock-In System
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restart_alt,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Restart Clock-In System',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Clear all clock-in sessions (keeps 24hr cycle, balances, and days count)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _restartClockInSystem,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restart Clock-In System'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Clock-In Time Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Daily Clock-In Times',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Set the 5 daily clock-in session times (5 minutes each)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _buildClockInTimesList(),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _saveClockInTimes,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Clock-In Times'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Reset Statistics & Earnings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orangeAccent.withAlpha(76),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restart_alt,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Reset Statistics & Earnings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'This will reset all earnings and statistics for ALL users.\n'
                  'Investment amounts will NOT be affected.',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _resetAllStatistics,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset All Statistics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Reset All Investments
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent.withAlpha(76),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Reset All Investments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ DANGER: This will clear all investment plans for ALL users',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _resetAllInvestments,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Reset All Investments'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayButton(String day) {
    final isSelected = _selectedWorkingDays.contains(day);
    final dayShort = day.substring(0, 3); // Mon, Tue, Wed, etc.

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedWorkingDays.remove(day);
          } else {
            _selectedWorkingDays.add(day);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withAlpha((0.6 * 255).round())
              : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white.withAlpha(51),
            width: 2,
          ),
        ),
        child: Text(
          dayShort,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentProofsSection() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Payment Approvals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<PaymentProof>>(
            future: _loadPaymentProofs(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final proofs = snapshot.data!;
              final pendingProofs =
                  proofs.where((p) => p.status == 'pending').toList();

              if (pendingProofs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No pending payment proofs',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }

              return Column(
                children: pendingProofs
                    .map((proof) => _buildPaymentProofCard(proof))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProofCard(PaymentProof proof) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, color: Colors.blue, size: 14),
                const SizedBox(width: 4),
                Text(
                  proof.username,
                  style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Investment Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    '\$${proof.investmentAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Paid Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    '\$${proof.paidAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Submitted: ${_formatDate(proof.submittedAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _viewPaymentProof(proof),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              minimumSize: const Size(double.infinity, 40),
            ),
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('View Details'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRejectDialog(proof),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approvePayment(proof),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<PaymentProof>> _loadPaymentProofs() async {
    final prefs = await SharedPreferences.getInstance();

    // Load both Growth system proofs and Family Tree system proofs
    final growthProofsJson = prefs.getStringList('payment_proofs') ?? [];
    final familyTreeProofsJson =
        prefs.getStringList('family_tree_pending_proofs') ?? [];

    final allProofs = <PaymentProof>[];

    // Add Growth proofs
    for (final json in growthProofsJson) {
      final proof =
          PaymentProof.fromJson(jsonDecode(json) as Map<String, dynamic>);
      allProofs.add(proof);
    }

    // Add Family Tree proofs
    for (final json in familyTreeProofsJson) {
      final proof =
          PaymentProof.fromJson(jsonDecode(json) as Map<String, dynamic>);
      allProofs.add(proof);
    }

    // Sort by submission date (newest first)
    allProofs.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return allProofs;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _viewPaymentProof(PaymentProof proof) async {
    final messageController =
        TextEditingController(text: proof.adminMessage ?? '');

    if (!mounted) {
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Payment Proof Details',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProofDetail('Investment',
                  '\$${proof.investmentAmount.toStringAsFixed(0)}'),
              _buildProofDetail(
                  'Paid', '\$${proof.paidAmount.toStringAsFixed(2)}'),
              _buildProofDetail('Submitted', _formatDate(proof.submittedAt)),
              const SizedBox(height: 16),
              const Text('Screenshot:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              if (proof.screenshotPath.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _showFullScreenImage(proof.screenshotPath),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(proof.screenshotPath),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey.withAlpha((0.2 * 255).round()),
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white54, size: 48),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _showFullScreenImage(proof.screenshotPath),
                    icon: const Icon(Icons.open_in_full, color: Colors.white70),
                    label: const Text(
                      'Open Fullscreen',
                      style: TextStyle(color: Colors.white70),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Admin Message (optional)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Add a message or request changes...',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.3 * 255).round())),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (proof.userReply != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Reply:',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(proof.userReply!,
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          if (messageController.text.isNotEmpty)
            FilledButton(
              onPressed: () async {
                await _sendMessageToUser(proof, messageController.text);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Send Message'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _approvePayment(proof);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectPayment(proof, messageController.text);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildProofDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _sendMessageToUser(PaymentProof proof, String message) async {
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final prefs = await SharedPreferences.getInstance();
    final proofsJson = prefs.getStringList('payment_proofs') ?? [];

    // Update proof with admin message
    final updatedProofs = proofsJson.map((json) {
      final proofData = jsonDecode(json) as Map<String, dynamic>;
      if (proofData['id'] == proof.id) {
        proofData['adminMessage'] = message;
        proofData['respondedAt'] = DateTime.now().toIso8601String();
      }
      return jsonEncode(proofData);
    }).toList();

    await prefs.setStringList('payment_proofs', updatedProofs);

    if (!mounted) {
      return;
    }

    scaffoldMessenger?.showSnackBar(
      SnackBar(
        content: const Text('Message sent to user'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {});
  }

  Future<void> _approvePayment(PaymentProof proof) async {
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Payment?'),
        content: Text(
            'Approve \$${proof.investmentAmount.toStringAsFixed(0)} investment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final username = proof.username;

      // Check if this is a Family Tree proof by looking in family_tree_pending_proofs
      final familyTreeProofsJson =
          prefs.getStringList('family_tree_pending_proofs') ?? [];
      final growthProofsJson = prefs.getStringList('payment_proofs') ?? [];

      bool isFamilyTreeProof = false;

      // Check Family Tree proofs first
      for (int i = 0; i < familyTreeProofsJson.length; i++) {
        final proofData =
            jsonDecode(familyTreeProofsJson[i]) as Map<String, dynamic>;
        if (proofData['id'] == proof.id) {
          isFamilyTreeProof = true;

          // Update proof status
          final approvalStamp = DateTime.now();
          proofData['status'] = 'approved';
          proofData['respondedAt'] = approvalStamp.toIso8601String();
          familyTreeProofsJson[i] = jsonEncode(proofData);
          await prefs.setStringList(
              'family_tree_pending_proofs', familyTreeProofsJson);

          // Activate Family Tree investment
          final previousAmount =
              prefs.getDouble('${username}_family_tree_approved_investment') ??
                  0.0;
          await prefs.setDouble('${username}_family_tree_approved_investment',
              proof.investmentAmount);
          await prefs.remove('${username}_family_tree_pending_proof_amount');
          if (proof.investmentAmount > 0 && previousAmount <= 0) {
            final activationIso = approvalStamp.toIso8601String();
            await prefs.setString(
                '${username}_family_tree_investment_activated_at',
                activationIso);
          }

          // If this is the current Family Tree user, also update global Family Tree keys
          final currentUser = prefs.getString('family_tree_user_name');
          if (currentUser == username) {
            await prefs.setDouble(
                'family_tree_approved_investment', proof.investmentAmount);
            await prefs.remove('family_tree_pending_proof_amount');
            if (proof.investmentAmount > 0 && previousAmount <= 0) {
              await prefs.setString(
                  'family_tree_investment_activated_at',
                  approvalStamp.toIso8601String());
            }
          }
          break;
        }
      }

      // If not found in Family Tree, check Growth system proofs
      if (!isFamilyTreeProof) {
        for (int i = 0; i < growthProofsJson.length; i++) {
          final proofData =
              jsonDecode(growthProofsJson[i]) as Map<String, dynamic>;
          if (proofData['id'] == proof.id) {
            // Update proof status
            proofData['status'] = 'approved';
            proofData['respondedAt'] = DateTime.now().toIso8601String();
            growthProofsJson[i] = jsonEncode(proofData);
            await prefs.setStringList('payment_proofs', growthProofsJson);

            // Activate Growth system investment
            await prefs.setDouble(
                '${username}_approved_investment', proof.investmentAmount);
            await prefs.remove('${username}_pending_investment_amount');

            // If this is the current logged-in user, also update global keys
            final currentUser = prefs.getString('family_tree_user_name');
            if (currentUser == username) {
              await prefs.setDouble(
                  'approved_investment', proof.investmentAmount);
              await prefs.setDouble(
                  'current_investment', proof.investmentAmount);
              await prefs.remove('pending_investment_amount');
            }
            break;
          }
        }
      }

      if (!mounted || !context.mounted) {
        return;
      }
      final systemName = isFamilyTreeProof ? 'Family Tree' : 'Growth';
      scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text(
            '✅ $systemName payment approved for $username! Investment activated.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {});
    }
  }

  Future<void> _showFullScreenImage(String imagePath) async {
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final file = File(imagePath);
    if (!await file.exists()) {
      scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: const Text(
            'Screenshot file not found. Ask the user to resubmit their proof.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted || !context.mounted) {
      return;
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 300,
                        height: 300,
                        color: Colors.grey.withAlpha((0.2 * 255).round()),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image,
                                color: Colors.white54, size: 64),
                            const SizedBox(height: 16),
                            const Text('Unable to load image',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              imagePath,
                              style: TextStyle(
                                  color: Colors.white
                                      .withAlpha((0.5 * 255).round()),
                                  fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRejectDialog(PaymentProof proof) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('Reject Payment', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting payment for ${proof.username}',
                style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount: \$${proof.investmentAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason (optional)',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.5 * 255).round())),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectPayment(proof, reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.cancel, size: 18),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPayment(PaymentProof proof, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final familyTreeProofsJson =
        prefs.getStringList('family_tree_pending_proofs') ?? [];
    final growthProofsJson = prefs.getStringList('payment_proofs') ?? [];

    bool isFamilyTreeProof = false;

    // Check Family Tree proofs first
    for (int i = 0; i < familyTreeProofsJson.length; i++) {
      final proofData =
          jsonDecode(familyTreeProofsJson[i]) as Map<String, dynamic>;
      if (proofData['id'] == proof.id) {
        isFamilyTreeProof = true;

        // Update proof status
        proofData['status'] = 'rejected';
        proofData['adminMessage'] =
            reason.isEmpty ? 'Payment rejected' : reason;
        proofData['respondedAt'] = DateTime.now().toIso8601String();
        familyTreeProofsJson[i] = jsonEncode(proofData);
        await prefs.setStringList(
            'family_tree_pending_proofs', familyTreeProofsJson);

        final username = proof.username;
        await prefs.remove(
            '${username}_family_tree_pending_investment_amount');
        await prefs.remove('family_tree_pending_investment_amount');
        await prefs
            .remove('${username}_family_tree_pending_proof_amount');
        await prefs.remove('family_tree_pending_proof_amount');
        break;
      }
    }

    // If not found in Family Tree, check Growth system proofs
    if (!isFamilyTreeProof) {
      for (int i = 0; i < growthProofsJson.length; i++) {
        final proofData =
            jsonDecode(growthProofsJson[i]) as Map<String, dynamic>;
        if (proofData['id'] == proof.id) {
          // Update proof status
          proofData['status'] = 'rejected';
          proofData['adminMessage'] =
              reason.isEmpty ? 'Payment rejected' : reason;
          proofData['respondedAt'] = DateTime.now().toIso8601String();
          growthProofsJson[i] = jsonEncode(proofData);
          await prefs.setStringList('payment_proofs', growthProofsJson);

          final username = proof.username;
          await prefs.remove('${username}_pending_investment_amount');

          final currentUser = prefs.getString('growth_user_name');
          if (currentUser == username) {
            await prefs.remove('pending_investment_amount');
            await prefs.remove('growth_pending_upload_amount');
            await prefs.remove('growth_pending_upload_timestamp');
          }
          break;
        }
      }
    }

    if (!mounted || !context.mounted) {
      return;
    }
    final systemName = isFamilyTreeProof ? 'Family Tree' : 'Growth';
    _showSnack('$systemName payment rejected', color: Colors.red);
    setState(() {});
  }

  void _showSnack(String message, {Color color = const Color(0xFF667eea)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadAdminClockInTimes() async {
    final prefs = await SharedPreferences.getInstance();

    // Load from the SAME keys that admin control screen uses
    // to ensure consistency across both admin screens
    final totalSessions = prefs.getInt('family_tree_total_sessions') ?? 5;
    List<TimeOfDay> adminTimes = [];

    for (int i = 0; i < totalSessions; i++) {
      final hour = prefs.getInt('family_tree_session_${i}_hour');
      final minute = prefs.getInt('family_tree_session_${i}_minute');

      if (hour != null && minute != null) {
        adminTimes.add(TimeOfDay(hour: hour, minute: minute));
      }
    }

    // Use admin times if available, otherwise keep defaults
    if (adminTimes.length == 5) {
      setState(() {
        _adminClockInTimes = adminTimes;
      });
    }
  }

  Widget _buildClockInTimesList() {
    return Column(
      children: List.generate(5, (index) {
        final time = _adminClockInTimes[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: Colors.white.withAlpha((0.2 * 255).round())),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.teal.shade600,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Session ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _selectTime(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal),
                  ),
                  child: Text(
                    time.format(context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _adminClockInTimes[index],
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _adminClockInTimes[index]) {
      setState(() {
        _adminClockInTimes[index] = picked;
      });

      // AUTO-SAVE immediately when time is changed
      await _saveClockInTimes();
    }
  }

  Future<void> _saveClockInTimes() async {
    final prefs = await SharedPreferences.getInstance();

    // Save to the SAME keys that admin control screen uses
    // to ensure consistency across both admin screens
    for (int i = 0; i < _adminClockInTimes.length; i++) {
      await prefs.setInt(
          'family_tree_session_${i}_hour', _adminClockInTimes[i].hour);
      await prefs.setInt(
          'family_tree_session_${i}_minute', _adminClockInTimes[i].minute);
    }
    await prefs.setInt('family_tree_total_sessions', _adminClockInTimes.length);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Clock-in times saved successfully and will persist!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }
}
