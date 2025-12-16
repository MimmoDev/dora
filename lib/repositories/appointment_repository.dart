import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../appwrite_service.dart';
import '../models/appointment.dart';

class AppointmentRepository {
  AppointmentRepository({Databases? databases, Realtime? realtime})
      : _databases = databases ?? AppwriteService.instance.databases,
        _realtime = realtime ?? AppwriteService.instance.realtime;

  final Databases _databases;
  final Realtime _realtime;

  static const _dbId = 'dora';
  static const _collection = 'appointments';

  List<String> _permsForAppointment(String createdBy) {
    final adminTeam = AppwriteService.instance.adminTeamId;
    return [
      'read("users")', // tutti autenticati possono leggere
      'read("team:$adminTeam")',
      'write("team:$adminTeam")',
      'read("user:$createdBy")',
      'write("user:$createdBy")', // opzionale per creatore
    ];
  }

  /// Ottiene tutti gli appuntamenti disponibili (futuri)
  Future<List<Appointment>> getAvailableAppointments() async {
    final todayIso = DateTime.now().toUtc().toIso8601String();
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.greaterThanEqual('appointment_date', todayIso),
        Query.orderAsc('appointment_date'),
        Query.orderAsc('appointment_time'),
      ],
    );
    return _mapDocs(res.documents);
  }

  /// Ottiene gli appuntamenti per una data specifica
  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    final dateIso = DateTime(date.year, date.month, date.day)
        .toUtc()
        .toIso8601String();
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('appointment_date', dateIso),
        Query.orderAsc('appointment_time'),
      ],
    );
    return _mapDocs(res.documents);
  }

  /// Ottiene gli appuntamenti per una settimana
  Future<List<Appointment>> getAppointmentsForWeek(DateTime weekStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final effectiveStart =
        weekStart.isBefore(today) && weekEnd.isAfter(today) ? today : weekStart;

    final startIso =
        DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day)
            .toUtc()
            .toIso8601String();
    final endIso = DateTime(weekEnd.year, weekEnd.month, weekEnd.day)
        .toUtc()
        .toIso8601String();

    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.greaterThanEqual('appointment_date', startIso),
        Query.lessThan('appointment_date', endIso),
        Query.orderAsc('appointment_date'),
        Query.orderAsc('appointment_time'),
      ],
    );
    return _mapDocs(res.documents);
  }

  /// Ottiene un singolo appuntamento
  Future<Appointment?> getAppointment(String appointmentId) async {
    try {
      final doc = await _databases.getDocument(
        databaseId: _dbId,
        collectionId: _collection,
        documentId: appointmentId,
      );
      final map = Map<String, dynamic>.from(doc.data)..['id'] = doc.$id;
      return Appointment.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Stream degli appuntamenti disponibili
  Stream<List<Appointment>> watchAvailableAppointments() {
    final controller = StreamController<List<Appointment>>();

    Future<void> push() async {
      final data = await getAvailableAppointments();
      if (!controller.isClosed) controller.add(data);
    }

    push();

    final sub = _realtime.subscribe(
        ['databases.$_dbId.collections.$_collection.documents']);
    sub.stream.listen((_) => push());
    controller.onCancel = () => sub.close();
    return controller.stream;
  }

  /// [ADMIN] Crea un nuovo appuntamento
  Future<Appointment> createAppointment({
    required DateTime appointmentDate,
    required String appointmentTime,
    required String title,
    String? description,
    int durationMinutes = 60,
    int maxParticipants = 10,
    required String createdBy,
  }) async {
    final data = {
      'appointment_date': appointmentDate.toUtc().toIso8601String(),
      'appointment_time': appointmentTime,
      'title': title,
      'description': description,
      'duration_minutes': durationMinutes,
      'max_participants': maxParticipants,
      'current_participants': 0,
      'created_by': createdBy,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final doc = await _databases.createDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: ID.unique(),
      data: data,
      permissions: _permsForAppointment(createdBy),
    );

    return Appointment.fromMap(Map<String, dynamic>.from(doc.data));
  }

  /// [ADMIN] Aggiorna un appuntamento
  Future<Appointment> updateAppointment(
    String appointmentId,
    Map<String, dynamic> updates,
  ) async {
    final doc = await _databases.updateDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: appointmentId,
      data: {
        ...updates,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return Appointment.fromMap(Map<String, dynamic>.from(doc.data));
  }

  /// [ADMIN] Elimina un appuntamento
  Future<void> deleteAppointment(String appointmentId) async {
    await _databases.deleteDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: appointmentId,
    );
  }

  /// Verifica se un appuntamento ha posti disponibili
  Future<bool> hasAvailableSpots(String appointmentId) async {
    final appointment = await getAppointment(appointmentId);
    return appointment?.hasAvailableSpots ?? false;
  }

  List<Appointment> _mapDocs(List<models.Document> docs) {
    return docs
        .map((doc) => Appointment.fromMap(
              Map<String, dynamic>.from(doc.data)..['id'] = doc.$id,
            ))
        .toList();
  }
}

