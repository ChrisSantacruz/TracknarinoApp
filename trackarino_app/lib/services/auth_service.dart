import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../config/api_config.dart';
import '../api_service.dart';
import 'realtime_service.dart';

enum AuthBootstrapPhase {
  initializing,
  unauthenticated,
  authenticated,
  invalidRole,
}

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  AuthBootstrapPhase _phase = AuthBootstrapPhase.initializing;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  static final FlutterSecureStorage _staticStorage = FlutterSecureStorage();

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  AuthBootstrapPhase get phase => _phase;

  static Future<String?> getToken() async {
    final token = await _staticStorage.read(key: ApiConfig.tokenKey);
    if (token == null && kDebugMode) {
      print('WARNING: No token found in secure storage');
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
    if (role == 'camionero' || role == 'contratista') {
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

  Future<void> logout() async {
    await _clearSessionOnly();
    RealtimeService.instance.disconnect();
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

  Future<void> actualizarDeviceToken(String token) async {
    try {
      if (_currentUser != null) {
        final data = {'deviceToken': token};
        await ApiService.put('${ApiConfig.users}/${_currentUser!.id}', data);
      }
    } catch (_) {}
  }

  Future<User?> obtenerPerfilCamionero() async {
    try {
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
