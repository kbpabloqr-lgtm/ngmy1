import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngmy1/screens/family_tree_investment_screen.dart';
import 'package:ngmy1/services/cash_tag_service.dart';
import 'package:ngmy1/services/wallet_transfer_service.dart';
import '../widgets/notification_bell.dart';

const List<String> _familyTreeWeekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class _DailyEarning {
  final DateTime date;
  final double amount;

  const _DailyEarning({required this.date, required this.amount});

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'amount': amount,
    };
  }

  static _DailyEarning? fromMap(Map<String, dynamic> map) {
    final dateString = map['date'] as String?;
    if (dateString == null) {
      return null;
    }
    final parsedDate = DateTime.tryParse(dateString);
    if (parsedDate == null) {
      return null;
    }
    final amountValue = (map['amount'] as num?)?.toDouble() ?? 0.0;
    return _DailyEarning(
      date: parsedDate.toLocal(),
      amount: amountValue.isFinite ? amountValue : 0.0,
    );
  }
}

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen>
    with TickerProviderStateMixin {
  static const int _historyRetentionLimit = 120;
  int _currentPageIndex = 0;
  late PageController _pageController;

  DateTime? _clockInStartTime;
  Timer? _timer;
  Duration _workDuration = Duration.zero;
  Duration _timeUntilAllSessionsComplete = Duration.zero;
  bool _isClockInAvailable = false;

  // 5 Clock-ins per day system
  List<TimeOfDay> _adminClockInTimes = [
    const TimeOfDay(hour: 8, minute: 0), // 8:00 AM
    const TimeOfDay(hour: 11, minute: 0), // 11:00 AM
    const TimeOfDay(hour: 14, minute: 0), // 2:00 PM
    const TimeOfDay(hour: 17, minute: 0), // 5:00 PM
    const TimeOfDay(hour: 20, minute: 0), // 8:00 PM
  ];
  List<bool> _completedClockIns = [false, false, false, false, false];
  List<bool> _missedClockIns = [
    false,
    false,
    false,
    false,
    false
  ]; // Track missed sessions
  int _currentClockInIndex = -1; // Which clock-in session is active
  int _clockInDurationMinutes =
      40; // Default 40 minutes per session (loaded from admin settings)
  bool _isClockInActive = false; // Whether currently in an active session
  static const int _dailyResetHour = 6;
  static const int _earningsHistoryRetentionLimit = 30;

  List<_DailyEarning> _earningsHistory = <_DailyEarning>[];
  DateTime? _investmentStartDate;
  DateTime? _investmentActivatedAt;

  late AnimationController _pulseController;
  late AnimationController _rotationController;

  // Realistic earnings data - starts at 0
  double _todayEarnings = 0.0;
  double _totalBalance = 0.0;
  double _bandwidth = 0.0;
  double _sessionStartBandwidth = 0.0; // Bandwidth at start of current session

  final double _maxBandwidth = 100000.0; // 100TB in GB (100,000 GB)
  int _activeDays = 0;
  double _currentInvestment = 0.0; // Track approved investment
  static const double _dailyReturnRate = 0.0333; // 3.33% per day
  static const double _autoSessionFeeRate = 0.10;
  static const double _standardWithdrawalFeeRate = 0.06;
  bool _autoSessionEnabled = false;
  double _autoSessionCoverage = 0.0;
  double _autoSessionPaidTotal = 0.0;
  double _autoSessionRequiredTotal = 0.0;
  double get _autoSessionOutstanding =>
      math.max(0.0, _autoSessionRequiredTotal - _autoSessionPaidTotal);
  bool _autoSessionBootstrapped = false;
  final Set<int> _autoSessionTriggeredIndices = <int>{};
  DateTime? _autoSessionTriggerStamp;
  List<String> _adminWorkingDays = const <String>[];
  bool _isTodayAllowedByAdmin = true;
  bool _hasPendingWithdrawal = false;
  double _pendingWithdrawalAmount = 0.0;
  double _pendingWithdrawalContribution = 0.0;
  double _pendingWithdrawalStandardFee = 0.0;
  double _pendingWithdrawalNetAmount = 0.0;
  double _pendingWithdrawalBalanceAfter = 0.0;
  double _pendingWithdrawalOutstandingAfter = 0.0;
  DateTime? _pendingWithdrawalRequestedAt;
  String? _pendingWithdrawalStatus;
  String? _pendingWithdrawalRequestId;

  double _sessionEarningsValue() {
    if (_currentInvestment <= 0) {
      return 0.0;
    }
    final sessionCount =
        _adminClockInTimes.isNotEmpty ? _adminClockInTimes.length : 5;
    if (sessionCount <= 0) {
      return 0.0;
    }
    return _currentInvestment * (_dailyReturnRate / sessionCount);
  }

  double _sessionBandwidthValue() {
    return _clockInDurationMinutes * 10.0;
  }

  // Profile picture functionality
  String? _profileImagePath;
  bool _profileImageIsLocalFile = false;
  final ImagePicker _imagePicker = ImagePicker();
  String? _familyTreeUserId;
  bool _isAccountDisabled = false;
  bool _isAccountBanned = false;
  DateTime? _accountSuspendedUntil;
  bool get _isAccountSuspended =>
      _accountSuspendedUntil != null &&
      DateTime.now().isBefore(_accountSuspendedUntil!);
  bool get _isAccountLocked =>
      _isAccountBanned || _isAccountDisabled || _isAccountSuspended;
  bool get _isWithdrawProhibited => _isAccountBanned || _isAccountSuspended;

  // Claim system variables
  bool _isClaimOnCooldown = false;
  DateTime? _lastClaimTime;
  Duration _claimCooldownRemaining = Duration.zero;
  double _lastClaimedAmount = 0.0;
  double _grossDailyProjection = 0.0;
  double _penaltyTotalToday = 0.0;
  double _penaltyTotalAllTime = 0.0;
  double _latestPenaltyAmount = 0.0;
  String? _latestPenaltyReason;
  DateTime? _latestPenaltyDate;
  double _remainingNetToday = 0.0;
  String _familyTreeUserName = 'NGMY User';
  String _familyTreePhoneNumber = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadClockInData();
    _startTimer();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload balance whenever screen is shown
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    _familyTreeUserName = username;
    // Use ONLY Family Tree specific keys - NOT connected to Growth
    final savedBalance = prefs.getDouble('${username}_family_tree_balance') ??
        prefs.getDouble('family_tree_total_balance') ??
        0.0;
    final approvedInvestment =
        prefs.getDouble('${username}_family_tree_approved_investment') ??
            prefs.getDouble('family_tree_approved_investment') ??
            0.0;
    final autoSessionEnabled =
        prefs.getBool('${username}_family_tree_auto_session_enabled') ?? false;
    final autoSessionCoverage =
        prefs.getDouble('${username}_family_tree_auto_session_coverage') ?? 0.0;
    final autoSessionPaidTotal =
        prefs.getDouble('${username}_family_tree_auto_session_paid_total') ??
            0.0;
    final autoSessionRequiredTotal = prefs
            .getDouble('${username}_family_tree_auto_session_required_total') ??
        (autoSessionEnabled ? approvedInvestment * 0.2 : 0.0);
    final previousInvestment = _currentInvestment;
    final activationKey = '${username}_family_tree_investment_activated_at';
    final rawActivation = prefs.getString(activationKey) ??
        prefs.getString('family_tree_investment_activated_at');
    DateTime? activationStamp = rawActivation != null
        ? DateTime.tryParse(rawActivation)?.toLocal()
        : null;
    final assignedUserId = await _ensureFamilyTreeUserId(
      prefsOverride: prefs,
      usernameOverride: username,
    );
    final disabled = prefs.getBool('${username}_family_tree_disabled') ?? false;
    final banned = prefs.getBool('${username}_family_tree_banned') ?? false;
    final phoneRaw = prefs.getString('${username}_family_tree_phone') ??
        prefs.getString('family_tree_user_phone') ??
        '';
    final normalizedPhone = _sanitizePhoneInput(phoneRaw);
    DateTime? suspendedUntil;
    final suspensionString =
        prefs.getString('${username}_family_tree_suspension_until');
    if (suspensionString != null && suspensionString.isNotEmpty) {
      final parsed = DateTime.tryParse(suspensionString);
      if (parsed != null) {
        if (DateTime.now().isAfter(parsed)) {
          await prefs.remove('${username}_family_tree_suspension_until');
        } else {
          suspendedUntil = parsed.toLocal();
        }
      }
    }

    if (approvedInvestment > 0) {
      if (activationStamp == null || previousInvestment <= 0) {
        final now = DateTime.now();
        activationStamp = now;
        await prefs.setString(activationKey, now.toIso8601String());
        await prefs.setString(
            'family_tree_investment_activated_at', now.toIso8601String());
      }
    } else if (activationStamp != null) {
      await prefs.remove(activationKey);
      await prefs.remove('family_tree_investment_activated_at');
      activationStamp = null;
    }

    if (activationStamp == null && _investmentStartDate != null) {
      activationStamp = _investmentStartDate;
    }

    final workingDays = _resolveAdminWorkingDays(prefs);
    final todayAllowedByAdmin = _isWorkingDay(DateTime.now(), workingDays);

    final needsUpdate = savedBalance != _totalBalance ||
        approvedInvestment != _currentInvestment ||
        autoSessionEnabled != _autoSessionEnabled ||
        autoSessionCoverage != _autoSessionCoverage ||
        autoSessionPaidTotal != _autoSessionPaidTotal ||
        math.max(0.0, autoSessionRequiredTotal) != _autoSessionRequiredTotal ||
        assignedUserId != _familyTreeUserId ||
        disabled != _isAccountDisabled ||
        banned != _isAccountBanned ||
        !_datesAreEqual(suspendedUntil, _accountSuspendedUntil) ||
        normalizedPhone != _familyTreePhoneNumber ||
        !_datesAreEqual(activationStamp, _investmentActivatedAt) ||
        !listEquals(workingDays, _adminWorkingDays) ||
        todayAllowedByAdmin != _isTodayAllowedByAdmin;

    if (needsUpdate && mounted) {
      setState(() {
        _totalBalance = savedBalance;
        _currentInvestment = approvedInvestment;
        _autoSessionEnabled = autoSessionEnabled;
        _autoSessionCoverage = autoSessionCoverage;
        _autoSessionPaidTotal = autoSessionPaidTotal;
        _autoSessionRequiredTotal = math.max(0.0, autoSessionRequiredTotal);
        _familyTreeUserId = assignedUserId;
        _familyTreeUserName = username;
        _familyTreePhoneNumber = normalizedPhone;
        _isAccountDisabled = disabled;
        _isAccountBanned = banned;
        _accountSuspendedUntil = suspendedUntil;
        _investmentActivatedAt = activationStamp;
        _adminWorkingDays = workingDays;
        _isTodayAllowedByAdmin = todayAllowedByAdmin;
      });
    } else {
      _adminWorkingDays = workingDays;
      _isTodayAllowedByAdmin = todayAllowedByAdmin;
    }

    await _markAllCompletedSessionsCredited(
      prefs,
      username,
      reference: DateTime.now(),
    );

    final shouldSilenceInitialReconcile = !_autoSessionBootstrapped;
    await _reconcileAutoSessionUpgrade(
      prefsOverride: prefs,
      usernameOverride: username,
      investmentOverride: approvedInvestment,
      silent: shouldSilenceInitialReconcile,
    );
    _autoSessionBootstrapped = true;

    await _updateFamilyTreeFinancialSummary(
      prefsOverride: prefs,
      usernameOverride: username,
      investmentOverride: approvedInvestment,
    );

    await _handleAutoSessionsIfNeeded(reference: DateTime.now());

    if (activationStamp != null && _missedClockIns.isNotEmpty) {
      final sanitizedMissed = List<bool>.from(_missedClockIns);
      final cleared = _clearMissedSessionsBeforeActivation(
        activation: activationStamp,
        missedFlags: sanitizedMissed,
      );
      if (cleared) {
        if (mounted) {
          setState(() {
            _missedClockIns = sanitizedMissed;
          });
        } else {
          _missedClockIns = sanitizedMissed;
        }
        await _saveMissedClockIns(prefsOverride: prefs);
      }
    }
  }

  Future<String?> _ensureFamilyTreeUserId({
    SharedPreferences? prefsOverride,
    String? usernameOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final username = usernameOverride ??
        prefs.getString('family_tree_user_name') ??
        'NGMY User';
    final keyName = username.isNotEmpty
        ? '${username}_family_tree_user_id'
        : '_system_family_tree_user_id';

    var existing = prefs.getString(keyName);
    final fallbackExisting = prefs.getString('family_tree_user_id');
    if ((existing == null || existing.isEmpty) &&
        fallbackExisting != null &&
        fallbackExisting.isNotEmpty) {
      existing = fallbackExisting;
    }
    if (existing == null || existing.isEmpty) {
      final existingIds = <String>{};
      for (final key in prefs.getKeys()) {
        if (key.endsWith('_family_tree_user_id')) {
          final value = prefs.getString(key);
          if (value != null && value.isNotEmpty) {
            existingIds.add(value);
          }
        }
      }
      if (fallbackExisting != null && fallbackExisting.isNotEmpty) {
        existingIds.add(fallbackExisting);
      }
      existing = _generateFamilyTreeUserId(existingIds);
      await prefs.setString(keyName, existing);
    } else {
      await prefs.setString(keyName, existing);
    }

    await prefs.setString('family_tree_user_id', existing);
    return existing;
  }

  double _storedFamilyTreeBalance(SharedPreferences prefs, String username) {
    return prefs.getDouble('${username}_family_tree_balance') ??
        prefs.getDouble('family_tree_total_balance') ??
        0.0;
  }

  Future<void> _appendFamilyTreeWalletReceipt(
    SharedPreferences prefs, {
    required String description,
    required double amount,
    required String type,
    DateTime? timestamp,
  }) async {
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    final receiptsKey = '${username}_family_tree_wallet_receipts';
    final receipts = prefs.getStringList(receiptsKey) ?? <String>[];
    final recordedAt = timestamp ?? DateTime.now();

    final receipt = jsonEncode({
      'type': type,
      'amount': amount,
      'description': description,
      'date': recordedAt.toIso8601String(),
    });

    receipts.add(receipt);
    await prefs.setStringList(receiptsKey, receipts);
  }

  String _formatDayKey(DateTime date) {
    final normalized = _normalizeDate(date);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime _operationalDay([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final normalized = _normalizeDate(now);
    if (now.hour < _dailyResetHour) {
      return normalized.subtract(const Duration(days: 1));
    }
    return normalized;
  }

  String _operationalDayKey([DateTime? reference]) =>
      _formatDayKey(_operationalDay(reference));

  List<String> _resolveAdminWorkingDays(SharedPreferences prefs) {
    final specific = prefs.getStringList('family_tree_admin_working_days');
    if (specific != null && specific.isNotEmpty) {
      return List<String>.from(specific);
    }
    final legacy = prefs.getStringList('admin_working_days');
    if (legacy != null && legacy.isNotEmpty) {
      return List<String>.from(legacy);
    }
    return const <String>[];
  }

  bool _isWorkingDay(DateTime day, List<String> workingDays) {
    if (workingDays.isEmpty) {
      return true;
    }
    final label = _familyTreeWeekdayNames[day.weekday - 1];
    return workingDays.contains(label);
  }

  Future<void> _syncDailySnapshot({
    required SharedPreferences prefs,
    required String username,
    required DateTime reference,
  }) async {
    if (_currentInvestment <= 0) {
      return;
    }

    final workingDays = _adminWorkingDays.isNotEmpty
        ? _adminWorkingDays
        : _resolveAdminWorkingDays(prefs);
    if (!_isWorkingDay(reference, workingDays)) {
      return;
    }

    await _recordDailyEarningsSnapshot(
      prefs: prefs,
      username: username,
      day: _operationalDay(reference),
      amount: _todayEarnings,
    );
  }

  String _sessionCreditDateKey(String username) =>
      '${username}_family_tree_session_credit_date';

  String _sessionCreditIndicesKey(String username) =>
      '${username}_family_tree_session_credit_indices';

  Future<List<String>> _ensureSessionCreditList(
      SharedPreferences prefs, String username,
      {DateTime? reference}) async {
    final now = reference ?? DateTime.now();
    final operationalAnchor = _operationalDay(now);
    final todayKey = _formatDayKey(operationalAnchor);
    final dateKey = _sessionCreditDateKey(username);
    final indicesKey = _sessionCreditIndicesKey(username);

    final storedDate = prefs.getString(dateKey);
    if (storedDate != todayKey) {
      await prefs.setString(dateKey, todayKey);
      await prefs.setStringList(indicesKey, <String>[]);
      return <String>[];
    }

    return List<String>.from(prefs.getStringList(indicesKey) ?? const []);
  }

  Future<bool> _isSessionCreditedToday(
    SharedPreferences prefs,
    String username,
    int sessionIndex, {
    DateTime? reference,
  }) async {
    final credits =
        await _ensureSessionCreditList(prefs, username, reference: reference);
    return credits.contains(sessionIndex.toString());
  }

  Future<void> _markSessionCredited(
    SharedPreferences prefs,
    String username,
    int sessionIndex, {
    DateTime? reference,
  }) async {
    final indicesKey = _sessionCreditIndicesKey(username);
    final credits =
        await _ensureSessionCreditList(prefs, username, reference: reference);
    final sessionToken = sessionIndex.toString();
    if (!credits.contains(sessionToken)) {
      credits.add(sessionToken);
      await prefs.setStringList(indicesKey, credits);
    }
  }

  Future<void> _markAllCompletedSessionsCredited(
    SharedPreferences prefs,
    String username, {
    DateTime? reference,
  }) async {
    final indicesKey = _sessionCreditIndicesKey(username);
    final credits =
        await _ensureSessionCreditList(prefs, username, reference: reference);
    var updated = false;
    for (var i = 0; i < _completedClockIns.length; i++) {
      if (_completedClockIns[i]) {
        final token = i.toString();
        if (!credits.contains(token)) {
          credits.add(token);
          updated = true;
        }
      }
    }
    if (updated) {
      await prefs.setStringList(indicesKey, credits);
    }
  }

  Future<void> _clearSessionCreditState(
      SharedPreferences prefs, String username) async {
    await prefs.remove(_sessionCreditDateKey(username));
    await prefs.remove(_sessionCreditIndicesKey(username));
  }

  String _generateFamilyTreeUserId(Set<String> existingIds) {
    final random = math.Random();
    String candidate;
    int attempts = 0;
    do {
      final timestampPortion =
          DateTime.now().millisecondsSinceEpoch.toRadixString(32).toUpperCase();
      final randomPortion = random
          .nextInt(0xFFFFF)
          .toRadixString(32)
          .toUpperCase()
          .padLeft(4, '0');
      candidate = 'FT-$timestampPortion-$randomPortion';
      attempts++;
    } while (existingIds.contains(candidate) && attempts < 6);

    while (existingIds.contains(candidate)) {
      candidate =
          '$candidate-${random.nextInt(9999).toString().padLeft(4, '0')}';
    }

    return candidate;
  }

  Future<void> _copyFamilyTreeUserId() async {
    final id = _familyTreeUserId;
    if (!mounted || id == null || id.isEmpty) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('User ID $id copied'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _copyFamilyTreePhoneNumber() async {
    final phone = _familyTreePhoneNumber;
    if (!mounted || phone.isEmpty) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('Phone $phone copied'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _promptEditFamilyTreeUsername() async {
    final currentUsername =
        _familyTreeUserName == 'NGMY User' ? '' : _familyTreeUserName;
    final usernameController = TextEditingController(text: currentUsername);
    final phoneController = TextEditingController(text: _familyTreePhoneNumber);
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final viewInsets = MediaQuery.of(dialogContext).viewInsets;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
                child: AlertDialog(
                  scrollable: true,
                  backgroundColor: const Color(0xFF0A2472),
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  title: const Text('Update Family Tree Profile',
                      style: TextStyle(color: Colors.white)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: usernameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                          ),
                          hintText: 'Enter new username',
                          hintStyle: TextStyle(
                            color: Colors.white.withAlpha((0.5 * 255).round()),
                          ),
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
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                          ),
                          hintText: 'Enter phone number',
                          hintStyle: TextStyle(
                            color: Colors.white.withAlpha((0.5 * 255).round()),
                          ),
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
                        'Usernames must be at least 3 characters. Phone numbers can be shared with one other account.',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.6 * 255).round()),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop({
                          'username': usernameController.text.trim(),
                          'phone': phoneController.text.trim(),
                        });
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (!mounted || result == null) {
        return;
      }

      final newUsername = result['username'] ?? '';
      final newPhone = result['phone'] ?? '';
      await _applyProfileChanges(
        newUsername: newUsername,
        newPhoneRaw: newPhone,
        messenger: messenger,
      );
    } finally {
      usernameController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _applyProfileChanges({
    required String newUsername,
    required String newPhoneRaw,
    required ScaffoldMessengerState? messenger,
  }) async {
    void showSnack(SnackBar snackBar) {
      if (messenger != null) {
        messenger.showSnackBar(snackBar);
      } else if (mounted) {
        final fallback = ScaffoldMessenger.maybeOf(context);
        fallback?.showSnackBar(snackBar);
      }
    }

    final trimmedUsername = newUsername.trim();
    final sanitizedPhone = _sanitizePhoneInput(newPhoneRaw);
    final currentSanitizedPhone = _sanitizePhoneInput(_familyTreePhoneNumber);

    final usernameChanged = trimmedUsername != _familyTreeUserName;
    final phoneChanged = sanitizedPhone != currentSanitizedPhone;

    if (!usernameChanged && !phoneChanged) {
      showSnack(
        const SnackBar(
          content: Text('Profile unchanged'),
          backgroundColor: Colors.blueGrey,
        ),
      );
      return;
    }

    if (trimmedUsername.isEmpty) {
      showSnack(
        const SnackBar(
          content: Text('Username cannot be empty'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (trimmedUsername.length < 3) {
      showSnack(
        const SnackBar(
          content: Text('Username must be at least 3 characters'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (sanitizedPhone.isNotEmpty && sanitizedPhone.length < 7) {
      showSnack(
        const SnackBar(
          content: Text('Enter a valid phone number (at least 7 digits).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (phoneChanged && sanitizedPhone.isNotEmpty) {
      final usageCount = _countAccountsUsingPhoneInPrefs(
        prefs,
        sanitizedPhone,
        excludeUsernames: {trimmedUsername, _familyTreeUserName},
      );
      if (usageCount >= 2) {
        showSnack(
          const SnackBar(
            content: Text(
                'This phone number is already used by two Family Tree accounts.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    final previousUsername = _familyTreeUserName;
    String? ensuredId = _familyTreeUserId;

    if (usernameChanged) {
      final oldPrefix = '${previousUsername}_family_tree_';
      final newPrefix = '${trimmedUsername}_family_tree_';

      if (previousUsername != 'NGMY User' && previousUsername.isNotEmpty) {
        final keysToMigrate = prefs
            .getKeys()
            .where((key) => key.startsWith(oldPrefix))
            .toList(growable: false);
        for (final key in keysToMigrate) {
          final suffix = key.substring(oldPrefix.length);
          final value = prefs.get(key);
          final newKey = '$newPrefix$suffix';
          await _setPreferenceValue(prefs, newKey, value);
          await prefs.remove(key);
        }
      }

      final oldIdKey = '${previousUsername}_family_tree_user_id';
      final existingId = _familyTreeUserId ??
          prefs.getString('family_tree_user_id') ??
          prefs.getString(oldIdKey) ??
          '';
      if (existingId.isNotEmpty) {
        await prefs.setString(
            '${trimmedUsername}_family_tree_user_id', existingId);
        await prefs.setString('family_tree_user_id', existingId);
        ensuredId = existingId;
      }
      await prefs.remove(oldIdKey);

      if (previousUsername == 'NGMY User') {
        await prefs.remove('${previousUsername}_family_tree_phone');
      }
    }

    await prefs.setString('family_tree_user_name', trimmedUsername);

    ensuredId ??= await _ensureFamilyTreeUserId(
      prefsOverride: prefs,
      usernameOverride: trimmedUsername,
    );

    await _persistPhoneNumber(
      prefs: prefs,
      username: trimmedUsername,
      phone: sanitizedPhone,
    );

    if (!mounted) {
      _familyTreeUserName = trimmedUsername;
      _familyTreeUserId = ensuredId;
      _familyTreePhoneNumber = sanitizedPhone;
      return;
    }

    setState(() {
      _familyTreeUserName = trimmedUsername;
      _familyTreeUserId = ensuredId;
      _familyTreePhoneNumber = sanitizedPhone;
    });

    final updatedMessage = () {
      if (usernameChanged && phoneChanged) {
        return sanitizedPhone.isEmpty
            ? 'Username updated and phone removed'
            : 'Username and phone updated';
      }
      if (usernameChanged) {
        return 'Username updated to $trimmedUsername';
      }
      return sanitizedPhone.isEmpty
          ? 'Phone number removed'
          : 'Phone number updated';
    }();

    showSnack(
      SnackBar(
        content: Text(updatedMessage),
        backgroundColor: Colors.green.shade700,
      ),
    );

    await _refreshBalance();
    if (usernameChanged) {
      await _reloadProfileImage(
        prefsOverride: prefs,
        usernameOverride: trimmedUsername,
      );
    }
  }

  Future<void> _setPreferenceValue(
      SharedPreferences prefs, String key, Object? value) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }

  String _sanitizePhoneInput(String input) {
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

  int _countAccountsUsingPhoneInPrefs(
    SharedPreferences prefs,
    String normalized, {
    Set<String>? excludeUsernames,
  }) {
    if (normalized.isEmpty) {
      return 0;
    }
    const suffix = '_family_tree_phone';
    final usernames = <String>{};
    for (final key in prefs.getKeys()) {
      if (!key.endsWith(suffix)) {
        continue;
      }
      final username = key.substring(0, key.length - suffix.length);
      if (username.isEmpty) {
        continue;
      }
      final stored = prefs.getString(key) ?? '';
      if (_sanitizePhoneInput(stored) == normalized) {
        usernames.add(username);
      }
    }

    final currentUsername = prefs.getString('family_tree_user_name');
    final currentPhone = prefs.getString('family_tree_user_phone') ?? '';
    if (currentUsername != null &&
        currentUsername.isNotEmpty &&
        _sanitizePhoneInput(currentPhone) == normalized) {
      usernames.add(currentUsername);
    }

    if (excludeUsernames != null && excludeUsernames.isNotEmpty) {
      usernames.removeWhere((username) => excludeUsernames.contains(username));
    }

    return usernames.length;
  }

  Future<void> _persistPhoneNumber({
    required SharedPreferences prefs,
    required String username,
    required String phone,
  }) async {
    final key = '${username}_family_tree_phone';
    final activeUsername = prefs.getString('family_tree_user_name');

    if (phone.isEmpty) {
      await prefs.remove(key);
      if (activeUsername == username) {
        await prefs.remove('family_tree_user_phone');
      }
      return;
    }

    await prefs.setString(key, phone);
    if (activeUsername == username) {
      await prefs.setString('family_tree_user_phone', phone);
    }
  }

  Future<void> _saveProfileImage(String? path,
      {required bool isLocal, SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    final pathKey = '${username}_family_tree_profile_image';
    final sourceKey = '${username}_family_tree_profile_image_source';

    if (path == null || path.isEmpty) {
      await prefs.remove(pathKey);
      await prefs.remove(sourceKey);
      return;
    }

    await prefs.setString(pathKey, path);
    await prefs.setString(sourceKey, isLocal ? 'file' : 'url');
  }

  Future<void> _reloadProfileImage({
    SharedPreferences? prefsOverride,
    String? usernameOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final username = usernameOverride ??
        prefs.getString('family_tree_user_name') ??
        'NGMY User';
    final savedPath = prefs.getString('${username}_family_tree_profile_image');
    final savedSource =
        prefs.getString('${username}_family_tree_profile_image_source');
    final isLocal = savedPath != null && savedSource == 'file';

    if (!mounted) {
      _profileImagePath = savedPath;
      _profileImageIsLocalFile = isLocal;
      return;
    }

    setState(() {
      _profileImagePath = savedPath;
      _profileImageIsLocalFile = isLocal;
    });
  }

  Future<void> _applyProfileImageChange({
    required String? path,
    required bool isLocal,
    String? successMessage,
  }) async {
    await _saveProfileImage(path, isLocal: isLocal);

    if (!mounted) {
      _profileImagePath = path;
      _profileImageIsLocalFile = path != null && isLocal;
      return;
    }

    setState(() {
      _profileImagePath = path;
      _profileImageIsLocalFile = path != null && isLocal;
    });

    if (successMessage != null && successMessage.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  bool _datesAreEqual(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.isAtSameMomentAs(b);
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  double _sanitizeEarningAmount(double value) {
    if (!value.isFinite) {
      return 0.0;
    }
    return math.max(0.0, value);
  }

  List<_DailyEarning> _applyHistoryRetention(List<_DailyEarning> entries) {
    if (entries.length <= _earningsHistoryRetentionLimit) {
      return entries;
    }
    return entries.sublist(
      entries.length - _earningsHistoryRetentionLimit,
      entries.length,
    );
  }

  String _chartDayLabel(DateTime date) {
    final normalized = _normalizeDate(date);
    final today = _normalizeDate(DateTime.now());
    if (_isSameDay(normalized, today)) {
      return 'Today';
    }
    final yesterday = _normalizeDate(today.subtract(const Duration(days: 1)));
    if (_isSameDay(normalized, yesterday)) {
      return 'Yesterday';
    }
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdayText = weekdayLabels[normalized.weekday - 1];
    return '$weekdayText ${normalized.month}/${normalized.day}';
  }

  String _accountLockReason() {
    if (_isAccountBanned) {
      return 'This account is banned by an administrator.';
    }
    if (_isAccountDisabled) {
      return 'This account is disabled by an administrator.';
    }
    if (_isAccountSuspended && _accountSuspendedUntil != null) {
      return 'Suspended until ${_formatSuspensionDate(_accountSuspendedUntil!)}.';
    }
    return 'This account is currently locked by an administrator.';
  }

  String _withdrawBlockReason() {
    if (_isAccountBanned) {
      return 'Withdrawals are blocked while this account is banned by an administrator.';
    }
    if (_isAccountSuspended && _accountSuspendedUntil != null) {
      return 'Withdrawals are blocked until ${_formatSuspensionDate(_accountSuspendedUntil!)}.';
    }
    if (_isAccountSuspended) {
      return 'Withdrawals are blocked while this account is suspended.';
    }
    return 'Withdrawals are currently blocked for this account.';
  }

  bool _ensureAccountActive(String actionLabel) {
    if (!_isAccountLocked) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    final reason = _accountLockReason();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionLabel unavailable. $reason'),
        backgroundColor: Colors.orange,
      ),
    );
    return false;
  }

  bool _ensureWithdrawAllowed() {
    if (!_isWithdrawProhibited) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    final reason = _withdrawBlockReason();
    final color = _isAccountBanned ? Colors.redAccent : Colors.orange;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason),
        backgroundColor: color,
      ),
    );
    return false;
  }

  // Recomputes gross/net projections and penalty totals using stored data.
  Future<void> _updateFamilyTreeFinancialSummary({
    SharedPreferences? prefsOverride,
    String? usernameOverride,
    double? investmentOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final username = usernameOverride ??
        prefs.getString('family_tree_user_name') ??
        'NGMY User';
    final investment = investmentOverride ?? _currentInvestment;
    final sessionCount = _adminClockInTimes.isNotEmpty
        ? _adminClockInTimes.length
        : (_completedClockIns.isNotEmpty ? _completedClockIns.length : 5);
    final sessionEarnings = (sessionCount > 0 && investment > 0)
        ? investment * (_dailyReturnRate / sessionCount)
        : 0.0;
    final grossDaily = sessionEarnings * sessionCount;
    final penaltyHistory =
        prefs.getStringList('${username}_family_tree_penalty_history') ??
            <String>[];

    double totalPenalty = 0.0;
    double todayPenalty = 0.0;
    double latestPenaltyAmount = 0.0;
    String? latestPenaltyReason;
    DateTime? latestPenaltyDate;
    final now = DateTime.now();

    for (final recordString in penaltyHistory) {
      try {
        final record = jsonDecode(recordString) as Map<String, dynamic>;
        final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
        final reason = record['reason'] as String?;
        final dateString = record['date'] as String?;
        DateTime? parsedDate;
        if (dateString != null) {
          parsedDate = DateTime.tryParse(dateString);
        }

        totalPenalty += amount;

        if (parsedDate != null) {
          final isToday = parsedDate.year == now.year &&
              parsedDate.month == now.month &&
              parsedDate.day == now.day;
          if (isToday) {
            todayPenalty += amount;
          }

          if (latestPenaltyDate == null ||
              parsedDate.isAfter(latestPenaltyDate)) {
            latestPenaltyDate = parsedDate;
            latestPenaltyAmount = amount;
            latestPenaltyReason = reason;
          }
        } else if (latestPenaltyDate == null && amount > 0) {
          latestPenaltyAmount = amount;
          latestPenaltyReason = reason;
        }
      } catch (_) {
        continue;
      }
    }

    final completedSessions =
        _completedClockIns.where((completed) => completed).length;
    final missedSessions = _missedClockIns.where((missed) => missed).length;
    final openSessions =
        math.max(0, sessionCount - completedSessions - missedSessions);
    final remainingPotential = sessionEarnings * openSessions;
    final remainingNetToday = math.max(0.0, remainingPotential);

    if (!mounted) {
      return;
    }

    setState(() {
      _grossDailyProjection = grossDaily;
      _penaltyTotalAllTime = totalPenalty;
      _penaltyTotalToday = todayPenalty;
      _latestPenaltyAmount = latestPenaltyAmount;
      _latestPenaltyReason = latestPenaltyReason;
      _latestPenaltyDate = latestPenaltyDate;
      _remainingNetToday = remainingNetToday;
    });
  }

  String _formatPenaltyTimestamp(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final timeLabel = '$hour:$minute $period';

    if (isToday) {
      return 'Today at $timeLabel';
    }
    if (isYesterday) {
      return 'Yesterday at $timeLabel';
    }
    return '${date.month}/${date.day}/${date.year} $timeLabel';
  }

  String _formatCurrency(double value, {int decimals = 2}) {
    if (value.isNaN || value.isInfinite) {
      return '₦₲${0.toStringAsFixed(decimals)}';
    }

    final isNegative = value.isNegative;
    final absolute = value.abs();
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

    final decimalPart =
        (decimals > 0 && parts.length > 1) ? '.${parts[1]}' : '';
    final sign = isNegative ? '-' : '';
    return '₦₲$sign${buffer.toString()}$decimalPart';
  }

  Widget _buildPenaltyNotificationCard() {
    final completedSessions =
        _completedClockIns.where((completed) => completed).length;
    final totalSessions = _adminClockInTimes.isNotEmpty
        ? _adminClockInTimes.length
        : (_completedClockIns.isNotEmpty ? _completedClockIns.length : 5);
    final missedSessions = _missedClockIns.where((missed) => missed).length;
    final hasPenalty = _penaltyTotalToday > 0;
    final outstanding = _autoSessionOutstanding;

    final stats = <Widget>[
      _buildNotificationStat('Today earned', _formatCurrency(_todayEarnings)),
      _buildNotificationStat(
          'Sessions complete', '$completedSessions/$totalSessions'),
      if (missedSessions > 0)
        _buildNotificationStat('Sessions missed', '$missedSessions',
            valueColor: Colors.orangeAccent),
      _buildNotificationStat(
          'Remaining potential today', _formatCurrency(_remainingNetToday)),
      _buildNotificationStat(
          'Daily target (5 sessions)', _formatCurrency(_grossDailyProjection)),
    ];

    if (_autoSessionEnabled) {
      stats.add(
        _buildNotificationStat(
          'Auto Session contributions',
          '${_formatCurrency(_autoSessionPaidTotal)} / ${_formatCurrency(_autoSessionRequiredTotal)}',
          valueColor: Colors.tealAccent,
        ),
      );
      if (outstanding > 0) {
        stats.add(
          _buildNotificationStat(
            'Outstanding coverage',
            _formatCurrency(outstanding),
            valueColor: Colors.tealAccent.shade100,
          ),
        );
      }
    }

    if (_hasPendingWithdrawal && _pendingWithdrawalAmount > 0) {
      final pendingStat = StringBuffer(
        '${_formatCurrency(_pendingWithdrawalAmount)} • Pending',
      );
      if (_pendingWithdrawalContribution > 0) {
        pendingStat.write(
            '\nAuto Session fee: ${_formatCurrency(_pendingWithdrawalContribution)}');
      }
      if (_pendingWithdrawalStandardFee > 0) {
        pendingStat.write(
            '\nWithdrawal fee: ${_formatCurrency(_pendingWithdrawalStandardFee)}');
      }
      if (_pendingWithdrawalContribution > 0 ||
          _pendingWithdrawalStandardFee > 0) {
        pendingStat
            .write('\nNet: ${_formatCurrency(_pendingWithdrawalNetAmount)}');
      }
      if (_pendingWithdrawalBalanceAfter > 0) {
        pendingStat.write(
            '\nBalance after: ${_formatCurrency(_pendingWithdrawalBalanceAfter)}');
      }
      stats.add(
        _buildNotificationStat(
          'Pending withdrawal',
          pendingStat.toString(),
          valueColor: Colors.orangeAccent.shade100,
        ),
      );
    }

    if (hasPenalty) {
      stats.add(
        _buildNotificationStat(
          'Missed session loss (today)',
          _formatCurrency(_penaltyTotalToday),
          valueColor: Colors.orangeAccent,
        ),
      );
      stats.add(
        _buildNotificationStat(
          'Total missed earnings',
          _formatCurrency(_penaltyTotalAllTime),
          valueColor: Colors.orangeAccent.shade100,
        ),
      );
    }

    final autoSessionMessage = _autoSessionEnabled
        ? (outstanding > 0
            ? 'Auto Session Complete active. Each withdrawal will contribute 10% until you finish paying ${_formatCurrency(_autoSessionRequiredTotal)}. Remaining coverage: ${_formatCurrency(outstanding)}.'
            : 'Auto Session Complete active. Coverage is fully paid through your withdrawals.')
        : (_currentInvestment > 0
            ? 'Enable Auto Session Complete to auto-finish sessions. We will take 10% from each withdrawal until ${_formatCurrency(_currentInvestment * 0.2)} is covered. Without Auto Session, standard withdrawals charge 6%.'
            : 'Add an approved investment to unlock Auto Session Complete auto-finish.');

    final badgeColor = hasPenalty
        ? Colors.orange.withAlpha((0.3 * 255).round())
        : Colors.green.withAlpha((0.25 * 255).round());
    final iconColor = hasPenalty ? Colors.orangeAccent : Colors.greenAccent;
    final iconData =
        hasPenalty ? Icons.assignment_late_rounded : Icons.check_circle_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF203A43),
            const Color(0xFF2C5364),
            const Color(0xFF0F2027),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withAlpha((0.22 * 255).round()),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.4 * 255).round()),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Daily Earnings Snapshot',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...stats,
          const SizedBox(height: 16),
          Text(
            autoSessionMessage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          if (hasPenalty && _latestPenaltyDate != null) ...[
            const SizedBox(height: 14),
            const Text(
              'Last missed session',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatCurrency(_latestPenaltyAmount)} • ${_formatPenaltyTimestamp(_latestPenaltyDate!)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            if ((_latestPenaltyReason ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _latestPenaltyReason!.trim(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationStat(String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureComingSoon(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1F4068),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showAutoSessionAgreementDialog({
    required double requiredTotal,
    required double paidTotal,
    required double outstanding,
  }) async {
    if (!mounted) {
      return false;
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF102A43),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Enable Auto Session Complete?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto Session Complete will finish your clock-ins automatically. The system will collect 10% of every withdrawal you make until the full 20% coverage is paid.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildAgreementRow(
                    'Coverage total', _formatCurrency(requiredTotal)),
                _buildAgreementRow('Paid so far', _formatCurrency(paidTotal)),
                _buildAgreementRow(
                    'Remaining balance', _formatCurrency(outstanding)),
                const SizedBox(height: 12),
                const Text(
                  'Do you agree to the 10% per withdrawal contribution until the remaining balance is cleared?',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.tealAccent.shade400),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('I Agree'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildAgreementRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAutoSessionToggle(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';

    if (enable) {
      if (_autoSessionEnabled) {
        return;
      }

      if (_currentInvestment <= 0) {
        if (mounted) {
          setState(() {
            _autoSessionEnabled = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Add an approved investment before enabling Auto Session Complete.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        await prefs.setBool(
            '${username}_family_tree_auto_session_enabled', false);
        return;
      }

      final requiredTotal =
          (_currentInvestment * 0.2).clamp(0.0, double.infinity);
      final paidTotal = math.min(_autoSessionPaidTotal, requiredTotal);
      final outstanding = math.max(0.0, requiredTotal - paidTotal);

      final agreed = await _showAutoSessionAgreementDialog(
        requiredTotal: requiredTotal,
        paidTotal: paidTotal,
        outstanding: outstanding,
      );

      if (agreed != true) {
        if (mounted) {
          setState(() {
            _autoSessionEnabled = false;
          });
        }
        await prefs.setBool(
            '${username}_family_tree_auto_session_enabled', false);
        return;
      }

      if (mounted) {
        setState(() {
          _autoSessionEnabled = true;
          _autoSessionCoverage = _currentInvestment;
          _autoSessionRequiredTotal = requiredTotal;
          _autoSessionPaidTotal = paidTotal;
        });
      }

      await prefs.setBool('${username}_family_tree_auto_session_enabled', true);
      await prefs.setDouble('${username}_family_tree_auto_session_coverage',
          _autoSessionCoverage);
      await prefs.setDouble(
          '${username}_family_tree_auto_session_required_total',
          _autoSessionRequiredTotal);
      await prefs.setDouble('${username}_family_tree_auto_session_paid_total',
          _autoSessionPaidTotal);
      await _recordAutoSessionHistory(
        prefs,
        username,
        event: 'auto_session_enabled',
        charge: 0.0,
        balanceAfter: _totalBalance,
        coverageInvestment: _autoSessionCoverage,
        requiredTotal: _autoSessionRequiredTotal,
        paidTotal: _autoSessionPaidTotal,
        outstanding: _autoSessionOutstanding,
      );

      if (mounted) {
        final enableMessage = _autoSessionOutstanding > 0
            ? 'Auto Session Complete enabled. We will keep 10% from each withdrawal until ${_formatCurrency(_autoSessionRequiredTotal)} is covered. Remaining: ${_formatCurrency(_autoSessionOutstanding)}.'
            : 'Auto Session Complete enabled. Coverage is already paid in full.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enableMessage),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }

      await _handleAutoSessionsIfNeeded(reference: DateTime.now());
    } else {
      if (!_autoSessionEnabled) {
        return;
      }
      if (mounted) {
        setState(() {
          _autoSessionEnabled = false;
        });
      }
      await prefs.setBool(
          '${username}_family_tree_auto_session_enabled', false);
      await prefs.setDouble('${username}_family_tree_auto_session_coverage',
          _autoSessionCoverage);
      await prefs.setDouble(
          '${username}_family_tree_auto_session_required_total',
          _autoSessionRequiredTotal);
      await prefs.setDouble('${username}_family_tree_auto_session_paid_total',
          _autoSessionPaidTotal);
      await _recordAutoSessionHistory(
        prefs,
        username,
        event: 'auto_session_disabled',
        charge: 0.0,
        balanceAfter: _totalBalance,
        coverageInvestment: _autoSessionCoverage,
        requiredTotal: _autoSessionRequiredTotal,
        paidTotal: _autoSessionPaidTotal,
        outstanding: _autoSessionOutstanding,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto Session Complete disabled.'),
            backgroundColor: Color(0xFF1B4965),
          ),
        );
      }
    }

    await _updateFamilyTreeFinancialSummary(
      prefsOverride: prefs,
      usernameOverride: username,
    );
  }

  void _showAutoSessionDisableGuard() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Auto Session Complete can only be disabled by a Family Tree admin.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _reconcileAutoSessionUpgrade({
    SharedPreferences? prefsOverride,
    String? usernameOverride,
    double? investmentOverride,
    bool silent = false,
  }) async {
    if (!_autoSessionEnabled) {
      return;
    }

    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final username = usernameOverride ??
        prefs.getString('family_tree_user_name') ??
        'NGMY User';

    final investment = investmentOverride ?? _currentInvestment;
    final requiredCoverage = investment;

    if (requiredCoverage <= 0) {
      if (mounted) {
        setState(() {
          _autoSessionEnabled = false;
          _autoSessionCoverage = 0.0;
          _autoSessionRequiredTotal = 0.0;
        });
      }
      await prefs.setBool(
          '${username}_family_tree_auto_session_enabled', false);
      await prefs.remove('${username}_family_tree_auto_session_coverage');
      await prefs.remove('${username}_family_tree_auto_session_required_total');
      return;
    }

    final previousCoverage = _autoSessionCoverage;
    final previousRequiredTotal = _autoSessionRequiredTotal;
    final previousOutstanding = _autoSessionOutstanding;

    final newRequiredTotal = (investment * 0.2).clamp(0.0, double.infinity);
    final adjustedPaidTotal = math.min(_autoSessionPaidTotal, newRequiredTotal);

    final hasChange = previousCoverage != requiredCoverage ||
        previousRequiredTotal != newRequiredTotal ||
        _autoSessionPaidTotal != adjustedPaidTotal;

    if (!hasChange) {
      return;
    }

    if (mounted) {
      setState(() {
        _autoSessionCoverage = requiredCoverage;
        _autoSessionRequiredTotal = newRequiredTotal;
        _autoSessionPaidTotal = adjustedPaidTotal;
      });
    }

    await prefs.setDouble(
        '${username}_family_tree_auto_session_coverage', _autoSessionCoverage);
    await prefs.setDouble('${username}_family_tree_auto_session_required_total',
        _autoSessionRequiredTotal);
    await prefs.setDouble('${username}_family_tree_auto_session_paid_total',
        _autoSessionPaidTotal);

    await _recordAutoSessionHistory(
      prefs,
      username,
      event: 'auto_session_recalculated',
      charge: 0.0,
      balanceAfter: _totalBalance,
      coverageInvestment: _autoSessionCoverage,
      requiredTotal: _autoSessionRequiredTotal,
      paidTotal: _autoSessionPaidTotal,
      outstanding: _autoSessionOutstanding,
    );

    final outstandingChange = _autoSessionOutstanding - previousOutstanding;
    if (!silent && mounted && outstandingChange > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Auto Session Complete updated for your new investment. Outstanding coverage: ${_formatCurrency(_autoSessionOutstanding)}.'),
          backgroundColor: Colors.teal.shade600,
        ),
      );
    }
  }

  Future<void> _recordAutoSessionHistory(
    SharedPreferences prefs,
    String username, {
    required String event,
    double charge = 0.0,
    double? balanceAfter,
    double? coverageInvestment,
    double? requiredTotal,
    double? paidTotal,
    double? outstanding,
  }) async {
    final history =
        prefs.getStringList('${username}_family_tree_work_session_history') ??
            [];
    final entry = jsonEncode({
      'date': DateTime.now().toIso8601String(),
      'sessionType': event,
      'charge': charge,
      'coverageInvestment': coverageInvestment,
      'balanceAfter': balanceAfter,
      'requiredTotal': requiredTotal,
      'paidTotal': paidTotal,
      'outstanding': outstanding,
    });
    history.insert(0, entry);
    if (history.length > _historyRetentionLimit) {
      history.removeRange(
        _historyRetentionLimit,
        history.length,
      );
    }
    await prefs.setStringList(
        '${username}_family_tree_work_session_history', history);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadClockInData() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    final savedProfileImagePath =
        prefs.getString('${username}_family_tree_profile_image');
    final savedProfileImageSource =
        prefs.getString('${username}_family_tree_profile_image_source');
    final hasLocalProfileImage =
        savedProfileImagePath != null && savedProfileImageSource == 'file';

    final totalSessions =
        prefs.getInt('family_tree_total_sessions') ?? _adminClockInTimes.length;
    var sessionCount = math.max(1, totalSessions);
    final adminTimes = <TimeOfDay>[];

    for (var i = 0; i < sessionCount; i++) {
      final hour = prefs.getInt('family_tree_session_${i}_hour');
      final minute = prefs.getInt('family_tree_session_${i}_minute');
      if (hour != null && minute != null) {
        adminTimes.add(TimeOfDay(hour: hour, minute: minute));
      }
    }

    if (adminTimes.isNotEmpty) {
      sessionCount = adminTimes.length;
      _adminClockInTimes = adminTimes;
    } else {
      sessionCount = _adminClockInTimes.length;
    }

  final storedDuration =
    prefs.getInt('family_tree_admin_session_duration');
  final clampedDuration =
    math.max(40, math.min(120, storedDuration ?? 40));
  if (storedDuration != clampedDuration) {
    await prefs.setInt(
      'family_tree_admin_session_duration', clampedDuration);
  }
  _clockInDurationMinutes = clampedDuration;
    _ensureSessionArrayLengths(sessionCount);

    final completedClockInsJson =
        prefs.getStringList('${username}_family_tree_completed_clock_ins') ??
            <String>[];
    final missedClockInsJson =
        prefs.getStringList('${username}_family_tree_missed_clock_ins') ??
            <String>[];
    final referenceTime = DateTime.now();
    final todayKey = _operationalDayKey(referenceTime);
    final lastClockInDate =
        prefs.getString('${username}_family_tree_last_clock_in_date');

    List<bool> loadedCompletedClockIns;
    List<bool> loadedMissedClockIns;

    if (lastClockInDate != todayKey) {
      loadedCompletedClockIns = List<bool>.filled(sessionCount, false);
      loadedMissedClockIns = List<bool>.filled(sessionCount, false);
      await prefs.setStringList(
          '${username}_family_tree_completed_clock_ins', <String>[]);
      await prefs.setStringList(
          '${username}_family_tree_missed_clock_ins', <String>[]);
      await prefs.setString(
          '${username}_family_tree_last_clock_in_date', todayKey);
    } else {
      final completedFlags = List<bool>.filled(sessionCount, false);
      for (final entry in completedClockInsJson) {
        final parsed = int.tryParse(entry);
        if (parsed != null && parsed >= 0 && parsed < sessionCount) {
          completedFlags[parsed] = true;
        }
      }

      final missedFlags = List<bool>.filled(sessionCount, false);
      for (final entry in missedClockInsJson) {
        final parsed = int.tryParse(entry);
        if (parsed != null && parsed >= 0 && parsed < sessionCount) {
          missedFlags[parsed] = true;
        }
      }

      loadedCompletedClockIns = completedFlags;
      loadedMissedClockIns = missedFlags;
    }

    // Don't auto-mark sessions as missed during initial load
    // Let the timer handle missed session detection

    // Read from user-specific family_tree keys
    final clockInStartString =
        prefs.getString('${username}_family_tree_clock_in_start_time');
    final savedBalance = prefs.getDouble('${username}_family_tree_balance') ??
        prefs.getDouble('family_tree_total_balance') ??
        0.0;
    final savedActiveDays =
        prefs.getInt('${username}_family_tree_active_days') ??
            prefs.getInt('family_tree_active_days') ??
            0;

    // ALWAYS load today's earnings from storage (so it persists when app reopens)
    // Use Family Tree specific keys ONLY - NOT connected to Growth
    final savedTodayEarnings =
        prefs.getDouble('${username}_family_tree_today_earnings') ?? 0.0;

    // Load last claimed amount (tracks what user already claimed/deposited)
    final savedLastClaimed =
        prefs.getDouble('${username}_family_tree_last_claimed_amount') ?? 0.0;

    // ALWAYS load today's bandwidth from storage and NEVER reset it
    // Bandwidth should accumulate continuously without ever resetting
    // Use Family Tree specific keys ONLY - NOT connected to Growth
    final savedTodayBandwidth =
        prefs.getDouble('${username}_family_tree_today_bandwidth') ?? 0.0;

    final rawHistory =
        prefs.getStringList('${username}_family_tree_earnings_history') ??
            const <String>[];
    final parsedHistory = <_DailyEarning>[];
    for (final entry in rawHistory) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, dynamic>) {
          final parsed = _DailyEarning.fromMap(decoded);
          if (parsed != null) {
            parsedHistory.add(parsed);
          }
        }
      } catch (_) {
        continue;
      }
    }
    parsedHistory.sort((a, b) => a.date.compareTo(b.date));
    final retainedHistory = _applyHistoryRetention(parsedHistory);

    DateTime? investmentStartDate;
    final storedStartDate =
        prefs.getString('${username}_family_tree_investment_start_date');
    if (storedStartDate != null) {
      investmentStartDate = DateTime.tryParse(storedStartDate)?.toLocal();
    }

    DateTime? activationStamp;
    final storedActivation =
        prefs.getString('${username}_family_tree_investment_activated_at') ??
            prefs.getString('family_tree_investment_activated_at');
    if (storedActivation != null) {
      activationStamp = DateTime.tryParse(storedActivation)?.toLocal();
    }

    String? pendingStatus =
        prefs.getString('${username}_family_tree_withdraw_status');
    final pendingAmount =
        prefs.getDouble('${username}_family_tree_withdraw_pending_amount') ??
            0.0;
    final pendingContribution = prefs.getDouble(
            '${username}_family_tree_withdraw_pending_contribution') ??
        0.0;
    final pendingStandardFee = prefs.getDouble(
            '${username}_family_tree_withdraw_pending_standard_fee') ??
        0.0;
    final pendingNet = prefs
            .getDouble('${username}_family_tree_withdraw_pending_net_amount') ??
        0.0;
    final pendingBalanceAfter = prefs.getDouble(
            '${username}_family_tree_withdraw_pending_balance_after') ??
        0.0;
    final pendingOutstandingAfter = prefs.getDouble(
            '${username}_family_tree_withdraw_pending_outstanding_after') ??
        0.0;
    final pendingTimestamp =
        prefs.getInt('${username}_family_tree_withdraw_pending_timestamp');
    final pendingRequestId =
        prefs.getString('${username}_family_tree_withdraw_request_id');
    DateTime? pendingRequestedAt;
    if (pendingTimestamp != null) {
      pendingRequestedAt =
          DateTime.fromMillisecondsSinceEpoch(pendingTimestamp).toLocal();
    }

    if (pendingStatus != null && pendingStatus != 'pending') {
      await prefs.remove('${username}_family_tree_withdraw_status');
      await prefs.remove('${username}_family_tree_withdraw_pending_amount');
      await prefs.remove('${username}_family_tree_withdraw_pending_timestamp');
      await prefs.remove('${username}_family_tree_withdraw_request_id');
      await prefs
          .remove('${username}_family_tree_withdraw_pending_contribution');
      await prefs
          .remove('${username}_family_tree_withdraw_pending_standard_fee');
      await prefs.remove('${username}_family_tree_withdraw_pending_net_amount');
      await prefs
          .remove('${username}_family_tree_withdraw_pending_balance_after');
      await prefs
          .remove('${username}_family_tree_withdraw_pending_outstanding_after');
      pendingStatus = null;
    }

    final hasPendingWithdrawal = pendingStatus == 'pending';
    final pendingAmountValue = hasPendingWithdrawal ? pendingAmount : 0.0;
    final pendingContributionValue =
        hasPendingWithdrawal ? pendingContribution : 0.0;
    final pendingStandardFeeValue =
        hasPendingWithdrawal ? pendingStandardFee : 0.0;
    final pendingNetValue = hasPendingWithdrawal ? pendingNet : 0.0;
    final pendingBalanceValue =
        hasPendingWithdrawal ? pendingBalanceAfter : 0.0;
    final pendingOutstandingValue =
        hasPendingWithdrawal ? pendingOutstandingAfter : 0.0;

    // Load saved values regardless of reset status - earnings should persist until manually reset
    setState(() {
      _completedClockIns = loadedCompletedClockIns;
      _missedClockIns = loadedMissedClockIns;
      _todayEarnings = savedTodayEarnings;
      _bandwidth = savedTodayBandwidth;
      _familyTreeUserName = username;
      _profileImagePath = savedProfileImagePath;
      _profileImageIsLocalFile = hasLocalProfileImage;
      _hasPendingWithdrawal = hasPendingWithdrawal;
      _pendingWithdrawalAmount = pendingAmountValue;
      _pendingWithdrawalContribution = pendingContributionValue;
      _pendingWithdrawalStandardFee = pendingStandardFeeValue;
      _pendingWithdrawalNetAmount = pendingNetValue;
      _pendingWithdrawalBalanceAfter = pendingBalanceValue;
      _pendingWithdrawalOutstandingAfter = pendingOutstandingValue;
      _pendingWithdrawalStatus = pendingStatus;
      _pendingWithdrawalRequestedAt = pendingRequestedAt;
      _pendingWithdrawalRequestId =
          hasPendingWithdrawal ? pendingRequestId : null;
    });

    // Load claim cooldown state - Family Tree specific
    final now = DateTime.now();
    final lastClaimTimeString =
        prefs.getString('${username}_family_tree_last_claim_time');
    if (lastClaimTimeString != null) {
      final lastClaimTime = DateTime.parse(lastClaimTimeString);
      final cooldownEnd =
          lastClaimTime.add(const Duration(seconds: 15)); // 15 seconds cooldown

      if (now.isBefore(cooldownEnd)) {
        // Still on cooldown
        setState(() {
          _isClaimOnCooldown = true;
          _lastClaimTime = lastClaimTime;
          _claimCooldownRemaining = cooldownEnd.difference(now);
        });
      } else {
        // Cooldown expired, clear it
        await prefs.remove('${username}_family_tree_last_claim_time');
      }
    }

    // Load approved and pending investments from user-specific keys
    final approvedInvestment =
        prefs.getDouble('${username}_family_tree_approved_investment') ??
            prefs.getDouble('family_tree_approved_investment') ??
            0.0;
    final autoSessionEnabled =
        prefs.getBool('${username}_family_tree_auto_session_enabled') ?? false;
    final autoSessionCoverage =
        prefs.getDouble('${username}_family_tree_auto_session_coverage') ?? 0.0;
    final autoSessionPaidTotal =
        prefs.getDouble('${username}_family_tree_auto_session_paid_total') ??
            0.0;
    final autoSessionRequiredTotal = prefs
            .getDouble('${username}_family_tree_auto_session_required_total') ??
        (autoSessionEnabled ? approvedInvestment * 0.2 : 0.0);

    if (approvedInvestment > 0 && activationStamp == null) {
      final now = DateTime.now();
      activationStamp = now;
      await prefs.setString('${username}_family_tree_investment_activated_at',
          now.toIso8601String());
      await prefs.setString(
          'family_tree_investment_activated_at', now.toIso8601String());
    } else if (approvedInvestment <= 0 && activationStamp != null) {
      await prefs.remove('${username}_family_tree_investment_activated_at');
      await prefs.remove('family_tree_investment_activated_at');
      activationStamp = null;
    }

    if (approvedInvestment > 0 && investmentStartDate == null) {
      final normalizedStart = _normalizeDate(DateTime.now());
      investmentStartDate = normalizedStart;
      await prefs.setString('${username}_family_tree_investment_start_date',
          normalizedStart.toIso8601String());
    }

    setState(() {
      _totalBalance = savedBalance;
      _activeDays = savedActiveDays;
      _currentInvestment = approvedInvestment;
      _lastClaimedAmount = savedLastClaimed;
      _autoSessionEnabled = autoSessionEnabled;
      _autoSessionCoverage = autoSessionCoverage;
      _autoSessionPaidTotal = autoSessionPaidTotal;
      _autoSessionRequiredTotal = math.max(0.0, autoSessionRequiredTotal);
      _earningsHistory = List<_DailyEarning>.from(retainedHistory);
      _investmentStartDate = investmentStartDate;
      _investmentActivatedAt = activationStamp;
    });

    if (!mounted) {
      _earningsHistory = List<_DailyEarning>.from(retainedHistory);
      _investmentStartDate = investmentStartDate;
      _investmentActivatedAt = activationStamp;
    }

    if (activationStamp != null && _missedClockIns.isNotEmpty) {
      final sanitizedMissed = List<bool>.from(_missedClockIns);
      final cleared = _clearMissedSessionsBeforeActivation(
        activation: activationStamp,
        missedFlags: sanitizedMissed,
      );
      if (cleared) {
        if (mounted) {
          setState(() {
            _missedClockIns = sanitizedMissed;
          });
        } else {
          _missedClockIns = sanitizedMissed;
        }
        await _saveMissedClockIns(prefsOverride: prefs);
      }
    }

    await _markAllCompletedSessionsCredited(
      prefs,
      username,
      reference: DateTime.now(),
    );

    await _reconcileAutoSessionUpgrade(
      prefsOverride: prefs,
      usernameOverride: username,
      silent: true,
    );

    // Parse active clock-in start time if available
    if (clockInStartString != null) {
      _clockInStartTime = DateTime.parse(clockInStartString);
      _isClockInActive = true;

      final activeStart = _clockInStartTime!;
      final matchedIndex = _adminClockInTimes.indexWhere(
        (time) =>
            time.hour == activeStart.hour && time.minute == activeStart.minute,
      );
      if (matchedIndex != -1 && matchedIndex < _completedClockIns.length) {
        _currentClockInIndex = matchedIndex;
      }

      final now = DateTime.now();
      final elapsed = now.difference(activeStart);
      final sessionSeconds = math.max(1, _clockInDurationMinutes * 60);
      final elapsedSeconds = elapsed.inSeconds.clamp(0, sessionSeconds);
      final progressBandwidth = (elapsedSeconds / 60.0) * 10.0;
      final baselineBandwidth =
          math.max(0.0, savedTodayBandwidth - progressBandwidth);
      _sessionStartBandwidth = math.min(baselineBandwidth, _maxBandwidth);

      if (elapsed.inMinutes >= _clockInDurationMinutes) {
        _isClockInActive = false;
        _clockInStartTime = null;
        await prefs.remove('${username}_family_tree_clock_in_start_time');
      } else {
        _isClockInActive = true;
        await _syncActiveSessionProgress(
            now: now, prefs: prefs, username: username);
      }
    }

    await _updateFamilyTreeFinancialSummary(
      prefsOverride: prefs,
      usernameOverride: username,
      investmentOverride: approvedInvestment,
    );

    // Check if it's past midnight (clock-in available)
    _checkMidnightAvailability();
  }

  DateTime _resolveSessionDateTime(TimeOfDay sessionTime, DateTime reference) {
    final today = DateTime(reference.year, reference.month, reference.day);
    final base = DateTime(
      today.year,
      today.month,
      today.day,
      sessionTime.hour,
      sessionTime.minute,
    );

    if (reference.hour >= _dailyResetHour) {
      return sessionTime.hour < _dailyResetHour
          ? base.add(const Duration(days: 1))
          : base;
    }

    // Before the 6 AM reset window keep the slots anchored to today so they
    // only complete after their actual start time.
    return base;
  }

  int _findCurrentClockInIndex() {
    final now = DateTime.now();

    if (!_isWorkingDay(now, _adminWorkingDays)) {
      return -1;
    }

    _ensureSessionArrayLengths(_adminClockInTimes.length);

    final loopLength =
        math.min(_adminClockInTimes.length, _completedClockIns.length);
    final activation = _investmentActivatedAt;

    for (var i = 0; i < loopLength; i++) {
      if (_completedClockIns[i]) {
        continue;
      }

      final sessionTime = _adminClockInTimes[i];
      final sessionStart = _resolveSessionDateTime(sessionTime, now);
      if (activation != null && sessionStart.isBefore(activation)) {
        continue;
      }
      // Only allow starting during the exact scheduled minute.
      if (now.isBefore(sessionStart)) {
        continue; // Too early
      }

      final sessionWindowEnd = sessionStart.add(const Duration(minutes: 1));
      if (!now.isBefore(sessionWindowEnd)) {
        continue; // Window has passed
      }

      return i;
    }

    return -1;
  }

  ({int index, DateTime start, bool isActive})? _nextSessionInfo(
      DateTime reference) {
    if (_adminClockInTimes.isEmpty) {
      return null;
    }

    _ensureSessionArrayLengths(_adminClockInTimes.length);

    final sessionDuration =
        Duration(minutes: math.max(1, _clockInDurationMinutes));
    ({int index, DateTime start, bool isActive})? bestCandidate;
    final activation = _investmentActivatedAt;

    for (var i = 0; i < _adminClockInTimes.length; i++) {
      final sessionStart =
          _resolveSessionDateTime(_adminClockInTimes[i], reference);
      final sessionEnd = sessionStart.add(sessionDuration);
      if (activation != null && sessionStart.isBefore(activation)) {
        continue;
      }
      final isCompleted =
          i < _completedClockIns.length && _completedClockIns[i];

      final isActive = !isCompleted &&
          !reference.isBefore(sessionStart) &&
          reference.isBefore(sessionEnd);
      if (isActive) {
        return (index: i, start: sessionStart, isActive: true);
      }

      if (!isCompleted && reference.isBefore(sessionStart)) {
        final candidate = (index: i, start: sessionStart, isActive: false);
        if (bestCandidate == null ||
            candidate.start.isBefore(bestCandidate.start)) {
          bestCandidate = candidate;
        }
        continue;
      }

      final nextDayStart = sessionStart.add(const Duration(days: 1));
      final candidate = (index: i, start: nextDayStart, isActive: false);
      if (bestCandidate == null ||
          candidate.start.isBefore(bestCandidate.start)) {
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }

  String _sessionStatusLabel(BuildContext context) {
    if (_isClockInActive) {
      return 'Active Session';
    }
    if (_isClockInAvailable) {
      return 'Ready to Start';
    }

    final now = DateTime.now();
    final nextInfo = _nextSessionInfo(now);
    if (nextInfo != null) {
      TimeOfDay? sessionTime;
      if (nextInfo.index >= 0 && nextInfo.index < _adminClockInTimes.length) {
        sessionTime = _adminClockInTimes[nextInfo.index];
      }
      final timeText = (sessionTime ?? TimeOfDay.fromDateTime(nextInfo.start))
          .format(context);
      return 'Next Session $timeText';
    }

    return 'Next Session';
  }

  Future<void> _startSession({
    required int index,
    required DateTime startTime,
    SharedPreferences? prefsOverride,
    bool autoTriggered = false,
    bool showFeedback = true,
    double? sessionStartBandwidthOverride,
    DateTime? referenceTime,
  }) async {
    _ensureSessionArrayLengths(_adminClockInTimes.length);
    if (index < 0 || index >= _adminClockInTimes.length) {
      return;
    }

    final activation = _investmentActivatedAt;
    if (activation != null && startTime.isBefore(activation)) {
      if (!autoTriggered && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final unlockLabel = MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(activation),
          alwaysUse24HourFormat: false,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text('Clock-in unlocks after $unlockLabel.'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }

    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';

    final effectiveReference = referenceTime ?? DateTime.now();
    final sessionSeconds = math.max(1, _clockInDurationMinutes * 60);
    var elapsedSeconds = effectiveReference.isBefore(startTime)
        ? 0
        : effectiveReference.difference(startTime).inSeconds;
    if (elapsedSeconds < 0) {
      elapsedSeconds = 0;
    } else if (elapsedSeconds > sessionSeconds) {
      elapsedSeconds = sessionSeconds;
    }

    final computedDuration = Duration(seconds: elapsedSeconds);

    _currentClockInIndex = index;
    _clockInStartTime = startTime;
    _isClockInActive = true;
    _sessionStartBandwidth = sessionStartBandwidthOverride ?? _bandwidth;
    _autoSessionTriggeredIndices.add(index);

    if (index < _missedClockIns.length) {
      _missedClockIns[index] = false;
      await _saveMissedClockIns(prefsOverride: prefs);
    }

    await prefs.setString(
      '${username}_family_tree_clock_in_start_time',
      startTime.toIso8601String(),
    );

    if (mounted) {
      setState(() {
        _isClockInActive = true;
        _currentClockInIndex = index;
        _workDuration = computedDuration;
      });
    }

    await _syncActiveSessionProgress(
      now: effectiveReference,
      prefs: prefs,
      username: username,
    );

    if (showFeedback && mounted) {
      final totalSessions = _adminClockInTimes.isNotEmpty
          ? _adminClockInTimes.length
          : _completedClockIns.length;
      final sessionEarnings = _sessionEarningsValue();
      final sessionTime =
          index < _adminClockInTimes.length ? _adminClockInTimes[index] : null;
      final label = autoTriggered ? 'Auto session' : 'Session';
      final timeDisplay =
          sessionTime != null ? sessionTime.format(context) : 'Scheduled';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$label ${index + 1}/$totalSessions started\nTime: $timeDisplay • Duration: $_clockInDurationMinutes min\nEarnings: ₦₲${sessionEarnings.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  double _claimableEarnings() {
    final rawClaimable = _todayEarnings - _lastClaimedAmount;
    // Guard against tiny negative rounding errors
    if (rawClaimable <= 0.0001) {
      return 0.0;
    }
    return rawClaimable;
  }

  Future<void> _completeClockInSession() async {
    if (_currentClockInIndex == -1) {
      return;
    }
    // Prevent duplicate completion when timer fires multiple times
    final completedSessionIndex = _currentClockInIndex;
    if (completedSessionIndex < 0 ||
        completedSessionIndex >= _completedClockIns.length) {
      return;
    }
    if (_completedClockIns[completedSessionIndex]) {
      // Already marked complete; nothing else to do.
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final username = _familyTreeUserName.isNotEmpty
        ? _familyTreeUserName
        : prefs.getString('family_tree_user_name') ?? 'NGMY User';

    // Calculate session earnings (3.33% ÷ 5 = 0.666% per session)
    final sessionEarnings = _sessionEarningsValue();

    // Mark this session as completed - PRIORITY: This must happen FIRST
    _completedClockIns[completedSessionIndex] = true;

    // Clear missed flag for this session (completed sessions should NEVER show red X)
    _missedClockIns[completedSessionIndex] = false;

    // Save completed sessions IMMEDIATELY
    final completedIndices = <String>[];
    for (int i = 0; i < _completedClockIns.length; i++) {
      if (_completedClockIns[i]) {
        completedIndices.add(i.toString());
      }
    }
    await prefs.setStringList(
        '${username}_family_tree_completed_clock_ins', completedIndices);

    // CRITICAL: Update the last clock-in date to TODAY so state persists
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    await prefs.setString(
        '${username}_family_tree_last_clock_in_date', todayString);

    // Save missed sessions (with completed session's missed flag cleared)
    await _saveMissedClockIns(prefsOverride: prefs);

    // Recalculate todays earnings purely from completed sessions to avoid double counting
    final completedCount =
        _completedClockIns.where((completed) => completed).length;
    _todayEarnings = completedCount * sessionEarnings;
    await prefs.setDouble(
        '${username}_family_tree_today_earnings', _todayEarnings);

    // Increment active days if this is first session of the day
    final lastActiveDate =
        prefs.getString('${username}_family_tree_last_active_date');
    if (lastActiveDate != todayString) {
      _activeDays++;
      await prefs.setInt('${username}_family_tree_active_days', _activeDays);
      await prefs.setString(
          '${username}_family_tree_last_active_date', todayString);
    }

    // Auto-deposit any unclaimed money when the session ends
    final storedBalance = _storedFamilyTreeBalance(prefs, username);
    final autoDepositAmount = _claimableEarnings();
    final sessionCredited = await _isSessionCreditedToday(
      prefs,
      username,
      completedSessionIndex,
      reference: today,
    );

    if (autoDepositAmount > 0 && !sessionCredited) {
      final balanceBeforeAutoDeposit = storedBalance;
      final newBalanceAfterDeposit = storedBalance + autoDepositAmount;

      final currentTotalEarnings =
          prefs.getDouble('${username}_family_tree_total_earnings') ?? 0.0;
      await prefs.setDouble(
        '${username}_family_tree_total_earnings',
        currentTotalEarnings + autoDepositAmount,
      );

      await prefs.setDouble(
          'family_tree_total_balance', newBalanceAfterDeposit);
      await prefs.setDouble(
          '${username}_family_tree_balance', newBalanceAfterDeposit);

      final workHistory =
          prefs.getStringList('${username}_family_tree_work_session_history') ??
              [];
      final sessionRecord = jsonEncode({
        'date': DateTime.now().toIso8601String(),
        'balanceBefore': balanceBeforeAutoDeposit,
        'balanceAfter': newBalanceAfterDeposit,
        'earnings': autoDepositAmount,
        'sessionType': 'family_tree_auto_deposit',
      });
      workHistory.insert(0, sessionRecord);
      if (workHistory.length > _historyRetentionLimit) {
        workHistory.removeRange(_historyRetentionLimit, workHistory.length);
      }
      await prefs.setStringList(
          '${username}_family_tree_work_session_history', workHistory);

      _totalBalance = newBalanceAfterDeposit;
      _lastClaimedAmount = _todayEarnings;
      await prefs.setDouble(
          '${username}_family_tree_last_claimed_amount', _lastClaimedAmount);
      await _markSessionCredited(
        prefs,
        username,
        completedSessionIndex,
        reference: today,
      );
    } else {
      _totalBalance = storedBalance;
      _lastClaimedAmount = _todayEarnings;
      await prefs.setDouble(
          '${username}_family_tree_last_claimed_amount', _lastClaimedAmount);
      if (!sessionCredited) {
        await _markSessionCredited(
          prefs,
          username,
          completedSessionIndex,
          reference: today,
        );
      }
    }

    await _updateFamilyTreeFinancialSummary(
      prefsOverride: prefs,
      usernameOverride: username,
    );

    await _syncDailySnapshot(
      prefs: prefs,
      username: username,
      reference: today,
    );

    // Clear any remaining cooldown so the next session starts fresh
    _isClaimOnCooldown = false;
    _claimCooldownRemaining = Duration.zero;
    _lastClaimTime = null;
    await prefs.remove('${username}_family_tree_last_claim_time');

    // Reset session state AFTER session completes - allow next session to start
    _isClockInActive = false; // Stop the timer
    _clockInStartTime = null;
    _currentClockInIndex = -1;

    // Clear active session from storage
    await prefs.remove('${username}_family_tree_clock_in_start_time');

    // Force immediate UI update - UPDATE THE ARRAYS TO TRIGGER REBUILD
    if (mounted) {
      setState(() {
        // Explicitly update to trigger circle rendering
        _completedClockIns = List.from(_completedClockIns);
        _missedClockIns = List.from(_missedClockIns);
      });
    }

    if (mounted) {
      final autoDepositLine = autoDepositAmount > 0
          ? 'Auto-Deposited: ₦₲${autoDepositAmount.toStringAsFixed(2)} -> Balance ₦₲${_totalBalance.toStringAsFixed(2)}'
          : 'All session earnings already in balance.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session ${completedSessionIndex + 1}/5 completed!\n'
              'Session Earnings: ₦₲${sessionEarnings.toStringAsFixed(2)}\n'
              '$autoDepositLine\n'
              'Today\'s Earnings: ₦₲${_todayEarnings.toStringAsFixed(2)}'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _checkMidnightAvailability() async {
    final now = DateTime.now();

    // Check for 6:00 AM daily reset
    await _check6AMReset();

    final todayAllowed = _isWorkingDay(now, _adminWorkingDays);
    _isTodayAllowedByAdmin = todayAllowed;
    if (!todayAllowed) {
      _timeUntilAllSessionsComplete = Duration.zero;
      _isClockInAvailable = false;
      return;
    }

    // Calculate time until all sessions are complete
    if (_adminClockInTimes.isNotEmpty) {
      // Find the last/latest session time of the day
      TimeOfDay? latestSessionTime;
      for (final time in _adminClockInTimes) {
        if (latestSessionTime == null ||
            time.hour > latestSessionTime.hour ||
            (time.hour == latestSessionTime.hour &&
                time.minute > latestSessionTime.minute)) {
          latestSessionTime = time;
        }
      }

      if (latestSessionTime != null) {
        // Calculate time until the last session plus the configured session duration
        final lastSessionDateTime = DateTime(now.year, now.month, now.day,
            latestSessionTime.hour, latestSessionTime.minute);

        // Add session duration for the completion time
        final allSessionsCompleteTime =
            lastSessionDateTime.add(Duration(minutes: _clockInDurationMinutes));

        // If the completion time has already passed today, show zero
        if (now.isAfter(allSessionsCompleteTime)) {
          _timeUntilAllSessionsComplete = Duration.zero;
        } else {
          _timeUntilAllSessionsComplete =
              allSessionsCompleteTime.difference(now);
        }
      }
    } else {
      _timeUntilAllSessionsComplete = Duration.zero;
    }

    final availableIndex = _findCurrentClockInIndex();
    _isClockInAvailable = availableIndex != -1;

    if (availableIndex != -1) {
      _ensureAutoSessionTriggerWindow(DateTime.now());
    }
  }

  void _checkForMissedSessions() {
    final now = DateTime.now();

    _ensureSessionArrayLengths(_adminClockInTimes.length);

    if (!_isWorkingDay(now, _adminWorkingDays)) {
      var clearedAny = false;
      for (var i = 0; i < _missedClockIns.length; i++) {
        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          clearedAny = true;
        }
      }
      if (clearedAny) {
        _saveMissedClockIns();
      }
      return;
    }

    if (_currentInvestment <= 0) {
      var clearedAny = false;
      for (var i = 0; i < _missedClockIns.length; i++) {
        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          clearedAny = true;
        }
      }
      if (clearedAny) {
        _saveMissedClockIns();
      }
      return;
    }

    bool needsSave = false;

    final loopLength =
        math.min(_adminClockInTimes.length, _missedClockIns.length);
    for (int i = 0; i < loopLength; i++) {
      // PRIORITY 1: If completed, ensure NEVER marked as missed
      if (i < _completedClockIns.length && _completedClockIns[i]) {
        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          needsSave = true;
        }
        continue; // Skip all other checks for completed sessions
      }

      // PRIORITY 2: If currently active, ensure NOT marked as missed
      if (_isClockInActive && _currentClockInIndex == i) {
        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          needsSave = true;
        }
        continue; // Skip all other checks for active sessions
      }

      // Check if this session's time has passed
      final sessionTime = _adminClockInTimes[i];
      final sessionDateTime = _resolveSessionDateTime(sessionTime, now);
      final activation = _investmentActivatedAt;
      if (activation != null && sessionDateTime.isBefore(activation)) {
        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          needsSave = true;
        }
        continue;
      }

      // Calculate the missed threshold (one-minute start window)
      final missedThreshold = sessionDateTime.add(const Duration(minutes: 1));

      // FUTURE TIME: If session time hasn't arrived yet, ensure NOT marked as missed
      if (now.isBefore(sessionDateTime)) {
        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          needsSave = true;
        }
      }
      // AVAILABLE WINDOW: If we're between session start and missed threshold, still available
      else if (now.isAfter(sessionDateTime) && now.isBefore(missedThreshold)) {
        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          needsSave = true;
        }
      }
      // PAST WINDOW: Time has PASSED the entire window - mark as missed
      else if (now.isAfter(missedThreshold)) {
        if (!_missedClockIns[i]) {
          _missedClockIns[i] = true;
          needsSave = true;
        }
      }
    }

    if (needsSave) {
      _saveMissedClockIns();
    }
  }

  void _ensureAutoSessionTriggerWindow(DateTime now) {
    if (_autoSessionTriggerStamp == null ||
        !_isSameDay(_autoSessionTriggerStamp!, now)) {
      _autoSessionTriggeredIndices.clear();
      _autoSessionTriggerStamp = DateTime(now.year, now.month, now.day);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _ensureSessionArrayLengths(int desiredLength) {
    final normalizedLength = math.max(1, desiredLength);
    final currentCompletedLength = _completedClockIns.length;
    final currentMissedLength = _missedClockIns.length;

    if (currentCompletedLength == normalizedLength &&
        currentMissedLength == normalizedLength) {
      return;
    }

    final newCompleted = List<bool>.filled(normalizedLength, false);
    final copyCompleted = math.min(normalizedLength, currentCompletedLength);
    for (var i = 0; i < copyCompleted; i++) {
      newCompleted[i] = _completedClockIns[i];
    }

    final newMissed = List<bool>.filled(normalizedLength, false);
    final copyMissed = math.min(normalizedLength, currentMissedLength);
    for (var i = 0; i < copyMissed; i++) {
      newMissed[i] = _missedClockIns[i];
    }

    _completedClockIns = newCompleted;
    _missedClockIns = newMissed;

    if (_currentClockInIndex >= normalizedLength) {
      _currentClockInIndex = -1;
      _isClockInActive = false;
      _clockInStartTime = null;
    }
  }

  bool _clearMissedSessionsBeforeActivation({
    required DateTime activation,
    required List<bool> missedFlags,
  }) {
    if (_adminClockInTimes.isEmpty || missedFlags.isEmpty) {
      return false;
    }

    final sessionCount =
        math.min(_adminClockInTimes.length, missedFlags.length);
    var changed = false;

    for (var i = 0; i < sessionCount; i++) {
      final sessionStart =
          _resolveSessionDateTime(_adminClockInTimes[i], activation);
      if (sessionStart.isBefore(activation) && missedFlags[i]) {
        missedFlags[i] = false;
        changed = true;
      }
    }

    return changed;
  }

  Future<void> _syncActiveSessionProgress({
    required DateTime now,
    required SharedPreferences prefs,
    required String username,
  }) async {
    if (!_isClockInActive || _clockInStartTime == null) {
      return;
    }

    var elapsedSeconds = now.difference(_clockInStartTime!).inSeconds;
    if (elapsedSeconds < 0) {
      elapsedSeconds = 0;
    }

    final sessionSeconds = math.max(1, _clockInDurationMinutes * 60);
    if (elapsedSeconds > sessionSeconds) {
      elapsedSeconds = sessionSeconds;
    }

    final sessionEarnings = _sessionEarningsValue();
    final completedSessions = _completedClockIns.where((c) => c).length;
    final baseEarnings = completedSessions * sessionEarnings;
    final progressRatio =
        math.max(0.0, math.min(1.0, elapsedSeconds / sessionSeconds));
    final currentSessionEarnings = sessionEarnings * progressRatio;
    final computedTodayEarnings = baseEarnings + currentSessionEarnings;

    if ((computedTodayEarnings - _todayEarnings).abs() > 0.0001) {
      _todayEarnings = computedTodayEarnings;
      await prefs.setDouble(
          '${username}_family_tree_today_earnings', _todayEarnings);
    }

    final sessionBandwidth = (elapsedSeconds / 60.0) * 10.0;
    final computedBandwidth = _sessionStartBandwidth + sessionBandwidth;
    if ((computedBandwidth - _bandwidth).abs() > 0.0001) {
      _bandwidth = computedBandwidth;
      await prefs.setDouble(
          '${username}_family_tree_today_bandwidth', _bandwidth);
    }
  }

  Future<void> _handleAutoSessionsIfNeeded({DateTime? reference}) async {
    if (_currentInvestment <= 0) {
      return;
    }

    _ensureSessionArrayLengths(_adminClockInTimes.length);

    final prefs = await SharedPreferences.getInstance();
    final username =
        prefs.getString('family_tree_user_name') ?? _familyTreeUserName;
    if (username == 'NGMY User' || username.isEmpty) {
      return;
    }

    final now = reference ?? DateTime.now();
    final workingDays = _resolveAdminWorkingDays(prefs);
    final todayAllowed = _isWorkingDay(now, workingDays);
    if (!listEquals(workingDays, _adminWorkingDays) ||
        todayAllowed != _isTodayAllowedByAdmin) {
      if (mounted) {
        setState(() {
          _adminWorkingDays = workingDays;
          _isTodayAllowedByAdmin = todayAllowed;
        });
      } else {
        _adminWorkingDays = workingDays;
        _isTodayAllowedByAdmin = todayAllowed;
      }
    }

    if (!todayAllowed) {
      return;
    }

    _ensureAutoSessionTriggerWindow(now);

    var completionsOccurred = false;
    var missedStateUpdated = false;
    int? activatedIndex;

    final sessionCount =
        math.min(_adminClockInTimes.length, _completedClockIns.length);
    for (var i = 0; i < sessionCount; i++) {
      if (_completedClockIns[i]) {
        continue;
      }

      final sessionTime = _adminClockInTimes[i];
      final sessionStart = _resolveSessionDateTime(sessionTime, now);
      final sessionEnd =
          sessionStart.add(Duration(minutes: _clockInDurationMinutes));

      final activation = _investmentActivatedAt;
      if (activation != null && sessionStart.isBefore(activation)) {
        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          missedStateUpdated = true;
        }
        continue;
      }

      if (now.isBefore(sessionStart)) {
        continue;
      }

      if (now.isBefore(sessionEnd)) {
        final alreadyActive = _isClockInActive &&
            _currentClockInIndex == i &&
            _clockInStartTime != null;
        final alreadyTriggered = _autoSessionTriggeredIndices.contains(i);

        if (!alreadyActive && !alreadyTriggered) {
          await _startSession(
            index: i,
            startTime: sessionStart,
            prefsOverride: prefs,
            autoTriggered: true,
            showFeedback: false,
            sessionStartBandwidthOverride: _bandwidth,
            referenceTime: now,
          );
          activatedIndex = i;
        } else if (!alreadyActive) {
          _currentClockInIndex = i;
          _clockInStartTime = sessionStart;
          _isClockInActive = true;
          activatedIndex = i;
        }

        if (_missedClockIns[i]) {
          _missedClockIns[i] = false;
          missedStateUpdated = true;
        }

        if (activatedIndex == i && _clockInStartTime != null) {
          await _syncActiveSessionProgress(
              now: now, prefs: prefs, username: username);
        }

        continue;
      }

      if (now.weekday == DateTime.sunday) {
        final sundayStart = DateTime(now.year, now.month, now.day);
        if (sessionEnd.isBefore(sundayStart)) {
          // Prevent Saturday sessions from crediting during the Sunday cycle.
          if (!_missedClockIns[i]) {
            _missedClockIns[i] = true;
            missedStateUpdated = true;
          }
          continue;
        }
      }

      await _completeSessionAutomatically(
        index: i,
        completionTime: sessionEnd,
        prefs: prefs,
        username: username,
      );
      completionsOccurred = true;
    }

    if (missedStateUpdated) {
      await _saveMissedClockIns(prefsOverride: prefs);
    }

    if (completionsOccurred) {
      await _updateFamilyTreeFinancialSummary(
        prefsOverride: prefs,
        usernameOverride: username,
      );

      if (mounted) {
        setState(() {
          _completedClockIns = List.from(_completedClockIns);
          _missedClockIns = List.from(_missedClockIns);
        });
      }
    } else if (activatedIndex != null && mounted && _clockInStartTime != null) {
      final sessionSeconds = math.max(1, _clockInDurationMinutes * 60);
      final elapsedSeconds = now.difference(_clockInStartTime!).inSeconds;
      final cappedSeconds =
          math.max(0, math.min(sessionSeconds, elapsedSeconds));

      setState(() {
        _isClockInActive = true;
        _currentClockInIndex = activatedIndex!;
        _workDuration = Duration(seconds: cappedSeconds);
      });
    }
  }

  Future<void> _completeSessionAutomatically({
    required int index,
    required DateTime completionTime,
    required SharedPreferences prefs,
    required String username,
  }) async {
    if (index < 0 || index >= _completedClockIns.length) {
      return;
    }
    if (_completedClockIns[index]) {
      return;
    }

    final sessionEarnings = _sessionEarningsValue();
    if (sessionEarnings <= 0) {
      // Nothing to credit but still mark completed so loops end.
      _completedClockIns[index] = true;
      _missedClockIns[index] = false;
      await _persistSessionStates(prefs, username);
      return;
    }

    final balanceBefore = _storedFamilyTreeBalance(prefs, username);
    final sessionCredited = await _isSessionCreditedToday(
      prefs,
      username,
      index,
      reference: completionTime,
    );
    final newBalance = balanceBefore + sessionEarnings;

    _completedClockIns[index] = true;
    _missedClockIns[index] = false;
    _autoSessionTriggeredIndices.add(index);

    final completedCount =
        _completedClockIns.where((completed) => completed).length;
    _todayEarnings = completedCount * sessionEarnings;
    await prefs.setDouble(
        '${username}_family_tree_today_earnings', _todayEarnings);

    final completedIndices = <String>[];
    for (var i = 0; i < _completedClockIns.length; i++) {
      if (_completedClockIns[i]) {
        completedIndices.add(i.toString());
      }
    }
    await prefs.setStringList(
        '${username}_family_tree_completed_clock_ins', completedIndices);
    await _saveMissedClockIns(prefsOverride: prefs);

    final todayString =
        '${completionTime.year}-${completionTime.month}-${completionTime.day}';
    final lastActiveDate =
        prefs.getString('${username}_family_tree_last_active_date');
    if (lastActiveDate != todayString) {
      _activeDays++;
      await prefs.setInt('${username}_family_tree_active_days', _activeDays);
      await prefs.setString(
          '${username}_family_tree_last_active_date', todayString);
    }
    await prefs.setString(
        '${username}_family_tree_last_clock_in_date', todayString);

    final storedTotalEarnings =
        prefs.getDouble('${username}_family_tree_total_earnings') ?? 0.0;
    await prefs.setDouble('${username}_family_tree_total_earnings',
        storedTotalEarnings + sessionEarnings);

    final sessionBandwidth = _sessionBandwidthValue();
    final storedBandwidth =
        prefs.getDouble('${username}_family_tree_today_bandwidth') ?? 0.0;
    _bandwidth = storedBandwidth + sessionBandwidth;
    await prefs.setDouble(
        '${username}_family_tree_today_bandwidth', _bandwidth);

    if (!sessionCredited) {
      _totalBalance = newBalance;
      await prefs.setDouble('family_tree_total_balance', newBalance);
      await prefs.setDouble('${username}_family_tree_balance', newBalance);

      _lastClaimedAmount = _todayEarnings;
      await prefs.setDouble(
          '${username}_family_tree_last_claimed_amount', _lastClaimedAmount);

      final workHistory =
          prefs.getStringList('${username}_family_tree_work_session_history') ??
              <String>[];
      final sessionRecord = jsonEncode({
        'date': completionTime.toIso8601String(),
        'balanceBefore': balanceBefore,
        'balanceAfter': newBalance,
        'earnings': sessionEarnings,
        'sessionType': 'family_tree_auto_session',
        'autoCompleted': true,
      });
      workHistory.insert(0, sessionRecord);
      if (workHistory.length > _historyRetentionLimit) {
        workHistory.removeRange(_historyRetentionLimit, workHistory.length);
      }
      await prefs.setStringList(
          '${username}_family_tree_work_session_history', workHistory);

      await _markSessionCredited(
        prefs,
        username,
        index,
        reference: completionTime,
      );
    } else {
      _totalBalance = balanceBefore;
      _lastClaimedAmount = _todayEarnings;
      await prefs.setDouble(
          '${username}_family_tree_last_claimed_amount', _lastClaimedAmount);
    }

    await _syncDailySnapshot(
      prefs: prefs,
      username: username,
      reference: completionTime,
    );

    if (_currentClockInIndex == index) {
      _currentClockInIndex = -1;
    }
    _isClockInActive = false;
    _clockInStartTime = null;
    await prefs.remove('${username}_family_tree_clock_in_start_time');
  }

  Future<void> _persistSessionStates(
      SharedPreferences prefs, String username) async {
    final completedIndices = <String>[];
    for (var i = 0; i < _completedClockIns.length; i++) {
      if (_completedClockIns[i]) {
        completedIndices.add(i.toString());
      }
    }
    await prefs.setStringList(
        '${username}_family_tree_completed_clock_ins', completedIndices);
    await _saveMissedClockIns(prefsOverride: prefs);
  }

  Future<void> _recordDailyEarningsSnapshot({
    required SharedPreferences prefs,
    required String username,
    required DateTime day,
    required double amount,
  }) async {
    final normalizedDay = _normalizeDate(day);
    final effectiveInvestment =
        prefs.getDouble('${username}_family_tree_approved_investment') ??
            prefs.getDouble('family_tree_approved_investment') ??
            _currentInvestment;
    if (effectiveInvestment <= 0) {
      return;
    }

    var storedStartDateString =
        prefs.getString('${username}_family_tree_investment_start_date');
    DateTime? storedStartDate;
    if (storedStartDateString != null) {
      storedStartDate = DateTime.tryParse(storedStartDateString)?.toLocal();
    }

    storedStartDate ??= normalizedDay;
    if (storedStartDateString == null) {
      await prefs.setString('${username}_family_tree_investment_start_date',
          storedStartDate.toIso8601String());
    }

    if (normalizedDay.isBefore(_normalizeDate(storedStartDate))) {
      return;
    }

    final sanitizedAmount = _sanitizeEarningAmount(amount);
    final history = List<_DailyEarning>.from(_earningsHistory);
    final existingIndex = history.indexWhere(
      (entry) => _isSameDay(_normalizeDate(entry.date), normalizedDay),
    );
    if (existingIndex != -1) {
      history[existingIndex] = _DailyEarning(
        date: normalizedDay,
        amount: sanitizedAmount,
      );
    } else {
      history.add(
        _DailyEarning(date: normalizedDay, amount: sanitizedAmount),
      );
    }

    history.sort((a, b) => a.date.compareTo(b.date));
    final trimmed = _applyHistoryRetention(history);
    final encoded = trimmed
        .map((entry) => jsonEncode(entry.toMap()))
        .toList(growable: false);
    await prefs.setStringList(
        '${username}_family_tree_earnings_history', encoded);

    if (mounted) {
      setState(() {
        _earningsHistory = trimmed;
        _investmentStartDate = storedStartDate;
      });
    } else {
      _earningsHistory = trimmed;
      _investmentStartDate = storedStartDate;
    }
  }

  Future<void> _check6AMReset() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';

    // Check if we need to reset at 6:00 AM
    final lastResetDate =
        prefs.getString('${username}_family_tree_last_6am_reset_date');
    final todayDateString = '${now.year}-${now.month}-${now.day}';

    // Only reset if it's past 6:00 AM and we haven't reset today yet
    if (now.hour >= 6 && lastResetDate != todayDateString) {
      final previousDay = _normalizeDate(now.subtract(const Duration(days: 1)));
      final snapshotEarnings = _todayEarnings;

      // Save yesterday's earnings for history tracking and charting
      await prefs.setDouble(
          '${username}_family_tree_yesterday_earnings', snapshotEarnings);
      await _recordDailyEarningsSnapshot(
        prefs: prefs,
        username: username,
        day: previousDay,
        amount: snapshotEarnings,
      );
      await prefs.setString(
          '${username}_family_tree_last_6am_reset_date', todayDateString);

      // Clear today's earnings from storage
      await prefs.setDouble('${username}_family_tree_today_earnings', 0.0);
      await prefs.setDouble('${username}_family_tree_last_claimed_amount', 0.0);
      await prefs.remove('${username}_family_tree_last_claim_time');

      // Reset completed sessions and missed sessions for the new day
      final sessionCount = _completedClockIns.length;
      final clearedCompleted = List<bool>.filled(sessionCount, false);
      final clearedMissed = List<bool>.filled(sessionCount, false);
      await prefs.remove('${username}_family_tree_completed_clock_ins');
      await prefs.remove('${username}_family_tree_missed_clock_ins');
      await prefs.remove('${username}_family_tree_clock_in_start_time');
      _autoSessionTriggeredIndices.clear();
      _autoSessionTriggerStamp = DateTime(now.year, now.month, now.day);

      if (mounted) {
        setState(() {
          _todayEarnings = 0.0;
          _lastClaimedAmount = 0.0;
          _completedClockIns = clearedCompleted;
          _missedClockIns = clearedMissed;
          _isClockInActive = false;
          _clockInStartTime = null;
          _currentClockInIndex = -1;
          _workDuration = Duration.zero;
          _isClaimOnCooldown = false;
          _claimCooldownRemaining = Duration.zero;
          _lastClaimTime = null;
        });
      } else {
        _todayEarnings = 0.0;
        _lastClaimedAmount = 0.0;
        _completedClockIns = clearedCompleted;
        _missedClockIns = clearedMissed;
        _isClockInActive = false;
        _clockInStartTime = null;
        _currentClockInIndex = -1;
        _workDuration = Duration.zero;
        _isClaimOnCooldown = false;
        _claimCooldownRemaining = Duration.zero;
        _lastClaimTime = null;
      }

      await _clearSessionCreditState(prefs, username);

      await _updateFamilyTreeFinancialSummary(
        prefsOverride: prefs,
        usernameOverride: username,
      );
    }
  }

  Future<void> _clearClaimCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    await prefs.remove('${username}_family_tree_last_claim_time');
  }

  Future<void> _saveMissedClockIns({SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';

    // Save missed sessions as list of indices
    final missedIndices = <String>[];
    for (int i = 0; i < _missedClockIns.length; i++) {
      if (_missedClockIns[i]) {
        missedIndices.add(i.toString());
      }
    }
    await prefs.setStringList(
        '${username}_family_tree_missed_clock_ins', missedIndices);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      // Handle SharedPreferences operations outside setState
      double updatedTodayEarnings = _todayEarnings;

      await _handleAutoSessionsIfNeeded(reference: DateTime.now());
      updatedTodayEarnings = _todayEarnings;

      // Handle clock-in sessions with real-time earnings
      if (_isClockInActive && _clockInStartTime != null) {
        final workDuration = DateTime.now().difference(_clockInStartTime!);

        // Calculate real-time earnings during session (like Growth menu)
        if (_currentInvestment > 0) {
          final sessionEarnings = _sessionEarningsValue();
          final secondsInSession = workDuration.inSeconds;
          final secondsInFullSession = _clockInDurationMinutes * 60;
          final progressRatio =
              (secondsInSession / secondsInFullSession).clamp(0.0, 1.0);

          // Calculate current session's partial earnings
          final currentSessionEarnings = sessionEarnings * progressRatio;

          // Add to today's earnings (this creates the "money going up" effect)
          final completedSessions =
              _completedClockIns.where((completed) => completed).length;
          final baseEarnings = completedSessions * sessionEarnings;
          updatedTodayEarnings = baseEarnings + currentSessionEarnings;

          // Save real-time earnings to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final username =
              prefs.getString('family_tree_user_name') ?? 'NGMY User';
          await prefs.setDouble(
              '${username}_family_tree_today_earnings', updatedTodayEarnings);

          // Accumulate bandwidth: ~10 GB per minute (continuously filling, never full)
          final sessionBandwidth =
              (workDuration.inMinutes * 10.0); // This session's bandwidth in GB
          final newTotalBandwidth = _sessionStartBandwidth + sessionBandwidth;

          if (newTotalBandwidth != _bandwidth) {
            _bandwidth = newTotalBandwidth;
            // Save updated bandwidth to SharedPreferences
            await prefs.setDouble(
                '${username}_family_tree_today_bandwidth', _bandwidth);
          }
        }
      }

      setState(() {
        // Update time until midnight
        _checkMidnightAvailability();

        // Check for missed sessions
        _checkForMissedSessions();

        // Check claim cooldown
        if (_isClaimOnCooldown && _lastClaimTime != null) {
          final cooldownEnd = _lastClaimTime!
              .add(const Duration(seconds: 15)); // 15 seconds cooldown
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

        // Update work duration and earnings in setState
        if (_isClockInActive && _clockInStartTime != null) {
          _workDuration = DateTime.now().difference(_clockInStartTime!);
          _todayEarnings = updatedTodayEarnings;

          // Check if the session has completed (at or past the configured duration)
          final sessionDurationSeconds = _clockInDurationMinutes * 60;
          if (_workDuration.inSeconds >= sessionDurationSeconds &&
              _isClockInActive) {
            // Stop timer immediately once the full duration elapses
            _isClockInActive = false; // Stop counting immediately
            _workDuration = Duration(
                seconds: sessionDurationSeconds); // Cap at configured duration
            // Complete session
            Future.microtask(() => _completeClockInSession());
          }
        }
      });
    });
  }

  Future<void> _handleClockIn() async {
    if (!_ensureAccountActive('Clock-in')) {
      return;
    }
    final activation = _investmentActivatedAt;
    final now = DateTime.now();
    if (activation != null && now.isBefore(activation)) {
      if (mounted) {
        final unlockLabel = MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(activation),
          alwaysUse24HourFormat: false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clock-in unlocks after $unlockLabel.'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    // Manual claim happens during active session; unclaimed money auto-deposits at completion

    // Check if admin has set working days restriction
    final adminWorkingDays = _adminWorkingDays.isNotEmpty
        ? _adminWorkingDays
        : _resolveAdminWorkingDays(prefs);
    if (!_isWorkingDay(now, adminWorkingDays)) {
      final todayName = _familyTreeWeekdayNames[now.weekday - 1];
      final allowedLabel =
          adminWorkingDays.isEmpty ? 'All days' : adminWorkingDays.join(', ');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Clock-in not available on $todayName. Working days: $allowedLabel'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    // Check if user has an approved investment
    if (_currentInvestment <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Please join an investment plan first to start earning!'),
          backgroundColor: Colors.orange.shade700,
          action: SnackBarAction(
            label: 'Join Now',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FamilyTreeInvestmentScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    // Find which clock-in session is available
    final clockInIndex = _findCurrentClockInIndex();
    if (clockInIndex == -1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No clock-in session available at this time.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    // Check if this session is already completed
    if (_completedClockIns[clockInIndex]) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session ${clockInIndex + 1} already completed today!'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    await _startSession(
      index: clockInIndex,
      startTime: now,
      prefsOverride: prefs,
      autoTriggered: false,
      showFeedback: true,
      sessionStartBandwidthOverride: _bandwidth,
      referenceTime: now,
    );
  }

  Future<void> _claimEarnings() async {
    if (!_ensureAccountActive('Claim request')) {
      return;
    }
    if (!_isClockInActive) {
      return;
    }

    if (_isClaimOnCooldown) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please wait ${_claimCooldownRemaining.inSeconds} seconds before claiming again'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Get current username
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';

    // Calculate only NEW earnings since last claim
    final newEarningsSinceLastClaim = _claimableEarnings();

    // If nothing NEW to claim, show message and return
    if (newEarningsSinceLastClaim <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'All earnings already in balance!\nBalance: ₦₲${_totalBalance.toStringAsFixed(2)}'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Get balance before this claim
    final balanceBefore = _storedFamilyTreeBalance(prefs, username);
    final newBalance =
        balanceBefore + newEarningsSinceLastClaim; // Add only NEW earnings

    // Track total lifetime earnings (separate from balance) - Family Tree specific
    final currentTotalEarnings =
        prefs.getDouble('${username}_family_tree_total_earnings') ?? 0.0;
    final newTotalEarnings = currentTotalEarnings + newEarningsSinceLastClaim;
    await prefs.setDouble(
        '${username}_family_tree_total_earnings', newTotalEarnings);

    // Update last claimed amount to current total earnings - tracks what user manually claimed
    final updatedLastClaim = _todayEarnings;
    await prefs.setDouble(
        '${username}_family_tree_last_claimed_amount', updatedLastClaim);

    // Save to Family Tree balance keys ONLY - NOT connected to Growth
    await prefs.setDouble('family_tree_total_balance', newBalance);

    // ALSO save to user-specific Family Tree keys (permanent record)
    await prefs.setDouble('${username}_family_tree_balance', newBalance);

    // Log this claim in Family Tree work session history - NOT connected to Growth
    final workHistory =
        prefs.getStringList('${username}_family_tree_work_session_history') ??
            [];
    final sessionRecord = jsonEncode({
      'date': DateTime.now().toIso8601String(),
      'balanceBefore': balanceBefore,
      'balanceAfter': newBalance,
      'earnings': newEarningsSinceLastClaim,
      'sessionType': 'family_tree_manual_claim',
    });
    workHistory.insert(0, sessionRecord);

    // Keep only last 30 records
    if (workHistory.length > _historyRetentionLimit) {
      workHistory.removeRange(_historyRetentionLimit, workHistory.length);
    }
    await prefs.setStringList(
        '${username}_family_tree_work_session_history', workHistory);

    await _markAllCompletedSessionsCredited(prefs, username);

    // Start cooldown
    final now = DateTime.now();

    // Save cooldown time to SharedPreferences - Family Tree specific
    await prefs.setString(
        '${username}_family_tree_last_claim_time', now.toIso8601String());

    // DO NOT clear session state - allow user to continue working during claim
    // Session will only end when the configured duration is up

    setState(() {
      _totalBalance = newBalance;
      _lastClaimedAmount = updatedLastClaim; // Track what was claimed
      _isClaimOnCooldown = true;
      _lastClaimTime = now;
      _claimCooldownRemaining =
          const Duration(seconds: 15); // 15 seconds cooldown
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'MANUAL CLAIM: ₦₲${newEarningsSinceLastClaim.toStringAsFixed(2)} added to balance!\n'
              'New Balance: ₦₲${newBalance.toStringAsFixed(2)}\n'
              'Today\'s Earnings: ₦₲${_todayEarnings.toStringAsFixed(2)}\n'
              'Cooldown: 15 seconds'),
          backgroundColor: Colors.green.shade700,
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
            physics:
                const NeverScrollableScrollPhysics(), // Disable swipe, only tab navigation
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
              // Refresh balance when changing pages
              _refreshBalance();
            },
            children: [
              _buildHomePage(),
              const FamilyTreeInvestmentScreen(),
              _buildFamilyTreeWalletPage(),
              _buildFamilyTreeStatsPage(),
              _buildFamilyTreeProfilePage(),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1B2A), // Dark blue-black at top
            const Color(0xFF1B263B), // Deeper blue-gray middle
            const Color(0xFF0D1B2A), // Back to dark blue-black
            const Color(0xFF415A77)
                .withAlpha((0.6 * 255).round()), // Lighter blue-gray bottom
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Animated background particles
          ...List.generate(
            15,
            (index) => AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = (index * 0.1 + _pulseController.value) % 1.0;
                return Positioned(
                  left: (index * 47.0) % MediaQuery.of(context).size.width,
                  top: (offset * MediaQuery.of(context).size.height),
                  child: Container(
                    width: 4 + (index % 3) * 2,
                    height: 4 + (index % 3) * 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20,
                        120), // Extra top padding for floating header and bottom padding for floating nav
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B263B).withAlpha((0.95 * 255).round()),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.4 * 255).round()),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF415A77).withAlpha((0.15 * 255).round()),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Family Tree Income',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 52,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: NotificationBell(
                          badgeColor: const Color(0xFF64B5F6),
                          tooltip: 'Family Tree notifications',
                          allowCompose: false,
                          scopes: const ['global', 'family_tree'],
                        ),
                      ),
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
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Today',
            _formatCurrency(_todayEarnings),
            Icons.trending_up,
            Colors.green.shade400,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Balance',
            _formatCurrency(_totalBalance),
            Icons.account_balance_wallet,
            Colors.blue.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockInCard() {
    final hasInvestment = _currentInvestment > 0;
    var availableSessionIndex = _findCurrentClockInIndex();
    if (!hasInvestment) {
      availableSessionIndex = -1;
    }
    final sessionClaimable = _claimableEarnings();
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
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 260 + (_pulseController.value * 20),
                    height: 260 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_isClockInActive ? Colors.green : Colors.grey)
                            .withAlpha(
                                (0.2 * 255 * (1 - _pulseController.value))
                                    .round()),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isClockInActive
                        ? [Colors.green.shade400, Colors.green.shade700]
                        : [Colors.grey.shade700, Colors.grey.shade900],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isClockInActive ? Colors.green : Colors.grey)
                          .withAlpha((0.5 * 255).round()),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isClockInActive)
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
                                  color: Colors.white
                                      .withAlpha((0.3 * 255).round()),
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
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isClockInActive
                              ? Icons.access_time
                              : Icons.power_settings_new,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isClockInActive
                              ? _formatDuration(_workDuration)
                              : '00:00:00',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _sessionStatusLabel(context),
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
          if (_isClockInActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(
                    'Session', '₦₲${sessionClaimable.toStringAsFixed(2)}'),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                ),
                _buildMiniStat(
                    'Data', '${(_bandwidth / 1000).toStringAsFixed(2)} TB'),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                ),
                _buildMiniStat('Days', '$_activeDays'),
              ],
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final claimableAmount = sessionClaimable;
                final bool hasAmountToClaim = claimableAmount > 0;
                return SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (_isClaimOnCooldown || _isAccountLocked)
                        ? null
                        : _claimEarnings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isClaimOnCooldown
                          ? Colors.grey.shade600
                          : hasAmountToClaim
                              ? Colors.orange.shade600
                              : Colors.orange.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _isClaimOnCooldown
                          ? 0
                          : hasAmountToClaim
                              ? 8
                              : 4,
                    ),
                    icon: Icon(
                      _isClaimOnCooldown
                          ? Icons.schedule
                          : Icons.account_balance_wallet,
                      size: 20,
                    ),
                    label: _isClaimOnCooldown
                        ? Text(
                            'Claim Cooldown ${_claimCooldownRemaining.inSeconds}s',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          )
                        : Text(
                            'Claim Earnings ₦₲${claimableAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                Text(
                  'All Sessions Complete In:',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.5 * 255).round()),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(_timeUntilAllSessionsComplete),
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Daily Sessions',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final indicatorCount = math.max(
                        _completedClockIns.length,
                        _adminClockInTimes.length,
                      );
                      final displayCount =
                          indicatorCount == 0 ? 1 : indicatorCount;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(displayCount, (index) {
                          final isCompleted = hasInvestment &&
                              index < _completedClockIns.length &&
                              _completedClockIns[index];
                          final isActive = hasInvestment &&
                              _currentClockInIndex == index &&
                              _isClockInActive;
                          final isMissed = hasInvestment &&
                              index < _missedClockIns.length &&
                              _missedClockIns[index];
                          final hasSessionTime =
                              index < _adminClockInTimes.length;
                          final sessionTime = hasSessionTime
                              ? _adminClockInTimes[index]
                              : const TimeOfDay(hour: 0, minute: 0);

                          return Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? Colors.green.shade600
                                      : isActive
                                          ? Colors.orange.shade600
                                          : isMissed
                                              ? Colors.red.shade600
                                              : Colors.grey.shade700,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white
                                        .withAlpha((0.3 * 255).round()),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 20)
                                      : isActive
                                          ? const Icon(Icons.play_arrow,
                                              color: Colors.white, size: 20)
                                          : isMissed
                                              ? const Icon(Icons.close,
                                                  color: Colors.white, size: 20)
                                              : Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasSessionTime
                                    ? sessionTime.format(context)
                                    : '--:--',
                                style: TextStyle(
                                  color: Colors.white
                                      .withAlpha((0.7 * 255).round()),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          (availableSessionIndex != -1 && !_isAccountLocked)
                              ? _handleClockIn
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade500,
                        disabledBackgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        availableSessionIndex != -1
                            ? 'Start Session ${availableSessionIndex + 1}'
                            : 'No Session Available',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
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

  Widget _buildAccountStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.18 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((0.6 * 255).round())),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  String _formatSuspensionDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Widget _buildBandwidthCard() {
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
              Icon(Icons.wifi, color: Colors.green.shade400, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Data Shared',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(_bandwidth / 1000).toStringAsFixed(2)} TB',
                style: TextStyle(
                  color: Colors.green.shade400,
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
              value: _bandwidth / _maxBandwidth,
              minHeight: 8,
              backgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
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
                'Limit: 100 TB',
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
            color: const Color(0xFF1B263B).withAlpha((0.95 * 255).round()),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.4 * 255).round()),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF415A77).withAlpha((0.15 * 255).round()),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                        Icons.home_rounded, 'Home', _currentPageIndex == 0, () {
                      _pageController.jumpToPage(0);
                    }),
                    _buildNavItem(Icons.trending_up_rounded, 'Join',
                        _currentPageIndex == 1, () {
                      _pageController.jumpToPage(1);
                    }),
                    _buildNavItem(Icons.account_balance_wallet_rounded,
                        'Wallet', _currentPageIndex == 2, () {
                      _pageController.jumpToPage(2);
                    }),
                    _buildNavItem(Icons.bar_chart_rounded, 'Stats',
                        _currentPageIndex == 3, () {
                      _pageController.jumpToPage(3);
                    }),
                    _buildNavItem(
                        Icons.person_rounded, 'Profile', _currentPageIndex == 4,
                        () {
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

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive
                ? Colors.green.shade400
                : Colors.white.withAlpha((0.5 * 255).round()),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive
                  ? Colors.green.shade400
                  : Colors.white.withAlpha((0.5 * 255).round()),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // Family Tree Wallet - EXACT copy of Growth design with Family Tree data
  Widget _buildFamilyTreeWalletPage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1B2A), // Dark blue-black at top
            const Color(0xFF1B263B), // Deeper blue-gray middle
            const Color(0xFF0D1B2A), // Back to dark blue-black
            const Color(0xFF415A77)
                .withAlpha((0.6 * 255).round()), // Lighter blue-gray bottom
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildFamilyTreeWalletHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFamilyTreeBalanceCard(),
                    const SizedBox(height: 24),
                    _buildFamilyTreeQuickActions(),
                    const SizedBox(height: 24),
                    _buildFamilyTreeTransactionHistory(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTreeWalletHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Spacer(),
          const Text(
            'Family Tree Wallet',
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

  Widget _buildFamilyTreeBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B).withAlpha((0.85 * 255).round()),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha((0.18 * 255).round()),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2A).withAlpha((0.6 * 255).round()),
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
                  color: Colors.white.withAlpha((0.2 * 255).round()),
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
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Family Tree',
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
          const Text(
            'Total Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_totalBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Today: ${_formatCurrency(_todayEarnings)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreeQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildFamilyTreeActionButton(
              'Deposit',
              Icons.add_circle_outline,
              Colors.green,
              () {
                if (!_ensureAccountActive('Deposits')) {
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FamilyTreeInvestmentScreen(),
                  ),
                ).then((_) => _refreshBalance());
              },
              enabled: !_isAccountLocked,
              disabledMessage: _isAccountLocked ? _accountLockReason() : null,
            ),
            const SizedBox(width: 12),
            _buildFamilyTreeActionButton(
              'Withdraw',
              Icons.remove_circle_outline,
              Colors.orange,
              () {
                _showWithdrawDialog();
              },
              buttonKey: const ValueKey('family_tree_action_withdraw'),
              enabled: !_isWithdrawProhibited,
              disabledMessage:
                  _isWithdrawProhibited ? _withdrawBlockReason() : null,
              disabledSnackColor:
                  _isAccountBanned ? Colors.redAccent : Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFamilyTreeActionButton(
              'History',
              Icons.history,
              Colors.blue,
              () {
                _showTransactionHistory();
              },
            ),
            const SizedBox(width: 12),
            _buildFamilyTreeActionButton(
              'Transfer',
              Icons.swap_horiz,
              Colors.lightBlueAccent,
              () {
                _showFamilyTreeTransferDialog();
              },
              enabled: !_isAccountLocked && _totalBalance > 0.0,
              disabledMessage: _isAccountLocked
                  ? _accountLockReason()
                  : 'No funds available to transfer.',
              disabledSnackColor:
                  _isAccountLocked ? Colors.redAccent : Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFamilyTreeActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    Key? buttonKey,
    bool enabled = true,
    String? disabledMessage,
    Color? disabledSnackColor,
  }) {
    return Expanded(
      child: GestureDetector(
        key: buttonKey,
        onTap: () {
          if (!enabled) {
            if (!mounted) {
              return;
            }
            final message = disabledMessage ?? 'Action unavailable.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: disabledSnackColor ?? Colors.orange,
              ),
            );
            return;
          }
          onTap();
        },
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withAlpha((0.3 * 255).round()),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFamilyTreeTransferDialog() async {
    if (!_ensureAccountActive('Transfers')) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    final balanceLabel = _formatCurrency(_totalBalance);

    final result = await showDialog<_FamilyTransferResult>(
      context: context,
      builder: (dialogContext) => _FamilyTransferDialog(
        currentBalance: _totalBalance,
        balanceLabel: balanceLabel,
        messenger: messenger,
      ),
    );

    if (result == null) {
      return;
    }

    await _processFamilyTreeTransfer(result.destination, result.amount);
  }

  Future<void> _processFamilyTreeTransfer(
    TransferDestination destination,
    double amount,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    final senderUserId = await _ensureFamilyTreeUserId(
          prefsOverride: prefs,
          usernameOverride: username,
        ) ??
        'family_tree_user';

    final currentBalance = _storedFamilyTreeBalance(prefs, username);
    final newBalance =
        (currentBalance - amount).clamp(0.0, double.infinity).toDouble();

    await prefs.setDouble('family_tree_total_balance', newBalance);
    await prefs.setDouble('${username}_family_tree_balance', newBalance);

    final transfersList = prefs.getStringList('transfers') ?? <String>[];
    final transferTimestamp = DateTime.now();
    final transferRecord = {
      'id': transferTimestamp.millisecondsSinceEpoch.toString(),
      'scope': 'family_tree',
      'senderUserID': senderUserId,
      'senderUsername': username,
      'recipientUserID': destination == TransferDestination.store
          ? 'ngmy_store_wallet'
          : 'money_betting_wallet',
      'destination': destination.name,
      'amount': amount,
      'timestamp': transferTimestamp.toIso8601String(),
      'status': 'completed',
    };
    transfersList.add(json.encode(transferRecord));
    await prefs.setStringList('transfers', transfersList);

    await _appendFamilyTreeWalletReceipt(
      prefs,
      description: destination == TransferDestination.store
          ? 'Transfer to NGMY Store wallet'
          : 'Transfer to Money & Betting wallet',
      amount: -amount,
      type: 'transfer_out',
      timestamp: transferTimestamp,
    );

    if (mounted) {
      setState(() {
        _totalBalance = newBalance;
      });
    }

    await WalletTransferService.credit(
      destination: destination,
      amount: amount,
      sourceLabel: 'Family Tree Wallet',
    );

    if (!mounted) {
      return;
    }

    final label = WalletTransferService.labelFor(destination);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transferred ₦₲${amount.toStringAsFixed(2)} to $label'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildFamilyTreeTransactionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildFamilyTreeTransactionItem(
                'Session Earnings',
                _formatCurrency(_currentInvestment * 0.00666),
                Icons.trending_up,
                Colors.green,
                'Today',
              ),
              _buildFamilyTreeDivider(),
              _buildFamilyTreeTransactionItem(
                'Investment',
                _formatCurrency(_currentInvestment),
                Icons.account_balance,
                Colors.blue,
                'Active',
              ),
              _buildFamilyTreeDivider(),
              _buildFamilyTreeTransactionItem(
                'Family Tree Bonus',
                _formatCurrency(0),
                Icons.card_giftcard,
                Colors.purple,
                'Pending',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyTreeTransactionItem(
      String title, String amount, IconData icon, Color color, String date) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreeDivider() {
    return Container(
      height: 1,
      color: Colors.white.withAlpha((0.1 * 255).round()),
    );
  }

  // Family Tree Stats - EXACT copy of Growth design with Family Tree data
  Widget _buildFamilyTreeStatsPage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1B2A), // Dark blue-black at top
            const Color(0xFF1B263B), // Deeper blue-gray middle
            const Color(0xFF0D1B2A), // Back to dark blue-black
            const Color(0xFF415A77)
                .withAlpha((0.6 * 255).round()), // Lighter blue-gray bottom
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildFamilyTreeStatsHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFamilyTreeOverviewCards(),
                    const SizedBox(height: 24),
                    _buildFamilyTreeEarningsChart(),
                    const SizedBox(height: 24),
                    _buildFamilyTreeStatsGrid(),
                    const SizedBox(height: 24),
                    _buildFamilyTreeMilestones(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTreeStatsHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Spacer(),
          const Text(
            'Family Tree Stats',
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

  Widget _buildFamilyTreeOverviewCards() {
    final completedSessions =
        _completedClockIns.where((completed) => completed).length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade600,
                  Colors.blue.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withAlpha((0.3 * 255).round()),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.trending_up, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                Text(
                  '₦₲${_todayEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Today\'s Earnings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade600,
                  Colors.green.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withAlpha((0.3 * 255).round()),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.access_time, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                Text(
                  '$completedSessions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Sessions Done',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyTreeEarningsChart() {
    final hasInvestment = _currentInvestment > 0;
    final history = List<_DailyEarning>.from(_earningsHistory);
    final startBoundary = _investmentStartDate != null
        ? _normalizeDate(_investmentStartDate!)
        : null;

    if (startBoundary != null) {
      history.removeWhere(
        (entry) => _normalizeDate(entry.date).isBefore(startBoundary),
      );
    }

    if (hasInvestment) {
      final today = _normalizeDate(DateTime.now());
      final todayAmount = _sanitizeEarningAmount(_todayEarnings);
      final existingIndex = history.indexWhere(
        (entry) => _isSameDay(_normalizeDate(entry.date), today),
      );
      if (existingIndex != -1) {
        history[existingIndex] =
            _DailyEarning(date: today, amount: todayAmount);
      } else {
        history.add(_DailyEarning(date: today, amount: todayAmount));
      }
    }

    history.sort((a, b) => a.date.compareTo(b.date));
    final recentHistory = history.length > 7
        ? history.sublist(history.length - 7)
        : List<_DailyEarning>.from(history);

    final slots = List<_DailyEarning?>.filled(7, null);
    for (var i = 0; i < recentHistory.length; i++) {
      slots[slots.length - recentHistory.length + i] = recentHistory[i];
    }

    final maxAmount = recentHistory.isEmpty
        ? 0.0
        : recentHistory
            .map((entry) => entry.amount)
            .fold<double>(0.0, (previous, value) => math.max(previous, value));
    final safeMax = maxAmount <= 0 ? 1.0 : maxAmount;
    final allEmpty = slots.every((entry) => entry == null);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          if (!hasInvestment)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'Purchase a plan to start tracking Family Tree earnings.',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.6 * 255).round()),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Container(
              height: 152,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: allEmpty
                  ? Center(
                      child: Text(
                        'No earnings recorded yet. Complete a session to populate your chart.',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.6 * 255).round()),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: slots.map((entry) {
                        final amount = entry?.amount ?? 0.0;
                        final label =
                            entry != null ? _chartDayLabel(entry.date) : '--';
                        final isZero = amount <= 0.0001;
                        final ratio = (amount / safeMax).clamp(0.0, 1.0);
                        const maxBarHeight = 92.0;
                        final barHeight =
                            isZero ? 4.0 : math.max(8.0, ratio * maxBarHeight);
                        final gradientColors = isZero
                            ? [Colors.white24, Colors.white12]
                            : [Colors.green.shade600, Colors.green.shade300];
                        final displayAmount = entry != null
                            ? _formatCurrency(
                                amount,
                                decimals: amount >= 1000 ? 0 : 1,
                              )
                            : '';
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (displayAmount.isNotEmpty)
                                  SizedBox(
                                    height: 16,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        displayAmount,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 16),
                                const SizedBox(height: 4),
                                Container(
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: gradientColors,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreeStatsGrid() {
    final completedSessions =
        _completedClockIns.where((completed) => completed).length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildFamilyTreeStatGridCard(
          'Investment',
          '₦₲${_currentInvestment.toStringAsFixed(0)}',
          Icons.account_balance,
          Colors.purple,
        ),
        _buildFamilyTreeStatGridCard(
          'Active Days',
          '$_activeDays',
          Icons.calendar_today,
          Colors.orange,
        ),
        _buildFamilyTreeStatGridCard(
          'Success Rate',
          '${completedSessions > 0 ? ((completedSessions / _completedClockIns.length) * 100).toStringAsFixed(1) : '0.0'}%',
          Icons.analytics,
          Colors.red,
        ),
        _buildFamilyTreeStatGridCard(
          'Total Sessions',
          '${_completedClockIns.length}',
          Icons.timer,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildFamilyTreeStatGridCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreeMilestones() {
    final completedSessions =
        _completedClockIns.where((completed) => completed).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Family Tree Milestones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildFamilyTreeMilestoneItem(
            'First Session',
            completedSessions >= 1,
            'Complete your first $_clockInDurationMinutes-minute session',
          ),
          _buildFamilyTreeMilestoneItem(
            '5 Sessions',
            completedSessions >= 5,
            'Complete all daily sessions',
          ),
          _buildFamilyTreeMilestoneItem(
            'Investment Active',
            _currentInvestment > 0,
            'Have an approved investment',
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreeMilestoneItem(
      String title, bool completed, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed ? Colors.green : Colors.white24,
            ),
            child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: completed ? Colors.white : Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Independent Family Tree Profile - NOT connected to Growth
  // Family Tree Profile - EXACT copy of Growth design with Family Tree data
  Widget _buildFamilyTreeProfilePage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1B2A), // Dark blue-black at top
            const Color(0xFF1B263B), // Deeper blue-gray middle
            const Color(0xFF0D1B2A), // Back to dark blue-black
            const Color(0xFF415A77)
                .withAlpha((0.6 * 255).round()), // Lighter blue-gray bottom
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildFamilyTreeProfileHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildFamilyTreeProfileCard(),
                    const SizedBox(height: 24),
                    _buildFamilyTreeAchievements(),
                    const SizedBox(height: 24),
                    _buildFamilyTreePreferences(),
                    const SizedBox(height: 24),
                    _buildFamilyTreeActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTreeProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Spacer(),
          const Text(
            'Family Tree Profile',
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

  Widget _buildFamilyTreeProfileCard() {
    final completedSessions =
        _completedClockIns.where((completed) => completed).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A5F),
            const Color(0xFF2A4F85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withAlpha((0.35 * 255).round()),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Picture with Upload functionality
          GestureDetector(
            onTap: _pickProfileImage,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha((0.2 * 255).round()),
                border: Border.all(
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                  width: 2,
                ),
              ),
              child: _profileImagePath != null
                  ? ClipOval(
                      child: _buildProfileImageWidget(),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.account_tree,
                          color: Colors.white,
                          size: 40,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D9BF0),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: 'Tap to change username',
            child: GestureDetector(
              onTap: _promptEditFamilyTreeUsername,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _familyTreeUserName.isEmpty
                        ? 'Family Tree Member'
                        : _familyTreeUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_familyTreeUserId != null && _familyTreeUserId!.isNotEmpty) ...[
            Tooltip(
              message: 'Tap to copy user ID',
              child: GestureDetector(
                onTap: _copyFamilyTreeUserId,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.25 * 255).round()),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'User ID: ${_familyTreeUserId!}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_familyTreePhoneNumber.isNotEmpty) ...[
            Tooltip(
              message: 'Tap to copy phone number',
              child: GestureDetector(
                onTap: _copyFamilyTreePhoneNumber,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.25 * 255).round()),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Phone: $_familyTreePhoneNumber',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_isAccountLocked) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_isAccountBanned)
                  _buildAccountStatusChip('Account Banned', Colors.redAccent),
                if (_isAccountDisabled)
                  _buildAccountStatusChip(
                      'Account Disabled', Colors.orangeAccent),
                if (_isAccountSuspended && _accountSuspendedUntil != null)
                  _buildAccountStatusChip(
                    'Suspended until ${_formatSuspensionDate(_accountSuspendedUntil!)}',
                    Colors.amber,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Active for $_activeDays days',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$completedSessions',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Sessions',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withAlpha((0.3 * 255).round()),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatCurrency(_todayEarnings, decimals: 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Earned',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withAlpha((0.3 * 255).round()),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatCurrency(_currentInvestment, decimals: 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Invested',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageWidget() {
    final path = _profileImagePath;
    if (path == null || path.isEmpty) {
      return const Icon(
        Icons.account_tree,
        color: Colors.white,
        size: 40,
      );
    }

    if (_profileImageIsLocalFile && !kIsWeb) {
      return Image.file(
        io.File(path),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.account_tree,
            color: Colors.white,
            size: 40,
          );
        },
      );
    }

    return Image.network(
      path,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.account_tree,
          color: Colors.white,
          size: 40,
        );
      },
    );
  }

  Widget _buildFamilyTreeAchievements() {
    final completedSessions =
        _completedClockIns.where((completed) => completed).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Family Tree Achievements',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAchievementDetails(
                      'Clock In Master',
                      completedSessions >= 5,
                      'Complete 5 session to unlock this achievement',
                      completedSessions,
                      5),
                  child: _buildFamilyTreeAchievementBadge(
                    'Clock In Master',
                    completedSessions >= 5,
                    Colors.amber,
                    Icons.access_time,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAchievementDetails(
                      'Investor',
                      _currentInvestment > 0,
                      'Make your first investment to unlock this achievement',
                      _currentInvestment > 0 ? 1 : 0,
                      1),
                  child: _buildFamilyTreeAchievementBadge(
                    'Investor',
                    _currentInvestment > 0,
                    Colors.blue,
                    Icons.trending_up,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAchievementDetails(
                      'Active Member',
                      _activeDays >= 7,
                      'Be active for 7 days to unlock this achievement',
                      _activeDays,
                      7),
                  child: _buildFamilyTreeAchievementBadge(
                    'Active Member',
                    _activeDays >= 7,
                    Colors.purple,
                    Icons.star,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreeAchievementBadge(
      String title, bool achieved, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: achieved
            ? color.withAlpha((0.2 * 255).round())
            : Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achieved
              ? color.withAlpha((0.5 * 255).round())
              : Colors.white.withAlpha((0.1 * 255).round()),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: achieved ? color : Colors.white30,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: achieved ? color : Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreePreferences() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Family Tree Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildPenaltyNotificationCard(),
          const SizedBox(height: 24),
          _buildFamilyTreePreferenceItem(
            'Session Reminders',
            'Get notified when each clock-in window opens.',
            Icons.notifications_active,
            true,
            (value) => _showFeatureComingSoon(
                'Session reminder preferences are coming soon.'),
          ),
          _buildFamilyTreePreferenceItem(
            'Daily Summary',
            'Receive a nightly recap of earnings and penalties.',
            Icons.summarize_rounded,
            true,
            (value) => _showFeatureComingSoon(
                'Daily summaries will arrive in a future update.'),
          ),
          _buildFamilyTreePreferenceItem(
            'Auto Session Complete',
            'Automatically complete your sessions. Activation costs 20% of your active investment.',
            Icons.bolt_rounded,
            _autoSessionEnabled,
            (value) {
              if (!_ensureAccountActive('Auto Session Complete settings')) {
                return;
              }
              if (_autoSessionEnabled && !value) {
                _showAutoSessionDisableGuard();
                return;
              }
              unawaited(_handleAutoSessionToggle(value));
            },
            trailingInfo: _autoSessionEnabled
                ? 'Contributed ${_formatCurrency(_autoSessionPaidTotal)} of ${_formatCurrency(_autoSessionRequiredTotal)} (10% per withdrawal)'
                : 'Needs ${_formatCurrency(_currentInvestment * 0.2)} funded at 10% per withdrawal',
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreePreferenceItem(
    String title,
    String subtitle,
    IconData icon,
    bool enabled,
    ValueChanged<bool>? onChanged, {
    String? trailingInfo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                if (trailingInfo != null && trailingInfo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    trailingInfo,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTreeActions() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            border:
                Border.all(color: Colors.white.withAlpha((0.3 * 255).round())),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ElevatedButton(
            onPressed: () {
              // Export Family Tree data
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export feature coming soon!'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Export Family Tree Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAchievementDetails(String title, bool achieved, String description,
      int current, int target) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              achieved ? Icons.check_circle : Icons.radio_button_unchecked,
              color: achieved ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: achieved
                    ? Colors.green.withAlpha((0.2 * 255).round())
                    : Colors.orange.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    achieved ? Icons.emoji_events : Icons.hourglass_empty,
                    color: achieved ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      achieved
                          ? 'Achievement Unlocked!'
                          : 'Progress: $current/$target',
                      style: TextStyle(
                        color: achieved ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  Future<void> _pickProfileImage() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> handleGallerySelection() async {
          Navigator.of(sheetContext).pop();
          try {
            final file = await _imagePicker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1024,
              imageQuality: 85,
            );
            if (file == null) {
              return;
            }
            if (!mounted) {
              return;
            }
            await _applyProfileImageChange(
              path: file.path,
              isLocal: true,
              successMessage: 'Profile picture updated!',
            );
          } catch (error) {
            if (!mounted) {
              return;
            }
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.showSnackBar(
              SnackBar(
                content: Text('Unable to select image: $error'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        Future<void> handleCameraCapture() async {
          Navigator.of(sheetContext).pop();
          try {
            final file = await _imagePicker.pickImage(
              source: ImageSource.camera,
              maxWidth: 1024,
              imageQuality: 85,
            );
            if (file == null) {
              return;
            }
            if (!mounted) {
              return;
            }
            await _applyProfileImageChange(
              path: file.path,
              isLocal: true,
              successMessage: 'Profile picture updated!',
            );
          } catch (error) {
            if (!mounted) {
              return;
            }
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.showSnackBar(
              SnackBar(
                content: Text('Unable to open camera: $error'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        Future<void> handleUrlSelection() async {
          Navigator.of(sheetContext).pop();
          if (!mounted) {
            return;
          }
          await _promptForProfileImageUrl(context);
        }

        Future<void> handleRemoval() async {
          Navigator.of(sheetContext).pop();
          if (!mounted) {
            return;
          }
          await _applyProfileImageChange(
            path: null,
            isLocal: false,
            successMessage: 'Profile picture removed',
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D4D3D), Color(0xFF062028)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined,
                        color: Colors.white),
                    title: const Text('Choose from Gallery',
                        style: TextStyle(color: Colors.white)),
                    onTap: handleGallerySelection,
                  ),
                  if (!kIsWeb)
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined,
                          color: Colors.white),
                      title: const Text('Take Photo',
                          style: TextStyle(color: Colors.white)),
                      onTap: handleCameraCapture,
                    ),
                  ListTile(
                    leading:
                        const Icon(Icons.link_outlined, color: Colors.white),
                    title: const Text('Use Image URL',
                        style: TextStyle(color: Colors.white)),
                    onTap: handleUrlSelection,
                  ),
                  if (_profileImagePath != null)
                    ListTile(
                      leading: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      title: const Text('Remove Photo',
                          style: TextStyle(color: Colors.redAccent)),
                      onTap: handleRemoval,
                    ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: const Icon(Icons.close, color: Colors.white70),
                    title: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptForProfileImageUrl(BuildContext messengerContext) async {
    final initialValue =
        !_profileImageIsLocalFile ? (_profileImagePath ?? '') : '';
    final controller = TextEditingController(text: initialValue);

    String? result;
    try {
      result = await showDialog<String>(
        context: messengerContext,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF0D4D3D),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Profile Picture URL',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste an image link to personalize your Family Tree account.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Image URL',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'https://example.com/your-photo.jpg',
                  hintStyle: const TextStyle(color: Colors.white30),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }

    if (!mounted || result == null) {
      return;
    }

    final trimmed = result.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty ||
        uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https'))) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid image URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _applyProfileImageChange(
      path: trimmed,
      isLocal: false,
      successMessage: 'Profile picture updated!',
    );
  }

  Future<void> _cancelPendingWithdrawalRequest(
      ScaffoldMessengerState? messenger) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    final requestId =
        prefs.getString('${username}_family_tree_withdraw_request_id') ??
            _pendingWithdrawalRequestId;

    if (requestId != null) {
      final withdrawalEntries =
          prefs.getStringList('family_tree_withdrawal_requests') ?? [];
      bool updated = false;
      final List<String> updatedEntries = [];

      for (final entry in withdrawalEntries) {
        try {
          final decoded = json.decode(entry) as Map<String, dynamic>;
          if (decoded['id'] == requestId && decoded['status'] == 'pending') {
            decoded['status'] = 'cancelled';
            decoded['processedAt'] = DateTime.now().toIso8601String();
            updatedEntries.add(json.encode(decoded));
            updated = true;
          } else {
            updatedEntries.add(entry);
          }
        } catch (_) {
          updatedEntries.add(entry);
        }
      }

      if (updated) {
        await prefs.setStringList(
            'family_tree_withdrawal_requests', updatedEntries);
      }
    }

    await prefs.remove('${username}_family_tree_withdraw_status');
    await prefs.remove('${username}_family_tree_withdraw_pending_amount');
    await prefs.remove('${username}_family_tree_withdraw_pending_timestamp');
    await prefs.remove('${username}_family_tree_withdraw_request_id');
    await prefs.remove('${username}_family_tree_withdraw_pending_contribution');
    await prefs.remove('${username}_family_tree_withdraw_pending_standard_fee');
    await prefs.remove('${username}_family_tree_withdraw_pending_net_amount');
    await prefs
        .remove('${username}_family_tree_withdraw_pending_balance_after');
    await prefs
        .remove('${username}_family_tree_withdraw_pending_outstanding_after');

    if (mounted) {
      setState(() {
        _hasPendingWithdrawal = false;
        _pendingWithdrawalAmount = 0.0;
        _pendingWithdrawalContribution = 0.0;
        _pendingWithdrawalStandardFee = 0.0;
        _pendingWithdrawalNetAmount = 0.0;
        _pendingWithdrawalBalanceAfter = 0.0;
        _pendingWithdrawalOutstandingAfter = 0.0;
        _pendingWithdrawalStatus = null;
        _pendingWithdrawalRequestedAt = null;
        _pendingWithdrawalRequestId = null;
      });
    }

    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Pending withdrawal cancelled'),
          backgroundColor: Colors.blueGrey.shade600,
        ),
      );
    } else if (mounted) {
      final fallback = ScaffoldMessenger.maybeOf(context);
      fallback?.showSnackBar(
        SnackBar(
          content: const Text('Pending withdrawal cancelled'),
          backgroundColor: Colors.blueGrey.shade600,
        ),
      );
    }
  }

  Future<void> _submitWithdrawalRequest(
      double amount, String cashTag, ScaffoldMessengerState? messenger) async {
    void showSnack(SnackBar snackBar) {
      if (messenger != null) {
        messenger.showSnackBar(snackBar);
      } else if (mounted) {
        final fallback = ScaffoldMessenger.maybeOf(context);
        fallback?.showSnackBar(snackBar);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    final normalizedCashTag = cashTag.trim();
    if (normalizedCashTag.isEmpty || normalizedCashTag == r'$') {
      showSnack(
        SnackBar(
          content: const Text('Please enter your Cash App tag'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!normalizedCashTag.startsWith(r'$')) {
      showSnack(
        SnackBar(
          content: const Text('Cash App tag must start with \$'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await CashTagStorage.save(normalizedCashTag,
        scope: 'family_tree', identifier: username);
    final currentBalance = _storedFamilyTreeBalance(prefs, username);

    amount = amount.abs();

    if (amount <= 0 || amount > currentBalance) {
      showSnack(
        SnackBar(
          content: Text(
            amount <= 0
                ? 'Enter a valid amount greater than zero'
                : 'Amount exceeds available balance (₦₲${currentBalance.toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final timestamp = DateTime.now();
    final requestId =
        'family_tree_${timestamp.millisecondsSinceEpoch}_${_familyTreeUserId ?? username.replaceAll(' ', '').toLowerCase()}';

    final outstandingBefore = _autoSessionOutstanding;
    double contribution = 0.0;
    double standardFee = 0.0;

    if (_autoSessionEnabled) {
      contribution = math.min(
        outstandingBefore,
        math.max(0.0, amount * _autoSessionFeeRate),
      );
    } else {
      standardFee = math.max(0.0, amount * _standardWithdrawalFeeRate);
    }

    final totalFee = contribution + standardFee;
    final netAmount = (amount - totalFee).clamp(0.0, amount);
    final balanceAfter = (currentBalance - amount).clamp(0.0, double.infinity);
    final outstandingAfter = math.max(0.0, outstandingBefore - contribution);

    await prefs.setString('${username}_family_tree_withdraw_status', 'pending');
    await prefs.setDouble(
        '${username}_family_tree_withdraw_pending_amount', amount);
    await prefs.setInt('${username}_family_tree_withdraw_pending_timestamp',
        timestamp.millisecondsSinceEpoch);
    await prefs.setString(
        '${username}_family_tree_withdraw_request_id', requestId);
    await prefs.setDouble(
        '${username}_family_tree_withdraw_pending_contribution', contribution);
    await prefs.setDouble(
        '${username}_family_tree_withdraw_pending_standard_fee', standardFee);
    await prefs.setDouble(
        '${username}_family_tree_withdraw_pending_net_amount', netAmount);
    await prefs.setDouble(
        '${username}_family_tree_withdraw_pending_balance_after', balanceAfter);
    await prefs.setDouble(
        '${username}_family_tree_withdraw_pending_outstanding_after',
        outstandingAfter);

    final withdrawalEntries =
        prefs.getStringList('family_tree_withdrawal_requests') ?? <String>[];
    final withdrawalRecord = <String, dynamic>{
      'id': requestId,
      'username': username,
      'userId': _familyTreeUserId,
      'amount': amount,
      'status': 'pending',
      'submittedAt': timestamp.toIso8601String(),
      'system': 'family_tree',
      'cashTag': normalizedCashTag,
      'notes': 'Family Tree wallet withdrawal request',
      'balanceBefore': currentBalance,
      'balanceAfter': balanceAfter,
      'contribution': contribution,
      'standardFee': standardFee,
      'totalFee': totalFee,
      'netAmount': netAmount,
      'autoSessionApplied': contribution > 0,
      'outstandingBefore': outstandingBefore,
      'outstandingAfter': outstandingAfter,
      'feeRate': _autoSessionEnabled
          ? _autoSessionFeeRate
          : _standardWithdrawalFeeRate,
      'requiredTotal': _autoSessionRequiredTotal,
      'paidTotalAtRequest': _autoSessionPaidTotal,
    };
    withdrawalEntries.add(json.encode(withdrawalRecord));
    await prefs.setStringList(
        'family_tree_withdrawal_requests', withdrawalEntries);

    if (mounted) {
      setState(() {
        _totalBalance = currentBalance;
        _hasPendingWithdrawal = true;
        _pendingWithdrawalAmount = amount;
        _pendingWithdrawalContribution = contribution;
        _pendingWithdrawalStandardFee = standardFee;
        _pendingWithdrawalNetAmount = netAmount;
        _pendingWithdrawalBalanceAfter = balanceAfter;
        _pendingWithdrawalOutstandingAfter = outstandingAfter;
        _pendingWithdrawalStatus = 'pending';
        _pendingWithdrawalRequestedAt = timestamp;
        _pendingWithdrawalRequestId = requestId;
      });
    }

    showSnack(
      SnackBar(
        content: Text(
            'Withdrawal request submitted for ₦₲${amount.toStringAsFixed(2)}'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _showWithdrawDialog() async {
    if (!_ensureWithdrawAllowed()) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final withdrawController = TextEditingController();

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('family_tree_user_name') ?? 'NGMY User';
    final savedCashTag =
        await CashTagStorage.load(scope: 'family_tree', identifier: username);
    final cashTagController = TextEditingController(
      text: savedCashTag ?? r'$',
    );
    final liveBalance = _storedFamilyTreeBalance(prefs, username);

    if (mounted) {
      setState(() {
        _totalBalance = liveBalance;
      });
    }

    String? pendingSummary() {
      if (!_hasPendingWithdrawal) {
        return null;
      }
      final status = (_pendingWithdrawalStatus ?? 'pending').toUpperCase();
      final timestamp = _pendingWithdrawalRequestedAt != null
          ? _formatPenaltyTimestamp(_pendingWithdrawalRequestedAt!)
          : null;
      final amountText = '₦₲${_pendingWithdrawalAmount.toStringAsFixed(2)}';
      final buffer = StringBuffer('$status • $amountText');
      final hasAutoFee = _pendingWithdrawalContribution > 0;
      final hasStandardFee = _pendingWithdrawalStandardFee > 0;
      if (hasAutoFee) {
        buffer.write(
            '\nAuto Session fee (10%): ${_formatCurrency(_pendingWithdrawalContribution)}');
      }
      if (hasStandardFee) {
        buffer.write(
            '\nWithdrawal fee (6%): ${_formatCurrency(_pendingWithdrawalStandardFee)}');
      }
      if (hasAutoFee || hasStandardFee) {
        buffer.write(
            '\nNet after fees: ${_formatCurrency(_pendingWithdrawalNetAmount)}');
      }
      if (hasAutoFee) {
        buffer.write(
            '\nCoverage remaining: ${_formatCurrency(_pendingWithdrawalOutstandingAfter)}');
      }
      if (_pendingWithdrawalBalanceAfter > 0) {
        buffer.write(
            '\nBalance after approval: ${_formatCurrency(_pendingWithdrawalBalanceAfter)}');
      }
      if (timestamp != null) {
        buffer.write('\nRequested $timestamp');
      }
      return buffer.toString();
    }

    ({bool cancelPending, double? amount, String? cashTag})? result;

    double previewAmount = 0.0;
    double previewContribution = 0.0;
    double previewStandardFee = 0.0;
    double previewNet = 0.0;
    double previewBalanceAfter = liveBalance;
    double previewOutstandingAfter = _autoSessionOutstanding;
    bool previewHasInput = false;
    bool previewExceeds = false;
    bool previewShowsCoverage =
        _autoSessionEnabled && _autoSessionOutstanding > 0;

    try {
      if (!mounted) {
        return;
      }

      result = await showModalBottomSheet<
          ({bool cancelPending, double? amount, String? cashTag})>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (innerContext, setSheetState) {
              final canWithdraw = liveBalance > 0 && !_hasPendingWithdrawal;
              final summary = pendingSummary();
              final bottomInset = MediaQuery.of(innerContext).viewInsets.bottom;

              return SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                      bottom: bottomInset > 0 ? bottomInset : 24),
                  child: SingleChildScrollView(
                    physics: bottomInset > 0
                        ? const BouncingScrollPhysics()
                        : const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF142336), Color(0xFF0B1A27)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 30,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 44,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: Colors.orangeAccent,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Withdraw',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Available: ₦₲${liveBalance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (summary != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          Colors.teal.withValues(alpha: 0.35)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pending Request',
                                      style: TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      summary,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (canWithdraw) ...[
                              TextField(
                                controller: withdrawController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (value) {
                                  setSheetState(() {
                                    final trimmed = value.trim();
                                    final parsed = double.tryParse(trimmed);
                                    previewHasInput = trimmed.isNotEmpty;

                                    if (parsed == null || parsed <= 0) {
                                      previewAmount = 0.0;
                                      previewContribution = 0.0;
                                      previewStandardFee = 0.0;
                                      previewNet = 0.0;
                                      previewBalanceAfter = liveBalance;
                                      previewOutstandingAfter =
                                          _autoSessionOutstanding;
                                      previewExceeds = false;
                                      previewShowsCoverage =
                                          _autoSessionEnabled &&
                                              _autoSessionOutstanding > 0;
                                      return;
                                    }

                                    final amount = parsed;
                                    previewAmount = amount;
                                    previewExceeds = amount > liveBalance;

                                    final outstanding = _autoSessionOutstanding;
                                    double contribution = 0.0;
                                    double standardFee = 0.0;

                                    if (_autoSessionEnabled) {
                                      contribution = math.min(
                                        outstanding,
                                        math.max(
                                          0.0,
                                          amount * _autoSessionFeeRate,
                                        ),
                                      );
                                    } else {
                                      standardFee = math.max(
                                        0.0,
                                        amount * _standardWithdrawalFeeRate,
                                      );
                                    }

                                    final totalFee = contribution + standardFee;

                                    previewContribution = contribution;
                                    previewStandardFee = standardFee;
                                    previewNet =
                                        math.max(0.0, amount - totalFee);
                                    previewBalanceAfter = (liveBalance - amount)
                                        .clamp(0.0, liveBalance);
                                    previewOutstandingAfter = math.max(
                                      0.0,
                                      outstanding - contribution,
                                    );
                                    previewShowsCoverage = contribution > 0.0;
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Withdrawal amount',
                                  labelStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7)),
                                  prefixText: '₦₲ ',
                                  prefixStyle:
                                      const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.05),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: Colors.orangeAccent, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: cashTagController,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Cash App tag',
                                  hintText: r'$YourCashTag',
                                  hintStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.4)),
                                  labelStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7)),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.05),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: Colors.orangeAccent, width: 1.5),
                                  ),
                                ),
                              ),
                              if (previewHasInput) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Withdrawal summary',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Requested: ${_formatCurrency(previewAmount)}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (previewContribution > 0)
                                        Text(
                                          'Auto Session fee (10%): ${_formatCurrency(previewContribution)}',
                                          style: const TextStyle(
                                            color: Colors.tealAccent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      if (previewStandardFee > 0)
                                        Text(
                                          'Withdrawal fee (6%): ${_formatCurrency(previewStandardFee)}',
                                          style: const TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      Text(
                                        'Net payout: ${_formatCurrency(previewNet)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Balance after withdrawal: ${_formatCurrency(previewBalanceAfter)}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (previewShowsCoverage)
                                        Text(
                                          'Coverage remaining: ${_formatCurrency(previewOutstandingAfter)}',
                                          style: const TextStyle(
                                            color: Colors.tealAccent,
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (previewExceeds)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Amount exceeds your available balance.',
                                            style: TextStyle(
                                              color: Colors.orangeAccent
                                                  .withValues(alpha: 0.9),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.orange
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  !_hasPendingWithdrawal
                                      ? 'No funds available to withdraw yet.'
                                      : 'You already have a withdrawal pending. Cancel it to create a new one.',
                                  style: const TextStyle(
                                      color: Colors.orangeAccent, fontSize: 13),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(innerContext).pop();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                      ),
                                      foregroundColor: Colors.white70,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('Close'),
                                  ),
                                ),
                                if (_hasPendingWithdrawal) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(innerContext).pop((
                                          cancelPending: true,
                                          amount: null,
                                          cashTag: null,
                                        ));
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orangeAccent,
                                        side: BorderSide(
                                          color: Colors.orangeAccent
                                              .withValues(alpha: 0.5),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text('Cancel Pending'),
                                    ),
                                  ),
                                ] else if (canWithdraw) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final amountText =
                                            withdrawController.text.trim();
                                        final amount =
                                            double.tryParse(amountText);
                                        final cashTagValue =
                                            cashTagController.text.trim();

                                        if (amount == null || amount <= 0) {
                                          messenger?.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Enter a valid amount greater than zero'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        if (amount > liveBalance) {
                                          messenger?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Amount exceeds available balance (₦₲${liveBalance.toStringAsFixed(2)})',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        if (cashTagValue.isEmpty ||
                                            cashTagValue == r'$') {
                                          messenger?.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Please enter your Cash App tag'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        if (!cashTagValue.startsWith(r'$')) {
                                          messenger?.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Cash App tag must start with \$'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        Navigator.of(innerContext).pop((
                                          cancelPending: false,
                                          amount: amount,
                                          cashTag: cashTagValue,
                                        ));
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orangeAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text('Withdraw'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      withdrawController.dispose();
      cashTagController.dispose();
    }

    if (!mounted || result == null) {
      return;
    }

    if (result.cancelPending) {
      await _cancelPendingWithdrawalRequest(messenger);
      return;
    }

    final amount = result.amount;
    if (amount != null) {
      await _submitWithdrawalRequest(amount, result.cashTag ?? '', messenger);
    }
  }

  void _showTransactionHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D4D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Transaction History',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              _buildHistoryItem(
                  'Session Completed',
                  '₦₲${(_currentInvestment * 0.00666).toStringAsFixed(2)}',
                  'Today',
                  Colors.green),
              _buildHistoryItem(
                  'Investment Deposit',
                  '₦₲${_currentInvestment.toStringAsFixed(2)}',
                  'Active',
                  Colors.blue),
              _buildHistoryItem(
                  'Daily Earnings',
                  '₦₲${_todayEarnings.toStringAsFixed(2)}',
                  'Today',
                  Colors.green),
              _buildHistoryItem(
                  'Bandwidth Sharing', '₦₲0.00', 'Today', Colors.purple),
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

  Widget _buildHistoryItem(
      String title, String amount, String date, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.monetization_on, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text(date,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Text(amount,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _FamilyTransferDestinationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final TransferDestination destination;
  final TransferDestination selected;
  final VoidCallback onSelected;

  const _FamilyTransferDestinationTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destination,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = destination == selected;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? Colors.white.withAlpha((0.08 * 255).round())
              : Colors.white.withAlpha((0.04 * 255).round()),
          border: Border.all(
            color: isSelected ? Colors.lightBlueAccent : Colors.white24,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.lightBlueAccent.withAlpha((0.25 * 255).round())
                    : Colors.black.withAlpha((0.35 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.65 * 255).round()),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.lightBlueAccent : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyTransferResult {
  final TransferDestination destination;
  final double amount;

  const _FamilyTransferResult({
    required this.destination,
    required this.amount,
  });
}

class _FamilyTransferDialog extends StatefulWidget {
  final double currentBalance;
  final String balanceLabel;
  final ScaffoldMessengerState? messenger;

  const _FamilyTransferDialog({
    required this.currentBalance,
    required this.balanceLabel,
    this.messenger,
  });

  @override
  State<_FamilyTransferDialog> createState() => _FamilyTransferDialogState();
}

class _FamilyTransferDialogState extends State<_FamilyTransferDialog> {
  late final TextEditingController _amountController;
  TransferDestination _selected = TransferDestination.store;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectDestination(TransferDestination destination) {
    if (_selected == destination) {
      return;
    }
    setState(() {
      _selected = destination;
    });
  }

  void _submit() {
    final parsed = double.tryParse(_amountController.text.trim());
    if (parsed == null || parsed <= 0) {
      _showError('Enter an amount greater than zero');
      return;
    }

    if (parsed > widget.currentBalance) {
      _showError('Insufficient balance (available ${widget.balanceLabel})');
      return;
    }

    Navigator.of(context).pop(
      _FamilyTransferResult(destination: _selected, amount: parsed),
    );
  }

  void _showError(String message) {
    setState(() {
      _errorText = message;
    });
    widget.messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D4D3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.wallet, color: Colors.lightBlueAccent),
          SizedBox(width: 12),
          Text('Transfer Funds', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.18 * 255).round()),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select destination',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FamilyTransferDestinationTile(
                    title: 'NGMY Store wallet',
                    subtitle:
                        'Move funds into your store balance for spins and item wins.',
                    icon: Icons.store_mall_directory,
                    destination: TransferDestination.store,
                    selected: _selected,
                    onSelected: () =>
                        _selectDestination(TransferDestination.store),
                  ),
                  const SizedBox(height: 10),
                  _FamilyTransferDestinationTile(
                    title: 'Money & Betting wallet',
                    subtitle:
                        'Credit your betting balance for games and payouts.',
                    icon: Icons.casino,
                    destination: TransferDestination.betting,
                    selected: _selected,
                    onSelected: () =>
                        _selectDestination(TransferDestination.betting),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Amount',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                ),
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
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Available balance: ${widget.balanceLabel}',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          style:
              ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Transfer'),
        ),
      ],
    );
  }
}
