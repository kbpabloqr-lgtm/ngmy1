# Firebase Setup for NGMY Flutter App

## Steps to Complete Firebase Integration

### 1. Download google-services.json (REQUIRED)
1. Go to Firebase Console: https://console.firebase.google.com/
2. Select project **ngmy-733bb**
3. Go to **Project Settings** (gear icon)
4. Scroll to **Android apps** section
5. Find your app and click the **Download google-services.json** button
6. Place the file at: `android/app/google-services.json`

### 2. Check Android Build Configuration
The following has been automatically configured in your `android/build.gradle` files:
- Google Services Gradle plugin

### 3. Firestore Security Rules
Set these rules in Firestore Console for development:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /notifications/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4. Firebase Storage Rules
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /user_uploads/{userId}/{allPaths=**} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

### 5. Complete the Build
After placing google-services.json, run:
```bash
flutter clean
flutter pub get
flutter run --debug
```

## Firebase Services Available

The app now has complete Firebase integration with:

✅ **Authentication** - User login/signup
✅ **Firestore Database** - Real-time data syncing
✅ **Cloud Storage** - File uploads (images, videos, documents)
✅ **Cloud Messaging** - Push notifications
✅ **Analytics** - User tracking

## Usage in Code

### Initialize (already done in main.dart)
```dart
await FirebaseService().initialize();
```

### Save User Data
```dart
final firebase = FirebaseService();
await firebase.saveUserData(
  userId: 'user123',
  data: {'name': 'John', 'email': 'john@example.com'},
);
```

### Upload File
```dart
final url = await firebase.uploadFile(
  filePath: '/path/to/image.jpg',
  storagePath: 'user_uploads/user123/image.jpg',
);
```

### Query Data
```dart
final docs = await firebase.queryDocuments(
  collection: 'users',
  whereField: 'email',
  whereValue: 'john@example.com',
);
```

### Get FCM Token (for push notifications)
```dart
final token = await firebase.getFCMToken();
```

## Next Steps

1. Download and place `google-services.json` in `android/app/`
2. Run `flutter clean && flutter pub get && flutter run --debug`
3. Test Firebase connection in debug console
4. Set up Firestore security rules
5. Start using Firebase services in your screens

## Troubleshooting

- **Build fails after adding google-services.json**: Run `flutter clean` then try again
- **Firestore write permission denied**: Update your security rules
- **Notifications not working**: Check Firebase Cloud Messaging permissions in AndroidManifest.xml
