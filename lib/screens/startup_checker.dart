import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/medication_service.dart';
import '../services/adherence_service.dart';
import '../services/notification_service.dart';
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
    final medicationIds =
        enabledMedications.map((m) => m.id).toList();

    if (medicationIds.isEmpty) {
      debugPrint('StartupChecker: No enabled medications found');
      return;
    }

    debugPrint('StartupChecker: Checking ${medicationIds.length} medications for missed/pending doses');

    // Ensure dose records exist for today's scheduled times
    // This is important if the app wasn't open when notifications fired
    for (final medication in enabledMedications) {
      await adherenceService.createScheduledDosesForMedication(medication);
    }

    // Get doses needing attention
    final dosesNeedingAttention =
        adherenceService.getDosesNeedingAttention(
      medicationIds: medicationIds,
    );

    debugPrint('StartupChecker: Found ${dosesNeedingAttention.length} medications with doses needing attention');
    for (final entry in dosesNeedingAttention.entries) {
      final medication = enabledMedications.firstWhere((m) => m.id == entry.key);
      debugPrint('  - ${medication.name}: ${entry.value.length} dose(s)');
      for (final dose in entry.value) {
        final status = dose.isMissed(DateTime.now()) ? 'MISSED' : 'PENDING';
        debugPrint('    * $status at ${dose.timeString}');
      }
    }

    // Show reminder screen if there are missed or pending doses
    if (dosesNeedingAttention.isNotEmpty && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MissedDosesReminderScreen(
            dosesNeedingAttention: dosesNeedingAttention,
          ),
        ),
      ).then((_) {
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
    final medicationId = notificationService.getPendingNotificationMedicationId();
    if (medicationId != null && medicationId.isNotEmpty) {
      debugPrint('StartupChecker: Found pending notification for: $medicationId');
      // Small delay to ensure everything is ready, then trigger the callback
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          notificationService.triggerNotificationTapCallback(medicationId);
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



