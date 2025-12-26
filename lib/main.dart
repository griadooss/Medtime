import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/medication_service.dart';
import 'services/notification_service.dart';
import 'services/adherence_service.dart';
import 'services/app_settings_service.dart';
import 'models/medication_dose.dart';
import 'screens/missed_doses_reminder_screen.dart';
import 'screens/startup_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MedtimeApp());
}

class MedtimeApp extends StatefulWidget {
  const MedtimeApp({super.key});

  @override
  State<MedtimeApp> createState() => _MedtimeAppState();
}

class _MedtimeAppState extends State<MedtimeApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsService()),
        ChangeNotifierProvider(create: (_) => MedicationService()),
        ChangeNotifierProvider(
          create: (_) {
            final service = NotificationService();
            service.initialize();
            // Set up notification tap callback
            service.setNotificationTappedCallback((payload) {
              _handleNotificationTap(payload);
            });
            return service;
          },
        ),
        ChangeNotifierProvider(create: (_) => AdherenceService()),
      ],
      child: MaterialApp(
        title: 'Medtime',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
        ),
        home: const StartupChecker(),
      ),
    );
  }

  void _handleNotificationTap(String payload) {
    debugPrint('=== Notification Tap Handler ===');
    debugPrint('Received payload: $payload');

    // Check if context is available
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('Context not available yet, will retry when app is ready');
      // Will be checked in StartupChecker after app loads
      return;
    }

    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    final medicationService = Provider.of<MedicationService>(
      context,
      listen: false,
    );
    final adherenceService = Provider.of<AdherenceService>(
      context,
      listen: false,
    );

    // Check if this is a time slot notification (new grouped approach)
    if (payload.contains('timeslot|')) {
      debugPrint('Time slot notification detected');

      // Parse time slot and date from payload
      final timeSlot = notificationService.parseTimeSlotFromPayload(payload);
      final notificationDate =
          notificationService.parseDateFromPayload(payload);

      if (timeSlot == null || notificationDate == null) {
        debugPrint(
            'ERROR: Could not parse time slot or date from payload: $payload');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Invalid notification payload'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      debugPrint('Time slot: ${timeSlot.timeString}, Date: $notificationDate');

      // Get all medications scheduled for this time slot
      final enabledMedications = medicationService.enabledMedications;
      final medicationsForTimeSlot = enabledMedications.where((med) {
        if (!med.enabled) return false;

        // Check if medication has this time slot
        return med.times.any((time) =>
            time.hour == timeSlot.hour && time.minute == timeSlot.minute);
      }).toList();

      if (medicationsForTimeSlot.isEmpty) {
        debugPrint('No medications found for time slot ${timeSlot.timeString}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No medications scheduled for this time'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      debugPrint(
          'Found ${medicationsForTimeSlot.length} medications for time slot ${timeSlot.timeString}');

      // Get doses needing attention for these medications, filtered by time slot
      final medicationIds = medicationsForTimeSlot.map((m) => m.id).toList();
      final allDosesNeedingAttention =
          adherenceService.getDosesNeedingAttention(
        medicationIds: medicationIds,
      );

      // Filter doses to only those scheduled for the notification date and time slot
      final filteredDoses = <String, List<MedicationDose>>{};
      for (final entry in allDosesNeedingAttention.entries) {
        final medicationId = entry.key;
        final doses = entry.value;

        // Filter doses for this date and time slot
        final matchingDoses = doses.where((dose) {
          final doseDate = DateTime(dose.scheduledTime.year,
              dose.scheduledTime.month, dose.scheduledTime.day);
          final notificationDateOnly = DateTime(notificationDate.year,
              notificationDate.month, notificationDate.day);

          return doseDate.isAtSameMomentAs(notificationDateOnly) &&
              dose.scheduledTime.hour == timeSlot.hour &&
              dose.scheduledTime.minute == timeSlot.minute;
        }).toList();

        if (matchingDoses.isNotEmpty) {
          filteredDoses[medicationId] = matchingDoses;
        }
      }

      // Show reminder screen with filtered doses
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MissedDosesReminderScreen(
              dosesNeedingAttention: filteredDoses,
            ),
          ),
        );
      }

      return;
    }

    // Legacy handling for old medication ID based payloads (backward compatibility)
    debugPrint('Legacy medication ID payload detected: $payload');
    debugPrint(
        'WARNING: This is the old notification format. Consider rescheduling notifications.');

    // For backward compatibility, show all missed doses
    final enabledMedications = medicationService.enabledMedications;
    final medicationIds = enabledMedications.map((m) => m.id).toList();
    final dosesNeedingAttention = adherenceService.getDosesNeedingAttention(
      medicationIds: medicationIds,
    );

    if (dosesNeedingAttention.isNotEmpty && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MissedDosesReminderScreen(
            dosesNeedingAttention: dosesNeedingAttention,
          ),
        ),
      );
    }
  }

  /// Check for pending notification tap after app is ready
  void checkPendingNotification() {
    final notificationService = Provider.of<NotificationService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final payload = notificationService.getPendingNotificationPayload();
    if (payload != null && payload.isNotEmpty) {
      debugPrint('Found pending notification with payload: $payload');
      // Small delay to ensure navigation is complete
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationTap(payload);
      });
    }
  }
}
