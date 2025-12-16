import 'package:flutter/material.dart';

/// Medication category
enum MedicationCategory {
  prescription,
  otc,
  other,
}

/// Medication unit form types
enum MedicationForm {
  tablet,
  pill,
  capsule,
  liquid,
  drops,
  spray,
  patch,
  injection,
  other,
}

/// Model representing a medication with schedule and settings
class Medication {
  final String id;
  final String name; // e.g., "Aspirin"
  final String? strength; // e.g., "100mg", "50mg" - strength per unit
  final MedicationForm form; // tablet, pill, capsule, etc.
  final String? dosageAmount; // e.g., "1", "0.5", "0.25" - how many units to take
  final MedicationCategory category; // Prescription, OTC, or Other
  final List<MedicationTime> times; // List of daily times (e.g., 8:00, 14:00, 20:00)
  final List<int> daysOfWeek; // 0=Sunday, 1=Monday, ..., 6=Saturday. Empty = all days
  final bool skipWeekends; // If true, skip Saturday and Sunday
  final String iconName; // Material icon name (e.g., "medication", "medication_liquid")
  final bool enabled; // Whether notifications are enabled
  final NotificationBehavior notificationBehavior; // Dismiss or remind
  final int? reminderIntervalMinutes; // Minutes between reminders (if behavior is remind)
  final DateTime createdAt;
  final DateTime? updatedAt;

  Medication({
    required this.id,
    required this.name,
    this.strength,
    this.form = MedicationForm.tablet,
    this.dosageAmount,
    this.category = MedicationCategory.other,
    required this.times,
    this.daysOfWeek = const [],
    this.skipWeekends = false,
    this.iconName = 'medication',
    this.enabled = true,
    this.notificationBehavior = NotificationBehavior.dismiss,
    this.reminderIntervalMinutes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create medication from JSON
  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String,
      strength: json['strength'] as String?,
      form: () {
        try {
          if (json['form'] != null && json['form'] is String) {
            return MedicationForm.values.firstWhere(
              (e) => e.name == json['form'] as String,
              orElse: () => MedicationForm.tablet,
            );
          }
        } catch (e) {
          // Fallback to tablet if parsing fails
        }
        return MedicationForm.tablet;
      }(),
      dosageAmount: json['dosageAmount'] as String? ?? 
          // Handle legacy 'dosage' field for backward compatibility
          (json['dosage'] as String?),
      category: () {
        try {
          if (json['category'] != null && json['category'] is String) {
            return MedicationCategory.values.firstWhere(
              (e) => e.name == json['category'] as String,
              orElse: () => MedicationCategory.other,
            );
          }
        } catch (e) {
          // Fallback to other if parsing fails
        }
        return MedicationCategory.other;
      }(),
      times: (json['times'] as List<dynamic>)
          .map((t) => MedicationTime.fromJson(t as Map<String, dynamic>))
          .toList(),
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.cast<int>() ?? [],
      skipWeekends: json['skipWeekends'] as bool? ?? false,
      iconName: json['iconName'] as String? ?? 'medication',
      enabled: json['enabled'] as bool? ?? true,
      notificationBehavior: NotificationBehavior.values.firstWhere(
        (e) => e.name == json['notificationBehavior'],
        orElse: () => NotificationBehavior.dismiss,
      ),
      reminderIntervalMinutes: json['reminderIntervalMinutes'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Convert medication to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'strength': strength,
      'form': form.name,
      'dosageAmount': dosageAmount,
      'category': category.name,
      'times': times.map((t) => t.toJson()).toList(),
      'daysOfWeek': daysOfWeek,
      'skipWeekends': skipWeekends,
      'iconName': iconName,
      'enabled': enabled,
      'notificationBehavior': notificationBehavior.name,
      'reminderIntervalMinutes': reminderIntervalMinutes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Medication copyWith({
    String? name,
    String? strength,
    MedicationForm? form,
    String? dosageAmount,
    MedicationCategory? category,
    List<MedicationTime>? times,
    List<int>? daysOfWeek,
    bool? skipWeekends,
    String? iconName,
    bool? enabled,
    NotificationBehavior? notificationBehavior,
    int? reminderIntervalMinutes,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      category: category ?? this.category,
      times: times ?? this.times,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      skipWeekends: skipWeekends ?? this.skipWeekends,
      iconName: iconName ?? this.iconName,
      enabled: enabled ?? this.enabled,
      notificationBehavior: notificationBehavior ?? this.notificationBehavior,
      reminderIntervalMinutes: reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if medication should be taken on a specific day of week
  bool shouldTakeOnDay(int dayOfWeek) {
    // 0=Sunday, 1=Monday, ..., 6=Saturday
    if (skipWeekends && (dayOfWeek == 0 || dayOfWeek == 6)) {
      return false; // Skip weekends
    }
    if (daysOfWeek.isEmpty) {
      return true; // All days
    }
    return daysOfWeek.contains(dayOfWeek);
  }
}

/// Notification behavior options
enum NotificationBehavior {
  dismiss, // One-time notification, dismiss when user dismisses
  remind, // Repeat notification at intervals until taken
}

/// Simple time of day representation
class MedicationTime {
  final int hour;
  final int minute;

  MedicationTime({required this.hour, required this.minute});

  factory MedicationTime.fromJson(Map<String, dynamic> json) {
    return MedicationTime(
      hour: json['hour'] as int,
      minute: json['minute'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'minute': minute,
    };
  }

  /// Format as HH:MM string
  String format() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Create from Flutter's TimeOfDay
  factory MedicationTime.fromFlutter(TimeOfDay flutterTime) {
    return MedicationTime(
      hour: flutterTime.hour,
      minute: flutterTime.minute,
    );
  }

  /// Convert to Flutter's TimeOfDay
  TimeOfDay toFlutter() {
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Compare two times
  int compareTo(MedicationTime other) {
    if (hour != other.hour) {
      return hour.compareTo(other.hour);
    }
    return minute.compareTo(other.minute);
  }
}

