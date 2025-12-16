import 'package:meta/meta.dart';

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.userId,
    required this.appointmentId,
    this.status = 'confirmed',
    required this.createdAt,
    this.cancelledAt,
  });

  final String id;
  final String userId;
  final String appointmentId;
  final String status; // 'confirmed', 'cancelled', 'completed'
  final DateTime createdAt;
  final DateTime? cancelledAt;

  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  Booking copyWith({
    String? id,
    String? userId,
    String? appointmentId,
    String? status,
    DateTime? createdAt,
    DateTime? cancelledAt,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      appointmentId: appointmentId ?? this.appointmentId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      appointmentId: map['appointment_id'] as String,
      status: map['status'] as String? ?? 'confirmed',
      createdAt: DateTime.parse(map['created_at'] as String),
      cancelledAt: map['cancelled_at'] != null
          ? DateTime.parse(map['cancelled_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'appointment_id': appointmentId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
    };
  }
}




