import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart' show kDebugMode;

import '../appwrite_service.dart';
import '../models/subscription.dart';

class SubscriptionRepository {
  SubscriptionRepository({Databases? databases, Realtime? realtime})
      : _databases = databases ?? AppwriteService.instance.databases,
        _realtime = realtime ?? AppwriteService.instance.realtime;

  final Databases _databases;
  final Realtime _realtime;

  static const _dbId = 'dora';
  static const _collection = 'subscriptions';

  List<String> _perms(String userId) {
    final adminTeam = AppwriteService.instance.adminTeamId;
    return [
      'read(user:$userId)',
      'write(user:$userId)',
      'read(team:$adminTeam)',
      'write(team:$adminTeam)',
    ];
  }

  /// Ottiene l'abbonamento attivo dell'utente
  Future<Subscription?> getActiveSubscription(String userId) async {
    try {
      final res = await _databases.listDocuments(
        databaseId: _dbId,
        collectionId: _collection,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('status', 'active'),
          Query.orderDesc('created_at'),
        ],
      );

      if (res.total == 0) return null;

      final nowUtc = DateTime.now().toUtc();
      final subs = res.documents
          .map((doc) => Subscription.fromMap(
                Map<String, dynamic>.from(doc.data)..['id'] = doc.$id,
              ))
          .toList();

      bool hasExpired = false;
      for (final sub in subs) {
        if (sub.status == 'active' &&
            sub.endDate != null &&
            sub.endDate!.toUtc().isBefore(nowUtc)) {
          hasExpired = true;
          try {
            await _databases.updateDocument(
              databaseId: _dbId,
              collectionId: _collection,
              documentId: sub.id,
              data: {
                'status': 'expired',
                'updated_at': nowUtc.toIso8601String(),
              },
            );
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Errore aggiornamento status abbonamento: $e');
            }
          }
        }
      }

      if (hasExpired) {
        return getActiveSubscription(userId);
      }

      final active = subs.where((s) => s.isActive).toList();
      if (active.isNotEmpty) return active.first;
      return subs.isNotEmpty ? subs.first : null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ getActiveSubscription errore: $e');
      }
      rethrow;
    }
  }

  /// Ottiene tutti gli abbonamenti di un utente
  Future<List<Subscription>> getUserSubscriptions(String userId) async {
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('user_id', userId),
        Query.orderDesc('created_at'),
      ],
    );
    return _mapDocs(res.documents);
  }

  /// Verifica se l'utente ha un abbonamento attivo
  Future<bool> hasActiveSubscription(String userId) async {
    final sub = await getActiveSubscription(userId);
    return sub != null && sub.isActive;
  }

  /// Stream dell'abbonamento attivo dell'utente
  Stream<Subscription?> watchActiveSubscription(String userId) {
    final controller = StreamController<Subscription?>();

    Future<void> push() async {
      final sub = await getActiveSubscription(userId);
      if (!controller.isClosed) controller.add(sub);
    }

    push();
    final subRealtime = _realtime.subscribe(
        ['databases.$_dbId.collections.$_collection.documents']);
    subRealtime.stream.listen((_) => push());
    controller.onCancel = () => subRealtime.close();
    return controller.stream;
  }

  /// [ADMIN] Crea o attiva un abbonamento per un utente
  Future<Subscription> activateSubscription({
    required String userId,
    required String subscriptionType,
    required DateTime startDate,
    required DateTime endDate,
    required String activatedBy,
  }) async {
    final now = DateTime.now().toUtc();
    // disattiva attivi
    final existing = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('user_id', userId),
        Query.equal('status', 'active'),
      ],
    );
    for (final doc in existing.documents) {
      await _databases.updateDocument(
        databaseId: _dbId,
        collectionId: _collection,
        documentId: doc.$id,
        data: {
          'status': 'cancelled',
          'updated_at': now.toIso8601String(),
        },
      );
    }

    final doc = await _databases.createDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: ID.unique(),
      data: {
        'user_id': userId,
        'subscription_type': subscriptionType,
        'status': 'active',
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
        'activated_by': activatedBy,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      permissions: _perms(userId),
    );
    return Subscription.fromMap(Map<String, dynamic>.from(doc.data)..['id'] = doc.$id);
  }

  /// [ADMIN] Disattiva un abbonamento
  Future<void> deactivateSubscription(String subscriptionId) async {
    await _databases.updateDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: subscriptionId,
      data: {
        'status': 'cancelled',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// [ADMIN] Ottiene tutti gli abbonamenti (per gestione admin)
  Future<List<Subscription>> getAllSubscriptions({String? status}) async {
    final queries = <String>[Query.orderDesc('created_at')];
    if (status != null) queries.add(Query.equal('status', status));

    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: queries,
    );
    return _mapDocs(res.documents);
  }

  /// [ADMIN] Aggiorna tutti gli abbonamenti scaduti da 'active' a 'expired'
  Future<int> expireOldSubscriptions() async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [
        Query.equal('status', 'active'),
        Query.lessThan('end_date', nowUtc),
      ],
    );
    int updated = 0;
    for (final doc in res.documents) {
      try {
        await _databases.updateDocument(
          databaseId: _dbId,
          collectionId: _collection,
          documentId: doc.$id,
          data: {'status': 'expired', 'updated_at': nowUtc},
        );
        updated++;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Errore aggiornamento abbonamento ${doc.$id}: $e');
        }
      }
    }
    return updated;
  }

  List<Subscription> _mapDocs(List<models.Document> docs) {
    return docs
        .map((doc) => Subscription.fromMap(
              Map<String, dynamic>.from(doc.data)..['id'] = doc.$id,
            ))
        .toList();
  }
}

