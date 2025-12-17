import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/adherence_service.dart';
import '../services/medication_service.dart';

class AdherenceScreen extends StatelessWidget {
  const AdherenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adherenceService = context.watch<AdherenceService>();
    final medicationService = context.watch<MedicationService>();
    final overallStats = adherenceService.getOverallAdherenceStats(days: 30);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adherence'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall stats card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Adherence (30 days)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context,
                            'Taken',
                            overallStats.taken,
                            Colors.green[300]!,
                          ),
                          _buildStatItem(
                            context,
                            'Missed',
                            overallStats.missed,
                            Colors.red[300]!,
                          ),
                          _buildStatItem(
                            context,
                            'Skipped',
                            overallStats.skipped,
                            Colors.orange[300]!,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: overallStats.total > 0
                            ? overallStats.adherenceRate / 100
                            : 0,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green[400]!,
                        ),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${overallStats.adherenceRate.toStringAsFixed(1)}% adherence rate',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.green[300],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Per-medication stats
              Text(
                'By Medication',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ...medicationService.medications.map((medication) {
                final stats = adherenceService.getAdherenceStats(
                  medication.id,
                  days: 30,
                );
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.medication,
                              color: Colors.green[300],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                medication.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              context,
                              'Taken',
                              stats.taken,
                              Colors.green[300]!,
                            ),
                            _buildStatItem(
                              context,
                              'Missed',
                              stats.missed,
                              Colors.red[300]!,
                            ),
                            _buildStatItem(
                              context,
                              'Skipped',
                              stats.skipped,
                              Colors.orange[300]!,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value:
                              stats.total > 0 ? stats.adherenceRate / 100 : 0,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.green[400]!,
                          ),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.adherenceRate.toStringAsFixed(1)}% adherence',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    int value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
              ),
        ),
      ],
    );
  }
}
