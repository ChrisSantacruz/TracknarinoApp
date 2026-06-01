import 'package:flutter/foundation.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'dart:convert';

import '../models/user_model.dart';

import '../config/api_config.dart';

import '../api_service.dart';
import '../offline/sync_engine.dart';

import 'calificacion_service.dart';
import 'realtime_service.dart';

enum AuthBootstrapPhase {
  initializing,

  unauthenticated,

  authenticated,

  roleSelectionRequired,

  invalidRole,
}

class AuthService extends ChangeNotifier {
  User? _currentUser;

  bool _isAuthenticated = false;

  AuthBootstrapPhase _phase = AuthBootstrapPhase.initializing;

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  static final FlutterSecureStorage _staticStorage = FlutterSecureStorage();
  GoogleSignIn? _googleSignIn;

  User? get currentUser => _currentUser;

  bool get isAuthenticated => _isAuthenticated;

  AuthBootstrapPhase get phase => _phase;
  bool get isSimulationSession =>
      _currentUser?.sessionType == 'SIMULATION_DRIVER' ||
      _currentUser?.isSimulation == true;

  static Future<String?> getToken() async {
    final token = await _staticStorage.read(key: ApiConfig.tokenKey);

    if (token == null && kDebugMode) {
      debugPrint('WARNING: No token found in secure storage');
    }

    return token;
  }

  static Future<String?> getStoredUserId() async {
    final userString = await _staticStorage.read(key: 'user_data');

    if (userString == null) return null;

    try {
      final userData = jsonDecode(userString);

      return (userData['_id'] ?? userData['id'])?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    _phase = AuthBootstrapPhase.initializing;

    notifyListeners();

    try {
      final token = await _storage.read(key: ApiConfig.tokenKey);

      final userString = await _storage.read(key: 'user_data');

      if (token != null && userString != null) {
        try {
          final userData = jsonDecode(userString);

          _currentUser = User.fromJson(userData);

          _isAuthenticated = true;

          final valid = await verificarToken();

          if (!valid) {
            await _clearSessionOnly();

            _phase = AuthBootstrapPhase.unauthenticated;

            notifyListeners();

            return;
          }

          _phase = _resolvePhase();
        } catch (e) {
          await _clearSessionOnly();

          _phase = AuthBootstrapPhase.unauthenticated;
        }
      } else {
        _phase = AuthBootstrapPhase.unauthenticated;
      }
    } catch (e) {
      _phase = AuthBootstrapPhase.unauthenticated;
    }

    notifyListeners();
  }

  AuthBootstrapPhase _resolvePhase() {
    if (!_isAuthenticated || _currentUser == null) {
      return AuthBootstrapPhase.unauthenticated;
    }

    final role = _currentUser!.tipoUsuario;

    if (_currentUser!.rolConfigurado == false || role == 'usuario') {
      return AuthBootstrapPhase.roleSelectionRequired;
    }
    if (role == 'camionero' || role == 'contratista' || role == 'cliente') {
      return AuthBootstrapPhase.authenticated;
    }

    return AuthBootstrapPhase.invalidRole;
  }

  Future<User> login(String correo, String contrasena) async {
    try {
      final data = {'correo': correo, 'contraseña': contrasena};

      final response = await ApiService.postUnauth(ApiConfig.login, data);

      if (response['token'] == null || response['usuario'] == null) {
        throw const AuthFailure('Respuesta del servidor incorrecta');
      }

      await _storage.write(key: ApiConfig.tokenKey, value: response['token']);

      _currentUser = User.fromJson(response['usuario']);

      _isAuthenticated = true;

      await _storage.write(
        key: 'user_data',

        value: jsonEncode(response['usuario']),
      );

      _phase = _resolvePhase();

      if (_phase == AuthBootstrapPhase.invalidRole) {
        await logout();

        throw const AuthFailure('Tipo de usuario no soportado en esta app.');
      }

      notifyListeners();

      return _currentUser!;
    } catch (e) {
      if (e is AuthFailure) rethrow;

      throw AuthFailure(_friendlyAuthError(e));
    }
  }

  Future<User> signInWithGoogle() async {
    try {
      if (kIsWeb && ApiConfig.googleWebClientId.isEmpty) {
        throw const AuthFailure(
          'Google no está configurado para web. Reinicia con: '
          'flutter run -d chrome --web-port=8080 '
          '--dart-define-from-file=config/google.dev.json',
        );
      }

      final account = await _googleClient.signIn();
      if (account == null) {
        throw const AuthFailure('Inicio de sesión cancelado.');
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure('Google no entregó un token verificable.');
      }

      final response = await ApiService.postUnauth(ApiConfig.googleLogin, {
        'idToken': idToken,
      });
      await _storeAuthenticatedResponse(response);
      notifyListeners();
      return _currentUser!;
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure(_friendlyAuthError(e));
    }
  }

  Future<User> startSimulationSession() async {
    try {
      final response = await ApiService.postUnauth(ApiConfig.simulationLogin, {
        'sessionType': 'SIMULATION_DRIVER',
      });
      await _storeAuthenticatedResponse(response);
      notifyListeners();
      return _currentUser!;
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure(_friendlyAuthError(e));
    }
  }

  GoogleSignIn get _googleClient {
    final existing = _googleSignIn;
    if (existing != null) return existing;

    final serverClientId =
        ApiConfig.googleAndroidServerClientId.isNotEmpty
            ? ApiConfig.googleAndroidServerClientId
            : ApiConfig.googleWebClientId;
    final clientId =
        kIsWeb
            ? ApiConfig.googleWebClientId
            : defaultTargetPlatform == TargetPlatform.iOS
            ? ApiConfig.googleIosClientId
            : '';

    return _googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: clientId.isEmpty ? null : clientId,
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
  }

  Future<User> configureRole(String role) async {
    if (!['camionero', 'contratista', 'cliente'].contains(role)) {
      throw const AuthFailure('Selecciona un rol válido.');
    }

    try {
      final response = await ApiService.put(ApiConfig.configureRole, {
        'tipoUsuario': role,
      });
      await _storeAuthenticatedResponse(response);
      notifyListeners();
      return _currentUser!;
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure(_friendlyAuthError(e));
    }
  }

  Future<void> _storeAuthenticatedResponse(
    Map<String, dynamic> response,
  ) async {
    if (response['token'] == null || response['usuario'] == null) {
      throw const AuthFailure('Respuesta del servidor incorrecta');
    }

    await _storage.write(key: ApiConfig.tokenKey, value: response['token']);
    _currentUser = User.fromJson(response['usuario']);
    _isAuthenticated = true;
    await _storage.write(
      key: 'user_data',
      value: jsonEncode(response['usuario']),
    );
    _phase = _resolvePhase();
  }

  Future<User> register(Map<String, dynamic> userData) async {
    try {
      final response = await ApiService.postUnauth(
        ApiConfig.register,

        userData,
      );

      if (response['token'] == null || response['usuario'] == null) {
        throw const AuthFailure('Respuesta del servidor incorrecta');
      }

      await _storage.write(key: ApiConfig.tokenKey, value: response['token']);

      _currentUser = User.fromJson(response['usuario']);

      _isAuthenticated = true;

      await _storage.write(
        key: 'user_data',

        value: jsonEncode(response['usuario']),
      );

      _phase = _resolvePhase();

      if (_phase == AuthBootstrapPhase.invalidRole) {
        await logout();

        throw const AuthFailure('Tipo de usuario no soportado en esta app.');
      }

      notifyListeners();

      return _currentUser!;
    } catch (e) {
      if (e is AuthFailure) rethrow;

      throw AuthFailure(_friendlyAuthError(e));
    }
  }

  Future<void> bumpSimulationCompletedTrip() async {
    if (_currentUser == null || !isSimulationSession) return;
    final nextCount = (_currentUser!.viajesCompletados ?? 0) + 1;
    _currentUser = _currentUser!.copyWith(viajesCompletados: nextCount);
    await _storage.write(
      key: 'user_data',
      value: jsonEncode(_currentUser!.toJson()),
    );
    notifyListeners();
  }

  Future<void> updateSimulationRating(double rating) async {
    if (_currentUser == null || !isSimulationSession) return;
    _currentUser = _currentUser!.copyWith(calificacion: rating);
    await _storage.write(
      key: 'user_data',
      value: jsonEncode(_currentUser!.toJson()),
    );
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _googleSignIn?.signOut();
    } catch (_) {}

    await _clearSessionOnly();

    RealtimeService.instance.disconnect();
    SyncEngine.instance.setSimulationOfflineOverride(false);

    _phase = AuthBootstrapPhase.unauthenticated;

    notifyListeners();
  }

  Future<void> _clearSessionOnly() async {
    try {
      await _storage.delete(key: ApiConfig.tokenKey);

      await _storage.delete(key: 'user_data');
    } catch (_) {}

    _currentUser = null;

    _isAuthenticated = false;
  }

  Future<bool> verificarToken() async {
    try {
      final token = await getToken();

      if (token == null) return false;

      final response = await ApiService.get('${ApiConfig.auth}/perfil');

      if (response['usuario'] != null) {
        _currentUser = User.fromJson(response['usuario']);

        _isAuthenticated = true;

        await _storage.write(
          key: 'user_data',

          value: jsonEncode(response['usuario']),
        );

        notifyListeners();

        return true;
      }

      return false;
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        return false;
      }

      return _isAuthenticated;
    }
  }

  Future<User> actualizarMetodoPago(String metodoPago) async {
    try {
      final data = {'metodoPago': metodoPago};

      final response = await ApiService.put(
        '${ApiConfig.baseUrl}/auth/actualizar-pago',

        data,
      );

      if (response['usuario'] == null) {
        throw Exception('Respuesta del servidor incorrecta');
      }

      _currentUser = User.fromJson(response['usuario']);

      await _storage.write(
        key: 'user_data',

        value: jsonEncode(response['usuario']),
      );

      notifyListeners();

      return _currentUser!;
    } catch (e) {
      throw Exception('Error al actualizar método de pago: $e');
    }
  }

  Future<User> actualizarPerfil(Map<String, dynamic> data) async {
    try {
      final response = await ApiService.put('${ApiConfig.auth}/perfil', data);

      if (response['usuario'] == null) {
        throw Exception('Respuesta del servidor incorrecta');
      }

      _currentUser = User.fromJson(response['usuario']);
      await _storage.write(
        key: 'user_data',
        value: jsonEncode(response['usuario']),
      );

      notifyListeners();
      return _currentUser!;
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }

  Future<void> actualizarDeviceToken(String token) async {
    try {
      if (_currentUser != null) {
        final data = {'deviceToken': token};

        await ApiService.put('${ApiConfig.users}/${_currentUser!.id}', data);
      }
    } catch (_) {}
  }

  Future<void> refreshSimulationReputation() async {
    if (_currentUser?.id == null || !isSimulationSession) return;
    try {
      final ratings = await CalificacionService.listarPorUsuario(_currentUser!.id!);
      if (ratings.isEmpty) return;
      final total = ratings.fold<double>(
        0,
        (sum, item) => sum + ((item['calificacion'] as num?)?.toDouble() ?? 0),
      );
      final promedio = total / ratings.length;
      _currentUser = _currentUser!.copyWith(calificacion: promedio);
      await _storage.write(
        key: 'user_data',
        value: jsonEncode(_currentUser!.toJson()),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<User?> obtenerPerfilCamionero() async {
    try {
      if (isSimulationSession && _currentUser != null) {
        await refreshSimulationReputation();
        return _currentUser;
      }

      final response = await ApiService.get('${ApiConfig.auth}/perfil');

      final usuario = User.fromJson(response['usuario']);

      _currentUser = usuario;

      await _storage.write(
        key: 'user_data',

        value: jsonEncode(response['usuario']),
      );

      notifyListeners();

      return usuario;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarEstadoDisponible(bool disponible) async {
    await _storage.write(
      key: 'estado_disponible',

      value: disponible.toString(),
    );
  }

  Future<bool> obtenerEstadoDisponible() async {
    final estadoString = await _storage.read(key: 'estado_disponible');

    if (estadoString == null) return false;

    return estadoString == 'true';
  }

  static String _friendlyAuthError(Object error) {
    if (error is ApiException) return error.message;

    final text = error.toString();

    if (text.contains('Exception:')) {
      return text.replaceFirst('Exception:', '').trim();
    }

    return 'No se pudo completar la operación. Intenta de nuevo.';
  }
}

class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}
