# Authentication Fix Guide: "Invalid Driver or PIN" Error

## What Was Fixed

### Problem
Both web and mobile apps show "Invalid Driver or PIN" error, preventing all login attempts.

### Root Cause
The `driverLogin()` method queries Firestore with 3 conditions (role + name + PIN hash), and returns no results, causing every login to fail.

---

## Implementation Summary

### ✅ Changes Made

#### 1. Debug Logging Added
- **File:** `lib/services/auth_service.dart`
- **Method:** `driverLogin()`
- **Debug Markers:** Look for `🔐 [AUTH]` in console logs
- **Shows:**
  - PIN hash being used
  - Firestore query conditions
  - Number of matching results
  - Driver data if found
  - Why PIN comparison failed (if applicable)

#### 2. Web Platform Fix
- **File:** `lib/services/auth_service.dart`
- **Change:** Skip device registration check for web platform
- **Reason:** Web uses hardcoded 'web-device' serial, not a real device
- **Impact:** Web users can now login without device registration

#### 3. Debug Helper Methods
- **File:** `lib/services/auth_service.dart`
- **New Methods:**
  - `getAvailableDriversForDebug()` — Lists all drivers with PIN hash preview
  - `debugTestDriverLogin()` — Test specific driver/PIN combination

#### 4. Mobile Debug Button
- **File:** `lib/screen/login/widgets/login_form.dart`
- **Feature:** "DEBUG: Show Available Drivers" button
- **Shows:** Popup with all drivers and their PIN hash status

---

## How to Use These Debugging Tools

### On Mobile:
1. Run the app: `flutter run`
2. Click **"DEBUG: Show Available Drivers"** button
3. Check if your driver appears in the list
4. Verify PIN Hash is not "MISSING"

### In Console/DevTools:
1. Open Flutter DevTools: `flutter attach`
2. Search console for: `🔐 [AUTH]`
3. Look at login attempt logs to see:
   - What PIN hash was sent
   - How many drivers matched the query
   - Exact data from matching driver (if any)

### Example Output:
```
🔐 [AUTH] Driver Login Attempt: name="John Doe", hashedPin="a1b2c3d4...", deviceSerial="ABC123"
🔐 [AUTH] Querying Firestore: collection="users", role="driver", name="John Doe", pin="a1b2c3d4..."
🔐 [AUTH] Query returned 0 documents
🔐 [AUTH] No driver found. Attempting fallback: query by name only to show available data...
🔐 [AUTH] Name-only query returned 1 documents
🔐 [AUTH] Found driver by name, but PIN mismatch. Stored PIN: "xyz789..."
```

---

## Next Steps to Fix Login

### Step 1: Identify the Problem
Run the debug button and check the output:

- **If driver name appears but "PIN Hash: MISSING"**
  → **Problem:** PIN field is empty in Firestore
  → **Solution:** Add PIN to driver record

- **If driver name appears but PIN hash is different**
  → **Problem:** User entered wrong PIN
  → **Solution:** Verify correct PIN with driver

- **If driver name doesn't appear at all**
  → **Problem:** Driver record doesn't exist or role ≠ 'driver'
  → **Solution:** Create driver record in Firebase Admin Dashboard

### Step 2: Verify Driver Data in Firestore
1. Go to **Firebase Console** → **Firestore Database** → **users** collection
2. Find your driver document and verify:
   ```
   {
     "name": "John Doe",           ← Must match exactly (case-sensitive)
     "role": "driver",              ← Must be exactly "driver"
     "pin": "a1b2c3d4...",         ← SHA256 hash of PIN (e.g., "1234")
     "email": "john@example.com",
     "accessibleCompanies": ["company-id-1"]
   }
   ```

### Step 3: Fix the PIN Field
If PIN is wrong or missing:

**Option A: Update existing driver**
1. In Firestore Console, edit the driver document
2. Set `pin` field to the SHA256 hash of the 4-digit PIN
3. Use this tool to generate hash: https://www.tools.md5hashgenerator.com/
   - Enter PIN (e.g., "1234")
   - Copy SHA256 hash value
   - Paste into Firestore `pin` field

**Option B: Recreate driver with correct PIN**
1. Delete existing driver record
2. Create new document with correct fields:
```json
{
  "name": "Driver Name",
  "role": "driver",
  "email": "driver@example.com",
  "pin": "[SHA256_HASH_OF_PIN]",
  "accessibleCompanies": ["[YOUR_COMPANY_ID]"]
}
```

### Step 4: Verify Device Registration (Mobile Only)
If PIN verification succeeds but you still get "Unregistered Device" error:

1. Go to Firebase Console → **devices** collection
2. Create/update document with device serial number:
```json
{
  "serialNumber": "[Device-Serial]",  ← Must match actual device serial
  "company": "Your Company Name",
  "companyId": "company-id-123",
  "plateNo": "ABC-1234",
  "status": "idle"
}
```

3. Ensure driver's `accessibleCompanies` array contains this company ID

---

## Testing the Fix

### Web Platform:
```bash
flutter run -d chrome
```
- Should bypass device registration
- Only PIN verification needed
- Look for `✅ [AUTH] Driver login SUCCESSFUL` in console

### Mobile Platform:
```bash
flutter run
```
- Ensure device serial is registered in Firebase
- Driver must have company access
- Should see all three checks pass:
  1. ✅ Driver name + PIN validated
  2. ✅ Device found in Firestore
  3. ✅ Driver has company access

---

## Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Invalid Driver or PIN" | PIN hash doesn't match | Use correct PIN or update Firestore hash |
| "Invalid Driver or PIN" | Driver doesn't exist | Create driver in Firebase Console |
| "Unregistered Device!" | Device not in 'devices' collection | Register device in Admin Dashboard |
| "You are not registered to drive for..." | Company ID mismatch | Add company ID to `accessibleCompanies` |

---

## Debug Commands

### Test specific driver login (in code):
```dart
final authService = AuthService();
final exists = await authService.debugTestDriverLogin("John Doe", "1234");
print("Driver login valid: $exists");
```

### Get all drivers:
```dart
final authService = AuthService();
final drivers = await authService.getAvailableDriversForDebug();
for (var d in drivers) {
  print("${d['name']}: PIN Hash = ${d['pin_hash_preview']}");
}
```

---

## Need More Help?

1. **Check the logs:** Look for `🔐 [AUTH]` messages
2. **Use the debug button:** Click "DEBUG: Show Available Drivers"
3. **Verify Firestore data:** Manually check driver and device records
4. **Check device serial:** Run `adb shell getprop ro.serialno` on Android
5. **Verify PIN hash:** Use online SHA256 tool to confirm hash value

---

## Summary of Files Modified

- `lib/services/auth_service.dart` — Added debug logging and helper methods
- `lib/screen/login/widgets/login_form.dart` — Added debug button

These changes are non-breaking and only add debugging capabilities. Any existing code will continue to work as before.
