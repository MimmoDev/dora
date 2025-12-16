import 'package:meta/meta.dart';

@immutable
class Subscription {
  const Subscription({
    required this.id,
    required this.userId,
    this.subscriptionType = 'mensile',
    this.status = 'inactive',
    this.startDate,
    this.endDate,
    required this.createdAt,
    this.updatedAt,
    this.activatedBy,
  });

  final String id;
  final String userId;
  final String subscriptionType;
  final String status; // 'active', 'inactive', 'expired', 'cancelled'
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? activatedBy;

  bool get isActive {
    if (status != 'active') return false;
    
    // Usa UTC per il confronto per evitare problemi di timezone
    final nowUtc = DateTime.now().toUtc();
    
    // Verifica startDate: deve essere null o nel passato/presente (non nel futuro)
    if (startDate != null) {
      final startUtc = startDate!.toUtc();
      if (startUtc.isAfter(nowUtc)) {
        return false;
      }
    }
    
    // Verifica endDate: deve essere null o nel futuro/presente (non nel passato)
    if (endDate != null) {
      final endUtc = endDate!.toUtc();
      if (endUtc.isBefore(nowUtc)) {
        return false;
      }
    }
    
    return true;
  }

  // Getter per il tipo in formato leggibile
  String get type => subscriptionType;

  // Getter per i giorni rimanenti fino alla scadenza
  int? get daysUntilExpiry {
    if (endDate == null) return null;
    final now = DateTime.now();
    final difference = endDate!.difference(now);
    return difference.inDays;
  }

  Subscription copyWith({
    String? id,
    String? userId,
    String? subscriptionType,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? activatedBy,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activatedBy: activatedBy ?? this.activatedBy,
    );
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      subscriptionType: map['subscription_type'] as String? ?? 'mensile',
      status: map['status'] as String? ?? 'inactive',
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : null,
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      activatedBy: map['activated_by'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'subscription_type': subscriptionType,
      'status': status,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'activated_by': activatedBy,
    };
  }
}

