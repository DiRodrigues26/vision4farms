import 'package:flutter/foundation.dart';
import '../models/farm_model.dart';
import '../models/dashboard_model.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../constants/app_constants.dart';

class FarmProvider extends ChangeNotifier {
  final ApiService _api;

  List<FarmModel> _farms       = [];
  FarmModel?      _selectedFarm;
  DashboardModel? _dashboard;
  bool            _isLoading   = false;
  bool            _isFromCache = false;
  String?         _errorMessage;

  FarmProvider(this._api);

  List<FarmModel> get farms        => _farms;
  FarmModel?      get selectedFarm => _selectedFarm;
  DashboardModel? get dashboard    => _dashboard;
  bool            get isLoading    => _isLoading;
  bool            get isFromCache  => _isFromCache;
  String?         get errorMessage => _errorMessage;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }

  // ── Explorações ───────────────────────────────────────────

  Future<void> loadFarms() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await _api.get(AppConstants.dashboardFarms);
      final data = ApiService.extractResults(response.data);
      _farms       = data.map((f) => FarmModel.fromJson(f)).toList();
      _isFromCache = false;
      await LocalDatabase.saveFarms(data); // guarda no SQLite
    } catch (_) {
      // Sem rede — ler do SQLite
      final cached = await LocalDatabase.getFarms();
      if (cached.isNotEmpty) {
        _farms       = cached.map((f) => FarmModel.fromJson(f)).toList();
        _isFromCache = true;
      } else {
        _errorMessage = 'Sem ligação e sem dados guardados.';
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> selectFarm(FarmModel farm) async {
    _selectedFarm = farm;
    notifyListeners();
    try {
      await loadDashboard(farm.farmId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Dashboard ─────────────────────────────────────────────

  Future<void> loadDashboard(int farmId) async {
    _setLoading(true);
    try {
      final response = await _api.get(AppConstants.dashboardFarm(farmId));
      final data     = response.data as Map<String, dynamic>;
      _dashboard   = DashboardModel.fromJson(data);
      _isFromCache = false;
      await LocalDatabase.saveDashboard(farmId, data); // guarda no SQLite
    } catch (_) {
      // Sem rede — ler do SQLite
      final cached = await LocalDatabase.getDashboard(farmId);
      if (cached != null) {
        _dashboard   = DashboardModel.fromJson(cached);
        _isFromCache = true;
      } else {
        _errorMessage = 'Erro ao carregar dashboard.';
      }
    } finally {
      _setLoading(false);
    }
  }

  // ── Sincronização automática ao voltar online ─────────────

  Future<void> syncWhenOnline() async {
    if (_selectedFarm == null) return;
    try {
      final response = await _api.get(
          AppConstants.dashboardFarm(_selectedFarm!.farmId));
      final data   = response.data as Map<String, dynamic>;
      _dashboard   = DashboardModel.fromJson(data);
      _isFromCache = false;
      await LocalDatabase.saveDashboard(_selectedFarm!.farmId, data);
      notifyListeners();
    } catch (_) {}
  }

  void clearSelectedFarm() {
    _selectedFarm = null;
    _dashboard    = null;
    notifyListeners();
  }
}
