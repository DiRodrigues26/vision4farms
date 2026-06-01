import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/sensor_data_resolver_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sensor_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/services/local_database.dart';
import 'create_land_dialog.dart';

class LandListScreen extends StatefulWidget {
  const LandListScreen({super.key});

  @override
  State<LandListScreen> createState() => _LandListScreenState();
}

class _LandListScreenState extends State<LandListScreen> {
  final _api = ApiService();
  List<dynamic> _lands = [];
  bool _isLoading = true;
  String? _error;
  double? _tempAvg;
  double? _humidityAvg;
  Map<int, SensorAverages> _sensorAveragesByLand = {};

  @override
  void initState() {
    super.initState();
    _loadLands();
  }

  Future<void> _loadLands() async {
    setState(() { _isLoading = true; _error = null; });
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) {
      setState(() {
        _isLoading = false;
        _error = 'Seleciona uma exploração primeiro.';
      });
      return;
    }
    try {
      final response = await _api
          .get(
            AppConstants.lands,
            params: {'farm_id': farm.farmId.toString()},
          )
          .timeout(const Duration(seconds: 15));
      final data = ApiService.extractResults(response.data);
      await LocalDatabase.saveLands(farm.farmId, data);
      setState(() => _lands = data);
    } on DioException catch (e) {
      debugPrint('[Lands] list FAILED: ${e.response?.statusCode} ${e.response?.data}');
      final cached = await LocalDatabase.getLands(farm.farmId);
      if (cached.isNotEmpty) {
        setState(() => _lands = cached);
      } else {
        final code = e.response?.statusCode;
        setState(() {
          _error = code == 403
              ? 'Sem acesso a esta exploração.'
              : code == 401
                  ? 'Sessão expirada. Volta a entrar.'
                  : 'Erro ao carregar terrenos${code != null ? " ($code)" : ""}.';
        });
      }
    } catch (e) {
      debugPrint('[Lands] list FAILED (other): $e');
      final cached = await LocalDatabase.getLands(farm.farmId);
      if (cached.isNotEmpty) {
        setState(() => _lands = cached);
      } else {
        setState(() => _error = 'Timeout ou erro a carregar terrenos.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    _loadWeatherAverages(farm.farmGps);
    _loadSensorAverages(farm.farmId);
  }

  Future<void> _loadSensorAverages(int farmId) async {
    try {
      final provider = context.read<SensorProvider>();
      final associations =
          await provider.loadFarmAssociations(farmId, notify: false);
      if (associations.isEmpty) return;
      final map = await provider.resolver.landsAverages(associations);
      if (mounted) setState(() => _sensorAveragesByLand = map);
    } catch (_) {}
  }

  Future<void> _loadWeatherAverages(String? gps) async {
    if (gps == null || gps.isEmpty) return;
    final parts = gps.split(',');
    if (parts.length < 2) return;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return;
    try {
      final response = await Dio().get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'hourly': 'temperature_2m,relative_humidity_2m',
          'timezone': 'Europe/Lisbon',
          'past_days': 1,
          'forecast_days': 1,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final hourly = response.data['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List).map((t) => DateTime.parse(t as String)).toList();
      final temps = (hourly['temperature_2m'] as List).map((v) => (v as num).toDouble()).toList();
      final hums = (hourly['relative_humidity_2m'] as List).map((v) => (v as num).toDouble()).toList();
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));
      double tSum = 0, hSum = 0;
      int count = 0;
      for (int i = 0; i < times.length; i++) {
        if (times[i].isAfter(cutoff) && times[i].isBefore(now)) {
          tSum += temps[i];
          hSum += hums[i];
          count++;
        }
      }
      if (count > 0 && mounted) {
        setState(() {
          _tempAvg = tSum / count;
          _humidityAvg = hSum / count;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Os Seus Terrenos',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            // ── Lista ────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _loadLands)
                      : _lands.isEmpty
                          ? const _EmptyState()
                          : RefreshIndicator(
                              color: AppTheme.primary,
                              onRefresh: _loadLands,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                itemCount: _lands.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final landData = _lands[index] as Map<String, dynamic>;
                                  final landId = landData['land_id'] as int? ?? 0;
                                  final sensorAvg = _sensorAveragesByLand[landId];
                                  return _LandCard(
                                    land: landData,
                                    apiService: _api,
                                    tempAvg: _tempAvg,
                                    humidityAvg: _humidityAvg,
                                    sensorAverages: sensorAvg,
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),

      // ── FAB — Adicionar terreno (Gestor only) ─────────────
      floatingActionButton: !(context.read<FarmProvider>().selectedFarm?.canManage ?? false)
          ? null
          : FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            barrierColor: Colors.black54,
            builder: (_) => const CreateLandDialog(),
          );
          if (created == true) _loadLands();
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Adicionar novo terreno',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Card de terreno ───────────────────────────────────────────

class _LandCard extends StatelessWidget {
  final Map<String, dynamic> land;
  final ApiService apiService;
  final double? tempAvg;
  final double? humidityAvg;
  final SensorAverages? sensorAverages;

  const _LandCard({
    required this.land,
    required this.apiService,
    this.tempAvg,
    this.humidityAvg,
    this.sensorAverages,
  });

  String _formatLastIrrigation(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      final now  = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) return 'Hoje';
      if (diff == 1) return 'Ontem';
      final months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final landId         = land['land_id'] as int? ?? 0;
    final landName       = land['land_name']?.toString() ?? '';
    final crops          = (land['crops'] as List?)
        ?.map((c) => c['crop_name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .join(' & ') ?? '';
    double areaHa = 0.0;
    try { areaHa = double.parse(land['land_size']?.toString() ?? '0'); } catch (_) {}
    int activities = 0;
    try { activities = int.parse(land['activity_count']?.toString() ?? '0'); } catch (_) {}
    final lastIrrigation = _formatLastIrrigation(land['last_irrigation']?.toString());

    return GestureDetector(
      onTap: () => context.go('/lands/$landId?name=${Uri.encodeComponent(landName)}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Nome + chevron ────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    landName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              ],
            ),

            if (crops.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                crops,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],

            const SizedBox(height: 12),

            // ── Linha de chips principais ─────────────────
            Row(
              children: [
                _StatChip(
                  value: areaHa % 1 == 0
                      ? areaHa.toInt().toString()
                      : areaHa.toStringAsFixed(1),
                  label: 'Hectares',
                  color: const Color(0xFFD4EDDA), // verde claro
                  textColor: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  value: activities.toString(),
                  label: 'Atividades',
                  color: const Color(0xFFE8D5F5), // lilás claro
                  textColor: const Color(0xFF7B1FA2),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  value: lastIrrigation,
                  label: 'Última Rega',
                  color: const Color(0xFFFFFFFF),
                  textColor: AppTheme.textPrimary,
                  bordered: true,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                _StatChip(
                  value: () {
                    final t = sensorAverages?.temperaturaAr;
                    if (t != null) return '${t.toStringAsFixed(0)}º';
                    return tempAvg != null
                        ? '${tempAvg!.toStringAsFixed(0)}º'
                        : '—';
                  }(),
                  label: sensorAverages?.temperaturaAr != null
                      ? 'Temperatura\nSensor'
                      : 'Temperatura\nMédia',
                  color: const Color(0xFFFFF3CD),
                  textColor: const Color(0xFFE65100),
                  flex: 1,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  value: () {
                    final h = sensorAverages?.humidadeAr;
                    if (h != null) return '${h.toStringAsFixed(0)}%';
                    return humidityAvg != null
                        ? '${humidityAvg!.toStringAsFixed(0)}%'
                        : '—';
                  }(),
                  label: sensorAverages?.humidadeAr != null
                      ? 'Humidade\nSensor'
                      : 'Humidade\nMédia',
                  color: const Color(0xFFCCE5FF),
                  textColor: const Color(0xFF0D47A1),
                  flex: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip de estatística ───────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color textColor;
  final bool bordered;
  final int flex;

  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
    this.bordered = false,
    this.flex = 0,
  });

  Widget _chip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: bordered ? Border.all(color: AppTheme.divider) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.75)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (flex > 0) return Expanded(child: _chip());
    return _chip();
  }
}

// ── Empty state ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terrain_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.35)),
            const SizedBox(height: 16),
            const Text(
              'Sem terrenos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adiciona o teu primeiro terreno\npara começar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}