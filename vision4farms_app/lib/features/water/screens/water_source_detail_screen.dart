import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/water_model.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';
import 'water_source_form_screen.dart';
import 'water_usage_form_screen.dart';
import 'water_planned_form_screen.dart';

class WaterSourceDetailScreen extends StatefulWidget {
  final int sourceId;
  const WaterSourceDetailScreen({super.key, required this.sourceId});

  @override
  State<WaterSourceDetailScreen> createState() => _WaterSourceDetailScreenState();
}

class _WaterSourceDetailScreenState extends State<WaterSourceDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabs;

  WaterSource? _source;
  List<WaterUsageLog> _usage = [];
  List<WaterIrrigationPlan> _planned = [];

  bool _loading = true;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    final sourceResult = await OfflineRead.json(
      cacheKey: 'water_source:${widget.sourceId}',
      apiCall: () => _api.get(AppConstants.waterSourceDetail(widget.sourceId)),
    );
    final usageResult = await OfflineRead.list(
      cacheKey: 'water_usage:source_${widget.sourceId}',
      apiCall: () => _api.get(AppConstants.waterUsageLogs,
          params: {'water_source_id': widget.sourceId}),
      localEntity: 'water_usage',
      parentId: widget.sourceId,
    );
    final plannedResult = await OfflineRead.list(
      cacheKey: 'water_planned:source_${widget.sourceId}',
      apiCall: () => _api.get(AppConstants.waterPlanned,
          params: {'water_source_id': widget.sourceId}),
      localEntity: 'water_planned',
      parentId: widget.sourceId,
    );

    if (!mounted) return;
    if (sourceResult.data == null) {
      setState(() { _error = sourceResult.errorMessage ?? 'Sem ligação.'; _loading = false; });
      return;
    }
    setState(() {
      _source  = WaterSource.fromJson(sourceResult.data!);
      _usage   = usageResult.items
          .map((e) => WaterUsageLog.fromJson(e as Map<String, dynamic>))
          .toList();
      _planned = plannedResult.items
          .map((e) => WaterIrrigationPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      _loading = false;
    });
  }

  Future<void> _edit() async {
    if (_source == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WaterSourceFormScreen(source: _source),
      ),
    );
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _confirmDelete() async {
    final s = _source;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar fonte de água'),
        content: Text('Tens a certeza que queres eliminar "${s.waterSourceName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await OfflineMutation.run(
      apiCall: () => _api.delete(AppConstants.waterSourceDetail(s.waterSourceId)),
      operationType: 'delete_water_source',
      queueData: {
        'water_source_id': s.waterSourceId,
        'client_uuid': UuidHelper.v4(),
      },
    );
    if (!mounted) return;
    if (result.queued) context.read<SyncProvider>().refreshCounts();
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Erro ao eliminar')),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _addUsage() async {
    if (_source == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WaterUsageFormScreen(source: _source!),
      ),
    );
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _addPlanned() async {
    if (_source == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WaterPlannedFormScreen(source: _source!),
      ),
    );
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _deleteUsage(WaterUsageLog u) async {
    final ok = await _confirmDeleteDialog('Eliminar registo de consumo?');
    if (ok != true || !mounted) return;
    final result = await OfflineMutation.run(
      apiCall: () => _api.delete(AppConstants.waterUsageDetail(u.waterUsageId)),
      operationType: 'delete_water_usage',
      queueData: {
        'water_usage_id': u.waterUsageId,
        'client_uuid': UuidHelper.v4(),
      },
      applyOptimistic: () async =>
          setState(() => _usage.removeWhere((x) => x.waterUsageId == u.waterUsageId)),
    );
    if (!mounted) return;
    if (result.queued) {
      context.read<SyncProvider>().refreshCounts();
    } else if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Erro ao eliminar')),
      );
      _load();
      return;
    }
    _changed = true;
  }

  Future<void> _deletePlanned(WaterIrrigationPlan p) async {
    final ok = await _confirmDeleteDialog('Eliminar rega planeada?');
    if (ok != true || !mounted) return;
    final result = await OfflineMutation.run(
      apiCall: () => _api.delete(AppConstants.waterPlannedDetail(p.plannedId)),
      operationType: 'delete_water_planned',
      queueData: {
        'planned_id': p.plannedId,
        'client_uuid': UuidHelper.v4(),
      },
      applyOptimistic: () async =>
          setState(() => _planned.removeWhere((x) => x.plannedId == p.plannedId)),
    );
    if (!mounted) return;
    if (result.queued) {
      context.read<SyncProvider>().refreshCounts();
    } else if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Erro ao eliminar')),
      );
      _load();
      return;
    }
    _changed = true;
  }

  Future<void> _executePlanned(WaterIrrigationPlan p) async {
    final ctrl = TextEditingController(text: p.volumeLiters?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Executar rega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirma o volume realmente utilizado (L):',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Executar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final volume = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    final queueData = <String, dynamic>{
      'planned_id': p.plannedId,
      'client_uuid': UuidHelper.v4(),
      if (volume != null) 'volume_liters': volume,
    };
    final result = await OfflineMutation.run(
      apiCall: () => _api.post(
        AppConstants.waterPlannedExecute(p.plannedId),
        data: volume != null ? {'volume_liters': volume} : {},
      ),
      operationType: 'execute_water_planned',
      queueData: queueData,
    );
    if (!mounted) return;
    if (result.queued) context.read<SyncProvider>().refreshCounts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.queued
            ? 'Rega marcada para executar offline — sincroniza quando voltares online.'
            : result.success
                ? 'Rega executada.'
                : (result.errorMessage ?? 'Erro ao executar rega')),
        backgroundColor: result.queued
            ? const Color(0xFF7B1FA2)
            : result.success
                ? AppTheme.primary
                : AppTheme.error,
      ),
    );
    _changed = true;
    _load();
  }

  Future<bool?> _confirmDeleteDialog(String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        context.read<FarmProvider>().selectedFarm?.canManage ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          title: Text(_source?.waterSourceName ?? 'Fonte de água'),
          actions: canManage && _source != null
              ? [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _edit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                    onPressed: _confirmDelete,
                  ),
                ]
              : null,
          bottom: _loading || _source == null
              ? null
              : TabBar(
                  controller: _tabs,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  tabs: const [
                    Tab(text: 'Detalhes'),
                    Tab(text: 'Consumos'),
                    Tab(text: 'Planeadas'),
                  ],
                ),
        ),
        floatingActionButton: _buildFab(canManage),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: _load, child: const Text('Tentar novamente')),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _DetailsTab(source: _source!),
                      _UsageTab(
                        items: _usage,
                        canManage: canManage,
                        onDelete: _deleteUsage,
                      ),
                      _PlannedTab(
                        items: _planned,
                        canManage: canManage,
                        onExecute: _executePlanned,
                        onDelete: _deletePlanned,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget? _buildFab(bool canManage) {
    if (!canManage || _source == null || _loading) return null;
    return AnimatedBuilder(
      animation: _tabs,
      builder: (_, __) {
        switch (_tabs.index) {
          case 1:
            return FloatingActionButton.extended(
              onPressed: _addUsage,
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Novo consumo',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            );
          case 2:
            return FloatingActionButton.extended(
              onPressed: _addPlanned,
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Planear rega',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Detalhes
// ══════════════════════════════════════════════════════════════

class _DetailsTab extends StatelessWidget {
  final WaterSource source;
  const _DetailsTab({required this.source});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'Informações',
          rows: [
            ('Tipo', source.waterTypeName ?? '—'),
            ('Estado', source.status == 1 ? 'Ativa' : 'Inativa'),
            ('Propriedade', source.ownership ? 'Própria' : 'Externa'),
            if (source.locationDescription != null &&
                source.locationDescription!.isNotEmpty)
              ('Localização', source.locationDescription!),
            if (source.hasCoordinates)
              ('Coordenadas',
                  '${source.latitude!.toStringAsFixed(5)}, ${source.longitude!.toStringAsFixed(5)}'),
            if (source.depthMeters != null)
              ('Profundidade', '${source.depthMeters} m'),
            if (source.capacity != null)
              ('Capacidade', '${source.capacity} m³'),
          ],
        ),
        if (source.hasCosts) ...[
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Custos de construção',
            rows: [
              if (source.buildDate != null) ('Data', source.buildDate!),
              if (source.buildCost != null)
                ('Custo', '${source.buildCost!.toStringAsFixed(2)} €'),
              if (source.buildInvoice != null && source.buildInvoice!.isNotEmpty)
                ('Fatura', source.buildInvoice!),
            ],
          ),
        ],
        if (source.notes != null && source.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Notas',
            rows: [('', source.notes!)],
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.$1.isNotEmpty) ...[
                      SizedBox(
                        width: 110,
                        child: Text(r.$1,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(r.$2,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Consumos
// ══════════════════════════════════════════════════════════════

class _UsageTab extends StatelessWidget {
  final List<WaterUsageLog> items;
  final bool canManage;
  final ValueChanged<WaterUsageLog> onDelete;

  const _UsageTab({
    required this.items,
    required this.canManage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Sem registos de consumo',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final u = items[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: Color(0xFF0277BD)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatDate(u.usageDate),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${u.volumeLiters.toStringAsFixed(0)} L'
                      '${u.methodName != null ? ' · ${u.methodName}' : ''}'
                      '${u.cost != null ? ' · ${u.cost!.toStringAsFixed(2)} €' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (u.purpose != null && u.purpose!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(u.purpose!,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ),
                  ],
                ),
              ),
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.textSecondary),
                  onPressed: () => onDelete(u),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String d) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Planeadas
// ══════════════════════════════════════════════════════════════

class _PlannedTab extends StatelessWidget {
  final List<WaterIrrigationPlan> items;
  final bool canManage;
  final ValueChanged<WaterIrrigationPlan> onExecute;
  final ValueChanged<WaterIrrigationPlan> onDelete;

  const _PlannedTab({
    required this.items,
    required this.canManage,
    required this.onExecute,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Sem regas planeadas',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = items[i];
        final color = _statusColor(p.status);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_formatDate(p.plannedDate),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_statusLabel(p.status),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (p.plannedTime != null) p.plannedTime!,
                        if (p.durationMin != null) '${p.durationMin} min',
                        if (p.volumeLiters != null)
                          '${p.volumeLiters!.toStringAsFixed(0)} L',
                        if (p.methodName != null) p.methodName!,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (canManage) ...[
                if (p.status == 0)
                  IconButton(
                    tooltip: 'Executar',
                    icon: const Icon(Icons.play_arrow_rounded,
                        color: AppTheme.primary),
                    onPressed: () => onExecute(p),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.textSecondary),
                  onPressed: () => onDelete(p),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(int s) {
    switch (s) {
      case 1:
        return AppTheme.primary;
      case 2:
        return AppTheme.textSecondary;
      default:
        return const Color(0xFF0277BD);
    }
  }

  String _statusLabel(int s) {
    switch (s) {
      case 1:
        return 'Executada';
      case 2:
        return 'Cancelada';
      default:
        return 'Planeada';
    }
  }

  String _formatDate(String d) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }
}
