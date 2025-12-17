import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/medication.dart';

/// Service for managing medications (CRUD operations)
class MedicationService extends ChangeNotifier {
  List<Medication> _medications = [];
  bool _isLoaded = false;

  List<Medication> get medications => List.unmodifiable(_medications);
  bool get isLoaded => _isLoaded;
  int get medicationCount => _medications.length;

  MedicationService() {
    _loadMedications();
  }

  /// Load medications from storage
  Future<void> _loadMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicationsJson = prefs.getString('medications');

      if (medicationsJson != null) {
        final List<dynamic> decoded = json.decode(medicationsJson);
        _medications = decoded
            .map((json) => Medication.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading medications: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Save medications to storage
  Future<void> _saveMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medicationsJson = json.encode(
        _medications.map((m) => m.toJson()).toList(),
      );
      await prefs.setString('medications', medicationsJson);
    } catch (e) {
      debugPrint('Error saving medications: $e');
    }
  }

  /// Add a new medication
  Future<void> addMedication(Medication medication) async {
    _medications.add(medication);
    await _saveMedications();
    notifyListeners();
  }

  /// Update an existing medication
  Future<void> updateMedication(Medication medication) async {
    final index = _medications.indexWhere((m) => m.id == medication.id);
    if (index != -1) {
      _medications[index] = medication;
      await _saveMedications();
      notifyListeners();
    }
  }

  /// Delete a medication
  Future<void> deleteMedication(String medicationId) async {
    _medications.removeWhere((m) => m.id == medicationId);
    await _saveMedications();
    notifyListeners();
  }

  /// Get medication by ID
  Medication? getMedicationById(String id) {
    try {
      return _medications.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get enabled medications
  List<Medication> get enabledMedications {
    return _medications.where((m) => m.enabled).toList();
  }

  /// Toggle medication enabled state
  Future<void> toggleMedication(String medicationId) async {
    final medication = getMedicationById(medicationId);
    if (medication != null) {
      final updated = medication.copyWith(enabled: !medication.enabled);
      await updateMedication(updated);
    }
  }

  /// Import medications from JSON (for backup restore)
  Future<void> importMedications(List<dynamic> medicationsJson) async {
    try {
      _medications = medicationsJson
          .map((json) => Medication.fromJson(json as Map<String, dynamic>))
          .toList();
      await _saveMedications();
      notifyListeners();
    } catch (e) {
      debugPrint('Error importing medications: $e');
      rethrow;
    }
  }

  /// Export medications as JSON (for backup)
  List<Map<String, dynamic>> exportMedications() {
    return _medications.map((m) => m.toJson()).toList();
  }
}
