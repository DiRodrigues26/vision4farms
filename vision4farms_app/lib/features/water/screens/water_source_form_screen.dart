import 'package:flutter/material.dart';
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

class WaterSourceFormScreen extends StatefulWidget {
  final WaterSource? source;
  const WaterSourceFormScreen({super.key, this.source});

  @override
  State<WaterSourceFormScreen> createState() => _WaterSourceFormScreenState();
}

class _WaterSourceFormScreenState extends State<WaterSourceFormScreen> {
  final _service = WaterService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _depthCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _buildCostCtrl = TextEditingController();
  final _buildInvoiceCtrl = TextEditingController();

  List<WaterSourceType> _types = [];
  int? _selectedTypeId;
  bool _ownership = true;
  bool _hasCosts = false;
  bool _active = true;
  DateTime? _buildDate;

  bool _loadingTypes = true;
  bool _submitting = false;
  String? _typesError;

  bool get _isEdit => widget.source != null;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    if (s != null) {
      _nameCtrl.text = s.waterSourceName;
      _selectedTypeId = s.waterTypeId;
      _locationCtrl.text = s.locationDescription ?? '';
      _latCtrl.text = s.latitude?.toString() ?? '';
      _lngCtrl.text = s.longitude?.toString() ?? '';
      _depthCtrl.text = s.depthMeters?.toString() ?? '';
      _capacityCtrl.text = s.capacity?.toString() ?? '';
      _notesCtrl.text = s.notes ?? '';
      _ownership = s.ownership;
      _hasCosts = s.hasCosts;
      _active = s.status == 1;
      _buildCostCtrl.text = s.buildCost?.toString() ?? '';
      _buildInvoiceCtrl.text = s.buildInvoice ?? '';
      if (s.buildDate != null && s.buildDate!.isNotEmpty) {
        _buildDate = DateTime.tryParse(s.buildDate!);
      }
    }
    _loadTypes();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _depthCtrl.dispose();
    _capacityCtrl.dispose();
    _notesCtrl.dispose();
    _buildCostCtrl.dispose();
    _buildInvoiceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    try {
      final list = await _service.listTypes();
      if (!mounted) return;
      setState(() {
        _types = list;
        _loadingTypes = false;
        if (_selectedTypeId == null && list.isNotEmpty) {
          _selectedTypeId = list.first.waterTypeId;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTypes = false;
        _typesError = 'Erro ao carregar tipos de fonte';
      });
    }
  }

  Future<void> _pickBuildDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _buildDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _buildDate = picked);
  }

  double? _parseDouble(String v) {
    final t = v.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleciona o tipo de fonte'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) return;

    setState(() => _submitting = true);

    final data = <String, dynamic>{
      'farm_id': farm.farmId,
      'water_source_name': _nameCtrl.text.trim(),
      'water_type_id': _selectedTypeId,
      'water_source_location_description':
          _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      'water_source_latitude': _parseDouble(_latCtrl.text),
      'water_source_longitude': _parseDouble(_lngCtrl.text),
      'water_source_depth_meters': _parseDouble(_depthCtrl.text),
      'water_source_capacity': _parseDouble(_capacityCtrl.text),
      'water_source_notes':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'water_source_ownership': _ownership,
      'water_source_has_costs': _hasCosts,
      'water_source_status': _active ? 1 : 0,
    };

    if (_hasCosts) {
      if (_buildDate != null) {
        data['water_source_build_date'] =
            '${_buildDate!.year.toString().padLeft(4, '0')}-${_buildDate!.month.toString().padLeft(2, '0')}-${_buildDate!.day.toString().padLeft(2, '0')}';
      }
      data['water_source_build_cost'] = _parseDouble(_buildCostCtrl.text);
      data['water_source_build_invoice'] =
          _buildInvoiceCtrl.text.trim().isEmpty ? null : _buildInvoiceCtrl.text.trim();
    }

    final api = ApiService();
    final clientUuid = UuidHelper.v4();
    final queueData = <String, dynamic>{
      ...data,
      'client_uuid': clientUuid,
      if (_isEdit) 'water_source_id': widget.source!.waterSourceId,
    };

    final result = await OfflineMutation.run(
      apiCall: () => _isEdit
          ? api.patch(
              AppConstants.waterSourceDetail(widget.source!.waterSourceId),
              data: data,
            )
          : api.post(AppConstants.waterSources, data: data),
      operationType: _isEdit ? 'update_water_source' : 'create_water_source',
      queueData: queueData,
      applyOptimistic: () async {
        if (!_isEdit) {
          await LocalDatabase.appendLocalWrite(
            entityType: 'water_source',
            parentId: farm.farmId,
            clientUuid: clientUuid,
            data: queueData,
          );
        }
      },
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Erro ao guardar fonte.'),
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
            ? 'Fonte guardada offline — sincroniza quando voltares online.'
            : (_isEdit ? 'Fonte atualizada.' : 'Fonte criada.')),
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
        title: Text(_isEdit ? 'Editar fonte' : 'Nova fonte'),
      ),
      body: _loadingTypes
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _typesError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_typesError!,
                          style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loadingTypes = true;
                            _typesError = null;
                          });
                          _loadTypes();
                        },
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      const _Label(text: 'Nome *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Furo do pomar',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 16),

                      const _Label(text: 'Tipo *'),
                      const SizedBox(height: 6),
                      _buildTypeDropdown(),
                      const SizedBox(height: 16),

                      const _Label(text: 'Descrição de localização'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _locationCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Canto norte do terreno A',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label(text: 'Latitude'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _latCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                                  decoration: const InputDecoration(hintText: '38.7223'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label(text: 'Longitude'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _lngCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                                  decoration: const InputDecoration(hintText: '-9.1393'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label(text: 'Profundidade (m)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _depthCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: const InputDecoration(hintText: '0'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label(text: 'Capacidade (m³)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _capacityCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: const InputDecoration(hintText: '0'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const _Label(text: 'Notas'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Observações sobre a fonte...',
                        ),
                        maxLines: 3,
                        minLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 20),

                      _SwitchRow(
                        label: 'Fonte própria',
                        value: _ownership,
                        onChanged: (v) => setState(() => _ownership = v),
                      ),
                      _SwitchRow(
                        label: 'Ativa',
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                      _SwitchRow(
                        label: 'Regista custos de construção',
                        value: _hasCosts,
                        onChanged: (v) => setState(() => _hasCosts = v),
                      ),

                      if (_hasCosts) ...[
                        const SizedBox(height: 8),
                        const _Label(text: 'Data de construção'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickBuildDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 18, color: AppTheme.textSecondary),
                                const SizedBox(width: 10),
                                Text(
                                  _buildDate != null
                                      ? '${_buildDate!.day.toString().padLeft(2, '0')}/${_buildDate!.month.toString().padLeft(2, '0')}/${_buildDate!.year}'
                                      : 'dd/mm/aaaa',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _buildDate != null
                                        ? AppTheme.textPrimary
                                        : const Color(0xFFBDBDBD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _Label(text: 'Custo de construção (€)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _buildCostCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(hintText: '0.00'),
                        ),
                        const SizedBox(height: 16),
                        const _Label(text: 'Referência de fatura'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _buildInvoiceCtrl,
                          decoration: const InputDecoration(hintText: 'Nº fatura'),
                        ),
                      ],

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
                            : Text(_isEdit ? 'Guardar alterações' : 'Criar fonte'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: DropdownButton<int>(
        value: _selectedTypeId,
        hint: const Text('Seleciona o tipo',
            style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14)),
        items: _types
            .map((t) => DropdownMenuItem<int>(
                  value: t.waterTypeId,
                  child: Text(t.waterTypeName),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selectedTypeId = v),
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
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

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                )),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
