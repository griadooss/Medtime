import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';

/// Service for managing app-wide default settings
class AppSettingsService extends ChangeNotifier {
  // Default medication settings
  String _defaultIconName = 'medication';
  bool _defaultEnabled = true;
  NotificationBehavior _defaultNotificationBehavior =
      NotificationBehavior.dismiss;
  int _defaultReminderIntervalMinutes = 15;
  bool _defaultSkipWeekends = false;
  MedicationCategory _defaultCategory = MedicationCategory.other;
  int _missedDoseTimeoutHours = 3; // Auto-dismiss missed doses after 3 hours

  // Getters
  String get defaultIconName => _defaultIconName;
  bool get defaultEnabled => _defaultEnabled;
  NotificationBehavior get defaultNotificationBehavior =>
      _defaultNotificationBehavior;
  int get defaultReminderIntervalMinutes => _defaultReminderIntervalMinutes;
  bool get defaultSkipWeekends => _defaultSkipWeekends;
  MedicationCategory get defaultCategory => _defaultCategory;
  int get missedDoseTimeoutHours => _missedDoseTimeoutHours;

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
        try {
          _defaultNotificationBehavior = NotificationBehavior.values.firstWhere(
            (e) => e.name == behaviorString,
          );
          debugPrint(
              'Loaded notification behavior: ${_defaultNotificationBehavior.name}');
        } catch (e) {
          debugPrint(
              'Invalid notification behavior: $behaviorString, using default');
          _defaultNotificationBehavior = NotificationBehavior.dismiss;
        }
      } else {
        // If not set, keep the default (dismiss)
        _defaultNotificationBehavior = NotificationBehavior.dismiss;
        debugPrint('No saved notification behavior, using default: dismiss');
      }

      debugPrint(
          'Loaded reminder interval: $_defaultReminderIntervalMinutes minutes');

      _defaultReminderIntervalMinutes =
          prefs.getInt('defaultReminderIntervalMinutes') ?? 15;
      _defaultSkipWeekends = prefs.getBool('defaultSkipWeekends') ?? false;
      _missedDoseTimeoutHours = prefs.getInt('missedDoseTimeoutHours') ?? 3;

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
      await prefs.setString(
          'defaultNotificationBehavior', _defaultNotificationBehavior.name);
      await prefs.setInt(
          'defaultReminderIntervalMinutes', _defaultReminderIntervalMinutes);
      await prefs.setBool('defaultSkipWeekends', _defaultSkipWeekends);
      await prefs.setString('defaultCategory', _defaultCategory.name);
      await prefs.setInt('missedDoseTimeoutHours', _missedDoseTimeoutHours);

      debugPrint(
          'Settings saved: notificationBehavior=${_defaultNotificationBehavior.name}, reminderInterval=${_defaultReminderIntervalMinutes}');
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
      debugPrint('setDefaultReminderIntervalMinutes: $minutes');
      notifyListeners();
    } else {
      debugPrint('WARNING: Invalid reminder interval: $minutes (must be 5-60)');
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

  /// Set missed dose timeout (hours)
  void setMissedDoseTimeoutHours(int hours) {
    if (hours >= 1 && hours <= 24) {
      _missedDoseTimeoutHours = hours;
      notifyListeners();
    }
  }

  /// Export settings as JSON (for backup)
  Map<String, dynamic> exportSettings() {
    return {
      'defaultIconName': _defaultIconName,
      'defaultEnabled': _defaultEnabled,
      'defaultNotificationBehavior': _defaultNotificationBehavior.name,
      'defaultReminderIntervalMinutes': _defaultReminderIntervalMinutes,
      'defaultSkipWeekends': _defaultSkipWeekends,
      'defaultCategory': _defaultCategory.name,
    };
  }

  /// Import settings from JSON (for backup restore)
  Future<void> importSettings(Map<String, dynamic> settingsJson) async {
    try {
      _defaultIconName = settingsJson['defaultIconName'] ?? 'medication';
      _defaultEnabled = settingsJson['defaultEnabled'] ?? true;

      final behaviorString = settingsJson['defaultNotificationBehavior'];
      if (behaviorString != null) {
        _defaultNotificationBehavior = NotificationBehavior.values.firstWhere(
          (e) => e.name == behaviorString,
          orElse: () => NotificationBehavior.dismiss,
        );
      }

      _defaultReminderIntervalMinutes =
          settingsJson['defaultReminderIntervalMinutes'] ?? 15;
      _defaultSkipWeekends = settingsJson['defaultSkipWeekends'] ?? false;

      final categoryString = settingsJson['defaultCategory'];
      if (categoryString != null) {
        try {
          _defaultCategory = MedicationCategory.values.firstWhere(
            (e) => e.name == categoryString,
            orElse: () => MedicationCategory.other,
          );
        } catch (e) {
          _defaultCategory = MedicationCategory.other;
        }
      }

      await saveSettings();
    } catch (e) {
      debugPrint('Error importing settings: $e');
      rethrow;
    }
  }
}
