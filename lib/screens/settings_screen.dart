import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/medication_service.dart';
import '../services/adherence_service.dart';
import '../services/notification_service.dart';
import '../services/app_settings_service.dart';
import '../models/medication.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _defaultIconName;
  late bool _defaultEnabled;
  late NotificationBehavior _defaultNotificationBehavior;
  late int _defaultReminderIntervalMinutes;
  late bool _defaultSkipWeekends;
  late MedicationCategory _defaultCategory;

  final List<String> _availableIcons = [
    'medication',
    'medication_liquid',
    'healing',
    'local_pharmacy',
  ];

  @override
  void initState() {
    super.initState();
    final settingsService = context.read<AppSettingsService>();
    _defaultIconName = settingsService.defaultIconName;
    _defaultEnabled = settingsService.defaultEnabled;
    _defaultNotificationBehavior = settingsService.defaultNotificationBehavior;
    _defaultReminderIntervalMinutes = settingsService.defaultReminderIntervalMinutes;
    _defaultSkipWeekends = settingsService.defaultSkipWeekends;
    _defaultCategory = settingsService.defaultCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Notifications section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Consumer<NotificationService>(
                        builder: (context, notificationService, child) {
                          return Column(
                            children: [
                              ListTile(
                                title: const Text('Notification Permission'),
                                subtitle: Text(
                                  notificationService.permissionGranted
                                      ? 'Granted'
                                      : 'Not granted',
                                  style: TextStyle(
                                    color: notificationService.permissionGranted
                                        ? Colors.green[300]
                                        : Colors.orange[300],
                                  ),
                                ),
                                trailing: notificationService.permissionGranted
                                    ? Icon(Icons.check_circle, color: Colors.green[300])
                                    : Icon(Icons.warning, color: Colors.orange[300]),
                              ),
                              if (!notificationService.permissionGranted)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await notificationService.initialize();
                                    },
                                    child: const Text('Request Permission'),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Default Medication Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Default Medication Settings',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'These settings will be used as defaults when adding new medications',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Default Category
                      Text(
                        'Default Category',
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: SegmentedButton<MedicationCategory>(
                        segments: const [
                          ButtonSegment<MedicationCategory>(
                            value: MedicationCategory.prescription,
                            label: Text('Script'),
                            icon: Icon(Icons.medication),
                          ),
                          ButtonSegment<MedicationCategory>(
                            value: MedicationCategory.otc,
                            label: Text('OTC'),
                            icon: Icon(Icons.local_pharmacy),
                          ),
                          ButtonSegment<MedicationCategory>(
                            value: MedicationCategory.other,
                            label: Text('Other'),
                            icon: Icon(Icons.category),
                          ),
                        ],
                        selected: {_defaultCategory},
                        onSelectionChanged: (Set<MedicationCategory> newSelection) {
                          setState(() {
                            _defaultCategory = newSelection.first;
                          });
                        },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Default Icon
                      Text(
                        'Default Icon',
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Wrap(
                          spacing: 12,
                          alignment: WrapAlignment.center,
                          children: _availableIcons.map((iconName) {
                          final isSelected = _defaultIconName == iconName;
                          return ChoiceChip(
                            label: Icon(_getIconData(iconName)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _defaultIconName = iconName;
                              });
                            },
                            selectedColor: Colors.green[200],
                          );
                        }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Default Notification Behavior
                      Text(
                        'Default Notification Behavior',
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<NotificationBehavior>(
                        title: const Text('Dismiss'),
                        subtitle: const Text('One-time notification'),
                        value: NotificationBehavior.dismiss,
                        groupValue: _defaultNotificationBehavior,
                        onChanged: (NotificationBehavior? value) {
                          if (value != null) {
                            setState(() {
                              _defaultNotificationBehavior = value;
                            });
                          }
                        },
                      ),
                      RadioListTile<NotificationBehavior>(
                        title: const Text('Remind Me'),
                        subtitle: const Text('Repeat notification until taken'),
                        value: NotificationBehavior.remind,
                        groupValue: _defaultNotificationBehavior,
                        onChanged: (NotificationBehavior? value) {
                          if (value != null) {
                            setState(() {
                              _defaultNotificationBehavior = value;
                            });
                          }
                        },
                      ),
                      if (_defaultNotificationBehavior == NotificationBehavior.remind) ...[
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Default Reminder Interval: $_defaultReminderIntervalMinutes minutes',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              Slider(
                                value: _defaultReminderIntervalMinutes.toDouble(),
                                min: 5,
                                max: 60,
                                divisions: 11,
                                label: '$_defaultReminderIntervalMinutes minutes',
                                onChanged: (value) {
                                  setState(() {
                                    _defaultReminderIntervalMinutes = value.round();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Default Skip Weekends
                      SwitchListTile(
                        title: const Text('Default Skip Weekends'),
                        subtitle: const Text('Skip Saturday and Sunday by default'),
                        value: _defaultSkipWeekends,
                        onChanged: (value) {
                          setState(() {
                            _defaultSkipWeekends = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Default Enabled
                      SwitchListTile(
                        title: const Text('Default Enabled'),
                        subtitle: const Text('Enable notifications by default'),
                        value: _defaultEnabled,
                        onChanged: (value) {
                          setState(() {
                            _defaultEnabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Save button
                      ElevatedButton(
                        onPressed: () => _saveDefaultSettings(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Save Default Settings'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Data export section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Export Data',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Export medications and adherence data to CSV',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Consumer2<MedicationService, AdherenceService>(
                        builder: (context, medicationService, adherenceService, child) {
                          return ElevatedButton.icon(
                            onPressed: () => _exportData(context, medicationService, adherenceService),
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export to CSV'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              backgroundColor: Colors.green[600],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // About section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.language, size: 20),
                        title: const Text('Website'),
                        subtitle: const Text('medtime.zimpics.com'),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => _launchUrl('https://medtime.zimpics.com'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.privacy_tip, size: 20),
                        title: const Text('Privacy Policy'),
                        subtitle: const Text('View our privacy policy'),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => _launchUrl('https://medtime.zimpics.com/privacy.html'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(
    BuildContext context,
    MedicationService medicationService,
    AdherenceService adherenceService,
  ) async {
    try {
      final medications = medicationService.medications;
      final doses = adherenceService.doses;

      // Create CSV content
      final buffer = StringBuffer();
      
      // Medications header
      buffer.writeln('Medications');
      buffer.writeln('ID,Name,Strength,Form,Dosage Amount,Category,Enabled,Times,Days of Week,Skip Weekends,Icon,Notification Behavior,Reminder Interval (min),Created At');
      
      for (final med in medications) {
        final timesStr = med.times.map((t) => t.format()).join(';');
        final daysStr = med.daysOfWeek.isEmpty ? 'All' : med.daysOfWeek.join(';');
        buffer.writeln([
          med.id,
          _escapeCsv(med.name),
          _escapeCsv(med.strength ?? ''),
          med.form.name,
          _escapeCsv(med.dosageAmount ?? ''),
          med.category.name,
          med.enabled,
          timesStr,
          daysStr,
          med.skipWeekends,
          med.iconName,
          med.notificationBehavior.name,
          med.reminderIntervalMinutes ?? '',
          med.createdAt.toIso8601String(),
        ].join(','));
      }

      buffer.writeln();
      buffer.writeln('Doses');
      buffer.writeln('ID,Medication ID,Scheduled Time,Taken Time,Skipped,Notes');

      for (final dose in doses) {
        buffer.writeln([
          dose.id,
          dose.medicationId,
          dose.scheduledTime.toIso8601String(),
          dose.takenTime?.toIso8601String() ?? '',
          dose.skipped,
          _escapeCsv(dose.notes ?? ''),
        ].join(','));
      }

      // Share the CSV
      await Share.share(
        buffer.toString(),
        subject: 'Medtime Data Export',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _saveDefaultSettings(BuildContext context) async {
    final settingsService = context.read<AppSettingsService>();
    
    settingsService.setDefaultIconName(_defaultIconName);
    settingsService.setDefaultEnabled(_defaultEnabled);
    settingsService.setDefaultNotificationBehavior(_defaultNotificationBehavior);
    settingsService.setDefaultReminderIntervalMinutes(_defaultReminderIntervalMinutes);
    settingsService.setDefaultSkipWeekends(_defaultSkipWeekends);
    settingsService.setDefaultCategory(_defaultCategory);
    
    await settingsService.saveSettings();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'medication':
        return Icons.medication;
      case 'medication_liquid':
        return Icons.medication_liquid;
      case 'healing':
        return Icons.healing;
      case 'local_pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.medication;
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Handle error
      }
    } catch (e) {
      // Handle error
    }
  }
}

