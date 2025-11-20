# GitHub Copilot Instructions for ngmy1

This Flutter app follows specific patterns and conventions. Use these guidelines when generating code suggestions.

## Core Architecture

### App Structure
- **Entry point**: `lib/main.dart` → `AppRouter` → `lib/screens/home.dart`
- **Navigation**: Use `Navigator.push(MaterialPageRoute(...))` (no router package)
- **State management**: Singletons extending `ChangeNotifier` + `AnimatedBuilder`

### Key Services (Singletons)
- `BettingDataStore` - Wallet and games (`lib/services/betting_data_store.dart`)
- `StoreDataStore` - Store wheel (`lib/services/store_data_store.dart`)
- `TicketDataStore` - Tickets/QR codes (`lib/services/ticket_data_store.dart`)
- `UserAccountService` - User accounts (`lib/services/user_account_service.dart`)
- `LearnDataStore` - Learn system (`lib/services/learn_data_store.dart`)

### Data Models Location
- Betting: `lib/models/betting_models.dart`, `betting_entities.dart`
- Store: `lib/models/store_models.dart`
- Tickets: `lib/models/ticket_models.dart`
- Learn: `lib/models/learn_models.dart`, `media_models.dart`

## Critical Integration Points

### Startup Flow
`main.dart` → `AppRouter` checks `UserAccountService.isLoggedIn` → routes to `OnboardingScreen` or `HomeScreen`

### Store-Wallet Integration
When money is won, `StoreDataStore._applyOutcome` must:
- Credit `BettingDataStore`
- Add `BettingHistoryEntry`
- Item wins go to `pendingItemWins` and `itemCounts`

### System Separation
**IMPORTANT**: Family Tree and Growth are SEPARATE systems
- Use different SharedPreferences keys: `family_tree_` vs `growth_`
- Never mix their data or UI components

### Ticket System Flow
Face recognition → Code application → Admin approval → QR generation (via `TicketDataStore`)

### Wheel Component
- Custom `_WheelPainter` draws wedges with dark background
- Spin animation uses `AnimationController` with ease-out curve
- Result from `StoreDataStore.spin()` with weighted random
- Show SnackBar if no segments configured

## Code Patterns

### Styling
- Dark backgrounds with glass theme
- Semi-transparent whites: `withAlpha((x * 255).round())`
- Accent colors: teal, gold, purple, blue

### State Management
```dart
// Access singleton
final store = BettingDataStore.instance;

// Update and notify
store.someProperty = newValue;
store.notifyListeners();

// React to changes
AnimatedBuilder(
  animation: store,
  builder: (context, _) { /* UI */ }
)
```

### Navigation
```dart
Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute(builder: (_) => SomeScreen())
);
```

### Performance
- Use `RepaintBoundary` around heavy painters
- Use `ClipRRect` for images
- Avoid excessive blur effects

## Development Commands

### Setup (Windows)
```bash
# Enable symlinks (Developer Mode required)
flutter clean
flutter pub get
flutter doctor -v
```

### Run & Test
```bash
flutter analyze
flutter run -d windows
flutter test
```

## Common Tasks

### Add Wheel Segment
```dart
final segment = PrizeSegment(
  id: 'id', label: 'label', type: PrizeType.money,
  weight: 10, color: Colors.blue, moneyAmount: 100
);
StoreDataStore.instance.addSegment(segment);
```

### Credit Wallet
```dart
final wallet = BettingDataStore.instance;
wallet.adjustBalance(amount);
wallet.addHistoryEntry(BettingHistoryEntry(/* ... */));
```

### Create Singleton Service
```dart
class MyService extends ChangeNotifier {
  static final instance = MyService._();
  MyService._();
  
  Future<void> _loadFromStorage() async { /* ... */ }
  Future<void> _saveToStorage() async { /* ... */ }
}
```

## Important Rules

### Do NOT:
- Introduce new state management libraries
- Remove wallet-credit/history calls in `StoreDataStore._applyOutcome`
- Mix Family Tree and Growth system data/keys
- Overlay Spin button on wheel (place below)
- Assume assets exist (use fallbacks)

### Key Files:
- Wheel visuals: `lib/screens/store/ngmy_store_screen.dart` (`_WheelPainter`)
- Store logic: `lib/services/store_data_store.dart`
- Wallet UI: `lib/screens/admin_money_screen.dart`
- Menu items: `lib/widgets/glass_menu.dart`
- Image slider: `lib/widgets/image_slider.dart`
