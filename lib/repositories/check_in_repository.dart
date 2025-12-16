import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../appwrite_service.dart';
import '../models/check_in.dart';
import 'appointment_repository.dart';
import 'booking_repository.dart';

class CheckInRepository {
  CheckInRepository({Databases? databases})
      : _databases = databases ?? AppwriteService.instance.databases;

  final Databases _databases;

  static const _dbId = 'dora';
  static const _collection = 'check_ins';

  List<String> _perms(String userId) {
    final adminTeam = AppwriteService.instance.adminTeamId;
    return [
      'read(user:$userId)',
      'write(user:$userId)',
      'read(team:$adminTeam)',
      'write(team:$adminTeam)',
    ];
  }

  /// Valida il check-in con QR code (logica client-side)
  Future<Map<String, dynamic>> validateCheckIn(
    String userId,
    String qrPassword,
  ) async {
    // Legge impostazioni
    final settings = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: 'gym_settings',
      queries: [Query.equal('setting_key', 'qr_code_password')],
    );
    final correctPassword = settings.total > 0
        ? settings.documents.first.data['setting_value'] as String
        : null;

    if (correctPassword == null || qrPassword != correctPassword) {
      return {
        'valid': false,
        'status': 'invalid_qr',
        'message': 'QR Code non valido',
      };
    }

    final earlyMinutes = await _readSettingInt('check_in_early_minutes', 30);
    final lateMinutes = await _readSettingInt('check_in_late_minutes', 15);

    // Trova prenotazione odierna
    final bookingRepo = BookingRepository(databases: _databases);
    final today = DateTime.now();
    final bookings = await bookingRepo.getUserBookings(userId,
        status: 'confirmed'); // filtreremo su appuntamenti odierni
    final appointmentRepo = AppointmentRepository(databases: _databases);
    Map<String, dynamic>? target;

    for (final b in bookings) {
      final appt = await appointmentRepo.getAppointment(b.appointmentId);
      if (appt == null) continue;
      if (appt.appointmentDate.toUtc().toIso8601String().split('T')[0] ==
          DateTime(today.year, today.month, today.day)
              .toUtc()
              .toIso8601String()
              .split('T')[0]) {
        target = {
          'booking': b,
          'appointment': appt,
        };
        break;
      }
    }

    if (target == null) {
      return {
        'valid': false,
        'status': 'no_booking',
        'message': 'Non hai prenotazioni per oggi',
      };
    }

    final appt = target['appointment'] as dynamic;
    final booking = target['booking'] as dynamic;
    final now = DateTime.now().toUtc();
    final apptDateTime = appt.fullDateTime.toUtc();
    final diff = now.difference(apptDateTime);

    if (diff < Duration(minutes: -earlyMinutes)) {
      return {
        'valid': false,
        'status': 'early',
        'message':
            'Sei troppo in anticipo. Puoi timbrare $earlyMinutes minuti prima della lezione.',
        'appointment_time': appt.appointmentTime,
        'appointment_title': appt.title,
        'booking_id': booking.id,
        'appointment_id': appt.id,
      };
    }

    if (diff > Duration(minutes: lateMinutes)) {
      return {
        'valid': false,
        'status': 'late',
        'message':
            'Sei in ritardo. Puoi timbrare fino a $lateMinutes minuti dopo l\'inizio.',
        'appointment_time': appt.appointmentTime,
        'appointment_title': appt.title,
        'booking_id': booking.id,
        'appointment_id': appt.id,
      };
    }

    return {
      'valid': true,
      'status': 'valid',
      'message': 'Check-in effettuato con successo!',
      'appointment_time': appt.appointmentTime,
      'appointment_title': appt.title,
      'appointment_description': appt.description,
      'booking_id': booking.id,
      'appointment_id': appt.id,
    };
  }

  Future<int> _readSettingInt(String key, int fallback) async {
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: 'gym_settings',
      queries: [Query.equal('setting_key', key)],
    );
    if (res.total == 0) return fallback;
    return int.tryParse(res.documents.first.data['setting_value'] ?? '') ??
        fallback;
  }

  /// Crea un check-in
  Future<CheckIn> createCheckIn({
    required String userId,
    String? bookingId,
    String? appointmentId,
    required String status,
    String? notes,
  }) async {
    final doc = await _databases.createDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: ID.unique(),
      data: {
        'user_id': userId,
        'booking_id': bookingId,
        'appointment_id': appointmentId,
        'status': status,
        'notes': notes,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      permissions: _perms(userId),
    );
    return CheckIn.fromMap(Map<String, dynamic>.from(doc.data)..['id'] = doc.$id);
  }

  /// Ottiene i check-in dell'utente
  Future<List<CheckIn>> getUserCheckIns(String userId) async {
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('user_id', userId),
        Query.orderDesc('checked_in_at'),
      ],
    );
    return _mapDocs(res.documents);
  }

  /// Ottiene i check-in dell'utente per una data specifica
  Future<List<CheckIn>> getUserCheckInsByDate(
    String userId,
    DateTime date,
  ) async {
    final start = DateTime(date.year, date.month, date.day).toUtc();
    final end = start.add(const Duration(days: 1));

    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('user_id', userId),
        Query.greaterThanEqual('checked_in_at', start.toIso8601String()),
        Query.lessThan('checked_in_at', end.toIso8601String()),
        Query.orderDesc('checked_in_at'),
      ],
    );
    return _mapDocs(res.documents);
  }

  /// [ADMIN] Ottiene tutti i check-in per una data
  Future<List<Map<String, dynamic>>> getCheckInsByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day).toUtc();
    final end = start.add(const Duration(days: 1));

    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.greaterThanEqual('checked_in_at', start.toIso8601String()),
        Query.lessThan('checked_in_at', end.toIso8601String()),
        Query.orderDesc('checked_in_at'),
      ],
    );
    return res.documents
        .map((d) => Map<String, dynamic>.from(d.data)..['id'] = d.$id)
        .toList();
  }

  /// [ADMIN] Ottiene statistiche check-in settimanali
  Future<Map<String, int>> getWeeklyStats(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 7));

    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.greaterThanEqual('checked_in_at', weekStart.toIso8601String()),
        Query.lessThan('checked_in_at', weekEnd.toIso8601String()),
      ],
    );

    final stats = <String, int>{
      'valid': 0,
      'late': 0,
      'early': 0,
      'no_booking': 0,
      'wrong_day': 0,
      'invalid_qr': 0,
    };

    for (final doc in res.documents) {
      final status = doc.data['status'] as String;
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return stats;
  }

  List<CheckIn> _mapDocs(List<models.Document> docs) {
    return docs
        .map((d) => CheckIn.fromMap(Map<String, dynamic>.from(d.data)..['id'] = d.$id))
        .toList();
  }
}

