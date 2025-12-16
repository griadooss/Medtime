import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/medication_dose.dart';

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
            .map((json) => MedicationDose.fromJson(json as Map<String, dynamic>))
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
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _doses.where((d) => d.dateString == dateString).toList();
  }

  /// Get adherence statistics for a medication
  AdherenceStats getAdherenceStats(String medicationId, {int days = 30}) {
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: days));
    
    final relevantDoses = _doses.where((d) =>
      d.medicationId == medicationId &&
      d.scheduledTime.isAfter(cutoffDate)
    ).toList();

    final taken = relevantDoses.where((d) => d.isTaken).length;
    final missed = relevantDoses.where((d) => d.isMissed(now)).length;
    final skipped = relevantDoses.where((d) => d.skipped).length;
    final pending = relevantDoses.where((d) => 
      !d.isTaken && !d.skipped && !d.isMissed(now)
    ).length;

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
    
    final relevantDoses = _doses.where((d) =>
      d.scheduledTime.isAfter(cutoffDate)
    ).toList();

    final taken = relevantDoses.where((d) => d.isTaken).length;
    final missed = relevantDoses.where((d) => d.isMissed(now)).length;
    final skipped = relevantDoses.where((d) => d.skipped).length;
    final pending = relevantDoses.where((d) => 
      !d.isTaken && !d.skipped && !d.isMissed(now)
    ).length;

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

