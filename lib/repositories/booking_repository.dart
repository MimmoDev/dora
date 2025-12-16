import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../appwrite_service.dart';
import '../models/booking.dart';
import 'appointment_repository.dart';
import 'subscription_repository.dart';

class BookingRepository {
  BookingRepository({Databases? databases, Realtime? realtime})
      : _databases = databases ?? AppwriteService.instance.databases,
        _realtime = realtime ?? AppwriteService.instance.realtime;

  final Databases _databases;
  final Realtime _realtime;

  static const _dbId = 'dora';
  static const _collection = 'bookings';

  List<String> _perms(String userId) {
    final adminTeam = AppwriteService.instance.adminTeamId;
    return [
      'read(user:$userId)',
      'write(user:$userId)',
      'read(team:$adminTeam)',
      'write(team:$adminTeam)',
    ];
  }

  /// Ottiene tutte le prenotazioni dell'utente
  Future<List<Booking>> getUserBookings(String userId, {String? status}) async {
    final queries = <String>[Query.equal('user_id', userId)];
    if (status != null) queries.add(Query.equal('status', status));
    queries.add(Query.orderDesc('created_at'));

    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: queries,
    );
    return _mapDocs(res.documents);
  }

  /// Ottiene le prenotazioni dell'utente con dettagli appuntamento
  Future<List<Map<String, dynamic>>> getUserBookingsWithAppointments(
    String userId,
  ) async {
    final bookings = await getUserBookings(userId);
    final appointmentRepo = AppointmentRepository(
      databases: _databases,
      realtime: _realtime,
    );

    final result = <Map<String, dynamic>>[];
    for (final booking in bookings) {
      final appointment =
          await appointmentRepo.getAppointment(booking.appointmentId);
      final map = booking.toMap();
      if (appointment != null) {
        map['appointment_date'] = appointment.appointmentDate.toIso8601String();
        map['appointment_time'] = appointment.appointmentTime;
        map['appointment_title'] = appointment.title;
        map['appointment_description'] = appointment.description;
      }
      result.add(map);
    }
    return result;
  }

  /// Conta le prenotazioni settimanali dell'utente (client-side)
  Future<int> countWeeklyBookings(String userId, DateTime weekStart) async {
    final appointments = await AppointmentRepository(
      databases: _databases,
      realtime: _realtime,
    ).getAppointmentsForWeek(weekStart);
    final appointmentIdsInWeek =
        appointments.map((a) => a.id).toSet(); // assuming id field in model

    final bookings = await getUserBookings(userId, status: 'confirmed');
    return bookings
        .where((b) => appointmentIdsInWeek.contains(b.appointmentId))
        .length;
  }

  /// Verifica se l'utente può prenotare un appuntamento
  Future<bool> canUserBook(String userId, DateTime appointmentDate) async {
    final hasSub = await SubscriptionRepository(
      databases: _databases,
      realtime: _realtime,
    ).hasActiveSubscription(userId);
    if (!hasSub) return false;

    final weekStart = DateTime(appointmentDate.year, appointmentDate.month,
        appointmentDate.day - appointmentDate.weekday + 1);
    final weekly = await countWeeklyBookings(userId, weekStart);
    return weekly < 3;
  }

  /// Crea una nuova prenotazione
  Future<Booking> createBooking({
    required String userId,
    required String appointmentId,
  }) async {
    final doc = await _databases.createDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: ID.unique(),
      data: {
        'user_id': userId,
        'appointment_id': appointmentId,
        'status': 'confirmed',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      permissions: _perms(userId),
    );
    return Booking.fromMap(Map<String, dynamic>.from(doc.data)..['id'] = doc.$id);
  }

  /// Cancella una prenotazione
  Future<void> cancelBooking(String bookingId) async {
    await _databases.updateDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: bookingId,
      data: {
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Verifica se l'utente ha già prenotato un appuntamento
  Future<bool> hasUserBookedAppointment(
    String userId,
    String appointmentId,
  ) async {
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('user_id', userId),
        Query.equal('appointment_id', appointmentId),
        Query.equal('status', 'confirmed'),
      ],
    );
    return res.total > 0;
  }

  /// Ottiene la prenotazione specifica di un utente per un appuntamento
  Future<Booking?> getUserBookingForAppointment(
    String userId,
    String appointmentId,
  ) async {
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('user_id', userId),
        Query.equal('appointment_id', appointmentId),
        Query.equal('status', 'confirmed'),
      ],
    );
    if (res.total == 0) return null;
    final doc = res.documents.first;
    return Booking.fromMap(
        Map<String, dynamic>.from(doc.data)..['id'] = doc.$id);
  }

  /// Stream delle prenotazioni dell'utente
  Stream<List<Booking>> watchUserBookings(String userId) {
    final controller = StreamController<List<Booking>>();

    Future<void> push() async {
      final list = await getUserBookings(userId, status: 'confirmed');
      if (!controller.isClosed) controller.add(list);
    }

    push();
    final sub = _realtime.subscribe(
        ['databases.$_dbId.collections.$_collection.documents']);
    sub.stream.listen((_) => push());
    controller.onCancel = () => sub.close();
    return controller.stream;
  }

  /// [ADMIN] Ottiene tutte le prenotazioni per un appuntamento
  Future<List<Map<String, dynamic>>> getAppointmentBookings(
    String appointmentId,
  ) async {
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('appointment_id', appointmentId),
        Query.equal('status', 'confirmed'),
        Query.orderAsc('created_at'),
      ],
    );
    return res.documents
        .map((d) => Map<String, dynamic>.from(d.data))
        .toList();
  }

  /// [ADMIN] Elimina una prenotazione
  Future<void> deleteBooking(String bookingId) async {
    await _databases.deleteDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: bookingId,
    );
  }

  List<Booking> _mapDocs(List<models.Document> docs) {
    return docs
        .map((doc) => Booking.fromMap(
              Map<String, dynamic>.from(doc.data)..['id'] = doc.$id,
            ))
        .toList();
  }
}

