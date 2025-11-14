import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

class _AutoSessionContributionResult {
  const _AutoSessionContributionResult({
    required this.contribution,
    required this.requiredTotal,
    required this.paidTotal,
    required this.outstanding,
    required this.outstandingBefore,
  });

  final double contribution;
  final double requiredTotal;
  final double paidTotal;
  final double outstanding;
  final double outstandingBefore;
}

enum AdminRequestSystem { growth, familyTree }

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({
    super.key,
    required this.system,
  });

  final AdminRequestSystem system;

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _withdrawRequests = [];
  List<Map<String, dynamic>> _depositRequests = [];
  List<Map<String, dynamic>> _historyRequests = [];
  bool _isLoading = true;

  DateTime _parseDate(dynamic rawDate) {
    final parsed = _tryParseDate(rawDate);
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _tryParseDate(dynamic rawDate) {
    if (rawDate is DateTime) {
      return rawDate;
    }
    if (rawDate is String && rawDate.isNotEmpty) {
      return DateTime.tryParse(rawDate);
    }
    return null;
  }

  String _formatDate(dynamic rawDate) {
    final parsed = _tryParseDate(rawDate);
    if (parsed == null) {
      return 'Unknown';
    }
    return parsed.toString().split('.').first;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRequests() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> withdrawPending = [];
      final List<Map<String, dynamic>> depositPending = [];
      final List<Map<String, dynamic>> history = [];
      final retentionCutoff = DateTime.now().subtract(const Duration(days: 4));
      // Prune non-pending receipts older than the retention window.

      DateTime? resolveRecordDate(Map<String, dynamic> source) {
        return _tryParseDate(source['processedAt']) ??
            _tryParseDate(source['respondedAt']) ??
            _tryParseDate(source['completedAt']) ??
            _tryParseDate(source['date']) ??
            _tryParseDate(source['timestamp']) ??
            _tryParseDate(source['submittedAt']);
      }

      void addRequest(Map<String, dynamic> request,
          {required bool isPending, required bool isWithdrawal}) {
        if (isPending) {
          if (isWithdrawal) {
            withdrawPending.add(request);
          } else {
            depositPending.add(request);
          }
        } else {
          history.add(request);
        }
      }

      if (widget.system == AdminRequestSystem.growth) {
        // Growth deposits
        try {
          final depositsJson = prefs.getString('deposit_requests') ?? '[]';
          final List<dynamic> depositsRaw = json.decode(depositsJson);
          final List<dynamic> filteredDeposits = [];
          var depositMutationDetected = false;

          for (final rawDeposit in depositsRaw) {
            if (rawDeposit is! Map<String, dynamic>) {
              continue;
            }
            final deposit = Map<String, dynamic>.from(rawDeposit);
            final status = deposit['status'] as String? ?? 'pending';
            final isPending = status == 'pending';
            final recordDate = resolveRecordDate(deposit);
            final shouldCull = !isPending &&
                recordDate != null &&
                recordDate.isBefore(retentionCutoff);
            if (shouldCull) {
              continue;
            }

            final rawScope = (deposit['scope'] as String?)?.toLowerCase();
            final scope = rawScope == 'global' ? 'global' : 'growth';
            if (rawScope != scope) {
              depositMutationDetected = true;
            }
            deposit['scope'] = scope;
            final originLabel = scope == 'global' ? 'Global Income' : 'Growth';

            filteredDeposits.add(deposit);
            final storageIndex = filteredDeposits.length - 1;
            final requestData = <String, dynamic>{
              'type': 'Deposit',
              'amount': (deposit['amount'] as num?)?.toDouble() ?? 0.0,
              'user': deposit['username'] ?? 'Unknown',
              'date': deposit['processedAt'] ??
                  deposit['timestamp'] ??
                  deposit['submittedAt'],
              'status': status,
              'index': storageIndex,
              'isDeposit': true,
              'isInvestment': false,
              'isWithdrawal': false,
              'storage': 'deposit_requests',
              'originLabel': originLabel,
              'scope': scope,
              'screenshotPath':
                  deposit['screenshotPath'] ?? deposit['screenshot_path'],
            };

            addRequest(requestData, isPending: isPending, isWithdrawal: false);
          }

          if (depositMutationDetected ||
              filteredDeposits.length != depositsRaw.length) {
            await prefs.setString(
              'deposit_requests',
              json.encode(filteredDeposits),
            );
          }
        } catch (e) {
          debugPrint('Error loading deposit requests: $e');
        }

        // Growth withdrawals
        try {
          final withdrawalsList =
              prefs.getStringList('withdrawal_requests') ?? [];
          final List<String> filteredWithdrawals = [];
          var withdrawalMutationDetected = false;

          for (final rawEntry in withdrawalsList) {
            final dynamic decoded = json.decode(rawEntry);
            if (decoded is! Map<String, dynamic>) {
              continue;
            }
            final withdrawal = Map<String, dynamic>.from(decoded);
            final status = withdrawal['status'] as String? ?? 'pending';
            final isPending = status == 'pending';
            final recordDate = resolveRecordDate(withdrawal);
            final shouldCull = !isPending &&
                recordDate != null &&
                recordDate.isBefore(retentionCutoff);
            if (shouldCull) {
              continue;
            }

            final rawScope = (withdrawal['scope'] as String?)?.toLowerCase();
            final scope = rawScope == 'global' ? 'global' : 'growth';
            if (rawScope != scope) {
              withdrawalMutationDetected = true;
            }
            withdrawal['scope'] = scope;
            final originLabel = scope == 'global' ? 'Global Income' : 'Growth';

            final resolvedUserId = withdrawal['userID'] ?? withdrawal['userId'];

            filteredWithdrawals.add(json.encode(withdrawal));
            final storageIndex = filteredWithdrawals.length - 1;
            final requestData = <String, dynamic>{
              'type': 'Withdrawal',
              'amount': (withdrawal['amount'] as num?)?.toDouble() ?? 0.0,
              'user': withdrawal['username'] ?? 'Unknown',
              'date': withdrawal['processedAt'] ??
                  withdrawal['submittedAt'] ??
                  withdrawal['timestamp'],
              'cashTag': withdrawal['cashTag'] ?? 'N/A',
              'status': status,
              'index': storageIndex,
              'isDeposit': false,
              'isInvestment': false,
              'isWithdrawal': true,
              'storage': 'withdrawal_requests',
              'originLabel': originLabel,
              'scope': scope,
              'requestId': withdrawal['id'],
              'contribution': (withdrawal['contribution'] as num?)?.toDouble(),
              'netAmount': (withdrawal['netAmount'] as num?)?.toDouble(),
              'autoSessionApplied': withdrawal['autoSessionApplied'] == true,
              'userId': resolvedUserId,
            };

            addRequest(requestData, isPending: isPending, isWithdrawal: true);
          }

          if (withdrawalMutationDetected ||
              filteredWithdrawals.length != withdrawalsList.length) {
            await prefs.setStringList(
              'withdrawal_requests',
              filteredWithdrawals,
            );
          }
        } catch (e) {
          debugPrint('Error loading withdrawal requests: $e');
        }
      } else {
        // Family Tree deposits
        try {
          final depositsJson =
              prefs.getString('family_tree_deposit_requests') ?? '[]';
          final List<dynamic> depositsRaw = json.decode(depositsJson);
          final List<dynamic> filteredDeposits = [];

          for (final rawDeposit in depositsRaw) {
            if (rawDeposit is! Map<String, dynamic>) {
              continue;
            }
            final deposit = Map<String, dynamic>.from(rawDeposit);
            final status = deposit['status'] as String? ?? 'pending';
            final isPending = status == 'pending';
            final recordDate = resolveRecordDate(deposit);
            final shouldCull = !isPending &&
                recordDate != null &&
                recordDate.isBefore(retentionCutoff);
            if (shouldCull) {
              continue;
            }

            filteredDeposits.add(deposit);
            final storageIndex = filteredDeposits.length - 1;
            final requestData = <String, dynamic>{
              'type': 'Deposit',
              'amount': (deposit['amount'] as num?)?.toDouble() ?? 0.0,
              'user': deposit['username'] ?? 'Unknown',
              'date': deposit['processedAt'] ??
                  deposit['timestamp'] ??
                  deposit['submittedAt'],
              'status': status,
              'index': storageIndex,
              'isDeposit': true,
              'isInvestment': false,
              'isWithdrawal': false,
              'storage': 'family_tree_deposit_requests',
              'originLabel': 'Family Tree',
              'screenshotPath':
                  deposit['screenshotPath'] ?? deposit['screenshot_path'],
            };

            addRequest(requestData, isPending: isPending, isWithdrawal: false);
          }

          if (filteredDeposits.length != depositsRaw.length) {
            await prefs.setString(
              'family_tree_deposit_requests',
              json.encode(filteredDeposits),
            );
          }
        } catch (e) {
          debugPrint('Error loading Family Tree deposit requests: $e');
        }

        // Family Tree withdrawals
        try {
          final withdrawalsList =
              prefs.getStringList('family_tree_withdrawal_requests') ?? [];
          final List<String> filteredWithdrawals = [];

          for (final rawEntry in withdrawalsList) {
            final dynamic decoded = json.decode(rawEntry);
            if (decoded is! Map<String, dynamic>) {
              continue;
            }
            final withdrawal = Map<String, dynamic>.from(decoded);
            final status = withdrawal['status'] as String? ?? 'pending';
            final isPending = status == 'pending';
            final recordDate = resolveRecordDate(withdrawal);
            final shouldCull = !isPending &&
                recordDate != null &&
                recordDate.isBefore(retentionCutoff);
            if (shouldCull) {
              continue;
            }

            filteredWithdrawals.add(json.encode(withdrawal));
            final storageIndex = filteredWithdrawals.length - 1;
            final requestData = <String, dynamic>{
              'type': 'Withdrawal',
              'amount': (withdrawal['amount'] as num?)?.toDouble() ?? 0.0,
              'user': withdrawal['username'] ?? 'Unknown',
              'userId': withdrawal['userId'],
              'date': withdrawal['processedAt'] ??
                  withdrawal['submittedAt'] ??
                  withdrawal['timestamp'],
              'cashTag': withdrawal['cashTag'] ?? 'N/A',
              'notes': withdrawal['notes'],
              'status': status,
              'index': storageIndex,
              'isDeposit': false,
              'isInvestment': false,
              'isWithdrawal': true,
              'storage': 'family_tree_withdrawal_requests',
              'originLabel': 'Family Tree',
              'requestId': withdrawal['id'],
              'contribution': (withdrawal['contribution'] as num?)?.toDouble(),
              'netAmount': (withdrawal['netAmount'] as num?)?.toDouble(),
              'autoSessionApplied': withdrawal['autoSessionApplied'] == true,
              'balanceAfter': (withdrawal['balanceAfter'] as num?)?.toDouble(),
            };

            addRequest(requestData, isPending: isPending, isWithdrawal: true);
          }

          if (filteredWithdrawals.length != withdrawalsList.length) {
            await prefs.setStringList(
              'family_tree_withdrawal_requests',
              filteredWithdrawals,
            );
          }
        } catch (e) {
          debugPrint('Error loading Family Tree withdrawal requests: $e');
        }

        // Family Tree investment proofs
        try {
          final proofsList =
              prefs.getStringList('family_tree_payment_proofs') ?? [];
          final List<String> filteredProofs = [];

          for (final rawEntry in proofsList) {
            final dynamic decoded = json.decode(rawEntry);
            if (decoded is! Map<String, dynamic>) {
              continue;
            }
            final proof = Map<String, dynamic>.from(decoded);
            final status = proof['status'] as String? ?? 'pending';
            final isPending = status == 'pending';
            final recordDate = resolveRecordDate(proof);
            final shouldCull = !isPending &&
                recordDate != null &&
                recordDate.isBefore(retentionCutoff);
            if (shouldCull) {
              continue;
            }

            filteredProofs.add(json.encode(proof));
            final storageIndex = filteredProofs.length - 1;
            final requestData = <String, dynamic>{
              'type': 'Investment',
              'amount': (proof['investmentAmount'] as num?)?.toDouble() ?? 0.0,
              'paidAmount': (proof['paidAmount'] as num?)?.toDouble() ?? 0.0,
              'user': proof['username'] ?? 'Unknown',
              'date': proof['respondedAt'] ?? proof['submittedAt'],
              'screenshotPath': proof['screenshotPath'],
              'status': status,
              'index': storageIndex,
              'isDeposit': false,
              'isInvestment': true,
              'isWithdrawal': false,
              'storage': 'family_tree_payment_proofs',
              'originLabel': 'Family Tree',
              'proofId': proof['id'],
            };

            addRequest(requestData, isPending: isPending, isWithdrawal: false);
          }

          if (filteredProofs.length != proofsList.length) {
            await prefs.setStringList(
              'family_tree_payment_proofs',
              filteredProofs,
            );
          }
        } catch (e) {
          debugPrint('Error loading investment requests: $e');
        }
      }

      // Sort by submitted date (newest first)
      try {
        int compareMaps(Map<String, dynamic> a, Map<String, dynamic> b) =>
            _parseDate(b['date']).compareTo(_parseDate(a['date']));
        withdrawPending.sort(compareMaps);
        depositPending.sort(compareMaps);
        history.sort(compareMaps);
      } catch (e) {
        debugPrint('Error sorting requests: $e');
      }

      if (mounted) {
        setState(() {
          _withdrawRequests = withdrawPending;
          _depositRequests = depositPending;
          _historyRequests = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('General error loading requests: $e');
      if (mounted) {
        setState(() {
          _withdrawRequests = [];
          _depositRequests = [];
          _historyRequests = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<_AutoSessionContributionResult> _applyAutoSessionContribution({
    required SharedPreferences prefs,
    required String username,
    required double grossAmount,
    required double balanceAfter,
    double? overrideContribution,
    double? overrideRequiredTotal,
  }) async {
    final paidKey = '${username}_family_tree_auto_session_paid_total';
    final requiredKey = '${username}_family_tree_auto_session_required_total';
    final enabled =
        prefs.getBool('${username}_family_tree_auto_session_enabled') ?? false;
    final existingPaid = prefs.getDouble(paidKey) ?? 0.0;

    double coverage =
        prefs.getDouble('${username}_family_tree_auto_session_coverage') ?? 0.0;
    if (coverage <= 0) {
      coverage =
          prefs.getDouble('${username}_family_tree_approved_investment') ??
              prefs.getDouble('family_tree_approved_investment') ??
              0.0;
    }

    double requiredTotal =
        prefs.getDouble(requiredKey) ?? (coverage > 0 ? coverage * 0.2 : 0.0);
    if (overrideRequiredTotal != null) {
      requiredTotal = overrideRequiredTotal.clamp(0.0, double.infinity);
    } else {
      requiredTotal = requiredTotal.clamp(0.0, double.infinity);
    }

    final outstandingBefore = math.max(0.0, requiredTotal - existingPaid);
    if (!enabled || grossAmount <= 0 || requiredTotal <= 0) {
      return _AutoSessionContributionResult(
        contribution: 0.0,
        requiredTotal: requiredTotal,
        paidTotal: existingPaid,
        outstanding: outstandingBefore,
        outstandingBefore: outstandingBefore,
      );
    }

    final desiredContribution = overrideContribution ?? (grossAmount * 0.10);
    final contributionCandidate = math.max(0.0, desiredContribution);
    final contribution = contributionCandidate <= 0
        ? 0.0
        : math.min(outstandingBefore, contributionCandidate);

    if (contribution <= 0) {
      return _AutoSessionContributionResult(
        contribution: 0.0,
        requiredTotal: requiredTotal,
        paidTotal: existingPaid,
        outstanding: outstandingBefore,
        outstandingBefore: outstandingBefore,
      );
    }

    final updatedPaidTotal = existingPaid + contribution;
    await prefs.setDouble(paidKey, updatedPaidTotal);
    await prefs.setDouble(requiredKey, requiredTotal);

    final historyKey = '${username}_family_tree_work_session_history';
    final history = prefs.getStringList(historyKey) ?? <String>[];
    final historyEntry = jsonEncode({
      'date': DateTime.now().toIso8601String(),
      'sessionType': 'auto_session_contribution',
      'charge': contribution,
      'balanceAfter': balanceAfter,
      'requiredTotal': requiredTotal,
      'paidTotal': updatedPaidTotal,
      'outstanding': math.max(0.0, requiredTotal - updatedPaidTotal),
    });
    history.insert(0, historyEntry);
    if (history.length > 30) {
      history.removeRange(30, history.length);
    }
    await prefs.setStringList(historyKey, history);

    return _AutoSessionContributionResult(
      contribution: contribution,
      requiredTotal: requiredTotal,
      paidTotal: updatedPaidTotal,
      outstanding: math.max(0.0, requiredTotal - updatedPaidTotal),
      outstandingBefore: outstandingBefore,
    );
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = request['storage'] as String? ?? '';
    final requestIndex = request['index'] as int? ?? -1;

    try {
      if (storage == 'family_tree_payment_proofs') {
        final proofs = prefs.getStringList('family_tree_payment_proofs') ?? [];
        if (requestIndex >= 0 && requestIndex < proofs.length) {
          final dynamic decoded = json.decode(proofs[requestIndex]);
          if (decoded is Map<String, dynamic>) {
            final proof = Map<String, dynamic>.from(decoded);
            proof['status'] = 'approved';
            proof['processedAt'] = DateTime.now().toIso8601String();
            proofs[requestIndex] = json.encode(proof);
            await prefs.setStringList('family_tree_payment_proofs', proofs);

            final username = proof['username'] as String? ?? '';
            final investmentAmount =
                (proof['investmentAmount'] as num?)?.toDouble() ?? 0.0;

            final previousAmount = prefs
                    .getDouble('${username}_family_tree_approved_investment') ??
                0.0;
            await prefs.setDouble('${username}_family_tree_approved_investment',
                investmentAmount);
            await prefs.setDouble(
                'family_tree_approved_investment', investmentAmount);
            if (investmentAmount > 0 && previousAmount <= 0) {
              final activationIso = DateTime.now().toIso8601String();
              await prefs.setString(
                  '${username}_family_tree_investment_activated_at',
                  activationIso);
              await prefs.setString(
                  'family_tree_investment_activated_at', activationIso);
            }

            await prefs
                .remove('${username}_family_tree_pending_investment_amount');
            await prefs.remove('family_tree_pending_investment_amount');
            await prefs.remove('${username}_family_tree_pending_proof_amount');
            await prefs.remove('family_tree_pending_proof_amount');
          }
        }
      } else if (storage == 'family_tree_deposit_requests') {
        final depositsJson =
            prefs.getString('family_tree_deposit_requests') ?? '[]';
        final List<dynamic> deposits = json.decode(depositsJson);
        if (requestIndex >= 0 && requestIndex < deposits.length) {
          final dynamic raw = deposits[requestIndex];
          if (raw is Map<String, dynamic>) {
            final deposit = Map<String, dynamic>.from(raw);
            deposit['status'] = 'approved';
            deposit['processedAt'] = DateTime.now().toIso8601String();
            deposits[requestIndex] = deposit;
            await prefs.setString(
                'family_tree_deposit_requests', json.encode(deposits));

            final username = deposit['username'] as String? ?? '';
            final amount = (deposit['amount'] as num?)?.toDouble() ?? 0.0;
            final balanceKey = '${username}_family_tree_balance';
            final currentBalance = prefs.getDouble(balanceKey) ?? 0.0;
            final newBalance = currentBalance + amount;
            await prefs.setDouble(balanceKey, newBalance);

            final totalDeposits =
                prefs.getDouble('family_tree_total_deposits') ?? 0.0;
            await prefs.setDouble(
                'family_tree_total_deposits', totalDeposits + amount);

            final totalBalanceKey = 'family_tree_total_balance';
            final currentTotalBalance = prefs.getDouble(totalBalanceKey) ?? 0.0;
            await prefs.setDouble(
                totalBalanceKey, currentTotalBalance + amount);
          }
        }
      } else if (storage == 'deposit_requests') {
        final depositsJson = prefs.getString('deposit_requests') ?? '[]';
        final List<dynamic> deposits = json.decode(depositsJson);
        if (requestIndex >= 0 && requestIndex < deposits.length) {
          final dynamic raw = deposits[requestIndex];
          if (raw is Map<String, dynamic>) {
            final deposit = Map<String, dynamic>.from(raw);
            deposit['status'] = 'approved';
            deposit['processedAt'] = DateTime.now().toIso8601String();
            final requestScope = (request['scope'] as String?)?.toLowerCase();
            final rawScope = (deposit['scope'] as String?)?.toLowerCase();
            final scope = requestScope == 'global' || rawScope == 'global'
                ? 'global'
                : 'growth';
            deposit['scope'] = scope;
            deposits[requestIndex] = deposit;
            await prefs.setString('deposit_requests', json.encode(deposits));

            final username = deposit['username'] as String? ?? '';
            final amount = (deposit['amount'] as num?)?.toDouble() ?? 0.0;
            if (scope == 'global') {
              final balanceKey = '${username}_global_balance';
              final currentBalance = prefs.getDouble(balanceKey) ?? 0.0;
              final newBalance = currentBalance + amount;
              await prefs.setDouble(balanceKey, newBalance);
              for (final variant in [
                '${username}_Global_balance',
                '${username}_GLOBAL_balance'
              ]) {
                if (prefs.containsKey(variant)) {
                  await prefs.setDouble(variant, newBalance);
                }
              }

              final activeGlobalUser = prefs.getString('global_user_name') ??
                  prefs.getString('Global_user_name');
              if (activeGlobalUser != null &&
                  activeGlobalUser.trim().toLowerCase() ==
                      username.trim().toLowerCase()) {
                await prefs.setDouble('global_total_balance', newBalance);
                for (final variant in [
                  'Global_total_balance',
                  'GLOBAL_total_balance'
                ]) {
                  if (prefs.containsKey(variant)) {
                    await prefs.setDouble(variant, newBalance);
                  }
                }
              }
            } else {
              final currentBalance =
                  prefs.getDouble('${username}_balance') ?? 0.0;
              await prefs.setDouble(
                  '${username}_balance', currentBalance + amount);
            }
          }
        }
      } else if (storage == 'family_tree_withdrawal_requests') {
        final withdrawalsList =
            prefs.getStringList('family_tree_withdrawal_requests') ?? [];
        if (requestIndex >= 0 && requestIndex < withdrawalsList.length) {
          final dynamic decoded = json.decode(withdrawalsList[requestIndex]);
          if (decoded is Map<String, dynamic>) {
            final withdrawal = Map<String, dynamic>.from(decoded);
            final username = withdrawal['username'] as String? ?? '';
            final rawAmount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
            final amount = rawAmount.abs();
            final balanceKey = '${username}_family_tree_balance';
            final currentBalance = prefs.getDouble(balanceKey) ?? 0.0;
            final recordedBalanceBefore =
                (withdrawal['balanceBefore'] as num?)?.toDouble();
            final recordedBalanceAfter =
                (withdrawal['balanceAfter'] as num?)?.toDouble();

            final baselineBalance = currentBalance > 0
                ? currentBalance
                : (recordedBalanceBefore ?? 0.0);
            final fallbackBalanceBefore =
                recordedBalanceBefore ?? baselineBalance;
            final computedBalanceAfter =
                math.max(0.0, baselineBalance - amount);

            double proposedBalance =
                recordedBalanceAfter ?? computedBalanceAfter;
            if (proposedBalance > baselineBalance + 0.0001) {
              proposedBalance = computedBalanceAfter;
            }
            final newBalance = proposedBalance.clamp(0.0, baselineBalance);

            final storedContribution =
                (withdrawal['contribution'] as num?)?.toDouble();
            final storedStandardFee =
                (withdrawal['standardFee'] as num?)?.toDouble() ?? 0.0;
            final storedRequiredTotal =
                (withdrawal['requiredTotal'] as num?)?.toDouble();

            final contributionResult = await _applyAutoSessionContribution(
              prefs: prefs,
              username: username,
              grossAmount: amount,
              balanceAfter: newBalance,
              overrideContribution: storedContribution,
              overrideRequiredTotal: storedRequiredTotal,
            );

            final standardFee = math.max(0.0, storedStandardFee);
            final totalFees = contributionResult.contribution + standardFee;
            final netAmount = (amount - totalFees).clamp(0.0, amount);
            final outstandingBefore = contributionResult.outstandingBefore;

            await prefs.setDouble(balanceKey, newBalance);

            final todayEarningsKey = '${username}_family_tree_today_earnings';
            final todayEarnings = prefs.getDouble(todayEarningsKey) ?? 0.0;
            await prefs.setDouble(
                '${username}_family_tree_last_claimed_amount', todayEarnings);

            final totalBalanceKey = 'family_tree_total_balance';
            final existingTotalBalance = prefs.getDouble(totalBalanceKey);
            if (existingTotalBalance != null) {
              final balanceBeforeForDelta =
                  math.max(baselineBalance, fallbackBalanceBefore);
              final delta = math.max(0.0, balanceBeforeForDelta - newBalance);
              final updatedTotalBalance = math.max(
                0.0,
                existingTotalBalance - delta,
              );
              await prefs.setDouble(totalBalanceKey, updatedTotalBalance);
            } else {
              await prefs.setDouble(totalBalanceKey, newBalance);
            }

            final totalWithdrawals =
                prefs.getDouble('family_tree_total_withdrawals') ?? 0.0;
            await prefs.setDouble(
                'family_tree_total_withdrawals', totalWithdrawals + netAmount);

            withdrawal['status'] = 'approved';
            withdrawal['processedAt'] = DateTime.now().toIso8601String();
            withdrawal['amount'] = amount;
            withdrawal['contribution'] = contributionResult.contribution;
            withdrawal['standardFee'] = standardFee;
            withdrawal['totalFee'] = totalFees;
            withdrawal['netAmount'] = netAmount;
            withdrawal['autoSessionApplied'] =
                contributionResult.contribution > 0;
            withdrawal['balanceAfter'] = newBalance;
            withdrawal['requiredTotal'] = contributionResult.requiredTotal;
            withdrawal['paidTotal'] = contributionResult.paidTotal;
            withdrawal['outstandingAfter'] = contributionResult.outstanding;
            withdrawal['balanceBefore'] = fallbackBalanceBefore;
            withdrawal['outstandingBefore'] = outstandingBefore;

            withdrawalsList[requestIndex] = json.encode(withdrawal);
            await prefs.setStringList(
                'family_tree_withdrawal_requests', withdrawalsList);

            await prefs.setString(
                '${username}_family_tree_withdraw_status', 'approved');
            await prefs
                .remove('${username}_family_tree_withdraw_pending_amount');
            await prefs
                .remove('${username}_family_tree_withdraw_pending_timestamp');
            await prefs.remove('${username}_family_tree_withdraw_request_id');
            await prefs.remove(
                '${username}_family_tree_withdraw_pending_contribution');
            await prefs.remove(
                '${username}_family_tree_withdraw_pending_standard_fee');
            await prefs
                .remove('${username}_family_tree_withdraw_pending_net_amount');
            await prefs.remove(
                '${username}_family_tree_withdraw_pending_balance_after');
            await prefs.remove(
                '${username}_family_tree_withdraw_pending_outstanding_after');
          }
        }
      } else if (storage == 'withdrawal_requests') {
        final withdrawalsList =
            prefs.getStringList('withdrawal_requests') ?? [];
        if (requestIndex >= 0 && requestIndex < withdrawalsList.length) {
          final dynamic decoded = json.decode(withdrawalsList[requestIndex]);
          if (decoded is Map<String, dynamic>) {
            final withdrawal = Map<String, dynamic>.from(decoded);
            final requestScope = (request['scope'] as String?)?.toLowerCase();
            final rawScope = (withdrawal['scope'] as String?)?.toLowerCase();
            final scope = requestScope == 'global' || rawScope == 'global'
                ? 'global'
                : 'growth';
            withdrawal['scope'] = scope;
            final username = withdrawal['username'] as String? ?? '';
            final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
            final balanceKey = scope == 'global'
                ? '${username}_global_balance'
                : '${username}_balance';
            final currentBalance = prefs.getDouble(balanceKey) ?? 0.0;
            final newBalance =
                (currentBalance - amount).clamp(0.0, double.infinity);

            withdrawal['status'] = 'approved';
            withdrawal['processedAt'] = DateTime.now().toIso8601String();
            withdrawal['netAmount'] = amount;
            withdrawalsList[requestIndex] = json.encode(withdrawal);
            await prefs.setStringList('withdrawal_requests', withdrawalsList);
            await prefs.setDouble(balanceKey, newBalance);
            if (scope == 'global') {
              for (final variant in [
                '${username}_Global_balance',
                '${username}_GLOBAL_balance',
              ]) {
                if (prefs.containsKey(variant)) {
                  await prefs.setDouble(variant, newBalance);
                }
              }

              final activeGlobalUser = prefs.getString('global_user_name') ??
                  prefs.getString('Global_user_name');
              if (activeGlobalUser != null &&
                  activeGlobalUser.trim().toLowerCase() ==
                      username.trim().toLowerCase()) {
                await prefs.setDouble('global_total_balance', newBalance);
                for (final variant in [
                  'Global_total_balance',
                  'GLOBAL_total_balance'
                ]) {
                  if (prefs.containsKey(variant)) {
                    await prefs.setDouble(variant, newBalance);
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error approving request from $storage: $e');
    }

    _showSuccessMessage('Request approved');
    await _loadAllRequests();
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = request['storage'] as String? ?? '';
    final requestIndex = request['index'] as int? ?? -1;

    try {
      if (storage == 'family_tree_payment_proofs') {
        final proofs = prefs.getStringList('family_tree_payment_proofs') ?? [];
        if (requestIndex >= 0 && requestIndex < proofs.length) {
          final dynamic decoded = json.decode(proofs[requestIndex]);
          if (decoded is Map<String, dynamic>) {
            final proof = Map<String, dynamic>.from(decoded);
            proof['status'] = 'rejected';
            proof['processedAt'] = DateTime.now().toIso8601String();
            proofs[requestIndex] = json.encode(proof);
            await prefs.setStringList('family_tree_payment_proofs', proofs);

            final username = proof['username'] as String? ?? '';
            await prefs
                .remove('${username}_family_tree_pending_investment_amount');
            await prefs.remove('family_tree_pending_investment_amount');
            await prefs.remove('${username}_family_tree_pending_proof_amount');
            await prefs.remove('family_tree_pending_proof_amount');
          }
        }
      } else if (storage == 'family_tree_deposit_requests') {
        final depositsJson =
            prefs.getString('family_tree_deposit_requests') ?? '[]';
        final List<dynamic> deposits = json.decode(depositsJson);
        if (requestIndex >= 0 && requestIndex < deposits.length) {
          final dynamic raw = deposits[requestIndex];
          if (raw is Map<String, dynamic>) {
            final deposit = Map<String, dynamic>.from(raw);
            deposit['status'] = 'rejected';
            deposit['processedAt'] = DateTime.now().toIso8601String();
            deposits[requestIndex] = deposit;
            await prefs.setString(
                'family_tree_deposit_requests', json.encode(deposits));
          }
        }
      } else if (storage == 'deposit_requests') {
        final depositsJson = prefs.getString('deposit_requests') ?? '[]';
        final List<dynamic> deposits = json.decode(depositsJson);
        if (requestIndex >= 0 && requestIndex < deposits.length) {
          final dynamic raw = deposits[requestIndex];
          if (raw is Map<String, dynamic>) {
            final deposit = Map<String, dynamic>.from(raw);
            deposit['status'] = 'rejected';
            deposit['processedAt'] = DateTime.now().toIso8601String();
            deposits[requestIndex] = deposit;
            await prefs.setString('deposit_requests', json.encode(deposits));
          }
        }
      } else if (storage == 'family_tree_withdrawal_requests') {
        final withdrawalsList =
            prefs.getStringList('family_tree_withdrawal_requests') ?? [];
        if (requestIndex >= 0 && requestIndex < withdrawalsList.length) {
          final dynamic decoded = json.decode(withdrawalsList[requestIndex]);
          if (decoded is Map<String, dynamic>) {
            final withdrawal = Map<String, dynamic>.from(decoded);
            withdrawal['status'] = 'rejected';
            withdrawal['processedAt'] = DateTime.now().toIso8601String();
            withdrawalsList[requestIndex] = json.encode(withdrawal);
            await prefs.setStringList(
                'family_tree_withdrawal_requests', withdrawalsList);

            final username = withdrawal['username'] as String? ?? '';
            await prefs.setString(
                '${username}_family_tree_withdraw_status', 'rejected');
            await prefs
                .remove('${username}_family_tree_withdraw_pending_amount');
            await prefs
                .remove('${username}_family_tree_withdraw_pending_timestamp');
            await prefs.remove('${username}_family_tree_withdraw_request_id');
            await prefs.remove(
                '${username}_family_tree_withdraw_pending_contribution');
            await prefs.remove(
                '${username}_family_tree_withdraw_pending_standard_fee');
            await prefs
                .remove('${username}_family_tree_withdraw_pending_net_amount');
            await prefs.remove(
                '${username}_family_tree_withdraw_pending_balance_after');
            await prefs.remove(
                '${username}_family_tree_withdraw_pending_outstanding_after');
          }
        }
      } else if (storage == 'withdrawal_requests') {
        final withdrawalsList =
            prefs.getStringList('withdrawal_requests') ?? [];
        if (requestIndex >= 0 && requestIndex < withdrawalsList.length) {
          final dynamic decoded = json.decode(withdrawalsList[requestIndex]);
          if (decoded is Map<String, dynamic>) {
            final withdrawal = Map<String, dynamic>.from(decoded);
            withdrawal['status'] = 'rejected';
            withdrawal['processedAt'] = DateTime.now().toIso8601String();
            final requestScope = (request['scope'] as String?)?.toLowerCase();
            final rawScope = (withdrawal['scope'] as String?)?.toLowerCase();
            final scope = requestScope == 'global' || rawScope == 'global'
                ? 'global'
                : 'growth';
            withdrawal['scope'] = scope;
            withdrawalsList[requestIndex] = json.encode(withdrawal);
            await prefs.setStringList('withdrawal_requests', withdrawalsList);

            final username = withdrawal['username'] as String? ?? '';
            final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
            final balanceKey = scope == 'global'
                ? '${username}_global_balance'
                : '${username}_balance';
            final currentBalance = prefs.getDouble(balanceKey) ?? 0.0;
            final newBalance = currentBalance + amount;
            await prefs.setDouble(balanceKey, newBalance);
            if (scope == 'global') {
              for (final variant in [
                '${username}_Global_balance',
                '${username}_GLOBAL_balance',
              ]) {
                if (prefs.containsKey(variant)) {
                  await prefs.setDouble(variant, newBalance);
                }
              }

              final activeGlobalUser = prefs.getString('global_user_name') ??
                  prefs.getString('Global_user_name');
              if (activeGlobalUser != null &&
                  activeGlobalUser.trim().toLowerCase() ==
                      username.trim().toLowerCase()) {
                await prefs.setDouble('global_total_balance', newBalance);
                for (final variant in [
                  'Global_total_balance',
                  'GLOBAL_total_balance'
                ]) {
                  if (prefs.containsKey(variant)) {
                    await prefs.setDouble(variant, newBalance);
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error rejecting request from $storage: $e');
    }

    _showSuccessMessage('Request rejected');
    await _loadAllRequests();
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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
              Color(0xFF0D4D3D),
              Color(0xFF1A6B54),
              Color(0xFF0D4D3D),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRequestsList(
                            _withdrawRequests,
                            showActions: true,
                            emptyIcon: Icons.account_balance_wallet_outlined,
                            emptyMessage: 'No withdrawal requests',
                          ),
                          _buildRequestsList(
                            _depositRequests,
                            showActions: true,
                            emptyIcon: Icons.account_balance,
                            emptyMessage: 'No deposit requests',
                          ),
                          _buildRequestsList(
                            _historyRequests,
                            showActions: false,
                            emptyIcon: Icons.history,
                            emptyMessage: 'No history available',
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = widget.system == AdminRequestSystem.growth
        ? 'Growth Request Management'
        : 'Family Tree Request Management';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadAllRequests,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withAlpha((0.6 * 255).round()),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 8),
                Text('Withdraw (${_withdrawRequests.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance),
                const SizedBox(width: 8),
                Text('Deposit (${_depositRequests.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Text('History (${_historyRequests.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(
    List<Map<String, dynamic>> requests, {
    required bool showActions,
    required IconData emptyIcon,
    required String emptyMessage,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 64,
              color: Colors.white.withAlpha((0.4 * 255).round()),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).round()),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) =>
          _buildRequestCard(requests[index], showActions),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool showActions) {
    Color typeColor;
    IconData typeIcon;

    switch (request['type']) {
      case 'Deposit':
        typeColor = Colors.green;
        typeIcon = Icons.add_circle;
        break;
      case 'Withdrawal':
        typeColor = Colors.red;
        typeIcon = Icons.remove_circle;
        break;
      case 'Investment':
        typeColor = Colors.purple;
        typeIcon = Icons.trending_up;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help;
    }
    final originLabel = request['originLabel'] as String? ?? 'General';
    final userId = request['userId'] as String?;
    final cashTag = request['cashTag'] as String?;
    final notes = request['notes'] as String?;
    final contribution = (request['contribution'] as num?)?.toDouble();
    final netAmount = (request['netAmount'] as num?)?.toDouble();
    final balanceAfter = (request['balanceAfter'] as num?)?.toDouble();
    final amountValue = (request['amount'] as num?)?.toDouble();
    final dynamic screenshotSource =
        request['screenshotPath'] ?? request['screenshot_path'];
    final String? screenshotPath =
        (screenshotSource is String && screenshotSource.isNotEmpty)
            ? screenshotSource
            : null;
    final File? screenshotFile =
        screenshotPath != null ? _resolveScreenshotFile(screenshotPath) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: typeColor,
            width: 1,
          ),
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          title: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  request['type'],
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '₦${(request['amount'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'User: ${request['user']}',
                style: const TextStyle(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Date: ${_formatDate(request['date'])}',
                style: const TextStyle(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'System: $originLabel',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              if (userId != null && (userId.isNotEmpty))
                Text(
                  'ID: $userId',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              if (!showActions)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: request['status'] == 'approved'
                        ? Colors.green
                        : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request['status'].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (request['type'] == 'Withdrawal' &&
                      cashTag != null &&
                      cashTag.isNotEmpty &&
                      cashTag != 'N/A')
                    Text(
                      'Cash Tag: ${request['cashTag']}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (request['type'] == 'Withdrawal' &&
                      contribution != null &&
                      contribution > 0)
                    Text(
                      'Auto Session Contribution: ₦${contribution.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.tealAccent),
                    ),
                  if (request['type'] == 'Withdrawal' &&
                      netAmount != null &&
                      amountValue != null &&
                      (netAmount - amountValue).abs() > 0.01)
                    Text(
                      'Net Payout: ₦${netAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (request['type'] == 'Withdrawal' && balanceAfter != null)
                    Text(
                      'Balance After Approval: ₦${balanceAfter.toStringAsFixed(2)}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  if (request['type'] == 'Investment') ...[
                    Text(
                      'Paid Amount: ₦${(request['paidAmount'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  if (screenshotPath != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Attached Screenshot:',
                      style: TextStyle(
                          color: Colors.white.withAlpha((0.75 * 255).round()),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (screenshotFile != null) ...[
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showFullScreenImage(screenshotFile.path),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 200,
                            width: double.infinity,
                            child: InteractiveViewer(
                              minScale: 0.9,
                              maxScale: 4.0,
                              child: Image.file(
                                screenshotFile,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.white
                                        .withAlpha((0.08 * 255).round()),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.broken_image,
                                            color: Colors.white54, size: 40),
                                        SizedBox(height: 8),
                                        Text('Unable to preview screenshot',
                                            style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _extractFileName(screenshotFile.path),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _showFullScreenImage(screenshotFile.path),
                            icon: const Icon(Icons.open_in_full,
                                color: Colors.white70, size: 18),
                            label: const Text(
                              'Open Fullscreen',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent
                                .withAlpha((0.35 * 255).round()),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Screenshot file missing or inaccessible.',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              screenshotPath,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ask the user to re-upload the proof if validation is required.',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      notes,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                  if (showActions) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveRequest(request),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _rejectRequest(request),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractFileName(String path) {
    if (path.isEmpty) {
      return 'screenshot.png';
    }
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : path;
  }

  File? _resolveScreenshotFile(String rawPath) {
    if (rawPath.isEmpty) {
      return null;
    }
    try {
      String candidate = rawPath;
      if (candidate.startsWith('file://')) {
        candidate = Uri.parse(candidate).toFilePath();
      }

      File file = File(candidate);
      if (file.existsSync()) {
        return file;
      }

      final decoded = Uri.decodeFull(candidate);
      if (decoded != candidate) {
        file = File(decoded);
        if (file.existsSync()) {
          return file;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to resolve screenshot file: $error');
      debugPrint('$stackTrace');
    }
    return null;
  }

  Future<void> _showFullScreenImage(String imagePath) async {
    final file = _resolveScreenshotFile(imagePath);
    if (file == null || !await file.exists()) {
      if (!mounted) return;
      _showSnack(
        'Screenshot file not found. Ask the user to resubmit their proof.',
        color: Colors.red,
      );
      return;
    }

    if (!mounted) {
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
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.08 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.broken_image,
                                color: Colors.white54, size: 56),
                            SizedBox(height: 12),
                            Text(
                              'Unable to display screenshot',
                              style: TextStyle(color: Colors.white70),
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
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message, {Color color = const Color(0xFF1E3A5F)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
