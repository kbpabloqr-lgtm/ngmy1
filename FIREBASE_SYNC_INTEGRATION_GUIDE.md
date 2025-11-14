# 📱 Integration Guide: Syncing to Firebase

## How to Update Existing Screens

This guide shows you how to add Firebase sync calls to existing screens so data automatically persists to the cloud.

---

## 1. Syncing Notifications

### File: `lib/screens/admin_notification_composer_screen.dart`

**Location**: Find the `_sendNotification()` method around line 749

**Current Code** (saves to SharedPreferences only):
```dart
await _appendNotification(prefs, 'admin_notifications', payload);
```

**Add Firebase Sync** (add these lines after SharedPreferences save):
```dart
// Sync to Firebase
import '../services/data_sync_service.dart';

// Inside _sendNotification(), after local save
await DataSyncService().syncNotificationToFirebase(
  notificationId: payload['id'],
  title: title,
  message: body,
  timestamp: now.toIso8601String(),
  targetUserId: _sendToAll ? null : _targetUserController.text.trim(),
  extraData: {
    'scopes': scopes,
    'attachments': _attachments.map((a) => a.toJson()).toList(),
    'type': _notificationType,
  },
);
```

**Same for `_sendMemberMessage()`** around line 900:
```dart
// After local save
await DataSyncService().syncNotificationToFirebase(
  notificationId: payload['id'],
  title: payload['title'],
  message: message,
  timestamp: now.toIso8601String(),
  targetUserId: null, // Sent to admin
  extraData: {
    'scopes': scopes,
    'attachments': attachments,
    'fromUser': _currentUsername,
  },
);
```

---

## 2. Syncing Money/Wallet Transactions

### File: `lib/services/betting_data_store.dart`

**Location**: Find methods that change wallet balance

**Search for**: `_currentBalance`, `adjustBalance`, `addHistoryEntry`

**After each balance change**, add:
```dart
import 'data_sync_service.dart';

// Example: After adjustBalance(100)
await DataSyncService().syncMoneyTransaction(
  transactionId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
  type: 'credit', // or 'debit', 'bet', 'win'
  amount: 100.0,
  description: 'Won on wheel spin',
  timestamp: DateTime.now().toIso8601String(),
);

// Also sync updated balance
await DataSyncService().syncWalletBalance(
  totalBalance: _currentBalance, // or however you track it
  currency: 'USD',
);
```

**Pattern**:
```dart
// Before (local only)
_currentBalance += amount;

// After (local + cloud)
_currentBalance += amount;
await DataSyncService().syncMoneyTransaction(...);
await DataSyncService().syncWalletBalance(_currentBalance);
```

---

## 3. Syncing Profile Updates

### File: `lib/screens/family_tree_screen.dart`

**Location**: Find `_applyProfileChanges()` and profile image upload

**Pattern for profile updates**:
```dart
import '../services/data_sync_service.dart';

// After updating profile locally
await DataSyncService().syncProfileToFirebase(
  name: _nameController.text,
  bio: _bioController.text,
  profileImageUrl: uploadedImageUrl, // If image was uploaded
);
```

**For image uploads** (after Cloudinary upload):
```dart
import '../services/data_sync_service.dart';

// After successful Cloudinary upload
final cloudinaryUrl = response.secureUrl; // From Cloudinary response

// Sync image to Firebase
await DataSyncService().syncMediaToFirebase(
  mediaId: 'profile_image_${DateTime.now().millisecondsSinceEpoch}',
  mediaUrl: cloudinaryUrl,
  mediaType: 'image',
  caption: 'Profile Picture',
  fileName: 'profile_${username}.jpg',
);

// Also update profile with new image URL
await DataSyncService().syncProfileToFirebase(
  name: username,
  profileImageUrl: cloudinaryUrl,
);
```

---

## 4. Syncing Store/Wheel Wins

### File: `lib/services/store_data_store.dart`

**Location**: Find `_applyOutcome()` method (around where money is credited)

**Add sync after applying outcome**:
```dart
import 'data_sync_service.dart';

// After segment win is processed
await DataSyncService().syncStoreWinToFirebase(
  winId: 'win_${DateTime.now().millisecondsSinceEpoch}',
  itemWon: segment.label,
  segmentLabel: segment.label,
  timestamp: DateTime.now().toIso8601String(),
  extraData: {
    'moneyAmount': moneyAmount,
    'weight': segment.weight,
    'itemWon': itemName, // if it's an item
  },
);

// If money was won, also sync the transaction
if (moneyAmount > 0) {
  await DataSyncService().syncMoneyTransaction(
    transactionId: 'wheel_${DateTime.now().millisecondsSinceEpoch}',
    type: 'win',
    amount: moneyAmount,
    description: 'Store wheel win: ${segment.label}',
    timestamp: DateTime.now().toIso8601String(),
  );
}
```

---

## 5. Syncing Family Tree Data

### File: `lib/services/family_tree_data_store.dart` or family tree screens

**For check-ins**:
```dart
import '../services/data_sync_service.dart';

// After recording check-in
await DataSyncService().syncFamilyTreeData(
  type: 'checkin',
  data: {
    'timestamp': DateTime.now().toIso8601String(),
    'username': username,
    'bonus': earnedAmount,
  },
);
```

**For earnings/penalties**:
```dart
// For penalty application
await DataSyncService().syncFamilyTreeData(
  type: 'penalty',
  data: {
    'timestamp': DateTime.now().toIso8601String(),
    'username': username,
    'penaltyAmount': penaltyValue,
    'reason': 'Late check-in',
  },
);

// For earnings
await DataSyncService().syncFamilyTreeData(
  type: 'earning',
  data: {
    'timestamp': DateTime.now().toIso8601String(),
    'username': username,
    'amount': earningAmount,
    'source': 'session_completion',
  },
);
```

---

## 6. Syncing Betting/Gaming Transactions

### File: `lib/screens/` (wherever betting happens)

**Pattern**:
```dart
import '../services/data_sync_service.dart';

// After betting transaction completes
await DataSyncService().syncBettingTransactionToFirebase(
  transactionId: 'bet_${DateTime.now().millisecondsSinceEpoch}',
  gameType: 'dice_roll', // or 'card_game', 'slots', etc.
  betAmount: betValue,
  winAmount: winValue, // null if loss
  result: result, // 'win', 'loss', 'pending'
  timestamp: DateTime.now().toIso8601String(),
  extraData: {
    'multiplier': 2.5,
    'gameId': gameId,
  },
);
```

---

## 7. Syncing Media Uploads

### File: `lib/services/cloudinary_service.dart` or wherever media is uploaded

**Pattern**:
```dart
import 'data_sync_service.dart';

// After successful Cloudinary upload
final response = await _dio.post(...); // Cloudinary upload
final cloudinaryUrl = response.data['secure_url'];

// Sync to Firebase
await DataSyncService().syncMediaToFirebase(
  mediaId: 'media_${DateTime.now().millisecondsSinceEpoch}',
  mediaUrl: cloudinaryUrl,
  mediaType: mediaType, // 'image', 'video', 'audio', 'document'
  caption: userCaption,
  fileName: fileName,
);
```

---

## 8. Batch Sync (Emergency Recovery)

**Use this if you need to force-sync all local data to Firebase**:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'data_sync_service.dart';

// Get all local data
final prefs = await SharedPreferences.getInstance();
final allKeys = prefs.getKeys();

// Construct map of all data
Map<String, dynamic> allLocalData = {};
for (String key in allKeys) {
  final value = prefs.get(key);
  allLocalData[key] = value;
}

// Force sync everything
await DataSyncService().batchSyncLocalDataToFirebase(
  localData: allLocalData,
);
```

---

## Quick Checklist

- [ ] Add `import '../services/data_sync_service.dart';` to files that sync data
- [ ] Add sync calls after every money change
- [ ] Add sync calls after every notification sent
- [ ] Add sync calls after every profile update
- [ ] Add sync calls after every media upload
- [ ] Add sync calls after store/wheel wins
- [ ] Add sync calls after family tree check-ins
- [ ] Add sync calls after betting transactions
- [ ] Test on device - data should appear in Firebase Console immediately
- [ ] Test cross-device - login on new phone, data should sync from cloud

---

## Testing Your Sync

### Before Publishing:

1. **Monitor Firebase Console** while testing:
   - Open Firebase Console
   - Go to Realtime Database
   - Watch for updates in real-time

2. **Test offline then reconnect**:
   - Do actions offline
   - Turn on internet
   - Data should sync to cloud automatically

3. **Test cross-device**:
   - Login on Phone A, add data
   - Login on Phone B with same email
   - Data should appear on Phone B ✅

---

## If Sync Fails

**Check these**:
1. Is user logged in? `FirebaseAuth.instance.currentUser != null`
2. Is internet connected?
3. Are Firebase rules allowing writes? Check Firebase Console > Database > Rules
4. Check device logs: `flutter logs | grep Firebase`

---

## Performance Notes

- Sync happens **asynchronously** - doesn't block UI
- App works **offline** - data syncs when reconnected
- Batch operations are fine for up to ~1000 items
- For large batches, consider splitting into smaller calls

---

## Security Rules

Make sure your Firebase Realtime Database rules allow authenticated users to write their own data:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

This ensures:
- Users can only access their own `users/{uid}/` data
- Each user can only write to their own data
- No user can read other user's data

---

## Summary

**Every time data changes:**
1. Save to local SharedPreferences (fast, offline access)
2. Call appropriate `DataSyncService` method (syncs to cloud)
3. User data is now safe and accessible from any device

**This ensures:**
- ✅ Users never lose data
- ✅ Users can switch phones seamlessly
- ✅ All data persists across app uninstalls
- ✅ Offline-first experience with cloud backup
