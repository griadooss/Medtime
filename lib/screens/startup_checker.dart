import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/medication_service.dart';
import '../services/adherence_service.dart';
import '../services/notification_service.dart';
import '../services/app_settings_service.dart';
import '../models/medication.dart';
import 'medication_list_screen.dart';
import 'missed_doses_reminder_screen.dart';

/// Widget that checks for missed/pending doses on startup and shows reminder
class StartupChecker extends StatefulWidget {
  const StartupChecker({super.key});

  @override
  State<StartupChecker> createState() => _StartupCheckerState();
}

class _StartupCheckerState extends State<StartupChecker> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    // Wait for services to load, then check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForMissedDoses();
    });
  }

  Future<void> _checkForMissedDoses() async {
    if (_hasChecked) return;

    // Wait for services to be loaded
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final medicationService =
        Provider.of<MedicationService>(context, listen: false);
    final adherenceService =
        Provider.of<AdherenceService>(context, listen: false);

    // Wait for services to finish loading
    if (!medicationService.isLoaded || !adherenceService.isLoaded) {
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _checkForMissedDoses();
      });
      return;
    }

    setState(() {
      _hasChecked = true;
    });

    // Get all enabled medication IDs
    final enabledMedications = medicationService.enabledMedications;
    final medicationIds = enabledMedications.map((m) => m.id).toList();

    if (medicationIds.isEmpty) {
      debugPrint('StartupChecker: No enabled medications found');
      return;
    }

    debugPrint(
        'StartupChecker: Checking ${medicationIds.length} medications for missed/pending doses');

    // Ensure dose records exist for today's scheduled times
    // This is important if the app wasn't open when notifications fired
    for (final medication in enabledMedications) {
      await adherenceService.createScheduledDosesForMedication(medication);
    }

    // CRITICAL: Ensure grouped notifications are scheduled for all enabled medications
    // This fixes the issue where notifications don't fire when app is closed
    debugPrint(
        'StartupChecker: Scheduling grouped notifications for all enabled medications');
    final notificationService =
        Provider.of<NotificationService>(context, listen: false);

    // Clean up expired notifications first (maintains clean list)
    await notificationService.cleanupExpiredNotifications();

    // Schedule all grouped notifications (one per time slot)
    // This maintains a rolling 7-day window - only schedules missing notifications
    await notificationService
        .scheduleAllGroupedNotifications(enabledMedications);

    // Auto-dismiss doses that are too old (based on timeout setting)
    final now = DateTime.now();
    final settingsService =
        Provider.of<AppSettingsService>(context, listen: false);
    final timeoutHours = settingsService.missedDoseTimeoutHours;
    final timeoutCutoff = now.subtract(Duration(hours: timeoutHours));

    bool hasAutoDismissed = false;
    for (final medication in enabledMedications) {
      final doses = adherenceService.getDosesForMedication(medication.id);
      for (final dose in doses) {
        if (!dose.isTaken &&
            !dose.skipped &&
            dose.scheduledTime.isBefore(timeoutCutoff)) {
          debugPrint(
              'Auto-dismissing old missed dose: ${medication.name} at ${dose.scheduledTime} (${timeoutHours}h timeout)');
          adherenceService.markDoseSkipped(dose.id,
              notes: 'Auto-dismissed after ${timeoutHours}h timeout');
          hasAutoDismissed = true;
        }
      }
    }
    if (hasAutoDismissed) {
      debugPrint('Auto-dismissed old missed doses (timeout: ${timeoutHours}h)');
    }

    // Get doses needing attention
    final dosesNeedingAttention = adherenceService.getDosesNeedingAttention(
      medicationIds: medicationIds,
    );

    debugPrint(
        'StartupChecker: Found ${dosesNeedingAttention.length} medications with doses needing attention');

    // Schedule follow-up reminders for missed doses with "Remind Me" behavior
    // (notificationService already defined above)

    for (final entry in dosesNeedingAttention.entries) {
      final medication =
          enabledMedications.firstWhere((m) => m.id == entry.key);
      debugPrint('  - ${medication.name}: ${entry.value.length} dose(s)');

      for (final dose in entry.value) {
        final status = dose.isMissed(now) ? 'MISSED' : 'PENDING';
        debugPrint('    * $status at ${dose.timeString}');

        // If dose is missed and medication has "Remind Me" behavior, schedule follow-up
        // Group reminders by time slot to avoid duplicate notifications
        // IMPORTANT: Double-check dose status to ensure it hasn't been taken since we last checked
        if (dose.isMissed(now) &&
            medication.notificationBehavior == NotificationBehavior.remind &&
            !dose.isTaken &&
            !dose.skipped) {
          final reminderInterval = medication.reminderIntervalMinutes ?? 15;
          final timeSinceScheduled = now.difference(dose.scheduledTime);
          final minutesSinceScheduled = timeSinceScheduled.inMinutes;

          debugPrint(
              '      Checking reminder for time slot ${dose.scheduledTime.hour}:${dose.scheduledTime.minute.toString().padLeft(2, '0')}');
          debugPrint('        Scheduled: ${dose.scheduledTime}');
          debugPrint('        Now: $now');
          debugPrint('        Minutes since scheduled: $minutesSinceScheduled');
          debugPrint('        Reminder interval: $reminderInterval minutes');

          // Check if reminder interval has passed
          if (minutesSinceScheduled >= reminderInterval) {
            // Calculate when the next reminder should be
            final intervalsPassed = minutesSinceScheduled ~/ reminderInterval;
            final nextReminderTime = dose.scheduledTime.add(
              Duration(minutes: reminderInterval * (intervalsPassed + 1)),
            );

            final minutesUntilNextReminder =
                nextReminderTime.difference(now).inMinutes;

            debugPrint('        Next reminder should be at: $nextReminderTime');
            debugPrint(
                '        Minutes until next reminder: $minutesUntilNextReminder');

            if (minutesUntilNextReminder > 0) {
              // Schedule time slot reminder
              final timeSlot = TimeSlot(
                  hour: dose.scheduledTime.hour,
                  minute: dose.scheduledTime.minute);
              debugPrint(
                  '      Scheduling follow-up reminder for time slot ${timeSlot.timeString} in $minutesUntilNextReminder minutes');
              await notificationService.scheduleTimeSlotReminder(
                timeSlot,
                dose.scheduledTime,
                minutesUntilNextReminder,
              );
            } else if (minutesUntilNextReminder >= -2) {
              // Within 2 minutes of the reminder time, schedule immediately
              final timeSlot = TimeSlot(
                  hour: dose.scheduledTime.hour,
                  minute: dose.scheduledTime.minute);
              debugPrint(
                  '      Scheduling immediate follow-up reminder for time slot ${timeSlot.timeString} (past due)');
              await notificationService.scheduleTimeSlotReminder(
                timeSlot,
                dose.scheduledTime,
                1, // Schedule in 1 minute
              );
            } else {
              // Calculate the next reminder after this one
              final nextNextReminderTime = nextReminderTime.add(
                Duration(minutes: reminderInterval),
              );
              final minutesUntilNextNext =
                  nextNextReminderTime.difference(now).inMinutes;
              if (minutesUntilNextNext > 0) {
                final timeSlot = TimeSlot(
                    hour: dose.scheduledTime.hour,
                    minute: dose.scheduledTime.minute);
                debugPrint(
                    '      Scheduling next follow-up reminder for time slot ${timeSlot.timeString} in $minutesUntilNextNext minutes');
                await notificationService.scheduleTimeSlotReminder(
                  timeSlot,
                  dose.scheduledTime,
                  minutesUntilNextNext,
                );
              }
            }
          } else {
            debugPrint(
                '      Reminder interval not yet reached (${reminderInterval - minutesSinceScheduled} minutes remaining)');
            // Schedule the first reminder for when the interval is reached
            final minutesUntilReminder =
                reminderInterval - minutesSinceScheduled;
            final timeSlot = TimeSlot(
                hour: dose.scheduledTime.hour,
                minute: dose.scheduledTime.minute);
            debugPrint(
                '      Scheduling first reminder for time slot ${timeSlot.timeString} in $minutesUntilReminder minutes');
            await notificationService.scheduleTimeSlotReminder(
              timeSlot,
              dose.scheduledTime,
              minutesUntilReminder,
            );
          }
        }
      }
    }

    // Show reminder screen if there are missed or pending doses
    if (dosesNeedingAttention.isNotEmpty && mounted) {
      Navigator.of(context)
          .pushReplacement(
        MaterialPageRoute(
          builder: (context) => MissedDosesReminderScreen(
            dosesNeedingAttention: dosesNeedingAttention,
          ),
        ),
      )
          .then((_) {
        // Check for pending notification after navigation
        _checkPendingNotification();
      });
    } else {
      // Check for pending notification if no reminder screen
      _checkPendingNotification();
    }
  }

  void _checkPendingNotification() {
    final notificationService =
        Provider.of<NotificationService>(context, listen: false);
    final payload = notificationService.getPendingNotificationPayload();
    if (payload != null && payload.isNotEmpty) {
      debugPrint(
          'StartupChecker: Found pending notification with payload: $payload');
      // Small delay to ensure everything is ready, then trigger the callback
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          notificationService.triggerNotificationTapCallback(payload);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading or home screen while checking
    if (!_hasChecked) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return const MedicationListScreen();
  }
}
