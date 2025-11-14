# Admin Notification Management Guide

## 🎯 Quick Overview

Your notification system now works **identically** in both locations:
- **Betting Screen** (for users)
- **Money & Betting Controls** (for admins)

Both show badge counters with unread counts and provide full notification management!

---

## 📍 Where to Find Notifications

### Location 1: Betting Screen (User View)
- Tap the **notification bell icon** in the top-right
- Badge shows unread count (red circle with number)
- Opens full notifications screen with referral system

### Location 2: Money & Betting Controls (Admin View)
- Tap the **notification bell icon** in the AppBar
- Badge shows unread count (red circle with number)
- Opens notification composer with **two tabs**

---

## 🔔 Admin Notification Features

### Tab 1: Send Notifications
**Purpose**: Compose and send messages to users

**Features**:
- ✍️ **Compose message**: Title, message, and notification type
- 🎯 **Send to all users** or **specific user**
- 📊 **Type selection**: Info, Success, Warning, Urgent
- 📜 **Recently Sent**: View last 5 sent messages
- 🗑️ **Delete sent messages**: Swipe left or tap delete icon
- ⏰ **Auto-cleanup**: Messages older than 2 days auto-delete

**How to Send**:
1. Enter title and message
2. Choose notification type (info/success/warning/urgent)
3. Toggle "Send to all users" or enter specific username
4. Tap "Send Notification"

**How to Delete Sent Messages**:
- **Swipe left** on any message in "Recently Sent"
- OR tap the **red delete icon** next to the message

---

### Tab 2: Inbox (Your Notifications)
**Purpose**: View and manage notifications you received

**Features**:
- 📬 **View all notifications**: See messages sent to you
- 🔴 **Badge counter**: Shows unread count on tab
- 📧 **Mark as read/unread**: Toggle with button
- 🗑️ **Delete messages**: Swipe or tap delete
- 🎨 **Color-coded**: Type-based styling (blue/green/orange/red)
- 🆕 **NEW badge**: Visible on unread notifications
- ⏰ **Auto-cleanup**: Messages older than 2 days auto-delete

**How to Manage**:
1. Switch to **Inbox** tab
2. See all your notifications with unread count
3. **Mark as read**: Tap "Mark Read" button
4. **Mark as unread**: Tap "Mark Unread" button
5. **Delete**: Swipe left OR tap delete icon

---

## 🔢 Badge Counter Behavior

### When Badge Appears
- Red circle with number appears when you have **unread notifications**
- Shows count: "1", "5", "25", "99+" (max display)
- Badge appears on BOTH screens (betting & money menu)

### When Badge Updates
- **Increases**: When new notification received
- **Decreases**: When you mark notification as read
- **Disappears**: When all notifications are read (count = 0)
- **Auto-updates**: Refreshes when you close notification screen

### What Counts as Unread
- Only notifications from **last 2 days**
- Only notifications where `read` = `false`
- Older notifications (2+ days) are automatically excluded

---

## 🗑️ Delete Functionality

### Delete Received Notifications (Inbox)
**Two ways to delete**:
1. **Swipe left** on notification → Auto-deletes
2. **Tap delete icon** (trash can) → Confirms and deletes

**What happens**:
- Notification removed from your inbox
- Badge counter updates immediately
- Cannot be undone
- SnackBar shows "Notification deleted"

### Delete Sent Messages (Send Tab)
**Two ways to delete**:
1. **Swipe left** on sent message → Auto-deletes
2. **Tap delete icon** → Confirms and deletes

**What happens**:
- Message removed from sent history
- Does NOT delete from user inboxes (already delivered)
- Cannot be undone
- SnackBar shows "Sent message deleted"

### Auto-Delete (Both)
**Automatic cleanup after 2 days**:
- Runs when you open notification screen
- Removes all notifications older than 2 days
- Applies to both received and sent
- No notification shown (happens silently)

---

## 🎨 Notification Types & Colors

| Type    | Color  | Icon                | Use Case                          |
|---------|--------|---------------------|-----------------------------------|
| Info    | Blue   | ℹ️ Info circle      | General announcements, updates    |
| Success | Green  | ✅ Check circle     | Positive news, achievements       |
| Warning | Orange | ⚠️ Warning triangle | Important notices, reminders      |
| Urgent  | Red    | ❗ Priority high    | Critical alerts, immediate action |

**Visual indicators**:
- Unread notifications have **thicker borders** and **type color glow**
- Read notifications are **faded** with minimal styling
- NEW badge appears on all **unread** notifications

---

## 💡 Tips & Best Practices

### For Admins
1. **Check inbox regularly**: Badge counter shows when you have messages
2. **Clean up old messages**: Swipe to delete messages you've handled
3. **Use appropriate types**: Match notification type to urgency
4. **Monitor sent history**: See what you've sent recently
5. **Delete sent messages**: Keep history clean (auto-deletes after 2 days anyway)

### Notification Etiquette
- **Info**: Regular updates, news, announcements
- **Success**: Rewards, achievements, completed actions
- **Warning**: Reminders, policy changes, maintenance notices
- **Urgent**: Account issues, security alerts, immediate actions

### Managing Badge Counters
- Mark messages as read to clear badge
- Delete unneeded notifications to keep inbox clean
- Badge auto-updates - no manual refresh needed
- Check both screens (betting & money menu) for consistency

---

## 🔄 Workflow Examples

### Example 1: Send System-Wide Announcement
1. Open Money & Betting Controls → Tap notification icon
2. Stay on **Send** tab
3. Enable "Send to all users"
4. Choose "Info" type
5. Title: "System Maintenance"
6. Message: "Scheduled maintenance on Sunday 3-4 PM"
7. Tap "Send Notification"
8. See it in "Recently Sent" section

### Example 2: Check Your Inbox
1. Open Money & Betting Controls → Tap notification icon
2. See badge counter on notification icon (e.g., "3")
3. Switch to **Inbox** tab
4. Badge shows "3 unread" on tab
5. Review each notification
6. Tap "Mark Read" on each after reading
7. Badge counter decreases to 0
8. Badge disappears from icon

### Example 3: Delete Old Messages
1. Open notifications → Go to **Inbox** tab
2. Find old/irrelevant notification
3. **Swipe left** on the notification
4. Red delete background appears
5. Release to delete
6. SnackBar confirms deletion
7. Badge counter updates if it was unread

---

## ⚙️ Technical Details

### Storage Keys
- **Your notifications**: `${your_username}_notifications`
- **Sent history**: `admin_sent_notifications`
- **Referral codes**: `${username}_referral_code`

### Data Retention
- **Automatic deletion**: 2 days from timestamp
- **Manual deletion**: Immediate removal
- **No recovery**: Deleted messages cannot be restored

### Badge Calculation
```
unread_count = notifications
  .where(age < 2 days)
  .where(read == false)
  .length
```

---

## 🐛 Troubleshooting

### Badge Not Updating
- Close and reopen notification screen
- Badge refreshes automatically on screen close
- Check if notifications are older than 2 days

### Notifications Not Appearing
- Verify you're checking the correct screen
- Admin notifications go to `${admin_username}_notifications`
- User notifications are separate per user

### Delete Not Working
- Try swiping slower for swipe-to-delete
- Use delete icon button as alternative
- Check if notification is already gone (auto-deleted)

### Badge Showing Wrong Number
- Open notification screen to refresh
- Mark messages as read/unread to recalculate
- Old notifications (2+ days) are not counted

---

## ✅ Summary

**What You Can Do**:
- ✅ Send notifications to all users or specific users
- ✅ View your received notifications in Inbox tab
- ✅ See badge counters on both screens (betting & money menu)
- ✅ Mark notifications as read/unread
- ✅ Delete received notifications (swipe or button)
- ✅ Delete sent messages from history (swipe or button)
- ✅ Automatic cleanup after 2 days
- ✅ Color-coded notification types
- ✅ Real-time badge counter updates

**What Happens Automatically**:
- 🤖 Notifications older than 2 days are deleted
- 🤖 Badge counters update when you manage notifications
- 🤖 Read/unread status persists across sessions
- 🤖 Sent messages appear in history for 2 days

---

**Questions or Issues?**
Check the `NOTIFICATION_FEATURES.md` file for detailed technical documentation!
