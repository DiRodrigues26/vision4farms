import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/api_service.dart';
import '../../core/services/local_database.dart';
import '../../core/services/offline_mutation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/utils/uuid_helper.dart';
import '../theme/app_theme.dart';

enum AnalysisKind { soil, yield_ }

class _NutrientGroup {
  final String title;
  final List<({String key, String label})> fields;
  const _NutrientGroup(this.title, this.fields);
}

const _soilGroups = <_NutrientGroup>[
  _NutrientGroup('Físico-químicos', [
    (key: 'soil_analysis_ph_h20', label: 'pH (H₂O)'),
    (key: 'soil_analysis_ph_cacl2', label: 'pH (CaCl₂)'),
    (key: 'soil_analysis_acidifier', label: 'Acidificação'),
    (key: 'soil_analysis_conductivity', label: 'Condutividade'),
    (key: 'soil_analysis_organic_matter', label: 'Matéria orgânica'),
    (key: 'soil_analysis_total_nitrogen', label: 'Azoto total'),
    (key: 'soil_analysis_carbon_nitrogen', label: 'Relação C/N'),
  ]),
  _NutrientGroup('Macronutrientes', [
    (key: 'soil_analysis_phosphor', label: 'Fósforo (P)'),
    (key: 'soil_analysis_potassium', label: 'Potássio (K)'),
    (key: 'soil_analysis_calcium', label: 'Cálcio (Ca)'),
    (key: 'soil_analysis_magnesium', label: 'Magnésio (Mg)'),
    (key: 'soil_analysis_sulfur', label: 'Enxofre (S)'),
  ]),
  _NutrientGroup('Micronutrientes e secundários', [
    (key: 'soil_analysis_iron', label: 'Ferro (Fe)'),
    (key: 'soil_analysis_manganese', label: 'Manganês (Mn)'),
    (key: 'soil_analysis_manganese_activity', label: 'Atividade Mn'),
    (key: 'soil_analysis_boron', label: 'Boro (B)'),
    (key: 'soil_analysis_copper', label: 'Cobre (Cu)'),
    (key: 'soil_analysis_zinc', label: 'Zinco (Zn)'),
    (key: 'soil_analysis_molybdenum', label: 'Molibdénio (Mo)'),
    (key: 'soil_analysis_sodium', label: 'Sódio (Na)'),
    (key: 'soil_analysis_nickel', label: 'Níquel (Ni)'),
    (key: 'soil_analysis_cobalt', label: 'Cobalto (Co)'),
  ]),
];

const _foliarGroups = <_NutrientGroup>[
  _NutrientGroup('Macronutrientes', [
    (key: 'yield_analysis_nitrogen_total', label: 'Azoto total (N)'),
    (key: 'yield_analysis_phosphorus', label: 'Fósforo (P)'),
    (key: 'yield_analysis_potassium', label: 'Potássio (K)'),
    (key: 'yield_analysis_calcium', label: 'Cálcio (Ca)'),
    (key: 'yield_analysis_magnesium', label: 'Magnésio (Mg)'),
    (key: 'yield_analysis_sulfur', label: 'Enxofre (S)'),
  ]),
  _NutrientGroup('Micronutrientes', [
    (key: 'yield_analysis_iron', label: 'Ferro (Fe)'),
    (key: 'yield_analysis_manganese', label: 'Manganês (Mn)'),
    (key: 'yield_analysis_boro', label: 'Boro (B)'),
    (key: 'yield_analysis_cobre', label: 'Cobre (Cu)'),
    (key: 'yield_analysis_zinc', label: 'Zinco (Zn)'),
    (key: 'yield_analysis_molybdenum', label: 'Molibdénio (Mo)'),
    (key: 'yield_analysis_sodium', label: 'Sódio (Na)'),
    (key: 'yield_analysis_aluminum', label: 'Alumínio (Al)'),
  ]),
];

class AddAnalysisDialog extends StatefulWidget {
  final ApiService apiService;
  final AnalysisKind kind;

  /// `land_id` (solo) ou `yield_id` (foliar).
  final int targetId;

  const AddAnalysisDialog({
    super.key,
    required this.apiService,
    required this.kind,
    required this.targetId,
  });

  @override
  State<AddAnalysisDialog> createState() => _AddAnalysisDialogState();

  static Future<bool?> show({
    required BuildContext context,
    required ApiService apiService,
    required AnalysisKind kind,
    required int targetId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AddAnalysisDialog(
        apiService: apiService,
        kind: kind,
        targetId: targetId,
      ),
    );
  }
}

class _AddAnalysisDialogState extends State<AddAnalysisDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sampleCtrl = TextEditingController();
  final Map<String, TextEditingController> _nutrientCtrls = {};
  DateTime _date = DateTime.now();
  PlatformFile? _pickedFile;
  bool _submitting = false;
  String? _error;

  List<_NutrientGroup> get _groups =>
      widget.kind == AnalysisKind.soil ? _soilGroups : _foliarGroups;

  @override
  void initState() {
    super.initState();
    for (final g in _groups) {
      for (final f in g.fields) {
        _nutrientCtrls[f.key] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _sampleCtrl.dispose();
    for (final c in _nutrientCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _title => widget.kind == AnalysisKind.soil
      ? 'Nova análise de solo'
      : 'Nova análise foliar';

  String get _endpoint => widget.kind == AnalysisKind.soil
      ? AppConstants.soilAnalysisCreate(widget.targetId)
      : AppConstants.foliarAnalysisCreate(widget.targetId);

  String get _dateField => widget.kind == AnalysisKind.soil
      ? 'soil_analysis_date'
      : 'yield_analysis_date';

  String get _sampleField => widget.kind == AnalysisKind.soil
      ? 'soil_analysis_sample'
      : 'yield_analysis_sample';

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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final fields = <String, dynamic>{
      _dateField: DateFormat('yyyy-MM-dd').format(_date),
      _sampleField: _sampleCtrl.text.trim(),
    };
    _nutrientCtrls.forEach((key, ctrl) {
      final v = ctrl.text.trim();
      if (v.isNotEmpty) fields[key] = v;
    });

    final hasFile = _pickedFile != null && _pickedFile!.path != null;
    final clientUuid = UuidHelper.v4();
    final isSoil = widget.kind == AnalysisKind.soil;

    final queueData = <String, dynamic>{
      ...fields,
      'client_uuid': clientUuid,
      if (isSoil) 'land_id': widget.targetId,
      if (!isSoil) 'yield_id': widget.targetId,
      if (hasFile) '_file_path': _pickedFile!.path,
    };

    final result = await OfflineMutation.run(
      apiCall: () async {
        if (hasFile) {
          final formFields = {...fields};
          formFields['file'] = await MultipartFile.fromFile(
            _pickedFile!.path!,
            filename: _pickedFile!.name,
          );
          return widget.apiService
              .post(_endpoint, data: FormData.fromMap(formFields));
        }
        return widget.apiService.post(_endpoint, data: fields);
      },
      operationType:
          isSoil ? 'create_soil_analysis' : 'create_foliar_analysis',
      queueData: queueData,
      applyOptimistic: () async {
        await LocalDatabase.appendLocalWrite(
          entityType: isSoil ? 'soil_analysis' : 'foliar_analysis',
          parentId: widget.targetId,
          clientUuid: clientUuid,
          data: queueData,
          photoPath: hasFile ? _pickedFile!.path : null,
        );
      },
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _submitting = false;
        _error = result.errorMessage ?? 'Erro ao guardar análise.';
      });
      return;
    }

    context.read<SyncProvider>().refreshCounts();
    Navigator.of(context).pop(true);
    if (result.queued) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Análise guardada offline — sincroniza quando voltares online.'),
          backgroundColor: Color(0xFF7B1FA2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(_date);
    final fileLabel = _pickedFile?.name ?? 'Nenhum ficheiro selecionado';
    final fileSize = _pickedFile != null
        ? ' (${(_pickedFile!.size / 1024).toStringAsFixed(0)} KB)'
        : '';

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
                Text(_title,
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
                              prefixIcon:
                                  Icon(Icons.calendar_today_outlined, size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child:
                                Text(dateLabel, style: const TextStyle(fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _sampleCtrl,
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Amostra / Referência',
                            hintText: 'Ex: Lote A — canto NW',
                            prefixIcon: Icon(Icons.label_outline, size: 20),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo obrigatório'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Valores (opcionais — basta preencher o que tiver)',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ..._groups.map((g) => _NutrientSection(
                              title: g.title,
                              fields: g.fields,
                              controllers: _nutrientCtrls,
                              enabled: !_submitting,
                            )),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.divider),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ficheiro PDF (opcional)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    _pickedFile != null
                                        ? Icons.picture_as_pdf
                                        : Icons.picture_as_pdf_outlined,
                                    color: _pickedFile != null
                                        ? const Color(0xFFD32F2F)
                                        : AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('$fileLabel$fileSize',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: _submitting ? null : _pickFile,
                                    icon: const Icon(Icons.attach_file, size: 18),
                                    label: Text(_pickedFile == null
                                        ? 'Anexar PDF'
                                        : 'Trocar'),
                                  ),
                                  if (_pickedFile != null)
                                    TextButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : () => setState(
                                              () => _pickedFile = null),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Remover'),
                                      style: TextButton.styleFrom(
                                          foregroundColor:
                                              AppTheme.textSecondary),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style:
                          FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar'),
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

class _NutrientSection extends StatelessWidget {
  final String title;
  final List<({String key, String label})> fields;
  final Map<String, TextEditingController> controllers;
  final bool enabled;

  const _NutrientSection({
    required this.title,
    required this.fields,
    required this.controllers,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(title,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        collapsedShape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fields.map((f) {
              final width = (MediaQuery.of(context).size.width - 80) / 2;
              return SizedBox(
                width: width.clamp(140.0, 240.0),
                child: TextFormField(
                  controller: controllers[f.key],
                  enabled: enabled,
                  decoration: InputDecoration(
                    labelText: f.label,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
