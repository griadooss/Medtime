
/// Model representing a single dose that was scheduled or taken
class MedicationDose {
  final String id;
  final String medicationId;
  final DateTime scheduledTime;
  final DateTime? takenTime; // null if not taken
  final bool skipped; // User explicitly skipped
  final String? notes; // Optional notes

  MedicationDose({
    required this.id,
    required this.medicationId,
    required this.scheduledTime,
    this.takenTime,
    this.skipped = false,
    this.notes,
  });

  /// Create dose from JSON
  factory MedicationDose.fromJson(Map<String, dynamic> json) {
    return MedicationDose(
      id: json['id'] as String,
      medicationId: json['medicationId'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      takenTime: json['takenTime'] != null
          ? DateTime.parse(json['takenTime'] as String)
          : null,
      skipped: json['skipped'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  /// Convert dose to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicationId': medicationId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'takenTime': takenTime?.toIso8601String(),
      'skipped': skipped,
      'notes': notes,
    };
  }

  /// Create a copy with updated fields
  MedicationDose copyWith({
    DateTime? takenTime,
    bool? skipped,
    String? notes,
  }) {
    return MedicationDose(
      id: id,
      medicationId: medicationId,
      scheduledTime: scheduledTime,
      takenTime: takenTime ?? this.takenTime,
      skipped: skipped ?? this.skipped,
      notes: notes ?? this.notes,
    );
  }

  /// Check if dose was taken
  bool get isTaken => takenTime != null;

  /// Check if dose was missed (scheduled time passed and not taken)
  bool isMissed(DateTime now) {
    return !isTaken && !skipped && scheduledTime.isBefore(now);
  }

  /// Get adherence status
  AdherenceStatus getStatus(DateTime now) {
    if (isTaken) {
      return AdherenceStatus.taken;
    } else if (skipped) {
      return AdherenceStatus.skipped;
    } else if (isMissed(now)) {
      return AdherenceStatus.missed;
    } else {
      return AdherenceStatus.pending;
    }
  }

  /// Get formatted date string
  String get dateString {
    return '${scheduledTime.year}-${scheduledTime.month.toString().padLeft(2, '0')}-${scheduledTime.day.toString().padLeft(2, '0')}';
  }

  /// Get formatted time string
  String get timeString {
    return '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Adherence status for a dose
enum AdherenceStatus {
  pending, // Not yet due
  taken, // Taken on time or late
  missed, // Past due and not taken
  skipped, // User explicitly skipped
}

