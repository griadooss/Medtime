import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medication.dart';
import '../models/medication_dose.dart';
import '../services/adherence_service.dart';

/// Dialog for marking a medication dose as taken or skipped
class DoseMarkingDialog extends StatefulWidget {
  final Medication medication;
  final DateTime scheduledTime;
  final MedicationDose? existingDose;

  const DoseMarkingDialog({
    super.key,
    required this.medication,
    required this.scheduledTime,
    this.existingDose,
  });

  @override
  State<DoseMarkingDialog> createState() => _DoseMarkingDialogState();
}

class _DoseMarkingDialogState extends State<DoseMarkingDialog> {
  String? _notes;

  @override
  Widget build(BuildContext context) {
    final adherenceService = context.read<AdherenceService>();
    final isTaken = widget.existingDose?.isTaken ?? false;
    final isSkipped = widget.existingDose?.skipped ?? false;

    return AlertDialog(
      title: Text(
        widget.medication.name,
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.medication.dosageInstruction.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  widget.medication.dosageInstruction,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green[300],
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            Text(
              'Scheduled: ${_formatTime(widget.scheduledTime)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
              textAlign: TextAlign.center,
            ),
            if (isTaken)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[300]),
                    const SizedBox(width: 8),
                    Text(
                      'Already taken at ${_formatTime(widget.existingDose!.takenTime!)}',
                      style: TextStyle(color: Colors.green[300]),
                    ),
                  ],
                ),
              ),
            if (isSkipped)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: Colors.orange[300]),
                    const SizedBox(width: 8),
                    Text(
                      'Skipped',
                      style: TextStyle(color: Colors.orange[300]),
                    ),
                  ],
                ),
              ),
            if (!isTaken && !isSkipped) ...[
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any notes...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  setState(() {
                    _notes = value.isEmpty ? null : value;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!isTaken && !isSkipped) ...[
          TextButton(
            onPressed: () async {
              // Mark as skipped
              final doseId = widget.existingDose?.id ??
                  '${widget.medication.id}_${widget.scheduledTime.millisecondsSinceEpoch}';

              // Create dose if it doesn't exist
              if (widget.existingDose == null) {
                final dose = MedicationDose(
                  id: doseId,
                  medicationId: widget.medication.id,
                  scheduledTime: widget.scheduledTime,
                  skipped: true,
                  notes: _notes,
                );
                await adherenceService.addScheduledDose(dose);
              } else {
                await adherenceService.markDoseSkipped(doseId, notes: _notes);
              }

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'Skip',
              style: TextStyle(color: Colors.orange[300]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Mark as taken
              final doseId = widget.existingDose?.id ??
                  '${widget.medication.id}_${widget.scheduledTime.millisecondsSinceEpoch}';

              // Create dose if it doesn't exist
              if (widget.existingDose == null) {
                final dose = MedicationDose(
                  id: doseId,
                  medicationId: widget.medication.id,
                  scheduledTime: widget.scheduledTime,
                  takenTime: DateTime.now(),
                  notes: _notes,
                );
                await adherenceService.addScheduledDose(dose);
              } else {
                await adherenceService.markDoseTaken(doseId, notes: _notes);
              }

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.medication.name} marked as taken'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
            ),
            child: const Text('Mark as Taken'),
          ),
        ] else
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
