import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/medication.dart';
import '../models/medication_dose.dart';

/// Service for managing medication reminder notifications
class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;

  bool get isInitialized => _initialized;
  bool get permissionGranted => _permissionGranted;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      
      // Note: tz.local defaults to UTC, but we'll handle timezone conversion
      // in the scheduling methods by using DateTime.now() which is in local time
      // and converting properly using TZDateTime.now(tz.local).add() approach
      debugPrint('Timezone initialized. Default timezone: ${tz.local.name}');
      final now = DateTime.now();
      debugPrint('Device timezone offset: ${now.timeZoneOffset.inHours} hours');
      
      // Request permissions first (before creating channels)
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        _permissionGranted = await androidPlugin.requestNotificationsPermission() ?? false;
        
        // Create notification channel with proper settings
        // Use Importance.max to ensure sound plays even in Do Not Disturb mode
        const androidChannel = AndroidNotificationChannel(
          'medtime_reminders',
          'Medication Reminders',
          description: 'Reminders for taking medications',
          importance: Importance.max, // Changed from high to max for sound/vibration
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        
        await androidPlugin.createNotificationChannel(androidChannel);
        debugPrint('Notification channel created: medtime_reminders with Importance.max');
        debugPrint('NOTE: If sound doesn\'t play, check Settings → Apps → Medtime → Notifications → Medication Reminders');
        
        // Check and request exact alarm permission on Android 12+ (API 31+)
        try {
          final canScheduleExactAlarms = await androidPlugin.canScheduleExactNotifications();
          debugPrint('Can schedule exact alarms: $canScheduleExactAlarms');
          if (canScheduleExactAlarms != null && !canScheduleExactAlarms) {
            debugPrint('WARNING: Exact alarm permission not granted. Notifications may be delayed!');
            debugPrint('Attempting to request exact alarm permission...');
            try {
              final requested = await androidPlugin.requestExactAlarmsPermission();
              debugPrint('Exact alarm permission request result: $requested');
              if (requested == true) {
                debugPrint('Exact alarm permission granted!');
              } else {
                debugPrint('User needs to grant "Alarms & reminders" permission in system settings.');
              }
            } catch (requestError) {
              debugPrint('Could not request exact alarm permission: $requestError');
              debugPrint('User needs to grant "Alarms & reminders" permission in system settings.');
            }
          } else {
            debugPrint('Exact alarm permission is already granted.');
          }
        } catch (e) {
          debugPrint('Could not check exact alarm permission: $e');
        }
      }
      
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        _permissionGranted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ?? false;
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // The payload contains the medication ID
    // Navigation will be handled in main.dart using a GlobalKey
    _notificationTappedCallback?.call(response.payload ?? '');
  }

  /// Callback for when notification is tapped
  Function(String medicationId)? _notificationTappedCallback;

  /// Set callback for notification taps
  void setNotificationTappedCallback(Function(String medicationId)? callback) {
    _notificationTappedCallback = callback;
  }

  /// Schedule notifications for a medication
  Future<void> scheduleMedicationNotifications(Medication medication) async {
    if (!_initialized) {
      await initialize();
    }

    debugPrint('=== Scheduling notifications for ${medication.name} ===');
    debugPrint('Enabled: ${medication.enabled}');
    debugPrint('Days of week: ${medication.daysOfWeek.isEmpty ? "ALL DAYS" : medication.daysOfWeek}');
    debugPrint('Skip weekends: ${medication.skipWeekends}');
    debugPrint('Times: ${medication.times.map((t) => "${t.hour}:${t.minute.toString().padLeft(2, '0')}").join(", ")}');

    // Cancel existing notifications for this medication
    await cancelMedicationNotifications(medication.id);

    if (!medication.enabled) {
      debugPrint('Medication is disabled, skipping notification scheduling');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int scheduledCount = 0;

    // Schedule for next 30 days
    for (int dayOffset = 0; dayOffset < 30; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      // DateTime.weekday: 1=Monday, 2=Tuesday, ..., 7=Sunday
      // We need: 0=Sunday, 1=Monday, ..., 6=Saturday
      final dayOfWeek = (targetDate.weekday % 7); // This gives: Mon=1, Tue=2, ..., Sat=6, Sun=0

      // Check if medication should be taken on this day
      if (!medication.shouldTakeOnDay(dayOfWeek)) {
        debugPrint('Skipping ${targetDate.toString().split(' ')[0]} (dayOfWeek=$dayOfWeek, shouldTake=${medication.shouldTakeOnDay(dayOfWeek)})');
        continue;
      }

      // Schedule for each time
      for (final time in medication.times) {
        final scheduledDateTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          time.hour,
          time.minute,
        );

        // Skip if time has already passed today (with 1 minute buffer to account for timing)
        final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
        if (dayOffset == 0 && scheduledDateTime.isBefore(oneMinuteAgo)) {
          debugPrint('Skipping past time: ${scheduledDateTime.toString()} (current: ${now.toString()})');
          continue;
        }
        
        // Log when scheduling near-term notifications
        final timeUntil = scheduledDateTime.difference(now);
        if (dayOffset == 0 && timeUntil.inMinutes < 10) {
          debugPrint('Scheduling near-term notification: ${scheduledDateTime.toString()} (in ${timeUntil.inMinutes} minutes)');
        }

        await _scheduleNotification(
          medication: medication,
          scheduledDateTime: scheduledDateTime,
          notificationId: _getNotificationId(medication.id, scheduledDateTime),
        );
        scheduledCount++;
      }
    }

    debugPrint('=== Scheduled $scheduledCount notifications for ${medication.name} ===');
  }

  /// Schedule a single notification
  Future<void> _scheduleNotification({
    required Medication medication,
    required DateTime scheduledDateTime,
    required int notificationId,
  }) async {
    // Convert local DateTime to TZDateTime
    // scheduledDateTime is in local time, so we need to construct TZDateTime in local timezone
    // Get the device's timezone offset
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    
    // Create TZDateTime by adding the offset to convert from local to UTC, then create TZDateTime
    // Actually, simpler: use the scheduled time directly and let timezone package handle it
    // But we need to ensure we're using the correct timezone location
    
    // Get current TZDateTime in local timezone
    final tzNow = tz.TZDateTime.now(tz.local);
    
    // Calculate difference in local time
    final difference = scheduledDateTime.difference(now);
    
    // Add the difference to current TZDateTime (this preserves timezone)
    final tzScheduledDate = tzNow.add(difference);
    
    debugPrint('Scheduling: DateTime=${scheduledDateTime.toString()}, TZDateTime=${tzScheduledDate.toString()}, Timezone=${tz.local.name}');
    debugPrint('Current time: ${now.toString()}, TZNow: ${tzNow.toString()}');
    debugPrint('Time difference: ${difference.inMinutes} minutes from now');
    debugPrint('Device timezone offset: ${offset.inHours} hours');

    final androidDetails = AndroidNotificationDetails(
      'medtime_reminders',
      'Medication Reminders',
      channelDescription: 'Reminders for taking medications',
      importance: Importance.max, // Max importance ensures sound/vibration work
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String body = 'Time to take ${medication.name}';
    if (medication.dosageInstruction.isNotEmpty) {
      body += ' - ${medication.dosageInstruction}';
    } else if (medication.strength != null) {
      body += ' (${medication.strength})';
    }

    // Try exact alarm first, fall back to inexact if permission not granted
    try {
      debugPrint('Scheduling notification: ${medication.name} at ${scheduledDateTime.toString()} (ID: $notificationId)');
      await _notifications.zonedSchedule(
        notificationId,
        medication.name,
        body,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: medication.id,
      );
      debugPrint('Notification scheduled successfully (exact alarm)');
    } catch (e) {
      // Fall back to inexact alarm if exact alarm permission not granted
      debugPrint('Exact alarm not permitted, using inexact: $e');
      debugPrint('WARNING: Inexact alarms may be delayed!');
      try {
        await _notifications.zonedSchedule(
          notificationId,
          medication.name,
          body,
          tzScheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: medication.id,
        );
        debugPrint('Notification scheduled with inexact alarm (may be delayed)');
      } catch (e2) {
        debugPrint('ERROR: Failed to schedule notification: $e2');
      }
    }
  }

  /// Generate unique notification ID from medication ID and datetime
  int _getNotificationId(String medicationId, DateTime dateTime) {
    // Use hash of medication ID + timestamp to create unique ID
    final hash = medicationId.hashCode ^ dateTime.millisecondsSinceEpoch;
    return hash.abs() % 2147483647; // Keep within int32 range
  }

  /// Show a test notification immediately (for UAT/testing)
  Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_permissionGranted) {
      debugPrint('Notification permission not granted');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'medtime_reminders',
      'Medication Reminders',
      channelDescription: 'Reminders for taking medications',
      importance: Importance.max, // Max importance ensures sound/vibration work
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999, // Use a high ID that won't conflict with real notifications
      'Test Medication',
      'Time to take Test Medication - Take one tablet',
      notificationDetails,
      payload: 'test',
    );
    debugPrint('Test notification shown immediately');
  }

  /// Schedule a test notification for a specific time (for UAT/testing)
  Future<void> scheduleTestNotification({int secondsFromNow = 10}) async {
    if (!_initialized) {
      await initialize();
    }

    if (!_permissionGranted) {
      debugPrint('Notification permission not granted');
      return;
    }

    // Use TZDateTime.now() which should use the correct timezone
    final tzNow = tz.TZDateTime.now(tz.local);
    final tzScheduledTime = tzNow.add(Duration(seconds: secondsFromNow));
    
    final now = DateTime.now();
    final scheduledTime = now.add(Duration(seconds: secondsFromNow));
    
    debugPrint('=== Scheduling Test Notification ===');
    debugPrint('Current time (DateTime): ${now.toString()}');
    debugPrint('Current time (TZDateTime): ${tzNow.toString()}');
    debugPrint('Scheduled time (DateTime): ${scheduledTime.toString()}');
    debugPrint('Scheduled time (TZDateTime): ${tzScheduledTime.toString()}');
    debugPrint('Local timezone: ${tz.local.name}');
    debugPrint('Device timezone offset: ${now.timeZoneOffset.inHours} hours');
    debugPrint('Seconds from now: $secondsFromNow');

    final androidDetails = AndroidNotificationDetails(
      'medtime_reminders',
      'Medication Reminders',
      channelDescription: 'Reminders for taking medications',
      importance: Importance.max, // Max importance ensures sound/vibration work
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    const testNotificationId = 999998;
    
    try {
      await _notifications.zonedSchedule(
        testNotificationId,
        'Test Medication (Scheduled)',
        'Time to take Test Medication - Take one tablet',
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_scheduled',
      );
      debugPrint('Test notification scheduled successfully (exact alarm)');
      
      // Verify it's in the pending list
      final pending = await _notifications.pendingNotificationRequests();
      final testNotification = pending.firstWhere(
        (n) => n.id == testNotificationId,
        orElse: () => throw Exception('Test notification not found in pending list'),
      );
      debugPrint('Verified: Test notification is in pending list (ID: ${testNotification.id})');
      debugPrint('Notification will fire at: ${testNotification.body}');
      
    } catch (e) {
      debugPrint('Error scheduling test notification (exact): $e');
      // Try with inexact alarm
      try {
        await _notifications.zonedSchedule(
          testNotificationId,
          'Test Medication (Scheduled)',
          'Time to take Test Medication - Take one tablet',
          tzScheduledTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'test_scheduled',
        );
        debugPrint('Test notification scheduled with inexact alarm');
        
        // Verify it's in the pending list
        final pending = await _notifications.pendingNotificationRequests();
        final testNotification = pending.firstWhere(
          (n) => n.id == testNotificationId,
          orElse: () => throw Exception('Test notification not found in pending list'),
        );
        debugPrint('Verified: Test notification is in pending list (ID: ${testNotification.id})');
      } catch (e2) {
        debugPrint('Error scheduling test notification (inexact): $e2');
      }
    }
  }

  /// Cancel all notifications for a medication
  Future<void> cancelMedicationNotifications(String medicationId) async {
    // Get all pending notifications and cancel those matching the medication
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    
    for (final notification in pendingNotifications) {
      if (notification.payload == medicationId) {
        await _notifications.cancel(notification.id);
      }
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }


  /// Schedule a reminder notification (for repeat behavior)
  Future<void> scheduleReminder(
    Medication medication,
    MedicationDose dose,
    int intervalMinutes,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    final reminderTime = DateTime.now().add(Duration(minutes: intervalMinutes));
    // DateTime.now() returns local time, so we construct TZDateTime directly
    final tzReminderTime = tz.TZDateTime(
      tz.local,
      reminderTime.year,
      reminderTime.month,
      reminderTime.day,
      reminderTime.hour,
      reminderTime.minute,
      reminderTime.second,
      reminderTime.millisecond,
      reminderTime.microsecond,
    );

    final androidDetails = AndroidNotificationDetails(
      'medtime_reminders',
      'Medication Reminders',
      channelDescription: 'Reminders for taking medications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String body = 'Reminder: ${medication.name}';
    if (medication.dosageInstruction.isNotEmpty) {
      body += ' - ${medication.dosageInstruction}';
    } else if (medication.strength != null) {
      body += ' (${medication.strength})';
    }

    // Use a unique ID for reminder notifications
    final reminderId = _getNotificationId(medication.id, reminderTime) + 1000000;

    // Try exact alarm first, fall back to inexact if permission not granted
    try {
      await _notifications.zonedSchedule(
        reminderId,
        medication.name,
        body,
        tzReminderTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '${medication.id}|${dose.id}', // Include dose ID for tracking
      );
    } catch (e) {
      // Fall back to inexact alarm if exact alarm permission not granted
      debugPrint('Exact alarm not permitted for reminder, using inexact: $e');
      await _notifications.zonedSchedule(
        reminderId,
        medication.name,
        body,
        tzReminderTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '${medication.id}|${dose.id}',
      );
    }
  }
}

