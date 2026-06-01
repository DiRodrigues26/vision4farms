import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/harvest_form_dialog.dart';
import '../../../shared/widgets/pdf_launcher.dart';

class YieldHarvestsScreen extends StatefulWidget {
  final int yieldId;
  final String yieldName;

  const YieldHarvestsScreen({
    super.key,
    required this.yieldId,
    required this.yieldName,
  });

  @override
  State<YieldHarvestsScreen> createState() => _YieldHarvestsScreenState();
}

class _YieldHarvestsScreenState extends State<YieldHarvestsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
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
    final result = await OfflineRead.list(
      cacheKey: 'harvests:yield_${widget.yieldId}',
      apiCall: () => _api.get(AppConstants.harvestList(widget.yieldId)),
      localEntity: 'harvest',
      parentId: widget.yieldId,
    );
    if (!mounted) return;
    setState(() {
      _items = result.items.cast<Map<String, dynamic>>();
      _error = result.fromCache && _items.isEmpty
          ? (result.errorMessage ?? 'Sem ligação e sem dados guardados.')
          : null;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final result = await HarvestFormDialog.show(
      context: context,
      yieldId: widget.yieldId,
    );
    if (result != null && mounted) _load();
  }

  Future<void> _edit(Map<String, dynamic> existing) async {
    final result = await HarvestFormDialog.show(
      context: context,
      yieldId: widget.yieldId,
      existing: existing,
    );
    if (result != null && mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar colheita'),
        content: const Text('Esta ação não pode ser revertida. Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final harvestId = item['harvest_id'] as int;
    final result = await OfflineMutation.run(
      apiCall: () => _api.delete(AppConstants.harvestDetail(harvestId)),
      operationType: 'delete_harvest',
      queueData: {
        'harvest_id': harvestId,
        'client_uuid': UuidHelper.v4(),
      },
      applyOptimistic: () async {
        setState(() {
          _items = _items.where((h) => h['harvest_id'] != harvestId).toList();
        });
      },
    );

    if (!mounted) return;
    if (result.queued) {
      context.read<SyncProvider>().refreshCounts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminação guardada offline — sincroniza quando voltares online.'),
          backgroundColor: Color(0xFF7B1FA2),
        ),
      );
    } else if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Erro ao eliminar.')),
      );
      await _load(); // recarregar para restaurar item
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Colheitas · ${widget.yieldName}'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova colheita',
            style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style:
                              const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text('Sem colheitas registadas.',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _HarvestCard(
                            harvest: _items[i],
                            dateLabel: _formatDate(
                                _items[i]['harvest_date']?.toString()),
                            onEdit: () => _edit(_items[i]),
                            onDelete: () => _delete(_items[i]),
                            onPdf: () => openProtectedPdf(
                              context,
                              path: AppConstants.harvestPdf(
                                  _items[i]['harvest_id'] as int),
                              filename:
                                  'colheita_${_items[i]['harvest_id']}.pdf',
                            ),
                          ),
                        ),
                ),
    );
  }
}

class _HarvestCard extends StatelessWidget {
  final Map<String, dynamic> harvest;
  final String dateLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPdf;

  const _HarvestCard({
    required this.harvest,
    required this.dateLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final name = harvest['harvest_name']?.toString() ?? 'Colheita';
    final harvested = harvest['harvest_harvested'];
    final unit = harvest['unit_measurement']?.toString() ?? 'KG';
    final totalCost = harvest['total_harvest_cost'];
    final costPerKg = harvest['harvest_cost_per_kg'];
    final labor = harvest['harvested_labor_count'];
    final machines = harvest['harvested_machine_count'];

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.agriculture,
                    color: Color(0xFFB8860B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    Text(dateLabel,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Gerar PDF',
                onPressed: onPdf,
                icon: const Icon(Icons.picture_as_pdf,
                    color: Color(0xFFD32F2F)),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (harvested != null)
                _kv('Quantidade', '$harvested $unit'),
              if (totalCost != null) _kv('Custo total', '$totalCost €'),
              if (costPerKg != null) _kv('Custo/kg', '$costPerKg €'),
              if (labor != null) _kv('Operadores', labor.toString()),
              if (machines != null) _kv('Máquinas', machines.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}
