import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'local_database.dart';

/// Resultado de uma mutação offline-aware.
class MutationResult {
  final bool success;
  final bool queued;
  final Map<String, dynamic>? data; // resposta do servidor (se enviada agora)
  final String? errorMessage;

  const MutationResult({
    required this.success,
    required this.queued,
    this.data,
    this.errorMessage,
  });

  bool get sentNow => success && !queued;
}

/// Camada uniforme para escrever dados quando online ou offline.
///
/// Padrão de uso:
/// ```
/// final result = await OfflineMutation.run(
///   apiCall: () => api.post('/observations/', data: payload),
///   operationType: 'create_observation',
///   queueData: payload,
///   applyOptimistic: () => LocalDatabase.appendLocalObservation(payload),
///   cacheServerResponse: (response) => LocalDatabase.replaceLocalWithServer(...),
/// );
/// ```
class OfflineMutation {
  /// Tenta a chamada à API; em caso de falha de rede, aplica otimisticamente
  /// no cache local e enfileira a operação para replay quando a ligação voltar.
  ///
  /// Erros de servidor (4xx com resposta — validação) são propagados para o
  /// caller decidir o que fazer (mostrar erro ao utilizador).
  static Future<MutationResult> run({
    required Future<Response> Function() apiCall,
    required String operationType,
    required Map<String, dynamic> queueData,
    Future<void> Function()? applyOptimistic,
    Future<void> Function(dynamic responseData)? cacheServerResponse,
  }) async {
    try {
      final response = await apiCall();
      // Sucesso na rede — atualizar cache com resposta autoritária do servidor.
      try {
        await cacheServerResponse?.call(response.data);
      } catch (e) {
        debugPrint('OfflineMutation: cacheServerResponse failed: $e');
      }
      return MutationResult(
        success: true,
        queued: false,
        data: response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : null,
      );
    } on DioException catch (e) {
      if (_shouldQueue(e)) {
        // Sem rede / timeout / servidor inacessível — aplica local + queue.
        try {
          await applyOptimistic?.call();
        } catch (err) {
          debugPrint('OfflineMutation: applyOptimistic failed: $err');
        }
        await LocalDatabase.enqueueOperation(operationType, queueData);
        return const MutationResult(success: true, queued: true);
      }
      // Erros de validação ou autorização — propagar para o caller.
      return MutationResult(
        success: false,
        queued: false,
        errorMessage: _extractErrorMessage(e),
      );
    } catch (e) {
      // Erros desconhecidos — tratamos como network e enfileiramos para
      // garantir que nada se perde.
      try {
        await applyOptimistic?.call();
      } catch (err) {
        debugPrint('OfflineMutation: applyOptimistic failed: $err');
      }
      await LocalDatabase.enqueueOperation(operationType, queueData);
      return const MutationResult(success: true, queued: true);
    }
  }

  /// Decide se um erro Dio deve resultar em queue (sim para erros de rede)
  /// ou em propagação (erros de servidor com resposta válida).
  static bool _shouldQueue(DioException e) {
    final type = e.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout) {
      return true;
    }
    // 5xx → também enfileiramos (servidor lá em baixo)
    final code = e.response?.statusCode ?? 0;
    if (code >= 500) return true;
    // Sem resposta de todo (cancelamento, certificado, etc.)
    if (e.response == null) return true;
    return false;
  }

  static String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['detail'] != null) return data['detail'].toString();
      if (data.values.isNotEmpty) {
        final first = data.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
    }
    return e.message;
  }
}
