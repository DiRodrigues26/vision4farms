import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'local_database.dart';

/// Resultado de um fetch resiliente.
class CachedListResult {
  /// Lista combinada: dados do servidor (ou cache) + escritas otimistas
  /// pendentes (com `_pending: true`).
  final List<dynamic> items;

  /// `true` quando os dados vêm da cache local (servidor inacessível).
  final bool fromCache;

  /// Quantos registos otimistas estão na lista (ainda não sincronizados).
  final int pendingCount;

  /// Erro de rede capturado, se houver.
  final String? errorMessage;

  const CachedListResult({
    required this.items,
    required this.fromCache,
    required this.pendingCount,
    this.errorMessage,
  });
}

/// Resultado de fetch de um objeto único.
class CachedJsonResult {
  final Map<String, dynamic>? data;
  final bool fromCache;
  final String? errorMessage;

  const CachedJsonResult({
    required this.data,
    required this.fromCache,
    this.errorMessage,
  });
}

/// Helper para leituras tolerantes a falta de rede.
/// Tenta a API; se falhar, devolve a cache; junta sempre escritas otimistas
/// pendentes para que o UI seja instantaneamente coerente após criar offline.
class OfflineRead {
  /// Lê uma lista. `apiCall` deve devolver um Response cujo `data` é uma
  /// lista (ou um envelope paginado com chave `results`).
  ///
  /// Se `localEntity` for fornecido, escritas otimistas desse tipo (e
  /// opcionalmente filtradas por `parentId`) são prepended à lista.
  static Future<CachedListResult> list({
    required String cacheKey,
    required Future<Response> Function() apiCall,
    String? localEntity,
    int? parentId,
  }) async {
    List<dynamic> serverData;
    bool fromCache = false;
    String? errorMessage;

    try {
      final response = await apiCall();
      serverData = ApiService.extractResults(response.data);
      await LocalDatabase.saveList(cacheKey, serverData);
    } catch (e) {
      fromCache = true;
      serverData = await LocalDatabase.getList(cacheKey);
      if (e is DioException) {
        errorMessage = e.response?.statusCode != null
            ? 'Erro ${e.response!.statusCode}'
            : 'Sem ligação';
      } else {
        errorMessage = 'Erro a carregar';
      }
      debugPrint('[OfflineRead.list] $cacheKey FAILED → cache (${serverData.length} itens)');
    }

    // Anexar escritas otimistas pendentes
    List<Map<String, dynamic>> pending = const [];
    if (localEntity != null) {
      try {
        pending = await LocalDatabase.getLocalWrites(
          entityType: localEntity,
          parentId: parentId,
        );
      } catch (e) {
        debugPrint('[OfflineRead.list] getLocalWrites failed: $e');
      }
    }

    return CachedListResult(
      items: [...pending, ...serverData],
      fromCache: fromCache,
      pendingCount: pending.length,
      errorMessage: errorMessage,
    );
  }

  /// Lê um objeto único (Map). Útil para detalhes que não são listas.
  static Future<CachedJsonResult> json({
    required String cacheKey,
    required Future<Response> Function() apiCall,
  }) async {
    try {
      final response = await apiCall();
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;
      if (data != null) {
        await LocalDatabase.saveJson(cacheKey, data);
      }
      return CachedJsonResult(data: data, fromCache: false);
    } catch (e) {
      final cached = await LocalDatabase.getJson(cacheKey);
      String? msg;
      if (e is DioException) {
        msg = e.response?.statusCode != null
            ? 'Erro ${e.response!.statusCode}'
            : 'Sem ligação';
      } else {
        msg = 'Erro a carregar';
      }
      debugPrint('[OfflineRead.json] $cacheKey FAILED → cache=${cached != null}');
      return CachedJsonResult(
        data: cached,
        fromCache: true,
        errorMessage: msg,
      );
    }
  }
}
