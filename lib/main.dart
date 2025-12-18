import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/medication_service.dart';
import 'services/notification_service.dart';
import 'services/adherence_service.dart';
import 'services/app_settings_service.dart';
import 'screens/dose_marking_dialog.dart';
import 'screens/startup_checker.dart';
import 'models/medication_dose.dart';
import 'models/medication.dart';

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
            service.setNotificationTappedCallback((medicationId) {
              _handleNotificationTap(medicationId);
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

  void _handleNotificationTap(String medicationId) {
    debugPrint('=== Notification Tap Handler ===');
    debugPrint('Received medicationId: $medicationId');

    // Check if context is available
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('Context not available yet, will retry when app is ready');
      // Will be checked in StartupChecker after app loads
      return;
    }

    final medicationService = Provider.of<MedicationService>(
      context,
      listen: false,
    );
    final adherenceService = Provider.of<AdherenceService>(
      context,
      listen: false,
    );

    // Find medication - don't use fallback, show error if not found
    Medication? medication;
    try {
      medication = medicationService.medications.firstWhere(
        (m) => m.id == medicationId,
      );
      debugPrint('Found medication: ${medication.name} (ID: ${medication.id})');
    } catch (e) {
      debugPrint('ERROR: Medication not found for ID: $medicationId');
      debugPrint('Available medications:');
      for (final med in medicationService.medications) {
        debugPrint('  - ${med.name} (ID: ${med.id})');
      }
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Medication not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Find the most recent scheduled dose for this medication
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );

    debugPrint('Looking for dose at: $scheduledTime');

    // Find existing dose or create a new one
    final doses = adherenceService.getDosesForMedication(medicationId);
    debugPrint('Found ${doses.length} doses for medication ${medication.name}');
    MedicationDose? existingDose;

    // Try to find a dose scheduled for today around this time
    for (final dose in doses) {
      if (dose.scheduledTime.year == now.year &&
          dose.scheduledTime.month == now.month &&
          dose.scheduledTime.day == now.day) {
        // Check if it's within 2 hours of the scheduled time
        final diff = (dose.scheduledTime.difference(scheduledTime)).abs();
        if (diff.inHours < 2) {
          existingDose = dose;
          debugPrint('Found existing dose: ${dose.id} at ${dose.scheduledTime}');
          break;
        }
      }
    }

    // If no existing dose, create one for tracking
    if (existingDose == null) {
      debugPrint('No existing dose found, creating new one');
      final dose = MedicationDose(
        id: '${medicationId}_${scheduledTime.millisecondsSinceEpoch}',
        medicationId: medicationId,
        scheduledTime: scheduledTime,
      );
      adherenceService.addScheduledDose(dose);
      existingDose = dose;
      debugPrint('Created new dose: ${dose.id} for medication ${medication.name}');
    }

    // Verify the dose belongs to the correct medication
    if (existingDose.medicationId != medication.id) {
      debugPrint('ERROR: Dose medicationId mismatch!');
      debugPrint('  Dose medicationId: ${existingDose.medicationId}');
      debugPrint('  Medication ID: ${medication.id}');
    }

    // Show dialog (medication is guaranteed to be non-null here due to early return above)
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => DoseMarkingDialog(
          medication: medication!,
          scheduledTime: existingDose!.scheduledTime,
          existingDose: existingDose,
        ),
      );
    } else {
      debugPrint('ERROR: Cannot show dialog - context not mounted');
    }
  }

  /// Check for pending notification tap after app is ready
  void checkPendingNotification() {
    final notificationService = Provider.of<NotificationService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final medicationId = notificationService.getPendingNotificationMedicationId();
    if (medicationId != null && medicationId.isNotEmpty) {
      debugPrint('Found pending notification for: $medicationId');
      // Small delay to ensure navigation is complete
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationTap(medicationId);
      });
    }
  }
}
