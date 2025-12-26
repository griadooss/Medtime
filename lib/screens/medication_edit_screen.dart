import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medication.dart';
import '../services/medication_service.dart';
import '../services/notification_service.dart';
import '../services/adherence_service.dart';
import '../services/app_settings_service.dart';

class MedicationEditScreen extends StatefulWidget {
  final Medication? medication;

  const MedicationEditScreen({super.key, this.medication});

  @override
  State<MedicationEditScreen> createState() => _MedicationEditScreenState();
}

class _MedicationEditScreenState extends State<MedicationEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _strengthController;
  late MedicationForm _form;
  late TextEditingController _dosageAmountController;
  late MedicationCategory _category;
  late List<MedicationTime> _times;
  late List<int> _daysOfWeek;
  late bool _skipWeekends;
  late String _iconName;
  late bool _enabled;
  late NotificationBehavior _notificationBehavior;
  late int? _reminderIntervalMinutes;
  bool _isSaving = false;

  final List<String> _availableIcons = [
    'medication',
    'medication_liquid',
    'healing',
    'local_pharmacy',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.medication != null) {
      final med = widget.medication!;
      _nameController = TextEditingController(text: med.name);
      _strengthController = TextEditingController(text: med.strength ?? '');
      _form = med.form;
      _dosageAmountController =
          TextEditingController(text: med.dosageAmount ?? '');
      _category = med.category;
      _times = List.from(med.times);
      _daysOfWeek = List.from(med.daysOfWeek);
      _skipWeekends = med.skipWeekends;
      _iconName = med.iconName;
      _enabled = med.enabled;
      _notificationBehavior = med.notificationBehavior;
      _reminderIntervalMinutes = med.reminderIntervalMinutes;
    } else {
      // Initialize with defaults - will be loaded from settings in didChangeDependencies
      _nameController = TextEditingController();
      _strengthController = TextEditingController();
      _form = MedicationForm.tablet;
      _dosageAmountController = TextEditingController();
      _category = MedicationCategory.other;
      _times = [];
      _daysOfWeek = [];
      _skipWeekends = false;
      _iconName = 'medication';
      _enabled = true;
      _notificationBehavior = NotificationBehavior.dismiss;
      _reminderIntervalMinutes = 15;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load defaults from settings if creating new medication
    if (widget.medication == null) {
      final settingsService =
          Provider.of<AppSettingsService>(context, listen: false);
      setState(() {
        _category = settingsService.defaultCategory;
        _skipWeekends = settingsService.defaultSkipWeekends;
        _iconName = settingsService.defaultIconName;
        _enabled = settingsService.defaultEnabled;
        _notificationBehavior = settingsService.defaultNotificationBehavior;
        _reminderIntervalMinutes =
            settingsService.defaultReminderIntervalMinutes;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _dosageAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medication != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medication' : 'Add Medication'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteMedication(context),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Medication Name
              TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  hintText: 'e.g., Aspirin',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Strength
              TextField(
                controller: _strengthController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Strength (optional)',
                  hintText: 'e.g., 100mg, 50mg, 5ml',
                  border: OutlineInputBorder(),
                  helperText: 'Strength per unit (e.g., 100mg per tablet)',
                  alignLabelWithHint: true,
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),

              // Unit Form
              Text(
                'Unit Form',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: SegmentedButton<MedicationForm>(
                  segments: const [
                    ButtonSegment<MedicationForm>(
                      value: MedicationForm.tablet,
                      label: Text('Tablet'),
                      icon: Icon(Icons.medication),
                    ),
                    ButtonSegment<MedicationForm>(
                      value: MedicationForm.pill,
                      label: Text('Pill'),
                      icon: Icon(Icons.circle),
                    ),
                    ButtonSegment<MedicationForm>(
                      value: MedicationForm.capsule,
                      label: Text('Capsule'),
                      icon: Icon(Icons.medication_liquid),
                    ),
                  ],
                  selected: {_form},
                  onSelectionChanged: (Set<MedicationForm> newSelection) {
                    setState(() {
                      _form = newSelection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    MedicationForm.liquid,
                    MedicationForm.drops,
                    MedicationForm.spray,
                    MedicationForm.patch,
                    MedicationForm.injection,
                    MedicationForm.other,
                  ].map((form) {
                    final isSelected = _form == form;
                    return FilterChip(
                      label: Text(_getFormLabel(form)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _form = form;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Dosage Amount
              TextField(
                controller: _dosageAmountController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Dosage Amount (optional)',
                  hintText: 'e.g., 1, 0.5, 0.25',
                  border: OutlineInputBorder(),
                  helperText:
                      'Enter a number: 1 = one, 0.5 = half, 0.25 = quarter (will display as words)',
                  alignLabelWithHint: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),

              // Category
              Text(
                'Category',
                style: Theme.of(context).textTheme.titleMedium,
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
                  selected: {_category},
                  onSelectionChanged: (Set<MedicationCategory> newSelection) {
                    setState(() {
                      _category = newSelection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Icon selection
              Text(
                'Icon',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: _availableIcons.map((iconName) {
                    final isSelected = _iconName == iconName;
                    return ChoiceChip(
                      label: Icon(_getIconData(iconName)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _iconName = iconName;
                        });
                      },
                      selectedColor: Colors.green[200],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Times
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Times',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addTime,
                    color: Colors.green[400],
                  ),
                ],
              ),
              if (_times.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No times set. Tap + to add.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._times.asMap().entries.map((entry) {
                  final index = entry.key;
                  final time = entry.value;
                  return ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(
                      time.format(),
                      textAlign: TextAlign.center,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _times.removeAt(index);
                        });
                      },
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // Days of week
              Card(
                child: SwitchListTile(
                  title: const Text('Skip Weekends'),
                  subtitle: const Text('Skip Saturday and Sunday'),
                  value: _skipWeekends,
                  onChanged: (value) {
                    setState(() {
                      _skipWeekends = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Days selection (if not skipping weekends)
              if (!_skipWeekends) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Days of Week',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _daysOfWeek.isEmpty
                            ? Colors.green[900]?.withOpacity(0.3)
                            : Colors.grey[800]?.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _daysOfWeek.isEmpty
                              ? Colors.green[300]!
                              : Colors.grey[600]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _daysOfWeek.isEmpty
                            ? '✓ All days selected (every day)'
                            : '${_daysOfWeek.length} day(s) selected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _daysOfWeek.isEmpty
                                  ? Colors.green[300]
                                  : Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          'Sun',
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat'
                        ].asMap().entries.map((entry) {
                          final index = entry.key;
                          final dayName = entry.value;
                          final isSelected = _daysOfWeek.contains(index);
                          return FilterChip(
                            label: Text(dayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _daysOfWeek.add(index);
                                } else {
                                  _daysOfWeek.remove(index);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Notification behavior
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Notification Behavior'),
                      subtitle:
                          const Text('What happens when notification appears'),
                    ),
                    RadioListTile<NotificationBehavior>(
                      title: const Text('Dismiss'),
                      subtitle: const Text('One-time notification'),
                      value: NotificationBehavior.dismiss,
                      groupValue: _notificationBehavior,
                      onChanged: (NotificationBehavior? value) {
                        if (value != null) {
                          setState(() {
                            _notificationBehavior = value;
                          });
                        }
                      },
                    ),
                    RadioListTile<NotificationBehavior>(
                      title: const Text('Remind Me'),
                      subtitle: const Text('Repeat notification until taken'),
                      value: NotificationBehavior.remind,
                      groupValue: _notificationBehavior,
                      onChanged: (NotificationBehavior? value) {
                        if (value != null) {
                          setState(() {
                            _notificationBehavior = value;
                          });
                        }
                      },
                    ),
                    if (_notificationBehavior ==
                        NotificationBehavior.remind) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Reminder Interval: ${_reminderIntervalMinutes ?? 15} minutes',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Slider(
                              value:
                                  (_reminderIntervalMinutes ?? 15).toDouble(),
                              min: 5,
                              max: 60,
                              divisions: 11,
                              label:
                                  '${_reminderIntervalMinutes ?? 15} minutes',
                              onChanged: (value) {
                                setState(() {
                                  _reminderIntervalMinutes = value.round();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Enabled toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Enabled'),
                  subtitle:
                      const Text('Enable notifications for this medication'),
                  value: _enabled,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: (_times.isEmpty || _isSaving)
                    ? null
                    : () => _saveMedication(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(widget.medication != null
                        ? 'Update Medication'
                        : 'Add Medication'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _times.add(MedicationTime.fromFlutter(picked));
        _times.sort((a, b) => a.compareTo(b));
      });
    }
  }

  Future<void> _saveMedication(BuildContext context) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a medication name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Prevent double-tap
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final medicationService = context.read<MedicationService>();
    final notificationService = context.read<NotificationService>();
    final adherenceService = context.read<AdherenceService>();
    final messenger = ScaffoldMessenger.of(context);

    final medication = widget.medication?.copyWith(
          name: _nameController.text.trim(),
          strength: _strengthController.text.trim().isEmpty
              ? null
              : _strengthController.text.trim(),
          form: _form,
          dosageAmount: _dosageAmountController.text.trim().isEmpty
              ? null
              : _dosageAmountController.text.trim(),
          category: _category,
          times: _times,
          daysOfWeek: _daysOfWeek,
          skipWeekends: _skipWeekends,
          iconName: _iconName,
          enabled: _enabled,
          notificationBehavior: _notificationBehavior,
          reminderIntervalMinutes: _reminderIntervalMinutes,
        ) ??
        Medication(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          strength: _strengthController.text.trim().isEmpty
              ? null
              : _strengthController.text.trim(),
          form: _form,
          dosageAmount: _dosageAmountController.text.trim().isEmpty
              ? null
              : _dosageAmountController.text.trim(),
          category: _category,
          times: _times,
          daysOfWeek: _daysOfWeek,
          skipWeekends: _skipWeekends,
          iconName: _iconName,
          enabled: _enabled,
          notificationBehavior: _notificationBehavior,
          reminderIntervalMinutes: _reminderIntervalMinutes,
          createdAt: DateTime.now(),
        );

    try {
      final isEditing = widget.medication != null;

      if (isEditing) {
        await medicationService.updateMedication(medication);
      } else {
        await medicationService.addMedication(medication);
      }

      // Schedule grouped notifications and create dose records
      if (medication.enabled) {
        // Create dose records proactively for adherence tracking
        await adherenceService.createScheduledDosesForMedication(medication);

        // Reschedule all grouped notifications (since medications are grouped by time slot)
        final allMedications = medicationService.medications;
        final enabledMedications =
            allMedications.where((m) => m.enabled).toList();
        await notificationService
            .scheduleAllGroupedNotifications(enabledMedications);

        debugPrint(
            'Rescheduled grouped notifications for all ${enabledMedications.length} enabled medications');
      } else {
        // Medication is disabled - reschedule all to remove it from time slot notifications
        final allMedications = medicationService.medications;
        final enabledMedications =
            allMedications.where((m) => m.enabled).toList();
        await notificationService
            .scheduleAllGroupedNotifications(enabledMedications);
        debugPrint('Rescheduled grouped notifications (medication disabled)');
      }

      if (!context.mounted) return;

      // Show success message
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                isEditing
                    ? 'Medication updated successfully'
                    : 'Medication added successfully',
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate back immediately - success message will show on home screen
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error saving medication: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteMedication(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content:
            Text('Are you sure you want to delete ${widget.medication?.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.medication != null) {
      final medicationService = context.read<MedicationService>();
      final notificationService = context.read<NotificationService>();

      // Delete medication first
      await medicationService.deleteMedication(widget.medication!.id);

      // Reschedule all grouped notifications (to remove this medication from time slots)
      final allMedications = medicationService.medications;
      final enabledMedications =
          allMedications.where((m) => m.enabled).toList();
      await notificationService
          .scheduleAllGroupedNotifications(enabledMedications);

      if (!context.mounted) return;
      Navigator.pop(context);
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

  String _getFormLabel(MedicationForm form) {
    switch (form) {
      case MedicationForm.tablet:
        return 'Tablet';
      case MedicationForm.pill:
        return 'Pill';
      case MedicationForm.capsule:
        return 'Capsule';
      case MedicationForm.liquid:
        return 'Liquid';
      case MedicationForm.drops:
        return 'Drops';
      case MedicationForm.spray:
        return 'Spray';
      case MedicationForm.patch:
        return 'Patch';
      case MedicationForm.injection:
        return 'Injection';
      case MedicationForm.other:
        return 'Other';
    }
  }
}
