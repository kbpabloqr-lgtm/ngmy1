# Complete Notification Flow - Admin to User with Replies

## 🔄 How the System Works

### The Complete Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                    ADMIN DASHBOARD                               │
│  1. Click "Money" → Opens Money & Betting Controls              │
│  2. Click notification icon (🔔) → Opens notification screen    │
│  3. Stay on "Send" tab                                          │
│  4. Compose message and send to users                           │
└─────────────────────────────────────────────────────────────────┘
                                ↓
                    Message is sent to users
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                    HOME SCREEN (User View)                       │
│  1. Click "Money" menu → Opens Betting Screen                   │
│  2. Red badge appears on notification icon (🔔) with count      │
│  3. User clicks notification icon                               │
│  4. User sees message from admin                                │
│  5. User clicks "Reply" button                                  │
│  6. User types reply and sends                                  │
└─────────────────────────────────────────────────────────────────┘
                                ↓
                    Reply is sent to admin
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│            ADMIN DASHBOARD (Admin receives reply)                │
│  1. Badge appears on Money & Betting Controls notification icon │
│  2. Admin clicks notification icon                              │
│  3. Admin switches to "Inbox" tab                               │
│  4. Admin sees reply with purple "REPLY" badge                  │
│  5. Reply shows original message context                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📍 Step-by-Step: Admin Sends Notification

### Step 1: Open Admin Dashboard
1. From home screen, click **center admin button** (or however you access admin)
2. Dashboard opens with various options

### Step 2: Access Money & Betting Controls
1. Click **"Money"** from admin dashboard menu
2. **Money & Betting Controls** screen opens
3. See notification bell icon (🔔) in the top-right corner

### Step 3: Open Notification Composer
1. Click the **notification icon** in Money & Betting Controls
2. Screen opens with **two tabs**: "Send" and "Inbox"
3. Stay on **"Send" tab** (default)

### Step 4: Compose Message
1. **Title**: Enter message title (e.g., "System Update")
2. **Message**: Enter detailed message content
3. **Type**: Choose notification type:
   - **Info** (blue): General announcements
   - **Success** (green): Positive news
   - **Warning** (orange): Important notices
   - **Urgent** (red): Critical alerts
4. **Recipients**: Toggle between:
   - **"Send to all users"**: Sends to everyone
   - **Specific user**: Enter username in text field

### Step 5: Send Notification
1. Click **"Send Notification"** button
2. Green SnackBar confirms: "✅ Notification sent to all users!"
3. Message appears in "Recently Sent" section below

---

## 📱 Step-by-Step: User Receives & Replies

### Step 1: User Opens Money Menu
1. From **home screen**, user sees circular menu
2. User clicks **"Money"** menu item
3. **Betting Screen** opens

### Step 2: User Sees Notification Badge
1. **Red badge** appears on notification icon (🔔) in top-right
2. Badge shows **number of unread messages** (e.g., "1", "5", "99+")
3. Badge has **red glow effect**

### Step 3: User Opens Notifications
1. User clicks **notification icon**
2. **Enhanced Notifications Screen** opens
3. User sees list of notifications with:
   - **NEW badge** on unread messages
   - **Color-coded** by type (blue/green/orange/red)
   - **Timestamp** ("Just now", "5m ago", etc.)

### Step 4: User Reads Message
1. User taps on notification to expand (if needed)
2. Sees **title** and **full message** from admin
3. Sees two buttons at bottom:
   - **"Reply"** button (blue, with reply icon)
   - **"Mark Read"** button (colored by type)

### Step 5: User Replies to Admin
1. User clicks **"Reply"** button
2. **Reply dialog** opens showing:
   - Original message in quoted box
   - Text field for reply
   - Cancel and Send Reply buttons
3. User types their reply message
4. User clicks **"Send Reply"** button
5. Green SnackBar confirms: "✅ Reply sent to admin!"
6. Dialog closes automatically

---

## 📬 Step-by-Step: Admin Receives Reply

### Step 1: Admin Sees Badge
1. Admin is in **Money & Betting Controls** screen
2. **Red badge** appears on notification icon (🔔)
3. Badge shows **number of unread** (including replies)

### Step 2: Admin Opens Notifications
1. Admin clicks **notification icon**
2. Notification screen opens
3. Badge shows **unread count on "Inbox" tab**

### Step 3: Admin Switches to Inbox
1. Admin taps **"Inbox" tab**
2. Sees list of received notifications
3. **User replies** have special features:
   - **Purple reply icon** (↩️)
   - **"REPLY" badge** (purple) + "NEW" badge (red)
   - **Purple border glow** for unread replies

### Step 4: Admin Reads Reply
1. Admin sees reply message with:
   - **Title**: "Reply from [Username]"
   - **Quoted original message** in gray box
   - **User's reply text** below
2. Admin can:
   - **Mark as read/unread** (toggle button)
   - **Delete** (swipe left or tap delete icon)

---

## 🎨 Visual Indicators

### Badge Counters
| Location | When Appears | Color | Shows |
|----------|-------------|-------|-------|
| Betting Screen (User) | Unread notifications | Red | Count (1-99+) |
| Money & Betting Controls (Admin) | Unread notifications | Red | Count (1-99+) |
| Inbox Tab (Admin) | Unread in inbox | Red | Count on tab |

### Notification Types (Admin Sends)
| Type | Color | Icon | Badge | Use Case |
|------|-------|------|-------|----------|
| Info | Blue | ℹ️ | NEW | General updates |
| Success | Green | ✅ | NEW | Achievements |
| Warning | Orange | ⚠️ | NEW | Important notices |
| Urgent | Red | ❗ | NEW | Critical alerts |

### Reply Indicators (Admin Receives)
| Element | Color | Icon | Badge | Meaning |
|---------|-------|------|-------|---------|
| Reply | Purple | ↩️ | REPLY + NEW | User replied |
| Border | Purple glow | - | - | Unread reply |
| Original | Gray box | ➡️ | - | Quoted message |

---

## 🔧 Technical Details

### Storage Keys Used

**User Notifications** (Betting Screen):
```
Key: ${username}_notifications
Example: "JohnDoe_notifications"
```

**Admin Notifications** (Money & Betting Controls Inbox):
```
Key: ${admin_username}_notifications
Example: "Admin_notifications"
OR: "admin_notifications"
```

**Admin Sent History**:
```
Key: admin_sent_notifications
```

### Notification Data Structure

**Admin Sends to User**:
```json
{
  "id": "1728734400000",
  "title": "System Update",
  "message": "Maintenance scheduled for Sunday",
  "type": "info",
  "timestamp": "2025-10-12T14:30:00.000Z",
  "read": false,
  "fromAdmin": true
}
```

**User Replies to Admin**:
```json
{
  "id": "1728738000000",
  "title": "Reply from JohnDoe",
  "message": "Thanks for the update! Will plan accordingly.",
  "type": "info",
  "timestamp": "2025-10-12T15:30:00.000Z",
  "read": false,
  "fromUser": "JohnDoe",
  "replyTo": "1728734400000",
  "originalTitle": "System Update",
  "originalMessage": "Maintenance scheduled for Sunday"
}
```

### Reply Delivery System

When a user clicks "Reply":
1. **Dialog opens** with original message context
2. User enters reply text
3. System creates reply notification with:
   - `fromUser`: Username who replied
   - `replyTo`: Original notification ID
   - `originalTitle`: Title of original message
   - `originalMessage`: Content of original message
4. Reply is sent to **multiple possible admin keys**:
   - `${admin_username}_notifications`
   - `admin_notifications`
   - `Admin_notifications`
   - `ADMIN_notifications`
5. Admin receives notification in their inbox

---

## ✅ Features Summary

### What Users Can Do
- ✅ Receive notifications from admin in Betting Screen
- ✅ See badge counter showing unread count
- ✅ Read notifications with type-based colors
- ✅ **Reply to admin messages** (NEW!)
- ✅ Mark notifications as read/unread
- ✅ Delete notifications (swipe or button)
- ✅ Generate referral codes
- ✅ Auto-cleanup after 2 days

### What Admins Can Do
- ✅ Send notifications to all users or specific users
- ✅ Choose notification type (info/success/warning/urgent)
- ✅ View sent history (last 5 messages)
- ✅ Delete sent messages
- ✅ **Receive user replies in Inbox tab** (NEW!)
- ✅ See replies with special purple styling
- ✅ View original message context in replies
- ✅ Mark replies as read/unread
- ✅ Delete replies
- ✅ Badge counter shows unread count
- ✅ Auto-cleanup after 2 days

---

## 💡 Usage Examples

### Example 1: Admin Announces Maintenance
**Admin:**
1. Opens Money & Betting Controls → Notification icon
2. Stays on "Send" tab
3. Title: "Scheduled Maintenance"
4. Message: "System will be down Sunday 3-4 PM for updates."
5. Type: Warning (orange)
6. Send to all users ✓
7. Clicks "Send Notification"

**User:**
1. Opens Money menu → Betting Screen
2. Sees badge "1" on notification icon
3. Clicks icon, sees orange warning message
4. Reads message
5. Clicks "Reply" button
6. Types: "Got it, thanks for the heads up!"
7. Sends reply

**Admin:**
1. Sees badge appear on Money & Betting Controls icon
2. Opens notifications, switches to "Inbox" tab
3. Sees reply with purple "REPLY" badge
4. Reads: "Reply from JohnDoe"
5. Sees original message quoted
6. Reads user's reply

### Example 2: User Asks Question via Reply
**Admin:**
1. Sends notification: "New rewards available in store!"
2. Type: Success (green)

**User:**
1. Sees notification in Betting Screen
2. Clicks "Reply"
3. Types: "How do I claim the rewards?"
4. Sends reply

**Admin:**
1. Receives reply in Inbox
2. Sees question from user
3. Can respond by:
   - Sending another notification
   - Or handling through other support channels

---

## 🐛 Troubleshooting

### User Not Receiving Notifications
**Check:**
- Admin selected "Send to all users" or entered correct username
- User's username matches exactly (case-sensitive)
- User has opened Betting Screen (badge appears there)
- Notification is less than 2 days old

**Fix:**
- Re-send notification with correct username
- Verify username spelling
- Ask user to open Money menu → Betting Screen

### Admin Not Receiving Replies
**Check:**
- Admin username is stored correctly in BettingDataStore
- Admin has switched to "Inbox" tab (not "Send" tab)
- Reply is less than 2 days old
- Admin is checking Money & Betting Controls notification icon

**Fix:**
- Ensure admin uses consistent username
- Check multiple admin notification keys are being created
- Ask user to re-send reply if older than 2 days

### Badge Counter Not Updating
**Check:**
- Close and reopen notification screen
- Badge updates when returning from notifications
- Old notifications (2+ days) don't count toward badge

**Fix:**
- Navigate away and back to refresh badge
- Mark all as read to clear badge
- Wait for auto-cleanup to remove old notifications

### Reply Button Not Showing
**Check:**
- Notification has `fromAdmin: true` in data
- User is viewing their own notifications (not admin view)
- Notification is displayed in EnhancedNotificationsScreen

**Fix:**
- Admin must send with proper `fromAdmin` flag
- User must open notifications from Betting Screen
- Check notification data structure in SharedPreferences

---

## 📊 Notification Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│ DAY 0: Admin sends notification                             │
│  ↓ Stored in user's ${username}_notifications               │
│  ↓ Badge appears on user's Betting Screen                   │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ DAY 0-2: User can read, reply, mark read/unread            │
│  ↓ Reply creates new notification in admin inbox            │
│  ↓ Badge appears on admin's Money & Betting Controls       │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ DAY 2+: Auto-cleanup runs                                   │
│  ↓ Notification removed from storage                        │
│  ↓ Badge counter excludes old notifications                │
│  ↓ User can no longer see or reply to old notifications    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Points

1. **Money menu opens Betting Screen** for users
2. **Money & Betting Controls** is where admin manages notifications
3. **Notification icon in Betting Screen** is where users see messages
4. **Notification icon in Money & Betting Controls** is where admin sends and receives
5. **Replies go to admin's Inbox tab** with special purple styling
6. **Badge counters work on both screens** (user and admin)
7. **Auto-cleanup after 2 days** prevents clutter
8. **Users can only reply to admin messages** (not to other users)
9. **Admins can see who replied** in the "Reply from [Username]" title
10. **Original message context is preserved** in reply notifications

---

## ✨ Summary

The notification system now provides **full two-way communication**:

**Admin → User**: Send announcements, updates, alerts  
**User → Admin**: Reply with questions, confirmations, feedback

All managed through the **Money menu notification icons** on both screens with intuitive badge counters and visual indicators!
