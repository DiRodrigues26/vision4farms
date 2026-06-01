import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../constants/app_constants.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService _api;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;
  bool isNewRegistration = false;

  AuthProvider(this._api);

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    try {
      final hasToken = await _api.hasToken();
      if (!hasToken) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      final response = await _api.get(AppConstants.me);
      _user = UserModel.fromJson(response.data);
      _status = AuthStatus.authenticated;
    } catch (_) {
      // Qualquer falha (rede, token inválido, storage) → não-autenticado.
      // Garante que o status nunca fica preso em 'unknown'.
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Força o estado para não-autenticado. Usado como rede de segurança
  /// pelo splash caso o checkAuth não tenha resolvido a tempo.
  void forceUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _setError(null);
    isNewRegistration = false;
    try {
      // Timeout duro global — garante que o botão nunca fica a girar para
      // sempre, mesmo que um pedido HTTP fique pendurado (ex: cold start
      // do servidor que não responde nem fecha a ligação).
      return await _loginFlow(username, password)
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      _setError('O servidor demorou demasiado a responder. '
          'Pode estar a arrancar — tenta novamente em alguns segundos.');
      return false;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _loginFlow(String username, String password) async {
    final response = await _api.post(AppConstants.login, data: {
      'username': username,
      'password': password,
    });
    await _api.saveTokens(
      access: response.data['access'],
      refresh: response.data['refresh'],
      userId: response.data['user_id'],
      username: response.data['username'],
    );
    final meResponse = await _api.get(AppConstants.me);
    _user = UserModel.fromJson(meResponse.data);
    _status = AuthStatus.authenticated;
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    required String inviteCode,
    String? fullName,
    String? mobile,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _api.post(AppConstants.register, data: {
        'username': username,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'invite_code': inviteCode,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      });
      await _api.saveTokens(
        access: response.data['access'],
        refresh: response.data['refresh'],
        userId: response.data['user_id'],
        username: response.data['username'],
      );
      final meResponse = await _api.get(AppConstants.me);
      _user = UserModel.fromJson(meResponse.data);
      isNewRegistration = false; // Já entra direto na farm via convite
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_parseError(e));
      _setLoading(false);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try { await _api.post(AppConstants.logout); } catch (_) {}
    try { await _api.clearTokens(); } catch (_) {}
    try { await LocalDatabase.clearAll(); } catch (_) {}
    _user = null;
    isNewRegistration = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    try {
      await _api.post(AppConstants.passwordReset, data: {'email': email});
      _isLoading = false;
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmPasswordReset({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.post(AppConstants.passwordResetConfirm, data: {
        'token': token,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      });
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Faz upload da foto de perfil
  Future<bool> uploadProfilePicture(String filePath) async {
    _setLoading(true);
    _setError(null);
    try {
      final formData = FormData.fromMap({
        'picture': await MultipartFile.fromFile(filePath),
      });
      await _api.post(AppConstants.profilePicture, data: formData);
      final meResponse = await _api.get(AppConstants.me);
      _user = UserModel.fromJson(meResponse.data);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza os dados do perfil (nome, email, telefone, NIF, NIFAP)
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.patch(AppConstants.profileUpdate, data: data);
      // Re-fetch user data so the UI updates
      final meResponse = await _api.get(AppConstants.me);
      _user = UserModel.fromJson(meResponse.data);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Altera a password (autenticado)
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.post(AppConstants.passwordChange, data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      });
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      if (data != null && data is Map) {
        if (data.containsKey('detail')) return data['detail'].toString();
        final firstKey = data.keys.first;
        final firstValue = data[firstKey];
        if (firstValue is List && firstValue.isNotEmpty) {
          return '$firstKey: ${firstValue.first}';
        }
        return data.values.first.toString();
      }

      if (statusCode == 401) return 'Credenciais inválidas.';
      if (statusCode == 400) return 'Dados inválidos. Verifica os campos.';
      if (statusCode == 403) return 'Conta inativa.';
      if (statusCode != null && statusCode >= 500) {
        return 'Erro no servidor ($statusCode). Tenta novamente.';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'O servidor demorou demasiado a responder. Tenta novamente.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Sem ligação ao servidor. Verifica a tua internet.';
      }
    }
    // TypeError, FormatException, etc. — provavelmente o servidor retornou HTML em vez de JSON
    debugPrint('AuthProvider._parseError: ${e.runtimeType}: $e');
    return 'Erro ao ligar ao servidor. Tenta novamente.';
  }
}