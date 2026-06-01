import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/land_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/providers/sensor_provider.dart';
import '../../../core/models/sensor_association_model.dart';
import '../../../core/models/sensor_reading_model.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/add_analysis_dialog.dart';
import '../../observations/screens/observation_detail_screen.dart';
import '../../../shared/widgets/pdf_launcher.dart';
import '../../../shared/utils/safe_back.dart';
import '../../../core/services/local_database.dart';

class LandDetailScreen extends StatefulWidget {
  final int landId;
  final String landName;
  final ApiService apiService;

  const LandDetailScreen({
    super.key,
    required this.landId,
    required this.landName,
    required this.apiService,
  });

  @override
  State<LandDetailScreen> createState() => _LandDetailScreenState();
}

class _LandDetailScreenState extends State<LandDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  LandModel? _land;
  Map<String, dynamic> _landRaw = {};
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _observations = [];
  List<Map<String, dynamic>> _irrigationUsage = [];
  List<Map<String, dynamic>> _irrigationPlanned = [];
  List<Map<String, dynamic>> _yields = [];
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
    final api = widget.apiService;

    // 1) Chamada crítica: detalhe do terreno. Se falhar, fallback para cache.
    Map<String, dynamic>? landData;
    try {
      final r = await api
          .get(AppConstants.landDetail(widget.landId))
          .timeout(const Duration(seconds: 15));
      landData = r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('[LandDetail] landDetail FAILED: ${e.response?.statusCode} ${e.response?.data}');
      await _loadFromCacheWithMessage(statusCode: e.response?.statusCode);
      return;
    } catch (e) {
      debugPrint('[LandDetail] landDetail FAILED (non-dio): $e');
      await _loadFromCacheWithMessage();
      return;
    }

    // 2) Chamadas secundárias: tolerantes a falhas.
    List<dynamic> actData = [];
    List<dynamic> obsData = [];
    Map<String, dynamic> irrData = {};

    try {
      final r = await api.get(AppConstants.activities,
          params: {'land_id': widget.landId.toString()});
      actData = ApiService.extractResults(r.data);
    } on DioException catch (e) {
      debugPrint('[LandDetail] activities failed: ${e.response?.statusCode} ${e.response?.data}');
    } catch (e) {
      debugPrint('[LandDetail] activities failed: $e');
    }

    try {
      final r = await api.get(AppConstants.observations,
          params: {'land_id': widget.landId.toString()});
      obsData = ApiService.extractResults(r.data);
    } on DioException catch (e) {
      debugPrint('[LandDetail] observations failed: ${e.response?.statusCode} ${e.response?.data}');
    } catch (e) {
      debugPrint('[LandDetail] observations failed: $e');
    }

    try {
      final r = await api.get(AppConstants.landIrrigation(widget.landId));
      irrData = r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('[LandDetail] irrigation failed: ${e.response?.statusCode} ${e.response?.data}');
    } catch (e) {
      debugPrint('[LandDetail] irrigation failed: $e');
    }

    List<dynamic> yieldsData = [];
    try {
      final r = await api.get(
        AppConstants.yields,
        params: {'land_id': widget.landId.toString()},
      );
      yieldsData = ApiService.extractResults(r.data);
    } on DioException catch (e) {
      debugPrint('[LandDetail] yields failed: ${e.response?.statusCode} ${e.response?.data}');
    } catch (e) {
      debugPrint('[LandDetail] yields failed: $e');
    }

    await LocalDatabase.saveLandDetail(widget.landId, {
      'land': landData,
      'activities': actData,
      'observations': obsData,
      'irrigation': irrData,
      'yields': yieldsData,
    });

    if (!mounted) return;
    final land = landData;
    setState(() {
      _land              = LandModel.fromJson(land);
      _landRaw           = land;
      _activities        = actData.cast<Map<String, dynamic>>();
      _observations      = obsData.cast<Map<String, dynamic>>();
      _irrigationUsage   = (irrData['usage'] as List? ?? []).cast<Map<String, dynamic>>();
      _irrigationPlanned = (irrData['planned'] as List? ?? []).cast<Map<String, dynamic>>();
      _yields            = yieldsData.cast<Map<String, dynamic>>();
      _isLoading         = false;
    });
  }

  Future<void> _loadFromCacheWithMessage({int? statusCode}) async {
    final cached = await LocalDatabase.getLandDetail(widget.landId);
    if (!mounted) return;
    if (cached != null) {
      final landData = cached['land'] as Map<String, dynamic>;
      final irrData  = cached['irrigation'] as Map<String, dynamic>? ?? {};
      setState(() {
        _land              = LandModel.fromJson(landData);
        _landRaw           = landData;
        _activities        = (cached['activities'] as List? ?? []).cast<Map<String, dynamic>>();
        _observations      = (cached['observations'] as List? ?? []).cast<Map<String, dynamic>>();
        _irrigationUsage   = (irrData['usage'] as List? ?? []).cast<Map<String, dynamic>>();
        _irrigationPlanned = (irrData['planned'] as List? ?? []).cast<Map<String, dynamic>>();
        _yields            = (cached['yields'] as List? ?? []).cast<Map<String, dynamic>>();
        _isLoading         = false;
      });
    } else {
      setState(() {
        _error = statusCode == 403
            ? 'Sem acesso a este terreno.'
            : statusCode == 401
                ? 'Sessão expirada. Volta a entrar.'
                : statusCode == 404
                    ? 'Terreno não encontrado.'
                    : 'Sem ligação e sem dados guardados${statusCode != null ? " ($statusCode)" : ""}.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.landName),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _loadData),
        ],
        bottom: _isLoading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Sensores'),
                  Tab(text: 'Rega'),
                  Tab(text: 'Atividades'),
                  Tab(text: 'Observações'),
                  Tab(text: 'Análises'),
                  Tab(text: 'Culturas'),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadData)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(
                        land: _land!, landRaw: _landRaw,
                        activitiesCount: _activities.length,
                        observationsCount: _observations.length,
                        apiService: widget.apiService,
                        onReload: _loadData,
                        onNavigateToTab: (i) =>
                            _tabController.animateTo(i)),
                    _BackendLandSensorsTab(landId: widget.landId, land: _land!),
                    _RegaTab(usage: _irrigationUsage, planned: _irrigationPlanned),
                    _AtividadesTab(activities: _activities),
                    _ObservacoesTab(observations: _observations),
                    _AnalisesTab(
                      analyses: (_landRaw['soil_analyses'] as List? ?? [])
                          .cast<Map<String, dynamic>>(),
                      landId: widget.landId,
                      apiService: widget.apiService,
                      onReload: _loadData,
                    ),
                    _CulturasTab(yields: _yields),
                  ],
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ═══════════════════════════════════════════════════════════════

class _OverviewTab extends StatefulWidget {
  final LandModel land;
  final Map<String, dynamic> landRaw;
  final int activitiesCount;
  final int observationsCount;
  final ApiService apiService;
  final VoidCallback onReload;
  final ValueChanged<int>? onNavigateToTab;

  const _OverviewTab({
    required this.land,
    required this.landRaw,
    required this.activitiesCount,
    required this.observationsCount,
    required this.apiService,
    required this.onReload,
    this.onNavigateToTab,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  static const _mapboxToken =
      'pk.eyJ1IjoiZGlvZ28yNiIsImEiOiJjbW11c3hkcWQxdGg4MnByMjk4dGxwMGRhIn0.fPZGRiR_C_d2JKuxExKBhw';

  bool _fetchingMapbox = false;
  String? _fetchedElevation;
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _sunExposureCtrl;
  late TextEditingController _inclinationCtrl;
  late TextEditingController _elevationCtrl;
  late TextEditingController _levelsCtrl;
  late TextEditingController _notesCtrl;
  late bool _hasWater;

  @override
  void initState() {
    super.initState();
    _sunExposureCtrl = TextEditingController(text: widget.land.landSunExposure ?? '');
    _inclinationCtrl = TextEditingController(text: widget.land.landInclination ?? '');
    _elevationCtrl = TextEditingController(text: widget.land.landElevation ?? '');
    _levelsCtrl = TextEditingController(text: widget.land.landLevels ?? '');
    _notesCtrl = TextEditingController(text: widget.land.landNotes ?? '');
    _hasWater = widget.land.landWater == 1;
    _tryFetchMapboxData();
  }

  @override
  void dispose() {
    _sunExposureCtrl.dispose();
    _inclinationCtrl.dispose();
    _elevationCtrl.dispose();
    _levelsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryFetchMapboxData() async {
    final lat = widget.land.effectiveLatitude;
    final lng = widget.land.effectiveLongitude;
    if (lat == null || lng == null) return;

    // Só buscar se campos vazios
    if ((widget.land.landElevation ?? '').isNotEmpty) return;

    setState(() => _fetchingMapbox = true);
    try {
      final dio = Dio();
      final url =
          'https://api.mapbox.com/v4/mapbox.mapbox-terrain-v2/tilequery/$lng,$lat.json?access_token=$_mapboxToken';
      final response = await dio.get(url);
      final features = response.data['features'] as List? ?? [];

      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>? ?? {};
        final layer = props['tilequery']?['layer']?.toString() ?? '';

        if (layer == 'contour') {
          final ele = props['ele'];
          if (ele != null) {
            _fetchedElevation = '${ele}m';
            if (_elevationCtrl.text.isEmpty) {
              _elevationCtrl.text = _fetchedElevation!;
            }
          }
        }
      }
    } catch (_) {
      // Mapbox indisponível — não é bloqueante
    } finally {
      if (mounted) setState(() => _fetchingMapbox = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    final clientUuid = UuidHelper.v4();
    final payload = <String, dynamic>{
      'land_id':          widget.land.landId,
      'client_uuid':      clientUuid,
      'land_sun_exposure': _sunExposureCtrl.text.trim(),
      'land_inclination':  _inclinationCtrl.text.trim(),
      'land_elevation':    _elevationCtrl.text.trim(),
      'land_levels':       _levelsCtrl.text.trim(),
      'land_water':        _hasWater ? 1 : 0,
      'land_notes':        _notesCtrl.text.trim(),
    };

    final result = await OfflineMutation.run(
      apiCall: () => widget.apiService.patch(
        AppConstants.landDetail(widget.land.landId),
        data: {
          'land_sun_exposure': _sunExposureCtrl.text.trim(),
          'land_inclination':  _inclinationCtrl.text.trim(),
          'land_elevation':    _elevationCtrl.text.trim(),
          'land_levels':       _levelsCtrl.text.trim(),
          'land_water':        _hasWater ? 1 : 0,
          'land_notes':        _notesCtrl.text.trim(),
        },
      ),
      operationType: 'update_land',
      queueData: payload,
    );

    if (!mounted) return;
    setState(() { _isSaving = false; _isEditing = false; });

    if (result.queued) {
      context.read<SyncProvider>().refreshCounts();
    }

    widget.onReload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.queued
            ? 'Alterações guardadas offline — sincroniza quando voltares online.'
            : result.success
                ? 'Dados atualizados.'
                : (result.errorMessage ?? 'Erro ao guardar alterações.')),
        backgroundColor: result.queued
            ? const Color(0xFF7B1FA2)
            : result.success
                ? null
                : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info principal com botão editar
        _Card(
          title: 'Informação',
          trailing: _isSaving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
              : _isEditing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isEditing = false),
                          child: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _saveChanges,
                          child: const Icon(Icons.check, size: 20, color: AppTheme.primary),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: () => setState(() => _isEditing = true),
                      child: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                    ),
          child: _isEditing ? _buildEditForm() : _buildInfoRows(),
        ),

        if (_fetchingMapbox) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('A obter dados do Mapbox...',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7))),
            ],
          ),
        ],

        const SizedBox(height: 12),

        // Resumo rápido — cards clicáveis que navegam para a tab respectiva
        Row(
          children: [
            Expanded(child: _StatCard(
                label: 'Atividades', value: '${widget.activitiesCount}',
                icon: Icons.checklist, color: AppTheme.primary,
                onTap: () => widget.onNavigateToTab?.call(3))),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
                label: 'Observações', value: '${widget.observationsCount}',
                icon: Icons.visibility_outlined, color: const Color(0xFFF57C00),
                onTap: () => widget.onNavigateToTab?.call(4))),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
                label: 'Análises',
                value: '${(widget.landRaw['soil_analyses'] as List? ?? []).length}',
                icon: Icons.science_outlined, color: const Color(0xFF1565C0),
                onTap: () => widget.onNavigateToTab?.call(5))),
          ],
        ),

        const SizedBox(height: 12),

        // Notas (apenas em modo leitura — em edição está no formulário)
        if (!_isEditing && widget.land.landNotes != null && widget.land.landNotes!.isNotEmpty)
          _Card(
            title: 'Notas',
            child: Text(widget.land.landNotes!,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
          ),
      ],
    );
  }

  Widget _buildInfoRows() {
    return Column(
      children: [
        _InfoRow(icon: Icons.straighten, label: 'Área',
            value: widget.land.landSize != null
                ? '${widget.land.landSize!.toStringAsFixed(2)} ha'
                : '—'),
        _InfoRow(icon: Icons.place_outlined, label: 'Localização',
            value: widget.land.landLocation ?? '—'),
        _InfoRow(icon: Icons.wb_sunny_outlined, label: 'Exposição solar',
            value: widget.land.landSunExposure ?? '—'),
        _InfoRow(icon: Icons.landscape_outlined, label: 'Inclinação',
            value: widget.land.landInclination ?? '—'),
        _InfoRow(icon: Icons.height, label: 'Elevação',
            value: widget.land.landElevation ?? '—'),
        _InfoRow(icon: Icons.stairs_outlined, label: 'Patamares',
            value: (widget.land.landLevels ?? '').isEmpty
                ? '—'
                : widget.land.landLevels!),
        _InfoRow(icon: Icons.water_drop_outlined, label: 'Ponto de água',
            value: widget.land.landWater == 1 ? 'Sim' : 'Não'),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _EditRow(label: 'Exposição solar', controller: _sunExposureCtrl,
            hint: 'Ex: Sul, Norte, Nascente...'),
        const SizedBox(height: 10),
        _EditRow(label: 'Inclinação', controller: _inclinationCtrl,
            hint: 'Ex: Plano, Ligeira, Acentuada...'),
        const SizedBox(height: 10),
        _EditRow(label: 'Elevação', controller: _elevationCtrl,
            hint: 'Ex: 120m'),
        const SizedBox(height: 10),
        _EditRow(label: 'Patamares', controller: _levelsCtrl,
            hint: 'Ex: 3 patamares'),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.water_drop_outlined, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            const Text('Ponto de água', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const Spacer(),
            Switch(
              value: _hasWater,
              onChanged: (v) => setState(() => _hasWater = v),
              activeColor: AppTheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notas',
            hintText: 'Notas adicionais sobre o terreno...',
          ),
          maxLines: 3,
          minLines: 2,
        ),
      ],
    );
  }
}

class _EditRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _EditRow({required this.label, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2 — REGA
// ═══════════════════════════════════════════════════════════════

class _RegaTab extends StatelessWidget {
  final List<Map<String, dynamic>> usage;
  final List<Map<String, dynamic>> planned;

  const _RegaTab({required this.usage, required this.planned});

  @override
  Widget build(BuildContext context) {
    if (usage.isEmpty && planned.isEmpty) {
      return const Center(
        child: Text('Sem registos de rega',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Próximas regas
        if (planned.isNotEmpty) ...[
          _Card(
            title: 'Próximas regas',
            child: Column(
              children: planned.map((p) {
                final dateStr = p['planned_date']?.toString() ?? '';
                final timeStr = p['planned_time']?.toString() ?? '';
                final volume  = p['planned_volume_liters'];
                final duration = p['planned_duration_min'];
                String formatted = _formatDate(dateStr);
                if (timeStr.isNotEmpty) formatted += ' · ${timeStr.substring(0, 5)}';

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
                                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            if (volume != null)
                              Text('${double.tryParse(volume.toString())?.toStringAsFixed(0) ?? volume} L',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      if (duration != null)
                        Text('$duration min',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Histórico
        if (usage.isNotEmpty)
          _Card(
            title: 'Histórico de rega',
            child: Column(
              children: usage.map((u) {
                final dateStr = u['water_usage_usage_date']?.toString() ?? '';
                final volume  = u['water_usage_volume_liters'];
                final cost    = u['water_usage_cost'];
                final notes   = u['water_usage_notes']?.toString() ?? '';

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
                      const Icon(Icons.water_drop, color: Color(0xFF1565C0), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatDate(dateStr),
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            if (notes.isNotEmpty)
                              Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (volume != null)
                            Text('${double.tryParse(volume.toString())?.toStringAsFixed(0) ?? volume} L',
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          if (cost != null)
                            Text('€${double.tryParse(cost.toString())?.toStringAsFixed(2) ?? cost}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
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

// ═══════════════════════════════════════════════════════════════
// TAB 3 — ATIVIDADES
// ═══════════════════════════════════════════════════════════════

class _AtividadesTab extends StatefulWidget {
  final List<Map<String, dynamic>> activities;
  const _AtividadesTab({required this.activities});

  @override
  State<_AtividadesTab> createState() => _AtividadesTabState();
}

class _AtividadesTabState extends State<_AtividadesTab> {
  static const Map<String, String> _typeLabels = {
    'irrigation': 'Rega', 'fertilization': 'Fertilização',
    'pruning': 'Poda', 'harvest': 'Colheita',
    'treatment': 'Tratamento', 'inspection': 'Inspeção',
    'maintenance': 'Manutenção', 'other': 'Outra',
  };

  static const Map<int, String> _statusLabels = {0: 'Pendente', 1: 'Concluída', 2: 'Atrasada', 3: 'Cancelada'};
  static const Map<int, Color> _statusColors = {
    0: Color(0xFFFFA726), 1: AppTheme.primary, 2: AppTheme.error, 3: AppTheme.textSecondary,
  };

  static const Map<int, Color> _priorityColors = {
    1: AppTheme.primary, 2: Color(0xFFFFA726), 3: AppTheme.error,
  };

  // Ordenação: true = mais recente primeiro, false = mais antigo primeiro
  bool _sortNewestFirst = true;
  // Filtro de status: null = todos, 0 = pendente, 1 = concluída
  int? _statusFilter;

  List<Map<String, dynamic>> get _filtered {
    var list = widget.activities.toList();

    // Filtrar por status
    if (_statusFilter != null) {
      list = list.where((a) => (a['activity_status'] as int? ?? 0) == _statusFilter).toList();
    }

    // Ordenar por data
    list.sort((a, b) {
      final aDate = a['activity_date_planned']?.toString() ?? '';
      final bDate = b['activity_date_planned']?.toString() ?? '';
      return _sortNewestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) {
      return const Center(
        child: Text('Sem atividades neste terreno',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final list = _filtered;

    return Column(
      children: [
        // Barra de filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              // Ordenação
              GestureDetector(
                onTap: () => setState(() => _sortNewestFirst = !_sortNewestFirst),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortNewestFirst ? 'Recentes' : 'Antigas',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filtros de status
              _StatusChip(
                label: 'Todas',
                isActive: _statusFilter == null,
                onTap: () => setState(() => _statusFilter = null),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                label: 'Pendentes',
                isActive: _statusFilter == 0,
                color: const Color(0xFFFFA726),
                onTap: () => setState(() => _statusFilter = _statusFilter == 0 ? null : 0),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                label: 'Concluídas',
                isActive: _statusFilter == 1,
                color: AppTheme.primary,
                onTap: () => setState(() => _statusFilter = _statusFilter == 1 ? null : 1),
              ),
            ],
          ),
          ),
        ),

        // Lista
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('Sem atividades com este filtro',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final a = list[i];
                    final name = a['activity_name']?.toString() ?? '';
                    final type = a['activity_type']?.toString() ?? '';
                    final status = a['activity_status'] as int? ?? 0;
                    final priority = a['activity_priority'] as int? ?? 1;
                    final dateStr = a['activity_date_planned']?.toString() ?? '';
                    final activityId = a['activity_id'] as int?;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: activityId == null
                          ? null
                          : () => ctx.go('/activities/$activityId'),
                      child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4, height: 48,
                            decoration: BoxDecoration(
                              color: _priorityColors[priority] ?? AppTheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.isNotEmpty ? name : (_typeLabels[type] ?? type),
                                    style: const TextStyle(fontSize: 14,
                                        fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 2),
                                Text('${_typeLabels[type] ?? type} · ${_formatDate(dateStr)}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_statusColors[status] ?? AppTheme.textSecondary).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(_statusLabels[status] ?? 'Pendente',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: _statusColors[status] ?? AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                    ),
                    );
                  },
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

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.isActive,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? chipColor.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? chipColor : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? chipColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 4 — OBSERVAÇÕES
// ═══════════════════════════════════════════════════════════════

class _ObservacoesTab extends StatelessWidget {
  final List<Map<String, dynamic>> observations;
  const _ObservacoesTab({required this.observations});

  static const Map<String, String> _pragaLabels = {
    'praga': 'Praga', 'fungo': 'Fungo', 'virus': 'Vírus',
    'bacteria': 'Bactéria', 'outro': 'Outro',
  };

  static const Map<String, Color> _pragaColors = {
    'praga': AppTheme.error, 'fungo': Color(0xFF7B1FA2),
    'virus': Color(0xFFF57C00), 'bacteria': Color(0xFF1565C0),
    'outro': AppTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) {
      return const Center(
        child: Text('Sem observações neste terreno',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: observations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final obs = observations[i];
        final text = obs['observation_text']?.toString() ?? '';
        final dateStr = obs['created_at']?.toString() ?? '';
        final praga = obs['praga_fungo']?.toString() ?? '';
        final fenologico = obs['estado_fenologico']?.toString() ?? '';

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => ObservationDetailScreen(observation: obs),
            ),
          ),
          child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: data + badges
              Row(
                children: [
                  Text(_formatDate(dateStr),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const Spacer(),
                  if (praga.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_pragaColors[praga] ?? AppTheme.textSecondary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_pragaLabels[praga] ?? praga,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: _pragaColors[praga] ?? AppTheme.textSecondary)),
                    ),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(text,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
                    maxLines: 4, overflow: TextOverflow.ellipsis),
              ],
              if (fenologico.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.eco_outlined, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(fenologico,
                        style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
                  ],
                ),
              ],
            ],
          ),
        ),
        );
      },
    );
  }

  static String _formatDate(String dateStr) {
    try {
      return DateFormat('d MMM yyyy, HH:mm', 'pt_PT').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 6 — CULTURAS
// ═══════════════════════════════════════════════════════════════

class _CulturasTab extends StatelessWidget {
  final List<Map<String, dynamic>> yields;
  const _CulturasTab({required this.yields});

  @override
  Widget build(BuildContext context) {
    if (yields.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.energy_savings_leaf_outlined,
                size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Sem culturas neste terreno',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: yields.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final y = yields[i];
        final cropId = y['crop_id'] as int?;
        final cropName = y['crop_name']?.toString() ?? 'Cultura';
        final variety = y['variety_name']?.toString() ?? '';
        final plantedAt = y['yield_planted_at']?.toString() ?? '';
        final status = y['yield_status'] as int? ?? 1;
        final isActive = status == 1;

        String plantedDisplay = '';
        if (plantedAt.isNotEmpty) {
          try {
            plantedDisplay =
                DateFormat('dd/MM/yyyy', 'pt_PT').format(DateTime.parse(plantedAt));
          } catch (_) {
            plantedDisplay = plantedAt;
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: cropId == null
              ? null
              : () => context.go(
                    '/crops/$cropId?name=${Uri.encodeComponent(cropName)}',
                  ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.energy_savings_leaf_outlined,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cropName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (!isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.divider,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Inactiva',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (variety.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          variety,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      if (plantedDisplay.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.event,
                                size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Plantada: $plantedDisplay',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 5 — ANÁLISES
// ═══════════════════════════════════════════════════════════════

class _AnalisesTab extends StatelessWidget {
  final List<Map<String, dynamic>> analyses;
  final int landId;
  final ApiService apiService;
  final VoidCallback onReload;

  const _AnalisesTab({
    required this.analyses,
    required this.landId,
    required this.apiService,
    required this.onReload,
  });

  Future<void> _openAddDialog(BuildContext context) async {
    final created = await AddAnalysisDialog.show(
      context: context,
      apiService: apiService,
      kind: AnalysisKind.soil,
      targetId: landId,
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

  // Campos mais relevantes para mostrar
  static const List<Map<String, String>> _fields = [
    {'key': 'soil_analysis_ph_h20', 'label': 'pH (H₂O)'},
    {'key': 'soil_analysis_organic_matter', 'label': 'Matéria orgânica'},
    {'key': 'soil_analysis_total_nitrogen', 'label': 'Azoto total'},
    {'key': 'soil_analysis_phosphor', 'label': 'Fósforo (P)'},
    {'key': 'soil_analysis_potassium', 'label': 'Potássio (K)'},
    {'key': 'soil_analysis_calcium', 'label': 'Cálcio (Ca)'},
    {'key': 'soil_analysis_magnesium', 'label': 'Magnésio (Mg)'},
    {'key': 'soil_analysis_conductivity', 'label': 'Condutividade'},
    {'key': 'soil_analysis_iron', 'label': 'Ferro (Fe)'},
    {'key': 'soil_analysis_zinc', 'label': 'Zinco (Zn)'},
    {'key': 'soil_analysis_boron', 'label': 'Boro (B)'},
    {'key': 'soil_analysis_copper', 'label': 'Cobre (Cu)'},
  ];

  @override
  Widget build(BuildContext context) {
    if (analyses.isEmpty) {
      return Stack(
        children: [
          const Center(
            child: Text('Sem análises de solo registadas',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _openAddDialog(context),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Adicionar',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: analyses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final a = analyses[i];
        final dateStr = a['soil_analysis_date']?.toString() ?? '';
        final sample  = a['soil_analysis_sample']?.toString() ?? '';
        final pdfUrl  = a['soil_analysis_file']?.toString();

        // Filtrar campos com valor
        final values = _fields.where((f) => a[f['key']] != null).toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.science_outlined, color: Color(0xFF1565C0), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDate(dateStr),
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        if (sample.isNotEmpty)
                          Text(sample,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gerar PDF da análise',
                    onPressed: () => openProtectedPdf(
                      context,
                      path: AppConstants.soilAnalysisPdf(
                          a['soil_analysis_id'] as int),
                      filename:
                          'analise_solo_${a['soil_analysis_id']}.pdf',
                    ),
                    icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F)),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  if (pdfUrl != null && pdfUrl.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _openPdf(context, pdfUrl),
                      icon: const Icon(Icons.attach_file, color: AppTheme.textSecondary),
                      tooltip: 'Abrir PDF anexado',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
              if (values.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.divider),
                const SizedBox(height: 12),
                // Grid de valores
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: values.map((f) {
                    final val = a[f['key']];
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 76) / 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(f['label']!,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ),
                          Text(val.toString(),
                              style: const TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openAddDialog(context),
            backgroundColor: AppTheme.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Adicionar',
                style: TextStyle(color: Colors.white)),
          ),
        ),
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
    // Origin = baseUrl sem o sufixo "/api"
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

  static String _formatDate(String dateStr) {
    try {
      return DateFormat('d MMM yyyy', 'pt_PT').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPONENTES PARTILHADOS
// ═══════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Card({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10,
              color: AppTheme.textSecondary)),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB SENSORES — Firebase se o terreno tiver nós, Open-Meteo caso contrário
// ═══════════════════════════════════════════════════════════════

class _BackendLandSensorsTab extends StatelessWidget {
  final int landId;
  final LandModel land;
  const _BackendLandSensorsTab({required this.landId, required this.land});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SensorAssociationModel>>(
      future: context.read<SensorProvider>().loadLandAssociations(
            landId,
            farmId: land.currentFarm,
            notify: false,
          ),
      builder: (context, associationsSnap) {
        final associations = associationsSnap.data ?? const [];
        if (associationsSnap.connectionState == ConnectionState.waiting &&
            associations.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }
        if (associations.isEmpty) return _LandWeatherFallback(land: land);

        return FutureBuilder(
          future: context.read<SensorProvider>().resolver.resolveLandSensorData(
                land: land,
                associations: associations,
              ),
          builder: (context, dataSnap) {
            if (dataSnap.connectionState == ConnectionState.waiting &&
                !dataSnap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            }
            final data = dataSnap.data;
            if (data == null || !data.hasReadings) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...associations.map((association) => _BackendNodeSensorCard(
                        association: association,
                        readings: const [],
                      )),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Sensores associados, mas sem leituras recentes.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFF57C00)),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: associations.map((association) {
                return _BackendNodeSensorCard(
                  association: association,
                  readings: data.readingsByAssociationId[
                          association.associationId] ??
                      const [],
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _BackendNodeSensorCard extends StatelessWidget {
  final SensorAssociationModel association;
  final List<SensorReadingModel> readings;
  const _BackendNodeSensorCard({
    required this.association,
    required this.readings,
  });

  List<double> _seriesOf(double? Function(SensorReadingModel) pick) =>
      readings
          .map(pick)
          .where((value) => value != null)
          .cast<double>()
          .toList()
          .reversed
          .toList();

  @override
  Widget build(BuildContext context) {
    final latest = readings.isNotEmpty ? readings.first : null;
    final temp = latest?.temperaturaAr;
    final humAr = latest?.humidadeAr;
    final humSolo = latest?.humidadeSolo;
    final pressao = latest?.pressao;

    final temps = _seriesOf((r) => r.temperaturaAr);
    final hums = _seriesOf((r) => r.humidadeAr);
    final humsSolo = _seriesOf((r) => r.humidadeSolo);
    final hasHistory =
        temps.length >= 2 || hums.length >= 2 || humsSolo.length >= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.sensors, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(association.sensorNome,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
                if (latest?.timestamp != null)
                  Text(
                    DateFormat('dd/MM HH:mm').format(latest!.timestamp!),
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          if (latest == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text('Sem leituras recentes',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          else ...[
            // ── Estado atual ──
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Text('Estado atual',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppTheme.textSecondary)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (temp != null)
                    _Metric(
                        icon: Icons.thermostat,
                        value: '${temp.toStringAsFixed(1)}°C',
                        label: 'Temperatura',
                        color: temp >= 35
                            ? AppTheme.error
                            : temp >= 28
                                ? const Color(0xFFF57C00)
                                : AppTheme.primary),
                  if (humAr != null)
                    _Metric(
                        icon: Icons.water_drop_outlined,
                        value: '${humAr.toStringAsFixed(1)}%',
                        label: 'Hum. ar',
                        color: const Color(0xFF1565C0)),
                  if (humSolo != null)
                    _Metric(
                        icon: Icons.grass,
                        value: '${humSolo.toStringAsFixed(1)}%',
                        label: 'Hum. solo',
                        color: const Color(0xFF4CAF50)),
                  if (pressao != null)
                    _Metric(
                        icon: Icons.speed,
                        value: '${pressao.toStringAsFixed(0)} hPa',
                        label: 'Pressão',
                        color: AppTheme.textSecondary),
                ],
              ),
            ),

            // ── Histórico ──
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  const Text('Histórico',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppTheme.textSecondary)),
                  const SizedBox(width: 6),
                  Text('(últimas ${readings.length} leituras)',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (!hasHistory)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text('Histórico ainda insuficiente.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              )
            else ...[
              if (temps.length >= 2)
                _HistoryChart(
                  title: 'Temperatura (°C)',
                  values: temps,
                  color: AppTheme.primary,
                ),
              if (hums.length >= 2)
                _HistoryChart(
                  title: 'Humidade ar (%)',
                  values: hums,
                  color: const Color(0xFF1565C0),
                ),
              if (humsSolo.length >= 2)
                _HistoryChart(
                  title: 'Humidade solo (%)',
                  values: humsSolo,
                  color: const Color(0xFF4CAF50),
                ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final String title;
  final List<double> values;
  final Color color;
  const _HistoryChart({
    required this.title,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final minY = values.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
          const SizedBox(height: 4),
          SizedBox(
            height: 70,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(values.length,
                        (i) => FlSpot(i.toDouble(), values[i])),
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandSensorsTab extends StatelessWidget {
  final int landId;
  final LandModel land;
  const _LandSensorsTab({required this.landId, required this.land});

  @override
  Widget build(BuildContext context) {
    // Procura link específico para este terreno em v4f_links
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instanceFor(app: Firebase.app('sensors'))
          .collection('v4f_links')
          .where('land_id', isEqualTo: landId)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final data = snap.data!.docs.first.data() as Map<String, dynamic>;
          final noIds = (data['no_ids'] as List?)
                  ?.map((e) => int.tryParse(e.toString()))
                  .where((id) => id != null)
                  .cast<int>()
                  .toList() ??
              [];
          if (noIds.isNotEmpty) {
            return _LandFirebaseSensors(noIds: noIds);
          }
        }

        // Sem sensores associados → Open-Meteo
        return _LandWeatherFallback(land: land);
      },
    );
  }
}

// ── Dados reais dos sensores Firebase ────────────────────────

class _LandFirebaseSensors extends StatelessWidget {
  final List<int> noIds;
  const _LandFirebaseSensors({required this.noIds});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: noIds.map((noId) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instanceFor(app: Firebase.app('sensors'))
              .collection('nos')
              .doc(noId.toString())
              .snapshots(),
          builder: (context, snap) {
            final nome = snap.hasData && snap.data!.exists
                ? (snap.data!.data() as Map<String, dynamic>)['nome']
                        ?.toString() ??
                    'Nó $noId'
                : 'Nó $noId';
            return _NodeSensorCard(nome: nome, noId: noId);
          },
        );
      }).toList(),
    );
  }
}

class _NodeSensorCard extends StatelessWidget {
  final String nome;
  final int noId;
  const _NodeSensorCard({required this.nome, required this.noId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instanceFor(app: Firebase.app('sensors'))
          .collection('leituras')
          .where('no_id', isEqualTo: noId)
          .orderBy('timestamp', descending: true)
          .limit(24)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Text('$nome — sem leituras',
                style: const TextStyle(color: AppTheme.textSecondary)),
          );
        }

        final readings = snap.data!.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();
        final latest = readings.first;
        final temp = double.tryParse(latest['temperatura_ar']?.toString() ?? '');
        final humAr = double.tryParse(latest['humidade_ar']?.toString() ?? '');
        final humSolo = double.tryParse(latest['humidade_solo']?.toString() ?? '');
        final pressao = double.tryParse(latest['pressao']?.toString() ?? '');
        final ts = latest['timestamp']?.toString() ?? '';

        // Dados para gráfico (últimas 24 leituras)
        final temps = readings
            .map((r) => double.tryParse(r['temperatura_ar']?.toString() ?? ''))
            .where((v) => v != null)
            .cast<double>()
            .toList()
            .reversed
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    const Icon(Icons.sensors, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(nome,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ),
                    if (ts.isNotEmpty)
                      Text(
                        _fmtTs(ts),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),

              // Métricas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (temp != null)
                      _Metric(
                          icon: Icons.thermostat,
                          value: '${temp.toStringAsFixed(1)}°C',
                          label: 'Temperatura',
                          color: temp >= 35
                              ? AppTheme.error
                              : temp >= 28
                                  ? const Color(0xFFF57C00)
                                  : AppTheme.primary),
                    if (humAr != null)
                      _Metric(
                          icon: Icons.water_drop_outlined,
                          value: '${humAr.toStringAsFixed(1)}%',
                          label: 'Hum. ar',
                          color: const Color(0xFF1565C0)),
                    if (humSolo != null)
                      _Metric(
                          icon: Icons.grass,
                          value: '${humSolo.toStringAsFixed(1)}%',
                          label: 'Hum. solo',
                          color: const Color(0xFF4CAF50)),
                    if (pressao != null)
                      _Metric(
                          icon: Icons.speed,
                          value: '${pressao.toStringAsFixed(0)} hPa',
                          label: 'Pressão',
                          color: AppTheme.textSecondary),
                  ],
                ),
              ),

              // Mini gráfico temperatura
              if (temps.length >= 3) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Temperatura — últimas leituras',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: LineChart(
                          LineChartData(
                            minY: temps.reduce((a, b) => a < b ? a : b) - 1,
                            maxY: temps.reduce((a, b) => a > b ? a : b) + 1,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(
                              leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(
                                    temps.length,
                                    (i) => FlSpot(i.toDouble(), temps[i])),
                                isCurved: true,
                                color: AppTheme.primary,
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }

  String _fmtTs(String ts) {
    try {
      return DateFormat('dd/MM HH:mm').format(DateTime.parse(ts));
    } catch (_) {
      return ts;
    }
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _Metric(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      );
}

// ── Fallback Open-Meteo quando não há sensores ─────────────────

class _LandWeatherFallback extends StatefulWidget {
  final LandModel land;
  const _LandWeatherFallback({required this.land});

  @override
  State<_LandWeatherFallback> createState() => _LandWeatherFallbackState();
}

class _LandWeatherFallbackState extends State<_LandWeatherFallback> {
  bool _loading = true;
  String? _error;
  double? _temp;
  double? _hum;
  double? _wind;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final lat = widget.land.effectiveLatitude;
    final lng = widget.land.effectiveLongitude;
    if (lat == null || lng == null) {
      setState(() {
        _loading = false;
        _error = 'GPS do terreno não definido.';
      });
      return;
    }
    try {
      final r = await Dio().get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m',
          'timezone': 'Europe/Lisbon',
        },
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final current = r.data['current'] as Map<String, dynamic>? ?? {};
      setState(() {
        _temp = (current['temperature_2m'] as num?)?.toDouble();
        _hum = (current['relative_humidity_2m'] as num?)?.toDouble();
        _wind = (current['wind_speed_10m'] as num?)?.toDouble();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Sem dados meteorológicos disponíveis.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return Center(
          child: Text(_error!,
              style: const TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_outlined,
                      color: AppTheme.textSecondary, size: 18),
                  SizedBox(width: 6),
                  Text('Meteorologia (Open-Meteo)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (_temp != null)
                    Expanded(
                      child: _WeatherMetric(
                        icon: Icons.thermostat,
                        value: '${_temp!.toStringAsFixed(1)}°C',
                        label: 'Temperatura',
                        color: AppTheme.primary,
                      ),
                    ),
                  if (_hum != null)
                    Expanded(
                      child: _WeatherMetric(
                        icon: Icons.water_drop_outlined,
                        value: '${_hum!.toStringAsFixed(0)}%',
                        label: 'Humidade',
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  if (_wind != null)
                    Expanded(
                      child: _WeatherMetric(
                        icon: Icons.air,
                        value: '${_wind!.toStringAsFixed(1)} km/h',
                        label: 'Vento',
                        color: const Color(0xFF7B1FA2),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este terreno não tem sensores físicos associados. '
                  'Associa sensores em "Sensores" → "Gerir sensores".',
                  style: TextStyle(fontSize: 12, color: Color(0xFFF57C00)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _WeatherMetric(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
    ]),
  );
}
