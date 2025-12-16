import 'package:meta/meta.dart';

@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.appointmentDate,
    required this.appointmentTime,
    this.durationMinutes = 60,
    this.maxParticipants = 10,
    this.currentParticipants = 0,
    required this.title,
    this.description,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final DateTime appointmentDate;
  final String appointmentTime; // "HH:mm" format
  final int durationMinutes;
  final int maxParticipants;
  final int currentParticipants;
  final String title;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isFull => currentParticipants >= maxParticipants;
  bool get hasAvailableSpots => currentParticipants < maxParticipants;
  int get availableSpots => maxParticipants - currentParticipants;

  DateTime get fullDateTime {
    final timeParts = appointmentTime.split(':');
    return DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  Appointment copyWith({
    String? id,
    DateTime? appointmentDate,
    String? appointmentTime,
    int? durationMinutes,
    int? maxParticipants,
    int? currentParticipants,
    String? title,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] as String,
      appointmentDate: DateTime.parse(map['appointment_date'] as String),
      appointmentTime: map['appointment_time'] as String,
      durationMinutes: map['duration_minutes'] as int? ?? 60,
      maxParticipants: map['max_participants'] as int? ?? 10,
      currentParticipants: map['current_participants'] as int? ?? 0,
      title: map['title'] as String,
      description: map['description'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointment_date': appointmentDate.toIso8601String().split('T')[0],
      'appointment_time': appointmentTime,
      'duration_minutes': durationMinutes,
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
      'title': title,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}




