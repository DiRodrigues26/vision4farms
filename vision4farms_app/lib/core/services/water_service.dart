import '../constants/app_constants.dart';
import '../models/water_model.dart';
import 'api_service.dart';

/// Serviço de API para fontes de água, consumo e regas planeadas.
class WaterService {
  final ApiService _api;

  WaterService([ApiService? api]) : _api = api ?? ApiService();

  // ── Lookups ────────────────────────────────────────────────

  Future<List<WaterSourceType>> listTypes() async {
    final response = await _api.get(AppConstants.waterTypes);
    final list = ApiService.extractResults(response.data);
    return list
        .map((e) => WaterSourceType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WaterIrrigationMethod>> listMethods() async {
    final response = await _api.get(AppConstants.waterMethods);
    final list = ApiService.extractResults(response.data);
    return list
        .map((e) => WaterIrrigationMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Water Sources ──────────────────────────────────────────

  Future<List<WaterSource>> listSources({required int farmId}) async {
    final response = await _api.get(
      AppConstants.waterSources,
      params: {'farm_id': farmId},
    );
    final list = ApiService.extractResults(response.data);
    return list
        .map((e) => WaterSource.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WaterSource> getSource(int sourceId) async {
    final response = await _api.get(AppConstants.waterSourceDetail(sourceId));
    return WaterSource.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WaterSource> createSource(Map<String, dynamic> data) async {
    final response = await _api.post(AppConstants.waterSources, data: data);
    return WaterSource.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WaterSource> updateSource(int sourceId, Map<String, dynamic> data) async {
    final response = await _api.patch(
      AppConstants.waterSourceDetail(sourceId),
      data: data,
    );
    return WaterSource.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteSource(int sourceId) async {
    await _api.delete(AppConstants.waterSourceDetail(sourceId));
  }

  // ── Usage Logs ─────────────────────────────────────────────

  Future<List<WaterUsageLog>> listUsage({
    int? waterSourceId,
    int? landId,
    int? farmId,
  }) async {
    final params = <String, dynamic>{};
    if (waterSourceId != null) params['water_source_id'] = waterSourceId;
    if (landId != null) params['land_id'] = landId;
    if (farmId != null) params['farm_id'] = farmId;
    final response = await _api.get(AppConstants.waterUsageLogs, params: params);
    final list = ApiService.extractResults(response.data);
    return list
        .map((e) => WaterUsageLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WaterUsageLog> createUsage(Map<String, dynamic> data) async {
    final response = await _api.post(AppConstants.waterUsageLogs, data: data);
    return WaterUsageLog.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WaterUsageLog> updateUsage(int usageId, Map<String, dynamic> data) async {
    final response = await _api.patch(
      AppConstants.waterUsageDetail(usageId),
      data: data,
    );
    return WaterUsageLog.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteUsage(int usageId) async {
    await _api.delete(AppConstants.waterUsageDetail(usageId));
  }

  // ── Planned Irrigations ────────────────────────────────────

  Future<List<WaterIrrigationPlan>> listPlanned({
    int? farmId,
    int? landId,
    int? waterSourceId,
    int? status,
  }) async {
    final params = <String, dynamic>{};
    if (farmId != null) params['farm_id'] = farmId;
    if (landId != null) params['land_id'] = landId;
    if (waterSourceId != null) params['water_source_id'] = waterSourceId;
    if (status != null) params['status'] = status;
    final response = await _api.get(AppConstants.waterPlanned, params: params);
    final list = ApiService.extractResults(response.data);
    return list
        .map((e) => WaterIrrigationPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WaterIrrigationPlan> createPlanned(Map<String, dynamic> data) async {
    final response = await _api.post(AppConstants.waterPlanned, data: data);
    return WaterIrrigationPlan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WaterIrrigationPlan> updatePlanned(int plannedId, Map<String, dynamic> data) async {
    final response = await _api.patch(
      AppConstants.waterPlannedDetail(plannedId),
      data: data,
    );
    return WaterIrrigationPlan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePlanned(int plannedId) async {
    await _api.delete(AppConstants.waterPlannedDetail(plannedId));
  }

  Future<Map<String, dynamic>> executePlanned(
    int plannedId, {
    double? volumeLiters,
    double? cost,
    String? purpose,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (volumeLiters != null) data['volume_liters'] = volumeLiters;
    if (cost != null) data['cost'] = cost;
    if (purpose != null) data['purpose'] = purpose;
    if (notes != null) data['notes'] = notes;
    final response = await _api.post(
      AppConstants.waterPlannedExecute(plannedId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }
}
