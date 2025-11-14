import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/store_data_store.dart';
import '../../services/betting_data_store.dart';
import '../../services/user_account_service.dart';
import '../../models/store_models.dart';
import '../../models/betting_models.dart';
import '../../widgets/floating_header.dart';
import '../../widgets/notification_bell.dart';
import '../login_screen.dart';

enum StoreSpinOutcome { tryAgain, moneyWin, moneyLoss, itemWin, limitBlocked }

class StoreSpinResult {
  const StoreSpinResult({
    required this.segment,
    required this.outcome,
    this.moneyWon = 0,
    this.itemName,
    this.betRefunded = false,
    this.limitPeriod,
    this.nextReset,
  });

  final PrizeSegment segment;
  final StoreSpinOutcome outcome;
  final double moneyWon;
  final String? itemName;
  final bool betRefunded;
  final PrizeLimitPeriod? limitPeriod;
  final DateTime? nextReset;
}

class NgmyStoreScreen extends StatefulWidget {
  const NgmyStoreScreen({super.key});

  @override
  State<NgmyStoreScreen> createState() => _NgmyStoreScreenState();
}

class _NgmyStoreScreenState extends State<NgmyStoreScreen>
    with SingleTickerProviderStateMixin {
  final StoreDataStore _store = StoreDataStore.instance;
  late AnimationController _controller;
  late Animation<double> _angle;
  bool _spinning = false;
  bool _showBetDropdown = false;
  double _selectedBetAmount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _angle = Tween<double>(begin: 0, end: 0).animate(_controller);

    final amounts = _store.betAmounts;
    if (amounts.isNotEmpty) {
      _selectedBetAmount = amounts.first;
    } else {
      _selectedBetAmount = 10;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin(
    StoreDataStore store, {
    PrizeSegment? targetItem,
  }) async {
    if (_spinning) {
      return;
    }

    final segments = store.segments;
    if (segments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No store wheel segments configured.')),
        );
      }
      return;
    }

    final betAmount = targetItem?.betAmount ?? _selectedBetAmount;
    if (betAmount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a bet amount to spin.')),
        );
      }
      return;
    }

    if (store.storeWalletBalance < betAmount || !store.placeBet(betAmount)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You need ₦₲${betAmount.toStringAsFixed(2)} in the store wallet to spin.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _spinning = true;
      _showBetDropdown = false;
    });

    final PrizeSegment? chosen =
        targetItem ?? store.pickWeightedSegment();
    if (chosen == null) {
      store.adjustStoreWalletBalance(betAmount);
      setState(() => _spinning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No winning segments are currently available.'),
          ),
        );
      }
      return;
    }

    final targetIndex = segments.indexOf(chosen);
    if (targetIndex == -1) {
      store.adjustStoreWalletBalance(betAmount);
      setState(() => _spinning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The selected item is no longer available.'),
          ),
        );
      }
      return;
    }

    final count = segments.length;
    final sweep = 2 * math.pi / count;
    final random = math.Random();
    final turns = 4 + (targetItem != null ? targetIndex % 3 : random.nextInt(3));

    final sliceCenterAngle = (targetIndex + 0.5) * sweep;
    const pointerAngle = 3 * math.pi / 2;
    double delta = pointerAngle - sliceCenterAngle;
    while (delta < 0) {
      delta += 2 * math.pi;
    }
    while (delta >= 2 * math.pi) {
      delta -= 2 * math.pi;
    }

    final targetRotation = (2 * math.pi * turns) + delta;

    _angle = Tween<double>(begin: 0, end: targetRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller
      ..reset()
      ..forward().whenComplete(() async {
        setState(() => _spinning = false);

        final finalAngle = _angle.value % (2 * math.pi);
        const pointer = 3 * math.pi / 2;
        double bestDist = double.infinity;
        int landedIndex = 0;

        for (int i = 0; i < count; i++) {
          final sliceCenter = (i + 0.5) * sweep;
          double rotatedCenter = sliceCenter + finalAngle;
          while (rotatedCenter < 0) {
            rotatedCenter += 2 * math.pi;
          }
          while (rotatedCenter >= 2 * math.pi) {
            rotatedCenter -= 2 * math.pi;
          }

          double dist = (rotatedCenter - pointer).abs();
          if (dist > math.pi) {
            dist = (2 * math.pi) - dist;
          }

          if (dist < bestDist) {
            bestDist = dist;
            landedIndex = i;
          }
        }

        final landed = segments[landedIndex];
        final prefs = await SharedPreferences.getInstance();
        final username = prefs.getString('growth_user_name') ?? 'Guest';

        final result = await _applyCustomBettingOutcome(
          store,
          landed,
          betAmount,
          username,
        );

        if (!mounted) {
          return;
        }

        _showCustomResult(context, result, betAmount);
      });
  }

  /// Custom betting outcome logic based on dropdown bet amount
  Future<StoreSpinResult> _applyCustomBettingOutcome(
    StoreDataStore store,
    PrizeSegment landed,
    double betAmount,
    String username,
  ) async {
    // Check if this is a "Try Again" segment (case insensitive)
    final isTryAgain = landed.label.toLowerCase().contains('try again') ||
        landed.isTryAgain ||
        (landed.itemName != null &&
            landed.itemName!.toLowerCase().contains('try again'));
    final now = DateTime.now();
    final bettingStore = BettingDataStore.instance;

    if (isTryAgain) {
      final historyEntry = BettingHistoryEntry(
        id: now.millisecondsSinceEpoch.toString(),
        title: 'Try Again: ${landed.label}',
        amount: betAmount,
        isCredit: false,
        category: TransactionCategory.game,
        icon: Icons.refresh,
        color: Colors.orange,
        timestamp: now,
      );
      bettingStore.addHistoryEntry(historyEntry);
      return StoreSpinResult(
        segment: landed,
        outcome: StoreSpinOutcome.tryAgain,
        moneyWon: 0,
      );
    }

    final limitAllowed = store.consumePrizeAllowance(landed, now);
    if (!limitAllowed) {
      store.adjustStoreWalletBalance(betAmount);
      final nextReset = store.nextResetFor(landed);
      bettingStore.addHistoryEntry(
        BettingHistoryEntry(
          id: now.millisecondsSinceEpoch.toString(),
          title: 'Limit Reached: ${landed.label}',
          amount: 0,
          isCredit: true,
          category: TransactionCategory.game,
          icon: Icons.lock_clock,
          color: Colors.yellow.shade700,
          timestamp: now,
        ),
      );
      return StoreSpinResult(
        segment: landed,
        outcome: StoreSpinOutcome.limitBlocked,
        betRefunded: true,
        limitPeriod: landed.winLimitPeriod,
        nextReset: nextReset,
      );
    }

    if (landed.type == PrizeType.money) {
      final wonAmount = landed.moneyAmount;

      if (wonAmount >= betAmount) {
        final totalWin = betAmount + wonAmount;
        store.adjustStoreWalletBalance(totalWin);
        bettingStore.addHistoryEntry(
          BettingHistoryEntry(
            id: now.millisecondsSinceEpoch.toString(),
            title: 'Store Win: ${landed.label}',
            amount: wonAmount,
            isCredit: true,
            category: TransactionCategory.game,
            icon: Icons.casino,
            color: Colors.green,
            timestamp: now,
          ),
        );
        return StoreSpinResult(
          segment: landed,
          outcome: StoreSpinOutcome.moneyWin,
          moneyWon: wonAmount,
        );
      }

      bettingStore.addHistoryEntry(
        BettingHistoryEntry(
          id: now.millisecondsSinceEpoch.toString(),
          title: 'Store Loss: ${landed.label}',
          amount: betAmount,
          isCredit: false,
          category: TransactionCategory.game,
          icon: Icons.casino,
          color: Colors.red,
          timestamp: now,
        ),
      );
      return StoreSpinResult(
        segment: landed,
        outcome: StoreSpinOutcome.moneyLoss,
        moneyWon: 0,
      );
    }

    if (landed.type == PrizeType.item) {
      store.addCustomItemWin(landed.itemName ?? 'Unknown Item');
      bettingStore.addHistoryEntry(
        BettingHistoryEntry(
          id: now.millisecondsSinceEpoch.toString(),
          title: 'Item Won (bet used): ${landed.itemName}',
          amount: betAmount,
          isCredit: false,
          category: TransactionCategory.game,
          icon: Icons.card_giftcard,
          color: Colors.blue,
          timestamp: now,
        ),
      );
      return StoreSpinResult(
        segment: landed,
        outcome: StoreSpinOutcome.itemWin,
        itemName: landed.itemName,
      );
    }

    bettingStore.addHistoryEntry(
      BettingHistoryEntry(
        id: now.millisecondsSinceEpoch.toString(),
        title: 'Store Spin: ${landed.label}',
        amount: betAmount,
        isCredit: false,
        category: TransactionCategory.game,
        icon: Icons.help_outline,
        color: Colors.grey,
        timestamp: now,
      ),
    );

    return StoreSpinResult(
      segment: landed,
      outcome: StoreSpinOutcome.moneyLoss,
      moneyWon: 0,
    );
  }

  void _showCustomResult(
    BuildContext context,
    StoreSpinResult result,
    double betAmount,
  ) {
    final s = result.segment;
    String text;
    Color backgroundColor;
    IconData icon;
    final wonAmount = result.moneyWon;

    switch (result.outcome) {
      case StoreSpinOutcome.tryAgain:
        text = 'Try Again! You lost ₦₲${betAmount.toStringAsFixed(0)}';
        backgroundColor = Colors.orange.shade700;
        icon = Icons.refresh;
        break;
      case StoreSpinOutcome.moneyWin:
        text =
            'WIN! You won ₦₲${wonAmount.toStringAsFixed(0)} (+ your ₦₲${betAmount.toStringAsFixed(0)} bet back)';
        backgroundColor = Colors.green.shade700;
        icon = Icons.celebration;
        break;
      case StoreSpinOutcome.moneyLoss:
        text = 'You lost ₦₲${betAmount.toStringAsFixed(0)}';
        backgroundColor = Colors.red.shade700;
        icon = Icons.trending_down;
        break;
      case StoreSpinOutcome.itemWin:
        final itemName = result.itemName ?? s.itemName ?? 'mystery prize';
        text =
            'ITEM WIN! You won $itemName. Your ₦₲${betAmount.toStringAsFixed(0)} bet was used to secure it.';
        backgroundColor = Colors.blue.shade700;
        icon = Icons.card_giftcard;
        break;
      case StoreSpinOutcome.limitBlocked:
        final periodLabel = result.limitPeriod?.shortLabel ?? 'limit period';
        final resetNote = result.nextReset != null
            ? ' Try again after ${_formatResetWindow(result.nextReset!)}.'
            : '';
        text =
            'High-value limit reached for ${s.label} this $periodLabel. Your bet was refunded.$resetNote';
        backgroundColor = Colors.amber.shade800;
        icon = Icons.lock_clock;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  String _formatResetWindow(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  Widget _buildProfileAction() {
    final user = UserAccountService.instance.currentUser;
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.account_circle, color: Colors.white70),
        onPressed: _openProfileSheet,
        tooltip: 'Account',
      );
    }

    final initial = _deriveInitial(user.name, user.email);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Account',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openProfileSheet,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(32),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openProfileSheet() async {
    final user = UserAccountService.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is currently signed in.')),
      );
      return;
    }

    final parentContext = context;
    final scaffoldMessenger = ScaffoldMessenger.of(parentContext);
    final nameController = TextEditingController(text: user.name);
    final usernameController =
        TextEditingController(text: BettingDataStore.instance.username);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? saveError;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: StatefulBuilder(
                builder: (modalContext, setModalState) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(60),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white.withAlpha(30),
                                child: Text(
                                  _deriveInitial(
                                      nameController.text, user.email),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nameController.text.isNotEmpty
                                          ? nameController.text
                                          : user.email,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(160),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(15),
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: Colors.white.withAlpha(32)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Signed in with',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(150),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  user.email,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                            decoration: _modalFieldDecoration(
                              'Display Name',
                              Icons.person_outline,
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: usernameController,
                            style: const TextStyle(color: Colors.white),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please choose a username';
                              }
                              return null;
                            },
                            decoration: _modalFieldDecoration(
                              'Store Username',
                              Icons.badge_outlined,
                            ),
                          ),
                          if (saveError != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              saveError!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      setModalState(() {
                                        isSaving = true;
                                        saveError = null;
                                      });

                                      final navigator =
                                          Navigator.of(modalContext);
                                      final trimmedName =
                                          nameController.text.trim();
                                      final trimmedUsername =
                                          usernameController.text.trim();

                                      final profileUpdated =
                                          await UserAccountService.instance
                                              .updateProfile(name: trimmedName);

                                      if (!profileUpdated) {
                                        setModalState(() {
                                          isSaving = false;
                                          saveError =
                                              'Could not save profile. Please try again.';
                                        });
                                        return;
                                      }

                                      final bettingStore =
                                          BettingDataStore.instance;
                                      if (trimmedUsername !=
                                          bettingStore.username) {
                                        bettingStore.updateUsername(
                                          trimmedUsername,
                                        );
                                        final prefs = await SharedPreferences
                                            .getInstance();
                                        await prefs.setString(
                                          'growth_user_name',
                                          trimmedUsername,
                                        );
                                        await prefs.setString(
                                          'family_tree_user_name',
                                          trimmedUsername,
                                        );
                                      }

                                      setModalState(() => isSaving = false);

                                      navigator.pop(true);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00A896),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () async {
                              final updated =
                                  await _showPasswordDialog(parentContext);
                              if (updated && mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Password updated successfully.'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.lock_reset,
                                color: Colors.white70),
                            label: const Text(
                              'Change Password',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const Divider(height: 32, color: Colors.white24),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(modalContext).pop(false);
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  if (mounted) {
                                    _logout();
                                  }
                                },
                              );
                            },
                            icon: const Icon(Icons.logout,
                                color: Colors.redAccent),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    usernameController.dispose();

    if (result == true && mounted) {
      setState(() {});
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    }
  }

  InputDecoration _modalFieldDecoration(String label, IconData icon) {
    final accent = Colors.white.withAlpha(179);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: accent),
      prefixIcon: Icon(icon, color: accent),
      filled: true,
      fillColor: Colors.white.withAlpha(25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withAlpha(51)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withAlpha(51)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  String _deriveInitial(String? name, String email) {
    final trimmedName = name?.trim() ?? '';
    final source = trimmedName.isNotEmpty ? trimmedName : email.trim();
    if (source.isEmpty) {
      return 'U';
    }
    return source.substring(0, 1).toUpperCase();
  }

  Future<bool> _showPasswordDialog(BuildContext dialogContext) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isProcessing = false;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            InputDecoration buildDecoration(String label, IconData icon,
                {required bool obscure, required VoidCallback onToggle}) {
              return _modalFieldDecoration(label, icon).copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    onToggle();
                  },
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withAlpha(179),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Update Password',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentController,
                        obscureText: obscureCurrent,
                        style: const TextStyle(color: Colors.white),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your current password';
                          }
                          return null;
                        },
                        decoration: buildDecoration(
                          'Current Password',
                          Icons.lock_outline,
                          obscure: obscureCurrent,
                          onToggle: () {
                            setDialogState(() {
                              obscureCurrent = !obscureCurrent;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newController,
                        obscureText: obscureNew,
                        style: const TextStyle(color: Colors.white),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter a new password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        decoration: buildDecoration(
                          'New Password',
                          Icons.lock_reset,
                          obscure: obscureNew,
                          onToggle: () {
                            setDialogState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmController,
                        obscureText: obscureConfirm,
                        style: const TextStyle(color: Colors.white),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirm your new password';
                          }
                          if (value != newController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        decoration: buildDecoration(
                          'Confirm Password',
                          Icons.lock,
                          obscure: obscureConfirm,
                          onToggle: () {
                            setDialogState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                          Navigator.of(context).pop(false);
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          if (currentController.text == newController.text) {
                            setDialogState(() {
                              errorMessage =
                                  'New password must differ from current password';
                            });
                            return;
                          }

                          setDialogState(() {
                            isProcessing = true;
                            errorMessage = null;
                          });

                          final navigator = Navigator.of(context);
                          final result =
                              await UserAccountService.instance.updatePassword(
                            currentPassword: currentController.text,
                            newPassword: newController.text,
                          );

                          if (result == PasswordChangeResult.success) {
                            navigator.pop(true);
                            return;
                          }

                          setDialogState(() {
                            isProcessing = false;
                            errorMessage = result ==
                                    PasswordChangeResult.invalidCurrentPassword
                                ? 'Current password is incorrect'
                                : 'Unable to update password. Please try again.';
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A896),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    return result ?? false;
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Sign Out',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child:
                  const Text('Sign Out', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      // Logout user
      await UserAccountService.instance.logout();

      // Navigate to login screen and clear the entire navigation stack
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final segments = store.segments;
        final items = store.itemCounts;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: FloatingHeader(
            title: 'NGMY Store',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: NotificationBell(
                  badgeColor: const Color(0xFFFFB74D),
                  tooltip: 'Store notifications',
                  allowCompose: false,
                  scopes: const ['global', 'store'],
                ),
              ),
              _buildProfileAction(),
            ],
          ),
          body: SingleChildScrollView(
            clipBehavior: Clip.hardEdge,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(
                  bottom: 20), // Reduced padding for better screen fit
              child: Column(
                children: [
                  // Keep a tiny top padding, then show Wallet/Items chips near the title
                  const SizedBox(height: 4),
                  // Wallet + Totals row (moved up)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _openWalletPage(context, store),
                          child: _StatChip(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Wallet',
                              value: _formatCurrency(store.storeWalletBalance)),
                        ),
                        const SizedBox(width: 12),
                        _StatChip(
                            icon: Icons.card_giftcard,
                            label: 'Items',
                            value: items.values
                                .fold<int>(0, (a, b) => a + b)
                                .toString()),
                      ],
                    ),
                  ),
                  // Minimal spacer to keep green arrow close to wallet/items
                  const SizedBox(height: 8),
                  // Clickable green arrow with bet amount dropdown
                  Center(
                    child: Column(
                      children: [
                        // Bet amount dropdown
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _showBetDropdown ? 280 : 0,
                          width: 200,
                          curve: Curves.easeInOut,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    Colors.black.withAlpha((0.9 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF00C853), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00C853)
                                        .withAlpha((0.3 * 255).round()),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _showBetDropdown
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Header
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF00C853),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(10),
                                              topRight: Radius.circular(10),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.casino,
                                                  color: Colors.white,
                                                  size: 20),
                                              SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'SELECT BET AMOUNT',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    letterSpacing: 1,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Bet options
                                        Expanded(
                                          child: ListView.builder(
                                            padding: const EdgeInsets.all(8),
                                            itemCount: _store.betAmounts.length,
                                            itemBuilder: (context, index) {
                                              final amount =
                                                  _store.betAmounts[index];
                                              final isSelected =
                                                  amount == _selectedBetAmount;
                                              final canAfford =
                                                  _store.storeWalletBalance >=
                                                      amount;

                                              return GestureDetector(
                                                onTap: canAfford
                                                    ? () {
                                                        setState(() {
                                                          _selectedBetAmount =
                                                              amount;
                                                          _showBetDropdown =
                                                              false;
                                                        });
                                                      }
                                                    : null,
                                                child: Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(vertical: 4),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(
                                                                0xFF00C853)
                                                            .withAlpha(
                                                                (0.2 * 255)
                                                                    .round())
                                                        : canAfford
                                                            ? Colors.white
                                                                .withAlpha(
                                                                    (0.1 * 255)
                                                                        .round())
                                                            : Colors.red
                                                                .withAlpha((0.1 *
                                                                        255)
                                                                    .round()),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF00C853)
                                                          : canAfford
                                                              ? Colors.white
                                                                  .withAlpha((0.3 *
                                                                          255)
                                                                      .round())
                                                              : Colors.red
                                                                  .withAlpha((0.5 *
                                                                          255)
                                                                      .round()),
                                                      width: isSelected ? 2 : 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        '₦₲${amount.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          color: canAfford
                                                              ? Colors.white
                                                              : Colors
                                                                  .red.shade300,
                                                          fontWeight: isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight.w500,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      if (isSelected)
                                                        const Icon(
                                                          Icons.check_circle,
                                                          color:
                                                              Color(0xFF00C853),
                                                          size: 20,
                                                        )
                                                      else if (!canAfford)
                                                        Icon(
                                                          Icons.lock,
                                                          color: Colors
                                                              .red.shade300,
                                                          size: 16,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox(),
                            ),
                          ),
                        ),

                        // Clickable green arrow (bigger, no circle)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showBetDropdown = !_showBetDropdown;
                            });
                          },
                          child: Column(
                            children: [
                              AnimatedRotation(
                                turns: _showBetDropdown ? 0.5 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: const Color(0xFF00C853),
                                  size: 72, // Made bigger (was 40)
                                  shadows: [
                                    Shadow(
                                      color: Colors.black
                                          .withAlpha((0.5 * 255).round()),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_showBetDropdown)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00C853)
                                            .withAlpha((0.4 * 255).round()),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '₦₲${_selectedBetAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Wheel (fixed square, centered)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = math.min(constraints.maxWidth, 360.0);
                        return Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Spinning wheel
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    final a = _angle.value;
                                    return Transform.rotate(
                                      angle: a,
                                      child: const RepaintBoundary(
                                        child: _WheelContainer(),
                                      ),
                                    );
                                  },
                                ),
                                // Removed stationary pointer overlay per user request
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Reduced spacing between wheel and spin button
                  const SizedBox(height: 16),
                  // Spin button below the wheel
                  Center(
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor:
                              store.storeWalletBalance < _selectedBetAmount
                                  ? Colors.grey
                                  : Colors.teal,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: (_spinning ||
                                store.storeWalletBalance < _selectedBetAmount)
                            ? null
                            : () => _spin(store),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rotate_right,
                                size: 24, color: Colors.white),
                            const SizedBox(height: 4),
                            Text(
                              _spinning ? 'Spinning…' : 'SPIN',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Possible items section is always visible (shows placeholder when none)
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Winning items',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150, // Increased to give overlays breathing room
                    child: Builder(
                      builder: (_) {
                        // Filter out Try Again and show only actual items
                        final itemSegments = segments
                            .where((s) =>
                                s.type == PrizeType.item && !s.isTryAgain)
                            .toList();
                        if (itemSegments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('No items configured yet',
                                    style: TextStyle(color: Colors.white54)),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              itemSegments.length, // Only show actual items
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final s = itemSegments[i];
                            final canBet = s.betAmount > 0;
                            return GestureDetector(
                              onTap: () => _previewItem(context, s),
                              child: SizedBox(
                                height: 130,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Item name label on top
                                    Container(
                                      width: 96,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 6),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (canBet)
                                            const Icon(Icons.casino_rounded,
                                                color: Colors.amber, size: 12),
                                          if (canBet) const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              s.itemName ?? 'Item',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Item image box
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 96,
                                          height: 96,
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: canBet
                                                  ? Colors.amber.withAlpha(100)
                                                  : Colors.white24,
                                              width: canBet ? 2 : 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: s.image != null &&
                                                    s.image!.isNotEmpty
                                                ? _buildImage(s.image!)
                                                : Center(
                                                    child: Icon(
                                                      Icons.card_giftcard,
                                                      color: Colors.white54,
                                                      size: 40,
                                                    ),
                                                  ),
                                          ),
                                        ),

                                        // BET button overlay (top center)
                                        if (canBet)
                                          Positioned(
                                            top: 6,
                                            left: 0,
                                            right: 0,
                                            child: Center(
                                              child: GestureDetector(
                                                onTap:
                                                    store.storeWalletBalance >=
                                                            s.betAmount
                                                        ? () => _spin(store,
                                                            targetItem: s)
                                                        : null,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    gradient: store
                                                                .storeWalletBalance >=
                                                            s.betAmount
                                                        ? const LinearGradient(
                                                            colors: [
                                                              Color(0xFF00C853),
                                                              Color(0xFF4CAF50)
                                                            ],
                                                          )
                                                        : LinearGradient(
                                                            colors: [
                                                              Colors.grey
                                                                  .shade600,
                                                              Colors
                                                                  .grey.shade500
                                                            ],
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: store.storeWalletBalance >=
                                                                s.betAmount
                                                            ? const Color(
                                                                    0xFF00C853)
                                                                .withAlpha(
                                                                    (0.4 * 255)
                                                                        .round())
                                                            : Colors.black
                                                                .withAlpha((0.3 *
                                                                        255)
                                                                    .round()),
                                                        blurRadius: 4,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        store.storeWalletBalance >=
                                                                s.betAmount
                                                            ? Icons.casino
                                                            : Icons.lock,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'BET',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                        // Bet amount indicator (bottom right corner)
                                        if (canBet)
                                          Positioned(
                                            bottom: 4,
                                            right: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withAlpha((0.3 * 255)
                                                            .round()),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '₦₲${s.betAmount.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
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
                      },
                    ),
                  ),
                  const SizedBox(
                      height: 8), // Reduced extra space for better screen fit
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCurrency(double amount) => '₦₲${amount.toStringAsFixed(2)}';

  Widget _buildImage(String imagePath, {BoxFit fit = BoxFit.cover}) {
    // Check if it's a network URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white54),
      );
    }
    // Check if it's an asset path
    else if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported, color: Colors.white54),
      );
    }
    // Otherwise, treat it as a file path from image picker
    else {
      return Image.file(
        File(imagePath),
        fit: fit,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image, color: Colors.white54),
      );
    }
  }

  void _previewItem(BuildContext context, PrizeSegment s) {
    final store = _store;
    final canBet = s.betAmount > 0 && !s.isTryAgain;

    final media = MediaQuery.of(context);
    final dialogMaxWidth = media.size.width * 0.9;
    final dialogMaxHeight = media.size.height * 0.85;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = math.min(constraints.maxWidth, dialogMaxWidth);
            final double maxHeight = math.min(constraints.maxHeight, dialogMaxHeight);
            final double reservedHeight = canBet ? 230.0 : 190.0;
            final double rawSize = math.min(
              maxWidth - 32,
              maxHeight - reservedHeight,
            );
      final double imageSize = rawSize.isFinite && rawSize > 0
        ? rawSize.clamp(180.0, maxWidth - 32).toDouble()
        : math.min(maxWidth - 32, 280.0);

            Widget betSection;
            if (canBet) {
              betSection = Column(
                children: [
                  Text(
                    'Bet ₦₲${s.betAmount.toStringAsFixed(2)} to win this item!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '70% chance to win when you bet on this item',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (store.storeWalletBalance < s.betAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'You need ₦₲${s.betAmount.toStringAsFixed(2)} to bet on this item!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        _spin(store, targetItem: s);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.casino_rounded,
                          color: Colors.white),
                      label: Text(
                        'Bet ₦₲${s.betAmount.toStringAsFixed(2)} & Spin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              betSection = const Text(
                'Pinch to zoom • Drag to pan • Double-tap to reset',
                style: TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
              );
            }

            final content = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.itemName ?? 'Item',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: s.image != null && s.image!.isNotEmpty
                        ? InteractiveViewer(
                            panEnabled: true,
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                color: Colors.black,
                                alignment: Alignment.center,
                                child: _buildImage(
                                  s.image!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.card_giftcard,
                              color: Colors.white54,
                              size: 72,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                betSection,
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            );

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openWalletPage(BuildContext context, StoreDataStore store) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StoreWalletPage(store: store),
      ),
    );
  }
}

class _StoreWalletPage extends StatelessWidget {
  const _StoreWalletPage({required this.store});
  final StoreDataStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: FloatingHeader(
            title: 'Store Wallet',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Text('Balance',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '₦₲${store.storeWalletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Four buttons in a 2x2 grid
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => _DepositPage(store: store),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5A8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_circle_rounded),
                        label: const Text('Deposit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => _WithdrawPage(store: store),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5E8A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.remove_circle_rounded),
                        label: const Text('Withdraw'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => _ItemsPage(store: store),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C9EFF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.inventory_2_rounded),
                        label: const Text('Items'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => _MyRequestsPage(store: store),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB347),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('My Requests'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (store.depositRequests.isNotEmpty) ...[
                        const Text('Deposits',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        ...store.depositRequests.map((d) => _TransactionTile(
                              icon: Icons.add_circle,
                              title: 'Deposit ₦₲${d.amount.toStringAsFixed(2)}',
                              subtitle: d.status == RequestStatus.pending
                                  ? 'Pending approval'
                                  : d.status == RequestStatus.approved
                                      ? 'Approved'
                                      : 'Rejected',
                              color: d.status == RequestStatus.approved
                                  ? Colors.green
                                  : d.status == RequestStatus.rejected
                                      ? Colors.red
                                      : Colors.orange,
                            )),
                      ],
                      if (store.withdrawRequests.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Withdrawals',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        ...store.withdrawRequests.map((w) => _TransactionTile(
                              icon: Icons.remove_circle,
                              title:
                                  'Withdraw ₦₲${w.amount.toStringAsFixed(2)}',
                              subtitle: w.status == RequestStatus.pending
                                  ? 'Pending approval'
                                  : w.status == RequestStatus.approved
                                      ? 'Approved'
                                      : 'Rejected',
                              color: w.status == RequestStatus.approved
                                  ? Colors.green
                                  : w.status == RequestStatus.rejected
                                      ? Colors.red
                                      : Colors.orange,
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white)),
                Text(subtitle, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Deposit Page
class _DepositPage extends StatefulWidget {
  const _DepositPage({required this.store});
  final StoreDataStore store;

  @override
  State<_DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<_DepositPage> {
  final _amountCtrl = TextEditingController();
  String _screenshotPath = '';

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _screenshotPath = image.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screenshot selected')),
        );
      }
    }
  }

  void _submitDeposit() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    if (_screenshotPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please attach a proof of payment screenshot')),
      );
      return;
    }
    widget.store.submitDepositRequest(amount, _screenshotPath);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Deposit request submitted! Awaiting admin approval.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Get keyboard height to adjust layout when keyboard is visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: FloatingHeader(
        title: 'Deposit Funds',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      resizeToAvoidBottomInset:
          true, // Important: Let scaffold resize when keyboard appears
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Ultra-conservative spacing for small devices
          final isVerySmallDevice = screenHeight < 600 || screenWidth < 360;

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(
                screenWidth * 0.025), // Ultra-conservative 2.5% padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Important: Use minimum size
              children: [
                Text(
                  'Enter amount to deposit',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize:
                        screenWidth * 0.035, // Smaller font for small devices
                  ),
                ),
                SizedBox(
                    height: isVerySmallDevice
                        ? 8
                        : screenHeight *
                            0.01), // Minimal spacing on small devices
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixText: '₦₲',
                    prefixStyle: const TextStyle(color: Colors.white70),
                    hintText: '0.00',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.03,
                      vertical: isVerySmallDevice
                          ? 12
                          : 16, // Compact padding on small devices
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.025),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.025),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                SizedBox(height: isVerySmallDevice ? 12 : screenHeight * 0.02),
                Text(
                  'Attach proof of payment screenshot from Cash App',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
                SizedBox(height: isVerySmallDevice ? 8 : screenHeight * 0.01),
                OutlinedButton.icon(
                  onPressed: _pickScreenshot,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: EdgeInsets.symmetric(
                      vertical: isVerySmallDevice ? 10 : 14,
                      horizontal: screenWidth * 0.03,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.025),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file,
                      color: Colors.white70, size: 18),
                  label: Text(
                    _screenshotPath.isEmpty
                        ? 'Select Screenshot'
                        : 'Screenshot attached',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: screenWidth * 0.032,
                    ),
                  ),
                ),
                if (_screenshotPath.isNotEmpty) ...[
                  SizedBox(height: isVerySmallDevice ? 8 : screenHeight * 0.01),
                  Container(
                    height: isVerySmallDevice
                        ? 100
                        : screenHeight *
                            0.15, // Much smaller preview on small devices
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(screenWidth * 0.025),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(screenWidth * 0.025),
                      child: Image.file(
                        File(_screenshotPath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image,
                              color: Colors.white54, size: 24),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isVerySmallDevice ? 4 : 8),
                  const Text(
                    'Screenshot preview',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
                SizedBox(height: isVerySmallDevice ? 16 : screenHeight * 0.025),
                SizedBox(
                  width: double.infinity,
                  height: isVerySmallDevice
                      ? 44
                      : screenHeight * 0.055, // Compact button on small devices
                  child: ElevatedButton(
                    onPressed: _submitDeposit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5A8),
                      padding: EdgeInsets.symmetric(
                        vertical: isVerySmallDevice ? 8 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(screenWidth * 0.025),
                      ),
                    ),
                    child: Text(
                      'Submit Deposit Request',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Extra bottom padding when keyboard is visible
                if (keyboardHeight > 0) SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Withdraw Page
class _WithdrawPage extends StatefulWidget {
  const _WithdrawPage({required this.store});
  final StoreDataStore store;

  @override
  State<_WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<_WithdrawPage> {
  final _amountCtrl = TextEditingController();
  final _cashAppCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _cashAppCtrl.dispose();
    super.dispose();
  }

  void _submitWithdraw() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    if (amount > widget.store.storeWalletBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }
    final cashAppTag = _cashAppCtrl.text.trim();
    if (cashAppTag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Cash App tag')),
      );
      return;
    }
    widget.store.submitWithdrawRequest(amount, cashAppTag);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Withdraw request submitted! Awaiting admin approval.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: FloatingHeader(
        title: 'Withdraw Funds',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Text('Available: ',
                      style: TextStyle(color: Colors.white70)),
                  Text(
                    '₦₲${widget.store.storeWalletBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Amount to withdraw',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixText: '₦₲',
                prefixStyle: const TextStyle(color: Colors.white70),
                hintText: '0.00',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cash App Tag',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cashAppCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixText: '\$',
                prefixStyle: const TextStyle(color: Colors.white70),
                hintText: 'YourCashTag',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitWithdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5E8A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit Withdraw Request',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Items Page (shipping address form)
class _ItemsPage extends StatefulWidget {
  const _ItemsPage({required this.store});
  final StoreDataStore store;

  @override
  State<_ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<_ItemsPage> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  String? _selectedItem;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  void _submitShipment() {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item to ship')),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final zip = _zipCtrl.text.trim();
    if (name.isEmpty || address.isEmpty || city.isEmpty || zip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all shipping details')),
      );
      return;
    }
    widget.store.submitShipmentRequest(
      itemName: _selectedItem!,
      fullName: name,
      address: address,
      city: city,
      zipCode: zip,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Shipment request submitted! Admin will process shortly.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.store.itemCounts;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: FloatingHeader(
        title: 'Request Item Shipment',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text('No items to ship',
                  style: TextStyle(color: Colors.white54)),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  const Text(
                    'Select item to ship',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...items.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _selectedItem = e.key),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedItem == e.key
                                      ? Colors.blue
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedItem == e.key
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: _selectedItem == e.key
                                        ? Colors.blue
                                        : Colors.white54,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.key,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          'x${e.value}',
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 24),
                  const Text(
                    'Shipping Address',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Street Address',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cityCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'City',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _zipCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'ZIP Code',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitShipment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C9EFF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit Shipment Request',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// (Removed bottom pointer painter; we show the circle clearly without overlays.)

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

// Container widget that reads the store segments and paints the wheel filling the space
class _WheelContainer extends StatelessWidget {
  const _WheelContainer();

  @override
  Widget build(BuildContext context) {
    final store = StoreDataStore.instance;
    final segments = store.segments;
    return CustomPaint(
      painter: _WheelPainter(segments: segments),
      size: Size.infinite,
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.segments});
  final List<PrizeSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final count = segments.isEmpty ? 6 : segments.length;
    final sweep = 2 * math.pi / count;

    // Ensure wheel pops on dark backgrounds: base + bright outer rim
    final baseFill = Paint()..color = const Color(0xFF222A36);
    canvas.drawCircle(center, radius, baseFill);

    final outerRim = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius - 1, outerRim);

    final sepPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5; // Thicker white bars to differentiate segments

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    if (segments.isEmpty) {
      // Fallback wedges with numbers
      final fallbackColors = [
        const Color(0xFF7C9EFF),
        const Color(0xFFFFC107),
        const Color(0xFF26A69A),
        const Color(0xFFE53935),
        const Color(0xFF8E24AA),
        const Color(0xFFFF6D00),
      ];
      for (var i = 0; i < count; i++) {
        final start = i * sweep;
        final base = fallbackColors[i % fallbackColors.length];
        final fill = Paint()..color = base; // solid vivid colors for contrast
        canvas.drawArc(arcRect, start, sweep, true, fill);
        canvas.drawArc(arcRect, start, sweep, true, sepPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: radius * 0.9);
        final mid = start + sweep / 2;
        final pos = Offset(
          center.dx + (radius * 0.58) * math.cos(mid) - tp.width / 2,
          center.dy + (radius * 0.58) * math.sin(mid) - tp.height / 2,
        );
        tp.paint(canvas, pos);
      }
    } else {
      for (var i = 0; i < segments.length; i++) {
        final seg = segments[i];
        final start = i * sweep;
        final fill = Paint()
          ..color = seg.color; // use solid segment colors for visibility
        canvas.drawArc(arcRect, start, sweep, true, fill);
        canvas.drawArc(arcRect, start, sweep, true, sepPaint);

        // Add currency symbol for money segments
        String displayLabel = seg.label;
        if (seg.type == PrizeType.money && !seg.label.contains('₦₲')) {
          // If label starts with +, put currency after the +
          if (seg.label.startsWith('+')) {
            displayLabel = '+₦₲${seg.label.substring(1)}';
          } else {
            displayLabel = '₦₲${seg.label}';
          }
        }

        final tp = TextPainter(
          text: TextSpan(
            text: displayLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: radius * 0.9);
        final mid = start + sweep / 2;
        final pos = Offset(
          center.dx + (radius * 0.58) * math.cos(mid) - tp.width / 2,
          center.dy + (radius * 0.58) * math.sin(mid) - tp.height / 2,
        );
        tp.paint(canvas, pos);
      }
    }

    // Center hub + inner rim for extra contrast
    final hub = Paint()..color = Colors.black;
    canvas.drawCircle(center, radius * 0.12, hub);
    final hubRim = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * 0.12, hubRim);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

// Removed _BottomPointerPainter class after removing the green arrow overlay.

class _MyRequestsPage extends StatelessWidget {
  const _MyRequestsPage({required this.store});
  final StoreDataStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final deposits = store.depositRequests;
        final withdrawals = store.withdrawRequests;
        final shipments = store.shipmentRequests;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: FloatingHeader(
            title: 'My Requests',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Deposit Requests
              if (deposits.isNotEmpty) ...[
                const Text(
                  'Deposit Requests',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...deposits.map((d) => Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.add_circle,
                                    color: Colors.green, size: 32),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₦₲${d.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        '${d.timestamp}',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11),
                                      ),
                                      Text(
                                        'Expires in: ${3 - DateTime.now().difference(d.timestamp).inDays} days',
                                        style: const TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: d.status == RequestStatus.pending
                                        ? Colors.orange
                                        : d.status == RequestStatus.approved
                                            ? Colors.green
                                            : Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    d.status.name.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            // Show admin comment if exists
                            if (d.adminComment != null &&
                                d.adminComment!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue
                                      .withAlpha((0.2 * 255).round()),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.blueAccent, width: 2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.comment,
                                            color: Colors.blueAccent, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Admin Comment:',
                                          style: TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      d.adminComment!,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 24),
              ],

              // Withdrawal Requests
              if (withdrawals.isNotEmpty) ...[
                const Text(
                  'Withdrawal Requests',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...withdrawals.map((w) => Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.remove_circle,
                                color: Colors.red, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₦₲${w.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Cash App: ${w.cashAppTag}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    '${w.timestamp}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: w.status == RequestStatus.pending
                                    ? Colors.orange
                                    : w.status == RequestStatus.approved
                                        ? Colors.green
                                        : Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                w.status.name.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 24),
              ],

              // Shipment Requests
              if (shipments.isNotEmpty) ...[
                const Text(
                  'Item Shipment Requests',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...shipments.map((s) => Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping,
                                color: Colors.blue, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.itemName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${s.fullName} - ${s.city}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    '${s.timestamp}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: s.status == RequestStatus.pending
                                    ? Colors.orange
                                    : s.status == RequestStatus.approved
                                        ? Colors.green
                                        : Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s.status.name.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],

              if (deposits.isEmpty && withdrawals.isEmpty && shipments.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'No requests yet',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
