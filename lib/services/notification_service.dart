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

      // Request permissions
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        _permissionGranted = await androidPlugin.requestNotificationsPermission() ?? false;
      }

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
    // Handle notification tap - could navigate to medication detail
  }

  /// Schedule notifications for a medication
  Future<void> scheduleMedicationNotifications(Medication medication) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancel existing notifications for this medication
    await cancelMedicationNotifications(medication.id);

    if (!medication.enabled) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Schedule for next 30 days
    for (int dayOffset = 0; dayOffset < 30; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final dayOfWeek = targetDate.weekday % 7; // Convert to 0=Sunday, 1=Monday, etc.

      // Check if medication should be taken on this day
      if (!medication.shouldTakeOnDay(dayOfWeek)) {
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

        // Skip if time has already passed today
        if (dayOffset == 0 && scheduledDateTime.isBefore(now)) {
          continue;
        }

        await _scheduleNotification(
          medication: medication,
          scheduledDateTime: scheduledDateTime,
          notificationId: _getNotificationId(medication.id, scheduledDateTime),
        );
      }
    }
  }

  /// Schedule a single notification
  Future<void> _scheduleNotification({
    required Medication medication,
    required DateTime scheduledDateTime,
    required int notificationId,
  }) async {
    final tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      'medtime_reminders',
      'Medication Reminders',
      channelDescription: 'Reminders for taking medications',
      importance: Importance.high,
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
    } catch (e) {
      // Fall back to inexact alarm if exact alarm permission not granted
      debugPrint('Exact alarm not permitted, using inexact: $e');
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
    }
  }

  /// Generate unique notification ID from medication ID and datetime
  int _getNotificationId(String medicationId, DateTime dateTime) {
    // Use hash of medication ID + timestamp to create unique ID
    final hash = medicationId.hashCode ^ dateTime.millisecondsSinceEpoch;
    return hash.abs() % 2147483647; // Keep within int32 range
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
    final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

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

