import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/medication_service.dart';
import 'services/notification_service.dart';
import 'services/adherence_service.dart';
import 'services/app_settings_service.dart';
import 'screens/medication_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MedtimeApp());
}

class MedtimeApp extends StatelessWidget {
  const MedtimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsService()),
        ChangeNotifierProvider(create: (_) => MedicationService()),
        ChangeNotifierProvider(create: (_) => NotificationService()..initialize()),
        ChangeNotifierProvider(create: (_) => AdherenceService()),
      ],
      child: MaterialApp(
        title: 'Medtime',
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
}
