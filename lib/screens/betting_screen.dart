import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/floating_header.dart';
import 'betting_history_screen.dart';
import 'enhanced_notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/betting_entities.dart';
import '../models/betting_models.dart';
import '../services/betting_data_store.dart';

String _formatNumeric(double amount) {
  final isNegative = amount < 0;
  final absolute = amount.abs();
  final parts = absolute.toStringAsFixed(2).split('.');
  final integer = parts.first;
  final buffer = StringBuffer();

  for (var i = 0; i < integer.length; i++) {
    final indexFromEnd = integer.length - i;
    buffer.write(integer[i]);
    final shouldInsertSeparator = indexFromEnd > 1 && indexFromEnd % 3 == 1;
    if (shouldInsertSeparator) {
      buffer.write(',');
    }
  }

  final formatted = buffer.toString();
  final fractional = parts.length > 1 ? parts[1] : '00';
  final result = '$formatted.$fractional';
  return isNegative ? '-$result' : result;
}

String _formatCurrency(double amount) => '₦₲${_formatNumeric(amount)}';

class BettingScreen extends StatefulWidget {
  const BettingScreen({
    super.key,
    this.username,
    this.userId,
    this.initialBalance,
  });

  final String? username;
  final String? userId;
  final double? initialBalance;

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  static const Duration _notificationRetention = Duration(days: 5);
  static const Map<GameType, _LuckySpinProfile> _luckySpinProfiles = {
    GameType.moneyMania: _LuckySpinProfile(
      tagline: 'Draw a premium ticket and chase casino multipliers.',
      buttonLabel: 'Draw ticket',
      outcomes: [
        _LuckySpinOutcome(
          label: 'Jackpot ticket',
          multiplier: 6.0,
          weight: 2,
          detail: 'Jackpot ticket cashes a 6x payout.',
        ),
        _LuckySpinOutcome(
          label: 'Gold ticket',
          multiplier: 3.0,
          weight: 6,
          detail: 'Gold ticket triples the stake.',
        ),
        _LuckySpinOutcome(
          label: 'Silver ticket',
          multiplier: 2.0,
          weight: 10,
          detail: 'Silver ticket doubles the stake.',
        ),
        _LuckySpinOutcome(
          label: 'Bronze ticket',
          multiplier: 1.1,
          weight: 14,
          detail: 'Bronze ticket refunds the stake with a 10 percent tip.',
        ),
        _LuckySpinOutcome(
          label: 'Lucky refund',
          multiplier: 1.0,
          weight: 16,
          detail: 'Lucky refund returns every chip.',
        ),
        _LuckySpinOutcome(
          label: 'Blank slip',
          multiplier: 0.0,
          weight: 18,
          detail: 'Blank slip misses all rewards.',
        ),
      ],
      benefits: [
        'Jackpot ticket pays 6x instantly.',
        'Gold and silver tickets double your stake.',
        'Bronze ticket keeps bankroll loss light.',
      ],
    ),
    GameType.magicTreasure: _LuckySpinProfile(
      tagline: 'Send a cash storm across the reels for steady boosts.',
      buttonLabel: 'Spin storm',
      outcomes: [
        _LuckySpinOutcome(
          label: 'Storm surge',
          multiplier: 4.5,
          weight: 3,
          detail: 'Storm surge rains a 4.5x return.',
        ),
        _LuckySpinOutcome(
          label: 'Power gust',
          multiplier: 2.5,
          weight: 8,
          detail: 'Power gust adds a 2.5x boost.',
        ),
        _LuckySpinOutcome(
          label: 'Cash shower',
          multiplier: 1.8,
          weight: 14,
          detail: 'Cash shower grows the stake by 80 percent.',
        ),
        _LuckySpinOutcome(
          label: 'Safe breeze',
          multiplier: 1.2,
          weight: 18,
          detail: 'Safe breeze returns the stake with a cushion.',
        ),
        _LuckySpinOutcome(
          label: 'Calm pocket',
          multiplier: 1.0,
          weight: 16,
          detail: 'Calm pocket refunds the entire stake.',
        ),
        _LuckySpinOutcome(
          label: 'Dry pocket',
          multiplier: 0.0,
          weight: 14,
          detail: 'Dry pocket pays nothing this round.',
        ),
      ],
      benefits: [
        'Storm surge reaches up to 4.5x.',
        'Half the spins return at least 1.2x.',
        'Two calm pockets refund the full stake.',
      ],
    ),
    GameType.lgtJackpot: _LuckySpinProfile(
      tagline: 'Break open the neon vault for stacked multipliers.',
      buttonLabel: 'Crack vault',
      outcomes: [
        _LuckySpinOutcome(
          label: 'Breaker badge',
          multiplier: 7.0,
          weight: 2,
          detail: 'Breaker badge smashes a 7x hit.',
        ),
        _LuckySpinOutcome(
          label: 'Vault surge',
          multiplier: 4.0,
          weight: 6,
          detail: 'Vault surge floods 4x back.',
        ),
        _LuckySpinOutcome(
          label: 'Neon stack',
          multiplier: 2.8,
          weight: 10,
          detail: 'Neon stack returns a 2.8x payout.',
        ),
        _LuckySpinOutcome(
          label: 'Security bond',
          multiplier: 1.5,
          weight: 16,
          detail: 'Security bond adds a 50 percent gain.',
        ),
        _LuckySpinOutcome(
          label: 'Safe slip',
          multiplier: 1.0,
          weight: 14,
          detail: 'Safe slip keeps the bankroll even.',
        ),
        _LuckySpinOutcome(
          label: 'Empty cell',
          multiplier: 0.0,
          weight: 18,
          detail: 'Empty cell turns up empty.',
        ),
      ],
      benefits: [
        'Breaker badge blasts a 7x payout.',
        'Neon stacks pay between 2.8x and 4x.',
        'Safe slip refunds the full stake.',
      ],
    ),
    GameType.jackpotInferno: _LuckySpinProfile(
      tagline: 'Ride the flames for explosive multiplier bursts.',
      buttonLabel: 'Heat spin',
      outcomes: [
        _LuckySpinOutcome(
          label: 'Inferno flare',
          multiplier: 9.0,
          weight: 2,
          detail: 'Inferno flare ignites a 9x payout.',
        ),
        _LuckySpinOutcome(
          label: 'Blaze roll',
          multiplier: 5.0,
          weight: 6,
          detail: 'Blaze roll fires a 5x reward.',
        ),
        _LuckySpinOutcome(
          label: 'Heat surge',
          multiplier: 3.2,
          weight: 10,
          detail: 'Heat surge delivers a 3.2x return.',
        ),
        _LuckySpinOutcome(
          label: 'Warm draft',
          multiplier: 1.7,
          weight: 14,
          detail: 'Warm draft keeps 1.7x in play.',
        ),
        _LuckySpinOutcome(
          label: 'Safe ember',
          multiplier: 1.1,
          weight: 14,
          detail: 'Safe ember protects most of the stake.',
        ),
        _LuckySpinOutcome(
          label: 'Ash out',
          multiplier: 0.0,
          weight: 20,
          detail: 'Ash out leaves the pot empty.',
        ),
      ],
      benefits: [
        'Inferno flare peaks at 9x.',
        'Blaze tiers return between 3x and 5x.',
        'Safe ember keeps losses minimal.',
      ],
    ),
    GameType.megaRoulette: _LuckySpinProfile(
      tagline: 'Loop the roulette burst for lightning gains.',
      buttonLabel: 'Loop spin',
      outcomes: [
        _LuckySpinOutcome(
          label: 'Loop strike',
          multiplier: 5.5,
          weight: 3,
          detail: 'Loop strike bolts a 5.5x return.',
        ),
        _LuckySpinOutcome(
          label: 'Charged rail',
          multiplier: 3.0,
          weight: 8,
          detail: 'Charged rail powers a triple payout.',
        ),
        _LuckySpinOutcome(
          label: 'Twin flash',
          multiplier: 2.0,
          weight: 12,
          detail: 'Twin flash doubles the stake.',
        ),
        _LuckySpinOutcome(
          label: 'Safety loop',
          multiplier: 1.2,
          weight: 18,
          detail: 'Safety loop returns the stake with interest.',
        ),
        _LuckySpinOutcome(
          label: 'Reset lane',
          multiplier: 1.0,
          weight: 16,
          detail: 'Reset lane refunds the stake.',
        ),
        _LuckySpinOutcome(
          label: 'Power drop',
          multiplier: 0.0,
          weight: 15,
          detail: 'Power drop drains the round.',
        ),
      ],
      benefits: [
        'Loop strike can reach 5.5x.',
        'Charged rails and twin flashes build fast profits.',
        'Safety lanes protect the bankroll on cold spins.',
      ],
    ),
  };

  final BettingDataStore _store = BettingDataStore.instance;
  final ImagePicker _picker = ImagePicker();

  late final VoidCallback _storeListener;
  int _unreadCount = 0;
  bool _initializing = true;
  bool _loadingUnread = false;

  @override
  void initState() {
    super.initState();
    _storeListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _store.addListener(_storeListener);
    _initialize();
  }

  @override
  void dispose() {
    _store.removeListener(_storeListener);
    super.dispose();
  }

  Future<void> _initialize() async {
    await _store.loadFromStorage();
    _store.initializeOnce(
      username: widget.username,
      userId: widget.userId,
      initialBalance: widget.initialBalance,
    );
    if (mounted) {
      setState(() {});
    }
    await _loadUnreadCount();
    if (!mounted) return;
    setState(() => _initializing = false);
  }

  Future<void> _refreshData() async {
    await _store.loadFromStorage();
    await _loadUnreadCount();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUnreadCount() async {
    if (_loadingUnread) return;
    _loadingUnread = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      var username = _store.username.trim();
      final hasExplicitUsername = username.isNotEmpty;
      if (!hasExplicitUsername) {
        username = 'guest';
      }

      final normalized = username.toLowerCase();
      final primaryKey = '${normalized}_notifications';
      final Map<String, Map<String, dynamic>> merged =
          <String, Map<String, dynamic>>{};
      final DateTime now = DateTime.now();

      Future<void> mergeKey(String key, {bool markPrimary = false}) async {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) return;
        List<dynamic> decoded;
        try {
          decoded = jsonDecode(raw) as List<dynamic>;
        } catch (_) {
          if (markPrimary) {
            await prefs.setString(primaryKey, '[]');
          }
          return;
        }
        bool changed = false;
        final List<Map<String, dynamic>> kept = <Map<String, dynamic>>[];
        for (final entry in decoded) {
          if (entry is! Map) {
            changed = true;
            continue;
          }
          final map = Map<String, dynamic>.from(entry);
          final timestampRaw = map['timestamp']?.toString();
          final timestamp =
              timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;
          if (timestamp == null ||
              now.difference(timestamp) > _notificationRetention) {
            changed = true;
            continue;
          }
          kept.add(map);
          final id = _deriveNotificationId(map, primaryKey);
          merged.putIfAbsent(id, () => map);
        }
        if (changed) {
          await prefs.setString(key, jsonEncode(kept));
        }
      }

      await mergeKey(primaryKey, markPrimary: true);

      if (hasExplicitUsername) {
        for (final key in prefs.getKeys()) {
          if (key == primaryKey) continue;
          if (!key.endsWith('_notifications')) continue;
          if (key.toLowerCase() == primaryKey) {
            await mergeKey(key);
          }
        }
      } else {
        const legacyCandidates = [
          'NGMY User_notifications',
          'ngmy user_notifications',
        ];
        for (final key in legacyCandidates) {
          if (prefs.containsKey(key)) {
            await mergeKey(key);
          }
        }
      }

      await mergeKey('user_notifications');
      await mergeKey('admin_notifications');

      final List<Map<String, dynamic>> ordered = merged.values
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

      const Set<String> allowedScopes = {'global'};
      final int unread = ordered.where((entry) {
        if (entry['read'] == true) {
          return false;
        }
        final scopesRaw = entry['scopes'];
        if (scopesRaw is! List || scopesRaw.isEmpty) {
          return true;
        }
        final scopes =
            scopesRaw.whereType<String>().map((scope) => scope.toLowerCase());
        if (scopes.contains('global')) {
          return true;
        }
        return scopes.any(allowedScopes.contains);
      }).length;

      if (!mounted) return;
      setState(() {
        _unreadCount = unread;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unreadCount = 0;
      });
    } finally {
      _loadingUnread = false;
    }
  }

  String _deriveNotificationId(Map<String, dynamic> map, String fallbackKey) {
    final id = map['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final timestampRaw = map['timestamp']?.toString();
    final timestamp =
        timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;
    if (timestamp != null) {
      return '${timestamp.microsecondsSinceEpoch}_$fallbackKey';
    }
    final title = map['title']?.toString() ?? '';
    final message = map['message']?.toString() ?? '';
    return '${title.hashCode}_${message.hashCode}_$fallbackKey';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      body: SafeArea(
        child: _initializing
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C9EFF)),
                ),
              )
            : RefreshIndicator(
                color: Colors.white,
                backgroundColor: const Color(0xFF1F2937),
                onRefresh: _refreshData,
                child: AnimatedBuilder(
                  animation: _store,
                  builder: (context, _) {
                    final games = _store.activeGames;
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 18),
                          _buildQuickActionsBar(),
                          const SizedBox(height: 28),
                          _buildGamesHeader(),
                          const SizedBox(height: 14),
                          if (games.isEmpty)
                            GlassSurface(
                              blur: 12,
                              elevation: 4,
                              borderRadius: BorderRadius.circular(20),
                              color:
                                  Colors.white.withAlpha((0.06 * 255).round()),
                              child: const Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.hourglass_empty_rounded,
                                      color: Colors.white54,
                                      size: 40,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Casino games are currently unavailable.\nCheck back soon for new challenges!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            _buildGamesSection(),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final profileBytes = _store.profileBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Center(
                child: Text(
                  'BETTING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: _openNotifications,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      tooltip: 'Notifications',
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            _unreadCount > 99 ? '99+' : '$_unreadCount',
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassSurface(
          blur: 20,
          elevation: 12,
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withAlpha((0.08 * 255).round()),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _handleChangeProfilePicture,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor:
                        Colors.white.withAlpha((0.10 * 255).round()),
                    backgroundImage:
                        profileBytes != null ? MemoryImage(profileBytes) : null,
                    child: profileBytes == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: Colors.white70,
                            size: 36,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WELCOME BACK',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _handleChangeDisplayName,
                        child: Text(
                          _store.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: ${_store.userId}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ACCOUNT BALANCE',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF00E676)
                              .withAlpha((0.10 * 255).round()),
                          border: Border.all(
                            color: const Color(0xFF00E676)
                                .withAlpha((0.55 * 255).round()),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '₦₲',
                              style: TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatNumeric(_store.balance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 21,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsBar() {
    return GlassSurface(
      blur: 14,
      elevation: 6,
      borderRadius: BorderRadius.circular(22),
      color: const Color(0xFF0E1728).withAlpha((0.12 * 255).round()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: Colors.white.withAlpha((0.14 * 255).round())),
        ),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                label: 'Deposit',
                icon: Icons.add_circle_rounded,
                color: const Color(0xFF00E5A8),
                onTap: _openDepositPage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                label: 'Withdraw',
                icon: Icons.remove_circle_rounded,
                color: const Color(0xFFFF5E8A),
                onTap: _openWithdrawPage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                label: 'History',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF7C9EFF),
                onTap: _openHistory,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesHeader() {
    return Row(
      children: [
        const Icon(Icons.videogame_asset_rounded, color: Colors.white70),
        const SizedBox(width: 8),
        const Text(
          'Available games',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _openGameResults,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C9EFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          icon: const Icon(Icons.stacked_bar_chart_rounded, size: 18),
          label: const Text('Results'),
        ),
      ],
    );
  }

  void _openHistory() {
    final moneyTransactions = _store.history
        .where((entry) =>
            entry.category == TransactionCategory.deposit ||
            entry.category == TransactionCategory.withdraw)
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BettingHistoryScreen(entries: moneyTransactions),
      ),
    );
  }

  void _openGameResults() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GameResultsSheet(results: _store.results),
    );
  }

  void _openDepositPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DepositPage(
          onSubmit: (amount, receiptBytes) async {
            await _handleDeposit(amount: amount, receiptBytes: receiptBytes);
          },
        ),
      ),
    );
  }

  void _openWithdrawPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WithdrawPage(
          currentBalance: _store.balance,
          onSubmit: (amount, cashTag) async {
            await _handleWithdraw(amount: amount, cashTag: cashTag);
          },
        ),
      ),
    );
  }

  Widget _buildGamesSection() {
    return GlassSurface(
      blur: 12,
      elevation: 4,
      borderRadius: BorderRadius.circular(22),
      color: const Color(0xFF0E1728).withAlpha((0.12 * 255).round()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: Colors.white.withAlpha((0.10 * 255).round())),
        ),
        child: Column(
          children: _store.activeGames
              .map((game) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GameCard(
                      game: game,
                      onTap: () => _handlePlayGame(game),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _handleChangeDisplayName() async {
    final controller = TextEditingController(text: _store.username);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Update display name'),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter display name'),
              autofocus: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                Navigator.of(context).pop();
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      _store.updateUsername(newName);
      await _loadUnreadCount();
    }
  }

  void _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            EnhancedNotificationsScreen(username: _store.username),
      ),
    );
    await _loadUnreadCount();
  }

  Future<void> _handleChangeProfilePicture() async {
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        _store.setProfileBytes(bytes);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $error')),
      );
    }
  }

  Future<void> _handleDeposit(
      {required double amount, Uint8List? receiptBytes}) async {
    if (amount <= 0) return;
    _addHistoryEntry(
      title: 'Wallet deposit',
      amount: amount,
      isCredit: true,
      category: TransactionCategory.deposit,
      icon: Icons.download_rounded,
      color: const Color(0xFF26A69A),
      receiptBytes: receiptBytes,
      status: TransactionStatus.pending,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deposit submitted! Waiting for admin approval.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleWithdraw(
      {required double amount, required String cashTag}) async {
    if (amount <= 0) return;
    if (!_store.canAfford(amount)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal exceeds available balance.')),
      );
      return;
    }
    _addHistoryEntry(
      title: 'Wallet withdrawal ($cashTag)',
      amount: amount,
      isCredit: false,
      category: TransactionCategory.withdraw,
      icon: Icons.upload_rounded,
      color: const Color(0xFFFF7043),
      status: TransactionStatus.pending,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Withdrawal submitted! Waiting for admin approval.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handlePlayGame(GameItem game) async {
    final stake = await _promptStake(game);
    if (stake == null || stake <= 0) return;

    if (!_store.canAfford(stake)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Insufficient balance for ${_formatCurrency(stake)} stake.')),
      );
      return;
    }

    _store.adjustBalance(-stake);
    _addHistoryEntry(
      title: 'Stake · ${game.title}',
      amount: stake,
      isCredit: false,
      category: TransactionCategory.game,
      icon: game.icon,
      color: game.accent,
      status: TransactionStatus.pending,
    );

    final result = await _startGameSession(game, stake);

    if (!mounted) return;

    if (result == null) {
      _store.adjustBalance(stake);
      _addHistoryEntry(
        title: 'Stake refunded · ${game.title}',
        amount: stake,
        isCredit: true,
        category: TransactionCategory.game,
        icon: Icons.refresh_rounded,
        color: Colors.white,
      );
      return;
    }

    if (result.didWin && result.payout > 0) {
      _store.adjustBalance(result.payout);
      final profit = result.payout - stake;
      final descriptor =
          profit > 0 ? 'Profit ${_formatCurrency(profit)}' : 'Stake returned';
      _addHistoryEntry(
        title: '${game.title} · $descriptor',
        amount: result.payout,
        isCredit: true,
        category: TransactionCategory.game,
        icon: Icons.celebration_rounded,
        color: const Color(0xFF81C784),
      );
    } else {
      _addHistoryEntry(
        title: '${game.title} · Lost stake',
        amount: stake,
        isCredit: false,
        category: TransactionCategory.game,
        icon: Icons.sentiment_dissatisfied_rounded,
        color: const Color(0xFFFF8A80),
      );
    }

    _store.addGameOutcome(
      GameOutcome(
        game: game,
        didWin: result.didWin,
        stake: stake,
        payout: result.payout,
        detail: result.detail,
        timestamp: DateTime.now(),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.detail)),
    );
  }

  Future<double?> _promptStake(GameItem game) async {
    final controller = TextEditingController(text: '5');
    final presets = [2.0, 5.0, 10.0, 20.0];
    double? selectedPreset;

    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stake on ${game.title}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  game.description,
                  style: TextStyle(
                      color: Colors.black.withAlpha((0.6 * 255).round())),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: presets
                      .map(
                        (value) => ChoiceChip(
                          label: Text(_formatCurrency(value)),
                          selected: selectedPreset == value,
                          onSelected: (_) {
                            setSheetState(() {
                              selectedPreset = value;
                              controller.text = value.toStringAsFixed(0);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Custom amount',
                    prefixIcon: Icon(Icons.currency_exchange_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final value = double.tryParse(
                              controller.text.replaceAll(',', ''));
                          if (value == null || value < 2.0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Minimum bet is ₦₲2')),
                            );
                            return;
                          }
                          Navigator.of(context).pop(value);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: game.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Place stake'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_GamePlayResult?> _startGameSession(GameItem game, double stake) {
    if (game.type == GameType.wheel) {
      return Navigator.of(context).push<_GamePlayResult>(
        MaterialPageRoute(
          builder: (_) => _WheelGameScreen(game: game, stake: stake),
        ),
      );
    }

    final profile = _luckySpinProfiles[game.type];
    if (profile != null) {
      return Navigator.of(context).push<_GamePlayResult>(
        MaterialPageRoute(
          builder: (_) => _LuckySpinGameScreen(
            game: game,
            stake: stake,
            profile: profile,
          ),
        ),
      );
    }

    if (game.type == GameType.slots) {
      return Navigator.of(context).push<_GamePlayResult>(
        MaterialPageRoute(
          builder: (_) => _LuckySlotsGameScreen(game: game, stake: stake),
        ),
      );
    }

    switch (game.type) {
      case GameType.prizeBox:
        return Navigator.of(context).push<_GamePlayResult>(
          MaterialPageRoute(
            builder: (_) => _PrizeBoxGameScreen(game: game, stake: stake),
          ),
        );
      case GameType.colorSpinner:
        return Navigator.of(context).push<_GamePlayResult>(
          MaterialPageRoute(
            builder: (_) => _ColorSpinnerGameScreen(game: game, stake: stake),
          ),
        );
      default:
        return Future.value(null);
    }
  }

  void _addHistoryEntry({
    required String title,
    required double amount,
    required bool isCredit,
    required TransactionCategory category,
    required IconData icon,
    required Color color,
    TransactionStatus status = TransactionStatus.completed,
    Uint8List? receiptBytes,
    String? receiptName,
  }) {
    final entry = BettingHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      isCredit: isCredit,
      category: category,
      icon: icon,
      color: color,
      timestamp: DateTime.now(),
      status: status,
      receiptBytes: receiptBytes,
      receiptName: receiptName,
    );

    _store.addHistoryEntry(entry);
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});

  final GameItem game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              game.accent.withAlpha((0.22 * 255).round()),
              game.accent.withAlpha((0.08 * 255).round()),
            ],
          ),
          border:
              Border.all(color: game.accent.withAlpha((0.35 * 255).round())),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: game.accent.withAlpha((0.25 * 255).round()),
              ),
              child: Icon(game.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    game.description,
                    style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round())),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: GlassSurface(
        blur: 16,
        elevation: 8,
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withAlpha((0.06 * 255).round()),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: Colors.white.withAlpha((0.12 * 255).round())),
            color: color.withAlpha((0.10 * 255).round()),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Label first, then icon, to prioritize readability
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 0.2,
                    ),
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      Color.lerp(color, Colors.white, 0.2)!,
                    ],
                  ),
                  border: Border.all(
                      color: color.withAlpha((0.65 * 255).round()), width: 1),
                ),
                child: Icon(icon, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepositPage extends StatefulWidget {
  const _DepositPage({required this.onSubmit});

  final Future<void> Function(double amount, Uint8List? receiptBytes) onSubmit;

  @override
  State<_DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<_DepositPage> {
  final _amountController = TextEditingController();
  Uint8List? _receipt;
  bool _submitting = false;
  final _store = BettingDataStore.instance;

  Future<void> _pickReceipt() async {
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, maxWidth: 1400);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() => _receipt = bytes);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: const FloatingHeader(
        title: 'Deposit',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Payment Logo (if uploaded)
            if (_store.paymentLogoBytes != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _store.paymentLogoBytes!,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Cash App Payment Button
            GlassSurface(
              blur: 14,
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              color: Colors.green.withAlpha((0.15 * 255).round()),
              child: InkWell(
                onTap: () async {
                  final url = Uri.parse('https://cash.app/\$NGMYPay');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha((0.3 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payment,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pay with Cash App',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Send to: \$NGMYPay',
                              style: TextStyle(
                                color:
                                    Colors.white.withAlpha((0.7 * 255).round()),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GlassSurface(
              blur: 14,
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withAlpha((0.05 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter amount',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Amount',
                        prefixIcon: Icon(Icons.currency_exchange_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Upload proof (screenshot)',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickReceipt,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload screenshot'),
                        ),
                        const SizedBox(width: 12),
                        if (_receipt != null)
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF81C784)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        final amount = double.tryParse(
                                _amountController.text.replaceAll(',', '')) ??
                            0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter a valid amount')));
                          return;
                        }
                        setState(() => _submitting = true);
                        await widget.onSubmit(amount, _receipt);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                child: Text(_submitting ? 'Submitting...' : 'Submit deposit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawPage extends StatefulWidget {
  const _WithdrawPage({required this.currentBalance, required this.onSubmit});

  final double currentBalance;
  final Future<void> Function(double amount, String cashTag) onSubmit;

  @override
  State<_WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<_WithdrawPage> {
  final _amountController = TextEditingController();
  final _cashTagController = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: const FloatingHeader(
        title: 'Withdraw',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassSurface(
              blur: 14,
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withAlpha((0.05 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available: ${_formatCurrency(widget.currentBalance)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount to withdraw',
                        prefixIcon: Icon(Icons.currency_exchange_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cashTagController,
                      decoration: const InputDecoration(
                        labelText: 'Cash App tag',
                        hintText: '\$yourtag',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        final amount = double.tryParse(
                                _amountController.text.replaceAll(',', '')) ??
                            0;
                        final tag = _cashTagController.text.trim();
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter a valid amount')));
                          return;
                        }
                        if (tag.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter your Cash App tag')));
                          return;
                        }
                        setState(() => _submitting = true);
                        await widget.onSubmit(amount, tag);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                child:
                    Text(_submitting ? 'Submitting...' : 'Submit withdrawal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameResultsSheet extends StatelessWidget {
  const _GameResultsSheet({required this.results});

  final List<GameOutcome> results;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E1728).withAlpha((0.96 * 255).round()),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border:
                Border.all(color: Colors.white.withAlpha((0.10 * 255).round())),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white.withAlpha((0.24 * 255).round()),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Game Results',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          'No game results yet',
                          style: TextStyle(
                              color:
                                  Colors.white.withAlpha((0.7 * 255).round())),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, i) {
                          final r = results[i];
                          final color = r.didWin
                              ? const Color(0xFF81C784)
                              : const Color(0xFFFF8A80);
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color:
                                  Colors.white.withAlpha((0.06 * 255).round()),
                              border: Border.all(
                                  color: Colors.white
                                      .withAlpha((0.12 * 255).round())),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.game.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text(
                                      r.didWin ? 'Won' : 'Lost',
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r.detail,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'Stake: ${_formatCurrency(r.stake)}',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Payout: ${_formatCurrency(r.payout)}',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatResultTime(r.timestamp),
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: results.length,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatResultTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _GamePlayResult {
  const _GamePlayResult({
    required this.stake,
    required this.payout,
    required this.didWin,
    required this.detail,
  });

  final double stake;
  final double payout;
  final bool didWin;
  final String detail;

  double get profit => didWin ? payout - stake : -stake;
}

class _LuckySpinProfile {
  const _LuckySpinProfile({
    required this.tagline,
    required this.buttonLabel,
    required this.outcomes,
    required this.benefits,
  });

  final String tagline;
  final String buttonLabel;
  final List<_LuckySpinOutcome> outcomes;
  final List<String> benefits;
}

class _LuckySpinOutcome {
  const _LuckySpinOutcome({
    required this.label,
    required this.multiplier,
    required this.weight,
    required this.detail,
  });

  final String label;
  final double multiplier;
  final int weight;
  final String detail;
}

class _LuckySpinGameScreen extends StatefulWidget {
  const _LuckySpinGameScreen({
    required this.game,
    required this.stake,
    required this.profile,
  });

  final GameItem game;
  final double stake;
  final _LuckySpinProfile profile;

  @override
  State<_LuckySpinGameScreen> createState() => _LuckySpinGameScreenState();
}

class _LuckySpinGameScreenState extends State<_LuckySpinGameScreen> {
  final Random _random = Random();
  bool _isSpinning = false;

  Future<void> _handleSpin() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    final outcome = _pickOutcome();
    final multiplier = outcome.multiplier;
    final payout = multiplier > 0 ? widget.stake * multiplier : 0.0;
    final didWin = multiplier >= 1.0;
    final detail = _buildDetail(outcome, payout);

    if (!mounted) return;

    setState(() {
      _isSpinning = false;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LuckySpinResultDialog(
        game: widget.game,
        outcome: outcome,
        stake: widget.stake,
        payout: payout,
        didWin: didWin,
      ),
    );

    if (!mounted) return;

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: didWin,
        detail: detail,
      ),
    );
  }

  _LuckySpinOutcome _pickOutcome() {
    final outcomes = widget.profile.outcomes;
    if (outcomes.isEmpty) {
      return const _LuckySpinOutcome(
        label: 'House hold',
        multiplier: 0.0,
        weight: 1,
        detail: 'No payouts configured.',
      );
    }

    final totalWeight = outcomes.fold<int>(
      0,
      (sum, outcome) => sum + (outcome.weight <= 0 ? 1 : outcome.weight),
    );

    var roll = totalWeight > 0 ? _random.nextInt(totalWeight) : 0;
    for (final outcome in outcomes) {
      final weight = outcome.weight <= 0 ? 1 : outcome.weight;
      if (roll < weight) {
        return outcome;
      }
      roll -= weight;
    }
    return outcomes.last;
  }

  String _buildDetail(_LuckySpinOutcome outcome, double payout) {
    final multiplierText = outcome.multiplier % 1 == 0
        ? outcome.multiplier.toStringAsFixed(0)
        : outcome.multiplier.toStringAsFixed(2);
    final buffer = StringBuffer()
      ..write('${widget.game.title}: ${outcome.label} ${multiplierText}x');
    if (payout > 0) {
      buffer
        ..write(' pays ')
        ..write(_formatCurrency(payout))
        ..write('.');
    } else {
      buffer.write(' pays nothing.');
    }
    buffer
      ..write(' ')
      ..write(outcome.detail);
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.game.accent;
    final profile = widget.profile;
    final outcomePreview = List<_LuckySpinOutcome>.from(profile.outcomes)
      ..sort((a, b) => b.multiplier.compareTo(a.multiplier));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassSurface(
                blur: 16,
                elevation: 8,
                borderRadius: BorderRadius.circular(24),
                color: Colors.white.withAlpha((0.08 * 255).round()),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withAlpha((0.30 * 255).round()),
                              border: Border.all(
                                color: Colors.white
                                    .withAlpha((0.30 * 255).round()),
                              ),
                            ),
                            child: Icon(
                              widget.game.icon,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.game.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  profile.tagline,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Stake ${_formatCurrency(widget.stake)}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ...profile.benefits.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: accent.withAlpha((0.75 * 255).round()),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Multiplier ladder',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: outcomePreview.map((outcome) {
                  final isLoss = outcome.multiplier <= 0;
                  final multiplierText = outcome.multiplier % 1 == 0
                      ? outcome.multiplier.toStringAsFixed(0)
                      : outcome.multiplier.toStringAsFixed(2);
                  return Container(
                    constraints: const BoxConstraints(minWidth: 130),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: isLoss
                          ? Colors.white.withAlpha((0.10 * 255).round())
                          : accent.withAlpha((0.22 * 255).round()),
                      border: Border.all(
                        color: isLoss
                            ? Colors.white.withAlpha((0.18 * 255).round())
                            : accent.withAlpha((0.65 * 255).round()),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          outcome.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${multiplierText}x',
                          style: TextStyle(
                            color: isLoss ? Colors.white70 : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outcome.detail,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 26),
              if (_isSpinning)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSpinning ? null : _handleSpin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _isSpinning ? 'Spinning...' : profile.buttonLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed:
                    _isSpinning ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LuckySpinResultDialog extends StatelessWidget {
  const _LuckySpinResultDialog({
    required this.game,
    required this.outcome,
    required this.stake,
    required this.payout,
    required this.didWin,
  });

  final GameItem game;
  final _LuckySpinOutcome outcome;
  final double stake;
  final double payout;
  final bool didWin;

  @override
  Widget build(BuildContext context) {
    final accent = game.accent;
    final multiplierText = outcome.multiplier % 1 == 0
        ? outcome.multiplier.toStringAsFixed(0)
        : outcome.multiplier.toStringAsFixed(2);

    return AlertDialog(
      backgroundColor: const Color(0xFF131A2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        outcome.label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${multiplierText}x multiplier',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            didWin
                ? 'Payout ${_formatCurrency(payout)} on stake ${_formatCurrency(stake)}.'
                : 'No payout on this spin.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            outcome.detail,
            style: const TextStyle(
              color: Colors.white54,
              height: 1.3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: accent),
          child: const Text('Collect'),
        ),
      ],
    );
  }
}

class _DiceRushGameScreen extends StatefulWidget {
  const _DiceRushGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_DiceRushGameScreen> createState() => _DiceRushGameScreenState();
}

class _DiceRushGameScreenState extends State<_DiceRushGameScreen> {
  final Random _random = Random();
  late final List<int> _secretCode;
  final TextEditingController _controller = TextEditingController();
  final List<_CodeBreakerAttempt> _attempts = [];
  int _attemptsRemaining = 6;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _secretCode = List<int>.generate(3, (_) => _random.nextInt(10));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitGuess() {
    if (_finished) return;
    final guess = _controller.text.trim();
    if (!RegExp(r'^\d{3}$').hasMatch(guess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a three-digit code (000-999).')),
      );
      return;
    }

    final digits = guess.split('').map(int.parse).toList(growable: false);
    final hints = <String>[];
    var exactMatches = 0;
    for (var i = 0; i < digits.length; i++) {
      final codeDigit = _secretCode[i];
      final guessDigit = digits[i];
      if (guessDigit == codeDigit) {
        exactMatches++;
        hints.add('Digit ${i + 1}: LOCKED');
      } else if (guessDigit < codeDigit) {
        hints.add('Digit ${i + 1}: Higher');
      } else {
        hints.add('Digit ${i + 1}: Lower');
      }
    }

    setState(() {
      _attempts.add(
        _CodeBreakerAttempt(
          guess: guess,
          hints: hints,
          success: exactMatches == _secretCode.length,
        ),
      );
      _attemptsRemaining--;
    });

    _controller.clear();

    if (exactMatches == _secretCode.length) {
      _finishGame(success: true);
    } else if (_attemptsRemaining <= 0) {
      _finishGame(success: false);
    }
  }

  void _finishGame({required bool success}) {
    if (_finished) return;
    _finished = true;
    final payout = success ? widget.stake * 6.0 : 0.0;
    final attemptSummary =
        _attempts.map((a) => '${a.guess} [${a.hints.join(', ')}]').join(' • ');
    final detail = success
        ? 'Code cracked in ${_attempts.length} attempts. Vault ${_secretCode.join()} pays 6.0x.'
        : 'All attempts used. Vault code was ${_secretCode.join()}. Attempts: $attemptSummary';

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: success,
        detail: detail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSurface(
              blur: 16,
              elevation: 8,
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withAlpha((0.06 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CODEBREAKER HEIST',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crack the three-digit vault. You have $_attemptsRemaining attempts left.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      enabled: !_finished,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, letterSpacing: 6),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Enter code',
                        hintStyle: TextStyle(
                            color: Colors.white.withAlpha((0.4 * 255).round())),
                        filled: true,
                        fillColor: Colors.white.withAlpha((0.05 * 255).round()),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                                color: Colors.white
                                    .withAlpha((0.24 * 255).round()))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: widget.game.accent)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _attemptsRemaining > 0 && !_finished
                          ? _submitGuess
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.game.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Test combination'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.05 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withAlpha((0.14 * 255).round())),
                ),
                child: _attempts.isEmpty
                    ? const Center(
                        child: Text(
                          'No attempts yet. Start cracking!',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        itemBuilder: (context, index) {
                          final attempt = _attempts[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: attempt.success
                                  ? widget.game.accent
                                      .withAlpha((0.35 * 255).round())
                                  : Colors.white
                                      .withAlpha((0.05 * 255).round()),
                              border: Border.all(
                                  color: Colors.white
                                      .withAlpha((0.14 * 255).round())),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attempt ${index + 1}: ${attempt.guess}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                ...attempt.hints.map(
                                  (hint) => Text(hint,
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                ),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: _attempts.length,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                if (_finished) {
                  Navigator.of(context).pop();
                } else {
                  _finishGame(success: false);
                }
              },
              child: const Text('Abort mission'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBreakerAttempt {
  const _CodeBreakerAttempt(
      {required this.guess, required this.hints, required this.success});

  final String guess;
  final List<String> hints;
  final bool success;
}

class _TreasureFlipGameScreen extends StatefulWidget {
  const _TreasureFlipGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_TreasureFlipGameScreen> createState() =>
      _TreasureFlipGameScreenState();
}

class _TreasureFlipGameScreenState extends State<_TreasureFlipGameScreen> {
  final Random _random = Random();
  static const List<_TreasureChest> _chests = <_TreasureChest>[
    _TreasureChest(label: 'Emerald Cache', minTotal: 7, maxTotal: 9),
    _TreasureChest(label: 'Sapphire Vault', minTotal: 8, maxTotal: 10),
    _TreasureChest(label: 'Crimson Hoard', minTotal: 9, maxTotal: 11),
  ];
  static const int _maxRolls = 9;

  final List<_TreasureRollRecord> _history = <_TreasureRollRecord>[];
  int _currentChest = 0;
  int _rollsRemaining = _maxRolls;
  bool _finished = false;
  bool _rolling = false;

  void _rollForChest() {
    if (_rolling || _finished) return;
    if (_currentChest >= _chests.length || _rollsRemaining <= 0) return;

    setState(() {
      _rolling = true;
      _rollsRemaining--;
    });

    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted || _finished) {
        setState(() => _rolling = false);
        return;
      }
      final dice = _rollDicePair();
      final total = dice[0] + dice[1];
      final chest = _chests[_currentChest];
      final success = total >= chest.minTotal && total <= chest.maxTotal;
      setState(() {
        _history.add(
          _TreasureRollRecord(
            chestIndex: _currentChest,
            diceValues: dice,
            total: total,
            success: success,
          ),
        );
        if (success) {
          _currentChest++;
          if (_currentChest >= _chests.length) {
            _finish(success: true);
          }
        } else if (_rollsRemaining <= 0) {
          _finish(success: false);
        }
        _rolling = false;
      });
    });
  }

  void _finish({required bool success, bool aborted = false}) {
    if (_finished) return;
    _finished = true;
    final detailSummary = _history
        .map(
          (record) =>
              'C${record.chestIndex + 1}:${record.total}${record.success ? '(hit)' : '(miss)'}',
        )
        .join(' | ');
    final prefix = aborted
        ? 'Explorer retreated with $_currentChest chests opened. '
        : (success
            ? 'All treasure chests unlocked! '
            : 'Expedition failed before all chests were opened. ');
    final detail =
        prefix + (detailSummary.isEmpty ? 'No rolls recorded.' : detailSummary);
    final payout = success ? widget.stake * 4.5 : 0.0;

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: success,
        detail: detail,
      ),
    );
  }

  List<int> _rollDicePair() =>
      <int>[_random.nextInt(6) + 1, _random.nextInt(6) + 1];

  @override
  Widget build(BuildContext context) {
    final currentLabel = _currentChest < _chests.length
        ? _chests[_currentChest].label
        : 'Complete';
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSurface(
              blur: 16,
              elevation: 8,
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withAlpha((0.06 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TREASURE ROLL EXPEDITION',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hit each target range to unlock the chest. Rolls remaining: $_rollsRemaining',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Active chest: $currentLabel',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withAlpha((0.05 * 255).round()),
                border: Border.all(
                    color: Colors.white.withAlpha((0.14 * 255).round())),
              ),
              child: Column(
                children: _chests.asMap().entries.map((entry) {
                  final index = entry.key;
                  final chest = entry.value;
                  final status = index < _currentChest
                      ? 'Unlocked'
                      : (index == _currentChest ? 'In play' : 'Locked');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: index < _currentChest
                          ? widget.game.accent.withAlpha((0.28 * 255).round())
                          : Colors.white.withAlpha((0.04 * 255).round()),
                      border: Border.all(
                          color: Colors.white.withAlpha((0.14 * 255).round())),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chest.label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Target: ${chest.minTotal}-${chest.maxTotal}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          status,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _history.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withAlpha((0.04 * 255).round()),
                        border: Border.all(
                            color:
                                Colors.white.withAlpha((0.12 * 255).round())),
                      ),
                      child: const Center(
                        child: Text('No dice rolls logged yet.',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = _history[index];
                        final chest = _chests[record.chestIndex];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: record.success
                                ? widget.game.accent
                                    .withAlpha((0.26 * 255).round())
                                : Colors.white.withAlpha((0.05 * 255).round()),
                            border: Border.all(
                                color: Colors.white
                                    .withAlpha((0.14 * 255).round())),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${chest.label} → ${record.total} (dice ${record.diceValues[0]} + ${record.diceValues[1]})',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.success
                                    ? 'Hit the range and unlocked the chest.'
                                    : 'Missed the ${chest.minTotal}-${chest.maxTotal} window.',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: (!_finished &&
                      _currentChest < _chests.length &&
                      _rollsRemaining > 0 &&
                      !_rolling)
                  ? _rollForChest
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.game.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(_rolling ? 'Rolling...' : 'Roll for treasure'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _finished
                  ? () => Navigator.of(context).pop()
                  : () => _finish(success: false, aborted: true),
              child: Text(_finished ? 'Close' : 'Retreat expedition'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreasureChest {
  const _TreasureChest(
      {required this.label, required this.minTotal, required this.maxTotal});

  final String label;
  final int minTotal;
  final int maxTotal;
}

class _TreasureRollRecord {
  _TreasureRollRecord({
    required this.chestIndex,
    required List<int> diceValues,
    required this.total,
    required this.success,
  }) : diceValues = List<int>.unmodifiable(diceValues);

  final int chestIndex;
  final List<int> diceValues;
  final int total;
  final bool success;
}

class _NeonVaultGameScreen extends StatefulWidget {
  const _NeonVaultGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_NeonVaultGameScreen> createState() => _NeonVaultGameScreenState();
}

class _NeonVaultGameScreenState extends State<_NeonVaultGameScreen> {
  final Random _random = Random();
  static const List<_VaultLock> _locks = <_VaultLock>[
    _VaultLock(label: 'Alpha Lock', target: 8),
    _VaultLock(label: 'Beta Lock', target: 9),
    _VaultLock(label: 'Gamma Lock', target: 10),
    _VaultLock(label: 'Delta Lock', target: 11),
    _VaultLock(label: 'Omega Lock', target: 12),
  ];
  static const int _attemptsPerLock = 3;

  final List<_VaultRollRecord> _history = <_VaultRollRecord>[];
  int _currentLock = 0;
  int _attemptsLeft = _attemptsPerLock;
  bool _rolling = false;
  bool _finished = false;

  void _rollLock() {
    if (_rolling || _finished || _currentLock >= _locks.length) return;

    setState(() => _rolling = true);

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || _finished) {
        if (mounted) setState(() => _rolling = false);
        return;
      }
      final dice = _rollDicePair();
      final total = dice[0] + dice[1];
      final attemptNumber = _attemptsPerLock - _attemptsLeft + 1;
      final lock = _locks[_currentLock];
      final success = total >= lock.target;

      setState(() {
        _history.add(
          _VaultRollRecord(
            lockIndex: _currentLock,
            attemptNumber: attemptNumber,
            diceValues: dice,
            total: total,
            success: success,
          ),
        );
        if (success) {
          _currentLock++;
          _attemptsLeft = _attemptsPerLock;
        } else {
          _attemptsLeft--;
        }
        _rolling = false;
      });

      if (success && _currentLock >= _locks.length) {
        _finish(success: true);
      } else if (!success && _attemptsLeft <= 0) {
        _finish(success: false);
      }
    });
  }

  void _finish({required bool success, bool aborted = false}) {
    if (_finished) return;
    _finished = true;
    final history = _history
        .map(
          (record) =>
              'L${record.lockIndex + 1}#${record.attemptNumber}:${record.total}${record.success ? '(pass)' : '(fail)'}',
        )
        .join(' | ');
    final prefix = aborted
        ? 'Vault run aborted at lock ${_currentLock + 1}. '
        : (success
            ? 'All locks broken. '
            : 'Vault sealed before the last lock. ');
    final detail =
        prefix + (history.isEmpty ? 'No attempts recorded.' : history);
    final payout = success ? widget.stake * 5.0 : 0.0;

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: success,
        detail: detail,
      ),
    );
  }

  List<int> _rollDicePair() =>
      <int>[_random.nextInt(6) + 1, _random.nextInt(6) + 1];

  @override
  Widget build(BuildContext context) {
    final attemptsLabel = _currentLock >= _locks.length
        ? 'Complete'
        : 'Attempts left: $_attemptsLeft';
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSurface(
              blur: 16,
              elevation: 8,
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withAlpha((0.06 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEON VAULT DICE RUN',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Beat the target on each lock before attempts run out. $attemptsLabel',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lock ${_currentLock + 1}/${_locks.length}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withAlpha((0.05 * 255).round()),
                border: Border.all(
                    color: Colors.white.withAlpha((0.14 * 255).round())),
              ),
              child: Column(
                children: _locks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final lock = entry.value;
                  final status = index < _currentLock
                      ? 'Cracked'
                      : (index == _currentLock ? 'Active' : 'Pending');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: index < _currentLock
                          ? widget.game.accent.withAlpha((0.28 * 255).round())
                          : Colors.white.withAlpha((0.04 * 255).round()),
                      border: Border.all(
                          color: Colors.white.withAlpha((0.14 * 255).round())),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lock.label,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Target total ≥ ${lock.target}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(status,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _history.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withAlpha((0.04 * 255).round()),
                        border: Border.all(
                            color:
                                Colors.white.withAlpha((0.12 * 255).round())),
                      ),
                      child: const Center(
                        child: Text('No dice rolls logged yet.',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = _history[index];
                        final lock = _locks[record.lockIndex];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: record.success
                                ? widget.game.accent
                                    .withAlpha((0.26 * 255).round())
                                : Colors.white.withAlpha((0.05 * 255).round()),
                            border: Border.all(
                                color: Colors.white
                                    .withAlpha((0.14 * 255).round())),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${lock.label} attempt ${record.attemptNumber}: ${record.total} (dice ${record.diceValues[0]} + ${record.diceValues[1]})',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.success
                                    ? 'Lock opened.'
                                    : 'Needed ${lock.target} or higher.',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed:
                  (!_finished && _currentLock < _locks.length && !_rolling)
                      ? _rollLock
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.game.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(_rolling ? 'Rolling...' : 'Roll vault dice'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _finished
                  ? () => Navigator.of(context).pop()
                  : () => _finish(success: false, aborted: true),
              child: Text(_finished ? 'Close' : 'Abort run'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultLock {
  const _VaultLock({required this.label, required this.target});

  final String label;
  final int target;
}

class _VaultRollRecord {
  _VaultRollRecord({
    required this.lockIndex,
    required this.attemptNumber,
    required List<int> diceValues,
    required this.total,
    required this.success,
  }) : diceValues = List<int>.unmodifiable(diceValues);

  final int lockIndex;
  final int attemptNumber;
  final List<int> diceValues;
  final int total;
  final bool success;
}

class _InfernoLadderGameScreen extends StatefulWidget {
  const _InfernoLadderGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_InfernoLadderGameScreen> createState() =>
      _InfernoLadderGameScreenState();
}

class _InfernoLadderGameScreenState extends State<_InfernoLadderGameScreen> {
  final Random _random = Random();
  static const List<_LadderStage> _stages = <_LadderStage>[
    _LadderStage(label: 'Ember Step', target: 7, multiplier: 1.6),
    _LadderStage(label: 'Flare Step', target: 8, multiplier: 2.3),
    _LadderStage(label: 'Blaze Step', target: 9, multiplier: 3.2),
    _LadderStage(label: 'Inferno Rise', target: 10, multiplier: 4.5),
    _LadderStage(label: 'Molten Apex', target: 11, multiplier: 6.5),
  ];

  final List<_LadderRollRecord> _history = <_LadderRollRecord>[];
  int _clearedStages = 0;
  bool _rolling = false;
  bool _finished = false;

  double get _currentMultiplier =>
      _clearedStages == 0 ? 1.0 : _stages[_clearedStages - 1].multiplier;

  void _rollNextStage() {
    if (_rolling || _finished || _clearedStages >= _stages.length) return;

    setState(() => _rolling = true);

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || _finished) {
        if (mounted) setState(() => _rolling = false);
        return;
      }
      final dice = _rollDicePair();
      final total = dice[0] + dice[1];
      final stageIndex = _clearedStages;
      final stage = _stages[stageIndex];
      final success = total >= stage.target;

      setState(() {
        _history.add(
          _LadderRollRecord(
            stageIndex: stageIndex,
            diceValues: dice,
            total: total,
            success: success,
          ),
        );
        if (success) {
          _clearedStages++;
        }
        _rolling = false;
      });

      if (success) {
        if (_clearedStages >= _stages.length) {
          _finish(success: true);
        }
      } else {
        _finish(success: false);
      }
    });
  }

  void _bankWinnings() {
    if (_finished || _clearedStages == 0) return;
    final multiplier = _currentMultiplier;
    _finish(success: true, banked: true, bankedMultiplier: multiplier);
  }

  void _finish(
      {required bool success,
      bool banked = false,
      bool aborted = false,
      double? bankedMultiplier}) {
    if (_finished) return;
    _finished = true;
    final summary = _history
        .map((record) =>
            'S${record.stageIndex + 1}:${record.total}${record.success ? '(pass)' : '(fail)'}')
        .join(' | ');
    String prefix;
    if (aborted) {
      prefix = 'Player retreated before the flames. ';
    } else if (banked) {
      prefix = 'Player banked after stage $_clearedStages. ';
    } else if (success) {
      prefix = 'All ladder stages cleared. ';
    } else {
      prefix = 'Heat collapse ended the climb. ';
    }
    final detail =
        prefix + (summary.isEmpty ? 'No ladder rolls recorded.' : summary);
    final multiplier = success ? (bankedMultiplier ?? _currentMultiplier) : 0.0;
    final payout = success ? widget.stake * multiplier : 0.0;

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: success,
        detail: detail,
      ),
    );
  }

  List<int> _rollDicePair() =>
      <int>[_random.nextInt(6) + 1, _random.nextInt(6) + 1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSurface(
              blur: 14,
              elevation: 8,
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withAlpha((0.05 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INFERNO DICE LADDER',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Clear each fiery rung by rolling above the threshold. Bank or push your luck.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Cleared stages: $_clearedStages/${_stages.length}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Current multiplier: ${_currentMultiplier.toStringAsFixed(1)}x',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withAlpha((0.05 * 255).round()),
                border: Border.all(
                    color: Colors.white.withAlpha((0.14 * 255).round())),
              ),
              child: Column(
                children: _stages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stage = entry.value;
                  String status;
                  if (index < _clearedStages) {
                    status = 'Cleared';
                  } else if (index == _clearedStages && !_finished) {
                    status = 'Current';
                  } else {
                    status = 'Ahead';
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: index < _clearedStages
                          ? widget.game.accent.withAlpha((0.28 * 255).round())
                          : Colors.white.withAlpha((0.04 * 255).round()),
                      border: Border.all(
                          color: Colors.white.withAlpha((0.14 * 255).round())),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stage.label,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                  'Need total ≥ ${stage.target} • ${stage.multiplier.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(status,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _history.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withAlpha((0.04 * 255).round()),
                        border: Border.all(
                            color:
                                Colors.white.withAlpha((0.12 * 255).round())),
                      ),
                      child: const Center(
                        child: Text('No ladder rolls yet.',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = _history[index];
                        final stage = _stages[record.stageIndex];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: record.success
                                ? widget.game.accent
                                    .withAlpha((0.26 * 255).round())
                                : Colors.white.withAlpha((0.05 * 255).round()),
                            border: Border.all(
                                color: Colors.white
                                    .withAlpha((0.14 * 255).round())),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${stage.label}: ${record.total} (dice ${record.diceValues[0]} + ${record.diceValues[1]})',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.success
                                    ? 'Stage cleared.'
                                    : 'Needed ${stage.target} or higher.',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed:
                  (!_finished && _clearedStages < _stages.length && !_rolling)
                      ? _rollNextStage
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.game.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(_rolling ? 'Rolling...' : 'Roll ladder dice'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed:
                  (!_finished && _clearedStages > 0) ? _bankWinnings : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                    color: Colors.white.withAlpha((0.28 * 255).round())),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text('Bank ${_currentMultiplier.toStringAsFixed(1)}x'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _finished
                  ? () => Navigator.of(context).pop()
                  : () => _finish(success: false, aborted: true),
              child: Text(_finished ? 'Close' : 'Retreat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LadderStage {
  const _LadderStage(
      {required this.label, required this.target, required this.multiplier});

  final String label;
  final int target;
  final double multiplier;
}

class _LadderRollRecord {
  _LadderRollRecord({
    required this.stageIndex,
    required List<int> diceValues,
    required this.total,
    required this.success,
  }) : diceValues = List<int>.unmodifiable(diceValues);

  final int stageIndex;
  final List<int> diceValues;
  final int total;
  final bool success;
}

class _RouletteCascadeGameScreen extends StatefulWidget {
  const _RouletteCascadeGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_RouletteCascadeGameScreen> createState() =>
      _RouletteCascadeGameScreenState();
}

class _RouletteCascadeGameScreenState
    extends State<_RouletteCascadeGameScreen> {
  final Random _random = Random();
  static const List<_CascadeStage> _stages = <_CascadeStage>[
    _CascadeStage(
      label: 'Flux Entry',
      description: 'Roll a total between 9 and 13 inclusive.',
      check: _CascadeCheck.totalBand,
    ),
    _CascadeStage(
      label: 'Twin Pulse',
      description: 'Roll at least one matching pair across the three dice.',
      check: _CascadeCheck.pair,
    ),
    _CascadeStage(
      label: 'Harmonic Apex',
      description: 'Roll a total divisible by 3 and at least 12.',
      check: _CascadeCheck.harmonic,
    ),
  ];

  final List<_CascadeRollRecord> _history = <_CascadeRollRecord>[];
  int _stageIndex = 0;
  bool _rolling = false;
  bool _finished = false;

  void _rollCascade() {
    if (_rolling || _finished || _stageIndex >= _stages.length) return;

    setState(() => _rolling = true);

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || _finished) {
        if (mounted) setState(() => _rolling = false);
        return;
      }
      final dice = _rollDiceTriplet();
      final total = dice[0] + dice[1] + dice[2];
      final stage = _stages[_stageIndex];
      final success = _meetsRequirement(stage, dice);

      setState(() {
        _history.add(
          _CascadeRollRecord(
            stageIndex: _stageIndex,
            diceValues: dice,
            total: total,
            success: success,
          ),
        );
        if (success) {
          _stageIndex++;
        }
        _rolling = false;
      });

      if (success) {
        if (_stageIndex >= _stages.length) {
          _finish(success: true);
        }
      } else {
        _finish(success: false);
      }
    });
  }

  void _finish({required bool success, bool aborted = false}) {
    if (_finished) return;
    _finished = true;
    final summary = _history
        .map((record) =>
            'S${record.stageIndex + 1}:${record.total}${record.success ? '(pass)' : '(fail)'}')
        .join(' | ');
    final prefix = aborted
        ? 'Trials aborted at stage ${_stageIndex + 1}. '
        : (success
            ? 'Cascade trials cleared. '
            : 'Cascade failed in the flux. ');
    final detail =
        prefix + (summary.isEmpty ? 'No cascade rolls recorded.' : summary);
    final payout = success ? widget.stake * 7.0 : 0.0;

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: success,
        detail: detail,
      ),
    );
  }

  bool _meetsRequirement(_CascadeStage stage, List<int> dice) {
    final total = dice[0] + dice[1] + dice[2];
    switch (stage.check) {
      case _CascadeCheck.totalBand:
        return total >= 9 && total <= 13;
      case _CascadeCheck.pair:
        return dice.toSet().length <= 2;
      case _CascadeCheck.harmonic:
        return total % 3 == 0 && total >= 12;
    }
  }

  List<int> _rollDiceTriplet() =>
      List<int>.generate(3, (_) => _random.nextInt(6) + 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSurface(
              blur: 16,
              elevation: 8,
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withAlpha((0.05 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CASCADE ROLL TRIALS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Meet each roll requirement consecutively. Stage ${_stageIndex + 1}/${_stages.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withAlpha((0.05 * 255).round()),
                border: Border.all(
                    color: Colors.white.withAlpha((0.14 * 255).round())),
              ),
              child: Column(
                children: _stages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stage = entry.value;
                  String status;
                  if (index < _stageIndex) {
                    status = 'Complete';
                  } else if (index == _stageIndex && !_finished) {
                    status = 'Active';
                  } else {
                    status = 'Ahead';
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: index < _stageIndex
                          ? widget.game.accent.withAlpha((0.28 * 255).round())
                          : Colors.white.withAlpha((0.04 * 255).round()),
                      border: Border.all(
                          color: Colors.white.withAlpha((0.14 * 255).round())),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stage.label,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(stage.description,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(status,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _history.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withAlpha((0.04 * 255).round()),
                        border: Border.all(
                            color:
                                Colors.white.withAlpha((0.12 * 255).round())),
                      ),
                      child: const Center(
                        child: Text('Waiting for first cascade roll.',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = _history[index];
                        final stage = _stages[record.stageIndex];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: record.success
                                ? widget.game.accent
                                    .withAlpha((0.26 * 255).round())
                                : Colors.white.withAlpha((0.05 * 255).round()),
                            border: Border.all(
                                color: Colors.white
                                    .withAlpha((0.14 * 255).round())),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${stage.label}: roll ${record.diceValues[0]}-${record.diceValues[1]}-${record.diceValues[2]} (total ${record.total})',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.success
                                    ? 'Requirement met.'
                                    : 'Requirement missed.',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed:
                  (!_finished && _stageIndex < _stages.length && !_rolling)
                      ? _rollCascade
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.game.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(_rolling ? 'Rolling...' : 'Roll cascade dice'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _finished
                  ? () => Navigator.of(context).pop()
                  : () => _finish(success: false, aborted: true),
              child: Text(_finished ? 'Close' : 'Abort trials'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CascadeCheck {
  totalBand,
  pair,
  harmonic,
}

class _CascadeStage {
  const _CascadeStage(
      {required this.label, required this.description, required this.check});

  final String label;
  final String description;
  final _CascadeCheck check;
}

class _CascadeRollRecord {
  _CascadeRollRecord({
    required this.stageIndex,
    required List<int> diceValues,
    required this.total,
    required this.success,
  }) : diceValues = List<int>.unmodifiable(diceValues);

  final int stageIndex;
  final List<int> diceValues;
  final int total;
  final bool success;
}

// A minimal proxy that hosts an external game screen and maps its result
// Removed proxy wrappers to keep the original in-file game screen structure

class _WheelGameScreen extends StatefulWidget {
  const _WheelGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_WheelGameScreen> createState() => _WheelGameScreenState();
}

class _WheelGameScreenState extends State<_WheelGameScreen> {
  final List<_WheelSegment> _segments = const [
    _WheelSegment(label: 'Miss', multiplier: 0, color: Color(0xFF37474F)),
    _WheelSegment(label: '1.2x', multiplier: 1.2, color: Color(0xFF42A5F5)),
    _WheelSegment(label: '1.6x', multiplier: 1.6, color: Color(0xFF26A69A)),
    _WheelSegment(label: '2.4x', multiplier: 2.4, color: Color(0xFFFFCA28)),
    _WheelSegment(label: '3.2x', multiplier: 3.2, color: Color(0xFFAB47BC)),
    _WheelSegment(label: '4.0x', multiplier: 4.0, color: Color(0xFFEF5350)),
    _WheelSegment(label: '1.8x', multiplier: 1.8, color: Color(0xFF66BB6A)),
    _WheelSegment(label: '2.8x', multiplier: 2.8, color: Color(0xFF7E57C2)),
  ];

  final Random _random = Random();
  final BettingDataStore _store = BettingDataStore.instance;
  bool _isSpinning = false;
  int _currentIndex = 0;
  int? _resultIndex;

  Future<void> _spinWheel() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _resultIndex = null;
    });

    // Use weighted random selection from admin-configured settings
    final selectedConfig = _store.selectWeightedWheelSegment();

    // Find the matching segment index by label
    final targetIndex =
        _segments.indexWhere((seg) => seg.label == selectedConfig.label);
    final finalTarget =
        targetIndex >= 0 ? targetIndex : _random.nextInt(_segments.length);

    final totalCycles =
        _segments.length * (6 + _random.nextInt(5)) + finalTarget;

    var index = _currentIndex;
    for (var step = 0; step <= totalCycles; step++) {
      final delay =
          Duration(milliseconds: 70 + (step ~/ _segments.length) * 12);
      await Future.delayed(delay);
      if (!mounted) return;
      index = (index + 1) % _segments.length;
      setState(() => _currentIndex = index);
    }

    if (!mounted) return;
    setState(() {
      _isSpinning = false;
      _resultIndex = _currentIndex;
    });
  }

  void _finishGame() {
    if (_resultIndex == null) return;
    final segment = _segments[_resultIndex!];
    final multiplier = segment.multiplier;
    final payout = multiplier > 0 ? widget.stake * multiplier : 0.0;
    final didWin = payout > 0;
    final detail = didWin
        ? 'Wheel landed on ${multiplier.toStringAsFixed(multiplier.truncateToDouble() == multiplier ? 0 : 1)}x.'
        : 'Wheel missed all multipliers.';

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: didWin,
        detail: detail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white.withAlpha((0.08 * 255).round()),
                border: Border.all(
                    color: Colors.white.withAlpha((0.18 * 255).round())),
              ),
              child: Column(
                children: [
                  Text(
                    _segments[_currentIndex].label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSpinning
                        ? 'Spinning...'
                        : (_resultIndex != null
                            ? 'Tap collect to settle this spin.'
                            : 'Tap spin to test your luck.'),
                    style: const TextStyle(color: Color(0xFFAEC0D6)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _segments.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.8,
                ),
                itemBuilder: (context, index) {
                  final segment = _segments[index];
                  final isActive = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: segment.color
                          .withAlpha(((isActive ? 0.45 : 0.18) * 255).round()),
                      border: Border.all(
                        color: Colors.white.withAlpha(
                            ((isActive ? 0.38 : 0.12) * 255).round()),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          segment.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isActive ? 18 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          segment.multiplier == 0
                              ? 'No payout'
                              : '${segment.multiplier.toStringAsFixed(segment.multiplier.truncateToDouble() == segment.multiplier ? 0 : 1)}x returns',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.game.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isSpinning ? null : _spinWheel,
                    child: Text(_isSpinning ? 'Spinning...' : 'Spin the wheel'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withAlpha((0.28 * 255).round())),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _resultIndex != null && !_isSpinning
                        ? _finishGame
                        : null,
                    child: const Text('Collect result'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSpinning ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// NEW GAME SCREENS: Lucky Slots, Prize Box, Color Spinner

class _SlotTheme {
  const _SlotTheme({
    required this.instructions,
    required this.symbols,
  });

  final String instructions;
  final List<SlotSymbolConfig> symbols;
}

final Map<GameType, _SlotTheme> _slotThemes = {
  GameType.moneyMania: _SlotTheme(
    instructions:
        'Stack cash icons across five paylines. Triple JACK vaults award the progressive.',
    symbols: [
      SlotSymbolConfig(
        id: 'mm_jackpot',
        symbol: 'JACK',
        label: 'Jackpot Vault',
        multiplier: 15.0,
        color: Color(0xFFFFD740),
        weight: 5.0,
        isProgressive: true,
      ),
      SlotSymbolConfig(
        id: 'mm_seven',
        symbol: '777',
        label: 'Lucky Sevens',
        multiplier: 8.0,
        color: Color(0xFFFF5252),
        weight: 10.0,
      ),
      SlotSymbolConfig(
        id: 'mm_gold',
        symbol: 'GOLD',
        label: 'Gold Bars',
        multiplier: 6.0,
        color: Color(0xFFFFB300),
        weight: 12.0,
      ),
      SlotSymbolConfig(
        id: 'mm_cash',
        symbol: 'CASH',
        label: 'Cash Stack',
        multiplier: 4.0,
        color: Color(0xFF00C853),
        weight: 16.0,
      ),
      SlotSymbolConfig(
        id: 'mm_chip',
        symbol: 'CHIP',
        label: 'High Roller Chip',
        multiplier: 3.0,
        color: Color(0xFF00ACC1),
        weight: 20.0,
      ),
      SlotSymbolConfig(
        id: 'mm_bar',
        symbol: 'BAR',
        label: 'Triple Bar',
        multiplier: 2.0,
        color: Color(0xFFBDBDBD),
        weight: 24.0,
      ),
    ],
  ),
  GameType.magicTreasure: _SlotTheme(
    instructions:
        'Reveal enchanted relics to charge the Magic Treasure pot. Three ORB symbols unleash it.',
    symbols: [
      SlotSymbolConfig(
        id: 'mt_orb',
        symbol: 'ORB',
        label: 'Arcane Orb',
        multiplier: 14.0,
        color: Color(0xFFAB47BC),
        weight: 6.0,
        isProgressive: true,
      ),
      SlotSymbolConfig(
        id: 'mt_crown',
        symbol: 'CRWN',
        label: 'Royal Crown',
        multiplier: 7.5,
        color: Color(0xFFFFD740),
        weight: 12.0,
      ),
      SlotSymbolConfig(
        id: 'mt_gem',
        symbol: 'GEM',
        label: 'Mystic Gem',
        multiplier: 5.0,
        color: Color(0xFF7E57C2),
        weight: 16.0,
      ),
      SlotSymbolConfig(
        id: 'mt_scroll',
        symbol: 'SCRL',
        label: 'Ancient Scroll',
        multiplier: 3.5,
        color: Color(0xFF26C6DA),
        weight: 18.0,
      ),
      SlotSymbolConfig(
        id: 'mt_ring',
        symbol: 'RING',
        label: 'Enchanted Ring',
        multiplier: 3.0,
        color: Color(0xFFE1BEE7),
        weight: 20.0,
      ),
      SlotSymbolConfig(
        id: 'mt_potion',
        symbol: 'ELIX',
        label: 'Elixir Bottle',
        multiplier: 2.0,
        color: Color(0xFF80CBC4),
        weight: 28.0,
      ),
    ],
  ),
  GameType.lgtJackpot: _SlotTheme(
    instructions:
        'Level up the LGT Diamond cabinet. Triple LGT logos strike the house jackpot.',
    symbols: [
      SlotSymbolConfig(
        id: 'lgt_logo',
        symbol: 'LGT',
        label: 'LGT Logo',
        multiplier: 16.0,
        color: Color(0xFF00B8D4),
        weight: 5.0,
        isProgressive: true,
      ),
      SlotSymbolConfig(
        id: 'lgt_dmd',
        symbol: 'DMD',
        label: 'Diamond Cluster',
        multiplier: 9.0,
        color: Color(0xFF4DD0E1),
        weight: 10.0,
      ),
      SlotSymbolConfig(
        id: 'lgt_star',
        symbol: 'STAR',
        label: 'Neon Star',
        multiplier: 6.0,
        color: Color(0xFF1DE9B6),
        weight: 14.0,
      ),
      SlotSymbolConfig(
        id: 'lgt_chip',
        symbol: 'VIP',
        label: 'VIP Chip',
        multiplier: 4.0,
        color: Color(0xFF00ACC1),
        weight: 18.0,
      ),
      SlotSymbolConfig(
        id: 'lgt_bar',
        symbol: 'BAR',
        label: 'Neon Bar',
        multiplier: 2.5,
        color: Color(0xFF80DEEA),
        weight: 22.0,
      ),
      SlotSymbolConfig(
        id: 'lgt_chip_low',
        symbol: 'MINI',
        label: 'Mini Chip',
        multiplier: 1.8,
        color: Color(0xFFB2EBF2),
        weight: 32.0,
      ),
    ],
  ),
  GameType.jackpotInferno: _SlotTheme(
    instructions:
        'Ride the flames. Triple BLAZ icons light the Inferno Jackpot instantly.',
    symbols: [
      SlotSymbolConfig(
        id: 'ji_blaze',
        symbol: 'BLAZ',
        label: 'Blaze Wild',
        multiplier: 13.0,
        color: Color(0xFFFF7043),
        weight: 6.0,
        isProgressive: true,
      ),
      SlotSymbolConfig(
        id: 'ji_flare',
        symbol: 'FLAR',
        label: 'Flare Burst',
        multiplier: 7.0,
        color: Color(0xFFFF8A65),
        weight: 12.0,
      ),
      SlotSymbolConfig(
        id: 'ji_heat',
        symbol: 'HEAT',
        label: 'Heat Wave',
        multiplier: 5.0,
        color: Color(0xFFF06292),
        weight: 16.0,
      ),
      SlotSymbolConfig(
        id: 'ji_coal',
        symbol: 'CHAR',
        label: 'Charcoal Ember',
        multiplier: 3.2,
        color: Color(0xFF8D6E63),
        weight: 20.0,
      ),
      SlotSymbolConfig(
        id: 'ji_spark',
        symbol: 'SPRK',
        label: 'Spark',
        multiplier: 2.2,
        color: Color(0xFFFFAB91),
        weight: 22.0,
      ),
      SlotSymbolConfig(
        id: 'ji_ash',
        symbol: 'ASH',
        label: 'Ash Chip',
        multiplier: 1.6,
        color: Color(0xFFD7CCC8),
        weight: 32.0,
      ),
    ],
  ),
  GameType.fortuneWheel: _SlotTheme(
    instructions:
        'Hit wheel emblems across paylines. Triple CROWN symbols trigger Fortune Wheel Royale.',
    symbols: [
      SlotSymbolConfig(
        id: 'fw_crown',
        symbol: 'CRWN',
        label: 'Royal Crown',
        multiplier: 12.0,
        color: Color(0xFFFFC107),
        weight: 6.0,
        isProgressive: true,
      ),
      SlotSymbolConfig(
        id: 'fw_spin',
        symbol: 'SPIN',
        label: 'Wheel Spin',
        multiplier: 7.0,
        color: Color(0xFFFFE082),
        weight: 12.0,
      ),
      SlotSymbolConfig(
        id: 'fw_star',
        symbol: 'STAR',
        label: 'Star Bonus',
        multiplier: 5.5,
        color: Color(0xFFFFF59D),
        weight: 16.0,
      ),
      SlotSymbolConfig(
        id: 'fw_wild',
        symbol: 'WILD',
        label: 'Wheel Wild',
        multiplier: 4.0,
        color: Color(0xFFFFD54F),
        weight: 18.0,
      ),
      SlotSymbolConfig(
        id: 'fw_chip',
        symbol: 'CHIP',
        label: 'Casino Chip',
        multiplier: 2.5,
        color: Color(0xFFFFECB3),
        weight: 22.0,
      ),
      SlotSymbolConfig(
        id: 'fw_bar',
        symbol: 'BAR',
        label: 'Classic Bar',
        multiplier: 1.8,
        color: Color(0xFFF5F5F5),
        weight: 30.0,
      ),
    ],
  ),
  GameType.megaRoulette: _SlotTheme(
    instructions:
        'Numbers spin like a roulette cascade. Triple ZERO locks the Mega Roulette jackpot.',
    symbols: [
      SlotSymbolConfig(
        id: 'mr_zero',
        symbol: 'ZERO',
        label: 'Zero Strike',
        multiplier: 18.0,
        color: Color(0xFF29B6F6),
        weight: 4.0,
        isProgressive: true,
      ),
      SlotSymbolConfig(
        id: 'mr_red',
        symbol: 'RED',
        label: 'Red Sector',
        multiplier: 6.5,
        color: Color(0xFFD32F2F),
        weight: 14.0,
      ),
      SlotSymbolConfig(
        id: 'mr_black',
        symbol: 'BLK',
        label: 'Black Sector',
        multiplier: 6.5,
        color: Color(0xFF000000),
        weight: 14.0,
      ),
      SlotSymbolConfig(
        id: 'mr_even',
        symbol: 'EVEN',
        label: 'Even Numbers',
        multiplier: 3.0,
        color: Color(0xFF90A4AE),
        weight: 20.0,
      ),
      SlotSymbolConfig(
        id: 'mr_odd',
        symbol: 'ODD',
        label: 'Odd Numbers',
        multiplier: 3.0,
        color: Color(0xFF546E7A),
        weight: 20.0,
      ),
      SlotSymbolConfig(
        id: 'mr_low',
        symbol: 'LOW',
        label: 'Low Tier',
        multiplier: 1.8,
        color: Color(0xFFCFD8DC),
        weight: 28.0,
      ),
    ],
  ),
};

class _LuckySlotsGameScreen extends StatefulWidget {
  const _LuckySlotsGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_LuckySlotsGameScreen> createState() => _LuckySlotsGameScreenState();
}

class _LuckySlotsGameScreenState extends State<_LuckySlotsGameScreen>
    with SingleTickerProviderStateMixin {
  late final BettingDataStore _store;
  late final AnimationController _spinController;
  late final _SlotTheme _theme;
  late final List<SlotSymbolConfig> _themeSymbols;

  List<List<SlotSymbolConfig>> _visibleGrid = <List<SlotSymbolConfig>>[];
  List<List<SlotSymbolConfig>> _targetFinalGrid = <List<SlotSymbolConfig>>[];
  Set<String> _winningCells = <String>{};
  _SpinEvaluation? _lastEvaluation;
  double _lastContribution = 0;
  late final List<Timer?> _reelTimers;
  final Random _random = Random();

  bool _spinning = false;
  bool _finished = false;

  static const List<_Payline> _paylines = <_Payline>[
    _Payline(
      name: 'Top Row',
      positions: <_GridPosition>[
        _GridPosition(0, 0),
        _GridPosition(0, 1),
        _GridPosition(0, 2),
      ],
    ),
    _Payline(
      name: 'Middle Row',
      positions: <_GridPosition>[
        _GridPosition(1, 0),
        _GridPosition(1, 1),
        _GridPosition(1, 2),
      ],
    ),
    _Payline(
      name: 'Bottom Row',
      positions: <_GridPosition>[
        _GridPosition(2, 0),
        _GridPosition(2, 1),
        _GridPosition(2, 2),
      ],
    ),
    _Payline(
      name: 'Diagonal ↘',
      positions: <_GridPosition>[
        _GridPosition(0, 0),
        _GridPosition(1, 1),
        _GridPosition(2, 2),
      ],
    ),
    _Payline(
      name: 'Diagonal ↗',
      positions: <_GridPosition>[
        _GridPosition(2, 0),
        _GridPosition(1, 1),
        _GridPosition(0, 2),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _store = BettingDataStore.instance;
    _store.addListener(_handleStoreUpdate);
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _reelTimers = List<Timer?>.filled(3, null, growable: false);
    _theme = _slotThemes[widget.game.type] ?? _slotThemes[GameType.moneyMania]!;
    _themeSymbols = _theme.symbols;
    _visibleGrid = _generateRandomGrid();
  }

  void _handleStoreUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreUpdate);
    _cancelReelTimers();
    _spinController.dispose();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;

    _cancelReelTimers();

    final contribution = _store.contributeToSlotJackpot(widget.stake);
    final targetGrid = _generateRandomGrid();

    _spinController.repeat(period: const Duration(milliseconds: 700));

    setState(() {
      _spinning = true;
      _finished = false;
      _winningCells = <String>{};
      _lastEvaluation = null;
      _lastContribution = contribution;
      _targetFinalGrid = targetGrid;
    });

    for (var col = 0; col < 3; col++) {
      final spinDuration = 900 + col * 250 + _random.nextInt(400);
      var elapsed = 0;
      _reelTimers[col] =
          Timer.periodic(const Duration(milliseconds: 90), (timer) {
        elapsed += 90;
        if (elapsed >= spinDuration) {
          timer.cancel();
          _reelTimers[col] = null;
          setState(() {
            for (var row = 0; row < 3; row++) {
              _visibleGrid[row][col] = targetGrid[row][col];
            }
          });
          _onPotentialSpinComplete();
        } else {
          setState(() {
            for (var row = 0; row < 3; row++) {
              _visibleGrid[row][col] = _pickSymbol();
            }
          });
        }
      });
    }
  }

  void _settleGame() {
    final evaluation = _lastEvaluation;
    if (!_finished || evaluation == null) {
      return;
    }

    final totalMultiplier = evaluation.totalMultiplier;
    final jackpotBefore = _store.slotJackpot;

    double payout = widget.stake * totalMultiplier;
    double jackpotAward = 0;

    final detailParts = <String>[];

    if (evaluation.winningLines.isNotEmpty) {
      final lineSummary = evaluation.winningLines
          .map((win) =>
              '${win.line.name} ${win.symbol.symbol} (${win.symbol.multiplier.toStringAsFixed(1)}x)')
          .join(', ');
      detailParts.add('Paylines: $lineSummary');
      detailParts.add('Total ${totalMultiplier.toStringAsFixed(2)}x stake');
    }

    if (_lastContribution > 0) {
      detailParts.add('Jackpot fund +${_formatCurrency(_lastContribution)}');
    }

    if (evaluation.progressiveHit) {
      jackpotAward = _store.claimSlotJackpot();
      payout += jackpotAward;
      detailParts.add(
        'Progressive jackpot ${_formatCurrency(jackpotAward)} (pot was ${_formatCurrency(jackpotBefore)})',
      );
      detailParts.add(
        'Jackpot resets to ${_formatCurrency(_store.slotJackpot)}',
      );
    } else {
      detailParts.add('Progressive pot ${_formatCurrency(_store.slotJackpot)}');
    }

    final didWin = payout > 0;

    if (!didWin) {
      detailParts
        ..clear()
        ..add(
          'No winning lines. Progressive pot ${_formatCurrency(_store.slotJackpot)}',
        );
    }

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: didWin ? payout : 0,
        didWin: didWin,
        detail: detailParts.join(' • '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jackpot = _store.slotJackpot;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      _buildJackpotHeader(jackpot),
                      const SizedBox(height: 20),
                      Text(
                        _theme.instructions,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      _buildSlotGrid(),
                      const SizedBox(height: 12),
                      _buildPaylineLegend(),
                      const Spacer(flex: 3),
                    ],
                  );

                  if (constraints.maxHeight < 640) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildJackpotHeader(jackpot),
                          const SizedBox(height: 16),
                          Text(
                            _theme.instructions,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          _buildSlotGrid(),
                          const SizedBox(height: 12),
                          _buildPaylineLegend(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  }

                  return content;
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.game.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _spinning || _finished ? null : _spin,
                    child: Text(
                      _spinning ? 'Spinning...' : 'Spin Progressive Reels',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJackpotHeader(double jackpot) {
    final seed = _store.slotJackpotSeed;
    final contributionRate =
        (_store.slotJackpotContributionRate * 100).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            widget.game.accent.withAlpha((0.55 * 255).round()),
            Colors.deepOrangeAccent.withAlpha((0.35 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.white.withAlpha((0.25 * 255).round()),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.game.accent.withAlpha((0.35 * 255).round()),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: Colors.white.withAlpha((0.9 * 255).round()),
              ),
              const SizedBox(width: 8),
              const Text(
                'Progressive Jackpot',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${contributionRate.toStringAsFixed(1)}% per spin',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(jackpot),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Resets to ${_formatCurrency(seed)} when claimed',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          if (_lastContribution > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${_formatCurrency(_lastContribution)} added this spin',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlotGrid() {
    final hasGrid = _visibleGrid.length == 3 &&
        _visibleGrid.every((row) => row.length == 3);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withAlpha((0.08 * 255).round()),
        border: Border.all(color: Colors.white.withAlpha((0.18 * 255).round())),
      ),
      child: Column(
        children: List.generate(3, (row) {
          return Expanded(
            child: Row(
              children: List.generate(3, (col) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _buildSlotCell(row, col, hasGrid),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSlotCell(int row, int col, bool hasResults) {
    final key = _cellKey(row, col);
    final isWinner = _finished && _winningCells.contains(key);
    final SlotSymbolConfig? symbol = hasResults ? _visibleGrid[row][col] : null;

    final highlightColor = symbol?.color ?? widget.game.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isWinner
            ? highlightColor.withAlpha((0.25 * 255).round())
            : Colors.white.withAlpha((0.12 * 255).round()),
        border: Border.all(
          color: isWinner
              ? highlightColor.withAlpha((0.90 * 255).round())
              : Colors.white.withAlpha((0.28 * 255).round()),
          width: isWinner ? 3 : 1.5,
        ),
      ),
      child: symbol != null
          ? RotationTransition(
              turns: _spinning
                  ? _spinController
                  : const AlwaysStoppedAnimation<double>(0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    symbol.symbol,
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    symbol.label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (symbol.isProgressive)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildProgressiveChip(highlightColor),
                    ),
                ],
              ),
            )
          : const Text(
              '?',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  Widget _buildProgressiveChip(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withAlpha((0.25 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withAlpha((0.85 * 255).round()),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 12,
            color: accent.withAlpha((0.9 * 255).round()),
          ),
          const SizedBox(width: 4),
          const Text(
            'Jackpot',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaylineLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: _paylines.map((line) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.08 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.white.withAlpha((0.18 * 255).round())),
          ),
          child: Text(
            line.name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  _SpinEvaluation _evaluateSpin(List<List<SlotSymbolConfig>> grid) {
    double totalMultiplier = 0;
    bool progressiveHit = false;
    final wins = <_PaylineWin>[];
    final winningCells = <String>{};

    for (final line in _paylines) {
      final firstPos = line.positions.first;
      final firstSymbol = grid[firstPos.row][firstPos.col];
      final matchesLine = line.positions
          .every((pos) => grid[pos.row][pos.col].id == firstSymbol.id);
      if (matchesLine) {
        totalMultiplier += firstSymbol.multiplier;
        progressiveHit = progressiveHit || firstSymbol.isProgressive;
        wins.add(_PaylineWin(line: line, symbol: firstSymbol));
        for (final pos in line.positions) {
          winningCells.add(_cellKey(pos.row, pos.col));
        }
      }
    }

    return _SpinEvaluation(
      totalMultiplier: totalMultiplier,
      progressiveHit: progressiveHit,
      winningLines: wins,
      winningCells: winningCells,
    );
  }

  String _cellKey(int row, int col) => '$row:$col';

  List<List<SlotSymbolConfig>> _generateRandomGrid() {
    return List<List<SlotSymbolConfig>>.generate(
      3,
      (_) => List<SlotSymbolConfig>.generate(
        3,
        (_) => _pickSymbol(),
        growable: false,
      ),
      growable: false,
    );
  }

  SlotSymbolConfig _pickSymbol() {
    if (_themeSymbols.isEmpty) {
      return SlotSymbolConfig(
        id: 'fallback',
        symbol: '???',
        label: 'Mystery',
        multiplier: 1.0,
        color: widget.game.accent,
      );
    }

    final totalWeight = _themeSymbols.fold<double>(
      0,
      (sum, symbol) => sum + (symbol.weight <= 0 ? 1.0 : symbol.weight),
    );

    var roll = _random.nextDouble() * totalWeight;
    for (final symbol in _themeSymbols) {
      final weight = symbol.weight <= 0 ? 1.0 : symbol.weight;
      roll -= weight;
      if (roll <= 0) {
        return symbol;
      }
    }

    return _themeSymbols.last;
  }

  void _onPotentialSpinComplete() {
    if (_reelTimers.every((timer) => timer == null)) {
      _spinController.stop();
      _spinController.reset();
      final evaluation = _evaluateSpin(_targetFinalGrid);
      setState(() {
        _lastEvaluation = evaluation;
        _winningCells = evaluation.winningCells;
        _spinning = false;
        _finished = true;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _settleGame();
      });
    }
  }

  void _cancelReelTimers() {
    for (var i = 0; i < _reelTimers.length; i++) {
      _reelTimers[i]?.cancel();
      _reelTimers[i] = null;
    }
  }
}

class _GridPosition {
  const _GridPosition(this.row, this.col);

  final int row;
  final int col;
}

class _Payline {
  const _Payline({required this.name, required this.positions});

  final String name;
  final List<_GridPosition> positions;
}

class _PaylineWin {
  const _PaylineWin({required this.line, required this.symbol});

  final _Payline line;
  final SlotSymbolConfig symbol;
}

class _SpinEvaluation {
  const _SpinEvaluation({
    required this.totalMultiplier,
    required this.progressiveHit,
    required this.winningLines,
    required this.winningCells,
  });

  final double totalMultiplier;
  final bool progressiveHit;
  final List<_PaylineWin> winningLines;
  final Set<String> winningCells;
}

class _PrizeBoxGameScreen extends StatefulWidget {
  const _PrizeBoxGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_PrizeBoxGameScreen> createState() => _PrizeBoxGameScreenState();
}

class _PrizeBoxGameScreenState extends State<_PrizeBoxGameScreen> {
  PrizeBoxConfig? _selectedPrize;
  bool _revealed = false;

  void _selectBox() {
    if (_revealed) return;

    final store = BettingDataStore.instance;
    final prize = store.selectWeightedPrizeBox();

    setState(() {
      _selectedPrize = prize;
      _revealed = true;
    });

    Future.delayed(const Duration(milliseconds: 800), _settleGame);
  }

  void _settleGame() {
    if (_selectedPrize == null) return;

    final payout = widget.stake * _selectedPrize!.multiplier;
    final didWin = payout > 0;

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: didWin,
        detail: 'You opened: ${_selectedPrize!.label} '
            '(${_selectedPrize!.multiplier.toStringAsFixed(1)}x)',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Text(
              _revealed
                  ? 'Prize revealed!'
                  : 'Pick a mystery box to reveal your prize!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: _revealed && _selectedPrize != null
                  ? Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: _selectedPrize!.color
                              .withAlpha((0.20 * 255).round()),
                          border: Border.all(
                            color: _selectedPrize!.color,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getIconData(_selectedPrize!.icon),
                              size: 60,
                              color: _selectedPrize!.color,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedPrize!.label,
                              style: TextStyle(
                                color: _selectedPrize!.color,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedPrize!.multiplier.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: _selectBox,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: widget.game.accent
                                  .withAlpha((0.20 * 255).round()),
                              border: Border.all(
                                color: widget.game.accent
                                    .withAlpha((0.40 * 255).round()),
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.card_giftcard_rounded,
                                size: 48,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'block':
        return Icons.block;
      case 'redeem':
        return Icons.redeem;
      case 'stars':
        return Icons.stars;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'diamond':
        return Icons.diamond;
      default:
        return Icons.card_giftcard;
    }
  }
}

class _ColorSpinnerGameScreen extends StatefulWidget {
  const _ColorSpinnerGameScreen({required this.game, required this.stake});

  final GameItem game;
  final double stake;

  @override
  State<_ColorSpinnerGameScreen> createState() =>
      _ColorSpinnerGameScreenState();
}

class _ColorSpinnerGameScreenState extends State<_ColorSpinnerGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  ColorSegmentConfig? _result;
  bool _spinning = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;

    setState(() {
      _spinning = true;
      _result = null;
    });

    _spinController.forward(from: 0).then((_) {
      // Select weighted color
      final store = BettingDataStore.instance;
      final selectedColor = store.selectWeightedColorSegment();

      setState(() {
        _result = selectedColor;
        _spinning = false;
        _finished = true;
      });

      Future.delayed(const Duration(milliseconds: 600), _settleGame);
    });
  }

  void _settleGame() {
    if (_result == null) return;

    final payout = widget.stake * _result!.multiplier;

    Navigator.of(context).pop(
      _GamePlayResult(
        stake: widget.stake,
        payout: payout,
        didWin: true,
        detail:
            'Landed on ${_result!.label}! Win ${_result!.multiplier.toStringAsFixed(1)}x',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = BettingDataStore.instance;
    final segments = store.colorSegments;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: FloatingHeader(
        title: '${widget.game.title} — ${_formatCurrency(widget.stake)}',
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const Text(
              'Spin the wheel to win!',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            // Wheel
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 8.0).animate(
                        CurvedAnimation(
                          parent: _spinController,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: CustomPaint(
                        size: const Size(280, 280),
                        painter: _ColorWheelPainter(segments: segments),
                      ),
                    ),
                    // Pointer
                    Positioned(
                      top: 0,
                      child: Icon(
                        Icons.arrow_drop_down,
                        size: 48,
                        color: widget.game.accent,
                      ),
                    ),
                    // Center result
                    if (_finished && _result != null)
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _result!.color.withAlpha((0.90 * 255).round()),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _result!.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_result!.multiplier.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Spin button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.game.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _spinning || _finished ? null : _spin,
                child: Text(
                  _spinning ? 'Spinning...' : 'Spin Wheel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  _ColorWheelPainter({required this.segments});

  final List<ColorSegmentConfig> segments;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final totalWeight = segments.fold(0.0, (sum, s) => sum + s.weight);

    double startAngle = -pi / 2;

    for (final segment in segments) {
      final sweepAngle = (segment.weight / totalWeight) * 2 * pi;

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = segment.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw separator
      final separatorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withAlpha((0.30 * 255).round())
        ..strokeWidth = 2;

      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(startAngle),
          center.dy + radius * sin(startAngle),
        ),
        separatorPaint,
      );

      startAngle += sweepAngle;
    }

    // Draw outer border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withAlpha((0.50 * 255).round())
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(_ColorWheelPainter oldDelegate) => false;
}

class _WheelSegment {
  const _WheelSegment({
    required this.label,
    required this.multiplier,
    required this.color,
  });

  final String label;
  final double multiplier;
  final Color color;
}

// Removed legacy custom currency painter classes after switching to text glyph '₦₲'.
