import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/betting_entities.dart';
import '../models/betting_models.dart';

/// Centralised state store for the betting/money experience.
class BettingDataStore extends ChangeNotifier {
  BettingDataStore._internal();

  static final BettingDataStore instance = BettingDataStore._internal();

  bool _initialized = false;

  String _username = 'John Doe';
  String _userId = '#NGMY001';
  double _balance = 0;
  Uint8List? _profileBytes;
  Uint8List? _paymentLogoBytes; // Admin-uploaded payment logo

  final List<BettingHistoryEntry> _history = [];
  final List<GameOutcome> _results = [];
  final Map<GameType, bool> _enabledGames = {
    for (final type in GameType.values)
      type: !(kGameCatalogue[type]?.hidden ?? false),
  };
  
  // Wheel game segment configurations
  List<WheelSegmentConfig> _wheelSegments = [];
  
  // Lucky Slots configurations
  List<SlotSymbolConfig> _slotSymbols = [];
  static const double _defaultSlotJackpotSeed = 1000.0;
  static const String _slotJackpotKey = 'betting_slots_progressive_jackpot';
  static const String _slotJackpotSeedKey = 'betting_slots_progressive_seed';
  static const String _slotJackpotRateKey = 'betting_slots_progressive_rate';
  double _slotJackpotSeed = _defaultSlotJackpotSeed;
  double _slotJackpot = _defaultSlotJackpotSeed;
  double _slotJackpotContributionRate = 0.08; // 8% of stake feeds the pot
  static const String _casinoLaunchFlagKey = 'betting_games_release_casino_v2';
  static const Set<GameType> _casinoLaunchGames = {
    GameType.moneyMania,
    GameType.magicTreasure,
    GameType.lgtJackpot,
    GameType.jackpotInferno,
    GameType.megaRoulette,
  };
  
  // Prize Box configurations  
  List<PrizeBoxConfig> _prizeBoxes = [];
  
  // Color Spinner configurations
  List<ColorSegmentConfig> _colorSegments = [];

  /// Ensures the store has starter values without overriding live data.
  void initializeOnce({
    String? username,
    String? userId,
    double? initialBalance,
  }) {
    if (_initialized) return;
    
    // Only use provided values if nothing was loaded from storage
    // Check if we're still at default values
    if (_username == 'John Doe' && username != null) {
      _username = username;
    }
    if (_userId == '#NGMY001' && userId != null) {
      _userId = userId;
    }
    if (_balance == 0 && initialBalance != null) {
      _balance = initialBalance;
    }
    
    _initialized = true;
  }

  /// Load all data from SharedPreferences
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load username (mark as initialized if found)
    final savedUsername = prefs.getString('betting_username');
    if (savedUsername != null) {
      _username = savedUsername;
      _initialized = true; // Mark as initialized to prevent override
    }
    
    // Load userId
    final savedUserId = prefs.getString('betting_userId');
    if (savedUserId != null) {
      _userId = savedUserId;
    }
    
    // Load balance
    final savedBalance = prefs.getDouble('betting_balance');
    if (savedBalance != null) {
      _balance = savedBalance;
    }
    
    // Load profile picture
    final profileBase64 = prefs.getString('betting_profile_picture');
    if (profileBase64 != null && profileBase64.isNotEmpty) {
      _profileBytes = base64Decode(profileBase64);
    }
    
    // Load payment logo
    final paymentLogoBase64 = prefs.getString('betting_payment_logo');
    if (paymentLogoBase64 != null && paymentLogoBase64.isNotEmpty) {
      _paymentLogoBytes = base64Decode(paymentLogoBase64);
    }
    
    // Load transaction history and auto-delete completed/rejected older than 3 days
    final historyJson = prefs.getString('betting_history');
    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        final allHistory = decoded
            .map((json) => BettingHistoryEntry.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Filter: Keep all pending, but only completed/rejected within 3 days
        final now = DateTime.now();
        final threeDaysAgo = now.subtract(const Duration(days: 3));
        _history.clear();
        _history.addAll(
          allHistory.where((entry) {
            if (entry.status == TransactionStatus.pending) {
              return true; // Always keep pending
            }
            // For completed/rejected, only keep if within 3 days
            return entry.timestamp.isAfter(threeDaysAgo);
          }),
        );
        
        // Save the filtered list back if any were deleted
        if (_history.length < allHistory.length) {
          await _saveHistory();
        }
      } catch (e) {
        _history.clear();
      }
    }
    
    // Load game enabled states
    for (final type in GameType.values) {
      final key = 'betting_game_${type.name}';
      final defaultEnabled = !(kGameCatalogue[type]?.hidden ?? false);
      _enabledGames[type] = prefs.getBool(key) ?? defaultEnabled;
      if (kGameCatalogue[type]?.hidden ?? false) {
        _enabledGames[type] = false;
      }
    }

    final casinoFlagApplied = prefs.getBool(_casinoLaunchFlagKey) ?? false;
    if (!casinoFlagApplied) {
      for (final type in _casinoLaunchGames) {
        final item = kGameCatalogue[type];
        if (item != null && !item.hidden) {
          final key = 'betting_game_${type.name}';
          _enabledGames[type] = true;
          await prefs.setBool(key, true);
        }
      }
      await prefs.setBool(_casinoLaunchFlagKey, true);
    }
    
    // Load wheel segment configurations
    final wheelJson = prefs.getString('betting_wheel_segments');
    if (wheelJson != null && wheelJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(wheelJson);
        _wheelSegments = decoded
            .map((json) => WheelSegmentConfig.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _wheelSegments = _getDefaultWheelSegments();
      }
    } else {
      _wheelSegments = _getDefaultWheelSegments();
    }
    
    // Load Lucky Slots configurations
    final slotsJson = prefs.getString('betting_slots_configs');
    if (slotsJson != null && slotsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(slotsJson);
        _slotSymbols = decoded
            .map((json) => SlotSymbolConfig.fromJson(json as Map<String, dynamic>))
            .toList();
        _ensureProgressiveSymbolAssigned();
      } catch (e) {
        _slotSymbols = _getDefaultSlotSymbols();
      }
    } else {
      _slotSymbols = _getDefaultSlotSymbols();
    }

    // Load progressive jackpot state for Lucky Slots
    _slotJackpotSeed =
        prefs.getDouble(_slotJackpotSeedKey) ?? _defaultSlotJackpotSeed;
    _slotJackpotContributionRate =
        prefs.getDouble(_slotJackpotRateKey) ?? 0.08;
    _slotJackpotContributionRate = _slotJackpotContributionRate.clamp(0.0, 1.0);

    final storedJackpot = prefs.getDouble(_slotJackpotKey);
    if (storedJackpot != null) {
      _slotJackpot = storedJackpot;
    } else {
      _slotJackpot = _slotJackpotSeed;
    }
    if (_slotJackpot < _slotJackpotSeed) {
      _slotJackpot = _slotJackpotSeed;
    }
    
    // Load Prize Box configurations
    final prizeBoxJson = prefs.getString('betting_prizebox_configs');
    if (prizeBoxJson != null && prizeBoxJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(prizeBoxJson);
        _prizeBoxes = decoded
            .map((json) => PrizeBoxConfig.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _prizeBoxes = _getDefaultPrizeBoxes();
      }
    } else {
      _prizeBoxes = _getDefaultPrizeBoxes();
    }
    
    // Load Color Spinner configurations
    final colorSpinnerJson = prefs.getString('betting_colorspinner_configs');
    if (colorSpinnerJson != null && colorSpinnerJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(colorSpinnerJson);
        _colorSegments = decoded
            .map((json) => ColorSegmentConfig.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _colorSegments = _getDefaultColorSegments();
      }
    } else {
      _colorSegments = _getDefaultColorSegments();
    }
    
    // Load game results and auto-delete results older than 3 days
    final resultsJson = prefs.getString('betting_game_results');
    if (resultsJson != null && resultsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(resultsJson);
        final allResults = decoded
            .map((json) => GameOutcome.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Filter out results older than 3 days
        final now = DateTime.now();
        final threeDaysAgo = now.subtract(const Duration(days: 3));
        _results.clear();
        _results.addAll(
          allResults.where((result) => result.timestamp.isAfter(threeDaysAgo)),
        );
        
        // Save the filtered list back to storage if any were deleted
        if (_results.length < allResults.length) {
          await _saveGameResults();
        }
      } catch (e) {
        _results.clear();
      }
    }
    
    notifyListeners();
  }

  /// Save all data to SharedPreferences
  Future<void> saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save username
    await prefs.setString('betting_username', _username);
    
    // Save userId
    await prefs.setString('betting_userId', _userId);
    
    // Save balance
    await prefs.setDouble('betting_balance', _balance);
    
    // Save profile picture
    if (_profileBytes != null) {
      await prefs.setString('betting_profile_picture', base64Encode(_profileBytes!));
    } else {
      await prefs.remove('betting_profile_picture');
    }
    
    // Save payment logo
    if (_paymentLogoBytes != null) {
      await prefs.setString('betting_payment_logo', base64Encode(_paymentLogoBytes!));
    } else {
      await prefs.remove('betting_payment_logo');
    }
    
    // Save transaction history
    await _saveHistory();
    
    // Save game enabled states
    for (final entry in _enabledGames.entries) {
      await prefs.setBool('betting_game_${entry.key.name}', entry.value);
    }
    
    // Save wheel segment configurations
    final wheelJson = jsonEncode(_wheelSegments.map((s) => s.toJson()).toList());
    await prefs.setString('betting_wheel_segments', wheelJson);
    
    // Save Lucky Slots configurations
    final slotsJson = jsonEncode(_slotSymbols.map((s) => s.toJson()).toList());
    await prefs.setString('betting_slots_configs', slotsJson);
  await prefs.setDouble(_slotJackpotKey, _slotJackpot);
  await prefs.setDouble(_slotJackpotSeedKey, _slotJackpotSeed);
  await prefs.setDouble(_slotJackpotRateKey, _slotJackpotContributionRate);
    
    // Save Prize Box configurations
    final prizeBoxJson = jsonEncode(_prizeBoxes.map((p) => p.toJson()).toList());
    await prefs.setString('betting_prizebox_configs', prizeBoxJson);
    
    // Save Color Spinner configurations
    final colorSpinnerJson = jsonEncode(_colorSegments.map((c) => c.toJson()).toList());
    await prefs.setString('betting_colorspinner_configs', colorSpinnerJson);
    
    // Save game results
    await _saveGameResults();
  }

  /// Save game results to SharedPreferences
  Future<void> _saveGameResults() async {
    final prefs = await SharedPreferences.getInstance();
    final resultsJson = jsonEncode(_results.map((r) => r.toJson()).toList());
    await prefs.setString('betting_game_results', resultsJson);
  }

  /// Save transaction history to SharedPreferences
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode(_history.map((h) => h.toJson()).toList());
    await prefs.setString('betting_history', historyJson);
  }

  // region: basic getters -------------------------------------------------

  String get username => _username;
  String get userId => _userId;
  double get balance => _balance;
  Uint8List? get profileBytes => _profileBytes;
  Uint8List? get paymentLogoBytes => _paymentLogoBytes;
  List<BettingHistoryEntry> get history => List.unmodifiable(_history);
  List<GameOutcome> get results => List.unmodifiable(_results);
  List<WheelSegmentConfig> get wheelSegments => List.unmodifiable(_wheelSegments);
  List<SlotSymbolConfig> get slotSymbols => List.unmodifiable(_slotSymbols);
  List<PrizeBoxConfig> get prizeBoxes => List.unmodifiable(_prizeBoxes);
  List<ColorSegmentConfig> get colorSegments => List.unmodifiable(_colorSegments);

  List<GameItem> get activeGames => _enabledGames.entries
    .where((entry) => entry.value)
    .map((entry) => kGameCatalogue[entry.key])
    .whereType<GameItem>()
    .where((game) => !game.hidden)
    .toList(growable: false);

  Map<GameType, bool> get gameStatus => Map.unmodifiable(_enabledGames);

  bool isGameEnabled(GameType type) => _enabledGames[type] ?? false;

  // endregion -------------------------------------------------------------

  // region: mutators ------------------------------------------------------

  void updateUsername(String value) {
    if (value == _username) return;
    _username = value;
    saveToStorage();
    notifyListeners();
  }

  void updateUserId(String value) {
    if (value == _userId) return;
    _userId = value;
    saveToStorage();
    notifyListeners();
  }

  void setProfileBytes(Uint8List? bytes) {
    _profileBytes = bytes;
    saveToStorage();
    notifyListeners();
  }

  void setPaymentLogoBytes(Uint8List? bytes) {
    _paymentLogoBytes = bytes;
    saveToStorage();
    notifyListeners();
  }

  void setBalance(double value) {
    _balance = value;
    saveToStorage();
    notifyListeners();
  }

  void adjustBalance(double delta) {
    _balance += delta;
    saveToStorage();
    notifyListeners();
  }

  bool canAfford(double amount) => amount <= _balance;

  void addHistoryEntry(BettingHistoryEntry entry) {
    _history.insert(0, entry);
    if (_history.length > 200) {
      _history.removeLast();
    }
    _saveHistory(); // Save to storage
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _saveHistory();
    notifyListeners();
  }

  void addGameOutcome(GameOutcome outcome) {
    _results.insert(0, outcome);
    // Keep only recent results (will be filtered to 3 days on load)
    if (_results.length > 100) {
      _results.removeLast();
    }
    _saveGameResults(); // Save to storage
    notifyListeners();
  }

  void clearResults() {
    _results.clear();
    _saveGameResults();
    notifyListeners();
  }

  /// Approve a pending deposit/withdrawal transaction
  void approveTransaction(String transactionId) {
    final index = _history.indexWhere((entry) => entry.id == transactionId);
    if (index == -1) return;
    
    final entry = _history[index];
    if (entry.status != TransactionStatus.pending) return;
    
    // Update status to completed
    _history[index] = entry.copyWith(status: TransactionStatus.completed);
    
    // Apply balance change
    if (entry.isCredit) {
      _balance += entry.amount; // Deposit - add money
    } else {
      _balance -= entry.amount; // Withdrawal - remove money
    }
    
    saveToStorage();
    notifyListeners();
  }

  /// Reject a pending deposit/withdrawal transaction
  void rejectTransaction(String transactionId) {
    final index = _history.indexWhere((entry) => entry.id == transactionId);
    if (index == -1) return;
    
    final entry = _history[index];
    if (entry.status != TransactionStatus.pending) return;
    
    // Update status to rejected
    _history[index] = entry.copyWith(status: TransactionStatus.rejected);
    
    // No balance change for rejected transactions
    saveToStorage();
    notifyListeners();
  }

  /// Get all pending transactions (deposits and withdrawals)
  List<BettingHistoryEntry> get pendingTransactions {
    return _history
        .where((entry) =>
            entry.status == TransactionStatus.pending &&
            (entry.category == TransactionCategory.deposit ||
             entry.category == TransactionCategory.withdraw))
        .toList();
  }

  /// Get all completed transactions (deposits and withdrawals)
  List<BettingHistoryEntry> get completedTransactions {
    return _history
        .where((entry) =>
            entry.status == TransactionStatus.completed &&
            (entry.category == TransactionCategory.deposit ||
             entry.category == TransactionCategory.withdraw))
        .toList();
  }

  /// Get all rejected transactions (deposits and withdrawals)
  List<BettingHistoryEntry> get rejectedTransactions {
    return _history
        .where((entry) =>
            entry.status == TransactionStatus.rejected &&
            (entry.category == TransactionCategory.deposit ||
             entry.category == TransactionCategory.withdraw))
        .toList();
  }

  void setGameEnabled(GameType type, bool enabled) {
    if (_enabledGames[type] == enabled) return;
    _enabledGames[type] = enabled;
    saveToStorage();
    notifyListeners();
  }

  void resetGames() {
    for (final key in _enabledGames.keys) {
      _enabledGames[key] = !(kGameCatalogue[key]?.hidden ?? false);
    }
    saveToStorage();
    notifyListeners();
  }

  // endregion -------------------------------------------------------------
  
  // region: wheel segment management --------------------------------------
  
  /// Get default wheel segments matching the hardcoded ones in the game
  List<WheelSegmentConfig> _getDefaultWheelSegments() {
    return [
      WheelSegmentConfig(
        id: 'miss',
        label: 'Miss',
        multiplier: 0,
        color: const Color(0xFF37474F),
        weight: 30.0, // Higher weight = more common
      ),
      WheelSegmentConfig(
        id: '1_2x',
        label: '1.2x',
        multiplier: 1.2,
        color: const Color(0xFF42A5F5),
        weight: 25.0,
      ),
      WheelSegmentConfig(
        id: '1_6x',
        label: '1.6x',
        multiplier: 1.6,
        color: const Color(0xFF26A69A),
        weight: 20.0,
      ),
      WheelSegmentConfig(
        id: '2_4x',
        label: '2.4x',
        multiplier: 2.4,
        color: const Color(0xFFFFCA28),
        weight: 12.0,
      ),
      WheelSegmentConfig(
        id: '3_2x',
        label: '3.2x',
        multiplier: 3.2,
        color: const Color(0xFFAB47BC),
        weight: 7.0,
      ),
      WheelSegmentConfig(
        id: '4_0x',
        label: '4.0x',
        multiplier: 4.0,
        color: const Color(0xFFEF5350),
        weight: 4.0, // Lower weight = rare
      ),
      WheelSegmentConfig(
        id: '1_8x',
        label: '1.8x',
        multiplier: 1.8,
        color: const Color(0xFF66BB6A),
        weight: 18.0,
      ),
      WheelSegmentConfig(
        id: '2_8x',
        label: '2.8x',
        multiplier: 2.8,
        color: const Color(0xFF7E57C2),
        weight: 10.0,
      ),
    ];
  }
  
  /// Select a random wheel segment based on weights
  WheelSegmentConfig selectWeightedWheelSegment() {
    if (_wheelSegments.isEmpty) {
      _wheelSegments = _getDefaultWheelSegments();
    }
    
    final totalWeight = _wheelSegments.fold(0.0, (sum, seg) => sum + seg.weight);
    if (totalWeight <= 0) {
      // Fallback to equal probability if all weights are 0
      final random = Random();
      return _wheelSegments[random.nextInt(_wheelSegments.length)];
    }
    
    final random = Random();
    var randomValue = random.nextDouble() * totalWeight;
    
    for (final segment in _wheelSegments) {
      randomValue -= segment.weight;
      if (randomValue <= 0) {
        return segment;
      }
    }
    
    // Fallback (shouldn't happen)
    return _wheelSegments.last;
  }
  
  void updateWheelSegmentWeight(String id, double weight) {
    final index = _wheelSegments.indexWhere((s) => s.id == id);
    if (index != -1) {
      _wheelSegments[index].weight = weight.clamp(0.0, 100.0);
      saveToStorage();
      notifyListeners();
    }
  }
  
  void resetWheelSegments() {
    _wheelSegments = _getDefaultWheelSegments();
    saveToStorage();
    notifyListeners();
  }
  
  void normalizeWheelWeights() {
    final total = _wheelSegments.fold(0.0, (sum, seg) => sum + seg.weight);
    if (total > 0) {
      for (final seg in _wheelSegments) {
        seg.weight = (seg.weight / total) * 100.0;
      }
      saveToStorage();
      notifyListeners();
    }
  }

  // endregion -------------------------------------------------------------
  
  // region: Lucky Slots management ----------------------------------------
  
  List<SlotSymbolConfig> _getDefaultSlotSymbols() {
    return [
      SlotSymbolConfig(
        id: 'cherry',
        symbol: '🍒',
        label: 'Cherry',
        multiplier: 0.5, // Loss - pays less than stake
        color: const Color(0xFFEF5350),
        weight: 35.0, // Most common
      ),
      SlotSymbolConfig(
        id: 'lemon',
        symbol: '🍋',
        label: 'Lemon',
        multiplier: 1.2,
        color: const Color(0xFFFFCA28),
        weight: 25.0,
      ),
      SlotSymbolConfig(
        id: 'watermelon',
        symbol: '🍉',
        label: 'Watermelon',
        multiplier: 2.0,
        color: const Color(0xFF66BB6A),
        weight: 20.0,
      ),
      SlotSymbolConfig(
        id: 'grape',
        symbol: '🍇',
        label: 'Grape',
        multiplier: 3.5,
        color: const Color(0xFF9C27B0),
        weight: 12.0,
      ),
      SlotSymbolConfig(
        id: 'seven',
        symbol: '7️⃣',
        label: 'Lucky 7',
        multiplier: 10.0, // Jackpot!
        color: const Color(0xFFFFD700),
        weight: 5.0, // Rare
      ),
      SlotSymbolConfig(
        id: 'diamond',
        symbol: '💎',
        label: 'Diamond',
        multiplier: 20.0, // Mega jackpot!
        color: const Color(0xFF00BCD4),
        weight: 3.0, // Very rare
        isProgressive: true,
      ),
    ];
  }
  
  SlotSymbolConfig selectWeightedSlotSymbol() {
    if (_slotSymbols.isEmpty) {
      _slotSymbols = _getDefaultSlotSymbols();
    }
    
    final totalWeight = _slotSymbols.fold(0.0, (sum, cfg) => sum + cfg.weight);
    if (totalWeight <= 0) {
      final random = Random();
      return _slotSymbols[random.nextInt(_slotSymbols.length)];
    }
    
    final random = Random();
    var randomValue = random.nextDouble() * totalWeight;
    
    for (final config in _slotSymbols) {
      randomValue -= config.weight;
      if (randomValue <= 0) {
        return config;
      }
    }
    
    return _slotSymbols.last;
  }
  
  void updateSlotSymbolWeight(String id, double weight) {
    final index = _slotSymbols.indexWhere((s) => s.id == id);
    if (index != -1) {
      _slotSymbols[index].weight = weight.clamp(0.0, 100.0);
      saveToStorage();
      notifyListeners();
    }
  }
  
  void resetSlotSymbols() {
    _slotSymbols = _getDefaultSlotSymbols();
    _ensureProgressiveSymbolAssigned();
    saveToStorage();
    notifyListeners();
  }
  
  void normalizeSlotWeights() {
    final total = _slotSymbols.fold(0.0, (sum, cfg) => sum + cfg.weight);
    if (total > 0) {
      for (final cfg in _slotSymbols) {
        cfg.weight = (cfg.weight / total) * 100.0;
      }
      saveToStorage();
      notifyListeners();
    }
  }

  // Progressive jackpot helpers -----------------------------------------

  double get slotJackpot => _slotJackpot;
  double get slotJackpotSeed => _slotJackpotSeed;
  double get slotJackpotContributionRate => _slotJackpotContributionRate;

  void setSlotJackpot(double value) {
    final sanitized = value.clamp(0.0, double.infinity);
    if ((sanitized - _slotJackpot).abs() < 0.0001) {
      return;
    }
  _slotJackpot = max(sanitized, 0.0);
    if (_slotJackpot < _slotJackpotSeed) {
      _slotJackpotSeed = _slotJackpot;
    }
    _saveSlotJackpotSnapshot();
    notifyListeners();
  }

  void setSlotJackpotSeed(double value) {
    final sanitized = value.clamp(0.0, double.infinity);
    if ((sanitized - _slotJackpotSeed).abs() < 0.0001) {
      return;
    }
    _slotJackpotSeed = sanitized;
    if (_slotJackpot < _slotJackpotSeed) {
      _slotJackpot = _slotJackpotSeed;
    }
    _saveSlotJackpotSnapshot();
    notifyListeners();
  }

  void setSlotJackpotContributionRate(double value) {
    final sanitized = value.clamp(0.0, 1.0);
    if ((sanitized - _slotJackpotContributionRate).abs() < 0.0001) {
      return;
    }
    _slotJackpotContributionRate = sanitized;
    _saveSlotJackpotSnapshot();
    notifyListeners();
  }

  void resetSlotJackpot() {
  _slotJackpot = max(_slotJackpotSeed, 0.0);
    _saveSlotJackpotSnapshot();
    notifyListeners();
  }

  void injectSlotJackpot(double amount) {
    if (amount <= 0) return;
    _slotJackpot += amount;
    _saveSlotJackpotSnapshot();
    notifyListeners();
  }

  double contributeToSlotJackpot(double stake) {
    if (stake <= 0) return 0;
    final contribution = stake * _slotJackpotContributionRate;
    if (contribution <= 0) return 0;
    _slotJackpot += contribution;
    _saveSlotJackpotSnapshot();
    notifyListeners();
    return contribution;
  }

  double claimSlotJackpot() {
    final jackpot = _slotJackpot;
  _slotJackpot = max(_slotJackpotSeed, 0.0);
    _saveSlotJackpotSnapshot();
    notifyListeners();
    return jackpot;
  }

  void designateProgressiveSymbol(String id) {
    var changed = false;
    for (final cfg in _slotSymbols) {
      final shouldBeProgressive = cfg.id == id;
      if (cfg.isProgressive != shouldBeProgressive) {
        cfg.isProgressive = shouldBeProgressive;
        changed = true;
      }
    }
    if (changed) {
      _saveSlotConfigSnapshot();
      notifyListeners();
    }
  }

  void _ensureProgressiveSymbolAssigned() {
    if (_slotSymbols.isEmpty) {
      return;
    }
    final anyMarked = _slotSymbols.any((cfg) => cfg.isProgressive);
    if (!anyMarked) {
      _slotSymbols.last.isProgressive = true;
    }
  }

  Future<void> _saveSlotConfigSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final slotsJson = jsonEncode(_slotSymbols.map((s) => s.toJson()).toList());
    await prefs.setString('betting_slots_configs', slotsJson);
  }

  Future<void> _saveSlotJackpotSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_slotJackpotKey, _slotJackpot);
    await prefs.setDouble(_slotJackpotSeedKey, _slotJackpotSeed);
    await prefs.setDouble(_slotJackpotRateKey, _slotJackpotContributionRate);
  }
  
  // endregion -------------------------------------------------------------
  
  // region: Prize Box management ------------------------------------------
  
  List<PrizeBoxConfig> _getDefaultPrizeBoxes() {
    return [
      PrizeBoxConfig(
        id: 'empty',
        label: 'Empty',
        multiplier: 0.0, // Complete loss
        color: const Color(0xFF757575),
        icon: 'close',
        weight: 30.0, // Most common
      ),
      PrizeBoxConfig(
        id: 'bronze',
        label: 'Bronze',
        multiplier: 0.8,
        color: const Color(0xFFCD7F32),
        icon: 'stars',
        weight: 25.0,
      ),
      PrizeBoxConfig(
        id: 'silver',
        label: 'Silver',
        multiplier: 1.5,
        color: const Color(0xFFC0C0C0),
        icon: 'workspace_premium',
        weight: 20.0,
      ),
      PrizeBoxConfig(
        id: 'gold',
        label: 'Gold',
        multiplier: 3.0,
        color: const Color(0xFFFFD700),
        icon: 'emoji_events',
        weight: 15.0,
      ),
      PrizeBoxConfig(
        id: 'platinum',
        label: 'Platinum',
        multiplier: 5.0,
        color: const Color(0xFFE5E4E2),
        icon: 'military_tech',
        weight: 7.0,
      ),
      PrizeBoxConfig(
        id: 'diamond',
        label: 'Diamond',
        multiplier: 10.0, // Big win!
        color: const Color(0xFF00BCD4),
        icon: 'diamond',
        weight: 3.0, // Rare
      ),
    ];
  }
  
  PrizeBoxConfig selectWeightedPrizeBox() {
    if (_prizeBoxes.isEmpty) {
      _prizeBoxes = _getDefaultPrizeBoxes();
    }
    
    final totalWeight = _prizeBoxes.fold(0.0, (sum, cfg) => sum + cfg.weight);
    if (totalWeight <= 0) {
      final random = Random();
      return _prizeBoxes[random.nextInt(_prizeBoxes.length)];
    }
    
    final random = Random();
    var randomValue = random.nextDouble() * totalWeight;
    
    for (final config in _prizeBoxes) {
      randomValue -= config.weight;
      if (randomValue <= 0) {
        return config;
      }
    }
    
    return _prizeBoxes.last;
  }
  
  void updatePrizeBoxWeight(String id, double weight) {
    final index = _prizeBoxes.indexWhere((p) => p.id == id);
    if (index != -1) {
      _prizeBoxes[index].weight = weight.clamp(0.0, 100.0);
      saveToStorage();
      notifyListeners();
    }
  }
  
  void resetPrizeBoxes() {
    _prizeBoxes = _getDefaultPrizeBoxes();
    saveToStorage();
    notifyListeners();
  }
  
  void normalizePrizeBoxWeights() {
    final total = _prizeBoxes.fold(0.0, (sum, cfg) => sum + cfg.weight);
    if (total > 0) {
      for (final cfg in _prizeBoxes) {
        cfg.weight = (cfg.weight / total) * 100.0;
      }
      saveToStorage();
      notifyListeners();
    }
  }
  
  // endregion -------------------------------------------------------------
  
  // region: Color Spinner management --------------------------------------
  
  List<ColorSegmentConfig> _getDefaultColorSegments() {
    return [
      ColorSegmentConfig(
        id: 'red',
        label: 'Red',
        multiplier: 2.0,
        color: const Color(0xFFEF5350),
        weight: 25.0,
      ),
      ColorSegmentConfig(
        id: 'blue',
        label: 'Blue',
        multiplier: 2.0,
        color: const Color(0xFF42A5F5),
        weight: 25.0,
      ),
      ColorSegmentConfig(
        id: 'green',
        label: 'Green',
        multiplier: 3.0,
        color: const Color(0xFF66BB6A),
        weight: 20.0,
      ),
      ColorSegmentConfig(
        id: 'yellow',
        label: 'Yellow',
        multiplier: 4.0,
        color: const Color(0xFFFFCA28),
        weight: 15.0,
      ),
      ColorSegmentConfig(
        id: 'purple',
        label: 'Purple',
        multiplier: 6.0,
        color: const Color(0xFF9C27B0),
        weight: 10.0,
      ),
      ColorSegmentConfig(
        id: 'gold',
        label: 'Gold',
        multiplier: 10.0, // Jackpot color!
        color: const Color(0xFFFFD700),
        weight: 5.0, // Rare
      ),
    ];
  }
  
  ColorSegmentConfig selectWeightedColorSegment() {
    if (_colorSegments.isEmpty) {
      _colorSegments = _getDefaultColorSegments();
    }
    
    final totalWeight = _colorSegments.fold(0.0, (sum, cfg) => sum + cfg.weight);
    if (totalWeight <= 0) {
      final random = Random();
      return _colorSegments[random.nextInt(_colorSegments.length)];
    }
    
    final random = Random();
    var randomValue = random.nextDouble() * totalWeight;
    
    for (final config in _colorSegments) {
      randomValue -= config.weight;
      if (randomValue <= 0) {
        return config;
      }
    }
    
    return _colorSegments.last;
  }
  
  void updateColorSegmentWeight(String id, double weight) {
    final index = _colorSegments.indexWhere((c) => c.id == id);
    if (index != -1) {
      _colorSegments[index].weight = weight.clamp(0.0, 100.0);
      saveToStorage();
      notifyListeners();
    }
  }
  
  void resetColorSegments() {
    _colorSegments = _getDefaultColorSegments();
    saveToStorage();
    notifyListeners();
  }
  
  void normalizeColorWeights() {
    final total = _colorSegments.fold(0.0, (sum, cfg) => sum + cfg.weight);
    if (total > 0) {
      for (final cfg in _colorSegments) {
        cfg.weight = (cfg.weight / total) * 100.0;
      }
      saveToStorage();
      notifyListeners();
    }
  }

  // endregion -------------------------------------------------------------
}
