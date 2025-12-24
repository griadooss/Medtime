import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/medication_dose.dart';
import '../models/medication.dart';

/// Service for tracking medication adherence
class AdherenceService extends ChangeNotifier {
  List<MedicationDose> _doses = [];
  bool _isLoaded = false;

  List<MedicationDose> get doses => List.unmodifiable(_doses);
  bool get isLoaded => _isLoaded;

  AdherenceService() {
    _loadDoses();
  }

  /// Load doses from storage
  Future<void> _loadDoses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dosesJson = prefs.getString('medication_doses');

      if (dosesJson != null) {
        final List<dynamic> decoded = json.decode(dosesJson);
        _doses = decoded
            .map(
                (json) => MedicationDose.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading doses: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Save doses to storage
  Future<void> _saveDoses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dosesJson = json.encode(
        _doses.map((d) => d.toJson()).toList(),
      );
      await prefs.setString('medication_doses', dosesJson);
    } catch (e) {
      debugPrint('Error saving doses: $e');
    }
  }

  /// Mark a dose as taken
  Future<void> markDoseTaken(String doseId, {String? notes}) async {
    final index = _doses.indexWhere((d) => d.id == doseId);
    if (index != -1) {
      _doses[index] = _doses[index].copyWith(
        takenTime: DateTime.now(),
        notes: notes,
      );
      await _saveDoses();
      notifyListeners();
    }
  }

  /// Mark a dose as skipped
  Future<void> markDoseSkipped(String doseId, {String? notes}) async {
    final index = _doses.indexWhere((d) => d.id == doseId);
    if (index != -1) {
      _doses[index] = _doses[index].copyWith(
        skipped: true,
        notes: notes,
      );
      await _saveDoses();
      notifyListeners();
    }
  }

  /// Add a scheduled dose
  Future<void> addScheduledDose(MedicationDose dose) async {
    // Check if dose already exists
    if (!_doses.any((d) => d.id == dose.id)) {
      _doses.add(dose);
      await _saveDoses();
      notifyListeners();
    }
  }

  /// Get doses for a medication
  List<MedicationDose> getDosesForMedication(String medicationId) {
    return _doses.where((d) => d.medicationId == medicationId).toList();
  }

  /// Get doses for a specific date
  List<MedicationDose> getDosesForDate(DateTime date) {
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _doses.where((d) => d.dateString == dateString).toList();
  }

  /// Get adherence statistics for a medication
  AdherenceStats getAdherenceStats(String medicationId, {int days = 30}) {
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: days));

    final relevantDoses = _doses
        .where((d) =>
            d.medicationId == medicationId &&
            d.scheduledTime.isAfter(cutoffDate))
        .toList();

    final taken = relevantDoses.where((d) => d.isTaken).length;
    final missed = relevantDoses.where((d) => d.isMissed(now)).length;
    final skipped = relevantDoses.where((d) => d.skipped).length;
    final pending = relevantDoses
        .where((d) => !d.isTaken && !d.skipped && !d.isMissed(now))
        .length;

    final total = relevantDoses.length;
    final adherenceRate = total > 0 ? (taken / total * 100) : 0.0;

    return AdherenceStats(
      total: total,
      taken: taken,
      missed: missed,
      skipped: skipped,
      pending: pending,
      adherenceRate: adherenceRate,
    );
  }

  /// Get overall adherence statistics
  AdherenceStats getOverallAdherenceStats({int days = 30}) {
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: days));

    final relevantDoses =
        _doses.where((d) => d.scheduledTime.isAfter(cutoffDate)).toList();

    final taken = relevantDoses.where((d) => d.isTaken).length;
    final missed = relevantDoses.where((d) => d.isMissed(now)).length;
    final skipped = relevantDoses.where((d) => d.skipped).length;
    final pending = relevantDoses
        .where((d) => !d.isTaken && !d.skipped && !d.isMissed(now))
        .length;

    final total = relevantDoses.length;
    final adherenceRate = total > 0 ? (taken / total * 100) : 0.0;

    return AdherenceStats(
      total: total,
      taken: taken,
      missed: missed,
      skipped: skipped,
      pending: pending,
      adherenceRate: adherenceRate,
    );
  }

  /// Get adherence statistics for a medication within a date range
  AdherenceStats getAdherenceStatsForDateRange(
    String medicationId, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final now = DateTime.now();
    final startOfStartDate =
        DateTime(startDate.year, startDate.month, startDate.day);
    final endOfEndDate =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final relevantDoses = _doses
        .where((d) =>
            d.medicationId == medicationId &&
            d.scheduledTime.isAfter(
                startOfStartDate.subtract(const Duration(seconds: 1))) &&
            d.scheduledTime
                .isBefore(endOfEndDate.add(const Duration(seconds: 1))))
        .toList();

    final taken = relevantDoses.where((d) => d.isTaken).length;
    final missed = relevantDoses.where((d) => d.isMissed(now)).length;
    final skipped = relevantDoses.where((d) => d.skipped).length;
    final pending = relevantDoses
        .where((d) => !d.isTaken && !d.skipped && !d.isMissed(now))
        .length;

    final total = relevantDoses.length;
    final adherenceRate = total > 0 ? (taken / total * 100) : 0.0;

    return AdherenceStats(
      total: total,
      taken: taken,
      missed: missed,
      skipped: skipped,
      pending: pending,
      adherenceRate: adherenceRate,
    );
  }

  /// Get overall adherence statistics within a date range
  AdherenceStats getOverallAdherenceStatsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final now = DateTime.now();
    final startOfStartDate =
        DateTime(startDate.year, startDate.month, startDate.day);
    final endOfEndDate =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final relevantDoses = _doses
        .where((d) =>
            d.scheduledTime.isAfter(
                startOfStartDate.subtract(const Duration(seconds: 1))) &&
            d.scheduledTime
                .isBefore(endOfEndDate.add(const Duration(seconds: 1))))
        .toList();

    final taken = relevantDoses.where((d) => d.isTaken).length;
    final missed = relevantDoses.where((d) => d.isMissed(now)).length;
    final skipped = relevantDoses.where((d) => d.skipped).length;
    final pending = relevantDoses
        .where((d) => !d.isTaken && !d.skipped && !d.isMissed(now))
        .length;

    final total = relevantDoses.length;
    final adherenceRate = total > 0 ? (taken / total * 100) : 0.0;

    return AdherenceStats(
      total: total,
      taken: taken,
      missed: missed,
      skipped: skipped,
      pending: pending,
      adherenceRate: adherenceRate,
    );
  }

  /// Delete old doses (older than specified days)
  Future<void> cleanupOldDoses(int keepDays) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    _doses.removeWhere((d) => d.scheduledTime.isBefore(cutoffDate));
    await _saveDoses();
    notifyListeners();
  }

  /// Import doses from JSON (for backup restore)
  Future<void> importDoses(List<dynamic> dosesJson) async {
    try {
      _doses = dosesJson
          .map((json) => MedicationDose.fromJson(json as Map<String, dynamic>))
          .toList();
      await _saveDoses();
      notifyListeners();
    } catch (e) {
      debugPrint('Error importing doses: $e');
      rethrow;
    }
  }

  /// Export doses as JSON (for backup)
  List<Map<String, dynamic>> exportDoses() {
    return _doses.map((d) => d.toJson()).toList();
  }

  /// Get the most recent missed dose (previous scheduled time only)
  /// Returns the dose that was scheduled most recently but not taken
  MedicationDose? getMostRecentMissedDose(String medicationId) {
    final now = DateTime.now();
    final doses = getDosesForMedication(medicationId)
        .where((d) => d.isMissed(now))
        .toList();

    if (doses.isEmpty) return null;

    // Return the most recent missed dose (closest to now)
    doses.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    return doses.first;
  }

  /// Get all missed doses (for adherence tracking - historical)
  List<MedicationDose> getMissedDoses({DateTime? now}) {
    final checkTime = now ?? DateTime.now();
    return _doses.where((d) => d.isMissed(checkTime)).toList();
  }

  /// Get pending doses (due within next 15 minutes)
  List<MedicationDose> getPendingDoses({DateTime? now}) {
    final checkTime = now ?? DateTime.now();
    final cutoffTime = checkTime.add(const Duration(minutes: 15));

    return _doses.where((d) {
      return !d.isTaken &&
          !d.skipped &&
          d.scheduledTime.isAfter(checkTime) &&
          d.scheduledTime.isBefore(cutoffTime);
    }).toList();
  }

  /// Get doses that need attention (missed only) for reminder screen
  /// Only shows doses that have actually been missed (scheduled time has passed)
  /// Returns map grouped by medication
  Map<String, List<MedicationDose>> getDosesNeedingAttention({
    required List<String> medicationIds,
  }) {
    final result = <String, List<MedicationDose>>{};

    for (final medicationId in medicationIds) {
      final doses = <MedicationDose>[];

      // Get most recent missed dose (only previous scheduled time)
      // Only show doses that have actually been missed (time has passed)
      final missedDose = getMostRecentMissedDose(medicationId);
      if (missedDose != null) {
        doses.add(missedDose);
      }

      // Removed pending doses - only show actually missed doses
      // The notification system handles scheduled reminders

      if (doses.isNotEmpty) {
        result[medicationId] = doses;
      }
    }

    return result;
  }

  /// Create dose records for a medication's schedule (proactive tracking)
  /// This creates dose records for the next 30 days when scheduling notifications
  Future<void> createScheduledDosesForMedication(Medication medication) async {
    if (!medication.enabled) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Create doses for next 30 days
    for (int dayOffset = 0; dayOffset < 30; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final dayOfWeek = (targetDate.weekday % 7);

      // Check if medication should be taken on this day
      if (!medication.shouldTakeOnDay(dayOfWeek)) {
        continue;
      }

      // Create dose for each scheduled time
      for (final time in medication.times) {
        final scheduledDateTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          time.hour,
          time.minute,
        );

        // For today, create dose records even if time has passed (up to 24 hours ago)
        // This allows us to detect missed doses when the app is opened later
        if (dayOffset == 0) {
          final oneDayAgo = now.subtract(const Duration(hours: 24));
          if (scheduledDateTime.isBefore(oneDayAgo)) {
            // Skip if more than 24 hours old
            continue;
          }
          // Otherwise, create the dose record even if it's in the past
          // This allows detection of missed doses
        }

        // Create dose record
        final doseId =
            '${medication.id}_${scheduledDateTime.millisecondsSinceEpoch}';
        final dose = MedicationDose(
          id: doseId,
          medicationId: medication.id,
          scheduledTime: scheduledDateTime,
        );

        // Add dose (will skip if already exists)
        await addScheduledDose(dose);
      }
    }
  }
}

/// Adherence statistics
class AdherenceStats {
  final int total;
  final int taken;
  final int missed;
  final int skipped;
  final int pending;
  final double adherenceRate;

  AdherenceStats({
    required this.total,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.pending,
    required this.adherenceRate,
  });
}
