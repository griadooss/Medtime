# Quick Test Checklist - Grouped Notifications

## Setup (Do Once)
- [ ] Fresh install or clear data
- [ ] Import 9 medications (9@06:00, 3@18:00, 1@12:00)
- [ ] Grant all permissions

## Core Functionality (Must Pass)
- [ ] **One notification per time slot** (not 9 for 06:00!)
- [ ] **Pending list shows ~20 notifications** (not 500+)
- [ ] **Notifications sorted chronologically**
- [ ] **Clear date/time display** (no "(check body)" confusion)
- [ ] **Notification fires when app is closed**
- [ ] **Tapping notification shows correct medications** for that time slot
- [ ] **Rolling window extends** when app opens

## Quick Verification Steps

### 1. Check Pending List
- Settings → "Check Pending Notifications"
- ✅ Should see ~20 notifications
- ✅ Sorted by time (next first)
- ✅ Clear dates (Today/Tomorrow/Date)
- ✅ No technical jargon

### 2. Wait for Notification
- Wait for next scheduled time
- ✅ ONE notification appears (not 9!)
- ✅ Correct title and body text

### 3. Tap Notification
- Tap the notification
- ✅ App opens
- ✅ Shows reminder screen
- ✅ Shows ONLY medications for that time slot

### 4. Test Follow-Up (Optional)
- Set one med to "Remind Me" (10 min interval)
- Swipe away notification
- Wait 10 minutes
- ✅ Follow-up reminder appears
- ✅ Shows "REMINDER" badge in pending list

### 5. Test Rolling Window
- Open app next day
- Check pending notifications
- ✅ Window extended forward
- ✅ No duplicates

## Red Flags (If You See These, There's a Problem)
- ❌ Multiple notifications for same time slot
- ❌ 500+ pending notifications
- ❌ "(check body)" text in pending list
- ❌ Notifications not firing when app closed
- ❌ Wrong medications shown when tapping notification
- ❌ Duplicate notifications appearing

## Success = All Green Checks ✅












