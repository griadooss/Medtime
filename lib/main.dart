import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/medication_service.dart';
import 'services/notification_service.dart';
import 'services/adherence_service.dart';
import 'services/app_settings_service.dart';
import 'screens/medication_list_screen.dart';
import 'screens/dose_marking_dialog.dart';
import 'models/medication_dose.dart';

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
        home: const MedicationListScreen(),
      ),
    );
  }

  void _handleNotificationTap(String medicationId) {
    final medicationService = Provider.of<MedicationService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final adherenceService = Provider.of<AdherenceService>(
      navigatorKey.currentContext!,
      listen: false,
    );

    final medication = medicationService.medications.firstWhere(
      (m) => m.id == medicationId,
      orElse: () => medicationService.medications.first,
    );

    // Find the most recent scheduled dose for this medication
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );

    // Find existing dose or create a new one
    final doses = adherenceService.getDosesForMedication(medicationId);
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
          break;
        }
      }
    }

    // If no existing dose, create one for tracking
    if (existingDose == null) {
      final dose = MedicationDose(
        id: '${medicationId}_${scheduledTime.millisecondsSinceEpoch}',
        medicationId: medicationId,
        scheduledTime: scheduledTime,
      );
      adherenceService.addScheduledDose(dose);
      existingDose = dose;
    }

    // Show dialog
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => DoseMarkingDialog(
        medication: medication,
        scheduledTime: existingDose!.scheduledTime,
        existingDose: existingDose,
      ),
    );
  }
}
