import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/water_model.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/local_database.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/services/water_service.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';

class WaterUsageFormScreen extends StatefulWidget {
  final WaterSource source;
  const WaterUsageFormScreen({super.key, required this.source});

  @override
  State<WaterUsageFormScreen> createState() => _WaterUsageFormScreenState();
}

class _WaterUsageFormScreenState extends State<WaterUsageFormScreen> {
  final _service = WaterService();
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _volumeCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  int? _methodId;
  int? _landId;

  List<WaterIrrigationMethod> _methods = [];
  List<Map<String, dynamic>> _lands = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _costCtrl.dispose();
    _purposeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final farm = context.read<FarmProvider>().selectedFarm;
      final methods = await _service.listMethods();
      List<Map<String, dynamic>> lands = [];
      if (farm != null) {
        final r = await _api.get(
          AppConstants.lands,
          params: {'farm_id': farm.farmId.toString()},
        );
        lands = ApiService.extractResults(r.data).cast<Map<String, dynamic>>();
      }
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _lands = lands;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  double? _parseDouble(String v) {
    final t = v.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final volume = _parseDouble(_volumeCtrl.text);
    if (volume == null || volume <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduz um volume válido'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final data = <String, dynamic>{
      'water_source_id': widget.source.waterSourceId,
      'water_usage_usage_date': DateFormat('yyyy-MM-dd').format(_date),
      'water_usage_volume_liters': volume,
      if (_landId != null) 'land_id': _landId,
      if (_methodId != null) 'water_usage_method': _methodId,
      if (_costCtrl.text.trim().isNotEmpty)
        'water_usage_cost': _parseDouble(_costCtrl.text),
      if (_purposeCtrl.text.trim().isNotEmpty)
        'water_usage_purpose': _purposeCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty)
        'water_usage_notes': _notesCtrl.text.trim(),
    };

    final clientUuid = UuidHelper.v4();
    final queueData = <String, dynamic>{
      ...data,
      'client_uuid': clientUuid,
    };

    final result = await OfflineMutation.run(
      apiCall: () => _api.post(AppConstants.waterUsageLogs, data: data),
      operationType: 'create_water_usage',
      queueData: queueData,
      applyOptimistic: () async {
        await LocalDatabase.appendLocalWrite(
          entityType: 'water_usage',
          parentId: widget.source.waterSourceId,
          clientUuid: clientUuid,
          data: queueData,
        );
      },
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Erro ao guardar consumo.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    context.read<SyncProvider>().refreshCounts();
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.queued
            ? 'Consumo guardado offline — sincroniza quando voltares online.'
            : 'Consumo registado.'),
        backgroundColor: result.queued
            ? const Color(0xFF7B1FA2)
            : AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text('Novo consumo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _Label('Fonte: ${widget.source.waterSourceName}'),
                  const SizedBox(height: 16),

                  const _Label('Data *'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: _BoxField(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormat('dd/MM/yyyy').format(_date),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const _Label('Volume (L) *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _volumeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: '0'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  const _Label('Custo (€)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _costCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: '0.00'),
                  ),
                  const SizedBox(height: 16),

                  if (_methods.isNotEmpty) ...[
                    const _Label('Método de rega'),
                    const SizedBox(height: 6),
                    _Dropdown<int>(
                      hint: 'Selecionar (opcional)',
                      value: _methodId,
                      items: _methods
                          .map((m) => DropdownMenuItem(
                                value: m.waterIrrigationId,
                                child: Text(m.waterIrrigationName),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _methodId = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_lands.isNotEmpty) ...[
                    const _Label('Terreno'),
                    const SizedBox(height: 6),
                    _Dropdown<int>(
                      hint: 'Associar a terreno (opcional)',
                      value: _landId,
                      items: _lands
                          .map((l) => DropdownMenuItem<int>(
                                value: l['land_id'] as int,
                                child: Text(l['land_name']?.toString() ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _landId = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const _Label('Finalidade'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _purposeCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Rega, limpeza...',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  const _Label('Notas'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(hintText: 'Observações...'),
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Guardar consumo'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      );
}

class _BoxField extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BoxField({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _Dropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14)),
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}
