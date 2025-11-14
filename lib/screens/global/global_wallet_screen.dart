import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ngmy1/services/cash_tag_service.dart';
import '../../services/global_account_guard.dart';

class GlobalWalletScreen extends StatefulWidget {
  const GlobalWalletScreen({super.key});

  @override
  State<GlobalWalletScreen> createState() => _GlobalWalletScreenState();
}

class _GlobalWalletScreenState extends State<GlobalWalletScreen> {
  static const int _transactionRetentionDays = 7;
  static const double _liveUpdateTolerance = 0.01;
  double _totalBalance = 0.0;
  int _activeDays = 0;
  final List<Map<String, dynamic>> _transactions = [];
  static const Color _panelTint = Color(0xFF231A4B);
  static const Color _accentPurple = Color(0xFF6C3FDB);
  static const Color _lavenderGlow = Color(0xFFA379FF);
  GlobalAccountStatus _accountStatus = const GlobalAccountStatus(
    username: 'NGMY User',
    isDisabled: false,
    isSuspended: false,
  );
  Timer? _liveMetricsTimer;
  bool _isPollingLiveMetrics = false;

  String _userNameKey(SharedPreferences prefs) {
    return prefs.getString('global_user_name') ??
        prefs.getString('Global_user_name') ??
        'NGMY User';
  }

  String _uKey(String username, String suffix) => '${username}_global_$suffix';
  String _gKey(String suffix) => 'global_$suffix';
  String _legacyKey(String username, String suffix) => '${username}_$suffix';
  String _namespacedUserIdKey(String username) => '${username}_global_user_id';

  bool _isGlobalId(String value) => value.toUpperCase().startsWith('GI-');

  String _resolveGlobalUserId(SharedPreferences prefs, String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      final fallback = prefs.getString('Global_user_id') ??
          prefs.getString('global_user_id');
      return (fallback == null || fallback.trim().isEmpty)
          ? 'N/A'
          : fallback.trim();
    }

    final candidates = <String?>[
      prefs.getString(_uKey(trimmed, 'user_id')),
      prefs.getString(_namespacedUserIdKey(trimmed)),
      prefs.getString(_gKey('user_id')),
      prefs.getString('Global_user_id'),
      prefs.getString('global_user_id'),
      prefs.getString(_legacyKey(trimmed, 'user_id')),
    ];

    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final normalized = candidate.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (_isGlobalId(normalized)) {
        return normalized;
      }
    }

    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final normalized = candidate.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return 'N/A';
  }

  Future<void> _refreshAccountStatus([SharedPreferences? prefs]) async {
    final status = await GlobalAccountGuard.load(prefs: prefs);
    if (!mounted) {
      return;
    }
    setState(() {
      _accountStatus = status;
    });
  }

  Future<bool> _ensureAccountActionAllowed({
    required String actionLabel,
    bool allowWithdraw = false,
  }) async {
    final decision = await GlobalAccountGuard.evaluateAction(
      allowWithdraw: allowWithdraw,
      actionLabel: actionLabel,
    );
    if (mounted) {
      setState(() {
        _accountStatus = decision.status;
      });
      if (!decision.allowed) {
        GlobalAccountGuard.showBlockedMessage(context, decision);
      }
    }
    return decision.allowed;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLiveMetricsRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload balance whenever screen is shown
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final username = _userNameKey(prefs);
    final approvedInvestment =
        prefs.getDouble(_uKey(username, 'approved_investment')) ??
            prefs.getDouble(_gKey('approved_investment')) ??
            0.0;
    final hasInvestment = approvedInvestment > 0;
    final savedBalance = hasInvestment
    ? (prefs.getDouble(_uKey(username, 'balance')) ?? 0.0)
        : 0.0;
    final savedActiveDays = hasInvestment
        ? (prefs.getInt(_uKey(username, 'active_days')) ??
            prefs.getInt(_gKey('active_days')) ??
            0)
        : 0;
    await _refreshAccountStatus(prefs);

    if (mounted &&
        (savedBalance != _totalBalance || savedActiveDays != _activeDays)) {
      setState(() {
        _totalBalance = savedBalance;
        _activeDays = savedActiveDays;
      });
    }
    await _loadTransactionHistory(prefs: prefs, hasInvestment: hasInvestment);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final username = _userNameKey(prefs);
    final approvedInvestment =
        prefs.getDouble(_uKey(username, 'approved_investment')) ??
            prefs.getDouble(_gKey('approved_investment')) ??
            0.0;
    final hasInvestment = approvedInvestment > 0;
    final savedBalance = hasInvestment
    ? (prefs.getDouble(_uKey(username, 'balance')) ?? 0.0)
        : 0.0;
    final savedActiveDays = hasInvestment
        ? (prefs.getInt(_uKey(username, 'active_days')) ??
            prefs.getInt(_gKey('active_days')) ??
            0)
        : 0;
    await _refreshAccountStatus(prefs);

    if (mounted) {
      setState(() {
        _totalBalance = savedBalance;
        _activeDays = savedActiveDays;
      });
    }

    await _loadTransactionHistory(prefs: prefs, hasInvestment: hasInvestment);
  }

  Future<void> _loadTransactionHistory(
      {SharedPreferences? prefs, bool hasInvestment = true}) async {
    final prefsInstance = prefs ?? await SharedPreferences.getInstance();
    final username = _userNameKey(prefsInstance);
    final receiptsKey = _uKey(username, 'wallet_receipts');
    final receipts = hasInvestment
        ? (prefsInstance.getStringList(receiptsKey) ?? <String>[])
        : <String>[];
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _transactionRetentionDays));
    final retainedStrings = <String>[];
    final parsedTransactions = <Map<String, dynamic>>[];

    for (final encoded in receipts) {
      try {
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        final date = DateTime.tryParse(decoded['date'] as String? ?? '');
        if (date == null || date.isBefore(cutoff)) {
          continue;
        }

        retainedStrings.add(encoded);
        parsedTransactions.add({
          'type': decoded['type'] ?? 'earning',
          'amount': (decoded['amount'] as num?)?.toDouble() ?? 0.0,
          'description': decoded['description'] as String? ?? 'Wallet receipt',
          'date': date,
          'bandwidthSnapshot':
              (decoded['bandwidthSnapshot'] as num?)?.toDouble(),
          'bandwidthPercent': (decoded['bandwidthPercent'] as num?)?.toDouble(),
          'bandwidthMax': (decoded['bandwidthMax'] as num?)?.toDouble(),
        });
      } catch (_) {
        // Ignore malformed entries silently
      }
    }

    parsedTransactions.sort((a, b) {
      final aDate = a['date'] as DateTime;
      final bDate = b['date'] as DateTime;
      return bDate.compareTo(aDate);
    });

    if (hasInvestment && retainedStrings.length != receipts.length) {
      await prefsInstance.setStringList(receiptsKey, retainedStrings);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _transactions
        ..clear()
        ..addAll(parsedTransactions);
    });
  }

  void _startLiveMetricsRefresh() {
    _liveMetricsTimer?.cancel();
    _liveMetricsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollLiveMetrics(),
    );
  }

  Future<void> _pollLiveMetrics() async {
    if (!mounted || _isPollingLiveMetrics) {
      return;
    }

    _isPollingLiveMetrics = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = _userNameKey(prefs);
      final approvedInvestment =
          prefs.getDouble(_uKey(username, 'approved_investment')) ??
              prefs.getDouble(_gKey('approved_investment')) ??
              0.0;
      final hasInvestment = approvedInvestment > 0;
      final latestBalance = hasInvestment
          ? (prefs.getDouble(_uKey(username, 'balance')) ?? 0.0)
          : 0.0;
      final latestActiveDays = hasInvestment
          ? (prefs.getInt(_uKey(username, 'active_days')) ??
              prefs.getInt(_gKey('active_days')) ??
              0)
          : 0;

      if (!mounted) {
        return;
      }

      final shouldUpdateBalance =
          (latestBalance - _totalBalance).abs() > _liveUpdateTolerance;
      final shouldUpdateActiveDays = latestActiveDays != _activeDays;

      if (shouldUpdateBalance || shouldUpdateActiveDays) {
        setState(() {
          if (shouldUpdateBalance) {
            _totalBalance = latestBalance;
          }
          if (shouldUpdateActiveDays) {
            _activeDays = latestActiveDays;
          }
        });
      }
    } finally {
      _isPollingLiveMetrics = false;
    }
  }

  @override
  void dispose() {
    _liveMetricsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF140C2F),
              Color(0xFF1F1147),
              Color(0xFF140C2F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildTransactionHistory(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Spacer(),
          const Text(
            'My Wallet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentPurple,
            _lavenderGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accentPurple.withAlpha((0.45 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.18 * 255).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 24),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.18 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'NGMY Wallet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white.withAlpha((0.9 * 255).round()),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦₲${_totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        '$_activeDays',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Active Days',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.trending_up,
                          color: Colors.white, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        '₦₲${(_totalBalance / (_activeDays > 0 ? _activeDays : 1)).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Avg/Day',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        if (_accountStatus.blocksAllActions) ...[
          _buildAccountStatusBanner(
            'This account is suspended. Wallet actions are temporarily locked.',
            icon: Icons.lock_outline,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
        ] else if (_accountStatus.withdrawOnly) ...[
          _buildAccountStatusBanner(
            'Account disabled: withdrawals remain available while other actions are locked.',
            icon: Icons.lock_open,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Withdraw',
                Icons.north_east,
                Colors.blue.shade400,
                () {
                  _handleWithdrawTap();
                },
                enabled: !_accountStatus.blocksAllActions,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Deposit',
                Icons.south_west,
                Colors.orange.shade400,
                () {
                  _handleDepositTap();
                },
                enabled: !_accountStatus.blocksAllActions &&
                    !_accountStatus.withdrawOnly,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Transfer',
                Icons.swap_horiz,
                Colors.purple.shade400,
                () {
                  _handleTransferTap();
                },
                enabled: !_accountStatus.blocksAllActions &&
                    !_accountStatus.withdrawOnly,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Request',
                Icons.call_received,
                Colors.pink.shade400,
                () {
                  _handleRequestTap();
                },
                enabled: !_accountStatus.blocksAllActions &&
                    !_accountStatus.withdrawOnly,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountStatusBanner(
    String message, {
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha((0.22 * 255).round()),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: color.withAlpha((0.4 * 255).round()), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withAlpha((0.95 * 255).round()),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleWithdrawTap() async {
    if (!await _ensureAccountActionAllowed(
      actionLabel: 'Withdraw funds',
      allowWithdraw: true,
    )) {
      return;
    }
    await _showWithdrawDialog();
  }

  Future<void> _handleDepositTap() async {
    if (!await _ensureAccountActionAllowed(
      actionLabel: 'Deposit funds',
    )) {
      return;
    }
    await _showDepositDialog();
  }

  Future<void> _handleTransferTap() async {
    if (!await _ensureAccountActionAllowed(
      actionLabel: 'Transfer funds',
    )) {
      return;
    }
    await _showTransferDialog();
  }

  Future<void> _handleRequestTap() async {
    if (!await _ensureAccountActionAllowed(
      actionLabel: 'Request funds',
    )) {
      return;
    }
    await _showRequestDialog();
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.08 * 255).round()),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.2 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    final autoDepositTransactions =
        _transactions.where((txn) => txn['type'] == 'auto_deposit').toList();
    final visibleTransactions = autoDepositTransactions.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Transaction History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _transactions.isEmpty ? null : _showAllTransactions,
              child: const Text(
                'See All',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visibleTransactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Daily automatic deposits will appear here',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...visibleTransactions
              .map((transaction) => _buildTransactionItem(transaction)),
      ],
    );
  }

  void _showAllTransactions() {
    if (_transactions.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B3A2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'All Transactions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTransactionItem(transaction),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final isEarning = amount >= 0;
    final date = transaction['date'] as DateTime;
    final description = transaction['description'] as String;
    final bandwidthSnapshot = transaction['bandwidthSnapshot'] as double?;
    final bandwidthPercent = transaction['bandwidthPercent'] as double?;
    final bandwidthMax = transaction['bandwidthMax'] as double?;

    final amountPrefix = isEarning ? '+' : '-';
    final formattedAmount = amount.abs().toStringAsFixed(2);

    String? bandwidthDetails;
    if (bandwidthSnapshot != null) {
      final maxText = bandwidthMax != null && bandwidthMax > 0
          ? ' of ${bandwidthMax.toStringAsFixed(0)} GB'
          : '';
      final percentText = bandwidthPercent != null
          ? ' (${(bandwidthPercent * 100).toStringAsFixed(0)}%)'
          : '';
      bandwidthDetails =
          'Bandwidth: ${bandwidthSnapshot.toStringAsFixed(1)} GB$maxText$percentText';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isEarning ? Colors.green : Colors.red)
                  .withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEarning ? Icons.arrow_downward : Icons.arrow_upward,
              color: isEarning ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.5 * 255).round()),
                    fontSize: 11,
                  ),
                ),
                if (bandwidthDetails != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    bandwidthDetails,
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.6 * 255).round()),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$amountPrefix₦₲$formattedAmount',
            style: TextStyle(
              color: isEarning ? Colors.green : Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWithdrawDialog() async {
    final rootContext = context;
    final rootMessenger = ScaffoldMessenger.maybeOf(rootContext);
    final prefs = await SharedPreferences.getInstance();
    final username = _userNameKey(prefs);
    final savedCashTag =
        await CashTagStorage.load(scope: 'Global', identifier: username);
    String amountText = '';
    String cashTagText =
        savedCashTag?.trim().isNotEmpty == true ? savedCashTag!.trim() : r'$';

    if (!rootContext.mounted) {
      return;
    }

    final result = await showDialog<({double amount, String cashTag})?>(
      context: rootContext,
      builder: (dialogContext) {
        void showErrorSnack(String message) {
          final messenger =
              rootMessenger ?? ScaffoldMessenger.maybeOf(dialogContext);
          messenger?.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }

        return AlertDialog(
          backgroundColor: _panelTint,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  color: _lavenderGlow, size: 28),
              const SizedBox(width: 12),
              const Text('Withdraw Funds',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Balance: ₦₲${_totalBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _lavenderGlow,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    initialValue: amountText,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) => amountText = value.trim(),
                    decoration: InputDecoration(
                      labelText: 'Withdrawal Amount',
                      labelStyle: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                      ),
                      prefixText: '₦₲ ',
                      prefixStyle: TextStyle(
                        color: _lavenderGlow,
                        fontWeight: FontWeight.bold,
                      ),
                      filled: true,
                      fillColor: Colors.white.withAlpha((0.08 * 255).round()),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withAlpha((0.25 * 255).round()),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _accentPurple, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: cashTagText,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) => cashTagText = value.trim(),
                    decoration: InputDecoration(
                      labelText: 'Cash App Tag',
                      labelStyle: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                      ),
                      hintText: r'$YourCashTag',
                      hintStyle: TextStyle(
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                      ),
                      filled: true,
                      fillColor: Colors.white.withAlpha((0.08 * 255).round()),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withAlpha((0.25 * 255).round()),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _accentPurple, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final amount = double.tryParse(amountText);
                final cashTag = cashTagText.trim();

                if (amount == null || amount <= 0) {
                  showErrorSnack('Please enter a valid amount');
                  return;
                }

                if (amount > _totalBalance) {
                  showErrorSnack('Insufficient balance');
                  return;
                }

                if (cashTag.isEmpty || cashTag == r'$') {
                  showErrorSnack('Please enter your Cash App tag');
                  return;
                }

                if (!cashTag.startsWith(r'$')) {
                  showErrorSnack('Cash tag must start with \$');
                  return;
                }

                Navigator.of(dialogContext)
                    .pop((amount: amount, cashTag: cashTag));
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accentPurple),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Withdraw'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      await _submitWithdrawalRequest(result.amount, result.cashTag);
    }
  }

  Future<void> _submitWithdrawalRequest(double amount, String cashTag) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_gKey('user_name')) ??
        prefs.getString('Global_user_name') ??
        'NGMY User';
    final userID = _resolveGlobalUserId(prefs, username);

    await CashTagStorage.save(
      cashTag,
      scope: 'Global',
      identifier: username,
    );

    // Get existing withdrawal requests
    final withdrawalsList = prefs.getStringList(_gKey('withdrawal_requests')) ??
        prefs.getStringList('withdrawal_requests') ??
        <String>[];

    // Create new withdrawal request
    final withdrawal = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'username': username,
      'userID': userID,
      'amount': amount,
      'cashTag': cashTag,
      'status': 'pending',
      'submittedAt': DateTime.now().toIso8601String(),
      'scope': 'global',
    };

    withdrawalsList.add(json.encode(withdrawal));
    await prefs.setStringList(_gKey('withdrawal_requests'), withdrawalsList);
    await prefs.setStringList('withdrawal_requests', withdrawalsList);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Withdrawal request for ₦₲${amount.toStringAsFixed(2)} submitted successfully!'),
        backgroundColor: _accentPurple,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showDepositDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Deposit Funds', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose deposit method:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.monetization_on, color: Colors.green),
                title: const Text('Cash App',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('\$NGMYPay',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _showCashAppDepositFlow();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCashAppDepositFlow() async {
    final cashAppUrl = Uri.parse('https://cash.app/\$NGMYPay');

    // Try to launch Cash App URL
    if (await canLaunchUrl(cashAppUrl)) {
      await launchUrl(cashAppUrl, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Cash App')),
      );
      return;
    }

    // Show confirmation dialog after user returns
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _showDepositConfirmationDialog();
  }

  Future<void> _showDepositConfirmationDialog() async {
    final TextEditingController amountController = TextEditingController();
    File? screenshot;
    final ImagePicker picker = ImagePicker();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0D4D3D),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Deposit',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the amount you sent:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: Colors.white),
                    hintText: '0.00',
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
                const SizedBox(height: 20),
                const Text(
                  'Upload payment screenshot:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                if (screenshot != null) ...[
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(screenshot!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ElevatedButton.icon(
                  onPressed: () async {
                    final XFile? image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() {
                        screenshot = File(image.path);
                      });
                    }
                  },
                  icon: Icon(
                      screenshot != null ? Icons.check_circle : Icons.upload),
                  label: Text(screenshot != null
                      ? 'Screenshot Selected'
                      : 'Select Screenshot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: screenshot != null
                        ? Colors.green
                        : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: () async {
                if (!context.mounted) return;

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid amount')),
                  );
                  return;
                }
                if (screenshot == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please upload payment screenshot')),
                  );
                  return;
                }

                if (!await _ensureAccountActionAllowed(
                  actionLabel: 'Deposit funds',
                )) {
                  return;
                }

                await _submitDepositRequest(amount, screenshot!.path);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDepositRequest(
      double amount, String screenshotPath) async {
    final prefs = await SharedPreferences.getInstance();
    final username = _userNameKey(prefs);

    final storedScreenshotPath = await _persistDepositScreenshot(
      screenshotPath,
      folder: 'Global_deposits',
    );

    if (storedScreenshotPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to read the screenshot file. Please try again.'),
        ),
      );
      return;
    }

    // Get existing deposit requests
    final depositsJson = prefs.getString(_gKey('deposit_requests_json')) ??
        prefs.getString('deposit_requests') ??
        '[]';
    final List<dynamic> deposits = json.decode(depositsJson);

    // Add new deposit request
    deposits.add({
      'username': username,
      'amount': amount,
      'screenshotPath': storedScreenshotPath,
      'screenshot_path': storedScreenshotPath,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
      'scope': 'global',
    });

    final encoded = json.encode(deposits);
    await prefs.setString(_gKey('deposit_requests_json'), encoded);
    await prefs.setString('deposit_requests', encoded);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Deposit request for \$$amount submitted! Awaiting admin approval.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<String?> _persistDepositScreenshot(
    String originalPath, {
    required String folder,
  }) async {
    try {
      final sourceFile = File(originalPath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final baseDir = await getApplicationDocumentsDirectory();
      final proofsRoot =
          Directory('${baseDir.path}${Platform.pathSeparator}ngmy_proofs');
      if (!await proofsRoot.exists()) {
        await proofsRoot.create(recursive: true);
      }

      final targetDir = Directory(
        '${proofsRoot.path}${Platform.pathSeparator}$folder',
      );
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = _sanitizeFileName(_extractFileName(originalPath));
      final destinationPath =
          '${targetDir.path}${Platform.pathSeparator}${timestamp}_$sanitizedName';

      final savedFile = await sourceFile.copy(destinationPath);
      return savedFile.path;
    } catch (error) {
      debugPrint('Failed to persist deposit screenshot: $error');
      return null;
    }
  }

  String _extractFileName(String path) {
    if (path.isEmpty) {
      return 'deposit.png';
    }
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : path;
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'deposit.png' : sanitized;
  }

  Future<void> _showTransferDialog() async {
    final TextEditingController userIDController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.send_to_mobile, color: Colors.blue),
            SizedBox(width: 12),
            Text('Transfer Funds', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recipient User ID',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: userIDController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter user ID',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.3 * 255).round())),
                  prefixIcon: const Icon(Icons.person, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withAlpha((0.3 * 255).round())),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Amount',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.3 * 255).round())),
                  prefixText: '₦₲ ',
                  prefixStyle: const TextStyle(color: Colors.white),
                  prefixIcon:
                      const Icon(Icons.attach_money, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withAlpha((0.3 * 255).round())),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Available balance: ₦₲${_totalBalance.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final recipientUserID = userIDController.text.trim();
              final amount = double.tryParse(amountController.text);

              if (recipientUserID.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter recipient user ID'),
                      backgroundColor: Colors.red),
                );
                return;
              }

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red),
                );
                return;
              }

              if (amount > _totalBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Insufficient balance'),
                      backgroundColor: Colors.red),
                );
                return;
              }

              if (!await _ensureAccountActionAllowed(
                actionLabel: 'Transfer funds',
              )) {
                return;
              }

              if (!context.mounted) {
                return;
              }

              Navigator.pop(context);
              await _processTransfer(recipientUserID, amount);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  Future<void> _processTransfer(String recipientUserID, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final senderUsername = prefs.getString(_gKey('user_name')) ??
        prefs.getString('Global_user_name') ??
        'NGMY User';
    final senderUserID = _resolveGlobalUserId(prefs, senderUsername);

    // Check if recipient exists
    // In a real app, you'd validate this against a user database
    // For now, we'll assume the user ID is valid

    // Deduct from sender
    final newBalance = _totalBalance - amount;
    await prefs.setDouble(_uKey(senderUsername, 'balance'), newBalance);
    await prefs.setDouble(_gKey('total_balance'), newBalance);

    // Create transfer record
    final transfersList = prefs.getStringList(_gKey('transfers')) ??
        prefs.getStringList('transfers') ??
        <String>[];
    final transfer = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'senderUserID': senderUserID,
      'senderUsername': senderUsername,
      'recipientUserID': recipientUserID,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'completed',
    };

    transfersList.add(json.encode(transfer));
    await prefs.setStringList(_gKey('transfers'), transfersList);
    await prefs.setStringList('transfers', transfersList);

    setState(() {
      _totalBalance = newBalance;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Successfully transferred ₦₲${amount.toStringAsFixed(2)} to User ID: $recipientUserID'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showRequestDialog() async {
    final TextEditingController userIDController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.request_page, color: Colors.orange),
            SizedBox(width: 12),
            Text('Request Funds', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request From User ID',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: userIDController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter user ID',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.3 * 255).round())),
                  prefixIcon: const Icon(Icons.person, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withAlpha((0.3 * 255).round())),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.orange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Amount',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha((0.3 * 255).round())),
                  prefixText: '₦₲ ',
                  prefixStyle: const TextStyle(color: Colors.white),
                  prefixIcon:
                      const Icon(Icons.attach_money, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.1 * 255).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withAlpha((0.3 * 255).round())),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.orange, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final fromUserID = userIDController.text.trim();
              final amount = double.tryParse(amountController.text);

              if (fromUserID.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter user ID'),
                      backgroundColor: Colors.red),
                );
                return;
              }

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red),
                );
                return;
              }

              if (!await _ensureAccountActionAllowed(
                actionLabel: 'Request funds',
              )) {
                return;
              }

              if (!context.mounted) {
                return;
              }

              Navigator.pop(context);
              await _sendMoneyRequest(fromUserID, amount);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.request_quote, size: 18),
            label: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMoneyRequest(String fromUserID, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final requesterUsername = _userNameKey(prefs);
    final requesterUserID = _resolveGlobalUserId(prefs, requesterUsername);

    // Create money request
    final requestsList = prefs.getStringList(_gKey('money_requests')) ??
        prefs.getStringList('money_requests') ??
        <String>[];
    final request = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'requesterUserID': requesterUserID,
      'requesterUsername': requesterUsername,
      'fromUserID': fromUserID,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    };

    requestsList.add(json.encode(request));
    await prefs.setStringList(_gKey('money_requests'), requestsList);
    await prefs.setStringList('money_requests', requestsList);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Money request for ₦₲${amount.toStringAsFixed(2)} sent to User ID: $fromUserID'),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
