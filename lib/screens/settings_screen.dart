import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:io';
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
  late int _missedDoseTimeoutHours;

  final List<String> _availableIcons = [
    'medication',
    'medication_liquid',
    'healing',
    'local_pharmacy',
  ];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Listen for changes from AppSettingsService
    context.read<AppSettingsService>().addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    context.read<AppSettingsService>().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted || _isSaving) return;
    _loadSettings();
  }

  void _loadSettings() {
    final settingsService = context.read<AppSettingsService>();
    setState(() {
      _defaultIconName = settingsService.defaultIconName;
      _defaultEnabled = settingsService.defaultEnabled;
      _defaultNotificationBehavior = settingsService.defaultNotificationBehavior;
      _defaultReminderIntervalMinutes =
          settingsService.defaultReminderIntervalMinutes;
      _defaultSkipWeekends = settingsService.defaultSkipWeekends;
      _defaultCategory = settingsService.defaultCategory;
      _missedDoseTimeoutHours = settingsService.missedDoseTimeoutHours;
    });
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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[900]?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification sound with Bluetooth:',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.blue[300],
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'If sound doesn\'t play through Bluetooth:\n'
                              '• Try disconnecting/reconnecting Bluetooth\n'
                              '• Check Settings → Connected devices → Bluetooth → [Your device]\n'
                              '  Ensure "Media audio" is enabled\n'
                              '• Sound works when Bluetooth is OFF\n'
                              '• This is a known Android Bluetooth routing behavior',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.blue[300],
                                  ),
                            ),
                          ],
                        ),
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
                                    ? Icon(Icons.check_circle,
                                        color: Colors.green[300])
                                    : Icon(Icons.warning,
                                        color: Colors.orange[300]),
                              ),
                              if (!notificationService.permissionGranted)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await notificationService.initialize();
                                    },
                                    child: const Text('Request Permission'),
                                  ),
                                ),
                              if (notificationService.permissionGranted) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await notificationService
                                          .showTestNotification();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Test notification sent'),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    icon:
                                        const Icon(Icons.notifications_active),
                                    label: const Text(
                                        'Test Notification (Immediate)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      minimumSize:
                                          const Size(double.infinity, 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await notificationService
                                          .scheduleTestNotification(
                                              secondsFromNow: 10);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Test notification scheduled for 10 seconds from now'),
                                            backgroundColor: Colors.blue,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.schedule),
                                    label: const Text(
                                        'Test Scheduled Notification (10s)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      minimumSize:
                                          const Size(double.infinity, 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final pending = await notificationService
                                          .getPendingNotifications();
                                      final testNotification = pending
                                          .where((n) => n.id == 999998)
                                          .toList();
                                      if (context.mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                                'Pending Notifications'),
                                            content: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Total: ${pending.length}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  if (testNotification
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green[900]
                                                            ?.withOpacity(0.3),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Test Notification Found:',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                          Text(
                                                              'ID: ${testNotification.first.id}'),
                                                          Text(
                                                              'Title: ${testNotification.first.title}'),
                                                          Text(
                                                              'Body: ${testNotification.first.body}'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'Upcoming notifications (sorted by time):',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ..._parseAndSortNotifications(pending).take(20).map((info) {
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets
                                                              .only(bottom: 12),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(12),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[900]?.withOpacity(0.5),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: info.isReminder
                                                                ? Colors.orange[700]!
                                                                : Colors.green[700]!,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            // Date and time header
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.schedule,
                                                                  size: 16,
                                                                  color: Colors.green[300],
                                                                ),
                                                                const SizedBox(width: 6),
                                                                Text(
                                                                  info.formattedDateTime,
                                                                  style: TextStyle(
                                                                    color: Colors.green[300],
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: 15,
                                                                  ),
                                                                ),
                                                                if (info.isReminder) ...[
                                                                  const SizedBox(width: 8),
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal: 6,
                                                                      vertical: 2,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.orange[900]?.withOpacity(0.5),
                                                                      borderRadius: BorderRadius.circular(4),
                                                                    ),
                                                                    child: Text(
                                                                      'REMINDER',
                                                                      style: TextStyle(
                                                                        color: Colors.orange[300],
                                                                        fontSize: 10,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                            const SizedBox(height: 8),
                                                            // Title
                                                            Text(
                                                              info.title,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            // Body/description
                                                            if (info.description.isNotEmpty)
                                                              Text(
                                                                info.description,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.grey[400],
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.list),
                                    label: const Text(
                                        'Check Pending Notifications'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      minimumSize:
                                          const Size(double.infinity, 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Clear All Notifications?'),
                                          content: const Text(
                                            'This will cancel all scheduled notifications. '
                                            'Your medications and adherence data will NOT be affected. '
                                            'You can reschedule notifications by saving any medication or restarting the app.\n\n'
                                            'Continue?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Clear All'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true && context.mounted) {
                                        await notificationService
                                            .cancelAllNotifications();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'All notifications cleared'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.clear_all),
                                    label: const Text('Clear All Notifications'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange[600],
                                      minimumSize:
                                          const Size(double.infinity, 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Reschedule All Notifications?'),
                                          content: const Text(
                                            'This will cancel and reschedule all notifications for all enabled medications. '
                                            'This is useful if notifications are missing or incorrect.\n\n'
                                            'Continue?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Reschedule All'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true && context.mounted) {
                                        final medicationService =
                                            context.read<MedicationService>();
                                        final enabledMedications =
                                            medicationService.enabledMedications;

                                        if (enabledMedications.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'No enabled medications found. Enable medications first.'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        // Cancel all existing notifications first
                                        await notificationService.cancelAllNotifications();

                                        // Schedule grouped notifications for all enabled medications
                                        await notificationService
                                            .scheduleAllGroupedNotifications(enabledMedications);

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Rescheduled grouped notifications for ${enabledMedications.length} enabled medication(s)'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Reschedule All Notifications'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      minimumSize:
                                          const Size(double.infinity, 40),
                                    ),
                                  ),
                                ),
                              ],
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
                          onSelectionChanged:
                              (Set<MedicationCategory> newSelection) {
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
                      if (_defaultNotificationBehavior ==
                          NotificationBehavior.remind) ...[
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
                                value:
                                    _defaultReminderIntervalMinutes.toDouble(),
                                min: 5,
                                max: 60,
                                divisions: 11,
                                label:
                                    '$_defaultReminderIntervalMinutes minutes',
                                onChanged: (value) {
                                  setState(() {
                                    _defaultReminderIntervalMinutes =
                                        value.round();
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
                        subtitle:
                            const Text('Skip Saturday and Sunday by default'),
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

                      // Missed Dose Timeout
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Missed Dose Auto-Dismiss: $_missedDoseTimeoutHours hours',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Automatically dismiss missed doses after this time',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Slider(
                              value: _missedDoseTimeoutHours.toDouble(),
                              min: 1,
                              max: 12,
                              divisions: 11,
                              label: '$_missedDoseTimeoutHours hours',
                              onChanged: (value) {
                                setState(() {
                                  _missedDoseTimeoutHours = value.round();
                                });
                              },
                            ),
                          ],
                        ),
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
                        builder: (context, medicationService, adherenceService,
                            child) {
                          return ElevatedButton.icon(
                            onPressed: () => _exportData(
                                context, medicationService, adherenceService),
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

              // Backup & Restore section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Backup & Restore',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[900]?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⚠️ WARNING: Uninstalling the app will delete all your data!\n'
                          'Always backup before uninstalling or updating.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[300],
                                    fontWeight: FontWeight.w500,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Consumer3<MedicationService, AdherenceService,
                          AppSettingsService>(
                        builder: (context, medicationService, adherenceService,
                            settingsService, child) {
                          return Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _backupData(
                                    context,
                                    medicationService,
                                    adherenceService,
                                    settingsService),
                                icon: const Icon(Icons.backup),
                                label: const Text('Backup All Data (JSON)'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  backgroundColor: Colors.blue[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _restoreData(
                                    context,
                                    medicationService,
                                    adherenceService,
                                    settingsService),
                                icon: const Icon(Icons.restore),
                                label: const Text('Restore from Backup'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
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
                        onTap: () => _launchUrl(
                            'https://medtime.zimpics.com/privacy.html'),
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
      buffer.writeln(
          'ID,Name,Strength,Form,Dosage Amount,Category,Enabled,Times,Days of Week,Skip Weekends,Icon,Notification Behavior,Reminder Interval (min),Created At');

      for (final med in medications) {
        final timesStr = med.times.map((t) => t.format()).join(';');
        final daysStr =
            med.daysOfWeek.isEmpty ? 'All' : med.daysOfWeek.join(';');
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
      buffer
          .writeln('ID,Medication ID,Scheduled Time,Taken Time,Skipped,Notes');

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

    debugPrint('=== Saving Default Settings ===');
    debugPrint('Reminder interval before save: $_defaultReminderIntervalMinutes');
    debugPrint('Notification behavior before save: ${_defaultNotificationBehavior.name}');

    _isSaving = true;
    try {
      settingsService.setDefaultIconName(_defaultIconName);
      settingsService.setDefaultEnabled(_defaultEnabled);
      settingsService
          .setDefaultNotificationBehavior(_defaultNotificationBehavior);
      settingsService
          .setDefaultReminderIntervalMinutes(_defaultReminderIntervalMinutes);
      settingsService.setDefaultSkipWeekends(_defaultSkipWeekends);
      settingsService.setDefaultCategory(_defaultCategory);
      settingsService.setMissedDoseTimeoutHours(_missedDoseTimeoutHours);

      await settingsService.saveSettings();

      // Verify the save
      debugPrint('Reminder interval after save: ${settingsService.defaultReminderIntervalMinutes}');
      debugPrint('Notification behavior after save: ${settingsService.defaultNotificationBehavior.name}');

      // Reload from service to ensure UI is in sync
      if (mounted) {
        setState(() {
          _defaultReminderIntervalMinutes =
              settingsService.defaultReminderIntervalMinutes;
          _defaultNotificationBehavior =
              settingsService.defaultNotificationBehavior;
        });
      }
    } finally {
      _isSaving = false;
    }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open URL: $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _backupData(
    BuildContext context,
    MedicationService medicationService,
    AdherenceService adherenceService,
    AppSettingsService settingsService,
  ) async {
    try {
      final backup = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'medications': medicationService.exportMedications(),
        'doses': adherenceService.exportDoses(),
        'settings': settingsService.exportSettings(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = 'medtime_backup_$timestamp.json';

      // Create temporary file with .json extension
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(jsonString);

      // Share the backup file with proper filename and MIME type
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json', name: filename)],
        text: 'Medtime Backup',
        subject: 'Medtime Backup',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Backup created: $filename\nSave this file to restore your data later.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreData(
    BuildContext context,
    MedicationService medicationService,
    AdherenceService adherenceService,
    AppSettingsService settingsService,
  ) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Backup'),
          content: const Text(
            'This will replace all current data with the backup.\n\n'
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Restore'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User cancelled
      }

      // Read and parse backup file
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final backup = json.decode(jsonString) as Map<String, dynamic>;

      // Restore data
      await medicationService
          .importMedications(backup['medications'] as List<dynamic>);
      await adherenceService.importDoses(backup['doses'] as List<dynamic>);
      await settingsService
          .importSettings(backup['settings'] as Map<String, dynamic>);

      // Reschedule notifications for all medications
      final notificationService = context.read<NotificationService>();
      for (final medication in medicationService.medications) {
        if (medication.enabled) {
          await notificationService.scheduleMedicationNotifications(medication);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Parse and sort notifications chronologically
  List<_NotificationInfo> _parseAndSortNotifications(
      List<PendingNotificationRequest> notifications) {
    final List<_NotificationInfo> parsed = [];

    for (final n in notifications) {
      DateTime? scheduledDateTime;
      bool isReminder = false;
      String description = n.body ?? '';

      // Parse new time slot payload format: "timeslot|HH:MM|YYYY-MM-DD" or "reminder|timeslot|HH:MM|YYYY-MM-DD"
      if (n.payload != null && n.payload!.contains('timeslot|')) {
        try {
          final parts = n.payload!.split('|');

          if (parts[0] == 'reminder' && parts.length >= 4) {
            // Format: "reminder|timeslot|HH:MM|YYYY-MM-DD"
            isReminder = true;
            final timeStr = parts[2];
            final dateStr = parts[3];

            final timeParts = timeStr.split(':');
            final dateParts = dateStr.split('-');

            if (timeParts.length == 2 && dateParts.length == 3) {
              scheduledDateTime = DateTime(
                int.parse(dateParts[0]), // year
                int.parse(dateParts[1]), // month
                int.parse(dateParts[2]), // day
                int.parse(timeParts[0]), // hour
                int.parse(timeParts[1]), // minute
              );
            }
          } else if (parts[0] == 'timeslot' && parts.length >= 3) {
            // Format: "timeslot|HH:MM|YYYY-MM-DD"
            final timeStr = parts[1];
            final dateStr = parts[2];

            final timeParts = timeStr.split(':');
            final dateParts = dateStr.split('-');

            if (timeParts.length == 2 && dateParts.length == 3) {
              scheduledDateTime = DateTime(
                int.parse(dateParts[0]), // year
                int.parse(dateParts[1]), // month
                int.parse(dateParts[2]), // day
                int.parse(timeParts[0]), // hour
                int.parse(timeParts[1]), // minute
              );
            }
          }
        } catch (e) {
          debugPrint('Error parsing notification payload: $e');
        }
      }

      // If we couldn't parse from payload, try to get from notification's scheduled time
      // (This is a fallback for test notifications or legacy format)
      if (scheduledDateTime == null) {
        // For now, use current time as fallback (not ideal, but better than nothing)
        scheduledDateTime = DateTime.now();
      }

      // Format date/time for display
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final scheduledDate = DateTime(
        scheduledDateTime.year,
        scheduledDateTime.month,
        scheduledDateTime.day,
      );

      String formattedDateTime;
      if (scheduledDate.isAtSameMomentAs(today)) {
        // Today - show time only
        final hour = scheduledDateTime.hour;
        final minute = scheduledDateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        formattedDateTime = 'Today at $displayHour:$minute $period';
      } else if (scheduledDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
        // Tomorrow
        final hour = scheduledDateTime.hour;
        final minute = scheduledDateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        formattedDateTime = 'Tomorrow at $displayHour:$minute $period';
      } else {
        // Other dates - show full date and time
        final monthNames = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        final hour = scheduledDateTime.hour;
        final minute = scheduledDateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        formattedDateTime = '${scheduledDateTime.day} ${monthNames[scheduledDateTime.month - 1]} ${scheduledDateTime.year} at $displayHour:$minute $period';
      }

      parsed.add(_NotificationInfo(
        scheduledDateTime: scheduledDateTime,
        title: n.title ?? 'Notification',
        description: description,
        isReminder: isReminder,
        formattedDateTime: formattedDateTime,
      ));
    }

    // Sort chronologically
    parsed.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

    return parsed;
  }
}

/// Helper class to hold parsed notification information
class _NotificationInfo {
  final DateTime scheduledDateTime;
  final String title;
  final String description;
  final bool isReminder;
  final String formattedDateTime;

  _NotificationInfo({
    required this.scheduledDateTime,
    required this.title,
    required this.description,
    required this.isReminder,
    required this.formattedDateTime,
  });
}
