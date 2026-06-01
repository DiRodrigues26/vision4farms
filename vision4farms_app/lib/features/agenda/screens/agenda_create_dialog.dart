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

/// Mostra o popup de criação de evento na agenda.
/// Retorna `true` se foi criado com sucesso.
Future<bool?> showCreateAgendaDialog(
  BuildContext context, {
  DateTime? preselectedDate,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _CreateAgendaDialog(preselectedDate: preselectedDate),
  );
}

class _CreateAgendaDialog extends StatefulWidget {
  final DateTime? preselectedDate;
  const _CreateAgendaDialog({this.preselectedDate});

  @override
  State<_CreateAgendaDialog> createState() => _CreateAgendaDialogState();
}

class _CreateAgendaDialogState extends State<_CreateAgendaDialog> {
  final _api = ApiService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'task';
  DateTime? _selectedDate;
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;
  bool _allDay = true;
  int? _selectedLandId;

  List<dynamic> _lands = [];
  bool _isLoadingLands = true;
  bool _isSubmitting = false;

  static const List<Map<String, dynamic>> _typeOptions = [
    {'value': 'task',     'label': 'Tarefa',   'icon': Icons.check_circle_outline},
    {'value': 'visit',    'label': 'Visita',   'icon': Icons.directions_walk_outlined},
    {'value': 'meeting',  'label': 'Reunião',  'icon': Icons.groups_outlined},
    {'value': 'reminder', 'label': 'Lembrete', 'icon': Icons.notifications_outlined},
    {'value': 'other',    'label': 'Outro',    'icon': Icons.event_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.preselectedDate ?? DateTime.now();
    _loadLands();
  }

  @override
  void dispose() {
    _titleController.dispose();
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
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? (_timeStart ?? TimeOfDay.now())
        : (_timeEnd ?? _timeStart ?? TimeOfDay.now());
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _timeStart = time;
        } else {
          _timeEnd = time;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preenche o título e a data.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isSubmitting = false); return; }

    final clientUuid = UuidHelper.v4();
    final payload = <String, dynamic>{
      'client_uuid': clientUuid,
      'farm': farm.farmId,
      'agenda_title': _titleController.text.trim(),
      'agenda_type': _selectedType,
      'agenda_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'agenda_allday': _allDay,
      if (_selectedLandId != null) 'land': _selectedLandId,
      if (_descriptionController.text.trim().isNotEmpty)
        'agenda_description': _descriptionController.text.trim(),
      if (_notesController.text.trim().isNotEmpty)
        'agenda_notes': _notesController.text.trim(),
      if (!_allDay && _timeStart != null)
        'agenda_time_start':
            '${_timeStart!.hour.toString().padLeft(2, '0')}:${_timeStart!.minute.toString().padLeft(2, '0')}:00',
      if (!_allDay && _timeEnd != null)
        'agenda_time_end':
            '${_timeEnd!.hour.toString().padLeft(2, '0')}:${_timeEnd!.minute.toString().padLeft(2, '0')}:00',
    };

    final result = await OfflineMutation.run(
      apiCall: () => _api.post(AppConstants.agendaCreate, data: payload),
      operationType: 'create_agenda',
      queueData: payload,
      applyOptimistic: () async {
        await LocalDatabase.appendLocalWrite(
          entityType: 'agenda',
          parentId: farm.farmId,
          clientUuid: clientUuid,
          data: payload,
        );
      },
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Erro ao criar evento.'),
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
            ? 'Evento guardado offline — sincroniza quando voltares online.'
            : 'Evento criado.'),
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
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Novo Evento',
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

            // Conteúdo
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo
                    const _Label(text: 'Tipo'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _typeOptions.map((t) {
                        final selected = _selectedType == t['value'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = t['value'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? AppTheme.primary : AppTheme.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(t['icon'] as IconData, size: 16,
                                    color: selected ? Colors.white : AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text(t['label'] as String,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                        color: selected ? Colors.white : AppTheme.textPrimary)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Título
                    const _Label(text: 'Título *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Reunião com técnico...',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 16),

                    // Data
                    const _Label(text: 'Data *'),
                    const SizedBox(height: 6),
                    GestureDetector(
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
                            const Icon(Icons.calendar_today_outlined, size: 18,
                                color: AppTheme.textSecondary),
                            const SizedBox(width: 10),
                            Text(
                              _selectedDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                  : 'dd/mm/aaaa',
                              style: TextStyle(fontSize: 14,
                                  color: _selectedDate != null
                                      ? AppTheme.textPrimary
                                      : const Color(0xFFBDBDBD)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dia inteiro toggle
                    Row(
                      children: [
                        const Text('Dia inteiro',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        const Spacer(),
                        Switch(
                          value: _allDay,
                          onChanged: (v) => setState(() => _allDay = v),
                          activeColor: AppTheme.primary,
                        ),
                      ],
                    ),

                    // Horas (se não dia inteiro)
                    if (!_allDay) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label(text: 'Início'),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _pickTime(true),
                                  child: _TimeBox(
                                    time: _timeStart,
                                    placeholder: '--:--',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label(text: 'Fim'),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _pickTime(false),
                                  child: _TimeBox(
                                    time: _timeEnd,
                                    placeholder: '--:--',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Terreno
                    if (!_isLoadingLands && _lands.isNotEmpty) ...[
                      const _Label(text: 'Terreno'),
                      const SizedBox(height: 6),
                      _buildDropdown<int>(
                        hint: 'Associar a um terreno (opcional)',
                        value: _selectedLandId,
                        items: _lands.map((l) => DropdownMenuItem<int>(
                          value: l['land_id'] as int,
                          child: Text(l['land_name']?.toString() ?? ''),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedLandId = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Descrição
                    const _Label(text: 'Descrição'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Detalhes do evento...',
                      ),
                      maxLines: 3,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 16),

                    // Notas
                    const _Label(text: 'Notas'),
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

                    // Botão
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          : const Text('Criar evento'),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
  );
}

class _TimeBox extends StatelessWidget {
  final TimeOfDay? time;
  final String placeholder;
  const _TimeBox({this.time, required this.placeholder});

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
          const Icon(Icons.access_time, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            time != null
                ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                : placeholder,
            style: TextStyle(fontSize: 14,
                color: time != null ? AppTheme.textPrimary : const Color(0xFFBDBDBD)),
          ),
        ],
      ),
    );
  }
}
