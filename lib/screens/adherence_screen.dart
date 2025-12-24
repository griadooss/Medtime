import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/adherence_service.dart';
import '../services/medication_service.dart';

class AdherenceScreen extends StatefulWidget {
  const AdherenceScreen({super.key});

  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isCustomRange = false;

  String _getDateRangeLabel() {
    if (_isCustomRange) {
      return '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';
    }
    final days = _endDate.difference(_startDate).inDays;
    if (days == 7) return 'Last 7 days';
    if (days == 30) return 'Last 30 days';
    if (days == 90) return 'Last 90 days';
    return '${days} days';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _setQuickRange(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = _endDate.subtract(Duration(days: days));
      _isCustomRange = false;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.green[400]!,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isCustomRange = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adherenceService = context.watch<AdherenceService>();
    final medicationService = context.watch<MedicationService>();
    final overallStats = adherenceService.getOverallAdherenceStatsForDateRange(
      startDate: _startDate,
      endDate: _endDate,
    );

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
              // Date range selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date Range',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      // Quick buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickButton(context, '7 days', 7),
                          _buildQuickButton(context, '30 days', 30),
                          _buildQuickButton(context, '90 days', 90),
                          _buildCustomButton(context),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Current range display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getDateRangeLabel(),
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.green[300],
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                          if (_isCustomRange)
                            TextButton.icon(
                              onPressed: _selectDateRange,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Change'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Overall stats card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Adherence',
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
                final stats = adherenceService.getAdherenceStatsForDateRange(
                  medication.id,
                  startDate: _startDate,
                  endDate: _endDate,
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

  Widget _buildQuickButton(BuildContext context, String label, int days) {
    final isSelected =
        !_isCustomRange && _endDate.difference(_startDate).inDays == days;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setQuickRange(days),
      selectedColor: Colors.green[600],
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[300],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildCustomButton(BuildContext context) {
    return FilterChip(
      label: const Text('Custom'),
      selected: _isCustomRange,
      onSelected: (_) => _selectDateRange(),
      selectedColor: Colors.green[600],
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: _isCustomRange ? Colors.white : Colors.grey[300],
        fontWeight: _isCustomRange ? FontWeight.bold : FontWeight.normal,
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
