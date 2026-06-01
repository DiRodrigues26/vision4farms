import 'package:flutter/foundation.dart';

import '../models/sensor_association_model.dart';
import '../models/sensor_node_model.dart';
import '../services/firebase_sensor_service.dart';
import '../services/sensor_association_service.dart';
import '../services/sensor_data_resolver_service.dart';

class SensorProvider extends ChangeNotifier {
  final SensorAssociationService _associations;
  final FirebaseSensorService _firebase;
  late final SensorDataResolverService resolver;

  SensorProvider({
    required SensorAssociationService associations,
    required FirebaseSensorService firebase,
  })  : _associations = associations,
        _firebase = firebase {
    resolver = SensorDataResolverService(_firebase);
  }

  final Map<int, List<SensorAssociationModel>> _byFarm = {};
  final Map<int, List<SensorAssociationModel>> _byLand = {};
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<SensorAssociationModel> associationsForFarm(int farmId) =>
      _byFarm[farmId] ?? const [];

  List<SensorAssociationModel> associationsForLand(int landId) =>
      _byLand[landId] ?? const [];

  Future<List<SensorNodeModel>> findNodesByGatewayCode(String gatewayCode) {
    return _firebase.findNodesByGatewayCode(gatewayCode);
  }

  Future<List<SensorAssociationModel>> loadFarmAssociations(
    int farmId, {
    bool notify = true,
  }) async {
    _setLoading(true, notify: notify);
    try {
      final list = await _associations.list(farmId: farmId);
      _cache(farmId: farmId, associations: list);
      _errorMessage = null;
      return list;
    } catch (e) {
      _errorMessage = 'Erro ao carregar associações de sensores.';
      return _byFarm[farmId] ?? const [];
    } finally {
      _setLoading(false, notify: notify);
    }
  }

  Future<List<SensorAssociationModel>> loadLandAssociations(
    int landId, {
    int? farmId,
    bool notify = true,
  }) async {
    _setLoading(true, notify: notify);
    try {
      final list = await _associations.list(farmId: farmId, landId: landId);
      _byLand[landId] = list;
      if (farmId != null) {
        final farmList = <SensorAssociationModel>[...(_byFarm[farmId] ?? const [])]
          ..removeWhere((item) => item.landId == landId)
          ..addAll(list);
        _cache(farmId: farmId, associations: farmList);
      }
      _errorMessage = null;
      return list;
    } catch (_) {
      _errorMessage = 'Erro ao carregar sensores do terreno.';
      return _byLand[landId] ?? const [];
    } finally {
      _setLoading(false, notify: notify);
    }
  }

  Future<void> deleteAssociation({
    required int associationId,
    required int farmId,
  }) async {
    _setLoading(true);
    try {
      await _associations.delete(associationId);
      await loadFarmAssociations(farmId, notify: false);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erro ao remover associação.';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<SensorAssociationModel>> saveAssociations({
    required int farmId,
    required List<Map<String, dynamic>> associations,
  }) async {
    _setLoading(true);
    try {
      final saved = await _associations.saveBulk(
        farmId: farmId,
        associations: associations,
      );
      await loadFarmAssociations(farmId, notify: false);
      _errorMessage = null;
      notifyListeners();
      return saved;
    } catch (e) {
      _errorMessage = 'Erro ao guardar associações de sensores.';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _cache({
    required int farmId,
    required List<SensorAssociationModel> associations,
  }) {
    _byFarm[farmId] = associations;
    final grouped = <int, List<SensorAssociationModel>>{};
    for (final association in associations) {
      grouped.putIfAbsent(association.landId, () => []).add(association);
    }
    _byLand.addAll(grouped);
  }

  void _setLoading(bool value, {bool notify = true}) {
    _isLoading = value;
    if (notify) notifyListeners();
  }
}
