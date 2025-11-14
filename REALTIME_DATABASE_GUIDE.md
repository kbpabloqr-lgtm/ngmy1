# Firebase Realtime Database Integration Guide

## Overview
Your app now has **complete Firebase Realtime Database integration** for storing and syncing:
- ✅ User profiles (username, email, bio, profile image)
- ✅ Media files (pictures, videos, documents, audio)
- ✅ User statistics (earnings, sessions, achievements)
- ✅ Real-time notifications
- ✅ Family Tree data
- ✅ Store/Betting data
- ✅ Ticket data

## Services Available

### 1. RealtimeDatabaseService
Located at: `lib/services/realtime_database_service.dart`

**Core Methods:**

#### Save User Profile
```dart
final db = RealtimeDatabaseService();
await db.saveUserProfile(
  userId: 'user123',
  username: 'john_doe',
  email: 'john@example.com',
  profileImageUrl: 'https://...',
  bio: 'Hello world!',
);
```

#### Update User Profile
```dart
await db.updateUserProfile(
  userId: 'user123',
  data: {
    'bio': 'Updated bio',
    'profileImageUrl': 'https://new-image.jpg',
  },
);
```

#### Get User Profile (One-time)
```dart
final profile = await db.getUserProfile('user123');
if (profile != null) {
  print('Username: ${profile['username']}');
  print('Email: ${profile['email']}');
}
```

#### Stream User Profile (Real-time)
```dart
db.streamUserProfile('user123').listen((profile) {
  if (profile != null) {
    print('Profile updated: ${profile['username']}');
  }
});
```

### 2. Media Management

#### Save Media URL
```dart
await db.saveMediaUrl(
  userId: 'user123',
  mediaId: 'photo_001',
  mediaUrl: 'https://firebasestorage.googleapis.com/...',
  mediaType: 'image',
  caption: 'My photo',
);
```

#### Get All User Media
```dart
final mediaList = await db.getUserMedia('user123');
for (var media in mediaList) {
  print('${media['type']}: ${media['url']}');
}
```

#### Stream User Media (Real-time)
```dart
db.streamUserMedia('user123').listen((mediaList) {
  print('Total media: ${mediaList.length}');
  for (var media in mediaList) {
    print('${media['mediaId']}: ${media['type']}');
  }
});
```

#### Delete Media
```dart
await db.deleteMedia(
  userId: 'user123',
  mediaId: 'photo_001',
);
```

### 3. Statistics & Data

#### Save User Statistics
```dart
await db.saveUserStats(
  userId: 'user123',
  stats: {
    'totalEarnings': 5000,
    'sessionsCompleted': 42,
    'achievements': ['level_1', 'first_checkin'],
    'familyTreeLevel': 3,
  },
);
```

#### Stream User Statistics (Real-time)
```dart
db.streamUserStats('user123').listen((stats) {
  if (stats != null) {
    print('Earnings: ${stats['totalEarnings']}');
    print('Sessions: ${stats['sessionsCompleted']}');
  }
});
```

### 4. Notifications

#### Save Notification
```dart
await db.saveNotification(
  userId: 'user123',
  title: 'Welcome!',
  message: 'Your profile is complete',
  type: 'info',
  data: {'link': '/profile'},
);
```

#### Stream User Notifications (Real-time)
```dart
db.streamUserNotifications('user123').listen((notifications) {
  for (var notif in notifications) {
    print('${notif['title']}: ${notif['message']}');
  }
});
```

### 5. Bulk Sync

#### Sync Multiple Data at Once
```dart
await db.bulkSyncData(
  userId: 'user123',
  path: 'familyTree',
  data: {
    'sessions': [...],
    'earnings': [...],
    'members': [...],
  },
);
```

#### Get All User Data
```dart
final allData = await db.getAllUserData('user123');
print('Profile: ${allData?['username']}');
print('Media: ${allData?['media']}');
print('Stats: ${allData?['stats']}');
```

#### Stream All User Data (Real-time)
```dart
db.streamAllUserData('user123').listen((data) {
  print('Complete user data updated');
});
```

## Database Structure

Your Firebase Realtime Database is organized as:

```
users/
  {userId}/
    userId
    username
    email
    profileImageUrl
    bio
    createdAt
    updatedAt
    media/
      {mediaId}/
        mediaId
        url
        type (image, video, document, audio)
        caption
        uploadedAt
    stats/
      totalEarnings
      sessionsCompleted
      achievements
      familyTreeLevel
      updatedAt
    notifications/
      {notificationId}/
        title
        message
        type
        read
        timestamp
        data (optional)
    familyTree/
      sessions
      earnings
      members
      checkIns
    store/
      wheelSpins
      prizes
      itemCounts
    betting/
      balance
      history
      transactions
    tickets/
      faceRecognitionData
      qrCodes
      approvalStatus
```

## Integration with Existing Systems

### Sync Family Tree Data to Realtime Database
```dart
// In family_tree_screen.dart
final db = RealtimeDatabaseService();
await db.saveUserStats(
  userId: currentUsername,
  stats: {
    'sessionsCompleted': _sessionCount,
    'totalEarnings': _totalEarnings,
    'currentSession': _currentSessionData,
  },
);
```

### Sync Store Wheel Results
```dart
// In ngmy_store_screen.dart
await db.bulkSyncData(
  userId: currentUsername,
  path: 'store',
  data: {
    'lastSpinResult': spinResult,
    'totalSpins': totalSpins,
    'itemsWon': itemWins,
  },
);
```

### Sync Media Uploads
```dart
// When uploading images/videos
final url = await CloudinaryService().uploadImage(imageFile);
await RealtimeDatabaseService().saveMediaUrl(
  userId: currentUsername,
  mediaId: DateTime.now().millisecondsSinceEpoch.toString(),
  mediaUrl: url,
  mediaType: 'image',
  caption: userCaption,
);
```

## Real-time Features

### Listen to Profile Changes
```dart
RealtimeDatabaseService().streamUserProfile(userId).listen((profile) {
  // Automatically update UI when profile changes on another device
  if (profile != null) {
    setState(() {
      _username = profile['username'];
      _bio = profile['bio'];
    });
  }
});
```

### Listen to Earnings Updates
```dart
RealtimeDatabaseService().streamUserStats(userId).listen((stats) {
  if (stats != null) {
    setState(() {
      _earnings = stats['totalEarnings'];
      _sessions = stats['sessionsCompleted'];
    });
  }
});
```

### Push Notifications
```dart
// Admin sends notification
await db.saveNotification(
  userId: 'user123',
  title: 'Bonus Earning!',
  message: 'You earned 500 points',
  type: 'reward',
);

// User's app automatically shows it via real-time stream
db.streamUserNotifications('user123').listen((notifications) {
  for (var notif in notifications.where((n) => n['read'] != true)) {
    _showNotification(notif['title'], notif['message']);
  }
});
```

## Firebase Console Setup

1. Go to **Firebase Console** → **Realtime Database**
2. **Create Database** (if not already created)
3. Set **Location** to your region
4. **Start in test mode** for development
5. **Update Security Rules** when ready for production:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "media": {
          ".indexOn": ["uploadedAt"]
        },
        "notifications": {
          ".indexOn": ["timestamp"]
        }
      }
    }
  }
}
```

## Offline Persistence

Your app automatically syncs data when connection is restored:
- ✅ Changes made offline are queued
- ✅ Data syncs automatically when online
- ✅ You can keep data synchronized with `keepSynced(true)`

## Error Handling

All methods return `bool` (success/failure) or nullable data:

```dart
// Safe error handling
final success = await db.saveUserProfile(
  userId: 'user123',
  username: 'john',
  email: 'john@example.com',
);

if (success) {
  print('Profile saved');
} else {
  print('Failed to save profile');
}
```

## Performance Tips

1. **Use real-time streams only when needed** - Don't stream every user's data
2. **Limit data queries** - Use specific paths instead of root queries
3. **Index frequently queried fields** - Add `.indexOn` in security rules
4. **Cache data locally** - Don't re-fetch data that rarely changes
5. **Batch updates** - Use `bulkSyncData()` for multiple changes

## Next Steps

1. ✅ Realtime Database service created
2. ✅ Integration with main.dart
3. 📝 **Next**: Update screens to use RealtimeDatabaseService for syncing data
4. 📝 **Next**: Set up security rules in Firebase Console
5. 📝 **Next**: Test offline persistence
