import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/medication_service.dart';
import '../services/adherence_service.dart';
import '../models/medication.dart';
import 'medication_edit_screen.dart';
import 'adherence_screen.dart';
import 'settings_screen.dart';

class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  MedicationCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medtime',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Adherence',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdherenceScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<MedicationService>(
        builder: (context, medicationService, child) {
          if (!medicationService.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter and sort medications
          var medications = medicationService.medications;
          
          // Filter by category if selected
          if (_filterCategory != null) {
            medications = medications.where((m) => m.category == _filterCategory).toList();
          }
          
          // Sort by category, then by name
          medications = List.from(medications)
            ..sort((a, b) {
              final categoryCompare = a.category.index.compareTo(b.category.index);
              if (categoryCompare != 0) return categoryCompare;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

          return Column(
            children: [
              // Category filter chips
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _filterCategory == null,
                        onSelected: (selected) {
                          setState(() {
                            _filterCategory = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Script'),
                        selected: _filterCategory == MedicationCategory.prescription,
                        onSelected: (selected) {
                          setState(() {
                            _filterCategory = selected
                                ? MedicationCategory.prescription
                                : null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('OTC'),
                        selected: _filterCategory == MedicationCategory.otc,
                        onSelected: (selected) {
                          setState(() {
                            _filterCategory = selected
                                ? MedicationCategory.otc
                                : null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Other'),
                        selected: _filterCategory == MedicationCategory.other,
                        onSelected: (selected) {
                          setState(() {
                            _filterCategory = selected
                                ? MedicationCategory.other
                                : null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              
              // Medications list
              if (medications.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medication,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filterCategory == null
                              ? 'No medications yet'
                              : 'No medications in this category',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[400],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterCategory == null
                              ? 'Tap + to add your first medication'
                              : 'Tap + to add a medication',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final medication = medications[index];
                      return _buildMedicationCard(context, medication);
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MedicationEditScreen(),
            ),
          );
        },
        backgroundColor: Colors.green[600],
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context, Medication medication) {
    final adherenceService = context.read<AdherenceService>();
    final stats = adherenceService.getAdherenceStats(medication.id, days: 7);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MedicationEditScreen(medication: medication),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconData(medication.iconName),
                    size: 32,
                    color: medication.enabled
                        ? Colors.green[300]
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                medication.name,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: medication.enabled
                                          ? null
                                          : Colors.grey[500],
                                    ),
                              ),
                              if (medication.strength != null && medication.strength!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '(${medication.strength})',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[400],
                                      ),
                                ),
                              ],
                              if (medication.dosageInstruction.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  medication.dosageInstruction,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.green[300],
                                      ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Category badge
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(medication.category).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getCategoryColor(medication.category),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _getCategoryLabel(medication.category),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: _getCategoryColor(medication.category),
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  Switch(
                    value: medication.enabled,
                    onChanged: (value) {
                      context.read<MedicationService>().toggleMedication(medication.id);
                    },
                    activeColor: Colors.green[400],
                    activeTrackColor: Colors.green[300],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Times
              Center(
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: medication.times.map((time) {
                    return Chip(
                      label: Text(
                        time.format(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.green[50],
                      labelStyle: TextStyle(color: Colors.green[900]),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              // Adherence stats
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[300]),
                    const SizedBox(width: 4),
                    Text(
                      '${stats.taken}/${stats.total} taken (${stats.adherenceRate.toStringAsFixed(0)}%)',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                    ),
                    if (stats.missed > 0) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.cancel, size: 16, color: Colors.red[300]),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.missed} missed',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red[300],
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  String _getCategoryLabel(MedicationCategory category) {
    switch (category) {
      case MedicationCategory.prescription:
        return 'Script';
      case MedicationCategory.otc:
        return 'OTC';
      case MedicationCategory.other:
        return 'Other';
    }
  }

  Color _getCategoryColor(MedicationCategory category) {
    switch (category) {
      case MedicationCategory.prescription:
        return Colors.red[300]!;
      case MedicationCategory.otc:
        return Colors.blue[300]!;
      case MedicationCategory.other:
        return Colors.grey[400]!;
    }
  }
}

