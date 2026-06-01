import '../constants/app_constants.dart';
import 'api_service.dart';

class HarvestService {
  final ApiService _api;
  HarvestService([ApiService? api]) : _api = api ?? ApiService();

  Future<List<Map<String, dynamic>>> list(int yieldId) async {
    final response = await _api.get(AppConstants.harvestList(yieldId));
    final list = ApiService.extractResults(response.data);
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> get(int harvestId) async {
    final response = await _api.get(AppConstants.harvestDetail(harvestId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(
      int yieldId, Map<String, dynamic> data) async {
    final response =
        await _api.post(AppConstants.harvestCreate(yieldId), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
      int harvestId, Map<String, dynamic> data) async {
    final response = await _api.patch(
      AppConstants.harvestDetail(harvestId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(int harvestId) async {
    await _api.delete(AppConstants.harvestDetail(harvestId));
  }
}
