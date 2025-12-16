import 'dart:async';

import 'package:appwrite/appwrite.dart';
import '../appwrite_service.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository({Databases? databases, Realtime? realtime})
      : _databases = databases ?? AppwriteService.instance.databases,
        _realtime = realtime ?? AppwriteService.instance.realtime;

  final Databases _databases;
  final Realtime _realtime;

  static const _dbId = 'dora';
  static const _collection = 'profiles';

  List<String> _perms(String userId) {
    final adminTeam = AppwriteService.instance.adminTeamId;
    return [
      'read("user:$userId")',
      'write("user:$userId")',
      'read("team:$adminTeam")',
      'write("team:$adminTeam")',
    ];
  }

  Future<Profile?> fetchProfile(String id) async {
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
      queries: [Query.equal('user_id', id)],
    );
    if (res.total == 0) return null;
    final data = res.documents.first.data;
    return Profile.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<Profile>> fetchProfiles() async {
    final res = await _databases.listDocuments(
      databaseId: _dbId,
      collectionId: _collection,
    );
    return res.documents
        .map((doc) => Profile.fromMap(Map<String, dynamic>.from(doc.data)))
        .toList();
  }

  Future<Profile> upsertProfile(Profile profile) async {
    // Usa user_id come documentId per coerenza con Supabase
    final docId = profile.id;
    final data = profile.toMap()..['user_id'] = profile.id;

    try {
      await _databases.createDocument(
        databaseId: _dbId,
        collectionId: _collection,
        documentId: docId,
        data: data,
        permissions: _perms(profile.id),
      );
    } catch (_) {
      await _databases.updateDocument(
        databaseId: _dbId,
        collectionId: _collection,
        documentId: docId,
        data: data,
        permissions: _perms(profile.id),
      );
    }
    return profile;
  }

  Future<void> deleteProfile(String id) async {
    await _databases.deleteDocument(
      databaseId: _dbId,
      collectionId: _collection,
      documentId: id,
    );
  }

  Stream<List<Profile>> watchProfiles() {
    final controller = StreamController<List<Profile>>();

    Future<void> push() async {
      final list = await fetchProfiles();
      if (!controller.isClosed) controller.add(list);
    }

    push();

    final subscription = _realtime.subscribe([
      'databases.$_dbId.collections.$_collection.documents'
    ]);

    subscription.stream.listen((_) => push());
    controller.onCancel = () => subscription.close();

    return controller.stream;
  }
}

