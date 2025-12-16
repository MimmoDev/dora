import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'appwrite_service.dart';
import 'environment.dart';
import 'models/profile.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/splash_page.dart';
import 'pages/user_dashboard_page.dart';
import 'pages/user_profile_page.dart';
import 'repositories/auth_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/subscription_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carica .env (opzionale)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Impossibile caricare .env: $e');
  }

  // Inizializza Appwrite
  await AppwriteService.instance.init();
  debugPrint(
      'Appwrite client pronto: ${Environment.appwritePublicEndpoint} / ${Environment.appwriteProjectId}');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      debugPrint('Inizio inizializzazione app...');
      // Aspetta almeno 2 secondi per la splash E che tutto sia pronto
      await Future.wait([
        Future.delayed(const Duration(seconds: 2)), // Splash minima
        _preloadData(), // Pre-carica dati se necessario
      ]);
      debugPrint('Inizializzazione completata');

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Errore durante inizializzazione: $e');
      // Anche in caso di errore, mostra l'app dopo un po'
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _preloadData() async {
    try {
      // Verifica sessione Appwrite (best-effort)
      await AuthRepository().refreshSession();
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('Errore preload: $e');
      // Continua comunque
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dora App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF849a82), // Verde salvia
          primary: const Color(0xFF849a82),
          secondary: const Color(0xFF9aad98),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF849a82),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF849a82),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF849a82), width: 2),
          ),
        ),
      ),
      home: _isInitialized ? const AuthGate() : const SplashPage(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  @override
  void initState() {
    super.initState();
    // Ripristina eventuale sessione esistente (Appwrite)
    _authRepository.refreshSession();
  }

  /// Verifica che il profilo esista, altrimenti lo crea
  Future<Profile?> _ensureProfileExists(AppUser user) async {
    try {
      // Prova a caricare il profilo esistente
      final existingProfile = await _profileRepository.fetchProfile(user.id);
      
      if (existingProfile != null) {
        debugPrint('Profilo esistente trovato per user: ${user.id}');
        return existingProfile;
      }

      // Se non esiste, crealo
      debugPrint('Profilo non trovato, creazione per user: ${user.id}');
      final newProfile = Profile(
        id: user.id,
        role: 'user',
        createdAt: DateTime.now().toUtc(),
      );

      await _profileRepository.upsertProfile(newProfile);
      debugPrint('Profilo creato con successo al primo login!');
      return newProfile;
    } catch (e) {
      debugPrint('Errore gestione profilo: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authRepository.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FullScreenMessage(
            title: 'Errore di autenticazione',
            message: snapshot.error.toString(),
          );
        }

        final session =
            snapshot.data?.session ?? _authRepository.currentSession;

        if (session == null) {
          return AuthPage(
            authRepository: _authRepository,
            profileRepository: _profileRepository,
          );
        }

        // Controlla se l'email è verificata
        // TODO: Abilitare quando SMTP è configurato in Appwrite
        // if (!session.user.emailVerified) {
        //   return EmailVerificationPage(
        //     authRepository: _authRepository,
        //     user: session.user,
        //   );
        // }

        // Verifica e crea il profilo al primo login
        return FutureBuilder<Profile?>(
          future: _ensureProfileExists(session.user),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (profileSnapshot.hasError) {
              return _FullScreenMessage(
                title: 'Errore profilo',
                message: 'Impossibile caricare il profilo: ${profileSnapshot.error}',
              );
            }

            final profile = profileSnapshot.data;

            // Se il profilo non è completo, mostra schermata di completamento
            if (profile != null && !profile.profileCompleted) {
              return CompleteProfilePage(
                authRepository: _authRepository,
                profileRepository: _profileRepository,
                profile: profile,
              );
            }

            // Se è admin, mostra dashboard admin
            if (profile != null && profile.role == 'admin') {
              return AdminDashboardPage(
                authRepository: _authRepository,
              );
            }

            // Altrimenti mostra homepage utente
            return HomePage(
              authRepository: _authRepository,
              profileRepository: _profileRepository,
              user: session.user,
            );
          },
        );
      },
    );
  }
}

/// Pagina mostrata quando l'email non è ancora verificata
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.authRepository,
    required this.user,
  });

  final AuthRepository authRepository;
  final AppUser user;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isResending = false;
  bool _isChecking = false;

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResending = true);
    try {
      await widget.authRepository.sendVerificationEmail(
        Environment.verificationRedirectUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email di verifica inviata! Controlla la tua casella.'),
        ),
      );
    } on AppwriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Errore nell\'invio dell\'email')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      await widget.authRepository.refreshSession();
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _signOut() async {
    await widget.authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Esci',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: Color(0xFF849a82),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verifica la tua email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Abbiamo inviato un\'email di verifica a:\n${widget.user.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Clicca sul link nell\'email per verificare il tuo account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkVerification,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Ho verificato, ricontrolla'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isResending ? null : _resendVerificationEmail,
                  child: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Non hai ricevuto l\'email? Invia di nuovo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.authRepository,
    required this.profileRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await widget.authRepository.signIn(
          email: email,
          password: password,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accesso eseguito con successo')),
        );
      } else {
        await widget.authRepository.signUp(
          email: email,
          password: password,
          data: {
            'first_name': firstName,
            'last_name': lastName,
            'phone': phone,
          },
        );

        // Crea il profilo subito dopo la registrazione
        final user = widget.authRepository.currentUser;
        if (user != null) {
          final newProfile = Profile(
            id: user.id,
            firstName: firstName.isNotEmpty ? firstName : null,
            lastName: lastName.isNotEmpty ? lastName : null,
            phone: phone.isNotEmpty ? phone : null,
            role: 'user',
            createdAt: DateTime.now().toUtc(),
          );
          await widget.profileRepository.upsertProfile(newProfile);
          debugPrint('Profilo creato subito dopo registrazione per user: ${user.id}');

          // Invia email di verifica
          // TODO: Abilitare quando SMTP è configurato in Appwrite
          // try {
          //   await widget.authRepository.sendVerificationEmail(
          //     Environment.verificationRedirectUrl,
          //   );
          //   debugPrint('Email di verifica inviata a: ${user.email}');
          // } catch (e) {
          //   debugPrint('Errore invio email verifica: $e');
          // }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione completata!'),
          ),
        );
      }
    } on AppwriteException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Errore di autenticazione')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Si è verificato un errore: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Accedi' : 'Registrati'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLogin
                        ? 'Inserisci le tue credenziali per accedere.'
                        : 'Crea un nuovo account per continuare.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci un\'email';
                      }
                      if (!value.contains('@')) {
                        return 'Inserisci un\'email valida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci una password';
                      }
                      if (value.length < 6) {
                        return 'La password deve avere almeno 6 caratteri';
                      }
                      return null;
                    },
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Cognome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isLogin ? 'Accedi' : 'Registrati'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                            });
                          },
                    child: Text(
                      _isLogin
                          ? 'Non hai un account? Registrati'
                          : 'Hai già un account? Accedi',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.user,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final AppUser user;

  Future<void> _signOut(BuildContext context) async {
    try {
      await authRepository.signOut();
    } on AppwriteException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(error.message ?? 'Errore durante il logout')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il logout: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserData(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final profile = data['profile'] as Profile?;
        final hasSubscription = data['hasSubscription'] as bool? ?? false;
        final userName = profile?.firstName ?? user.email?.split('@').first ?? 'Utente';

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UserProfilePage(),
                  ),
                );
              },
              icon: const Icon(Icons.person),
              tooltip: 'Profilo',
            ),
            title: Row(
              children: [
                Text('Benvenuto, $userName'),
                if (hasSubscription) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                tooltip: 'Esci',
              ),
            ],
          ),
          body: const UserDashboardPage(),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadUserData() async {
    try {
      final profile = await profileRepository.fetchProfile(user.id);
      final subscription = await SubscriptionRepository()
          .hasActiveSubscription(user.id);
      
      return {
        'profile': profile,
        'hasSubscription': subscription,
      };
    } catch (e) {
      return {};
    }
  }
}

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.profile,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final Profile profile;

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.profile.firstName);
    _lastNameController = TextEditingController(text: widget.profile.lastName);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedProfile = widget.profile.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        profileCompleted: true,
      );

      await widget.profileRepository.upsertProfile(updatedProfile);

      if (!mounted) return;
      
      // Mostra messaggio di successo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo completato con successo!')),
      );

      // Forza il reload dell'app tornando alla root e ricostruendo l'AuthGate
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyApp()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa il tuo profilo'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Benvenuto! Completa il tuo profilo per continuare.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il tuo nome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Cognome',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il tuo cognome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefono (opzionale)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _completeProfile,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Completa profilo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenMessage extends StatelessWidget {
  const _FullScreenMessage({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
