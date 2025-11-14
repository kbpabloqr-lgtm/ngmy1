import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/glass_widgets.dart';

class AdminFamilyTreeUserScreen extends StatefulWidget {
  final String username;
  final String? userId;

  const AdminFamilyTreeUserScreen({super.key, required this.username, this.userId});

  @override
  State<AdminFamilyTreeUserScreen> createState() => _AdminFamilyTreeUserScreenState();
}

class _AdminFamilyTreeUserScreenState extends State<AdminFamilyTreeUserScreen> {
  bool _loading = true;
  late SharedPreferences _prefs;

  String _userId = 'N/A';
  String? _phone;
  double _balance = 0.0;
  double _todayEarnings = 0.0;
  double _totalEarnings = 0.0;
  int _activeDays = 0;
  double _investment = 0.0;

  bool _autoSessionEnabled = false;
  double _autoSessionPaid = 0.0;
  double _autoSessionRequired = 0.0;
  double get _autoSessionOutstanding => math.max(0.0, _autoSessionRequired - _autoSessionPaid);

  bool _isDisabled = false;
  bool _isBanned = false;
  DateTime? _suspendedUntil;

  double _penaltyTotal = 0.0;
  int _penaltyCount = 0;
  List<Map<String, dynamic>> _recentPenalties = const [];
  List<Map<String, dynamic>> _recentBalanceAdjustments = const [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
    });

    _prefs = await SharedPreferences.getInstance();
    final username = widget.username;

    var userId = _prefs.getString('${username}_family_tree_user_id') ?? widget.userId ?? '';
    if (userId.isEmpty || userId == 'N/A') {
      userId = await _ensureUserId(username);
    }
    final phone = _prefs.getString('${username}_family_tree_phone');
    final balance = _prefs.getDouble('${username}_family_tree_balance') ?? 0.0;
    final todayEarnings = _prefs.getDouble('${username}_family_tree_today_earnings') ?? 0.0;
    final totalEarnings = _prefs.getDouble('${username}_family_tree_total_earnings') ?? 0.0;
    final activeDays = _prefs.getInt('${username}_family_tree_active_days') ?? 0;
    final investment = _prefs.getDouble('${username}_family_tree_approved_investment') ?? 0.0;

    final autoSessionEnabled = _prefs.getBool('${username}_family_tree_auto_session_enabled') ?? false;
    final autoSessionPaid = _prefs.getDouble('${username}_family_tree_auto_session_paid_total') ?? 0.0;
    final autoSessionRequired = _prefs.getDouble('${username}_family_tree_auto_session_required_total') ??
        (autoSessionEnabled ? investment * 0.2 : 0.0);

    final disabled = _prefs.getBool('${username}_family_tree_disabled') ?? false;
    final banned = _prefs.getBool('${username}_family_tree_banned') ?? false;
    final suspensionString = _prefs.getString('${username}_family_tree_suspension_until');
    DateTime? suspendedUntil;
    if (suspensionString != null && suspensionString.isNotEmpty) {
      final parsed = DateTime.tryParse(suspensionString);
      if (parsed != null) {
        if (DateTime.now().isAfter(parsed)) {
          await _prefs.remove('${username}_family_tree_suspension_until');
        } else {
          suspendedUntil = parsed.toLocal();
        }
      }
    }

    final penaltyHistory = _prefs.getStringList('${username}_family_tree_penalty_history') ?? const [];
    double penaltyTotal = 0.0;
    final penalties = <Map<String, dynamic>>[];
    for (final record in penaltyHistory.reversed.take(8)) {
      try {
        final payload = jsonDecode(record) as Map<String, dynamic>;
        final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
        final reason = payload['reason'] as String? ?? 'Penalty';
        final dateString = payload['date'] as String?;
        DateTime? date;
        if (dateString != null) {
          date = DateTime.tryParse(dateString)?.toLocal();
        }
        penaltyTotal += amount;
        penalties.add({
          'amount': amount,
          'reason': reason,
          'date': date,
        });
      } catch (_) {
        continue;
      }
    }

    final adjustmentsRaw = _prefs.getStringList('${username}_family_tree_admin_balance_history') ?? const [];
    final adjustments = _parseAdminBalanceAdjustments(adjustmentsRaw);

    setState(() {
      _userId = userId;
      _phone = phone;
      _balance = balance;
      _todayEarnings = todayEarnings;
      _totalEarnings = totalEarnings;
      _activeDays = activeDays;
      _investment = investment;
      _autoSessionEnabled = autoSessionEnabled;
      _autoSessionPaid = autoSessionPaid;
      _autoSessionRequired = autoSessionRequired;
      _isDisabled = disabled;
      _isBanned = banned;
      _suspendedUntil = suspendedUntil;
      _penaltyTotal = penaltyTotal;
      _penaltyCount = penaltyHistory.length;
      _recentPenalties = penalties;
      _recentBalanceAdjustments = adjustments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2472),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2472),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Family Tree: ${widget.username}', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Refresh user data',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadUser,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Member Overview'),
                        const SizedBox(height: 16),
                        _buildOverviewRow('User ID', _userId),
                        _buildOverviewRow('Phone', _phone ?? 'Not set'),
                        _buildOverviewRow('Active Days', _activeDays.toString()),
                        _buildOverviewRow('Balance', _formatCurrency(_balance)),
                        _buildOverviewRow('Today\'s Earnings', _formatCurrency(_todayEarnings)),
                        _buildOverviewRow('Total Earnings', _formatCurrency(_totalEarnings)),
                        _buildOverviewRow('Approved Investment', _formatCurrency(_investment)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Account Controls'),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          value: _isDisabled,
                          title: const Text('Disable account', style: TextStyle(color: Colors.white)),
                          subtitle: const Text('Pauses Family Tree activity (user can still withdraw existing balance).', style: TextStyle(color: Colors.white60)),
                          activeThumbColor: Colors.orangeAccent,
                          activeTrackColor: Colors.orangeAccent.withAlpha((0.4 * 255).round()),
                          onChanged: (value) => _toggleDisable(value),
                        ),
                        SwitchListTile.adaptive(
                          value: _isBanned,
                          title: const Text('Ban account', style: TextStyle(color: Colors.white)),
                          subtitle: const Text('Blocks the user permanently until unbanned.', style: TextStyle(color: Colors.white60)),
                          activeThumbColor: Colors.redAccent,
                          activeTrackColor: Colors.redAccent.withAlpha((0.4 * 255).round()),
                          onChanged: (value) => _toggleBan(value),
                        ),
                        const SizedBox(height: 12),
                        _buildSuspensionRow(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Auto Session Complete'),
                        const SizedBox(height: 12),
                        _buildOverviewRow('Status', _autoSessionEnabled ? 'Enabled' : 'Disabled'),
                        _buildOverviewRow('Coverage Required', _formatCurrency(_autoSessionRequired)),
                        _buildOverviewRow('Paid So Far', _formatCurrency(_autoSessionPaid)),
                        _buildOverviewRow('Outstanding', _formatCurrency(_autoSessionOutstanding)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _autoSessionEnabled ? _forceDisableAutoSession : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.power_settings_new),
                          label: const Text('Force disable Auto Session Complete'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Penalties'),
                        const SizedBox(height: 12),
                        _buildOverviewRow('Total Penalties', _formatCurrency(_penaltyTotal)),
                        _buildOverviewRow('Recorded Hits', _penaltyCount.toString()),
                        const SizedBox(height: 12),
                        if (_recentPenalties.isEmpty)
                          const Text('No penalties recorded for this member.', style: TextStyle(color: Colors.white60))
                        else
                          Column(
                            children: _recentPenalties.map((penalty) {
                              final amount = penalty['amount'] as double? ?? 0.0;
                              final reason = penalty['reason'] as String? ?? 'Penalty';
                              final date = penalty['date'] as DateTime?;
                              final dateLabel = date != null ? _formatDate(date) : 'Unknown date';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                                title: Text(reason, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                subtitle: Text(dateLabel, style: const TextStyle(color: Colors.white38)),
                                trailing: Text(_formatCurrency(amount), style: const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Balance Management'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _promptBalanceAdjustment(isCredit: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.shade400,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add Funds'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _promptBalanceAdjustment(isCredit: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade200,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                            label: const Text('Deduct Funds'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_recentBalanceAdjustments.isEmpty)
                          const Text(
                            'No manual balance changes yet.',
                            style: TextStyle(color: Colors.white60),
                          )
                        else
                          Column(
                            children: _recentBalanceAdjustments.take(5).map((adjustment) {
                              final amount = (adjustment['amount'] as double?) ?? 0.0;
                              final isCredit = (adjustment['type'] as String?) == 'credit';
                              final before = (adjustment['before'] as double?) ?? 0.0;
                              final after = (adjustment['after'] as double?) ?? 0.0;
                              final timestamp = adjustment['timestamp'] as DateTime?;
                              final color = isCredit ? Colors.greenAccent : Colors.redAccent;
                              final label = isCredit ? 'Credited' : 'Debited';
                              final subtitle = timestamp != null
                                  ? '${_formatTimestamp(timestamp)} • ${_formatCurrency(before)} → ${_formatCurrency(after)}'
                                  : '${_formatCurrency(before)} → ${_formatCurrency(after)}';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: color,
                                ),
                                title: Text('$label ${_formatCurrency(amount)}', style: const TextStyle(color: Colors.white)),
                                subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Admin Tools'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _resetAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset Family Tree account data'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _copyToClipboard(_userId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy user ID'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildOverviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSuspensionRow() {
    final suspended = _suspendedUntil != null && DateTime.now().isBefore(_suspendedUntil!);
    final status = suspended
        ? 'Suspended until ${_formatDate(_suspendedUntil!)}'
        : 'No active suspension';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(status, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _promptSuspensionDays(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black87),
              icon: const Icon(Icons.timer),
              label: const Text('Suspend'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: suspended ? () => _clearSuspension() : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              icon: const Icon(Icons.lock_open),
              label: const Text('Lift suspension'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggleDisable(bool value) async {
    await _prefs.setBool('${widget.username}_family_tree_disabled', value);
    setState(() {
      _isDisabled = value;
    });
    _showToast(value ? 'Account disabled' : 'Account enabled');
  }

  Future<void> _toggleBan(bool value) async {
    await _prefs.setBool('${widget.username}_family_tree_banned', value);
    setState(() {
      _isBanned = value;
    });
    _showToast(value ? 'Account banned' : 'Account unbanned');
  }

  Future<void> _promptSuspensionDays() async {
    final controller = TextEditingController(text: '3');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Text('Suspend account', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter number of days to suspend this member.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 3',
                hintStyle: TextStyle(color: Colors.white.withAlpha((0.4 * 255).round())),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white60),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = int.tryParse(controller.text.trim());
              if (raw == null || raw <= 0) {
                Navigator.of(context).pop();
                _showToast('Enter a valid suspension length', color: Colors.redAccent);
                return;
              }
              Navigator.of(context).pop(raw);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == null) {
      return;
    }

    final until = DateTime.now().add(Duration(days: result));
    await _prefs.setString('${widget.username}_family_tree_suspension_until', until.toIso8601String());
    setState(() {
      _suspendedUntil = until.toLocal();
    });
    _showToast('Account suspended for $result day${result == 1 ? '' : 's'}', color: Colors.amber);
  }

  Future<void> _clearSuspension() async {
    await _prefs.remove('${widget.username}_family_tree_suspension_until');
    setState(() {
      _suspendedUntil = null;
    });
    _showToast('Suspension lifted', color: Colors.green);
  }

  Future<void> _forceDisableAutoSession() async {
    await _prefs.setBool('${widget.username}_family_tree_auto_session_enabled', false);
    await _prefs.setDouble('${widget.username}_family_tree_auto_session_paid_total', _autoSessionPaid);
    await _prefs.setDouble('${widget.username}_family_tree_auto_session_required_total', _autoSessionRequired);
    setState(() {
      _autoSessionEnabled = false;
    });
    _showToast('Auto Session Complete disabled for this user', color: Colors.redAccent);
  }

  Future<void> _promptBalanceAdjustment({required bool isCredit}) async {
    final controller = TextEditingController();
    String? errorText;
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF0A2472),
          title: Text(
            isCredit ? 'Add funds to account' : 'Deduct funds from account',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount (e.g. 2500)',
                  hintStyle: TextStyle(color: Colors.white.withAlpha((0.45 * 255).round())),
                  errorText: errorText,
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
              const SizedBox(height: 12),
              Text(
                isCredit
                    ? 'Funds are added instantly to the member balance.'
                    : 'Amount is removed immediately. Balance cannot drop below zero.',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed <= 0) {
                  setStateDialog(() {
                    errorText = 'Enter a valid positive amount';
                  });
                  return;
                }
                Navigator.of(dialogContext).pop(parsed);
              },
              child: Text(isCredit ? 'Add funds' : 'Deduct funds'),
            ),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (amount == null) {
      return;
    }

    await _applyBalanceAdjustment(amount: amount, isCredit: isCredit);
  }

  Future<void> _applyBalanceAdjustment({required double amount, required bool isCredit}) async {
    final username = widget.username;
    final balanceKey = '${username}_family_tree_balance';
    final currentBalance = _prefs.getDouble(balanceKey) ?? 0.0;
    final before = currentBalance;
    final newBalance = isCredit ? currentBalance + amount : math.max(0.0, currentBalance - amount);

    await _prefs.setDouble(balanceKey, newBalance);
    await _prefs.setDouble('family_tree_total_balance', newBalance);

    await _recordAdminTransaction(
      amount: amount,
      isCredit: isCredit,
      before: before,
      after: newBalance,
    );

    setState(() {
      _balance = newBalance;
    });

    _showToast(
      isCredit
          ? 'Credited ${_formatCurrency(amount)} to ${widget.username}'
          : 'Debited ${_formatCurrency(amount)} from ${widget.username}',
      color: isCredit ? Colors.greenAccent : Colors.redAccent,
    );
  }

  Future<void> _recordAdminTransaction({
    required double amount,
    required bool isCredit,
    required double before,
    required double after,
  }) async {
    final historyKey = '${widget.username}_family_tree_admin_balance_history';
    final history = _prefs.getStringList(historyKey) ?? <String>[];
    final payload = jsonEncode({
      'type': isCredit ? 'credit' : 'debit',
      'amount': amount,
      'before': before,
      'after': after,
      'timestamp': DateTime.now().toIso8601String(),
    });
    history.insert(0, payload);
    if (history.length > 40) {
      history.removeRange(40, history.length);
    }
    await _prefs.setStringList(historyKey, history);
    setState(() {
      _recentBalanceAdjustments = _parseAdminBalanceAdjustments(history);
    });
  }

  Future<void> _resetAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2472),
        title: const Text('Reset Family Tree account?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This clears earnings, sessions, penalties, and auto session progress for this member. The unique ID and phone number will be kept.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset account'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final prefix = '${widget.username}_family_tree_';
    final preserved = {
      '${widget.username}_family_tree_user_id',
      '${widget.username}_family_tree_phone',
    };
    final keys = _prefs.getKeys().where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      if (preserved.contains(key)) {
        continue;
      }
      await _prefs.remove(key);
    }

    _showToast('Family Tree account reset', color: Colors.orangeAccent);
    await _loadUser();
  }

  Future<void> _copyToClipboard(String value) async {
    if (value.isEmpty || value == 'N/A') {
      _showToast('No user ID available to copy', color: Colors.redAccent);
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    _showToast('User ID copied to clipboard');
  }

  String _formatCurrency(double value) {
    return '₦₲${value.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTimestamp(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(local)} • $hour:$minute $period';
  }

  Future<String> _ensureUserId(String username) async {
    var existing = _prefs.getString('${username}_family_tree_user_id');
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final ids = <String>{};
    for (final key in _prefs.getKeys()) {
      if (key.endsWith('_family_tree_user_id')) {
        final value = _prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          ids.add(value);
        }
      }
    }

    final generated = _generateUserId(ids);
    await _prefs.setString('${username}_family_tree_user_id', generated);
    return generated;
  }

  String _generateUserId(Set<String> existing) {
    final random = math.Random();
    String candidate;
    int attempts = 0;
    do {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(32).toUpperCase();
      final randomPart = random.nextInt(0xFFFFF).toRadixString(32).toUpperCase().padLeft(4, '0');
      candidate = 'FT-$timestamp-$randomPart';
      attempts++;
    } while (existing.contains(candidate) && attempts < 6);

    while (existing.contains(candidate)) {
      candidate = '$candidate-${random.nextInt(9999).toString().padLeft(4, '0')}';
    }

    return candidate;
  }

  List<Map<String, dynamic>> _parseAdminBalanceAdjustments(List<String> raw) {
    final entries = <Map<String, dynamic>>[];
    for (final record in raw) {
      try {
        final decoded = jsonDecode(record) as Map<String, dynamic>;
        final timestampString = decoded['timestamp'] as String?;
        final timestamp = timestampString != null ? DateTime.tryParse(timestampString) : null;
        entries.add({
          'type': decoded['type'],
          'amount': (decoded['amount'] as num?)?.toDouble() ?? 0.0,
          'before': (decoded['before'] as num?)?.toDouble() ?? 0.0,
          'after': (decoded['after'] as num?)?.toDouble() ?? 0.0,
          'timestamp': timestamp,
        });
      } catch (_) {
        continue;
      }
    }
    return entries;
  }

  void _showToast(String message, {Color color = Colors.blueAccent}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}
