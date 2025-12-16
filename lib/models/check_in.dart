import 'package:meta/meta.dart';

@immutable
class CheckIn {
  const CheckIn({
    required this.id,
    required this.userId,
    this.bookingId,
    this.appointmentId,
    required this.checkedInAt,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? bookingId;
  final String? appointmentId;
  final DateTime checkedInAt;
  final String status; // 'valid', 'late', 'early', 'no_booking', 'wrong_day'
  final String? notes;
  final DateTime createdAt;

  bool get isValid => status == 'valid';

  CheckIn copyWith({
    String? id,
    String? userId,
    String? bookingId,
    String? appointmentId,
    DateTime? checkedInAt,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return CheckIn(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookingId: bookingId ?? this.bookingId,
      appointmentId: appointmentId ?? this.appointmentId,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CheckIn.fromMap(Map<String, dynamic> map) {
    return CheckIn(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      bookingId: map['booking_id'] as String?,
      appointmentId: map['appointment_id'] as String?,
      checkedInAt: DateTime.parse(map['checked_in_at'] as String),
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'booking_id': bookingId,
      'appointment_id': appointmentId,
      'checked_in_at': checkedInAt.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}




