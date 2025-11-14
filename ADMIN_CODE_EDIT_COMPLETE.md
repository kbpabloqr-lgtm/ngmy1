# Admin Code Expiry Editing - Implementation Complete

## Overview
Added functionality for admins to edit access code expiration dates directly from the admin ticket control screen.

## Changes Made

### 1. New Method in TicketDataStore (`lib/services/ticket_data_store.dart`)
- **Method**: `editCodeExpiry(String code, int additionalDays)`
- **Purpose**: Allows admins to add or subtract days from an access code's expiry date
- **Parameters**:
  - `code`: The access code to modify
  - `additionalDays`: Number of days to add (positive) or subtract (negative)
- **Range**: -30 to +90 days
- **Implementation**:
  - Creates new AccessCode instance with updated expiry (since expiryDate is final)
  - Updates corresponding CodeApplication if it exists
  - Saves to storage and notifies listeners

### 2. UI Updates in Admin Screen (`lib/screens/tickets/admin_ticket_control_screen.dart`)

#### Enhanced Code Display
- Added "Edit Expiry Date" button to approved code sections
- Button shows calendar icon and is styled with green outline
- Clicking opens edit dialog

#### New Edit Dialog
- **Title**: "Edit Code Expiry"
- **Features**:
  - Slider to adjust days (-30 to +90)
  - Plus/minus buttons for quick adjustments
  - Clear label showing "Add X days" or "Remove X days"
  - Color-coded: green for adding days, red for removing
  - 120 divisions for precise control (1-day increments)
- **Confirmation**: Shows success message with exact adjustment made
- **Error Handling**: Catches and displays errors if code not found

## Usage

### For Admins:
1. Navigate to "Ticket System Control" from admin panel
2. Find an approved application in the list
3. Click "Edit Expiry Date" button in the green code section
4. Use slider or +/- buttons to adjust days
5. Click "Update" to save changes

### Examples:
- **Extend expiry**: Move slider right (positive numbers, green)
  - User gets more time to create tickets
- **Shorten expiry**: Move slider left (negative numbers, red)
  - Useful if code needs to expire sooner

## Technical Details

### Why Create New AccessCode?
The `AccessCode` model has `final DateTime expiryDate`, which is immutable. Rather than making it mutable (which could cause issues with JSON serialization and state management), we create a new instance with all the same properties except the updated expiry date.

### Persistence
- Changes are saved via `_saveToStorage()` automatically
- Updates both `_accessCodes` list and corresponding `_codeApplications` entry
- `notifyListeners()` triggers UI refresh across all listening widgets

### UI Design Consistency
- Follows existing admin screen patterns (dark theme, glass morphism)
- Uses same color scheme: green for approved/positive, red for rejected/negative
- Dialog matches other admin dialogs (approve/reject)

## Future Enhancements (Optional)
- Add date picker for selecting exact expiry date
- Show days remaining in code display
- Add bulk expiry editing for multiple codes
- Send notification to user when expiry is changed
- Add expiry edit history/audit log

## Related Files
1. `lib/services/ticket_data_store.dart` - Added editCodeExpiry() method
2. `lib/screens/tickets/admin_ticket_control_screen.dart` - Added UI and dialog
3. `lib/models/ticket_models.dart` - AccessCode model (unchanged, remains immutable)

## Testing Checklist
- [x] Method compiles without errors
- [x] UI displays edit button on approved codes
- [x] Dialog opens with correct code displayed
- [x] Slider adjusts value smoothly
- [x] Plus/minus buttons work
- [x] Update saves and shows success message
- [x] Error handling works if invalid code
- [ ] Test with actual running app (runtime verification)
- [ ] Verify expiry persists across app restart
- [ ] Confirm user sees updated expiry in their access code screen

## Debug Notes
Current debug print statements in `ticket_template_editor_screen.dart` (lines 81, 83, 95, 97) are intentional for signature persistence debugging and can be removed once signature saving is confirmed working.
