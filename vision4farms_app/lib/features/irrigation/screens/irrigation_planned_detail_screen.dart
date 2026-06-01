import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/water_service.dart';
import '../../../core/models/water_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/theme/app_theme.dart';

class IrrigationPlannedDetailScreen extends StatefulWidget {
  final int plannedId;

  const IrrigationPlannedDetailScreen({super.key, required this.plannedId});

  @override
  State<IrrigationPlannedDetailScreen> createState() =>
      _IrrigationPlannedDetailScreenState();
}

class _IrrigationPlannedDetailScreenState
    extends State<IrrigationPlannedDetailScreen> {
  final _api = ApiService();
  final _waterService = WaterService();

  WaterIrrigationPlan? _plan;
  String? _landName;
  String? _yieldName;
  String? _sourceName;
  bool _loading = true;
  bool _busy = false;
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
    try {
      final response =
          await _api.get(AppConstants.waterPlannedDetail(widget.plannedId));
      final plan =
          WaterIrrigationPlan.fromJson(response.data as Map<String, dynamic>);

      // Buscar nomes em paralelo
      final futures = <Future>[
        _api.get('${AppConstants.lands}${plan.landId}/'),
      ];
      if (plan.yieldId != null) {
        futures.add(_api.get('${AppConstants.yields}${plan.yieldId}/'));
      }
      if (plan.waterSourceId != null) {
        futures.add(
            _api.get(AppConstants.waterSourceDetail(plan.waterSourceId!)));
      }
      final results = await Future.wait(futures);
      final landData = (results[0] as dynamic).data as Map<String, dynamic>;
      String? yieldName;
      String? sourceName;
      int idx = 1;
      if (plan.yieldId != null) {
        final yd = (results[idx] as dynamic).data as Map<String, dynamic>;
        yieldName = yd['yield_name']?.toString();
        idx++;
      }
      if (plan.waterSourceId != null) {
        final sd = (results[idx] as dynamic).data as Map<String, dynamic>;
        sourceName = sd['water_source_name']?.toString();
      }

      if (!mounted) return;
      setState(() {
        _plan = plan;
        _landName = landData['land_name']?.toString();
        _yieldName = yieldName;
        _sourceName = sourceName;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Erro ao carregar rega.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _execute() async {
    final plan = _plan;
    if (plan == null) return;
    final volCtrl = TextEditingController(
        text: plan.volumeLiters != null
            ? plan.volumeLiters!.toStringAsFixed(0)
            : '');
    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Executar rega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: volCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Volume (L)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await _waterService.executePlanned(
        plan.plannedId,
        volumeLiters: double.tryParse(volCtrl.text.replaceAll(',', '.')),
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao executar rega'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _cancelPlan() async {
    final plan = _plan;
    if (plan == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar rega'),
        content: const Text('Tens a certeza que queres cancelar esta rega planeada?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar rega',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await _waterService
          .updatePlanned(plan.plannedId, {'irrigation_status': 2});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao cancelar'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar rega'),
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
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await _waterService.deletePlanned(widget.plannedId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao eliminar'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '—';
    return t.length >= 5 ? t.substring(0, 5) : t;
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

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Rega'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null || plan == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error ?? 'Rega não encontrada.',
                          style:
                              const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _InfoCard(children: [
                      _InfoRow(label: 'Estado', value: _statusLabel(plan.status)),
                      _InfoRow(
                          label: 'Âmbito',
                          value: plan.yieldId == null
                              ? 'Geral (todas as culturas)'
                              : 'Cultura específica'),
                      _InfoRow(label: 'Terreno', value: _landName ?? '—'),
                      _InfoRow(
                          label: 'Cultura',
                          value: plan.yieldId == null
                              ? '—'
                              : (_yieldName ?? '—')),
                      _InfoRow(label: 'Fonte', value: _sourceName ?? '—'),
                      _InfoRow(
                          label: 'Data', value: _formatDate(plan.plannedDate)),
                      _InfoRow(
                          label: 'Hora', value: _formatTime(plan.plannedTime)),
                      _InfoRow(
                          label: 'Duração',
                          value: plan.durationMin != null
                              ? '${plan.durationMin} min'
                              : '—'),
                      _InfoRow(
                          label: 'Volume',
                          value: plan.volumeLiters != null
                              ? '${plan.volumeLiters!.toStringAsFixed(0)} L'
                              : '—'),
                      _InfoRow(label: 'Método', value: plan.methodName ?? '—'),
                      if (plan.notes != null && plan.notes!.isNotEmpty)
                        _InfoRow(label: 'Notas', value: plan.notes!),
                      if (plan.executedAt != null)
                        _InfoRow(
                            label: 'Executada em',
                            value: _formatDate(plan.executedAt!)),
                    ]),
                    const SizedBox(height: 20),
                    if (plan.status == 0) ...[
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _execute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Executar'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _cancelPlan,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancelar rega'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextButton.icon(
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.error),
                      label: const Text('Eliminar',
                          style: TextStyle(color: AppTheme.error)),
                    ),
                  ],
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textPrimary)),
            ),
          ],
        ),
      );
}
