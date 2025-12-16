import 'package:appwrite/appwrite.dart';

import 'environment.dart';

/// Singleton che incapsula client, account, database, funzioni e realtime.
class AppwriteService {
  AppwriteService._internal();
  static final AppwriteService instance = AppwriteService._internal();

  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Functions functions;
  late final Realtime realtime;

  /// ID del team admin (impostato da Environment)
  late final String adminTeamId;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    client = Client()
        .setEndpoint(Environment.appwritePublicEndpoint)
        .setProject(Environment.appwriteProjectId);

    account = Account(client);
    databases = Databases(client);
    functions = Functions(client);
    realtime = Realtime(client);
    adminTeamId = Environment.appwriteAdminTeamId;

    _initialized = true;
  }
}

