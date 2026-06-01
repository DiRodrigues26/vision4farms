import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/local_database.dart';
import '../../core/services/offline_mutation.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/utils/uuid_helper.dart';
import '../theme/app_theme.dart';

class HarvestFormDialog extends StatefulWidget {
  final int yieldId;
  final Map<String, dynamic>? existing;

  const HarvestFormDialog({
    super.key,
    required this.yieldId,
    this.existing,
  });

  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required int yieldId,
    Map<String, dynamic>? existing,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => HarvestFormDialog(yieldId: yieldId, existing: existing),
    );
  }

  @override
  State<HarvestFormDialog> createState() => _HarvestFormDialogState();
}

class _HarvestFormDialogState extends State<HarvestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  bool _submitting = false;
  String? _error;

  late DateTime _date;
  final _name = TextEditingController();
  final _harvested = TextEditingController();
  final _unit = TextEditingController(text: 'KG');
  final _laborCount = TextEditingController();
  final _laborHours = TextEditingController();
  final _laborHoursPerOp = TextEditingController();
  final _laborCost = TextEditingController();
  final _kgPerOp = TextEditingController();
  final _machineCount = TextEditingController();
  final _machineHours = TextEditingController();
  final _machineCost = TextEditingController();
  final _totalCost = TextEditingController();
  final _costPerKg = TextEditingController();
  final _kgPerHour = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = _parseDate(e?['harvest_date']?.toString()) ?? DateTime.now();
    _name.text = e?['harvest_name']?.toString() ?? '';
    _harvested.text = _fmtNum(e?['harvest_harvested']);
    _unit.text = e?['unit_measurement']?.toString() ?? 'KG';
    _laborCount.text = _fmtNum(e?['harvested_labor_count']);
    _laborHours.text = _fmtNum(e?['harvested_labor_hours']);
    _laborHoursPerOp.text = _fmtNum(e?['harvested_labor_hours_per_operator']);
    _laborCost.text = _fmtNum(e?['harvested_labor_total_cost']);
    _kgPerOp.text = _fmtNum(e?['harvest_kg_per_operator']);
    _machineCount.text = _fmtNum(e?['harvested_machine_count']);
    _machineHours.text = _fmtNum(e?['harvested_machine_hours']);
    _machineCost.text = _fmtNum(e?['harvested_machine_cost']);
    _totalCost.text = _fmtNum(e?['total_harvest_cost']);
    _costPerKg.text = _fmtNum(e?['harvest_cost_per_kg']);
    _kgPerHour.text = _fmtNum(e?['harvest_kg_per_hour']);
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _harvested.dispose();
    _unit.dispose();
    _laborCount.dispose();
    _laborHours.dispose();
    _laborHoursPerOp.dispose();
    _laborCost.dispose();
    _kgPerOp.dispose();
    _machineCount.dispose();
    _machineHours.dispose();
    _machineCost.dispose();
    _totalCost.dispose();
    _costPerKg.dispose();
    _kgPerHour.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('pt', 'PT'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _numValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (double.tryParse(v.replaceAll(',', '.')) == null) {
      return 'Número inválido';
    }
    return null;
  }

  Map<String, dynamic> _payload() {
    final data = <String, dynamic>{
      'harvest_date': DateFormat('yyyy-MM-dd').format(_date),
      'harvest_name': _name.text.trim(),
      'harvest_harvested': _harvested.text.replaceAll(',', '.').trim(),
      'unit_measurement': _unit.text.trim().isEmpty ? 'KG' : _unit.text.trim(),
    };
    void addNum(String key, TextEditingController ctrl) {
      final v = ctrl.text.replaceAll(',', '.').trim();
      if (v.isNotEmpty) data[key] = v;
    }

    addNum('harvested_labor_count', _laborCount);
    addNum('harvested_labor_hours', _laborHours);
    addNum('harvested_labor_hours_per_operator', _laborHoursPerOp);
    addNum('harvested_labor_total_cost', _laborCost);
    addNum('harvest_kg_per_operator', _kgPerOp);
    addNum('harvested_machine_count', _machineCount);
    addNum('harvested_machine_hours', _machineHours);
    addNum('harvested_machine_cost', _machineCost);
    addNum('total_harvest_cost', _totalCost);
    addNum('harvest_cost_per_kg', _costPerKg);
    addNum('harvest_kg_per_hour', _kgPerHour);
    return data;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final payload = _payload();
    final isCreate = widget.existing == null;
    final clientUuid = UuidHelper.v4();
    final harvestId = isCreate ? null : widget.existing!['harvest_id'] as int?;

    final queueData = <String, dynamic>{
      ...payload,
      'client_uuid': clientUuid,
      'yield_id': widget.yieldId,
      if (!isCreate && harvestId != null) 'harvest_id': harvestId,
    };

    final result = await OfflineMutation.run(
      apiCall: () => isCreate
          ? _api.post(
              AppConstants.harvestCreate(widget.yieldId), data: payload)
          : _api.patch(
              AppConstants.harvestDetail(harvestId!), data: payload),
      operationType: isCreate ? 'create_harvest' : 'update_harvest',
      queueData: queueData,
      applyOptimistic: () async {
        if (isCreate) {
          await LocalDatabase.appendLocalWrite(
            entityType: 'harvest',
            parentId: widget.yieldId,
            clientUuid: clientUuid,
            data: queueData,
          );
        }
      },
    );

    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _submitting = false;
        _error = result.errorMessage ?? 'Erro ao guardar colheita.';
      });
      return;
    }

    context.read<SyncProvider>().refreshCounts();
    Navigator.of(context).pop(result.data ?? queueData);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.queued
            ? 'Colheita guardada offline — sincroniza quando voltares online.'
            : (isCreate ? 'Colheita criada.' : 'Colheita atualizada.')),
        backgroundColor: result.queued
            ? const Color(0xFF7B1FA2)
            : AppTheme.primary,
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, {double width = 0}) {
    return SizedBox(
      width: width > 0 ? width : null,
      child: TextFormField(
        controller: ctrl,
        enabled: !_submitting,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: _numValidator,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(_date);
    final isEdit = widget.existing != null;
    final width = MediaQuery.of(context).size.width;
    final halfWidth = ((width - 80) / 2).clamp(140.0, 240.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEdit ? 'Editar colheita' : 'Nova colheita',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: _submitting ? null : _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data',
                              prefixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(dateLabel,
                                style: const TextStyle(fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            hintText: 'Ex: Colheita Lote A',
                            prefixIcon: Icon(Icons.label_outline, size: 20),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo obrigatório'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _harvested,
                                enabled: !_submitting,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Quantidade',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Obrigatório';
                                  }
                                  return _numValidator(v);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _unit,
                                enabled: !_submitting,
                                decoration: const InputDecoration(
                                  labelText: 'Unidade',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _SectionTitle('Mão-de-obra'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _numField('Nº operadores', _laborCount,
                              width: halfWidth),
                          _numField('Horas totais', _laborHours,
                              width: halfWidth),
                          _numField('Horas/operador', _laborHoursPerOp,
                              width: halfWidth),
                          _numField('Custo total (€)', _laborCost,
                              width: halfWidth),
                          _numField('Kg/operador', _kgPerOp, width: halfWidth),
                        ]),
                        const SizedBox(height: 16),
                        const _SectionTitle('Máquinas'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _numField('Nº máquinas', _machineCount,
                              width: halfWidth),
                          _numField('Horas totais', _machineHours,
                              width: halfWidth),
                          _numField('Custo (€)', _machineCost,
                              width: halfWidth),
                        ]),
                        const SizedBox(height: 16),
                        const _SectionTitle('Totais'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _numField('Custo total (€)', _totalCost,
                              width: halfWidth),
                          _numField('Custo/kg (€)', _costPerKg,
                              width: halfWidth),
                          _numField('Kg/hora', _kgPerHour, width: halfWidth),
                        ]),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xFFD32F2F), fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEdit ? 'Guardar' : 'Criar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary)),
      );
}
