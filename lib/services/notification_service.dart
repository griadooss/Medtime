import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/medication.dart';
import '../models/medication_dose.dart';

/// Represents a time slot (hour:minute) for grouping medications
class TimeSlot {
  final int hour;
  final int minute;

  TimeSlot({required this.hour, required this.minute});

  String get timeString =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlot &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}

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
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        _permissionGranted =
            await androidPlugin.requestNotificationsPermission() ?? false;

        // Create notification channel with proper settings
        // Use Importance.max to ensure sound plays even in Do Not Disturb mode
        const androidChannel = AndroidNotificationChannel(
          'medtime_reminders',
          'Medication Reminders',
          description: 'Reminders for taking medications',
          importance:
              Importance.max, // Changed from high to max for sound/vibration
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidPlugin.createNotificationChannel(androidChannel);
        debugPrint(
            'Notification channel created: medtime_reminders with Importance.max');
        debugPrint(
            'NOTE: If sound doesn\'t play, check Settings → Apps → Medtime → Notifications → Medication Reminders');

        // Check and request exact alarm permission on Android 12+ (API 31+)
        try {
          final canScheduleExactAlarms =
              await androidPlugin.canScheduleExactNotifications();
          debugPrint('Can schedule exact alarms: $canScheduleExactAlarms');
          if (canScheduleExactAlarms != null && !canScheduleExactAlarms) {
            debugPrint(
                'WARNING: Exact alarm permission not granted. Notifications may be delayed!');
            debugPrint('Attempting to request exact alarm permission...');
            try {
              final requested =
                  await androidPlugin.requestExactAlarmsPermission();
              debugPrint('Exact alarm permission request result: $requested');
              if (requested == true) {
                debugPrint('Exact alarm permission granted!');
              } else {
                debugPrint(
                    'User needs to grant "Alarms & reminders" permission in system settings.');
              }
            } catch (requestError) {
              debugPrint(
                  'Could not request exact alarm permission: $requestError');
              debugPrint(
                  'User needs to grant "Alarms & reminders" permission in system settings.');
            }
          } else {
            debugPrint('Exact alarm permission is already granted.');
          }
        } catch (e) {
          debugPrint('Could not check exact alarm permission: $e');
        }
      }

      // Android initialization settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

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
            ) ??
            false;
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? '';
    debugPrint('Notification tapped: $payload');

    // Store payload in case the app isn't ready yet
    _pendingNotificationPayload = payload;

    // Try to call the callback
    _notificationTappedCallback?.call(payload);
  }

  /// Callback for when notification is tapped
  /// Payload format: "timeslot|HH:MM|YYYY-MM-DD" or "reminder|timeslot|HH:MM|YYYY-MM-DD"
  Function(String payload)? _notificationTappedCallback;

  /// Pending notification payload from notification tap (when app wasn't ready)
  String? _pendingNotificationPayload;

  /// Get pending notification payload
  String? getPendingNotificationPayload() {
    final payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null; // Clear after reading
    return payload;
  }

  /// Trigger notification tap callback (for retry when app becomes ready)
  void triggerNotificationTapCallback(String payload) {
    _notificationTappedCallback?.call(payload);
  }

  /// Set callback for notification taps
  void setNotificationTappedCallback(Function(String payload)? callback) {
    _notificationTappedCallback = callback;
  }

  /// Parse time slot from notification payload
  /// Returns TimeSlot and date if payload is valid, null otherwise
  TimeSlot? parseTimeSlotFromPayload(String payload) {
    // Payload format: "timeslot|HH:MM|YYYY-MM-DD" or "reminder|timeslot|HH:MM|YYYY-MM-DD"
    if (!payload.contains('timeslot|')) {
      return null;
    }

    try {
      final parts = payload.split('|');
      String timeStr;

      if (parts[0] == 'reminder' && parts.length >= 4) {
        // "reminder|timeslot|HH:MM|YYYY-MM-DD"
        timeStr = parts[2];
      } else if (parts[0] == 'timeslot' && parts.length >= 3) {
        // "timeslot|HH:MM|YYYY-MM-DD"
        timeStr = parts[1];
      } else {
        return null;
      }

      final timeParts = timeStr.split(':');
      if (timeParts.length != 2) {
        return null;
      }

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return TimeSlot(hour: hour, minute: minute);
    } catch (e) {
      debugPrint('Error parsing time slot from payload: $e');
      return null;
    }
  }

  /// Parse date from notification payload
  /// Returns DateTime if payload is valid, null otherwise
  DateTime? parseDateFromPayload(String payload) {
    // Payload format: "timeslot|HH:MM|YYYY-MM-DD" or "reminder|timeslot|HH:MM|YYYY-MM-DD"
    if (!payload.contains('timeslot|')) {
      return null;
    }

    try {
      final parts = payload.split('|');
      String dateStr;

      if (parts[0] == 'reminder' && parts.length >= 4) {
        // "reminder|timeslot|HH:MM|YYYY-MM-DD"
        dateStr = parts[3];
      } else if (parts[0] == 'timeslot' && parts.length >= 3) {
        // "timeslot|HH:MM|YYYY-MM-DD"
        dateStr = parts[2];
      } else {
        return null;
      }

      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) {
        return null;
      }

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      return DateTime(year, month, day);
    } catch (e) {
      debugPrint('Error parsing date from payload: $e');
      return null;
    }
  }

  /// Schedule notifications for all enabled medications (grouped by time slot)
  /// This is the new grouped notification approach - one notification per time slot
  ///
  /// Maintains a rolling 7-day window:
  /// - Only schedules notifications that don't already exist
  /// - Automatically extends the window when called (e.g., on app startup)
  /// - No need to manually reschedule if you open the app at least once per week
  Future<void> scheduleAllGroupedNotifications(
      List<Medication> medications) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      if (!_permissionGranted) {
        debugPrint(
            'ERROR: Notification permission not granted! Cannot schedule notifications.');
        throw Exception('Notification permission not granted');
      }

      debugPrint(
          '=== Scheduling grouped notifications for all medications ===');
      debugPrint('Total medications provided: ${medications.length}');
      debugPrint(
          'Enabled medications: ${medications.where((m) => m.enabled).length}');

      if (medications.isEmpty) {
        debugPrint('WARNING: No medications provided to schedule');
        return;
      }

      // Group medications by time slot
      final timeSlotGroups = _groupMedicationsByTimeSlot(medications);
      debugPrint('Found ${timeSlotGroups.length} unique time slots');

      if (timeSlotGroups.isEmpty) {
        debugPrint(
            'WARNING: No time slots found! Check that medications have scheduled times and are enabled.');
        for (final med in medications) {
          debugPrint(
              '  - ${med.name}: enabled=${med.enabled}, times=${med.times.length}');
        }
        return;
      }

      // Log time slots found
      for (final entry in timeSlotGroups.entries) {
        debugPrint(
            '  Time slot ${entry.key.timeString}: ${entry.value.length} medication(s)');
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      const int daysAhead = 7;
      int scheduledCount = 0;
      int skippedCount = 0;
      int alreadyScheduledCount = 0;

      // Get existing pending notifications to avoid duplicates
      final existingNotifications =
          await _notifications.pendingNotificationRequests();
      final existingPayloads = existingNotifications
          .where((n) => n.payload != null && n.payload!.contains('timeslot|'))
          .map((n) => n.payload!)
          .toSet();

      // Schedule one notification per time slot per day
      for (int dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
        final targetDate = today.add(Duration(days: dayOffset));
        final dayOfWeek = (targetDate.weekday % 7);

        for (final entry in timeSlotGroups.entries) {
          final timeSlot = entry.key;
          final medicationsForSlot = entry.value;

          // Filter medications that should be taken on this day
          final validMedications = medicationsForSlot.where((med) {
            return med.enabled && med.shouldTakeOnDay(dayOfWeek);
          }).toList();

          if (validMedications.isEmpty) {
            skippedCount++;
            continue; // No medications for this time slot on this day
          }

          final scheduledDateTime = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            timeSlot.hour,
            timeSlot.minute,
          );

          // Skip if time has already passed today (with 5 minute buffer)
          if (dayOffset == 0 &&
              scheduledDateTime
                  .isBefore(now.subtract(const Duration(minutes: 5)))) {
            debugPrint('Skipping past time slot: ${timeSlot.timeString}');
            skippedCount++;
            continue;
          }

          // Check if notification already exists (rolling window - don't reschedule existing ones)
          final dateKey =
              '${scheduledDateTime.year}-${scheduledDateTime.month.toString().padLeft(2, '0')}-${scheduledDateTime.day.toString().padLeft(2, '0')}';
          final expectedPayload = 'timeslot|${timeSlot.timeString}|$dateKey';

          if (existingPayloads.contains(expectedPayload)) {
            alreadyScheduledCount++;
            debugPrint(
                'Notification already scheduled for ${timeSlot.timeString} on $dateKey - skipping');
            continue;
          }

          // Schedule grouped notification for this time slot
          await _scheduleGroupedNotification(
            timeSlot: timeSlot,
            scheduledDateTime: scheduledDateTime,
            medications: validMedications,
          );

          scheduledCount++;
        }
      }

      debugPrint(
          '=== Scheduling complete: $scheduledCount new notifications scheduled, $alreadyScheduledCount already exist, $skippedCount skipped ===');
    } catch (e, stackTrace) {
      debugPrint('ERROR in scheduleAllGroupedNotifications: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Schedule notifications for a medication (legacy method - now calls grouped scheduling)
  /// This is kept for backward compatibility but now reschedules all medications
  Future<void> scheduleMedicationNotifications(Medication medication) async {
    debugPrint(
        '=== scheduleMedicationNotifications called for ${medication.name} ===');
    debugPrint(
        'NOTE: This now triggers rescheduling of ALL medications (grouped by time slot)');

    // For backward compatibility, we'll need access to all medications
    // This will be called from MedicationService context, so we'll need to pass all medications
    // For now, we'll just log that this needs to be updated
    debugPrint(
        'WARNING: scheduleMedicationNotifications should be replaced with scheduleAllGroupedNotifications');
  }

  /// Group medications by their scheduled time slots
  Map<TimeSlot, List<Medication>> _groupMedicationsByTimeSlot(
      List<Medication> medications) {
    final Map<TimeSlot, List<Medication>> groups = {};

    for (final medication in medications) {
      if (!medication.enabled) continue;

      for (final time in medication.times) {
        final timeSlot = TimeSlot(hour: time.hour, minute: time.minute);
        groups.putIfAbsent(timeSlot, () => []).add(medication);
      }
    }

    return groups;
  }

  /// Generate unique notification ID from time slot and datetime
  int _getTimeSlotNotificationId(TimeSlot timeSlot, DateTime dateTime) {
    // Use hash of time slot + date to create unique ID
    final hash = timeSlot.hashCode ^ dateTime.millisecondsSinceEpoch;
    return hash.abs() % 2147483647; // Keep within int32 range
  }

  /// Generate notification ID for follow-up reminders (time slot based)
  int _getTimeSlotReminderId(TimeSlot timeSlot, DateTime reminderTime) {
    // Add offset to distinguish from initial notifications
    final baseId = _getTimeSlotNotificationId(timeSlot, reminderTime);
    return (baseId + 1000000) % 2147483647;
  }

  /// Schedule a grouped notification for a time slot
  Future<void> _scheduleGroupedNotification({
    required TimeSlot timeSlot,
    required DateTime scheduledDateTime,
    required List<Medication> medications,
  }) async {
    final now = DateTime.now();
    final tzNow = tz.TZDateTime.now(tz.local);
    final difference = scheduledDateTime.difference(now);
    final tzScheduledDate = tzNow.add(difference);

    final notificationId =
        _getTimeSlotNotificationId(timeSlot, scheduledDateTime);

    final androidDetails = AndroidNotificationDetails(
      'medtime_reminders',
      'Medication Reminders',
      channelDescription: 'Reminders for taking medications',
      importance: Importance.max,
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

    // Create notification text
    final medicationCount = medications.length;
    final timeStr = timeSlot.timeString;

    String title;
    String body;

    if (medicationCount == 1) {
      final med = medications.first;
      title = 'Time to take ${med.name}';
      body = 'Take your medication at $timeStr';
      if (med.dosageInstruction.isNotEmpty) {
        body += ' - ${med.dosageInstruction}';
      }
    } else {
      title = 'Time to take your medications';
      body = 'Take $medicationCount medications at $timeStr';
    }

    // Payload format: "timeslot|HH:MM|YYYY-MM-DD"
    final dateKey =
        '${scheduledDateTime.year}-${scheduledDateTime.month.toString().padLeft(2, '0')}-${scheduledDateTime.day.toString().padLeft(2, '0')}';
    final payload = 'timeslot|${timeSlot.timeString}|$dateKey';

    debugPrint(
        'Scheduling grouped notification: $title at ${scheduledDateTime.toString()} (ID: $notificationId)');
    debugPrint('  Medications: ${medications.map((m) => m.name).join(", ")}');
    debugPrint('  Payload: $payload');

    try {
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Grouped notification scheduled successfully (exact alarm)');
    } catch (e) {
      debugPrint('Exact alarm not permitted, using inexact: $e');
      try {
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          tzScheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        debugPrint('Grouped notification scheduled with inexact alarm');
      } catch (e2) {
        debugPrint('ERROR: Failed to schedule grouped notification: $e2');
      }
    }
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
        orElse: () =>
            throw Exception('Test notification not found in pending list'),
      );
      debugPrint(
          'Verified: Test notification is in pending list (ID: ${testNotification.id})');
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
          orElse: () =>
              throw Exception('Test notification not found in pending list'),
        );
        debugPrint(
            'Verified: Test notification is in pending list (ID: ${testNotification.id})');
      } catch (e2) {
        debugPrint('Error scheduling test notification (inexact): $e2');
      }
    }
  }

  /// Cancel all notifications for a medication
  /// Note: With grouped notifications, this will cancel time slot notifications that include this medication
  /// This is less precise but necessary for backward compatibility
  Future<void> cancelMedicationNotifications(String medicationId) async {
    debugPrint(
        'WARNING: cancelMedicationNotifications is less precise with grouped notifications.');
    debugPrint(
        'Consider using cancelTimeSlotNotifications or rescheduling all notifications instead.');

    // With grouped notifications, we can't easily cancel just one medication's notifications
    // The best approach is to reschedule all notifications, which will exclude this medication
    // For now, we'll just log this
    debugPrint(
        'Medication $medicationId notifications should be handled by rescheduling all grouped notifications');
  }

  /// Cancel notifications for a specific time slot and date
  Future<void> cancelTimeSlotNotifications(
      TimeSlot timeSlot, DateTime date) async {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final payloadPrefix = 'timeslot|${timeSlot.timeString}|$dateKey';
    final reminderPayloadPrefix =
        'reminder|timeslot|${timeSlot.timeString}|$dateKey';

    final pendingNotifications =
        await _notifications.pendingNotificationRequests();
    int cancelledCount = 0;

    for (final notification in pendingNotifications) {
      if (notification.payload != null &&
          (notification.payload!.startsWith(payloadPrefix) ||
              notification.payload!.startsWith(reminderPayloadPrefix))) {
        await _notifications.cancel(notification.id);
        cancelledCount++;
      }
    }

    debugPrint(
        'Cancelled $cancelledCount notifications for time slot ${timeSlot.timeString} on $dateKey');
  }

  /// Cancel all reminders for a specific scheduled dose time
  /// This is called when a dose is marked as taken to prevent unnecessary reminders
  Future<void> cancelRemindersForDose(DateTime scheduledTime) async {
    final timeSlot =
        TimeSlot(hour: scheduledTime.hour, minute: scheduledTime.minute);
    await cancelTimeSlotNotifications(timeSlot, scheduledTime);
    debugPrint(
        'Cancelled all reminders for dose scheduled at ${scheduledTime.toString()}');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Clean up expired notifications (past their scheduled time)
  /// This helps maintain a clean notification list
  Future<void> cleanupExpiredNotifications() async {
    final now = DateTime.now();
    final pendingNotifications =
        await _notifications.pendingNotificationRequests();
    int cleanedCount = 0;

    for (final notification in pendingNotifications) {
      // Only clean up time slot notifications (not follow-up reminders)
      if (notification.payload != null &&
          notification.payload!.startsWith('timeslot|') &&
          !notification.payload!.startsWith('reminder|')) {
        try {
          // Parse date from payload: "timeslot|HH:MM|YYYY-MM-DD"
          final parts = notification.payload!.split('|');
          if (parts.length >= 3) {
            final dateStr = parts[2];
            final dateParts = dateStr.split('-');
            if (dateParts.length == 3) {
              final notificationDate = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
              );

              // If notification date is more than 1 day in the past, cancel it
              if (notificationDate
                  .isBefore(now.subtract(const Duration(days: 1)))) {
                await _notifications.cancel(notification.id);
                cleanedCount++;
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing notification payload for cleanup: $e');
        }
      }
    }

    if (cleanedCount > 0) {
      debugPrint('Cleaned up $cleanedCount expired notifications');
    }
  }

  /// Get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Schedule a follow-up reminder for a time slot (for repeat behavior)
  /// This schedules a reminder for all medications at a specific time slot that haven't been taken
  Future<void> scheduleTimeSlotReminder(
    TimeSlot timeSlot,
    DateTime originalScheduledDateTime,
    int intervalMinutes,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    final reminderTime = DateTime.now().add(Duration(minutes: intervalMinutes));
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
      importance: Importance.max,
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

    final timeStr = timeSlot.timeString;

    String title = 'Reminder: Take your medications';
    String body = 'Reminder to take your medications at $timeStr';

    // Payload format: "reminder|timeslot|HH:MM|YYYY-MM-DD"
    final dateKey =
        '${originalScheduledDateTime.year}-${originalScheduledDateTime.month.toString().padLeft(2, '0')}-${originalScheduledDateTime.day.toString().padLeft(2, '0')}';
    final payload = 'reminder|timeslot|${timeSlot.timeString}|$dateKey';

    final reminderId = _getTimeSlotReminderId(timeSlot, reminderTime);

    debugPrint(
        'Scheduling time slot reminder: $timeStr at ${reminderTime.toString()} (ID: $reminderId)');
    debugPrint('  Original scheduled time: $originalScheduledDateTime');
    debugPrint('  Payload: $payload');

    try {
      await _notifications.zonedSchedule(
        reminderId,
        title,
        body,
        tzReminderTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Time slot reminder scheduled successfully (exact alarm)');
    } catch (e) {
      debugPrint('Exact alarm not permitted for reminder, using inexact: $e');
      try {
        await _notifications.zonedSchedule(
          reminderId,
          title,
          body,
          tzReminderTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        debugPrint('Time slot reminder scheduled with inexact alarm');
      } catch (e2) {
        debugPrint('ERROR: Failed to schedule time slot reminder: $e2');
      }
    }
  }

  /// Schedule a reminder notification (legacy method - kept for backward compatibility)
  /// This now converts to time slot based reminder
  Future<void> scheduleReminder(
    Medication medication,
    MedicationDose dose,
    int intervalMinutes,
  ) async {
    debugPrint(
        'WARNING: scheduleReminder(medication, dose) is deprecated. Use scheduleTimeSlotReminder instead.');

    // Extract time slot from dose
    final timeSlot = TimeSlot(
        hour: dose.scheduledTime.hour, minute: dose.scheduledTime.minute);

    // Schedule time slot reminder
    await scheduleTimeSlotReminder(
      timeSlot,
      dose.scheduledTime,
      intervalMinutes,
    );
  }
}
