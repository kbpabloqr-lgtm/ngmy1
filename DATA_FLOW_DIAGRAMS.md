# 📊 Data Flow Diagrams - Firebase Integration

## Diagram 1: Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        NGMY1 Flutter App                         │
│                                                                  │
│  ┌─────────────────────────┐      ┌──────────────────────────┐  │
│  │   Local Storage Layer   │      │   Firebase Layer         │  │
│  │  (SharedPreferences)    │      │  (Cloud Backup)          │  │
│  │                         │      │                          │  │
│  │  • Notifications        │  ←→  │  • Firestore (Profile)   │  │
│  │  • Messages             │      │  • Realtime DB (Sync)    │  │
│  │  • Money                │      │  • Auth (Users)          │  │
│  │  • Media URLs           │      │  • Storage (Files)       │  │
│  │  • Profiles             │      │                          │  │
│  │  • Family Tree          │      │                          │  │
│  │  • Betting History      │      │                          │  │
│  │  • Store Wins           │      │                          │  │
│  └─────────────────────────┘      └──────────────────────────┘  │
│           ↓                                    ↓                 │
│    [DataSyncService] ←──────────────────────→ [Firebase APIs]   │
│    Syncs changes to                  Stores & retrieves data     │
│    Firebase when possible                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

        WiFi/Mobile              Internet Required for Sync
           Connected                (Offline mode works locally)
```

---

## Diagram 2: User Registration Flow

```
Registration Flow:
═══════════════════════════════════════════════════════════════════

User enters:
  Name: "John Doe"
  Email: "john@example.com"  
  Password: "secure123"
           │
           ▼
    ┌─────────────────────┐
    │ FirebaseAuthService │
    │    .register()      │
    └─────────────────────┘
           │
    ┌──────┴──────┐
    │             │
    ▼             ▼
Firebase Auth    Firestore
(Validate)       (Save Profile)
Creates UID      Stores: name, email,
    │            bio, createdAt
    │            │
    ├─────┬──────┘
    │     │
    │     ▼
    │   Realtime DB
    │   (Mirror Profile)
    │   Stores same data
    │   for real-time sync
    │     │
    ├─────┤
    │     │
    ▼     ▼
Local Storage    Cloud Storage
(Copy locally)   (Backup)
user_id: 123     users/123/profile/...
profile: {...}   users/123/notifications/...
               users/123/media/...
               etc.

Result: User can now login from ANY device
        with same email & password
```

---

## Diagram 3: Login & Data Pull Flow

```
Login Flow:
═══════════════════════════════════════════════════════════════════

User enters:
  Email: "john@example.com"
  Password: "secure123"
           │
           ▼
    ┌──────────────────────┐
    │ FirebaseAuthService  │
    │    .login()          │
    └──────────────────────┘
           │
           ▼
    Firebase Auth
    (Validate credentials)
           │
           ├─ Invalid? → Return false → Show "Login failed"
           │
           └─ Valid? → Get UID (e.g., "user_123")
              │
              ▼
    ┌────────────────────────┐
    │ Pull ALL Cloud Data    │
    │ From users/user_123/   │
    └────────────────────────┘
              │
    ┌─────────┼─────────┬──────────┬──────────┬────────┬────────┐
    │         │         │          │          │        │        │
    ▼         ▼         ▼          ▼          ▼        ▼        ▼
  Profile  Messages Notifications Money   Media   FamilyTree  Store
  (name,  (history) (unread)    (balance) (URLs) (earnings)  (wins)
  email)  ────────── ────────── ────────── ────── ──────────  ─────
    │         │         │          │        │        │        │
    └─────────┴─────────┴──────────┴────────┴────────┴────────┘
              │
              ▼
    ┌──────────────────────────┐
    │ Save to Local Storage    │
    │ (SharedPreferences)      │
    │ Instant access, works    │
    │ offline                  │
    └──────────────────────────┘
              │
              ▼
    ┌──────────────────────────┐
    │ Show HomeScreen          │
    │ All data available now   │
    └──────────────────────────┘

User can now work OFFLINE using local data.
Changes sync to Firebase when online.
```

---

## Diagram 4: Data Sync Process

```
Data Sync Flow (Async, Non-Blocking):
═══════════════════════════════════════════════════════════════════

User Action                    App Response
(e.g., Send Notification)
         │
         ▼
    ┌──────────────┐
    │ Save Locally │
    │ (Fast)       │ ← User sees immediate feedback
    └──────────────┘   (notification sent)
         │
         ▼ (Async - background)
    ┌────────────────────────────┐
    │ DataSyncService.           │
    │ syncNotificationToFirebase()│
    └────────────────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 Online    Offline
    │         │
    ▼         ▼
Firebase   Queue
(Sync)     (Store
 ~500ms    locally)
    │         │
    ▼         └─┐
 Success       │
    │          │
    ▼          │
 Other         │
Devices    Later when
 Receive   online:
 Update       │
 Real-        ▼
 time    Firebase
          (Sync
           all changes)
```

---

## Diagram 5: Cross-Device Data Persistence

```
Switching Phones Scenario:
═══════════════════════════════════════════════════════════════════

PHONE A (Original Device)
┌─────────────────────────────────┐
│ 1. Login as john@test.com       │
│ 2. Send notification (synced)   │
│ 3. Add \$100 to wallet (synced) │
│ 4. Upload profile pic (synced)  │
│ 5. Logout                       │
└──────────────────────────────────┘
             │
             ▼
        Firebase Cloud
    ┌─────────────────────────┐
    │ users/uid_john/         │
    │ ├─ profile/             │
    │ │  └─ profileImageUrl   │
    │ ├─ notifications/       │
    │ │  └─ [notification]    │
    │ ├─ money/               │
    │ │  ├─ balance: 100      │
    │ │  └─ transactions/[]   │
    │ └─ media/               │
    │    └─ [image URL]       │
    └─────────────────────────┘
             │
             ▼
  PHONE B (New Device)
┌─────────────────────────────────┐
│ 1. Login as john@test.com       │
│ 2. Firebase Auth validates      │
│ 3. Pull ALL cloud data for john │
│                                 │
│ 4. User sees:                   │
│    ✓ Profile picture            │
│    ✓ Notification history       │
│    ✓ Wallet: \$100              │
│    ✓ All media                  │
│                                 │
│ ZERO DATA LOSS! ✓               │
└─────────────────────────────────┘

Key: Users can change phones seamlessly by logging in with same email
```

---

## Diagram 6: Offline-First Architecture

```
Offline Operation:
═══════════════════════════════════════════════════════════════════

Internet: OFF
     │
     ▼
User Action (Send Message)
     │
     ▼ (No network check needed)
Save to Local Storage
(Immediate success)
     │
     ├─ User sees: "Message sent" ✓
     │
     └─ DataSyncService.sync()
        ├─ Checks internet
        │
        └─ No internet?
           → Add to sync queue
              (stored locally)

Later... Internet: ON
     │
     ▼
App detects connection
     │
     ▼
DataSyncService.sync()
     │
     ▼
Sync queued changes to Firebase
     │
     ├─ Message sent ✓
     ├─ Money synced ✓
     ├─ Profile updated ✓
     └─ Media synced ✓

Result: NO DATA LOSS
        App works offline
        Sync happens automatically
```

---

## Diagram 7: Real-Time Sync Between Devices

```
Real-Time Update Flow:
═══════════════════════════════════════════════════════════════════

Device A              Firebase            Device B
┌──────────────┐     Realtime DB       ┌──────────────┐
│              │                       │              │
│ Send         │                       │              │
│ Notification │                       │              │
│              │                       │              │
└──────────────┘                       └──────────────┘
      │                                      ▲
      │                                      │
      ├─ Sync to Firebase                   │
      │  (DataSyncService)                  │
      │                                      │
      ▼                                      │
┌──────────────────────────────────────────┐│
│ Firebase Realtime Database               ││
│ users/uid/notifications/                 ││
│   └─ [new notification entry]            ││
│                                          ││
│ Broadcasts update to all connected       │
│ clients listening to this path           │
└──────────────────────────────────────────┘│
                   │                        │
                   └────────────────────────┘
                   Stream update
                   (Real-time)
                         │
                         ▼
                   Device B receives
                   notification in ~100ms
                   (Updates UI instantly)

All devices with same user ID stay in sync!
```

---

## Diagram 8: Integration Points

```
Services Needing Sync Calls:
═══════════════════════════════════════════════════════════════════

┌────────────────────────────────────────────────────────────────┐
│                   Your App Screens                              │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  admin_notification_composer_screen.dart                      │
│  ├─ After _sendNotification()                                 │
│  └─ → syncNotificationToFirebase()                            │
│                                                                │
│  betting_data_store.dart                                      │
│  ├─ After adjustBalance()                                     │
│  ├─ → syncMoneyTransaction()                                  │
│  └─ → syncWalletBalance()                                     │
│                                                                │
│  family_tree_screen.dart                                      │
│  ├─ After profile update                                      │
│  └─ → syncProfileToFirebase()                                 │
│                                                                │
│  [Media Upload Code]                                          │
│  ├─ After Cloudinary upload                                   │
│  ├─ → syncMediaToFirebase()                                   │
│  └─ → syncProfileToFirebase() [if profile pic]               │
│                                                                │
│  store_data_store.dart                                        │
│  ├─ After _applyOutcome()                                     │
│  └─ → syncStoreWinToFirebase()                                │
│                                                                │
│  [Family Tree Services]                                       │
│  ├─ After check-in                                            │
│  ├─ → syncFamilyTreeData(type: 'checkin')                     │
│  └─ → syncFamilyTreeData(type: 'earning')                     │
│                                                                │
│  [Betting/Gaming Screens]                                     │
│  ├─ After game result                                         │
│  └─ → syncBettingTransactionToFirebase()                      │
│                                                                │
└────────────────────────────────────────────────────────────────┘
                           │
                           ▼
        ┌─────────────────────────────────┐
        │   DataSyncService               │
        │   (Centralizes all syncing)     │
        └─────────────────────────────────┘
                           │
                           ▼
        ┌─────────────────────────────────┐
        │   Firebase Realtime Database    │
        │   (Stores all user data)        │
        └─────────────────────────────────┘
```

---

## Diagram 9: User Data Lifetime

```
User Data Lifecycle:
═══════════════════════════════════════════════════════════════════

1. CREATION
   User registers
   ├─ Email/password verified
   ├─ Profile created in Firestore
   ├─ Realtime DB synced
   └─ Local storage populated

2. ACTIVE USE
   User adds data (notifications, money, media, etc.)
   ├─ Save locally (fast)
   ├─ Sync to Firebase (background)
   └─ Other devices notified (real-time)

3. MULTI-DEVICE ACCESS
   Same user logs in on different device
   ├─ Authenticate with Firebase Auth
   ├─ Pull all cloud data
   ├─ Populate local storage
   └─ User sees everything

4. CONTINUATION
   User continues on new device
   ├─ All changes sync to same user ID
   ├─ Other devices see updates
   └─ Perfect continuity

5. PERSISTENCE
   User uninstalls app / switches phones
   ├─ Local data deleted (phone storage)
   ├─ Cloud data REMAINS (Firebase)
   └─ Reinstall/login recovers everything

6. RECOVERY
   User lost their phone
   ├─ Install on new device
   ├─ Login with same email/password
   ├─ ALL data restored from cloud
   └─ ZERO permanent data loss
```

---

## Diagram 10: Error Handling & Recovery

```
Error Scenarios & Recovery:
═══════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────┐
│ SCENARIO 1: Sync Fails (Network Issue)                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Action → Save Locally ✓  →  Sync to Firebase ✗             │
│                              (Network down)                │
│                                     │                      │
│                    ┌────────────────┴───────────────┐      │
│                    │ DataSyncService Handles:       │      │
│                    ├─ Log error                     │      │
│                    ├─ Keep local copy (safe)        │      │
│                    ├─ Queue for retry               │      │
│                    └─ Retry when online             │      │
│                                     │                      │
│                                     ▼                      │
│                            Network Restored               │
│                                     │                      │
│                                     ▼                      │
│                        Retry sync (auto) ✓                │
│                        Firebase updated ✓                 │
│                        Data safe ✓                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ SCENARIO 2: Firebase Unreachable (Maintenance)              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Action → Save Locally ✓  →  Sync to Firebase ✗             │
│                              (Server down)                 │
│                                     │                      │
│                      User continues working ✓              │
│                      Changes save locally ✓                │
│                      App works normally ✓                  │
│                                     │                      │
│                                     ▼                      │
│                      Firebase comes back                   │
│                                     │                      │
│                                     ▼                      │
│                      Auto-sync all changes ✓              │
│                      All data preserved ✓                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ SCENARIO 3: App Crashes                                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Action → Save Locally ✓  →  Crash ✗                        │
│                              (Before sync)                 │
│                                     │                      │
│                      Local data PRESERVED ✓                │
│                                     │                      │
│                                     ▼                      │
│                      User restarts app                     │
│                                     │                      │
│                                     ▼                      │
│                      Sync happens on startup ✓             │
│                      Firebase updated ✓                    │
│                      ZERO data loss ✓                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Summary Table: Before vs After

```
┌────────────────────┬──────────────────┬──────────────────┐
│ Feature            │ Before           │ After            │
├────────────────────┼──────────────────┼──────────────────┤
│ Authentication     │ Local only       │ Firebase Auth    │
│ Data Location      │ SharedPref only  │ Local + Cloud    │
│ Backup             │ None             │ Firebase (auto)  │
│ Cross-Device       │ ❌ Not possible  │ ✅ Seamless      │
│ Data Loss Risk     │ ⚠️ Very high     │ ✅ Very low      │
│ Offline Support    │ ⚠️ Limited       │ ✅ Full support  │
│ Sync Speed         │ N/A              │ ~500ms           │
│ Real-time Updates  │ ❌ None          │ ✅ <100ms        │
│ Multi-Device Sync  │ ❌ No            │ ✅ Yes           │
│ Analytics          │ ❌ Not working   │ ✅ Available     │
│ Disaster Recovery  │ ❌ No recovery   │ ✅ Full recovery │
│ Scaling            │ ⚠️ Limited       │ ✅ Unlimited     │
└────────────────────┴──────────────────┴──────────────────┘
```

---

## Conclusion

These diagrams show how the complete Firebase integration creates a robust,
persistent, and scalable data system where:

✅ Users never lose data
✅ Switching phones is seamless
✅ Everything works offline
✅ Multi-device sync is automatic
✅ Real-time updates across all devices
✅ Complete disaster recovery

**The infrastructure is ready. Now just add sync calls to existing screens!**
