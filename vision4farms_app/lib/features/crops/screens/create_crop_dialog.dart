import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/local_database.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';

class CreateCropDialog extends StatefulWidget {
  const CreateCropDialog({super.key});

  @override
  State<CreateCropDialog> createState() => _CreateCropDialogState();
}

class _CreateCropDialogState extends State<CreateCropDialog> {
  final _api      = ApiService();
  final _nameCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();

  // Dados carregados da API
  List<dynamic> _lands    = [];
  List<dynamic> _crops    = [];
  List<dynamic> _varieties = [];

  int? _selectedLandId;
  int? _selectedCropId;
  int? _selectedVarietyId;
  String? _selectedMethod;

  bool _loadingLands  = true;
  bool _loadingCrops  = true;
  bool _submitting    = false;
  String? _error;

  static const List<Map<String,String>> _methods = [
    {'value': 'convencional',  'label': 'Convencional'},
    {'value': 'biologico',     'label': 'Biológico'},
    {'value': 'integrado',     'label': 'Produção Integrada'},
    {'value': 'hidroponia',    'label': 'Hidroponia'},
    {'value': 'permacultura',  'label': 'Permacultura'},
    {'value': 'outro',         'label': 'Outro'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) return;

    final landsResult = OfflineRead.list(
      cacheKey: 'lands:farm_${farm.farmId}',
      apiCall: () => _api.get(
        AppConstants.lands,
        params: {'farm_id': farm.farmId.toString()},
      ),
    );
    final cropsResult = OfflineRead.list(
      cacheKey: 'crops:all',
      apiCall: () => _api.get(AppConstants.crops),
    );

    final results = await Future.wait([landsResult, cropsResult]);
    if (!mounted) return;
    setState(() {
      _lands         = results[0].items;
      _crops         = results[1].items;
      _loadingLands  = false;
      _loadingCrops  = false;
    });
  }

  void _onCropSelected(int? cropId) {
    setState(() {
      _selectedCropId  = cropId;
      _selectedVarietyId = null;
      _varieties = [];
      if (cropId != null) {
        final crop = _crops.firstWhere(
            (c) => c['crop_id'] == cropId, orElse: () => null);
        if (crop != null && crop['varieties'] != null) {
          _varieties = crop['varieties'] as List;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLandId == null) {
      setState(() => _error = 'Seleciona um terreno');
      return;
    }
    if (_selectedCropId == null) {
      setState(() => _error = 'Seleciona uma cultura');
      return;
    }
    if (_selectedMethod == null) {
      setState(() => _error = 'Seleciona um método de produção');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final farm = context.read<FarmProvider>().selectedFarm!;

      double size = 0;
      if (_sizeCtrl.text.isNotEmpty) {
        size = double.tryParse(_sizeCtrl.text.replaceAll(',', '.')) ?? 0;
      }

      // Validar soma dos tamanhos das culturas vs tamanho do terreno
      final land = _lands.firstWhere(
          (l) => l['land_id'] == _selectedLandId,
          orElse: () => null);
      final landSize = land != null
          ? double.tryParse(land['land_size']?.toString() ?? '')
          : null;

      if (landSize != null && landSize > 0 && size > 0) {
        final yieldsRes = await _api.get(
          AppConstants.yields,
          params: {'land_id': _selectedLandId.toString()},
        );
        final existing = ApiService.extractResults(yieldsRes.data);
        double existingTotal = 0;
        for (final y in existing) {
          existingTotal +=
              double.tryParse(y['yield_size']?.toString() ?? '') ?? 0;
        }
        final totalAfter = existingTotal + size;
        if (totalAfter > landSize) {
          if (!mounted) return;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Tamanho excede o terreno'),
              content: Text(
                'O total de culturas (${totalAfter.toStringAsFixed(3)} ha) '
                'ultrapassa o tamanho do terreno (${landSize.toStringAsFixed(3)} ha).\n\n'
                'Deseja continuar mesmo assim?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );
          if (confirm != true) {
            if (mounted) setState(() => _submitting = false);
            return;
          }
        }
      }

      // Buscar nome da cultura para usar como yield_name
      final cropName = _crops.firstWhere(
          (c) => c['crop_id'] == _selectedCropId,
          orElse: () => {'crop_name': 'Cultura'})['crop_name']?.toString() ?? 'Cultura';

      final yieldName = _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : cropName;

      final clientUuid = UuidHelper.v4();
      final payload = <String, dynamic>{
        'client_uuid':  clientUuid,
        'yield_name':   yieldName,
        'farm':         farm.farmId,
        'land':         _selectedLandId,
        'crop':         _selectedCropId,
        if (_selectedVarietyId != null) 'variety': _selectedVarietyId,
        'yield_method': _selectedMethod,
        'yield_size':   size > 0 ? size : 0.001,
        'yield_status': 1,
      };

      final result = await OfflineMutation.run(
        apiCall: () => _api.post(AppConstants.yieldsCreate, data: payload),
        operationType: 'create_yield',
        queueData: payload,
        applyOptimistic: () async {
          await LocalDatabase.appendLocalWrite(
            entityType: 'yield',
            parentId: _selectedLandId,
            clientUuid: clientUuid,
            data: {
              ...payload,
              'land_id': _selectedLandId,
              'crop_name': cropName,
            },
          );
        },
      );

      if (!mounted) return;
      if (!result.success) {
        setState(() => _error = result.errorMessage ?? 'Erro ao criar cultura.');
        return;
      }

      context.read<SyncProvider>().refreshCounts();
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.queued
              ? 'Cultura guardada offline — sincroniza quando voltares online.'
              : 'Cultura criada com sucesso!'),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Erro ao criar cultura. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text('Nova Cultura',
                          style: TextStyle(fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close,
                          color: AppTheme.textSecondary, size: 22),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Nome (opcional — usa nome da cultura se vazio)
                _FieldLabel(label: 'Nome'),
                const SizedBox(height: 6),
                _InputField(
                  controller: _nameCtrl,
                  hint: 'Insira o nome',
                ),

                const SizedBox(height: 16),

                // Terreno *
                _FieldLabel(label: 'Terreno'),
                const SizedBox(height: 6),
                _loadingLands
                    ? const _LoadingField()
                    : _DropdownField<int>(
                        hint: 'Selecione um terreno',
                        value: _selectedLandId,
                        items: _lands.map((l) => DropdownMenuItem<int>(
                          value: l['land_id'] as int? ?? 0,
                          child: Text(l['land_name']?.toString() ?? ''),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedLandId = v),
                      ),

                const SizedBox(height: 16),

                // Cultura *
                _FieldLabel(label: 'Cultura'),
                const SizedBox(height: 6),
                _loadingCrops
                    ? const _LoadingField()
                    : _DropdownField<int>(
                        hint: 'Selecione uma cultura',
                        value: _selectedCropId,
                        items: _crops.map((c) => DropdownMenuItem<int>(
                          value: c['crop_id'] as int? ?? 0,
                          child: Text(c['crop_name']?.toString() ?? ''),
                        )).toList(),
                        onChanged: _onCropSelected,
                      ),

                const SizedBox(height: 16),

                // Variedade (só aparece quando a cultura tem variedades)
                if (_selectedCropId != null) ...[
                  const _FieldLabel(label: 'Variedade'),
                  const SizedBox(height: 6),
                  _varieties.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: const Text(
                            'Esta cultura não tem variedades disponíveis.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        )
                      : _DropdownField<int>(
                          hint: 'Selecione a variedade',
                          value: _selectedVarietyId,
                          items: _varieties
                              .where((v) => v['variety_id'] != null)
                              .map((v) => DropdownMenuItem<int>(
                                    value: v['variety_id'] as int,
                                    child: Text(
                                        v['variety_name']?.toString() ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedVarietyId = v),
                        ),
                  const SizedBox(height: 16),
                ],

                // Método de produção *
                _FieldLabel(label: 'Método de produção'),
                const SizedBox(height: 6),
                _DropdownField<String>(
                  hint: 'Selecione um método de produção',
                  value: _selectedMethod,
                  items: _methods.map((m) => DropdownMenuItem<String>(
                    value: m['value'],
                    child: Text(m['label']!),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedMethod = v),
                ),

                const SizedBox(height: 16),

                // Área (ha)
                const _FieldLabel(label: 'Área (ha)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _sizeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Ex: 2.5',
                    hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.divider)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 13)),
                ],

                const SizedBox(height: 24),

                // Botão Adicionar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Adicionar',
                                  style: TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _InputField({
    required this.controller, required this.hint,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.divider)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.divider)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    ),
  );
}

class _DropdownField<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.hint, required this.value,
    required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
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

class _LoadingField extends StatelessWidget {
  const _LoadingField();
  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.divider),
    ),
    child: const Center(
      child: SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 2)),
    ),
  );
}