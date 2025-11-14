import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GrowthAccountStatus {
  final String username;
  final bool isDisabled;
  final bool isSuspended;

  const GrowthAccountStatus({
    required this.username,
    required this.isDisabled,
    required this.isSuspended,
  });

  bool get blocksAllActions => isSuspended;
  bool get withdrawOnly => isDisabled && !isSuspended;

  String? messageForAction({
    required bool allowWithdraw,
    String? actionLabel,
  }) {
    if (blocksAllActions) {
      final label = actionLabel ?? 'This action';
      return '$label is unavailable while this account is suspended.';
    }

    if (withdrawOnly && !allowWithdraw) {
      final label = actionLabel ?? 'This action';
      return '$label is blocked while the account is disabled. Only withdrawals are available until the account is re-enabled.';
    }

    return null;
  }

  GrowthAccountStatus copyWith({
    String? username,
    bool? isDisabled,
    bool? isSuspended,
  }) {
    return GrowthAccountStatus(
      username: username ?? this.username,
      isDisabled: isDisabled ?? this.isDisabled,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }
}

class GrowthAccountDecision {
  final bool allowed;
  final GrowthAccountStatus status;
  final String? message;

  const GrowthAccountDecision({
    required this.allowed,
    required this.status,
    this.message,
  });
}

class GrowthAccountGuard {
  static Future<GrowthAccountStatus> load({
    SharedPreferences? prefs,
    String? username,
  }) async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    final resolvedUsername =
        username ?? sharedPrefs.getString('growth_user_name') ?? 'NGMY User';

    final disabled =
        sharedPrefs.getBool('${resolvedUsername}_disabled') ??
            sharedPrefs.getBool('user_disabled') ??
            false;
    final suspended =
        sharedPrefs.getBool('${resolvedUsername}_suspended') ??
            sharedPrefs.getBool('user_suspended') ??
            false;

    return GrowthAccountStatus(
      username: resolvedUsername,
      isDisabled: disabled,
      isSuspended: suspended,
    );
  }

  static Future<GrowthAccountDecision> evaluateAction({
    bool allowWithdraw = false,
    String? actionLabel,
    SharedPreferences? prefs,
    String? username,
  }) async {
    final status = await load(prefs: prefs, username: username);
    final message = status.messageForAction(
      allowWithdraw: allowWithdraw,
      actionLabel: actionLabel,
    );

    return GrowthAccountDecision(
      allowed: message == null,
      status: status,
      message: message,
    );
  }

  static void showBlockedMessage(
    BuildContext context,
    GrowthAccountDecision decision,
  ) {
    if (decision.allowed || decision.message == null) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(decision.message!),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
