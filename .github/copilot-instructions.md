# AI agent instructions for this repo

These notes make an AI productive quickly in this Flutter app. Keep changes aligned with the existing patterns and file layout.

## Architecture at a glance
- UI-first Flutter app with a dark glass theme. Entry is `lib/main.dart` → Smart `AppRouter` → `lib/screens/home.dart`.
- Navigation uses classic `Navigator.push(MaterialPageRoute(...))` from widgets, no router package.
- State management: local singletons extending `ChangeNotifier` + `AnimatedBuilder` in widgets. No external state libs.
  - Wallet/games: `lib/services/betting_data_store.dart` (singleton `BettingDataStore`).
  - Store wheel: `lib/services/store_data_store.dart` (singleton `StoreDataStore`).
  - Tickets/QR codes: `lib/services/ticket_data_store.dart` (singleton `TicketDataStore`).
  - User accounts: `lib/services/user_account_service.dart` (singleton `UserAccountService`).
  - Learn system: `lib/services/learn_data_store.dart` (singleton `LearnDataStore`).
- Data models:
  - Betting: `lib/models/betting_models.dart`, `lib/models/betting_entities.dart`.
  - Store: `lib/models/store_models.dart` (`PrizeSegment`, `PrizeType`, `ItemWin`).
  - Tickets: `lib/models/ticket_models.dart` (`TicketTemplate`, `AccessCode`, `CodeApplication`).
  - Learn: `lib/models/learn_models.dart`, `lib/models/media_models.dart`.
- Major screens:
  - Onboarding/Auth: `lib/screens/onboarding_screen.dart`, `lib/screens/login_screen.dart`.
  - Home: `lib/screens/home.dart` uses `lib/widgets/glass_menu.dart` and `lib/widgets/image_slider.dart`.
  - Store: `lib/screens/store/ngmy_store_screen.dart` (spinning wheel), `lib/screens/admin_store_screen.dart` (admin).
  - Family Tree: `lib/screens/family_tree_screen.dart` (check-ins, earnings), `lib/screens/admin_family_tree_screen.dart`.
  - Growth: `lib/screens/growth_premium.dart` (separate from Family Tree), growth admin screens.
  - Tickets: `lib/screens/tickets/` (face recognition, QR generation, admin approval).
  - Money: `lib/screens/admin_money_screen.dart`, `lib/screens/betting_history_screen.dart`.

## Cross-component behavior you must preserve
- **App startup flow**: `main.dart` → `AppRouter` checks `UserAccountService.isLoggedIn` → routes to `OnboardingScreen` or `HomeScreen`.
- **Store → Wallet integration**: When a money segment is won, `StoreDataStore._applyOutcome` credits `BettingDataStore` and adds a `BettingHistoryEntry`. Item wins are added to `pendingItemWins` and `itemCounts`.
- **Family Tree vs Growth separation**: These are SEPARATE systems with different SharedPreferences keys (`family_tree_` vs `growth_`). Don't cross-contaminate.
- **Check-in penalty system**: Late check-ins (after midnight) automatically trigger penalties via `growth_premium.dart`. Only affects users with active investments.
- **Ticket system flow**: Face recognition → Code application → Admin approval → QR generation. All managed by `TicketDataStore`.
- **Wheel drawing/animation**:
  - Custom painter `_WheelPainter` draws wedges; visible on dark bg (base fill + rim + separators).
  - Spin uses an `AnimationController` + ease-out curve rotating the whole wheel; result decided by `StoreDataStore.spin()` using weighted random.
  - Guards: If no segments configured, user spin shows a SnackBar; painter also shows a colorful fallback wheel (so the area is never blank).
- **Admin screens**: Each system has its own admin screen (store, family tree, growth, tickets, etc.) with CRUD operations and system controls.
- **Notification system**: Unified composer in `admin_notification_composer_screen.dart` sends to both home screen and dedicated notifications screen.

## Project conventions and patterns
- Styling: dark backgrounds, semi-transparent whites via `withAlpha((x * 255).round())`, and accent colors (teal, gold, purple, blue).
- Currency formatting is ad-hoc per screen (e.g., `_formatCurrency` in `admin_money_screen.dart`). If adding amounts, follow existing helpers in that file or a shared helper if present.
- Keep state singletons (`instance`) and call `notifyListeners()` after any mutation.
- Use `AnimatedBuilder(animation: store, ...)` to react to store updates; avoid introducing new state libraries unless asked.
- Navigation from menu items: check labels and route via `Navigator.of(context, rootNavigator: true).push(...)` where needed.
- Performance: prefer `RepaintBoundary` around heavy painters (wheel), avoid excessive blur; use `ClipRRect` for images.

## Build, run, and tests (Windows focus)
- Enable symlinks (required for plugins): open Developer Mode
  - PowerShell: `start ms-settings:developers` then enable Developer Mode.
- Toolchain check: `flutter doctor -v` (ensure Visual Studio Desktop C++, CMake, and Windows SDK).
- Clean/build:
  - `flutter clean` → `flutter pub get` → `flutter analyze` → `flutter run -d windows`.
- Tests: basic widget test lives at `test/widget_test.dart`. Run `flutter test`.

## Examples to follow when editing
- **Add a new wheel segment in admin**:
  - Create `PrizeSegment` with id/label/type/weight/color (and `moneyAmount` or `itemName`/`image`).
  - Call `StoreDataStore.instance.addSegment(seg)`; UI updates via `AnimatedBuilder`.
- **Credit wallet from anywhere**:
  - `final wallet = BettingDataStore.instance; wallet.adjustBalance(amount); wallet.addHistoryEntry(BettingHistoryEntry(...));`
- **Navigate from a menu tile** (see `lib/widgets/glass_menu.dart`):
  - Match on the tile label and push the screen via `MaterialPageRoute`.
- **Create a new admin screen**: Follow pattern in existing admin screens - separate SharedPreferences keys, `StatefulWidget` with system controls, save/load state.
- **Add a new singleton service**: Extend `ChangeNotifier`, create `static instance`, implement `_loadFromStorage()` and `_saveToStorage()` with SharedPreferences.

## Things to avoid
- Don't introduce new global state mechanisms or navigation packages without explicit approval.
- Don't remove wallet-credit/history calls in `StoreDataStore._applyOutcome`.
- Don't overlay the Spin button on the wheel; place it below the wheel (see `ngmy_store_screen.dart`).
- Don't assume assets exist—prefer fallbacks or guards (as with the image slider and wheel painter).
- Don't mix Family Tree and Growth system keys or UI components - they are completely separate.
- Don't modify penalty logic without understanding the automated triggers in `growth_premium.dart`.

## Where to start for common tasks
- Change wheel visuals/labels: `lib/screens/store/ngmy_store_screen.dart` (`_WheelPainter`).
- Change store logic/weights: `lib/services/store_data_store.dart`.
- Change wallet/betting UI: `lib/screens/admin_money_screen.dart` and `lib/screens/betting_history_screen.dart`.
- Add/edit menu items: `lib/widgets/glass_menu.dart`.
- Modify slider defaults: `lib/widgets/image_slider.dart` and `pubspec.yaml` (assets section).

If any of the above seems out-of-date, search the referenced files first—this codebase evolves iteratively and patterns are replicated rather than abstracted.
