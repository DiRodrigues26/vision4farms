import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/water_service.dart';
import '../../../core/models/water_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/safe_back.dart';

class IrrigationScreen extends StatefulWidget {
  const IrrigationScreen({super.key});

  @override
  State<IrrigationScreen> createState() => _IrrigationScreenState();
}

class _IrrigationScreenState extends State<IrrigationScreen> {
  final _api = ApiService();
  final _waterService = WaterService();

  List<Map<String, dynamic>> _lands = [];
  Map<int, int> _plannedCount = {};
  Map<int, int> _executedCount = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.get(AppConstants.lands, params: {'farm_id': farm.farmId.toString()}),
        _waterService.listPlanned(farmId: farm.farmId, status: 0),
        _waterService.listUsage(farmId: farm.farmId),
      ]);
      final landsList = ApiService.extractResults((results[0] as dynamic).data)
          .cast<Map<String, dynamic>>();
      final plans = results[1] as List<WaterIrrigationPlan>;
      final usages = results[2] as List<WaterUsageLog>;

      final planned = <int, int>{};
      for (final p in plans) {
        planned[p.landId] = (planned[p.landId] ?? 0) + 1;
      }
      final executed = <int, int>{};
      for (final u in usages) {
        if (u.landId != null) {
          executed[u.landId!] = (executed[u.landId!] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _lands = landsList;
        _plannedCount = planned;
        _executedCount = executed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erro ao carregar regas.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLand(int landId, String landName) async {
    await context.push('/irrigation/land/$landId?name=${Uri.encodeComponent(landName)}');
    if (mounted) _load();
  }

  Future<void> _openSources() async {
    await context.push('/water/sources');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Regas'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Fontes de água',
            icon: const Icon(Icons.water_drop_outlined),
            onPressed: _openSources,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    if (_lands.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text(
              'Sem terrenos nesta exploração.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Regas por terreno',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ..._lands.map((l) {
          final landId = l['land_id'] as int;
          final landName = l['land_name']?.toString() ?? '';
          return _LandIrrigationCard(
            landName: landName,
            plannedCount: _plannedCount[landId] ?? 0,
            executedCount: _executedCount[landId] ?? 0,
            onTap: () => _openLand(landId, landName),
          );
        }),
      ],
    );
  }
}

class _LandIrrigationCard extends StatelessWidget {
  final String landName;
  final int plannedCount;
  final int executedCount;
  final VoidCallback onTap;

  const _LandIrrigationCard({
    required this.landName,
    required this.plannedCount,
    required this.executedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.terrain,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(landName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CountChip(
                            label: 'Planeadas',
                            count: plannedCount,
                            color: const Color(0xFFCCE5FF),
                            textColor: const Color(0xFF0D47A1),
                          ),
                          const SizedBox(width: 8),
                          _CountChip(
                            label: 'Executadas',
                            count: executedCount,
                            color: const Color(0xFFE8F5E9),
                            textColor: const Color(0xFF1B5E20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color textColor;

  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
