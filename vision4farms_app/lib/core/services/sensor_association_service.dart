import '../constants/app_constants.dart';
import '../models/sensor_association_model.dart';
import 'api_service.dart';

class SensorAssociationService {
  final ApiService _api;

  SensorAssociationService(this._api);

  Future<List<SensorAssociationModel>> list({
    int? farmId,
    int? landId,
  }) async {
    final response = await _api.get(
      AppConstants.sensorAssociations,
      params: {
        if (farmId != null) 'farm_id': farmId.toString(),
        if (landId != null) 'land_id': landId.toString(),
      },
    );
    final data = ApiService.extractResults(response.data).isNotEmpty
        ? ApiService.extractResults(response.data)
        : (response.data is List ? response.data as List : const []);
    return data
        .map((item) => SensorAssociationModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<List<SensorAssociationModel>> saveBulk({
    required int farmId,
    required List<Map<String, dynamic>> associations,
  }) async {
    final response = await _api.post(
      AppConstants.sensorAssociationsBulk,
      data: {
        'farm_id': farmId,
        'associations': associations,
      },
    );
    final data = response.data is List ? response.data as List : const [];
    return data
        .map((item) => SensorAssociationModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<void> delete(int associationId) async {
    await _api.delete(AppConstants.sensorAssociationDetail(associationId));
  }
}
