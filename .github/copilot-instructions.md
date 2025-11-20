# Copilot Instructions

Flutter app using ChangeNotifier singletons for state management.

## Key Patterns

State Management:
```dart
final store = BettingDataStore.instance;
store.value = newValue;
store.notifyListeners();
```

Navigation:
```dart
Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute(builder: (_) => Screen())
);
```

Styling:
```dart
Colors.white.withAlpha((0.5 * 255).round())
```

## Services
- BettingDataStore.instance - wallet/games
- StoreDataStore.instance - store wheel  
- UserAccountService.instance - auth
- TicketDataStore.instance - tickets
- LearnDataStore.instance - content

## Rules
- Use ChangeNotifier singletons (no other state libs)
- Family Tree and Growth are SEPARATE (different SharedPreferences keys)
- Store wins must update BettingDataStore + add BettingHistoryEntry
- Don't assume assets exist (use fallbacks)
