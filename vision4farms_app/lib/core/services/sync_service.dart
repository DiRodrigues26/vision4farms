import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';
import 'local_database.dart';

/// Replay de operações que ficaram pendentes offline. Cada tipo de operação
/// tem o seu handler que reproduz a chamada à API original.
///
/// Convenção dos `data` na queue:
/// - sempre que possível inclui um `client_uuid` para idempotência e
///   correspondência com a escrita otimista no `local_writes`.
/// - operações com upload de ficheiro (observações com foto) incluem
///   também `_photo_path` (caminho local) que é tratado após o create.
class SyncService {
  final ApiService _api;

  SyncService(this._api);

  /// Drena a fila pendente, com retry e last-write-wins.
  Future<int> processPendingQueue() async {
    final pending = await LocalDatabase.getPendingOperations();
    if (pending.isEmpty) return 0;

    int synced = 0;
    debugPrint('[Sync] ${pending.length} operações pendentes');

    for (final op in pending) {
      final id   = op['id'] as int;
      final type = op['operation_type'] as String;
      Map<String, dynamic> data;
      try {
        data = jsonDecode(op['data'] as String) as Map<String, dynamic>;
      } catch (_) {
        await LocalDatabase.markOperationFailed(id, 'JSON inválido');
        continue;
      }

      try {
        await _processOperation(type, data);
        await LocalDatabase.markOperationDone(id);
        // Remove a escrita otimista correspondente (se existir)
        final clientUuid = data['client_uuid']?.toString();
        if (clientUuid != null && clientUuid.isNotEmpty) {
          await LocalDatabase.removeLocalWriteByUuid(clientUuid);
        }
        synced++;
        debugPrint('[Sync] ✅ $type');
      } on DioException catch (e) {
        // 4xx (exceto 429) → operação inválida, marcar como failed sem retry
        final code = e.response?.statusCode ?? 0;
        if (code >= 400 && code < 500 && code != 429) {
          final detail = _extractDetail(e);
          await LocalDatabase.markOperationFailed(id, '$code: $detail');
          debugPrint('[Sync] ❌ $type falhou definitivamente ($code): $detail');
        } else {
          await _retryOrFail(op, id, type, e.toString());
        }
      } catch (e) {
        await _retryOrFail(op, id, type, e.toString());
      }
    }

    debugPrint('[Sync] $synced/${pending.length} sincronizados');
    return synced;
  }

  Future<void> _retryOrFail(
      Map<String, dynamic> op, int id, String type, String error) async {
    final retries = (op['retries'] as int? ?? 0) + 1;
    if (retries >= 3) {
      await LocalDatabase.markOperationFailed(id, error);
      debugPrint('[Sync] ❌ $type abandonado após 3 tentativas');
    } else {
      await LocalDatabase.incrementRetry(id);
      debugPrint('[Sync] ⚠️ $type falhou (tentativa $retries): $error');
    }
  }

  String _extractDetail(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    if (data is Map && data.isNotEmpty) return data.values.first.toString();
    return e.message ?? 'Erro desconhecido';
  }

  /// Remove campos internos (prefixados com _ ou client_uuid) que não devem
  /// ser enviados ao servidor.
  Map<String, dynamic> _strip(Map<String, dynamic> data) {
    return Map.fromEntries(data.entries.where(
        (e) => !e.key.startsWith('_') && e.key != 'client_uuid'));
  }

  // ════════════════════════════════════════════════════════════
  // Handlers por tipo de operação
  // ════════════════════════════════════════════════════════════

  Future<void> _processOperation(
      String type, Map<String, dynamic> data) async {
    switch (type) {
      // ── Lands ──────────────────────────────────────────────
      case 'create_land':
        await _api.post(AppConstants.landsCreate, data: _strip(data));
        return;
      case 'update_land':
        await _api.patch(
          AppConstants.landDetail(data['land_id'] as int),
          data: _strip(data)..remove('land_id'),
        );
        return;

      // ── Yields (cultura num terreno) ────────────────────────
      case 'create_yield':
        await _api.post(AppConstants.yieldsCreate, data: _strip(data));
        return;
      case 'update_yield':
        await _api.patch(
          AppConstants.yieldDetail(data['yield_id'] as int),
          data: _strip(data)..remove('yield_id'),
        );
        return;
      case 'delete_yield':
        await _api.delete(AppConstants.yieldDetail(data['yield_id'] as int));
        return;

      // ── Activities ──────────────────────────────────────────
      case 'create_activity':
        await _api.post(AppConstants.activitiesCreate, data: _strip(data));
        return;
      case 'update_activity':
        await _api.patch(
          AppConstants.activityDetail(data['activity_id'] as int),
          data: _strip(data)..remove('activity_id'),
        );
        return;
      case 'complete_activity':
        await _api.patch(
          AppConstants.activityDetail(data['activity_id'] as int),
          data: {'activity_status': 1},
        );
        return;
      case 'delete_activity':
        await _api.delete(
            AppConstants.activityDetail(data['activity_id'] as int));
        return;

      // ── Observations (com possíveis fotos locais) ──────────
      case 'create_observation':
        final payload = _strip(data)
          ..remove('_photo_path')
          ..remove('_photo_paths')
          ..remove('_link_activity_id');
        final response =
            await _api.post(AppConstants.observations, data: payload);
        final created = response.data as Map<String, dynamic>;
        final obsId = created['observation_id'] as int;

        // Coletar paths de foto: aceita campo único ou lista
        final paths = <String>[];
        final single = data['_photo_path']?.toString();
        if (single != null && single.isNotEmpty) paths.add(single);
        final list = data['_photo_paths'];
        if (list is List) {
          paths.addAll(list.map((e) => e.toString()).where((s) => s.isNotEmpty));
        }
        for (final p in paths) {
          if (!File(p).existsSync()) continue;
          try {
            final formData = FormData.fromMap({
              'photo': await MultipartFile.fromFile(p),
            });
            await _api.post(
              AppConstants.observationImageUpload(obsId),
              data: formData,
            );
          } catch (e) {
            debugPrint('[Sync] foto da observação $obsId falhou: $e');
          }
        }

        // Ligar a uma atividade, se solicitado
        final linkActivityId = data['_link_activity_id'] as int?;
        if (linkActivityId != null) {
          try {
            await _api.patch(
              AppConstants.activityDetail(linkActivityId),
              data: {'observation': obsId},
            );
          } catch (e) {
            debugPrint('[Sync] ligação atividade↔obs falhou: $e');
          }
        }
        return;

      // ── Harvests ───────────────────────────────────────────
      case 'create_harvest':
        await _api.post(
          AppConstants.harvestCreate(data['yield_id'] as int),
          data: _strip(data)..remove('yield_id'),
        );
        return;
      case 'update_harvest':
        await _api.patch(
          AppConstants.harvestDetail(data['harvest_id'] as int),
          data: _strip(data)..remove('harvest_id'),
        );
        return;
      case 'delete_harvest':
        await _api.delete(
            AppConstants.harvestDetail(data['harvest_id'] as int));
        return;

      // ── Water sources ──────────────────────────────────────
      case 'create_water_source':
        await _api.post(AppConstants.waterSources, data: _strip(data));
        return;
      case 'update_water_source':
        await _api.patch(
          AppConstants.waterSourceDetail(data['water_source_id'] as int),
          data: _strip(data)..remove('water_source_id'),
        );
        return;
      case 'delete_water_source':
        await _api.delete(
            AppConstants.waterSourceDetail(data['water_source_id'] as int));
        return;

      // ── Water usage logs (regas executadas) ────────────────
      case 'create_water_usage':
        await _api.post(AppConstants.waterUsageLogs, data: _strip(data));
        return;
      case 'update_water_usage':
        await _api.patch(
          AppConstants.waterUsageDetail(data['water_usage_id'] as int),
          data: _strip(data)..remove('water_usage_id'),
        );
        return;
      case 'delete_water_usage':
        await _api.delete(
            AppConstants.waterUsageDetail(data['water_usage_id'] as int));
        return;

      // ── Water planned (regas planeadas) ────────────────────
      case 'create_water_planned':
        await _api.post(AppConstants.waterPlanned, data: _strip(data));
        return;
      case 'update_water_planned':
        await _api.patch(
          AppConstants.waterPlannedDetail(data['planned_id'] as int),
          data: _strip(data)..remove('planned_id'),
        );
        return;
      case 'delete_water_planned':
        await _api.delete(
            AppConstants.waterPlannedDetail(data['planned_id'] as int));
        return;
      case 'execute_water_planned':
        final id = data['planned_id'] as int;
        final body = _strip(data)..remove('planned_id');
        await _api.post(AppConstants.waterPlannedExecute(id), data: body);
        return;

      // ── Agenda ─────────────────────────────────────────────
      case 'create_agenda':
        await _api.post(AppConstants.agendaCreate, data: _strip(data));
        return;
      case 'update_agenda':
        await _api.patch(
          AppConstants.agendaDetail(data['agenda_id'] as int),
          data: _strip(data)..remove('agenda_id'),
        );
        return;
      case 'delete_agenda':
        await _api.delete(
            AppConstants.agendaDetail(data['agenda_id'] as int));
        return;

      // ── Soil analyses (com possível PDF anexado) ───────────
      case 'create_soil_analysis':
        {
          final landId = data['land_id'] as int;
          final filePath = data['_file_path']?.toString();
          final body = _strip(data)
            ..remove('land_id')
            ..remove('_file_path');
          if (filePath != null && filePath.isNotEmpty &&
              File(filePath).existsSync()) {
            final formFields = {...body};
            formFields['file'] = await MultipartFile.fromFile(filePath);
            await _api.post(
              AppConstants.soilAnalysisCreate(landId),
              data: FormData.fromMap(formFields),
            );
          } else {
            await _api.post(
                AppConstants.soilAnalysisCreate(landId), data: body);
          }
        }
        return;
      case 'update_soil_analysis':
        await _api.patch(
          AppConstants.soilAnalysisDetail(
              data['soil_analysis_id'] as int),
          data: _strip(data)..remove('soil_analysis_id'),
        );
        return;
      case 'delete_soil_analysis':
        await _api.delete(AppConstants.soilAnalysisDetail(
            data['soil_analysis_id'] as int));
        return;

      // ── Foliar analyses (com possível PDF anexado) ─────────
      case 'create_foliar_analysis':
        {
          final yieldId = data['yield_id'] as int;
          final filePath = data['_file_path']?.toString();
          final body = _strip(data)
            ..remove('yield_id')
            ..remove('_file_path');
          if (filePath != null && filePath.isNotEmpty &&
              File(filePath).existsSync()) {
            final formFields = {...body};
            formFields['file'] = await MultipartFile.fromFile(filePath);
            await _api.post(
              AppConstants.foliarAnalysisCreate(yieldId),
              data: FormData.fromMap(formFields),
            );
          } else {
            await _api.post(
                AppConstants.foliarAnalysisCreate(yieldId), data: body);
          }
        }
        return;
      case 'delete_foliar_analysis':
        await _api.delete(AppConstants.foliarAnalysisDetail(
            data['foliar_analysis_id'] as int));
        return;

      // ── Notifications ──────────────────────────────────────
      case 'mark_notification_read':
        await _api.post(
            AppConstants.notificationRead(data['notification_id'] as int));
        return;
      case 'toggle_notification_read':
        await _api.post(AppConstants.notificationToggleRead(
            data['notification_id'] as int));
        return;

      // ── Profile ────────────────────────────────────────────
      case 'update_profile':
        await _api.patch(AppConstants.profileUpdate, data: _strip(data));
        return;

      default:
        throw Exception('Tipo de operação desconhecido: $type');
    }
  }

  // ════════════════════════════════════════════════════════════
  // Métodos utilitários
  // ════════════════════════════════════════════════════════════

  Future<bool> hasPending() async {
    final pending = await LocalDatabase.getPendingOperations();
    return pending.isNotEmpty;
  }

  Future<int> pendingCount() async {
    final pending = await LocalDatabase.getPendingOperations();
    return pending.length;
  }
}
