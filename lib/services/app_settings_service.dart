import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';

/// Service for managing app-wide default settings
class AppSettingsService extends ChangeNotifier {
  // Default medication settings
  String _defaultIconName = 'medication';
  bool _defaultEnabled = true;
  NotificationBehavior _defaultNotificationBehavior = NotificationBehavior.dismiss;
  int _defaultReminderIntervalMinutes = 15;
  bool _defaultSkipWeekends = false;
  MedicationCategory _defaultCategory = MedicationCategory.other;

  // Getters
  String get defaultIconName => _defaultIconName;
  bool get defaultEnabled => _defaultEnabled;
  NotificationBehavior get defaultNotificationBehavior => _defaultNotificationBehavior;
  int get defaultReminderIntervalMinutes => _defaultReminderIntervalMinutes;
  bool get defaultSkipWeekends => _defaultSkipWeekends;
  MedicationCategory get defaultCategory => _defaultCategory;

  AppSettingsService() {
    _loadSettings();
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _defaultIconName = prefs.getString('defaultIconName') ?? 'medication';
      _defaultEnabled = prefs.getBool('defaultEnabled') ?? true;
      
      final behaviorString = prefs.getString('defaultNotificationBehavior');
      if (behaviorString != null) {
        _defaultNotificationBehavior = NotificationBehavior.values.firstWhere(
          (e) => e.name == behaviorString,
          orElse: () => NotificationBehavior.dismiss,
        );
      }
      
      _defaultReminderIntervalMinutes = prefs.getInt('defaultReminderIntervalMinutes') ?? 15;
      _defaultSkipWeekends = prefs.getBool('defaultSkipWeekends') ?? false;
      
      final categoryString = prefs.getString('defaultCategory');
      if (categoryString != null) {
        try {
          _defaultCategory = MedicationCategory.values.firstWhere(
            (e) => e.name == categoryString,
            orElse: () => MedicationCategory.other,
          );
        } catch (e) {
          _defaultCategory = MedicationCategory.other;
        }
      } else {
        _defaultCategory = MedicationCategory.other;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading app settings: $e');
    }
  }

  /// Save settings to storage
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('defaultIconName', _defaultIconName);
      await prefs.setBool('defaultEnabled', _defaultEnabled);
      await prefs.setString('defaultNotificationBehavior', _defaultNotificationBehavior.name);
      await prefs.setInt('defaultReminderIntervalMinutes', _defaultReminderIntervalMinutes);
      await prefs.setBool('defaultSkipWeekends', _defaultSkipWeekends);
      await prefs.setString('defaultCategory', _defaultCategory.name);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving app settings: $e');
    }
  }

  /// Set default icon name
  void setDefaultIconName(String iconName) {
    _defaultIconName = iconName;
    notifyListeners();
  }

  /// Set default enabled state
  void setDefaultEnabled(bool enabled) {
    _defaultEnabled = enabled;
    notifyListeners();
  }

  /// Set default notification behavior
  void setDefaultNotificationBehavior(NotificationBehavior behavior) {
    _defaultNotificationBehavior = behavior;
    notifyListeners();
  }

  /// Set default reminder interval
  void setDefaultReminderIntervalMinutes(int minutes) {
    if (minutes >= 5 && minutes <= 60) {
      _defaultReminderIntervalMinutes = minutes;
      notifyListeners();
    }
  }

  /// Set default skip weekends
  void setDefaultSkipWeekends(bool skip) {
    _defaultSkipWeekends = skip;
    notifyListeners();
  }

  /// Set default category
  void setDefaultCategory(MedicationCategory category) {
    _defaultCategory = category;
    notifyListeners();
  }
}

