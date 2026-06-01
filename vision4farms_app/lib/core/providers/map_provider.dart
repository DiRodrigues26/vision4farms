import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/land_model.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';
import '../services/local_database.dart';

enum MapFilter { all, withActivities, overdue, withCrops, irrigation, treatment, harvest, pending, done }

class MapProvider extends ChangeNotifier {
  final ApiService _api;

  List<LandMapItem> _lands = [];
  LandModel? _selectedLand;
  bool _isLoading = false;
  String? _errorMessage;

  MapFilter _activeFilter = MapFilter.all;
  String _searchQuery = '';
  String _mapStyle = 'satellite';

  String? _farmName;
  String? _farmGps;
  double _totalAreaHa = 0;

  MapProvider(this._api);

  List<LandMapItem> get filteredLands => _filteredLands;
  List<LandMapItem> get allLands => _lands;
  LandModel? get selectedLand => _selectedLand;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MapFilter get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;
  String get mapStyle => _mapStyle;
  String? get farmGps => _farmGps;

  List<LandMapItem> get _filteredLands {
    var list = _lands;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((item) =>
        item.land.landName.toLowerCase().contains(q) ||
        (item.land.landLocation ?? '').toLowerCase().contains(q)).toList();
    }
    switch (_activeFilter) {
      case MapFilter.all: break;
      case MapFilter.withActivities:
        list = list.where((item) => item.hasActivities).toList(); break;
      case MapFilter.overdue:
        list = list.where((item) => item.hasOverdue).toList(); break;
      case MapFilter.withCrops:
        list = list.where((item) => item.cropName != null).toList(); break;
      case MapFilter.irrigation:
        list = list.where((item) => item.hasType('irrigation')).toList(); break;
      case MapFilter.treatment:
        list = list.where((item) => item.hasType('treatment')).toList(); break;
      case MapFilter.harvest:
        list = list.where((item) => item.hasType('harvest')).toList(); break;
      case MapFilter.pending:
        list = list.where((item) => item.pendingActivities > 0).toList(); break;
      case MapFilter.done:
        list = list.where((item) => item.hasDone).toList(); break;
    }
    return list;
  }

  void setFilter(MapFilter filter) { _activeFilter = filter; notifyListeners(); }
  void setSearch(String query) { _searchQuery = query; notifyListeners(); }
  void toggleMapStyle() {
    _mapStyle = _mapStyle == 'satellite' ? 'hybrid' : 'satellite';
    notifyListeners();
  }
  void selectLand(LandModel? land) { _selectedLand = land; notifyListeners(); }
  void clearSelection() { _selectedLand = null; notifyListeners(); }

  Future<void> loadMapData(int farmId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.get(AppConstants.mapData(farmId));
      final data = response.data as Map<String, dynamic>;
      await LocalDatabase.saveMapData(farmId, data);
      _parseMapData(data);
    } catch (e) {
      if (e is DioException) {
        final code = e.response?.statusCode;
        debugPrint('[MapProvider] loadMapData FAILED farm=$farmId status=$code body=${e.response?.data}');
        if (code == 403) {
          _errorMessage = 'Sem acesso a esta exploração.';
        } else if (code == 404) {
          _errorMessage = 'Exploração não encontrada.';
        }
      } else {
        debugPrint('[MapProvider] loadMapData FAILED farm=$farmId error=$e');
      }
      // Sem rede (ou erro) — tentar SQLite
      final cached = await LocalDatabase.getMapData(farmId);
      if (cached != null) {
        _parseMapData(cached);
        _errorMessage = null;
      } else {
        _errorMessage ??= 'Sem ligação e sem dados do mapa guardados.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _parseMapData(Map<String, dynamic> data) {
    final farmData = data['farm'] as Map<String, dynamic>? ?? {};
    _farmName    = farmData['farm_name'] as String?;
    _farmGps     = farmData['farm_gps']  as String?;
    _totalAreaHa = (data['total_area_ha'] as num?)?.toDouble() ?? 0;
    final landsRaw = data['lands'] as List? ?? [];
    _lands = landsRaw.map((raw) {
      final m = raw as Map<String, dynamic>;
      return LandMapItem(
        land: LandModel.fromJson(m),
        pendingActivities: (m['pending_activities'] as num?)?.toInt() ?? 0,
        overdueActivities: (m['overdue_activities'] as num?)?.toInt() ?? 0,
        doneActivities: (m['done_activities'] as num?)?.toInt() ?? 0,
        activityTypes: (m['activity_types'] as List?)?.cast<String>() ?? [],
        cropName: m['crop_name'] as String?,
      );
    }).toList();
  }

  int get totalLands => _lands.length;
  double get totalAreaHa => _totalAreaHa;
  int get landsWithActivities => _lands.where((l) => l.hasActivities).length;
  int get landsWithOverdue    => _lands.where((l) => l.hasOverdue).length;
}