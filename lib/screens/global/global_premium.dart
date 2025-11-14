import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'global_wallet_screen.dart';
import 'global_stats_screen.dart';
import 'global_profile_screen.dart';
import 'global_investment_join_screen.dart';
import '../../services/global_account_guard.dart';
import '../growth/growth_message_center.dart';
import '../../models/growth_chat_models.dart';
import '../../services/growth_messaging_store.dart';
import '../../services/user_account_service.dart';

class GlobalScreen extends StatefulWidget {
  const GlobalScreen({super.key});

  @override
  State<GlobalScreen> createState() => _GlobalScreenState();
}

class _GlobalScreenState extends State<GlobalScreen> with TickerProviderStateMixin {
  int _currentPageIndex = 0;
  late PageController _pageController;
  
  DateTime? _clockInStartTime;
  DateTime? _lastClockInDate;
  Timer? _timer;
  bool _isClockedIn = false;
  Duration _workDuration = Duration.zero;
  Duration _timeUntilMidnight = Duration.zero;
  bool _isClockInAvailable = false;
  bool _isEndingSession = false;
  
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  final GrowthMessagingStore _messagingStore = GrowthMessagingStore.instance;
  int _unreadMessageCount = 0;
  
  // Realistic earnings data - starts at 0
  double _todayEarnings = 0.0;
  double _totalBalance = 0.0;
  double _bandwidth = 0.0;
  double _sessionStartBandwidth = 0.0; // Bandwidth at start of current session
  final double _maxBandwidth = 50.0; // GB
  int _activeDays = 0;
  double _currentInvestment = 0.0; // Track approved investment
  static const double _dailyReturnRate = 0.0286; // 2.86% per day
  static const double _earningsEpsilon = 0.0001; // Guard tiny floating errors
  static const int _historyRetentionDays = 2;
  static const int _maxWalletReceipts = 50;
  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const Color _deepPurple = Color(0xFF140C2F);
  static const Color _midPurple = Color(0xFF1C1045);
  static const Color _headerTint = Color(0xFF231A4B);
  static const Color _accentPurple = Color(0xFF6C3FDB);
  static const Color _lavenderGlow = Color(0xFFA379FF);
  static const Color _magentaPulse = Color(0xFFD36BFF);
  List<String> _adminWorkingDays = const <String>[];
  bool _isTodayAllowedByAdmin = true;
  
  // Claim system variables
  bool _isClaimOnCooldown = false;
  DateTime? _lastClaimTime;
  Duration _claimCooldownRemaining = Duration.zero;
  double _lastClaimedAmount = 0.0;
  GlobalAccountStatus _accountStatus = const GlobalAccountStatus(
    username: 'NGMY User',
    isDisabled: false,
    isSuspended: false,
  );

  String _uKey(String username, String suffix) => '${username}_global_$suffix';
  String _gKey(String suffix) => 'global_$suffix';

  Future<bool> _ensureAccountActionAllowed({
    bool allowWithdraw = false,
    required String actionLabel,
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
    _pageController = PageController(initialPage: 0);
    _loadClockInData();
    _startTimer();
    Future.microtask(() async {
      final status = await GlobalAccountGuard.load();
      if (!mounted) return;
      setState(() {
        _accountStatus = status;
      });
    });
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _initMessagingBadges();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload balance whenever screen is shown
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('Global_user_name') ?? 'NGMY User';
    final savedBalance =
        prefs.getDouble(_uKey(username, 'balance')) ??
            prefs.getDouble(_gKey('total_balance')) ??
            0.0;
    
    if (mounted && savedBalance != _totalBalance) {
      setState(() {
        _totalBalance = savedBalance;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _messagingStore.removeListener(_handleMessagingStoreChanged);
    super.dispose();
  }

  void _initMessagingBadges() {
    _messagingStore.addListener(_handleMessagingStoreChanged);
    Future.microtask(() async {
      await UserAccountService.instance.initialize();
      await _messagingStore.load();
      if (!mounted) {
        return;
      }
      _updateUnreadBadge();
    });
  }

  void _handleMessagingStoreChanged() {
    if (!mounted) {
      return;
    }
    _updateUnreadBadge();
  }

  void _updateUnreadBadge() {
    final user = UserAccountService.instance.currentUser;
    if (user == null) {
      if (_unreadMessageCount != 0) {
        setState(() {
          _unreadMessageCount = 0;
        });
      }
      return;
    }

    final count =
        _messagingStore.totalUnreadForScope(user.id, GrowthChatScope.global);
    if (count != _unreadMessageCount) {
      setState(() {
        _unreadMessageCount = count;
      });
    }
  }

  Widget _buildMessagingBell({
    required int unreadCount,
    required VoidCallback onTap,
    Color badgeColor = _accentPurple,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Unread',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withAlpha((0.45 * 255).round()),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadClockInData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // Get current username
    final username = prefs.getString('Global_user_name') ?? 'NGMY User';
    final accountStatus =
        await GlobalAccountGuard.load(prefs: prefs, username: username);
    final adminWorkingDays = prefs.getStringList('admin_working_days') ?? [];
    final todayName = _weekdayNames[now.weekday - 1];
    final todayAllowedByAdmin =
        adminWorkingDays.isEmpty || adminWorkingDays.contains(todayName);
    
    // Read from user-specific keys first, fallback to global
    final clockInStartString =
        prefs.getString(_uKey(username, 'clock_in_start_time')) ??
            prefs.getString(_gKey('clock_in_start'));
    final lastClockInDateString =
        prefs.getString(_uKey(username, 'last_clock_in')) ??
            prefs.getString(_gKey('last_clock_in_date'));
    final savedBalance =
        prefs.getDouble(_uKey(username, 'balance')) ??
            prefs.getDouble(_gKey('total_balance')) ??
            0.0;
    final savedActiveDays =
        prefs.getInt(_uKey(username, 'active_days')) ??
            prefs.getInt(_gKey('active_days')) ??
            0;
    final savedLastClaimed =
        prefs.getDouble(_uKey(username, 'last_claimed_amount')) ?? 0.0;

    // ALWAYS load today's earnings from storage (so it persists when app reopens)
    final savedTodayEarnings =
        prefs.getDouble(_uKey(username, 'today_earnings')) ?? 0.0;

    // ALWAYS load today's bandwidth from storage and NEVER reset it
    // Bandwidth should accumulate continuously without ever resetting
    final savedTodayBandwidth =
        prefs.getDouble(_uKey(username, 'today_bandwidth')) ?? 0.0;
    final approvedInvestment =
        prefs.getDouble(_uKey(username, 'approved_investment')) ??
            prefs.getDouble(_gKey('approved_investment')) ??
            0.0;
    
    if (mounted) {
      setState(() {
        _todayEarnings = savedTodayEarnings;
        _bandwidth = savedTodayBandwidth;
        _totalBalance = savedBalance;
        _activeDays = savedActiveDays;
        _currentInvestment = approvedInvestment;
        _lastClaimedAmount = savedLastClaimed;
        _accountStatus = accountStatus;
        _adminWorkingDays = adminWorkingDays;
        _isTodayAllowedByAdmin = todayAllowedByAdmin;
      });
    }
    
  // Load claim cooldown state
  final lastClaimTimeString =
    prefs.getString(_uKey(username, 'last_claim_time'));
    if (lastClaimTimeString != null) {
      final lastClaimTime = DateTime.parse(lastClaimTimeString);
      final cooldownEnd = lastClaimTime.add(const Duration(minutes: 1));
      
      if (now.isBefore(cooldownEnd)) {
        // Still on cooldown
        setState(() {
          _isClaimOnCooldown = true;
          _lastClaimTime = lastClaimTime;
          _claimCooldownRemaining = cooldownEnd.difference(now);
        });
      } else {
        // Cooldown expired, clear it
    await prefs.remove(_uKey(username, 'last_claim_time'));
      }
    }
    
    // Check if user already clocked in today
    if (lastClockInDateString != null) {
      _lastClockInDate = DateTime.parse(lastClockInDateString);
      final today = DateTime.now();
      
      // If clock-in was today, disable button
      if (_lastClockInDate!.year == today.year &&
          _lastClockInDate!.month == today.month &&
          _lastClockInDate!.day == today.day) {
        setState(() {
          _isClockInAvailable = false;
        });
      }
    }
    
    // Check if currently clocked in
    if (clockInStartString != null) {
      _clockInStartTime = DateTime.parse(clockInStartString);
      setState(() {
        _isClockedIn = true;
      });
    }
    
    // Check if it's past midnight (clock-in available)
    _checkMidnightAvailability();
  }

  void _checkMidnightAvailability() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final previousTimeUntilMidnight = _timeUntilMidnight;
    _timeUntilMidnight = tomorrow.difference(now);
    
    // Detect when midnight countdown hits zero (crosses from positive to zero/negative)
    // This ensures earnings reset at the EXACT same time as "Next Clock In" resets
    final crossedMidnight = previousTimeUntilMidnight.inSeconds > 0 && _timeUntilMidnight.inSeconds >= 86000; // Reset happened
    
    // Check if user hasn't clocked in today yet
    final isNewDay = _lastClockInDate == null ||
        _lastClockInDate!.year != now.year ||
        _lastClockInDate!.month != now.month ||
        _lastClockInDate!.day != now.day;
    
    final todayName = _weekdayNames[now.weekday - 1];
    final todayAllowedByAdmin =
        _adminWorkingDays.isEmpty || _adminWorkingDays.contains(todayName);
    final canClockIn =
        !_accountStatus.blocksAllActions && !_accountStatus.withdrawOnly && todayAllowedByAdmin;
    setState(() {
      _isTodayAllowedByAdmin = todayAllowedByAdmin;
      _isClockInAvailable = isNewDay && canClockIn;
    });
    
    // CRITICAL FIX: Only reset earnings when we detect actual midnight crossing
    // NOT when app is reopened during the same day
    if (crossedMidnight) {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('Global_user_name') ?? 'NGMY User';
      final refreshedWorkingDays =
          prefs.getStringList('admin_working_days') ?? _adminWorkingDays;
      final refreshedTodayAllowed = refreshedWorkingDays.isEmpty ||
          refreshedWorkingDays.contains(_weekdayNames[now.weekday - 1]);
      if (mounted) {
        setState(() {
          _adminWorkingDays = refreshedWorkingDays;
          _isTodayAllowedByAdmin = refreshedTodayAllowed;
        });
      }
      
      // Check if we already reset today (prevent multiple resets)
      final lastResetDate =
          prefs.getString(_uKey(username, 'last_earnings_reset_date'));
      final todayDateString = '${now.year}-${now.month}-${now.day}';
      
      if (lastResetDate != todayDateString) {
        // Save yesterday's earnings for history tracking
        await prefs.setDouble(
            _uKey(username, 'yesterday_earnings'), _todayEarnings);
        await prefs.setString(
            _uKey(username, 'last_earnings_reset_date'), todayDateString);
        
        // Clear only today's earnings from storage (NOT bandwidth - it should continue accumulating)
        await prefs.setDouble(_uKey(username, 'today_earnings'), 0.0);
        // DO NOT reset bandwidth - it should accumulate continuously without ever resetting
        
        // Now reset only today's earnings for the new day (keep bandwidth)
        setState(() {
          _todayEarnings = 0.0;
          // DO NOT reset _bandwidth - it should continue from where it was
        });
      }
    }
  }

  Future<void> _clearClaimCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('Global_user_name') ?? 'NGMY User';
    await prefs.remove(_uKey(username, 'last_claim_time'));
  }

  Future<void> _addWalletReceipt({
    required SharedPreferences prefs,
    required String type,
    required double amount,
    required String description,
    required double bandwidthSnapshot,
  }) async {
    if (amount <= 0) {
      return;
    }

    final username = prefs.getString('Global_user_name') ?? 'NGMY User';
    final receiptsKey = _uKey(username, 'wallet_receipts');
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: _historyRetentionDays));
    final existing = prefs.getStringList(receiptsKey) ?? <String>[];
    final retained = <String>[];

    for (final encoded in existing) {
      try {
        final parsed = jsonDecode(encoded) as Map<String, dynamic>;
        final date = DateTime.tryParse(parsed['date'] as String? ?? '');
        if (date != null && !date.isBefore(cutoff)) {
          retained.add(encoded);
        }
      } catch (_) {
        // Ignore malformed entries
      }
    }

    final percent = _maxBandwidth <= 0 ? 0.0 : bandwidthSnapshot / _maxBandwidth;
    final boundedPercent = math.min(1.0, math.max(0.0, percent));

    retained.insert(0, jsonEncode({
      'date': now.toIso8601String(),
      'type': type,
      'amount': amount,
      'description': description,
      'bandwidthSnapshot': bandwidthSnapshot,
      'bandwidthPercent': boundedPercent,
      'bandwidthMax': _maxBandwidth,
    }));

    if (retained.length > _maxWalletReceipts) {
      retained.removeRange(_maxWalletReceipts, retained.length);
    }

    await prefs.setStringList(receiptsKey, retained);
  }

  Future<void> _endWorkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('Global_user_name') ?? 'NGMY User';
    
  // Get balance before session
    final balanceBefore =
        prefs.getDouble(_uKey(username, 'balance_before_session')) ??
            _totalBalance;

  // Re-load authoritative earnings + caps from storage to eliminate race conditions
    final storedTodayEarnings =
        prefs.getDouble(_uKey(username, 'today_earnings')) ?? _todayEarnings;
    final storedClaimedAmount =
        prefs.getDouble(_uKey(username, 'last_claimed_amount')) ??
            _lastClaimedAmount;
    final dailyIncomeAfterPenalty =
        prefs.getDouble(_uKey(username, 'daily_income_after_penalty')) ??
            (_currentInvestment * _dailyReturnRate);

  // If the full 2-hour session completed, force earnings to match the post-penalty allowance
  const fullSessionDuration = Duration(hours: 2);
  final bool sessionCompleted = _workDuration >= fullSessionDuration;

  double finalSessionEarnings = math.max(_todayEarnings, storedTodayEarnings);
  if (sessionCompleted) {
    finalSessionEarnings = math.max(finalSessionEarnings, dailyIncomeAfterPenalty);
  }

  // Clamp already-claimed amount so it never exceeds the final session earnings
  final double adjustedClaimed = math.min(storedClaimedAmount, finalSessionEarnings);

  // Calculate how much hasn't been delivered yet
  final double rawRemaining = finalSessionEarnings - adjustedClaimed;
  final double remainingEarnings =
    rawRemaining > _earningsEpsilon ? rawRemaining : 0.0;

  // Mirror the authoritative earnings in state so the UI stays in sync
  _todayEarnings = finalSessionEarnings;
  _lastClaimedAmount = adjustedClaimed;

  if (remainingEarnings > 0) {
      final newBalance = _totalBalance + remainingEarnings;
      
      // Track total lifetime earnings
    final currentTotalEarnings =
      prefs.getDouble(_uKey(username, 'total_earnings')) ?? 0.0;
      final newTotalEarnings = currentTotalEarnings + remainingEarnings;
  await prefs.setDouble(_uKey(username, 'total_earnings'), newTotalEarnings);
      
      // Save new balance
    await prefs.setDouble(_gKey('total_balance'), newBalance);
    await prefs.setDouble(_uKey(username, 'balance'), newBalance);
      
      // Log work session completion with balance changes
  final workHistory =
      prefs.getStringList(_uKey(username, 'work_session_history')) ?? [];
      final sessionRecord = jsonEncode({
        'date': DateTime.now().toIso8601String(),
        'balanceBefore': balanceBefore,
        'balanceAfter': newBalance,
        'earnings': remainingEarnings,
        'sessionType': 'auto_deposit_remaining_earnings',
      });
      workHistory.insert(0, sessionRecord);
      
      // Keep only last 30 records
      if (workHistory.length > 30) {
        workHistory.removeRange(30, workHistory.length);
      }
  await prefs.setStringList(
      _uKey(username, 'work_session_history'), workHistory);
      
      await _addWalletReceipt(
        prefs: prefs,
        type: 'auto_deposit',
        amount: remainingEarnings,
        description: 'Daily auto deposit',
        bandwidthSnapshot: _bandwidth,
      );

      setState(() {
        _totalBalance = newBalance;
        _todayEarnings = finalSessionEarnings;
        _lastClaimedAmount = finalSessionEarnings;
      });
    }
    
    // Clear clock-in session
    await prefs.remove(_uKey(username, 'clock_in_start_time'));
    await prefs.remove(_gKey('clock_in_start'));
    await prefs.remove(_uKey(username, 'balance_before_session'));
    
    // CRITICAL: Update last claimed amount to current total earnings
    // This means after session ends, all earnings are considered "claimed"
    await prefs.setDouble(
        _uKey(username, 'last_claimed_amount'), _todayEarnings);

    // SAVE today's earnings so it persists until midnight reset
  await prefs.setDouble(
    _uKey(username, 'today_earnings'), _todayEarnings);
    
    setState(() {
      _isClockedIn = false;
      _clockInStartTime = null;
      _isClockInAvailable = false; // Can't clock in again until midnight
      _lastClaimedAmount = _todayEarnings; // Update in memory too
      // DON'T reset _todayEarnings - keep displaying until midnight reset
      _workDuration = Duration.zero;
      _isEndingSession = false;
      _sessionStartBandwidth = _bandwidth;
    });
    
  // Calculate previous balance for display
  final previousBalance = _totalBalance - remainingEarnings;
    
    if (mounted) {
      final message = remainingEarnings > 0 
          ? '2-hour session complete! ₦₲${_formatCurrency(remainingEarnings)} auto-deposited to balance.\n'
            'Previous Balance: ₦₲${_formatCurrency(previousBalance)}\n'
            'New Balance: ₦₲${_formatCurrency(_totalBalance)}\n'
            'Today\'s Total Earnings: ₦₲${_formatCurrency(_todayEarnings)}\n'
            'Next clock-in available at midnight.'
          : '2-hour session complete! All earnings were already claimed. Next clock-in available at midnight.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _accentPurple,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      var shouldEndSession = false;
      const twoHourDuration = Duration(hours: 2);

      setState(() {
        // Update time until midnight
        _checkMidnightAvailability();

        // Check claim cooldown
        if (_isClaimOnCooldown && _lastClaimTime != null) {
          final cooldownEnd = _lastClaimTime!.add(const Duration(minutes: 1));
          final now = DateTime.now();
          if (now.isBefore(cooldownEnd)) {
            _claimCooldownRemaining = cooldownEnd.difference(now);
          } else {
            _isClaimOnCooldown = false;
            _claimCooldownRemaining = Duration.zero;
            // Clear cooldown from storage when it expires
            _clearClaimCooldown();
          }
        }

        if (_isClockedIn && _clockInStartTime != null) {
          final now = DateTime.now();
          final rawDuration = now.difference(_clockInStartTime!);
          final cappedDuration = rawDuration > twoHourDuration ? twoHourDuration : rawDuration;
          _workDuration = cappedDuration;

          // Calculate earnings based on approved investment (2.86% daily return)
          if (_currentInvestment > 0) {
            final workProgress = cappedDuration.inSeconds / twoHourDuration.inSeconds;

            // Load daily income after penalty (if penalty was applied)
            SharedPreferences.getInstance().then((prefs) async {
              final username = prefs.getString('Global_user_name') ?? 'NGMY User';
              final dailyIncomeAfterPenalty =
          prefs.getDouble(_uKey(username, 'daily_income_after_penalty')) ??
            (_currentInvestment * _dailyReturnRate);

              // Calculate today's earnings based on work progress and PENALIZED daily income
              final calculatedEarnings = dailyIncomeAfterPenalty * workProgress;

              // Save to SharedPreferences so it persists when app closes
        await prefs.setDouble(
          _uKey(username, 'today_earnings'), calculatedEarnings);

              if (!mounted) return;
              setState(() {
                _todayEarnings = calculatedEarnings;
              });
            });

            if (!_isEndingSession && rawDuration >= twoHourDuration) {
              _isEndingSession = true;
              shouldEndSession = true;
            }
          } else {
            // No investment = no earnings
            _todayEarnings = 0.0;
          }

          // Simulate bandwidth usage: ~10 MB per minute (add to existing daily bandwidth)
          final sessionBandwidth = (_workDuration.inMinutes * 0.01); // This session's bandwidth
          final newTotalBandwidth = math.min(_sessionStartBandwidth + sessionBandwidth, _maxBandwidth);

          if (newTotalBandwidth != _bandwidth) {
            _bandwidth = newTotalBandwidth;
            // Save updated bandwidth to SharedPreferences so it persists when app closes
            SharedPreferences.getInstance().then((prefs) async {
              final username = prefs.getString('Global_user_name') ?? 'NGMY User';
              await prefs.setDouble(
                  _uKey(username, 'today_bandwidth'), _bandwidth);
            });
          }
        }
      });

      if (shouldEndSession) {
        Future.microtask(_endWorkSession);
      }
    });
  }

  Future<void> _handleClockIn() async {
    if (!await _ensureAccountActionAllowed(actionLabel: 'Clock in')) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final adminWorkingDays = prefs.getStringList('admin_working_days') ?? [];
    final todayName = _weekdayNames[now.weekday - 1];
    final todayAllowed =
        adminWorkingDays.isEmpty || adminWorkingDays.contains(todayName);

    if (mounted) {
      setState(() {
        _adminWorkingDays = adminWorkingDays;
        _isTodayAllowedByAdmin = todayAllowed;
      });
    }

    if (!todayAllowed) {
      if (!mounted) return;
      final availableDays = adminWorkingDays.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            availableDays.isEmpty
                ? 'Clock-in is closed for today.'
                : 'Clock-in is closed on $todayName. Active days: $availableDays',
          ),
          backgroundColor: _magentaPulse,
        ),
      );
      return;
    }
    
    // Check if user has an approved investment
    if (_currentInvestment <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please join an investment plan first to start earning!'),
          backgroundColor: _magentaPulse,
          action: SnackBarAction(
            label: 'Join Now',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to Join tab
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GlobalInvestmentJoinScreen()),
              );
            },
          ),
        ),
      );
      return;
    }
    
    if (!_isClockInAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Clock-in available at midnight. Wait ${_formatDuration(_timeUntilMidnight)}'),
          backgroundColor: _magentaPulse,
        ),
      );
      return;
    }
    
    // Get current username
    final username = prefs.getString('Global_user_name') ?? 'NGMY User';
    
    // Check if this is an admin-initiated clock-in reset
  final isAdminReset = prefs.getBool(_uKey(username, 'admin_clock_reset')) ??
             prefs.getBool(_gKey('admin_clock_reset')) ??
                         false;
    
    // ===== CHECK-IN PENALTY ENFORCEMENT (Terms of Service Section 2) =====
    // Calculate midnight for today (12:00 AM)
    final todayMidnight = DateTime(now.year, now.month, now.day, 0, 0, 0);

    // Penalty is now based on daily income, not total balance
    double penaltyPercentage = 0.0;
    String penaltyReason = '';
    bool isLate = false;
    double dailyIncome = _currentInvestment * _dailyReturnRate;
    int minutesLate = 0;

    // Only apply penalty if this is NOT an admin reset
    if (!isAdminReset && now.isAfter(todayMidnight)) {
      minutesLate = now.difference(todayMidnight).inMinutes;
      if (minutesLate >= 15 && minutesLate < 30) {
        // 15-29 minutes late: 25% penalty
        penaltyPercentage = 0.25;
        penaltyReason = 'Late check-in ($minutesLate min after midnight, 25% penalty)';
        isLate = true;
      } else if (minutesLate >= 30) {
        // 30+ minutes late: 35% penalty
        penaltyPercentage = 0.35;
        penaltyReason = 'Late check-in ($minutesLate min after midnight, 35% penalty)';
        isLate = true;
      }
    }
    
    // Clear the admin reset flag after checking (one-time use)
    if (isAdminReset) {
      await prefs.remove(_uKey(username, 'admin_clock_reset'));
      await prefs.remove(_gKey('admin_clock_reset'));
    }

    // Apply penalty if user is late AND has an active investment
    double penaltyAmount = 0.0;
    double dailyIncomeAfterPenalty = dailyIncome; // Track daily income after penalty
    if (isLate && penaltyPercentage > 0 && _currentInvestment > 0 && dailyIncome > 0) {
      // Calculate penalty based on daily income
      penaltyAmount = dailyIncome * penaltyPercentage;
      
      // Verify calculation (debug check)
      final calculatedPenalty = dailyIncome * penaltyPercentage;
      if ((penaltyAmount - calculatedPenalty).abs() > 0.01) {
        // Log calculation error (only in debug mode)
        assert(() {
          // Use debugPrint instead of print for production safety
          debugPrint('PENALTY CALCULATION ERROR: Expected ${calculatedPenalty.toStringAsFixed(2)}, got ${penaltyAmount.toStringAsFixed(2)}');
          return true;
        }());
      }
      
      // Calculate balance before (current balance before any daily income)
      final balanceBefore = _totalBalance;
      
      // Calculate daily income after penalty is deducted
      dailyIncomeAfterPenalty = math.max(0.0, dailyIncome - penaltyAmount);
      final balanceAfter = _totalBalance + dailyIncomeAfterPenalty;

      // Store the REDUCED daily income (after penalty) so it will be shown in "Today's Money"
      // This money will stay visible until midnight reset
      // NOTE: We're not setting _todayEarnings here yet, it will accumulate during work progress

      // Store the REDUCED daily income (after penalty) so it will be shown in "Today's Money"
      // This money will stay visible until midnight reset
      // NOTE: We're not setting _todayEarnings here yet, it will accumulate during work progress

      // Log penalty in history
  final penaltyKey = _uKey(username, 'penalty_history');
      final existingPenalties = prefs.getStringList(penaltyKey) ?? <String>[];
      final cutoff = now.subtract(const Duration(days: _historyRetentionDays));
      final retainedPenalties = <String>[];

      for (final encoded in existingPenalties) {
        try {
          final parsed = jsonDecode(encoded) as Map<String, dynamic>;
          final date = DateTime.tryParse(parsed['date'] as String? ?? '');
          if (date != null && !date.isBefore(cutoff)) {
            retainedPenalties.add(encoded);
          }
        } catch (_) {
          // Ignore malformed entries
        }
      }

      final penaltyRecord = jsonEncode({
        'date': now.toIso8601String(),
        'reason': penaltyReason,
        'percentage': '${(penaltyPercentage * 100).toStringAsFixed(0)}%',
        'amount': penaltyAmount,
        'dailyIncome': dailyIncome,
        'earningsAfterPenalty': dailyIncomeAfterPenalty,
        'balanceBefore': balanceBefore, // Balance BEFORE daily income added
        'balanceAfter': balanceAfter, // Balance AFTER daily income added minus penalty
      });
      retainedPenalties.insert(0, penaltyRecord);

      // Keep only last 30 penalty records
      if (retainedPenalties.length > 30) {
        retainedPenalties.removeRange(30, retainedPenalties.length);
      }

      await prefs.setStringList(penaltyKey, retainedPenalties);

      // Send notification to user's notification center
    final globalNotifications =
      prefs.getStringList(_uKey(username, 'notifications')) ?? [];
      final notificationRecord = jsonEncode({
        'id': now.millisecondsSinceEpoch.toString(),
        'title': 'Late Check-In Penalty',
  'message': 'You checked in $minutesLate minutes late. A ${(penaltyPercentage * 100).toStringAsFixed(0)}% penalty (₦₲${_formatCurrency(penaltyAmount)}) was deducted from your daily income. Your earnings for today: ₦₲${_formatCurrency(dailyIncomeAfterPenalty)}.',
        'type': 'penalty',
        'timestamp': now.toIso8601String(),
        'read': false,
      });
  globalNotifications.insert(0, notificationRecord);
      
      // Keep only last 50 notifications
      if (globalNotifications.length > 50) {
        globalNotifications.removeRange(50, globalNotifications.length);
      }
      
      await prefs.setStringList(
          _uKey(username, 'notifications'), globalNotifications);

      // Show penalty notification with detailed math
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Late Check-In Penalty Applied!\n'
              'Daily Income: ₦₲${_formatCurrency(dailyIncome)}\n'
              'Penalty (${(penaltyPercentage * 100).toStringAsFixed(0)}%): ₦₲${_formatCurrency(penaltyAmount)}\n'
              'Earnings After Penalty: ₦₲${_formatCurrency(dailyIncomeAfterPenalty)}\n'
              'Balance Before: ₦₲${_formatCurrency(balanceBefore)}\n'
              'Expected Balance After: ₦₲${_formatCurrency(balanceAfter)}',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
    
    // Save the daily income after penalty to SharedPreferences so timer can use it
  await prefs.setDouble(
    _uKey(username, 'daily_income_after_penalty'), dailyIncomeAfterPenalty);

    if (mounted && _todayEarnings > dailyIncomeAfterPenalty) {
      setState(() {
        _todayEarnings = dailyIncomeAfterPenalty;
      });
    }

    // Ensure last claimed amount never exceeds the adjusted income cap
  final storedClaimed =
    prefs.getDouble(_uKey(username, 'last_claimed_amount')) ?? 0.0;
    if (storedClaimed > dailyIncomeAfterPenalty) {
    await prefs.setDouble(
      _uKey(username, 'last_claimed_amount'), dailyIncomeAfterPenalty);
      if (mounted && _lastClaimedAmount > dailyIncomeAfterPenalty) {
        setState(() {
          _lastClaimedAmount = dailyIncomeAfterPenalty;
        });
      }
    }
    
    // Check if this is a new day (24-hour cycle completed) and user has investment
    // Only increment active days if user has an approved investment
    int newActiveDays = _activeDays;
    bool isNewDay = false;
    if (_currentInvestment > 0 && _lastClockInDate != null) {
      // Check if last clock-in was on a previous day
      final lastClockIn = _lastClockInDate!;
      if (lastClockIn.year != now.year || 
          lastClockIn.month != now.month || 
          lastClockIn.day != now.day) {
        // Full 24-hour cycle completed, increment day
        newActiveDays = _activeDays + 1;
        isNewDay = true;
        
        // Save the incremented active days
  await prefs.setInt(_uKey(username, 'active_days'), newActiveDays);
  await prefs.setInt(_gKey('active_days'), newActiveDays);
      }
    }
    
    // Clock in and start session - save to BOTH user-specific and global keys
  await prefs.setString(
    _uKey(username, 'clock_in_start_time'), now.toIso8601String());
  await prefs.setString(
    _uKey(username, 'last_clock_in'), now.toIso8601String());
  await prefs.setString(_gKey('clock_in_start'), now.toIso8601String());
  await prefs.setString(_gKey('last_clock_in_date'), now.toIso8601String());
    
    // Save balance before starting work session
  await prefs.setDouble(
    _uKey(username, 'balance_before_session'), _totalBalance);
    
    // Reset last claimed amount for new day
  await prefs.setDouble(_uKey(username, 'last_claimed_amount'), 0.0);
    
    // Store current bandwidth at session start
    _sessionStartBandwidth = _bandwidth;
    
    setState(() {
      _isClockedIn = true;
      _clockInStartTime = now;
      _lastClockInDate = now;
      _isClockInAvailable = false;
      _workDuration = Duration.zero;
      // DON'T reset _todayEarnings here - it should only reset at midnight
      // _todayEarnings will start accumulating based on work progress
      _lastClaimedAmount = 0.0; // Reset for new day
      // DON'T reset _bandwidth here - it should persist throughout the day until midnight reset
      // _bandwidth will continue from where it left off during previous work sessions
      _activeDays = newActiveDays; // Update active days count
    });
    
    if (mounted) {
      final dayMessage = isNewDay 
          ? ' Day $newActiveDays started!' 
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Clocked in! Earning 2.86% of \$${_formatCurrency(_currentInvestment, decimals: 0)} daily.$dayMessage'),
          backgroundColor: _accentPurple,
        ),
      );
    }
  }

  Future<void> _claimEarnings() async {
    if (!_isClockedIn) return;
    if (_isClaimOnCooldown) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait ${_claimCooldownRemaining.inSeconds} seconds before claiming again'),
            backgroundColor: _magentaPulse,
          ),
        );
      }
      return;
    }

    if (!await _ensureAccountActionAllowed(actionLabel: 'Claim earnings')) {
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    
    // Calculate only the NEW earnings since last claim
    final rawNewEarnings = _todayEarnings - _lastClaimedAmount;
    final newEarningsSinceLastClaim = rawNewEarnings > _earningsEpsilon ? rawNewEarnings : 0.0;
    
    // Only proceed if there are new earnings to claim
    if (newEarningsSinceLastClaim <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No new earnings to claim yet. Keep working!'),
            backgroundColor: _magentaPulse,
          ),
        );
      }
      return;
    }
    
    // Get current username
    final username = prefs.getString('Global_user_name') ?? 'NGMY User';

    // Get balance before this claim
    final previousBalance = _totalBalance;
    final newBalance = previousBalance + newEarningsSinceLastClaim;
    
    // Track total lifetime earnings (separate from balance)
  final currentTotalEarnings =
    prefs.getDouble(_uKey(username, 'total_earnings')) ?? 0.0;
    final newTotalEarnings = currentTotalEarnings + newEarningsSinceLastClaim;
  await prefs.setDouble(_uKey(username, 'total_earnings'), newTotalEarnings);
    
    // Update last claimed amount to current total earnings
  await prefs.setDouble(_uKey(username, 'last_claimed_amount'), _todayEarnings);
    
    // Save to global keys (current session)
  await prefs.setDouble(_gKey('total_balance'), newBalance);
    
    // ALSO save to user-specific keys (permanent record)
  await prefs.setDouble(_uKey(username, 'balance'), newBalance);
    
    // Log this claim in work session history
  final workHistory =
    prefs.getStringList(_uKey(username, 'work_session_history')) ?? [];
    final sessionRecord = jsonEncode({
      'date': DateTime.now().toIso8601String(),
      'balanceBefore': previousBalance,
      'balanceAfter': newBalance,
      'earnings': newEarningsSinceLastClaim,
      'sessionType': 'manual_claim',
    });
    workHistory.insert(0, sessionRecord);
    
    // Keep only last 30 records
    if (workHistory.length > 30) {
      workHistory.removeRange(30, workHistory.length);
    }
  await prefs.setStringList(
    _uKey(username, 'work_session_history'), workHistory);
    
    await _addWalletReceipt(
      prefs: prefs,
      type: 'manual_claim',
      amount: newEarningsSinceLastClaim,
      description: 'Manual claim deposit',
      bandwidthSnapshot: _bandwidth,
    );

    // Start cooldown
    final now = DateTime.now();
    
    // Save cooldown time to SharedPreferences
  await prefs.setString(
    _uKey(username, 'last_claim_time'), now.toIso8601String());
    
    setState(() {
      _totalBalance = newBalance;
      _lastClaimedAmount = _todayEarnings; // Update in memory
      _isClaimOnCooldown = true;
      _lastClaimTime = now;
      _claimCooldownRemaining = const Duration(minutes: 1);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claimed ₦₲${_formatCurrency(newEarningsSinceLastClaim)}!\n'
            'Previous Balance: ₦₲${_formatCurrency(previousBalance)}\n'
            'New Balance: ₦₲${_formatCurrency(newBalance)}\n'
            'Today\'s Total Earnings: ₦₲${_formatCurrency(_todayEarnings)}'
          ),
          backgroundColor: _accentPurple,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content - full screen
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Disable swipe, only tab navigation
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
              // Refresh balance when changing pages
              _refreshBalance();
            },
            children: [
              _buildHomePage(),
              const GlobalInvestmentJoinScreen(),
              const GlobalWalletScreen(),
              const GlobalStatsScreen(),
              const GlobalProfileScreen(),
            ],
          ),
          // Floating header - positioned over content (only show on Home tab)
          if (_currentPageIndex == 0) 
            Positioned(
              left: 0,
              right: 0,  
              top: 0,
              child: _buildHeader(),
            ),
          // Floating bottom nav
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _deepPurple,
            _midPurple,
            _deepPurple,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 120), // Extra top padding for floating header and bottom padding for floating nav
                child: Column(
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    _buildClockInCard(),
                    const SizedBox(height: 24),
                    _buildBandwidthCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGlobalMessagingStudio() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GrowthMessagingScreen(
          scope: GrowthChatScope.global,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    _updateUnreadBadge();
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
        child: Container(
          decoration: BoxDecoration(
            color: _headerTint.withAlpha((0.95 * 255).round()),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.4 * 255).round()),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _accentPurple.withAlpha((0.25 * 255).round()),
                blurRadius: 30,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: Colors.white.withAlpha((0.15 * 255).round()),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Global Income',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    _buildMessagingBell(
                      unreadCount: _unreadMessageCount,
                      onTap: () {
                        _openGlobalMessagingStudio();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final hasInvestment = _currentInvestment > 0;
    final todayDisplay = hasInvestment ? _todayEarnings : 0.0;
    final balanceDisplay = hasInvestment ? _totalBalance : 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Today',
            '₦₲${_formatCurrency(todayDisplay)}',
            Icons.trending_up,
            _accentPurple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Balance',
            '₦₲${_formatCurrency(balanceDisplay)}',
            Icons.account_balance_wallet,
            _lavenderGlow,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockInCard() {
    final hasInvestment = _currentInvestment > 0;
    final sessionEarnings = hasInvestment ? _todayEarnings : 0.0;
    final sessionBandwidth = hasInvestment ? _bandwidth : 0.0;
    final sessionDays = hasInvestment ? _activeDays : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Timer Display
          Stack(
            alignment: Alignment.center,
            children: [
              // Animated background circles
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 260 + (_pulseController.value * 20),
                    height: 260 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_isClockedIn ? _magentaPulse : Colors.grey)
                            .withAlpha((0.2 * 255 * (1 - _pulseController.value)).round()),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              // Main circle
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isClockedIn
                        ? [_accentPurple, _lavenderGlow]
                        : [_headerTint, _deepPurple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isClockedIn ? _accentPurple : Colors.black)
                          .withAlpha((0.5 * 255).round()),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating border effect
                    if (_isClockedIn)
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationController.value * 2 * math.pi,
                            child: Container(
                              width: 240,
                              height: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withAlpha((0.3 * 255).round()),
                                  width: 2,
                                ),
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withAlpha((0.5 * 255).round()),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    // Timer text
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isClockedIn ? Icons.access_time : Icons.power_settings_new,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isClockedIn ? _formatDuration(_workDuration) : '00:00:00',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isClockedIn 
                              ? 'Active Session' 
                              : _isClockInAvailable 
                                  ? 'Ready to Start' 
                                  : 'Next at Midnight',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          if (_isClockedIn) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Earning', '₦₲${_formatCurrency(sessionEarnings)}'),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                ),
                _buildMiniStat('Bandwidth', '${sessionBandwidth.toStringAsFixed(1)} GB'),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                ),
                _buildMiniStat('Days', '$sessionDays'),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // Clock In Button OR Claim Earnings Button
          if (_isClockedIn) ...[
            // Claim Earnings Button with cooldown
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (
                  _isClaimOnCooldown ||
                  _todayEarnings <= _lastClaimedAmount ||
                  _accountStatus.blocksAllActions ||
                  _accountStatus.withdrawOnly ||
                  !hasInvestment
                )
                    ? null
                    : _claimEarnings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isClaimOnCooldown
                      ? Colors.grey.shade600
                      : _accentPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: _isClaimOnCooldown ? 0 : 8,
                  shadowColor: _lavenderGlow.withAlpha((0.5 * 255).round()),
                ),
                icon: Icon(
                  _isClaimOnCooldown ? Icons.schedule : Icons.account_balance_wallet,
                  size: 20,
                  color: Colors.white,
                ),
                label: _isClaimOnCooldown
                    ? Text(
                        'Claim Cooldown ${_claimCooldownRemaining.inSeconds}s',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      )
                    : Text(
                        _todayEarnings > _lastClaimedAmount 
              ? 'Claim Earnings ₦₲${_formatCurrency(_todayEarnings - _lastClaimedAmount)}'
                            : 'No New Earnings',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // 24-hour countdown - just time, no text
            Center(
              child: Text(
                _formatDuration(_timeUntilMidnight),
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ]
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (
                  !_isClockInAvailable ||
                  _accountStatus.blocksAllActions ||
                  _accountStatus.withdrawOnly ||
                  !hasInvestment
                )
                    ? null
                    : _handleClockIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentPurple,
                  disabledBackgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: _lavenderGlow.withAlpha((0.5 * 255).round()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Clock In',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Countdown to midnight
          if (!_isClockInAvailable && !_isClockedIn && _isTodayAllowedByAdmin) ...[
            const SizedBox(height: 12),
            Text(
              'Next clock-in: ${_formatDuration(_timeUntilMidnight)}',
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.6 * 255).round()),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBandwidthCard() {
    final hasInvestment = _currentInvestment > 0;
    final bandwidthDisplay = hasInvestment ? _bandwidth : 0.0;
    final progressValue = (bandwidthDisplay / _maxBandwidth).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi, color: _lavenderGlow, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Bandwidth Shared',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${bandwidthDisplay.toStringAsFixed(1)} GB',
                style: TextStyle(
                  color: _lavenderGlow,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
              valueColor: AlwaysStoppedAnimation<Color>(_accentPurple),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Used',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.6 * 255).round()),
                  fontSize: 12,
                ),
              ),
              Text(
                'Limit: $_maxBandwidth GB',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.6 * 255).round()),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _headerTint.withAlpha((0.95 * 255).round()),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.4 * 255).round()),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _accentPurple.withAlpha((0.2 * 255).round()),
                blurRadius: 30,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: Colors.white.withAlpha((0.15 * 255).round()),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home_rounded, 'Home', _currentPageIndex == 0, () {
                      _pageController.jumpToPage(0);
                    }),
                    _buildNavItem(Icons.trending_up_rounded, 'Join', _currentPageIndex == 1, () {
                      _pageController.jumpToPage(1);
                    }),
                    _buildNavItem(Icons.account_balance_wallet_rounded, 'Wallet', _currentPageIndex == 2, () {
                      _pageController.jumpToPage(2);
                    }),
                    _buildNavItem(Icons.bar_chart_rounded, 'Stats', _currentPageIndex == 3, () {
                      _pageController.jumpToPage(3);
                    }),
                    _buildNavItem(Icons.person_rounded, 'Profile', _currentPageIndex == 4, () {
                      _pageController.jumpToPage(4);
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? _accentPurple : Colors.white.withAlpha((0.5 * 255).round()),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? _accentPurple : Colors.white.withAlpha((0.5 * 255).round()),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(num amount, {int decimals = 2}) {
    final isNegative = amount.isNegative;
    final absolute = amount.abs();
    final fixed = absolute.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final buffer = StringBuffer();

    for (int i = 0; i < integerPart.length; i++) {
      buffer.write(integerPart[i]);
      final digitsLeft = integerPart.length - i - 1;
      if (digitsLeft > 0 && digitsLeft % 3 == 0) {
        buffer.write(',');
      }
    }

    final decimalsPart = (decimals > 0 && parts.length > 1) ? '.${parts[1]}' : '';
    final sign = isNegative ? '-' : '';
    return '$sign${buffer.toString()}$decimalsPart';
  }
}

