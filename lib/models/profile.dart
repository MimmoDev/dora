import 'package:meta/meta.dart';

@immutable
class Profile {
  const Profile({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
    this.role = 'user',
    this.createdAt,
    this.profileCompleted = false,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String role;
  final DateTime? createdAt;
  final bool profileCompleted;

  Profile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    DateTime? createdAt,
    bool? profileCompleted,
  }) {
    return Profile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      phone: map['phone'] as String?,
      role: map['role'] as String? ?? 'user',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      profileCompleted: map['profile_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'role': role,
      'profile_completed': profileCompleted,
    };
    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    return map;
  }
}

