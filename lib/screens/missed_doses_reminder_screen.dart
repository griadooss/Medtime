import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medication.dart';
import '../models/medication_dose.dart';
import '../services/medication_service.dart';
import '../services/adherence_service.dart';
import 'medication_list_screen.dart';

/// Full-screen reminder for missed and pending medication doses
class MissedDosesReminderScreen extends StatefulWidget {
  final Map<String, List<MedicationDose>> dosesNeedingAttention;

  const MissedDosesReminderScreen({
    super.key,
    required this.dosesNeedingAttention,
  });

  @override
  State<MissedDosesReminderScreen> createState() =>
      _MissedDosesReminderScreenState();
}

class _MissedDosesReminderScreenState
    extends State<MissedDosesReminderScreen> {
  final Map<String, bool> _processingDoses = {};

  @override
  Widget build(BuildContext context) {
    final medicationService = context.watch<MedicationService>();
    final adherenceService = context.watch<AdherenceService>();
    final now = DateTime.now();

    // Recalculate doses needing attention (in case they were marked)
    final enabledMedications = medicationService.enabledMedications;
    final medicationIds = enabledMedications.map((m) => m.id).toList();
    final currentDosesNeedingAttention =
        adherenceService.getDosesNeedingAttention(
      medicationIds: medicationIds,
    );

    // If no doses need attention, navigate back to home
    if (currentDosesNeedingAttention.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MedicationListScreen(),
            ),
          );
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Separate missed and pending doses
    final missedDoses = <String, List<MedicationDose>>{};
    final pendingDoses = <String, List<MedicationDose>>{};

    for (final entry in currentDosesNeedingAttention.entries) {
      final medicationId = entry.key;
      final doses = entry.value;

      final missed = doses.where((d) => d.isMissed(now)).toList();
      final pending = doses.where((d) => !d.isMissed(now)).toList();

      if (missed.isNotEmpty) {
        missedDoses[medicationId] = missed;
      }
      if (pending.isNotEmpty) {
        pendingDoses[medicationId] = pending;
      }
    }

    final totalDoses = currentDosesNeedingAttention.values
        .expand((doses) => doses)
        .where((d) => !d.isTaken && !d.skipped)
        .length;

    final takenDoses = currentDosesNeedingAttention.values
        .expand((doses) => doses)
        .where((d) => d.isTaken)
        .length;

    final remainingDoses = totalDoses - takenDoses;

    return WillPopScope(
      onWillPop: () async {
        // Prevent dismissing if there are unmarked doses
        if (remainingDoses > 0) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Dismiss Reminder?'),
              content: Text(
                'You have $remainingDoses unmarked dose(s). '
                'Are you sure you want to dismiss this reminder?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          );
          return confirmed ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medication Reminder'),
          automaticallyImplyLeading: false,
          actions: [
            if (remainingDoses == 0)
              IconButton(
                icon: const Icon(Icons.check_circle),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const MedicationListScreen(),
                    ),
                  );
                },
                tooltip: 'All doses marked',
              )
            else
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Dismiss Reminder?'),
                      content: Text(
                        'You have $remainingDoses unmarked dose(s). '
                        'Are you sure you want to dismiss?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    Navigator.pop(context);
                  }
                },
                tooltip: 'Dismiss',
              ),
          ],
        ),
        body: Column(
          children: [
            // Progress indicator
            if (totalDoses > 0)
              Container(
                padding: const EdgeInsets.all(16),
                color: remainingDoses == 0
                    ? Colors.green[900]
                    : Colors.orange[900],
                child: Row(
                  children: [
                    Icon(
                      remainingDoses == 0
                          ? Icons.check_circle
                          : Icons.warning,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            remainingDoses == 0
                                ? 'All doses marked!'
                                : '$remainingDoses of $totalDoses dose(s) remaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (totalDoses > 0)
                            LinearProgressIndicator(
                              value: takenDoses / totalDoses,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Missed doses section
                  if (missedDoses.isNotEmpty) ...[
                    Text(
                      'Missed Doses',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.red[300],
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...missedDoses.entries.map((entry) {
                      final medicationId = entry.key;
                      final doses = entry.value;
                      final medication =
                          medicationService.getMedicationById(medicationId);
                      if (medication == null) return const SizedBox.shrink();

                      return _buildMedicationCard(
                        context,
                        medication,
                        doses,
                        adherenceService,
                        isMissed: true,
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // Pending doses section
                  if (pendingDoses.isNotEmpty) ...[
                    Text(
                      'Due Soon',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.orange[300],
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...pendingDoses.entries.map((entry) {
                      final medicationId = entry.key;
                      final doses = entry.value;
                      final medication =
                          medicationService.getMedicationById(medicationId);
                      if (medication == null) return const SizedBox.shrink();

                      return _buildMedicationCard(
                        context,
                        medication,
                        doses,
                        adherenceService,
                        isMissed: false,
                      );
                    }),
                  ],

                  // Empty state
                  if (missedDoses.isEmpty && pendingDoses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All caught up!',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No missed or pending doses.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(
    BuildContext context,
    Medication medication,
    List<MedicationDose> doses,
    AdherenceService adherenceService, {
    required bool isMissed,
  }) {
    final now = DateTime.now();
    final dose = doses.first; // Show the most recent missed or first pending

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isMissed ? Colors.red[900]?.withOpacity(0.3) : Colors.orange[900]?.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medication name and info
            Row(
              children: [
                Icon(
                  _getIconData(medication.iconName),
                  color: isMissed ? Colors.red[300] : Colors.orange[300],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (medication.dosageInstruction.isNotEmpty)
                        Text(
                          medication.dosageInstruction,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scheduled time and status
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  'Scheduled: ${_formatTime(dose.scheduledTime)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (isMissed)
                  Text(
                    _getTimeAgo(dose.scheduledTime, now),
                    style: TextStyle(
                      color: Colors.red[300],
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Text(
                    'Due in ${_getTimeUntil(dose.scheduledTime, now)}',
                    style: TextStyle(
                      color: Colors.orange[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            if (!dose.isTaken && !dose.skipped)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processingDoses[dose.id] == true
                          ? null
                          : () => _markAsSkipped(
                                context,
                                dose,
                                adherenceService,
                              ),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Skip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[300],
                        side: BorderSide(color: Colors.orange[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _processingDoses[dose.id] == true
                          ? null
                          : () => _markAsTaken(
                                context,
                                dose,
                                adherenceService,
                              ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark as Taken'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            else if (dose.isTaken)
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[300]),
                  const SizedBox(width: 8),
                  Text(
                    'Taken at ${_formatTime(dose.takenTime!)}',
                    style: TextStyle(color: Colors.green[300]),
                  ),
                ],
              )
            else if (dose.skipped)
              Row(
                children: [
                  Icon(Icons.cancel, color: Colors.orange[300]),
                  const SizedBox(width: 8),
                  Text(
                    'Skipped',
                    style: TextStyle(color: Colors.orange[300]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsTaken(
    BuildContext context,
    MedicationDose dose,
    AdherenceService adherenceService,
  ) async {
    setState(() {
      _processingDoses[dose.id] = true;
    });

    try {
      await adherenceService.markDoseTaken(dose.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dose marked as taken'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingDoses[dose.id] = false;
        });
      }
    }
  }

  Future<void> _markAsSkipped(
    BuildContext context,
    MedicationDose dose,
    AdherenceService adherenceService,
  ) async {
    setState(() {
      _processingDoses[dose.id] = true;
    });

    try {
      await adherenceService.markDoseSkipped(dose.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dose marked as skipped'),
            backgroundColor: Colors.orange[600],
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingDoses[dose.id] = false;
        });
      }
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

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _getTimeAgo(DateTime scheduledTime, DateTime now) {
    final difference = now.difference(scheduledTime);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }
  }

  String _getTimeUntil(DateTime scheduledTime, DateTime now) {
    final difference = scheduledTime.difference(now);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    }
  }
}

