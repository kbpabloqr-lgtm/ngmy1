import 'package:flutter/material.dart';
import 'package:ngmy1/models/betting_models.dart';
import 'package:ngmy1/services/betting_data_store.dart';
import 'package:ngmy1/services/store_data_store.dart';

/// Destinations available to receive wallet transfers from other menus.
enum TransferDestination { store, betting }

class WalletTransferService {
  WalletTransferService._();

  static String labelFor(TransferDestination destination) {
    switch (destination) {
      case TransferDestination.store:
        return 'NGMY Store wallet';
      case TransferDestination.betting:
        return 'Money & Betting wallet';
    }
  }

  static Future<void> credit({
    required TransferDestination destination,
    required double amount,
    required String sourceLabel,
  }) async {
    final now = DateTime.now();
    switch (destination) {
      case TransferDestination.store:
        StoreDataStore.instance.adjustStoreWalletBalance(amount);
        return;
      case TransferDestination.betting:
        final bettingStore = BettingDataStore.instance;
        await bettingStore.loadFromStorage();
        bettingStore.adjustBalance(amount);
        bettingStore.addHistoryEntry(
          BettingHistoryEntry(
            id: 'transfer_${now.millisecondsSinceEpoch}',
            title: '$sourceLabel Transfer',
            amount: amount,
            isCredit: true,
            category: TransactionCategory.deposit,
            icon: Icons.swap_horiz,
            color: Colors.tealAccent,
            timestamp: now,
          ),
        );
        return;
    }
  }
}
