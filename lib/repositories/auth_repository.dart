import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../appwrite_service.dart';

class AppUser {
  const AppUser({required this.id, this.email, this.emailVerified = false});
  final String id;
  final String? email;
  final bool emailVerified;
}

class AppSession {
  const AppSession({required this.user});
  final AppUser user;
}

class AuthState {
  const AuthState({this.session, this.error});
  final AppSession? session;
  final Object? error;
}

class AuthRepository {
  AuthRepository({Account? account})
      : _account = account ?? AppwriteService.instance.account;

  final Account _account;

  final _authStateController = StreamController<AuthState>.broadcast();
  AppSession? _currentSession;

  Stream<AuthState> get authStateChanges => _authStateController.stream;

  AppSession? get currentSession => _currentSession;

  AppUser? get currentUser => _currentSession?.user;

  Future<void> refreshSession() async {
    try {
      final models.User user = await _account.get();
      _currentSession = AppSession(
        user: AppUser(
          id: user.$id,
          email: user.email,
          emailVerified: user.emailVerification,
        ),
      );
      _authStateController.add(AuthState(session: _currentSession));
    } catch (e) {
      _currentSession = null;
      _authStateController.add(const AuthState(session: null));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _account.createEmailSession(email: email, password: password);
    await refreshSession();
  }

  Future<void> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    await _account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: data?['name'],
    );
    await _account.createEmailSession(email: email, password: password);
    await refreshSession();
  }

  Future<void> signOut() async {
    await _account.deleteSessions();
    _currentSession = null;
    _authStateController.add(const AuthState(session: null));
  }

  /// Invia email di verifica all'utente corrente
  /// [redirectUrl] è l'URL a cui l'utente viene reindirizzato dopo la verifica
  Future<void> sendVerificationEmail(String redirectUrl) async {
    await _account.createVerification(url: redirectUrl);
  }

  /// Completa la verifica email (chiamato dopo che l'utente clicca sul link)
  Future<void> completeVerification({
    required String userId,
    required String secret,
  }) async {
    await _account.updateVerification(userId: userId, secret: secret);
    await refreshSession();
  }

  /// Rinvia email di verifica
  Future<void> resendVerificationEmail(String redirectUrl) async {
    await _account.createVerification(url: redirectUrl);
  }
}

