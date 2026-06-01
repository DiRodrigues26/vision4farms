import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/add_analysis_dialog.dart';
import '../../../shared/widgets/harvest_form_dialog.dart';
import '../../observations/screens/observation_detail_screen.dart';
import '../../../shared/widgets/pdf_launcher.dart';
import '../../../shared/utils/safe_back.dart';
import '../../../core/services/local_database.dart';

class CropDetailScreen extends StatefulWidget {
  final int cropId;
  final String cropName;
  final ApiService apiService;

  const CropDetailScreen({
    super.key,
    required this.cropId,
    required this.cropName,
    required this.apiService,
  });

  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  Map<String, dynamic> _crop = {};
  List<Map<String, dynamic>> _yields = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _observations = [];
  List<Map<String, dynamic>> _harvests = [];
  List<Map<String, dynamic>> _analyses = [];
  List<Map<String, dynamic>> _irrigationUsage = [];
  List<Map<String, dynamic>> _irrigationPlanned = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final farm = context.read<FarmProvider>().selectedFarm;
      final params = <String, String>{};
      if (farm != null) params['farm_id'] = farm.farmId.toString();

      final response = await widget.apiService.get(
        AppConstants.cropHub(widget.cropId),
        params: params,
      );
      final data = response.data as Map<String, dynamic>;

      // Cache
      await LocalDatabase.saveCropDetail(widget.cropId, data);

      setState(() {
        _crop = (data['crop'] as Map<String, dynamic>?) ?? {};
        _yields = _castList(data['yields']);
        _activities = _castList(data['activities']);
        _observations = _castList(data['observations']);
        _harvests = _castList(data['harvests']);
        _analyses = _castList(data['analyses']);
        final irrData = data['irrigation'] as Map<String, dynamic>? ?? {};
        _irrigationUsage = _castList(irrData['usage']);
        _irrigationPlanned = _castList(irrData['planned']);
      });
    } catch (e) {
      final cached = await LocalDatabase.getCropDetail(widget.cropId);
      if (cached != null) {
        setState(() {
          _crop = (cached['crop'] as Map<String, dynamic>?) ?? {};
          _yields = _castList(cached['yields']);
          _activities = _castList(cached['activities']);
          _observations = _castList(cached['observations']);
          _harvests = _castList(cached['harvests']);
          _analyses = _castList(cached['analyses']);
          final irrData = cached['irrigation'] as Map<String, dynamic>? ?? {};
          _irrigationUsage = _castList(irrData['usage']);
          _irrigationPlanned = _castList(irrData['planned']);
        });
      } else {
        setState(() => _error = 'Sem ligação e sem dados guardados.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  static List<Map<String, dynamic>> _castList(dynamic list) {
    if (list is List) return list.cast<Map<String, dynamic>>();
    return [];
  }

  String _fmt(String? d) {
    if (d == null || d.isEmpty) return '—';
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Fev','Mar','Abr','Mai','Jun',
                  'Jul','Ago','Set','Out','Nov','Dez'];
      return '${dt.day} ${m[dt.month - 1]}, ${dt.year}';
    } catch (_) { return d; }
  }

  /// Abre o formulário de nova colheita. Se a cultura tem apenas um yield
  /// usa-o directamente; se tiver mais que um, pede ao utilizador para
  /// escolher para qual terreno/yield quer registar a colheita.
  Future<void> _addHarvest() async {
    if (_yields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta cultura ainda não está atribuída a nenhum terreno.'),
        ),
      );
      return;
    }

    int? yieldId;
    if (_yields.length == 1) {
      yieldId = _yields.first['yield_id'] as int?;
    } else {
      yieldId = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Escolhe o terreno',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
              ),
              const Divider(height: 1, color: AppTheme.divider),
              ..._yields.map((y) {
                final landName = y['land_name']?.toString() ?? 'Terreno';
                final variety = y['variety_name']?.toString() ?? '';
                final id = y['yield_id'] as int?;
                return ListTile(
                  leading: const Icon(Icons.terrain, color: AppTheme.primary),
                  title: Text(landName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  subtitle: variety.isNotEmpty ? Text(variety) : null,
                  onTap: () => Navigator.of(ctx).pop(id),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    if (yieldId == null || !mounted) return;

    final result = await HarvestFormDialog.show(
      context: context,
      yieldId: yieldId,
    );
    if (result != null && mounted) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.cropName),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context),
        ),
        bottom: _isLoading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Resumo'),
                  Tab(text: 'Terrenos'),
                  Tab(text: 'Rega'),
                  Tab(text: 'Atividades'),
                  Tab(text: 'Observações'),
                  Tab(text: 'Análises'),
                  Tab(text: 'Colheitas'),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadData)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _ResumoTab(
                      crop: _crop,
                      yields: _yields,
                      activities: _activities,
                      observations: _observations,
                      harvests: _harvests,
                      analyses: _analyses,
                    ),
                    _TerrenosTab(yields: _yields),
                    _RegaTab(usage: _irrigationUsage, planned: _irrigationPlanned),
                    _AtividadesTab(activities: _activities, fmt: _fmt),
                    _ObservacoesTab(observations: _observations, fmt: _fmt),
                    _AnalisesTab(
                      analyses: _analyses,
                      fmt: _fmt,
                      yields: _yields,
                      apiService: widget.apiService,
                      onReload: _loadData,
                    ),
                    _ColheitasTab(harvests: _harvests, fmt: _fmt),
                  ],
                ),
      // FAB "Nova colheita" só visível quando a tab Colheitas está activa
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          final hide = _isLoading ||
              _error != null ||
              _tabController.index != 6 ||
              _tabController.indexIsChanging;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: hide
                ? const SizedBox.shrink(key: ValueKey('hide'))
                : FloatingActionButton.extended(
                    key: const ValueKey('fab'),
                    onPressed: _addHarvest,
                    backgroundColor: AppTheme.primary,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Nova colheita',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// ── Resumo Tab ──────────────────────────────────────────────────

class _ResumoTab extends StatelessWidget {
  final Map<String, dynamic> crop;
  final List<Map<String, dynamic>> yields;
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> observations;
  final List<Map<String, dynamic>> harvests;
  final List<Map<String, dynamic>> analyses;

  const _ResumoTab({
    required this.crop,
    required this.yields,
    required this.activities,
    required this.observations,
    required this.harvests,
    required this.analyses,
  });

  @override
  Widget build(BuildContext context) {
    final varieties = (crop['varieties'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];

    // Stats
    double totalArea = 0;
    for (final y in yields) {
      totalArea += (y['yield_size'] as num?)?.toDouble() ?? 0;
    }
    final pendingAct = activities
        .where((a) => a['activity_status'] == 0)
        .length;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info da cultura
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop['crop_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                if (crop['crop_type'] != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(crop['crop_type'].toString(),
                        style: const TextStyle(fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 16),
                if (crop['production_cycle'] != null)
                  _InfoRow('Ciclo produtivo', crop['production_cycle']),
                if (crop['planting_season'] != null)
                  _InfoRow('Época de plantação', crop['planting_season']),
                if (crop['harvest_season'] != null)
                  _InfoRow('Época de colheita', crop['harvest_season']),
                if (crop['preferred_climate'] != null)
                  _InfoRow('Clima preferido', crop['preferred_climate']),
                if (crop['preferred_soil'] != null)
                  _InfoRow('Solo preferido', crop['preferred_soil']),
                if (crop['water_needs'] != null)
                  _InfoRow('Necessidades hídricas', crop['water_needs']),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: yields.length.toString(),
                  label: 'Terrenos',
                  color: const Color(0xFFD4EDDA),
                  textColor: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: totalArea % 1 == 0
                      ? totalArea.toInt().toString()
                      : totalArea.toStringAsFixed(1),
                  label: 'Hectares',
                  color: const Color(0xFFD4EDDA),
                  textColor: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: pendingAct.toString(),
                  label: 'Pendentes',
                  color: const Color(0xFFFFF3CD),
                  textColor: const Color(0xFFE65100),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: activities.length.toString(),
                  label: 'Atividades',
                  color: const Color(0xFFE8D5F5),
                  textColor: const Color(0xFF7B1FA2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: observations.length.toString(),
                  label: 'Observações',
                  color: const Color(0xFFCCE5FF),
                  textColor: const Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: harvests.length.toString(),
                  label: 'Colheitas',
                  color: const Color(0xFFD4EDDA),
                  textColor: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),

          // Inimigos comuns
          if (crop['common_enemies'] != null &&
              crop['common_enemies'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inimigos comuns',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text(crop['common_enemies'].toString(),
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textPrimary, height: 1.5)),
                ],
              ),
            ),
          ],

          // Variedades
          if (varieties.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Variedades (${varieties.length})',
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  ...varieties.map((v) => _VarietyRow(variety: v)),
                ],
              ),
            ),
          ],

          // Últimas colheitas
          if (harvests.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Últimas colheitas',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  ...harvests.take(5).map((h) => _HarvestRow(harvest: h)),
                ],
              ),
            ),
          ],

          // Notas
          if (crop['crop_observations'] != null &&
              crop['crop_observations'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notas',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text(crop['crop_observations'].toString(),
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textPrimary, height: 1.5)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Terrenos Tab ────────────────────────────────────────────────

class _TerrenosTab extends StatelessWidget {
  final List<Map<String, dynamic>> yields;
  const _TerrenosTab({required this.yields});

  @override
  Widget build(BuildContext context) {
    if (yields.isEmpty) {
      return const _EmptyView(
        icon: Icons.terrain_outlined,
        message: 'Sem terrenos associados a esta cultura.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: yields.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final y = yields[index];
        final landName = y['land_name']?.toString() ?? 'Terreno';
        final yieldName = y['yield_name']?.toString() ?? '';
        final method = y['yield_method']?.toString() ?? '';
        final size = (y['yield_size'] as num?)?.toDouble() ?? 0;
        final estimated = y['yield_estimated']?.toString();
        final unit = y['yield_unit']?.toString();
        final notes = y['yield_notes']?.toString();
        final landId = y['land_id'] as int?;

        return GestureDetector(
          onTap: landId != null
              ? () => context.go(
                  '/lands/$landId?name=${Uri.encodeComponent(landName)}')
              : null,
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.terrain,
                          color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(landName,
                              style: const TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          if (yieldName.isNotEmpty)
                            Text(yieldName,
                                style: const TextStyle(fontSize: 12,
                                    color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    if (landId != null)
                      const Icon(Icons.chevron_right,
                          color: AppTheme.textSecondary, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniChip(
                      '${size % 1 == 0 ? size.toInt() : size.toStringAsFixed(1)} ha',
                      const Color(0xFFD4EDDA),
                      const Color(0xFF2E7D32),
                    ),
                    if (method.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _MiniChip(method, const Color(0xFFE8D5F5),
                          const Color(0xFF7B1FA2)),
                    ],
                    if (estimated != null && estimated.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _MiniChip(
                        '$estimated${unit != null ? ' $unit' : ''}',
                        const Color(0xFFFFF3CD),
                        const Color(0xFFE65100),
                      ),
                    ],
                  ],
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(notes,
                      style: const TextStyle(fontSize: 12,
                          color: AppTheme.textSecondary, height: 1.4)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final yid = y['yield_id'] as int?;
                          if (yid == null) return;
                          final label = yieldName.isNotEmpty
                              ? yieldName
                              : landName;
                          context.push(
                            '/yields/$yid/harvests?name=${Uri.encodeComponent(label)}',
                          );
                        },
                        icon: const Icon(Icons.agriculture,
                            size: 18, color: AppTheme.primary),
                        label: const Text('Colheitas',
                            style: TextStyle(color: AppTheme.primary)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Rega Tab ───────────────────────────────────────────────────

class _RegaTab extends StatelessWidget {
  final List<Map<String, dynamic>> usage;
  final List<Map<String, dynamic>> planned;

  const _RegaTab({required this.usage, required this.planned});

  @override
  Widget build(BuildContext context) {
    if (usage.isEmpty && planned.isEmpty) {
      return const _EmptyView(
        icon: Icons.water_drop_outlined,
        message: 'Sem registos de rega associados a esta cultura.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (planned.isNotEmpty) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Próximas regas',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                ...planned.map((p) {
                  final dateStr = p['planned_date']?.toString() ?? '';
                  final timeStr = p['planned_time']?.toString() ?? '';
                  final volume = p['planned_volume_liters'];
                  final duration = p['planned_duration_min'];
                  String formatted = _formatDate(dateStr);
                  if (timeStr.isNotEmpty) {
                    formatted += ' · ${timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr}';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatted,
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              if (volume != null)
                                Text(
                                  '${double.tryParse(volume.toString())?.toStringAsFixed(0) ?? volume} L',
                                  style: const TextStyle(fontSize: 12,
                                      color: AppTheme.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        if (duration != null)
                          Text('$duration min',
                              style: const TextStyle(fontSize: 12,
                                  color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (usage.isNotEmpty)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Histórico de rega',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                ...usage.map((u) {
                  final dateStr = u['water_usage_usage_date']?.toString() ?? '';
                  final volume = u['water_usage_volume_liters'];
                  final cost = u['water_usage_cost'];
                  final notes = u['water_usage_notes']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop,
                            color: Color(0xFF1565C0), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatDate(dateStr),
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              if (notes.isNotEmpty)
                                Text(notes,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12,
                                        color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (volume != null)
                              Text(
                                '${double.tryParse(volume.toString())?.toStringAsFixed(0) ?? volume} L',
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary),
                              ),
                            if (cost != null)
                              Text(
                                '€${double.tryParse(cost.toString())?.toStringAsFixed(2) ?? cost}',
                                style: const TextStyle(fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  static String _formatDate(String dateStr) {
    try {
      return DateFormat('d MMM yyyy', 'pt_PT').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}

// ── Atividades Tab ──────────────────────────────────────────────

class _AtividadesTab extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final String Function(String?) fmt;
  const _AtividadesTab({required this.activities, required this.fmt});

  static const _typeLabels = {
    'treatment': 'Tratamento',
    'fertilization': 'Fertilização',
    'pruning': 'Poda',
    'irrigation': 'Rega',
    'harvest': 'Colheita',
    'inspection': 'Inspeção',
    'other': 'Outro',
  };

  static const _statusLabels = {0: 'Pendente', 1: 'Concluída', 2: 'Atrasada', 3: 'Cancelada'};
  static const _statusColors = {
    0: Color(0xFFFFA000),
    1: Color(0xFF2E7D32),
    2: Color(0xFFD32F2F),
    3: Color(0xFF757575),
  };

  static const _priorityColors = {
    1: Color(0xFF2E7D32),
    2: Color(0xFFFFA000),
    3: Color(0xFFD32F2F),
  };

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const _EmptyView(
        icon: Icons.assignment_outlined,
        message: 'Sem atividades associadas a esta cultura.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final a = activities[index];
        final name = a['activity_name']?.toString() ?? 'Atividade';
        final type = a['activity_type']?.toString() ?? '';
        final status = a['activity_status'] as int? ?? 0;
        final priority = a['activity_priority'] as int? ?? 1;
        final datePlanned = a['activity_date_planned']?.toString();
        final dateDone = a['activity_date_done']?.toString();

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              // Priority bar
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: _priorityColors[priority] ?? AppTheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _typeLabels[type] ?? type,
                            style: const TextStyle(fontSize: 12,
                                color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          const Text('·', style: TextStyle(
                              color: AppTheme.textSecondary)),
                          const SizedBox(width: 8),
                          Text(
                            dateDone != null ? fmt(dateDone) : fmt(datePlanned),
                            style: const TextStyle(fontSize: 12,
                                color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Status badge
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_statusColors[status] ?? AppTheme.textSecondary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabels[status] ?? '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColors[status] ?? AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Observações Tab ─────────────────────────────────────────────

class _ObservacoesTab extends StatelessWidget {
  final List<Map<String, dynamic>> observations;
  final String Function(String?) fmt;
  const _ObservacoesTab({required this.observations, required this.fmt});

  static const _pragaColors = {
    'praga': Color(0xFFD32F2F),
    'fungo': Color(0xFF7B1FA2),
    'virus': Color(0xFFE65100),
    'bacteria': Color(0xFF0D47A1),
    'outro': Color(0xFF757575),
  };

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) {
      return const _EmptyView(
        icon: Icons.visibility_outlined,
        message: 'Sem observações associadas a esta cultura.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: observations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final o = observations[index];
        final text = o['observation_text']?.toString() ?? '';
        final praga = o['praga_fungo']?.toString();
        final estado = o['estado_fenologico']?.toString();
        final date = o['created_at']?.toString();

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ObservationDetailScreen(observation: o),
            ),
          ),
          child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text.length > 80 ? '${text.substring(0, 80)}...' : text,
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (praga != null && praga.isNotEmpty)
                    _MiniChip(
                      praga,
                      (_pragaColors[praga] ?? AppTheme.textSecondary)
                          .withValues(alpha: 0.12),
                      _pragaColors[praga] ?? AppTheme.textSecondary,
                    ),
                  if (estado != null && estado.isNotEmpty)
                    _MiniChip(estado, const Color(0xFFD4EDDA),
                        const Color(0xFF2E7D32)),
                  if (date != null)
                    _MiniChip(fmt(date), AppTheme.background,
                        AppTheme.textSecondary),
                ],
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

// ── Análises Tab ────────────────────────────────────────────────

class _AnalisesTab extends StatelessWidget {
  final List<Map<String, dynamic>> analyses;
  final String Function(String?) fmt;
  final List<Map<String, dynamic>> yields;
  final ApiService apiService;
  final VoidCallback onReload;

  const _AnalisesTab({
    required this.analyses,
    required this.fmt,
    required this.yields,
    required this.apiService,
    required this.onReload,
  });

  Future<void> _openAddDialog(BuildContext context) async {
    if (yields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            'Esta cultura não tem terrenos ativos. Adicione um yield primeiro.')),
      );
      return;
    }

    int? targetYieldId;
    if (yields.length == 1) {
      targetYieldId = yields.first['yield_id'] as int?;
    } else {
      targetYieldId = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Selecione o terreno'),
          children: yields.map((y) {
            final name = y['yield_name']?.toString() ?? 'Cultura';
            final land = y['land_name']?.toString() ?? '';
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, y['yield_id'] as int?),
              child: Text(land.isNotEmpty ? '$name — $land' : name),
            );
          }).toList(),
        ),
      );
    }

    if (targetYieldId == null || !context.mounted) return;

    final created = await AddAnalysisDialog.show(
      context: context,
      apiService: apiService,
      kind: AnalysisKind.yield_,
      targetId: targetYieldId,
    );
    if (created == true) {
      onReload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Análise adicionada.')),
        );
      }
    }
  }

  static const _nutrients = [
    ('N Total', 'yield_analysis_nitrogen_total'),
    ('P (Fósforo)', 'yield_analysis_phosphorus'),
    ('K (Potássio)', 'yield_analysis_potassium'),
    ('Ca (Cálcio)', 'yield_analysis_calcium'),
    ('Mg (Magnésio)', 'yield_analysis_magnesium'),
    ('Fe (Ferro)', 'yield_analysis_iron'),
    ('Mn (Manganês)', 'yield_analysis_manganese'),
    ('B (Boro)', 'yield_analysis_boro'),
    ('Zn (Zinco)', 'yield_analysis_zinc'),
  ];

  Widget _fab(BuildContext context) => Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton.extended(
          onPressed: () => _openAddDialog(context),
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Adicionar',
              style: TextStyle(color: Colors.white)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (analyses.isEmpty) {
      return Stack(
        children: [
          const _EmptyView(
            icon: Icons.science_outlined,
            message: 'Sem análises foliares associadas a esta cultura.',
          ),
          _fab(context),
        ],
      );
    }

    return Stack(
      children: [
        ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: analyses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final a = analyses[index];
        final date = a['yield_analysis_date']?.toString();
        final sample = a['yield_analysis_sample']?.toString() ?? '';
        final pdfUrl = a['yield_analysis_file']?.toString();

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8D5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.science,
                        color: Color(0xFF7B1FA2), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Análise foliar',
                            style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                        Text(
                          '${fmt(date)}${sample.isNotEmpty ? ' · $sample' : ''}',
                          style: const TextStyle(fontSize: 12,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gerar PDF da análise',
                    onPressed: () => openProtectedPdf(
                      context,
                      path: AppConstants.foliarAnalysisPdf(
                          a['yield_analysis_id'] as int),
                      filename:
                          'analise_foliar_${a['yield_analysis_id']}.pdf',
                    ),
                    icon: const Icon(Icons.picture_as_pdf,
                        color: Color(0xFFD32F2F)),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  if (pdfUrl != null && pdfUrl.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _openPdf(context, pdfUrl),
                      icon: const Icon(Icons.attach_file,
                          color: AppTheme.textSecondary),
                      tooltip: 'Abrir PDF anexado',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Nutrient grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _nutrients.where((n) {
                  final v = a[n.$2]?.toString();
                  return v != null && v.isNotEmpty;
                }).map((n) {
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 72) / 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.$1,
                            style: const TextStyle(fontSize: 10,
                                color: AppTheme.textSecondary)),
                        Text(a[n.$2].toString(),
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
        ),
        _fab(context),
      ],
    );
  }

  static Future<void> _openPdf(BuildContext context, String url) async {
    final fullUrl = _resolveMediaUrl(url);
    await openRemotePdf(
      context,
      url: fullUrl,
      filename: url.split('/').last,
    );
  }

  /// Constrói um URL absoluto para um ficheiro guardado em `MEDIA_ROOT`.
  /// O Django serve media em `/media/...` (na raiz do servidor, não sob `/api/`).
  static String _resolveMediaUrl(String path) {
    if (path.startsWith('http')) return path;
    var origin = AppConstants.baseUrl;
    if (origin.endsWith('/api')) {
      origin = origin.substring(0, origin.length - 4);
    } else if (origin.endsWith('/api/')) {
      origin = origin.substring(0, origin.length - 5);
    }
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('media/')) {
      return '$origin/$cleanPath';
    }
    return '$origin/media/$cleanPath';
  }
}

// ── Shared Widgets ──────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: const TextStyle(fontSize: 13,
                    color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value?.toString() ?? '—',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color textColor;
  const _StatCard({
    required this.value, required this.label,
    required this.color, required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: textColor)),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _MiniChip(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: fg)),
    );
  }
}

class _VarietyRow extends StatelessWidget {
  final Map<String, dynamic> variety;
  const _VarietyRow({required this.variety});

  @override
  Widget build(BuildContext context) {
    final name = variety['variety_name']?.toString() ?? '';
    final desc = variety['variety_description']?.toString();
    final strong = variety['strong_points']?.toString();
    final weak = variety['weak_points']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc,
                style: const TextStyle(fontSize: 12,
                    color: AppTheme.textSecondary)),
          ],
          if (strong != null && strong.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 14, color: Color(0xFF2E7D32)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(strong,
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF2E7D32))),
                ),
              ],
            ),
          ],
          if (weak != null && weak.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.remove_circle_outline,
                    size: 14, color: Color(0xFFD32F2F)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(weak,
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFFD32F2F))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HarvestRow extends StatelessWidget {
  final Map<String, dynamic> harvest;
  const _HarvestRow({required this.harvest});

  @override
  Widget build(BuildContext context) {
    final name = harvest['harvest_name']?.toString() ?? 'Colheita';
    final date = harvest['harvest_date']?.toString() ?? '';
    final harvested = harvest['harvest_harvested'];
    final unit = harvest['unit_measurement']?.toString() ?? 'KG';
    final cost = harvest['total_harvest_cost'];

    String dateStr = date;
    try {
      final d = DateTime.parse(date);
      const m = ['Jan','Fev','Mar','Abr','Mai','Jun',
                  'Jul','Ago','Set','Out','Nov','Dez'];
      dateStr = '${d.day} ${m[d.month - 1]}, ${d.year}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                Text(dateStr,
                    style: const TextStyle(fontSize: 11,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (harvested != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$harvested $unit',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          if (cost != null) ...[
            const SizedBox(width: 8),
            Text('$cost€',
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56,
                color: AppTheme.textSecondary.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14,
                    color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Colheitas Tab ───────────────────────────────────────────────

class _ColheitasTab extends StatelessWidget {
  final List<Map<String, dynamic>> harvests;
  final String Function(String?) fmt;

  const _ColheitasTab({required this.harvests, required this.fmt});

  // Ordena por data e filtra entradas com quantidade válida para o gráfico
  List<Map<String, dynamic>> get _sorted {
    final list = harvests.toList()
      ..sort((a, b) {
        final aDate = a['harvest_date']?.toString() ?? '';
        final bDate = b['harvest_date']?.toString() ?? '';
        return aDate.compareTo(bDate);
      });
    return list;
  }

  List<Map<String, dynamic>> get _chartData =>
      _sorted.where((h) {
        final v = double.tryParse(h['harvest_harvested']?.toString() ?? '');
        return v != null && v > 0;
      }).toList();

  String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (harvests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture_outlined, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Sem colheitas registadas',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    final chart = _chartData;
    final unit = harvests.isNotEmpty
        ? (harvests.last['unit_measurement']?.toString() ?? 'KG')
        : 'KG';
    final maxY = chart.isEmpty
        ? 1.0
        : chart
            .map((h) => double.tryParse(h['harvest_harvested']?.toString() ?? '0') ?? 0)
            .reduce((a, b) => a > b ? a : b) *
            1.2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Gráfico de evolução ──────────────────────────────
        if (chart.length >= 2) ...[
          _SectionTitle(title: 'Evolução da colheita ($unit)'),
          const SizedBox(height: 8),
          Container(
            height: 200,
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.primary.withValues(alpha: 0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final h = chart[groupIndex];
                      final qty = rod.toY.toStringAsFixed(1);
                      final date = _shortDate(h['harvest_date']?.toString());
                      return BarTooltipItem(
                        '$qty $unit\n$date',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == 0) {
                          return Text(
                            value == 0 ? '0' : value.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= chart.length) return const SizedBox.shrink();
                        // Mostrar só o primeiro, o último e cada 3
                        if (i != 0 && i != chart.length - 1 && i % 3 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _shortDate(chart[i]['harvest_date']?.toString()),
                            style: const TextStyle(
                                fontSize: 9, color: AppTheme.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.divider,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(chart.length, (i) {
                  final qty =
                      double.tryParse(chart[i]['harvest_harvested']?.toString() ?? '0') ?? 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: qty,
                        color: AppTheme.primary,
                        width: chart.length > 12 ? 8 : 14,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppTheme.divider.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Totais rápidos ───────────────────────────────────
        _SectionTitle(title: 'Resumo'),
        const SizedBox(height: 8),
        _HarvestSummaryRow(harvests: harvests, unit: unit),
        const SizedBox(height: 24),

        // ── Lista de colheitas ───────────────────────────────
        _SectionTitle(title: 'Histórico (${_sorted.length})'),
        const SizedBox(height: 8),
        ..._sorted.map((h) => _HarvestCard(harvest: h, fmt: fmt)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary),
      );
}

class _HarvestSummaryRow extends StatelessWidget {
  final List<Map<String, dynamic>> harvests;
  final String unit;
  const _HarvestSummaryRow({required this.harvests, required this.unit});

  @override
  Widget build(BuildContext context) {
    double total = 0;
    double cost = 0;
    for (final h in harvests) {
      total += double.tryParse(h['harvest_harvested']?.toString() ?? '') ?? 0;
      cost  += double.tryParse(h['total_harvest_cost']?.toString() ?? '') ?? 0;
    }
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Total colhido',
            value: '${total.toStringAsFixed(1)} $unit',
            icon: Icons.agriculture_outlined,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Custo total',
            value: cost > 0 ? '€${cost.toStringAsFixed(2)}' : '—',
            icon: Icons.euro_outlined,
            color: const Color(0xFF7B1FA2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'N.º colheitas',
            value: '${harvests.length}',
            icon: Icons.format_list_numbered,
            color: const Color(0xFFF57C00),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      );
}

class _HarvestCard extends StatelessWidget {
  final Map<String, dynamic> harvest;
  final String Function(String?) fmt;
  const _HarvestCard({required this.harvest, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final name      = harvest['harvest_name']?.toString() ?? 'Colheita';
    final date      = harvest['harvest_date']?.toString();
    final qty       = harvest['harvest_harvested'];
    final unit      = harvest['unit_measurement']?.toString() ?? 'KG';
    final cost      = harvest['total_harvest_cost'];
    final costPerKg = harvest['harvest_cost_per_kg'];
    final kgPerH    = harvest['harvest_kg_per_hour'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.agriculture_outlined,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
              Text(fmt(date),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          if (qty != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _InfoChip(
                  label: 'Quantidade',
                  value: '${double.tryParse(qty.toString())?.toStringAsFixed(1) ?? qty} $unit',
                  color: AppTheme.primary,
                ),
                if (cost != null)
                  _InfoChip(
                    label: 'Custo total',
                    value: '€${double.tryParse(cost.toString())?.toStringAsFixed(2) ?? cost}',
                    color: const Color(0xFF7B1FA2),
                  ),
                if (costPerKg != null)
                  _InfoChip(
                    label: '€/kg',
                    value: '€${double.tryParse(costPerKg.toString())?.toStringAsFixed(3) ?? costPerKg}',
                    color: const Color(0xFF1565C0),
                  ),
                if (kgPerH != null)
                  _InfoChip(
                    label: 'kg/h',
                    value: double.tryParse(kgPerH.toString())?.toStringAsFixed(1) ?? kgPerH.toString(),
                    color: const Color(0xFFF57C00),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      );
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
          Icon(Icons.error_outline, size: 48,
              color: AppTheme.error.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry,
              child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
