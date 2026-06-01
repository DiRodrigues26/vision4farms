import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor — adiciona token automaticamente aos pedidos.
    // Exceção: endpoints de autenticação (login/registo/refresh/reset) NÃO
    // devem levar token — se levarem um token antigo/inválido, o servidor
    // rejeita com "Given token not valid" antes de validar as credenciais.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        const noAuthPaths = [
          '/auth/login',
          '/auth/register',
          '/auth/refresh',
          '/auth/password-reset',
          '/status',
        ];
        final isNoAuth =
            noAuthPaths.any((p) => options.path.contains(p));
        if (!isNoAuth) {
          final token = await _storage.read(key: AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Token expirado — tenta refresh automático
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            // Repetir o pedido original com novo token
            final token = await _storage.read(key: AppConstants.accessTokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefresh() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final refreshDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
      ));
      final response = await refreshDio.post(
        '${AppConstants.baseUrl}${AppConstants.refresh}',
        data: {'refresh': refreshToken},
      );
      final newAccess = response.data['access'];
      await _storage.write(key: AppConstants.accessTokenKey, value: newAccess);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Métodos HTTP ───────────────────────────────────────
  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    return _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) async {
    return _dio.delete(path);
  }

  /// Extrai a lista de resultados de uma resposta paginada ou não paginada.
  static List<dynamic> extractResults(dynamic data) {
    if (data is List) return data;
    if (data is Map && data.containsKey('results')) return data['results'] as List;
    return [];
  }

  // ── Storage helpers ────────────────────────────────────
  Future<void> saveTokens({
    required String access,
    required String refresh,
    required int userId,
    required String username,
  }) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: access);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);
    await _storage.write(key: AppConstants.userIdKey, value: userId.toString());
    await _storage.write(key: AppConstants.usernameKey, value: username);
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null;
  }

  Future<String?> getUsername() async {
    return _storage.read(key: AppConstants.usernameKey);
  }
}
