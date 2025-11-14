import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/store_models.dart';
// Store wallet is now self-contained; not using the shared betting wallet here.

class StoreDataStore extends ChangeNotifier {
  StoreDataStore._internal() {
    _loadFromStorage();
  }
  static final StoreDataStore instance = StoreDataStore._internal();

  // Wheel configuration
  final List<PrizeSegment> _segments = [
    PrizeSegment(
      id: 's1',
      label: '+100',
      type: PrizeType.money,
      moneyAmount: 100,
      color: const Color(0xFF26A69A),
      weight: 1,
      betAmount: 0,
    ),
    PrizeSegment(
      id: 's2',
      label: 'Try Again',
      type: PrizeType.item,
      itemName: 'Try Again',
      color: const Color(0xFFEF5350),
      weight: 1.2,
      betAmount: 0,
      isTryAgain: true,
      tryAgainMessage: 'Try again!',
      tryAgainPenalty: 35.0,
    ),
    PrizeSegment(
      id: 's3',
      label: '+20',
      type: PrizeType.money,
      moneyAmount: 20,
      color: const Color(0xFF7C9EFF),
      weight: 1.5,
      betAmount: 0,
    ),
    PrizeSegment(
      id: 's4',
      label: 'NGMY Cap',
      type: PrizeType.item,
      itemName: 'NGMY Cap',
      color: const Color(0xFFFFD54F),
      weight: 0.8,
      betAmount: 10.0,
    ),
    PrizeSegment(
      id: 's5',
      label: '+5',
      type: PrizeType.money,
      moneyAmount: 5,
      color: const Color(0xFF8E24AA),
      weight: 2,
      betAmount: 0,
    ),
    PrizeSegment(
      id: 's6',
      label: 'NGMY Shirt',
      type: PrizeType.item,
      itemName: 'NGMY Shirt',
      color: const Color(0xFFFF6D00),
      weight: 0.6,
      betAmount: 15.0,
    ),
  ];

  // Totals
  double _totalMoneyWon = 0;
  double _storeWalletBalance = 0;
  final Map<String, int> _itemCounts = {};
  final List<ItemWin> _pendingItemWins = [];
  final Map<String, _SegmentWinWindow> _segmentWinWindows = {};

  // Spin history tracking
  final List<SpinHistory> _spinHistory = [];

  // Transaction requests
  final List<DepositRequest> _depositRequests = [];
  final List<WithdrawRequest> _withdrawRequests = [];
  final List<ShipmentRequest> _shipmentRequests = [];

  // Bet amounts for dropdown
  List<double> _betAmounts = [10, 15, 20, 30, 50, 100];

  // Accessors
  List<PrizeSegment> get segments => List.unmodifiable(_segments);
  double get totalMoneyWon => _totalMoneyWon;
  double get storeWalletBalance => _storeWalletBalance;
  Map<String, int> get itemCounts => Map.unmodifiable(_itemCounts);
  List<ItemWin> get pendingItemWins => List.unmodifiable(_pendingItemWins);
  List<SpinHistory> get spinHistory => List.unmodifiable(_spinHistory);

  List<DepositRequest> get depositRequests =>
      List.unmodifiable(_depositRequests);
  List<WithdrawRequest> get withdrawRequests =>
      List.unmodifiable(_withdrawRequests);
  List<ShipmentRequest> get shipmentRequests =>
      List.unmodifiable(_shipmentRequests);

  List<double> get betAmounts => List.unmodifiable(_betAmounts);

  // Store wallet controls (admin can manage)
  void setStoreWalletBalance(double value) {
    _storeWalletBalance = value.clamp(0, double.infinity);
    notifyListeners();
    _saveToStorage();
  }

  void adjustStoreWalletBalance(double delta) {
    _storeWalletBalance =
        (_storeWalletBalance + delta).clamp(0, double.infinity);
    notifyListeners();
    _saveToStorage();
  }

  // Admin mutators
  void addSegment(PrizeSegment segment) {
    _segments.add(segment);
    notifyListeners();
    _saveToStorage();
  }

  void updateSegment(String id, PrizeSegment updated) {
    final i = _segments.indexWhere((s) => s.id == id);
    if (i == -1) return;
    _segments[i] = updated;
    _syncLimitWindow(updated);
    notifyListeners();
    _saveToStorage();
  }

  void removeSegment(String id) {
    _segments.removeWhere((s) => s.id == id);
    _segmentWinWindows.remove(id);
    notifyListeners();
    _saveToStorage();
  }

  void reorderSegments(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final s = _segments.removeAt(oldIndex);
    _segments.insert(newIndex, s);
    notifyListeners();
    _saveToStorage();
  }

  // Bet amount management
  void setBetAmounts(List<double> amounts) {
    _betAmounts = [...amounts];
    notifyListeners();
    _saveToStorage();
  }

  void addBetAmount(double amount) {
    if (!_betAmounts.contains(amount)) {
      _betAmounts.add(amount);
      _betAmounts.sort();
      notifyListeners();
      _saveToStorage();
    }
  }

  void removeBetAmount(double amount) {
    _betAmounts.remove(amount);
    notifyListeners();
    _saveToStorage();
  }

  bool consumePrizeAllowance(PrizeSegment segment, DateTime now) {
    final limitCount = segment.winLimitCount;
    final limitPeriod = segment.winLimitPeriod;
    if (limitCount == null || limitCount <= 0 || limitPeriod == null) {
      return true;
    }

    final tracker = _segmentWinWindows[segment.id];
    if (tracker == null ||
        !_isWithinPeriod(tracker.periodStart, now, limitPeriod)) {
      _segmentWinWindows[segment.id] = _SegmentWinWindow(
        count: 1,
        periodStart: _normalizedPeriodAnchor(now, limitPeriod),
        period: limitPeriod,
      );
      _saveToStorage();
      return true;
    }

    if (tracker.count >= limitCount) {
      return false;
    }

    tracker
      ..count += 1
      ..period = limitPeriod;
    _saveToStorage();
    return true;
  }

  int? remainingPrizeAllowance(PrizeSegment segment, DateTime now) {
    final limitCount = segment.winLimitCount;
    final limitPeriod = segment.winLimitPeriod;
    if (limitCount == null || limitCount <= 0 || limitPeriod == null) {
      return null;
    }

    final tracker = _segmentWinWindows[segment.id];
    if (tracker == null ||
        !_isWithinPeriod(tracker.periodStart, now, limitPeriod)) {
      return limitCount;
    }

    final int allowed = limitCount;
    final remaining = (allowed - tracker.count).toInt();
    return remaining <= 0 ? 0 : remaining;
  }

  bool isPrizeAvailable(PrizeSegment segment, DateTime now) {
    return _segmentHasAllowance(segment, now);
  }

  DateTime? nextResetFor(PrizeSegment segment) {
    final limitCount = segment.winLimitCount;
    final limitPeriod = segment.winLimitPeriod;
    if (limitCount == null || limitCount <= 0 || limitPeriod == null) {
      return null;
    }

    final tracker = _segmentWinWindows[segment.id];
    if (tracker == null) {
      return null;
    }

    switch (limitPeriod) {
      case PrizeLimitPeriod.week:
        return tracker.periodStart.add(const Duration(days: 7));
      case PrizeLimitPeriod.month:
        final start = tracker.periodStart;
        if (start.month == 12) {
          return DateTime(start.year + 1, 1, 1);
        }
        return DateTime(start.year, start.month + 1, 1);
    }
  }

  DateTime _normalizedPeriodAnchor(
      DateTime reference, PrizeLimitPeriod period) {
    final dayStart = DateTime(reference.year, reference.month, reference.day);
    if (period == PrizeLimitPeriod.week) {
      final weekdayOffset = dayStart.weekday - DateTime.monday;
      return dayStart.subtract(Duration(days: weekdayOffset));
    }
    return DateTime(reference.year, reference.month, 1);
  }

  bool _isWithinPeriod(
    DateTime start,
    DateTime reference,
    PrizeLimitPeriod period,
  ) {
    if (period == PrizeLimitPeriod.week) {
      final windowEnd = start.add(const Duration(days: 7));
      return !reference.isBefore(start) && reference.isBefore(windowEnd);
    }
    final nextMonth = start.month == 12
        ? DateTime(start.year + 1, 1, 1)
        : DateTime(start.year, start.month + 1, 1);
    return !reference.isBefore(start) && reference.isBefore(nextMonth);
  }

  bool _segmentHasAllowance(PrizeSegment segment, DateTime now) {
    final limitCount = segment.winLimitCount;
    final limitPeriod = segment.winLimitPeriod;
    if (limitCount == null || limitCount <= 0 || limitPeriod == null) {
      return true;
    }

    final tracker = _segmentWinWindows[segment.id];
    if (tracker == null ||
        !_isWithinPeriod(tracker.periodStart, now, limitPeriod)) {
      return true;
    }

    return tracker.count < limitCount;
  }

  void _syncLimitWindow(PrizeSegment segment) {
    final limitCount = segment.winLimitCount;
    final limitPeriod = segment.winLimitPeriod;
    if (limitCount == null || limitCount <= 0 || limitPeriod == null) {
      _segmentWinWindows.remove(segment.id);
      return;
    }

    final tracker = _segmentWinWindows[segment.id];
    if (tracker == null) {
      return;
    }

    tracker.period = limitPeriod;
    final now = DateTime.now();
    if (!_isWithinPeriod(tracker.periodStart, now, limitPeriod)) {
      tracker
        ..periodStart = _normalizedPeriodAnchor(now, limitPeriod)
        ..count = 0;
    }
    if (tracker.count > limitCount) {
      tracker.count = limitCount;
    }
  }

  void resetTotals() {
    _totalMoneyWon = 0;
    _itemCounts.clear();
    _pendingItemWins.clear();
    _segmentWinWindows.clear();
    notifyListeners();
    _saveToStorage();
  }

  // Weight helpers for admin bias controls
  void setSegmentWeight(String id, double weight) {
    final i = _segments.indexWhere((s) => s.id == id);
    if (i == -1) return;
    _segments[i].weight = weight.clamp(0, 100);
    notifyListeners();
    _saveToStorage();
  }

  void normalizeWeightsTo100() {
    final sum =
        _segments.fold<double>(0, (a, b) => a + (b.weight <= 0 ? 0 : b.weight));
    if (sum <= 0) return;
    for (final s in _segments) {
      if (s.weight > 0) {
        s.weight = (s.weight / sum) * 100;
      }
    }
    notifyListeners();
    _saveToStorage();
  }

  void makeDominant(String id, {double dominant = 95, double others = 1}) {
    for (final s in _segments) {
      s.weight = s.id == id ? dominant : others;
    }
    notifyListeners();
    _saveToStorage();
  }

  // Pick a segment using weighted random but DO NOT apply outcome yet.
  // Weight system: 0 = never win (disabled), 1-33 = rare, 34-66 = uncommon, 67-100 = very likely
  PrizeSegment? pickWeightedSegment({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final activeSegments = _segments.where((segment) {
      if (segment.weight <= 0) {
        return false;
      }
      return _segmentHasAllowance(segment, now);
    }).toList();

    if (activeSegments.isEmpty) {
      return null;
    }

    final totalWeight =
        activeSegments.fold<double>(0, (sum, segment) => sum + segment.weight);
    if (totalWeight <= 0) {
      return activeSegments.last;
    }

    double r = Random().nextDouble() * totalWeight;

    for (final segment in activeSegments) {
      if (r < segment.weight) {
        return segment;
      }
      r -= segment.weight;
    }
    return activeSegments.last;
  }

  // Apply the outcome once the wheel has visually landed at the pointer.
  void applyOutcome(PrizeSegment s,
      {double betAmount = 0, String username = 'Guest'}) {
    final now = DateTime.now();

    // If the segment is "Try Again", apply penalty
    if (s.isTryAgain ||
        (s.itemName != null &&
            s.itemName!.toLowerCase().contains('try again'))) {
      // Deduct penalty percentage from wallet
      final penalty = _storeWalletBalance * (s.tryAgainPenalty / 100);
      _storeWalletBalance =
          (_storeWalletBalance - penalty).clamp(0, double.infinity);

      // Record spin history as a loss
      _spinHistory.add(SpinHistory(
        id: 'spin_${now.millisecondsSinceEpoch}',
        username: username,
        segmentLabel: s.label,
        isWin: false,
        moneyAmount: -penalty, // Negative for loss
        betAmount: betAmount,
        timestamp: now,
      ));

      notifyListeners();
      _saveToStorage();
      return;
    }

    final limitAllowed = consumePrizeAllowance(s, now);
    if (!limitAllowed) {
      _storeWalletBalance =
          (_storeWalletBalance + betAmount).clamp(0, double.infinity);
      _spinHistory.add(SpinHistory(
        id: 'spin_${now.millisecondsSinceEpoch}_limited',
        username: username,
        segmentLabel: '${s.label} (limit reached)',
        isWin: false,
        moneyAmount: 0,
        betAmount: betAmount,
        timestamp: now,
      ));
      notifyListeners();
      _saveToStorage();
      return;
    }

    if (s.type == PrizeType.money) {
      _totalMoneyWon += s.moneyAmount;
      // Credit the self-contained store wallet only
      _storeWalletBalance += s.moneyAmount;

      // Record spin history as a win
      _spinHistory.add(SpinHistory(
        id: 'spin_${now.millisecondsSinceEpoch}',
        username: username,
        segmentLabel: s.label,
        isWin: true,
        moneyAmount: s.moneyAmount,
        betAmount: betAmount,
        timestamp: now,
      ));
    } else if (s.type == PrizeType.item && s.itemName != null) {
      _itemCounts.update(s.itemName!, (v) => v + 1, ifAbsent: () => 1);
      _pendingItemWins.add(ItemWin(
        id: 'win_${now.millisecondsSinceEpoch}',
        itemName: s.itemName!,
        userId: 'current',
        timestamp: now,
      ));

      // Record spin history as a win (item)
      _spinHistory.add(SpinHistory(
        id: 'spin_${now.millisecondsSinceEpoch}_item',
        username: username,
        segmentLabel: s.label,
        isWin: true,
        moneyAmount: 0, // Items don't have money value in spin
        betAmount: betAmount,
        timestamp: now,
        itemName: s.itemName,
      ));
    }
    notifyListeners();
    _saveToStorage();
  }

  // Deduct bet amount from wallet before spinning
  bool placeBet(double amount) {
    if (_storeWalletBalance < amount) return false;
    _storeWalletBalance -= amount;
    notifyListeners();
    _saveToStorage();
    return true;
  }

  // Check if user can spin (minimum balance requirements)
  bool canSpin({double requiredAmount = 5.0}) {
    return _storeWalletBalance >= requiredAmount;
  }

  // Get all segments that can be targeted for betting
  List<PrizeSegment> get bettableSegments {
    return _segments.where((s) => s.betAmount > 0 && !s.isTryAgain).toList();
  }

  void markItemFulfilled(String id) {
    final i = _pendingItemWins.indexWhere((w) => w.id == id);
    if (i == -1) return;
    _pendingItemWins[i].fulfilled = true;
    notifyListeners();
    _saveToStorage();
  }

  /// Add an item win directly (for custom betting logic)
  void addCustomItemWin(String itemName) {
    final now = DateTime.now();
    _itemCounts.update(itemName, (v) => v + 1, ifAbsent: () => 1);
    _pendingItemWins.add(ItemWin(
      id: 'win_${now.millisecondsSinceEpoch}',
      itemName: itemName,
      userId: 'current',
      timestamp: now,
    ));
    notifyListeners();
    _saveToStorage();
  }

  // Deposit management
  void submitDepositRequest(double amount, String screenshotPath) {
    _depositRequests.add(DepositRequest(
      id: 'dep_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'current',
      amount: amount,
      screenshotPath: screenshotPath,
      timestamp: DateTime.now(),
    ));
    _cleanupExpiredRequests(); // Remove expired requests
    notifyListeners();
    _saveToStorage();
  }

  void updateDepositStatus(String id, RequestStatus status) {
    final i = _depositRequests.indexWhere((r) => r.id == id);
    if (i == -1) return;
    _depositRequests[i].status = status;
    if (status == RequestStatus.approved) {
      _storeWalletBalance += _depositRequests[i].amount;
    }
    notifyListeners();
    _saveToStorage();
  }

  void addDepositComment(String id, String comment) {
    final i = _depositRequests.indexWhere((r) => r.id == id);
    if (i == -1) return;
    _depositRequests[i].adminComment = comment;
    notifyListeners();
    _saveToStorage();
  }

  // Auto-delete expired requests (older than 3 days)
  void _cleanupExpiredRequests() {
    _depositRequests.removeWhere((r) => r.isExpired);
    _withdrawRequests.removeWhere((r) => r.isExpired);
    _shipmentRequests.removeWhere((r) => r.isExpired);
  }

  // Manual cleanup trigger for admin or periodic cleanup
  void cleanupExpiredRequests() {
    _cleanupExpiredRequests();
    notifyListeners();
    _saveToStorage();
  }

  // Withdraw management
  void submitWithdrawRequest(double amount, String cashAppTag) {
    if (amount > _storeWalletBalance) return; // insufficient balance
    _withdrawRequests.add(WithdrawRequest(
      id: 'wd_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'current',
      amount: amount,
      cashAppTag: cashAppTag,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
    _saveToStorage();
  }

  void updateWithdrawStatus(String id, RequestStatus status) {
    final i = _withdrawRequests.indexWhere((r) => r.id == id);
    if (i == -1) return;
    _withdrawRequests[i].status = status;
    if (status == RequestStatus.approved) {
      _storeWalletBalance -= _withdrawRequests[i].amount;
    }
    notifyListeners();
    _saveToStorage();
  }

  // Shipment management
  void submitShipmentRequest({
    required String itemName,
    required String fullName,
    required String address,
    required String city,
    required String zipCode,
  }) {
    _shipmentRequests.add(ShipmentRequest(
      id: 'ship_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'current',
      itemName: itemName,
      fullName: fullName,
      address: address,
      city: city,
      zipCode: zipCode,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
    _saveToStorage();
  }

  void updateShipmentStatus(String id, RequestStatus status) {
    final i = _shipmentRequests.indexWhere((r) => r.id == id);
    if (i == -1) return;
    _shipmentRequests[i].status = status;
    notifyListeners();
    _saveToStorage();
  }

  // ========== PERSISTENCE LAYER ==========

  /// Load all store data from SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load wallet balance
      _storeWalletBalance = prefs.getDouble('store_wallet_balance') ?? 0.0;
      _totalMoneyWon = prefs.getDouble('store_total_money_won') ?? 0.0;

      // Load segments
      final segmentsJson = prefs.getString('store_segments');
      if (segmentsJson != null) {
        final List<dynamic> decoded = jsonDecode(segmentsJson);
        _segments.clear();
        _segments.addAll(
            decoded.map((json) => PrizeSegment.fromJson(json)).toList());
      }

      // Load item counts
      final itemCountsJson = prefs.getString('store_item_counts');
      if (itemCountsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(itemCountsJson);
        _itemCounts.clear();
        _itemCounts
            .addAll(decoded.map((key, value) => MapEntry(key, value as int)));
      }

      // Load pending item wins
      final itemWinsJson = prefs.getString('store_pending_item_wins');
      if (itemWinsJson != null) {
        final List<dynamic> decoded = jsonDecode(itemWinsJson);
        _pendingItemWins.clear();
        _pendingItemWins
            .addAll(decoded.map((json) => ItemWin.fromJson(json)).toList());
      }

      // Load bet amounts
      final betAmountsJson = prefs.getString('store_bet_amounts');
      if (betAmountsJson != null) {
        final List<dynamic> decoded = jsonDecode(betAmountsJson);
        _betAmounts = decoded.map((e) => (e as num).toDouble()).toList();
      }

      // Load spin history
      final spinHistoryJson = prefs.getString('store_spin_history');
      if (spinHistoryJson != null) {
        final List<dynamic> decoded = jsonDecode(spinHistoryJson);
        _spinHistory.clear();
        _spinHistory
            .addAll(decoded.map((json) => SpinHistory.fromJson(json)).toList());
      }

      // Load deposit requests
      final depositRequestsJson = prefs.getString('store_deposit_requests');
      if (depositRequestsJson != null) {
        final List<dynamic> decoded = jsonDecode(depositRequestsJson);
        _depositRequests.clear();
        _depositRequests.addAll(
            decoded.map((json) => DepositRequest.fromJson(json)).toList());
      }

      // Load withdraw requests
      final withdrawRequestsJson = prefs.getString('store_withdraw_requests');
      if (withdrawRequestsJson != null) {
        final List<dynamic> decoded = jsonDecode(withdrawRequestsJson);
        _withdrawRequests.clear();
        _withdrawRequests.addAll(
            decoded.map((json) => WithdrawRequest.fromJson(json)).toList());
      }

      // Load shipment requests
      final shipmentRequestsJson = prefs.getString('store_shipment_requests');
      if (shipmentRequestsJson != null) {
        final List<dynamic> decoded = jsonDecode(shipmentRequestsJson);
        _shipmentRequests.clear();
        _shipmentRequests.addAll(
            decoded.map((json) => ShipmentRequest.fromJson(json)).toList());
      }

      final winWindowsJson = prefs.getString('store_segment_limit_windows') ??
          prefs.getString('store_money_limit_windows');
      if (winWindowsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(winWindowsJson);
        _segmentWinWindows.clear();
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _segmentWinWindows[key] =
                _SegmentWinWindow.fromJson(Map<String, dynamic>.from(value));
          }
        });
      }

      final segmentIds = _segments.map((e) => e.id).toSet();
      _segmentWinWindows.removeWhere((key, _) => !segmentIds.contains(key));
      for (final segment in _segments) {
        _syncLimitWindow(segment);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading store data: $e');
    }
  }

  /// Save all store data to SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save wallet balance
      await prefs.setDouble('store_wallet_balance', _storeWalletBalance);
      await prefs.setDouble('store_total_money_won', _totalMoneyWon);

      // Save segments
      await prefs.setString('store_segments',
          jsonEncode(_segments.map((s) => s.toJson()).toList()));

      // Save bet amounts
      await prefs.setString('store_bet_amounts', jsonEncode(_betAmounts));

      // Save item counts
      await prefs.setString('store_item_counts', jsonEncode(_itemCounts));

      // Save pending item wins
      await prefs.setString('store_pending_item_wins',
          jsonEncode(_pendingItemWins.map((w) => w.toJson()).toList()));

      // Save spin history
      await prefs.setString('store_spin_history',
          jsonEncode(_spinHistory.map((s) => s.toJson()).toList()));

      // Save deposit requests
      await prefs.setString('store_deposit_requests',
          jsonEncode(_depositRequests.map((r) => r.toJson()).toList()));

      // Save withdraw requests
      await prefs.setString('store_withdraw_requests',
          jsonEncode(_withdrawRequests.map((r) => r.toJson()).toList()));

      // Save shipment requests
      await prefs.setString('store_shipment_requests',
          jsonEncode(_shipmentRequests.map((r) => r.toJson()).toList()));

      await prefs.setString(
        'store_segment_limit_windows',
        jsonEncode(_segmentWinWindows.map(
          (key, value) => MapEntry(key, value.toJson()),
        )),
      );
    } catch (e) {
      debugPrint('Error saving store data: $e');
    }
  }

  /// Public method to force save (useful for admin actions)
  Future<void> forceSave() async {
    await _saveToStorage();
  }

  /// Clear all store data (admin reset function)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('store_wallet_balance');
      await prefs.remove('store_total_money_won');
      await prefs.remove('store_segments');
      await prefs.remove('store_bet_amounts');
      await prefs.remove('store_item_counts');
      await prefs.remove('store_pending_item_wins');
      await prefs.remove('store_deposit_requests');
      await prefs.remove('store_withdraw_requests');
      await prefs.remove('store_shipment_requests');
      await prefs.remove('store_money_limit_windows');
      await prefs.remove('store_segment_limit_windows');

      // Reset in-memory data
      _storeWalletBalance = 0;
      _totalMoneyWon = 0;
      _betAmounts = [10, 15, 20, 30, 50, 100]; // Reset to defaults
      _itemCounts.clear();
      _pendingItemWins.clear();
      _depositRequests.clear();
      _withdrawRequests.clear();
      _shipmentRequests.clear();
      _segmentWinWindows.clear();

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing store data: $e');
    }
  }
}

class _SegmentWinWindow {
  _SegmentWinWindow({
    required this.count,
    required this.periodStart,
    required this.period,
  });

  int count;
  DateTime periodStart;
  PrizeLimitPeriod period;

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'periodStart': periodStart.toIso8601String(),
      'period': period.name,
    };
  }

  factory _SegmentWinWindow.fromJson(Map<String, dynamic> json) {
    final periodRaw = json['period'] as String?;
    final parsedPeriod = PrizeLimitPeriod.values.firstWhere(
      (p) => p.name == periodRaw,
      orElse: () => PrizeLimitPeriod.week,
    );
    final startRaw = json['periodStart'] as String?;
    final start =
        startRaw != null ? DateTime.tryParse(startRaw)?.toLocal() : null;
    return _SegmentWinWindow(
      count: (json['count'] as num?)?.toInt() ?? 0,
      periodStart: start ?? DateTime.now(),
      period: parsedPeriod,
    );
  }
}
