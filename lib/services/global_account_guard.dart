import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalAccountStatus {
  final String username;
  final bool isDisabled;
  final bool isSuspended;

  const GlobalAccountStatus({
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

  GlobalAccountStatus copyWith({
    String? username,
    bool? isDisabled,
    bool? isSuspended,
  }) {
    return GlobalAccountStatus(
      username: username ?? this.username,
      isDisabled: isDisabled ?? this.isDisabled,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }
}

class GlobalAccountDecision {
  final bool allowed;
  final GlobalAccountStatus status;
  final String? message;

  const GlobalAccountDecision({
    required this.allowed,
    required this.status,
    this.message,
  });
}

class GlobalAccountGuard {
  static Future<GlobalAccountStatus> load({
    SharedPreferences? prefs,
    String? username,
  }) async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    final resolvedUsername =
        username ?? sharedPrefs.getString('global_user_name') ?? 'NGMY User';

    final disabled = sharedPrefs.getBool('${resolvedUsername}_global_disabled') ??
        sharedPrefs.getBool('${resolvedUsername}_disabled') ??
        sharedPrefs.getBool('global_user_disabled') ??
        sharedPrefs.getBool('user_disabled') ??
        false;
    final suspended = sharedPrefs.getBool('${resolvedUsername}_global_suspended') ??
        sharedPrefs.getBool('${resolvedUsername}_suspended') ??
        sharedPrefs.getBool('global_user_suspended') ??
        sharedPrefs.getBool('user_suspended') ??
        false;

    return GlobalAccountStatus(
      username: resolvedUsername,
      isDisabled: disabled,
      isSuspended: suspended,
    );
  }

  static Future<GlobalAccountDecision> evaluateAction({
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

    return GlobalAccountDecision(
      allowed: message == null,
      status: status,
      message: message,
    );
  }

  static void showBlockedMessage(
    BuildContext context,
    GlobalAccountDecision decision,
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
