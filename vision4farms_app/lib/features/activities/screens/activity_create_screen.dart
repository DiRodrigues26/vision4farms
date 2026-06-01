import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

/// Mostra o popup de criação de atividade.
/// Retorna `true` se foi criada com sucesso.
Future<bool?> showCreateActivityDialog(
  BuildContext context, {
  int? preselectedLandId,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _CreateActivityDialog(preselectedLandId: preselectedLandId),
  );
}

class _CreateActivityDialog extends StatefulWidget {
  final int? preselectedLandId;
  const _CreateActivityDialog({this.preselectedLandId});

  @override
  State<_CreateActivityDialog> createState() => _CreateActivityDialogState();
}

class _CreateActivityDialogState extends State<_CreateActivityDialog> {
  final _api = ApiService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedType;
  int? _selectedLandId;
  int? _selectedYieldId;
  int _selectedPriority = 1;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  List<dynamic> _lands = [];
  List<dynamic> _yields = [];
  bool _isLoadingLands = true;
  bool _isLoadingYields = false;
  bool _isSubmitting = false;

  static const List<Map<String, String>> _activityTypes = [
    {'value': 'treatment',     'label': 'Tratamento'},
    {'value': 'fertilization', 'label': 'Fertilização'},
    {'value': 'pruning',       'label': 'Poda'},
    {'value': 'irrigation',    'label': 'Rega'},
    {'value': 'harvest',       'label': 'Colheita'},
    {'value': 'inspection',    'label': 'Inspeção'},
    {'value': 'other',         'label': 'Outra'},
  ];

  static const Map<int, String> _priorityLabels = {
    1: 'Normal',
    2: 'Alta',
    3: 'Urgente',
  };

  static const Map<int, Color> _priorityColors = {
    1: AppTheme.primary,
    2: Color(0xFFFFA726),
    3: AppTheme.error,
  };

  @override
  void initState() {
    super.initState();
    _selectedLandId = widget.preselectedLandId;
    _loadLands();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLands() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoadingLands = false); return; }
    final result = await OfflineRead.list(
      cacheKey: 'lands:farm_${farm.farmId}',
      apiCall: () => _api.get(
        AppConstants.lands,
        params: {'farm_id': farm.farmId.toString()},
      ),
    );
    if (!mounted) return;
    setState(() { _lands = result.items; _isLoadingLands = false; });
    if (_selectedLandId != null) _loadYieldsForLand(_selectedLandId!);
  }

  Future<void> _loadYieldsForLand(int landId) async {
    setState(() { _isLoadingYields = true; _selectedYieldId = null; _yields = []; });
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoadingYields = false); return; }
    final result = await OfflineRead.list(
      cacheKey: 'yields:farm_${farm.farmId}:land_$landId',
      apiCall: () => _api.get(
        AppConstants.yields,
        params: {'farm_id': farm.farmId.toString(), 'land_id': landId.toString()},
      ),
    );
    if (!mounted) return;
    setState(() { _yields = result.items; _isLoadingYields = false; });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    if (_selectedType == null || _selectedLandId == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preenche o tipo, terreno e data.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final datePart = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final hour = (_selectedTime?.hour ?? 0).toString().padLeft(2, '0');
    final minute = (_selectedTime?.minute ?? 0).toString().padLeft(2, '0');
    final plannedDateTime = '${datePart}T$hour:$minute:00';

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _activityTypes.firstWhere((t) => t['value'] == _selectedType)['label']!;

    final clientUuid = UuidHelper.v4();
    final payload = <String, dynamic>{
      'client_uuid': clientUuid,
      'farm': farm.farmId,
      'land': _selectedLandId,
      'activity_name': name,
      'activity_type': _selectedType,
      'activity_description': _descriptionController.text.trim(),
      'activity_date_planned': plannedDateTime,
      'activity_status': 0,
      'activity_priority': _selectedPriority,
      'activity_notes': _notesController.text.trim(),
      if (_selectedYieldId != null) 'yield_id': _selectedYieldId,
    };

    final result = await OfflineMutation.run(
      apiCall: () => _api.post(AppConstants.activitiesCreate, data: payload),
      operationType: 'create_activity',
      queueData: payload,
      applyOptimistic: () async {
        await LocalDatabase.appendLocalWrite(
          entityType: 'activity',
          parentId: farm.farmId,
          clientUuid: clientUuid,
          data: {
            ...payload,
            'land_id': _selectedLandId,
            'farm_id': farm.farmId,
          },
        );
      },
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Erro ao criar atividade.'),
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
            ? 'Atividade guardada offline — sincroniza quando voltares online.'
            : 'Atividade criada.'),
        backgroundColor: result.queued
            ? const Color(0xFF7B1FA2)
            : AppTheme.primary,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //  Header 
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Nova Atividade',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.divider),

            // Conteúdo scrollável 
            Flexible(
              child: _isLoadingLands
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tipo
                          const _SectionLabel(text: 'Tipo de atividade *'),
                          const SizedBox(height: 8),
                          _buildTypeSelector(),

                          const SizedBox(height: 16),

                          // Nome
                          const _SectionLabel(text: 'Nome da atividade'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Rega do pomar norte',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 16),

                          // Terreno
                          const _SectionLabel(text: 'Terreno *'),
                          const SizedBox(height: 6),
                          _buildDropdown<int>(
                            hint: 'Seleciona um terreno',
                            value: _selectedLandId,
                            items: _lands.map((l) => DropdownMenuItem<int>(
                              value: l['land_id'] as int,
                              child: Text(l['land_name']?.toString() ?? ''),
                            )).toList(),
                            onChanged: (v) {
                              setState(() => _selectedLandId = v);
                              if (v != null) _loadYieldsForLand(v);
                            },
                          ),

                          // Cultura (yield)
                          if (_yields.isNotEmpty || _isLoadingYields) ...[
                            const SizedBox(height: 16),
                            const _SectionLabel(text: 'Cultura'),
                            const SizedBox(height: 6),
                            _isLoadingYields
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primary, strokeWidth: 2)),
                                    ),
                                  )
                                : _buildDropdown<int>(
                                    hint: 'Seleciona uma cultura (opcional)',
                                    value: _selectedYieldId,
                                    items: _yields.map((y) => DropdownMenuItem<int>(
                                      value: y['yield_id'] as int,
                                      child: Text(y['yield_name']?.toString() ?? ''),
                                    )).toList(),
                                    onChanged: (v) => setState(() => _selectedYieldId = v),
                                  ),
                          ],

                          const SizedBox(height: 16),

                          // Prioridade
                          const _SectionLabel(text: 'Prioridade'),
                          const SizedBox(height: 8),
                          _buildPrioritySelector(),

                          const SizedBox(height: 16),

                          // Data e hora
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel(text: 'Data *'),
                                    const SizedBox(height: 6),
                                    _buildDateButton(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel(text: 'Hora'),
                                    const SizedBox(height: 6),
                                    _buildTimeButton(),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Descrição
                          const _SectionLabel(text: 'Descrição'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              hintText: 'Descreve o que precisa de ser feito...',
                            ),
                            maxLines: 3,
                            minLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 16),

                          // Notas
                          const _SectionLabel(text: 'Notas'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              hintText: 'Notas adicionais...',
                            ),
                            maxLines: 2,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 24),

                          // BotÃ£o criar
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                                : const Text('Criar atividade'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  //Tipo selector (chips)

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _activityTypes.map((t) {
        final selected = _selectedType == t['value'];
        return GestureDetector(
          onTap: () => setState(() => _selectedType = t['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.divider,
              ),
            ),
            child: Text(
              t['label']!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  //Priority selector

  Widget _buildPrioritySelector() {
    return Row(
      children: [1, 2, 3].map((p) {
        final selected = _selectedPriority == p;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPriority = p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: p < 3 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? _priorityColors[p]
                    : _priorityColors[p]!.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? _priorityColors[p]!
                      : _priorityColors[p]!.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  _priorityLabels[p]!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _priorityColors[p],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  //Date button 

  Widget _buildDateButton() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'dd/mm/aaaa',
                style: TextStyle(
                  fontSize: 14,
                  color: _selectedDate != null
                      ? AppTheme.textPrimary
                      : const Color(0xFFBDBDBD),
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  //Time button

  Widget _buildTimeButton() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedTime != null
                    ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                    : '--:--',
                style: TextStyle(
                  fontSize: 14,
                  color: _selectedTime != null
                      ? AppTheme.textPrimary
                      : const Color(0xFFBDBDBD),
                ),
              ),
            ),
            const Icon(Icons.access_time_outlined,
                size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  //Dropdown 

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
  );
}

