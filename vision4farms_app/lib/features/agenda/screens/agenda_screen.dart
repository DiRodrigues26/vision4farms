import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';
import 'agenda_create_dialog.dart';
import 'agenda_detail_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _api = ApiService();

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _events = [];
  bool _isLoading = true;
  String? _error;

  // Filtro por terreno
  int? _landFilter;
  List<dynamic> _lands = [];

  // Dias do mês que têm eventos (para mostrar dots)
  Set<int> _daysWithEvents = {};

  // Eventos pendentes (todos, em qualquer mês)
  List<dynamic> _pendingEvents = [];
  bool _loadingPending = false;

  @override
  void initState() {
    super.initState();
    _loadLands();
    _loadMonth();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) return;
    setState(() => _loadingPending = true);
    try {
      final r = await _api.get(
        AppConstants.agenda,
        params: {
          'farm_id': farm.farmId.toString(),
          'status': '0',
        },
      );
      final list = ApiService.extractResults(r.data);
      if (!mounted) return;
      setState(() {
        _pendingEvents = list;
        _loadingPending = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  void _showPendingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final pending = List<Map<String, dynamic>>.from(
          _pendingEvents.cast<Map<String, dynamic>>(),
        )..sort((a, b) {
            final da = DateTime.tryParse(a['agenda_date']?.toString() ?? '');
            final db = DateTime.tryParse(b['agenda_date']?.toString() ?? '');
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.background,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.event_note,
                          color: AppTheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${pending.length} ${pending.length == 1 ? "evento pendente" : "eventos pendentes"}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.divider),
                Expanded(
                  child: pending.isEmpty
                      ? const Center(
                          child: Text('Sem eventos pendentes',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: pending.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _buildPendingTile(sheetCtx, pending[i]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingTile(BuildContext sheetCtx, Map<String, dynamic> event) {
    final title = event['agenda_title']?.toString() ?? 'Sem título';
    final dateStr = event['agenda_date']?.toString() ?? '';
    final timeStr = event['agenda_time']?.toString() ?? '';
    final type = event['agenda_type']?.toString() ?? '';
    final landName = event['land_name']?.toString() ?? '';

    String dateDisplay = '';
    bool overdue = false;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) {
      dateDisplay =
          DateFormat('dd/MM/yyyy', 'pt_PT').format(parsed);
      final today = DateTime.now();
      overdue = parsed
          .isBefore(DateTime(today.year, today.month, today.day));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(sheetCtx).pop();
        _openDetail(event);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: overdue ? AppTheme.error : AppTheme.primary,
              width: 4,
            ),
            top: const BorderSide(color: AppTheme.divider),
            right: const BorderSide(color: AppTheme.divider),
            bottom: const BorderSide(color: AppTheme.divider),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (overdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Em atraso',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event,
                    size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  dateDisplay + (timeStr.isNotEmpty ? ' · $timeStr' : ''),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                if (type.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.label_outline,
                      size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(type,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
                if (landName.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.terrain,
                      size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(landName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadLands() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) return;
    final result = await OfflineRead.list(
      cacheKey: 'lands:farm_${farm.farmId}',
      apiCall: () => _api.get(
        AppConstants.lands,
        params: {'farm_id': farm.farmId.toString()},
      ),
    );
    if (!mounted) return;
    setState(() => _lands = result.items);
  }

  /// Carrega todos os eventos do mês focado
  Future<void> _loadMonth() async {
    setState(() { _isLoading = true; _error = null; });
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoading = false); return; }

    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final monthKey =
        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';
    final landKey = _landFilter == null ? 'all' : 'land_$_landFilter';
    final cacheKey = 'agenda:farm_${farm.farmId}:$monthKey:$landKey';

    final result = await OfflineRead.list(
      cacheKey: cacheKey,
      apiCall: () {
        final params = <String, dynamic>{
          'farm_id': farm.farmId.toString(),
          'date_from': DateFormat('yyyy-MM-dd').format(firstDay),
          'date_to': DateFormat('yyyy-MM-dd').format(lastDay),
        };
        if (_landFilter != null) params['land_id'] = _landFilter.toString();
        return _api.get(AppConstants.agenda, params: params);
      },
      localEntity: 'agenda',
      parentId: farm.farmId,
    );

    // Filtrar otimistas para o mês visível
    final filtered = result.items.where((e) {
      final dateStr = (e is Map ? e['agenda_date'] : null)?.toString() ?? '';
      try {
        final d = DateTime.parse(dateStr);
        return !d.isBefore(firstDay) && !d.isAfter(lastDay);
      } catch (_) {
        return true; // sem data válida → mostrar para evitar perder
      }
    }).toList();

    if (!mounted) return;
    setState(() {
      _events = filtered;
      _daysWithEvents = _buildDaysSet(filtered);
      _error = result.fromCache && filtered.isEmpty
          ? (result.errorMessage ?? 'Sem ligação e sem agenda guardada.')
          : null;
      _isLoading = false;
    });
  }

  Set<int> _buildDaysSet(List<dynamic> events) {
    final days = <int>{};
    for (final e in events) {
      final dateStr = e['agenda_date']?.toString() ?? '';
      try {
        days.add(DateTime.parse(dateStr).day);
      } catch (_) {}
    }
    return days;
  }

  /// Eventos do dia selecionado
  List<dynamic> get _eventsForDay {
    return _events.where((e) {
      final dateStr = e['agenda_date']?.toString() ?? '';
      try {
        final date = DateTime.parse(dateStr);
        return date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
    _loadMonth();
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
    _loadMonth();
  }

  void _selectDay(DateTime day) {
    setState(() => _selectedDate = day);
  }

  void _openCreate() async {
    final result = await showCreateAgendaDialog(context, preselectedDate: _selectedDate);
    if (result == true) {
      _loadMonth();
      _loadPending();
    }
  }

  void _openDetail(Map<String, dynamic> event) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AgendaDetailScreen(event: event),
      ),
    );
    if (result == true) {
      _loadMonth();
      _loadPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Agenda'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (context.read<FarmProvider>().selectedFarm?.canManage ?? false)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _openCreate,
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner de eventos pendentes (clicável)
          if (_pendingEvents.isNotEmpty)
            GestureDetector(
              onTap: _showPendingSheet,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_note,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary),
                          children: [
                            TextSpan(
                              text: '${_pendingEvents.length} ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary),
                            ),
                            TextSpan(
                              text: _pendingEvents.length == 1
                                  ? 'evento pendente'
                                  : 'eventos pendentes',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.primary, size: 18),
                  ],
                ),
              ),
            ),

          // Calendário mensal
          _buildCalendar(),

          // Filtro por terreno
          if (_lands.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: DropdownButton<int?>(
                  value: _landFilter,
                  hint: const Text('Todos os terrenos',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos os terrenos'),
                    ),
                    ..._lands.map((l) => DropdownMenuItem<int?>(
                      value: l['land_id'] as int,
                      child: Text(l['land_name']?.toString() ?? ''),
                    )),
                  ],
                  onChanged: (v) {
                    setState(() => _landFilter = v);
                    _loadMonth();
                  },
                  isExpanded: true,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                ),
              ),
            ),

          const Divider(height: 1, color: AppTheme.divider),

          // Lista de eventos do dia
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? _buildError()
                    : _eventsForDay.isEmpty
                        ? _buildEmptyDay()
                        : RefreshIndicator(
                            color: AppTheme.primary,
                            onRefresh: _loadMonth,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                              itemCount: _eventsForDay.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final event = _eventsForDay[i] as Map<String, dynamic>;
                                return GestureDetector(
                                  onTap: () => _openDetail(event),
                                  child: _EventCard(event: event),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ── Calendário ──────────────────────────────────────────

  Widget _buildCalendar() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Segunda = 1, Domingo = 7
    final startWeekday = firstDayOfMonth.weekday; // 1=Mon

    final monthLabel = DateFormat('MMMM yyyy', 'pt_PT').format(_focusedMonth);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: AppTheme.surface,
      child: Column(
        children: [
          // Header: < Março 2026 >
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                onPressed: _goToPreviousMonth,
              ),
              Text(
                monthLabel[0].toUpperCase() + monthLabel.substring(1),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                onPressed: _goToNextMonth,
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Dias da semana
          Row(
            children: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary)),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 6),

          // Grid de dias
          ..._buildWeekRows(startWeekday, daysInMonth, year, month),
        ],
      ),
    );
  }

  List<Widget> _buildWeekRows(int startWeekday, int daysInMonth, int year, int month) {
    final rows = <Widget>[];
    int day = 1;
    // startWeekday: 1=Mon -> offset 0, 2=Tue -> offset 1, etc.
    final offset = startWeekday - 1;

    for (int week = 0; week < 6; week++) {
      if (day > daysInMonth) break;
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final cellIndex = week * 7 + col;
        if (cellIndex < offset || day > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 36)));
        } else {
          final thisDay = day;
          final date = DateTime(year, month, thisDay);
          final isSelected = _selectedDate.year == year &&
              _selectedDate.month == month &&
              _selectedDate.day == thisDay;
          final isToday = DateTime.now().year == year &&
              DateTime.now().month == month &&
              DateTime.now().day == thisDay;
          final hasEvents = _daysWithEvents.contains(thisDay);

          cells.add(Expanded(
            child: GestureDetector(
              onTap: () => _selectDay(date),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : isToday
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$thisDay',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : isToday
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                      ),
                    ),
                    if (hasEvents && !isSelected)
                      Positioned(
                        bottom: 3,
                        child: Container(
                          width: 5, height: 5,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ));
          day++;
        }
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: cells),
      ));
    }
    return rows;
  }

  // ── Estados ─────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadMonth, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _buildEmptyDay() {
    final label = DateFormat('d MMMM', 'pt_PT').format(_selectedDate);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_outlined, size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('Nada agendado para $label',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          if (context.read<FarmProvider>().selectedFarm?.canManage ?? false)
            ElevatedButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Novo evento'),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Card de evento
// ══════════════════════════════════════════════════════════════

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  static const Map<String, IconData> _typeIcons = {
    'task': Icons.check_circle_outline,
    'visit': Icons.directions_walk_outlined,
    'meeting': Icons.groups_outlined,
    'reminder': Icons.notifications_outlined,
    'other': Icons.event_outlined,
  };

  static const Map<String, Color> _typeColors = {
    'task': Color(0xFF2E7D32),
    'visit': Color(0xFF1565C0),
    'meeting': Color(0xFF7B1FA2),
    'reminder': Color(0xFFF57C00),
    'other': Color(0xFF757575),
  };

  static const Map<int, String> _statusLabels = {
    0: 'Pendente',
    1: 'Concluído',
    2: 'Cancelado',
  };

  static const Map<int, Color> _statusColors = {
    0: Color(0xFFFFA726),
    1: Color(0xFF2E7D32),
    2: Color(0xFF757575),
  };

  @override
  Widget build(BuildContext context) {
    final title = event['agenda_title']?.toString() ?? '';
    final type = event['agenda_type']?.toString() ?? 'task';
    final status = event['agenda_status'] as int? ?? 0;
    final timeStart = event['agenda_time_start']?.toString() ?? '';
    final timeEnd = event['agenda_time_end']?.toString() ?? '';
    final allday = event['agenda_allday'] == true || event['agenda_allday'] == 1;
    final landName = event['land_name']?.toString() ?? '';
    final description = event['agenda_description']?.toString() ?? '';

    final color = _typeColors[type] ?? AppTheme.textSecondary;

    String timeLabel = '';
    if (!allday && timeStart.isNotEmpty) {
      timeLabel = timeStart.substring(0, 5);
      if (timeEnd.isNotEmpty) timeLabel += ' – ${timeEnd.substring(0, 5)}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra lateral colorida
          Container(
            width: 4, height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Conteúdo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + badge tipo
                Row(
                  children: [
                    Icon(_typeIcons[type] ?? Icons.event_outlined,
                        size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: status == 2
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                            decoration: status == 2
                                ? TextDecoration.lineThrough
                                : null,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Hora + terreno
                Row(
                  children: [
                    if (allday)
                      const Text('Dia inteiro',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
                    else if (timeLabel.isNotEmpty)
                      Text(timeLabel,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    if (landName.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Flexible(
                        child: Text(landName,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ),
                    ],
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (_statusColors[status] ?? AppTheme.textSecondary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _statusLabels[status] ?? 'Pendente',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: _statusColors[status] ?? AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
