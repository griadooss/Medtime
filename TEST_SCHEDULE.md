# Grouped Notification System - Test Schedule

## Prerequisites
- Fresh app installation (or cleared data)
- No existing adherence data
- No pending notifications
- 9 medications configured as follows:
  - **9 medications** scheduled at **06:00** (all 9)
  - **3 medications** scheduled at **18:00** (Vitamin B12, Pirfenidone, Bio Magnesium)
  - **1 medication** scheduled at **12:00** (Pirfenidone)

---

## Test Phase 1: Initial Setup & Verification

### Step 1.1: Fresh Installation
- [ ] Install app (or clear app data)
- [ ] Grant notification permissions
- [ ] Grant exact alarm permissions (if prompted)

### Step 1.2: Import/Configure Medications
- [ ] Import 9 medications from JSON file (or manually create)
- [ ] Verify all medications are enabled
- [ ] Verify scheduled times are correct:
  - 9 medications at 06:00
  - 3 medications at 18:00
  - 1 medication at 12:00

### Step 1.3: Verify Initial Scheduling
- [ ] Go to Settings → "Check Pending Notifications"
- [ ] **Expected**: Should show ~20 notifications (7 days × 3 time slots, minus today's past 06:00)
- [ ] **Expected**: Notifications sorted chronologically
- [ ] **Expected**: Clear date/time display (e.g., "Today at 6:00 PM", "Tomorrow at 6:00 AM")
- [ ] **Expected**: No confusing "(check body)" text
- [ ] **Expected**: "Time to take your medications" for 06:00 and 18:00
- [ ] **Expected**: "Time to take Pirfenidone" for 12:00

### Step 1.4: Verify Notification Count
- [ ] Count notifications in the list
- [ ] **Expected**: Should be approximately 20 (not 189!)
- [ ] **Expected**: One notification per time slot per day

---

## Test Phase 2: Notification Reception

### Step 2.1: Wait for Next Scheduled Time
- [ ] Note the next scheduled notification time
- [ ] Wait until that time arrives
- [ ] **Expected**: ONE notification should appear (not 9 for 06:00!)
- [ ] **Expected**: Notification title should match:
  - "Time to take your medications" for 06:00 (9 meds)
  - "Time to take your medications" for 18:00 (3 meds)
  - "Time to take Pirfenidone" for 12:00 (1 med)

### Step 2.2: Verify Notification Content
- [ ] Check notification body text
- [ ] **Expected**: Should show medication count (e.g., "Take 9 medications at 06:00")
- [ ] **Expected**: Should NOT show individual medication names in notification

---

## Test Phase 3: Notification Tap Behavior

### Step 3.1: Tap Notification
- [ ] Tap the notification when it appears
- [ ] **Expected**: App opens
- [ ] **Expected**: Reminder screen appears
- [ ] **Expected**: Shows ONLY medications for that time slot
  - If 06:00 tapped → shows all 9 medications
  - If 18:00 tapped → shows 3 medications
  - If 12:00 tapped → shows 1 medication (Pirfenidone)

### Step 3.2: Mark Medications
- [ ] Mark some medications as "Taken"
- [ ] Mark some medications as "Skip"
- [ ] **Expected**: Actions are recorded correctly
- [ ] **Expected**: Can navigate back to home screen

### Step 3.3: Verify After Marking
- [ ] Go to Adherence screen
- [ ] **Expected**: Marked doses appear in adherence history
- [ ] **Expected**: Correct medications are recorded

---

## Test Phase 4: Follow-Up Reminders (Remind Me Behavior)

### Step 4.1: Configure Remind Me
- [ ] Set at least one medication to "Remind Me" behavior
- [ ] Set reminder interval (e.g., 10 minutes for testing)
- [ ] Save medication

### Step 4.2: Let Notification Fire Without Action
- [ ] Wait for a scheduled notification
- [ ] **Expected**: Notification appears
- [ ] **DO NOT** tap the notification - swipe it away instead
- [ ] Wait for reminder interval (e.g., 10 minutes)

### Step 4.3: Verify Follow-Up Reminder
- [ ] **Expected**: Follow-up reminder notification appears after interval
- [ ] **Expected**: Notification shows "Reminder: Take your medications"
- [ ] **Expected**: Orange "REMINDER" badge in pending list
- [ ] Tap the reminder notification
- [ ] **Expected**: App opens and shows reminder screen
- [ ] **Expected**: Shows medications that haven't been taken yet

### Step 4.4: Multiple Reminders
- [ ] Swipe away the reminder again
- [ ] Wait another interval
- [ ] **Expected**: Another reminder appears
- [ ] **Expected**: Continues until timeout (3 hours default) or medication is taken

---

## Test Phase 5: Rolling Window Maintenance

### Step 5.1: Check Current Window
- [ ] Go to Settings → "Check Pending Notifications"
- [ ] Note the furthest scheduled date
- [ ] **Expected**: Should be approximately 7 days from today

### Step 5.2: Simulate Daily Use (Day 1)
- [ ] Wait until next day (or manually advance device time)
- [ ] Open the app (tap a notification or manually open)
- [ ] **Expected**: StartupChecker runs
- [ ] Check pending notifications again
- [ ] **Expected**: Window should extend forward by 1 day
- [ ] **Expected**: Old expired notifications should be cleaned up

### Step 5.3: Verify No Duplicates
- [ ] Check pending notifications
- [ ] **Expected**: No duplicate notifications for same time slot/date
- [ ] **Expected**: Debug log should show "already exist" for existing notifications

### Step 5.4: Multiple Days
- [ ] Repeat Step 5.2 for 2-3 more days
- [ ] **Expected**: Window continues to roll forward
- [ ] **Expected**: Always maintains ~7 days ahead

---

## Test Phase 6: Edge Cases

### Step 6.1: App Closed During Notification
- [ ] Schedule a test notification (or wait for real one)
- [ ] Close the app completely
- [ ] Wait for notification time
- [ ] **Expected**: Notification still fires even when app is closed
- [ ] Tap notification
- [ ] **Expected**: App opens and shows reminder screen

### Step 6.2: Multiple Time Slots Same Day
- [ ] Wait for a day with multiple time slots (e.g., 06:00, 12:00, 18:00)
- [ ] **Expected**: Each time slot gets ONE notification
- [ ] **Expected**: Notifications fire at correct times
- [ ] **Expected**: Each notification shows correct medications for that time slot

### Step 6.3: Medication Changes
- [ ] Edit a medication (change time or disable)
- [ ] Save changes
- [ ] **Expected**: All notifications rescheduled
- [ ] Check pending notifications
- [ ] **Expected**: Updated medication appears in correct time slots
- [ ] **Expected**: Disabled medication removed from notifications

### Step 6.4: Delete Medication
- [ ] Delete one medication
- [ ] **Expected**: All notifications rescheduled
- [ ] Check pending notifications
- [ ] **Expected**: Deleted medication no longer appears in any notifications

### Step 6.5: Manual Reschedule
- [ ] Go to Settings → "Reschedule All Notifications"
- [ ] Confirm reschedule
- [ ] **Expected**: All notifications cancelled and rescheduled
- [ ] **Expected**: Debug log shows scheduling process
- [ ] Check pending notifications
- [ ] **Expected**: Fresh 7-day window scheduled

---

## Test Phase 7: Notification Display Quality

### Step 7.1: Pending List Readability
- [ ] Go to Settings → "Check Pending Notifications"
- [ ] Review the list
- [ ] **Expected**: Clear date/time format (no confusion)
- [ ] **Expected**: Sorted chronologically (next first)
- [ ] **Expected**: Easy to understand what each notification is for
- [ ] **Expected**: Reminder badges visible for follow-ups

### Step 7.2: Notification Text Quality
- [ ] Review actual notification text when it fires
- [ ] **Expected**: Clear and concise
- [ ] **Expected**: Shows medication count for grouped notifications
- [ ] **Expected**: Shows medication name for single medication

---

## Test Phase 8: Performance & Reliability

### Step 8.1: Notification Count
- [ ] Check pending notifications count
- [ ] **Expected**: Should be ~20-21 (not 500+!)
- [ ] **Expected**: Count remains stable (doesn't grow unbounded)

### Step 8.2: App Startup Performance
- [ ] Open app multiple times
- [ ] **Expected**: No significant delay
- [ ] **Expected**: Rolling window maintenance is fast
- [ ] **Expected**: Debug logs show efficient scheduling

### Step 8.3: Battery Impact
- [ ] Monitor battery usage over 24 hours
- [ ] **Expected**: Minimal battery impact
- [ ] **Expected**: Notifications fire reliably

---

## Success Criteria Summary

✅ **All tests pass if:**
1. Only ONE notification per time slot (not per medication)
2. Notifications fire reliably even when app is closed
3. Tapping notification shows correct medications for that time slot
4. Follow-up reminders work for "Remind Me" medications
5. Rolling window maintains 7 days automatically
6. No duplicate notifications
7. Pending list is clear and understandable
8. Total notification count stays low (~20-21, not 500+)
9. App performance is good
10. Edge cases handled gracefully

---

## Known Limitations (Document for Users)

- If you swipe away ALL notifications without tapping them AND don't open the app manually for 7+ days, the notification window may expire
- Solution: Open the app manually at least once per week, or tap any notification
- For most users taking daily medications, this is not an issue

---

## Notes for Testing

- Use debug console to monitor scheduling behavior
- Check "Pending Notifications" frequently to verify state
- Test with device time changes if needed (but be careful with timezone)
- Document any issues or unexpected behavior










