import 'dart:async';



import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/foundation.dart';

import 'lifecycle/app_lifecycle_coordinator.dart';

import 'observability/error_reporter.dart';


import 'api_service.dart';

import 'services/auth_service.dart';

import 'services/location_service.dart';

import 'services/notification_service.dart';

import 'offline/sync_engine.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selection_screen.dart';

import 'screens/camionero/camionero_home_screen.dart';

import 'screens/contratista/contratista_home_screen.dart';
import 'screens/cliente/cliente_home_screen.dart';

import 'screens/common/loading_widget.dart';

import 'state/alert_store.dart';

import 'state/session_bootstrap.dart';

import 'state/trip_store.dart';

import 'theme/app_theme.dart';


import 'theme/app_spacing.dart';

import 'widgets/operational/operational_error_state.dart';

import 'widgets/realtime_bindings.dart';



int hashValues(dynamic a, dynamic b) {

  return Object.hash(a, b);

}



extension TextThemeCompat on TextTheme {

  TextStyle get headline5 => titleLarge ?? const TextStyle(fontSize: 20);

}



void main() {

  runZonedGuarded(

    () {

      WidgetsFlutterBinding.ensureInitialized();

      ErrorReporter.installFlutterHandlers();

      runApp(const AppBootstrap());

    },

    (error, stackTrace) {

      unawaited(

        ErrorReporter.capture(

          error,

          stackTrace,

          type: OperationalErrorType.asyncZone,

        ),

      );

    },

  );

}



class AppBootstrap extends StatefulWidget {

  const AppBootstrap({super.key});



  @override

  State<AppBootstrap> createState() => _AppBootstrapState();

}



class _AppBootstrapState extends State<AppBootstrap> {

  bool _ready = false;



  @override

  void initState() {

    super.initState();

    _bootstrapApp();

  }



  Future<void> _bootstrapApp() async {

    try {

      if (kIsWeb) {

        await _initializeFirebaseWeb();

      } else {

        await Firebase.initializeApp();

      }

    } catch (error, stackTrace) {

      await ErrorReporter.capture(

        error,

        stackTrace,

        type: OperationalErrorType.appStartup,

        tags: {'service': 'firebase'},

      );

    }



    try {

      await SyncEngine.instance.initialize();

    } catch (error, stackTrace) {

      await ErrorReporter.capture(

        error,

        stackTrace,

        type: OperationalErrorType.appStartup,

        tags: {'service': 'sync_engine'},

      );

    }



    AppLifecycleCoordinator.instance.initialize();

    if (mounted) {

      setState(() => _ready = true);

    }

  }



  @override

  Widget build(BuildContext context) {

    if (!_ready) {

      return const MaterialApp(

        home: Scaffold(

          body: Center(

            child: LoadingWidget(message: 'Iniciando TrackNariño...'),

          ),

        ),

      );

    }

    return const MyApp();

  }

}



Future<void> _initializeFirebaseWeb() async {

  const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');

  const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');

  const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');

  const storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');

  const messagingSenderId = String.fromEnvironment(

    'FIREBASE_WEB_MESSAGING_SENDER_ID',

  );

  const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');



  final missingConfig =

      apiKey.isEmpty ||

      authDomain.isEmpty ||

      projectId.isEmpty ||

      storageBucket.isEmpty ||

      messagingSenderId.isEmpty ||

      appId.isEmpty;



  if (missingConfig) {

    throw StateError('Firebase web configuration is missing');

  }



  await Firebase.initializeApp(

    options: const FirebaseOptions(

      apiKey: apiKey,

      authDomain: authDomain,

      projectId: projectId,

      storageBucket: storageBucket,

      messagingSenderId: messagingSenderId,

      appId: appId,

    ),

  );

}



class MyApp extends StatelessWidget {

  const MyApp({super.key});



  @override

  Widget build(BuildContext context) {

    return MultiProvider(

      providers: [

        ChangeNotifierProvider(create: (_) => AuthService()),

        ChangeNotifierProvider(create: (_) => LocationService()),

        ChangeNotifierProvider(create: (_) => AlertStore()),

        ChangeNotifierProvider(create: (_) => TripStore()),

        Provider(create: (_) => NotificationService()),

      ],

      child: MaterialApp(

        title: 'Tracknariño',

        theme: AppTheme.light,

        darkTheme: AppTheme.dark,

        themeMode: ThemeMode.system,

        home: const AuthWrapper(),

        debugShowCheckedModeBanner: false,

      ),

    );

  }

}



class AuthWrapper extends StatefulWidget {

  const AuthWrapper({super.key});



  @override

  State<AuthWrapper> createState() => _AuthWrapperState();

}



class _AuthWrapperState extends State<AuthWrapper> {

  bool _servicesReady = false;

  bool _sessionApplied = false;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());

  }



  Future<void> _boot() async {

    final auth = context.read<AuthService>();

    ApiService.onUnauthorized = () async {

      if (auth.isAuthenticated) {

        await auth.logout();

        if (mounted) {

          final loc = context.read<LocationService>();

          await SessionBootstrap.teardownSession(location: loc);

        }

      }

    };



    await auth.init().timeout(const Duration(seconds: 10));

    if (auth.phase == AuthBootstrapPhase.authenticated) {

      await _applySession();

    }

    if (mounted) {

      setState(() => _servicesReady = true);

    }

  }



  Future<void> _applySession() async {

    if (_sessionApplied) return;

    _sessionApplied = true;

    await SessionBootstrap.applyAuthenticatedSession(

      auth: context.read<AuthService>(),

      notification: context.read<NotificationService>(),

      location: context.read<LocationService>(),

    );

    if (!mounted) return;

    await context.read<TripStore>().refreshActiveTrip();

  }



  @override

  Widget build(BuildContext context) {

    final auth = context.watch<AuthService>();



    if (!_servicesReady || auth.phase == AuthBootstrapPhase.initializing) {

      return const Scaffold(

        body: Center(

          child: LoadingWidget(message: 'Iniciando aplicación...'),

        ),

      );

    }



    if (auth.phase == AuthBootstrapPhase.unauthenticated) {

      _sessionApplied = false;

      return const LoginScreen();

    }



    if (auth.phase == AuthBootstrapPhase.invalidRole) {

      return Scaffold(

        body: Center(

          child: Padding(

            padding: const EdgeInsets.all(AppSpacing.lg),

            child: OperationalErrorState(

              message:

                  'Tu cuenta no tiene un rol operativo válido (camionero o contratista).',

              onRetry: () async {

                await auth.logout();

              },

              retryLabel: 'Cerrar sesión',

            ),

          ),

        ),

      );

    }

    if (auth.phase == AuthBootstrapPhase.roleSelectionRequired) {
      return const RoleSelectionScreen();
    }



    final user = auth.currentUser!;

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!_sessionApplied && auth.isAuthenticated) {

        _applySession();

      }

    });



    return RealtimeBindings(

      child: switch (user.tipoUsuario) {

        'camionero' => CamioneroHomeScreen(usuario: user),

        'contratista' => ContratistaHomeScreen(usuario: user),

        'cliente' => ClienteHomeScreen(usuario: user),

        _ => const LoginScreen(),

      },

    );

  }

}


