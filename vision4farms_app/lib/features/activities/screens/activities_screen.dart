import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/local_database.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../shared/theme/app_theme.dart';
import 'activity_create_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final _api = ApiService();
  final _calendarController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _activities = [];
  bool _isLoading = true;

  // null = sem filtro, 3 = Alta, 2 = Média, 1 = Baixa
  int? _priorityFilter;

  // Filtro por terreno
  int? _landFilter;
  List<dynamic> _lands = [];

  // Calendário: 60 dias para trás + 60 para a frente, ancorado em hoje.
  static const int _daysBack = 60;
  static const int _daysForward = 60;
  static const double _dayItemWidth = 42;
  static const double _dayItemSpacing = 6;
  static const double _calendarHorizontalPadding = 20;

  late final DateTime _calendarAnchor;
  List<DateTime> get _calendarDays => List.generate(
        _daysBack + _daysForward + 1,
        (i) => _calendarAnchor.add(Duration(days: i - _daysBack)),
      );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarAnchor = DateTime(now.year, now.month, now.day);
    _loadLands();
    _loadActivities();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDay());
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDay() {
    if (!_calendarController.hasClients) return;
    final selected = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day);
    final index = selected.difference(_calendarAnchor).inDays + _daysBack;
    final viewport = _calendarController.position.viewportDimension;
    final target = index * (_dayItemWidth + _dayItemSpacing)
        - (viewport / 2) + (_dayItemWidth / 2);
    final clamped = target
        .clamp(0.0, _calendarController.position.maxScrollExtent)
        .toDouble();
    _calendarController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
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

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoading = false); return; }
    final landKey = _landFilter == null ? 'all' : 'land_$_landFilter';
    final result = await OfflineRead.list(
      cacheKey: 'activities:farm_${farm.farmId}:$landKey',
      apiCall: () {
        final params = <String, dynamic>{'farm_id': farm.farmId.toString()};
        if (_landFilter != null) params['land_id'] = _landFilter.toString();
        return _api.get(AppConstants.activities, params: params);
      },
      localEntity: 'activity',
      parentId: farm.farmId,
    );
    // Persistir as atividades cache nativo (usado por outras telas)
    await LocalDatabase.saveActivities(farm.farmId, result.items);
    if (!mounted) return;
    setState(() {
      _activities = result.items;
      _isLoading = false;
    });
  }

  // ── Actividades do dia selecionado (baseado em activity_date_planned) ──
  List<dynamic> get _activitiesForDay {
    return _activities.where((a) {
      final dateStr = a['activity_date_planned']?.toString() ?? '';
      try {
        final date = DateTime.parse(dateStr);
        return date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final aStr = a['activity_date_planned']?.toString() ?? '';
        final bStr = b['activity_date_planned']?.toString() ?? '';
        return aStr.compareTo(bStr);
      });
  }

  // ── Filtered list (por prioridade sobre o dia) ──────────────
  List<dynamic> get _filteredActivities {
    final dayActivities = _activitiesForDay;
    if (_priorityFilter == null) return dayActivities;
    return dayActivities
        .where((a) => (a['activity_priority'] as int? ?? 1) == _priorityFilter)
        .toList();
  }

  // ── Contadores do dia selecionado (não do total!) ────────────
  int get _highPriorityCount => _activitiesForDay
      .where((a) => (a['activity_priority'] as int? ?? 1) == 3).length;
  int get _mediumPriorityCount => _activitiesForDay
      .where((a) => (a['activity_priority'] as int? ?? 1) == 2).length;
  int get _lowPriorityCount => _activitiesForDay
      .where((a) => (a['activity_priority'] as int? ?? 1) == 1).length;

  // ── Verifica se um dia tem atividades ───────────────────────
  bool _dayHasActivities(DateTime day) {
    return _activities.any((a) {
      final dateStr = a['activity_date_planned']?.toString() ?? '';
      try {
        final date = DateTime.parse(dateStr);
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      } catch (_) {
        return false;
      }
    });
  }

  // ── Verifica se um dia tem atividades em atraso ──────────────
  bool _dayHasOverdue(DateTime day) {
    final today = DateTime.now();
    final isInPast = day.year < today.year ||
        (day.year == today.year && day.month < today.month) ||
        (day.year == today.year &&
            day.month == today.month &&
            day.day < today.day);
    if (!isInPast) return false;
    return _activities.any((a) {
      final status = a['activity_status'] as int? ?? 0;
      if (status != 0) return false; // só pendentes
      final dateStr = a['activity_date_planned']?.toString() ?? '';
      try {
        final date = DateTime.parse(dateStr);
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      } catch (_) {
        return false;
      }
    });
  }

  // ── Total de atividades pendentes com data no passado ────────
  int get _totalOverdue {
    final today = DateTime.now();
    return _activities.where((a) {
      final status = a['activity_status'] as int? ?? 0;
      if (status != 0) return false;
      final dateStr = a['activity_date_planned']?.toString() ?? '';
      try {
        final date = DateTime.parse(dateStr);
        return date.isBefore(DateTime(today.year, today.month, today.day));
      } catch (_) {
        return false;
      }
    }).length;
  }

  // ── Agrupar por prioridade para mostrar secções ──────────────
  Map<int, List<dynamic>> get _groupedByPriority {
    final Map<int, List<dynamic>> groups = {3: [], 2: [], 1: []};
    for (final a in _filteredActivities) {
      final p = a['activity_priority'] as int? ?? 1;
      groups[p] ??= [];
      groups[p]!.add(a);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text('Atividades',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  if (context.read<FarmProvider>().selectedFarm?.canContribute ?? false)
                    ElevatedButton.icon(
                      onPressed: () => _showNewActivityModal(context),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Nova'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Banner de atividades em atraso ───────────────
            if (_totalOverdue > 0 && !_isLoading)
              GestureDetector(
                onTap: () => _showOverdueActivitiesSheet(context),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textPrimary),
                            children: [
                              TextSpan(
                                text: '$_totalOverdue ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.error),
                              ),
                              TextSpan(
                                text: _totalOverdue == 1
                                    ? 'atividade em atraso'
                                    : 'atividades em atraso',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.error, size: 18),
                    ],
                  ),
                ),
              ),

            // ── Mês e ano ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                DateFormat('MMMM, yyyy', 'pt_PT').format(_selectedDate),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
            ),

            const SizedBox(height: 12),

            // ── Calendário horizontal (scrollável) ───────────
            SizedBox(
              height: 64,
              child: ListView.separated(
                controller: _calendarController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: _calendarHorizontalPadding),
                itemCount: _calendarDays.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: _dayItemSpacing),
                itemBuilder: (context, index) {
                  final day = _calendarDays[index];
                  final isSelected = day.day == _selectedDate.day &&
                      day.month == _selectedDate.month &&
                      day.year == _selectedDate.year;
                  final isToday = day.day == DateTime.now().day &&
                      day.month == DateTime.now().month &&
                      day.year == DateTime.now().year;
                  final hasActivities = _dayHasActivities(day);
                  final hasOverdue = _dayHasOverdue(day);

                  // Cor do dot: vermelho para atrasos, verde para pendentes normais
                  final dotColor = isSelected
                      ? Colors.white70
                      : hasOverdue
                          ? AppTheme.error
                          : AppTheme.primary;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = day;
                        _priorityFilter = null;
                      });
                      _scrollToSelectedDay();
                    },
                    child: Container(
                      width: _dayItemWidth,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (hasOverdue ? AppTheme.error : AppTheme.primary)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? (hasOverdue ? AppTheme.error : AppTheme.primary)
                              : hasOverdue
                                  ? AppTheme.error.withValues(alpha: 0.5)
                                  : isToday
                                      ? AppTheme.primaryLight
                                      : AppTheme.divider,
                          width: (isToday && !isSelected) || hasOverdue ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E', 'pt_PT').format(day),
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected ? Colors.white70 : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            day.day.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasActivities
                                  ? dotColor
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 14),

            // ── Label ────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Atividades do dia',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
            ),

            const SizedBox(height: 10),

            // ── Filtro por terreno ────────────────────────────
            if (_lands.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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
                      _loadActivities();
                    },
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                    style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                  ),
                ),
              ),

            // ── Contadores de prioridade (clicáveis!) ────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _PriorityCounter(
                    count: _highPriorityCount,
                    label: 'Alta\nPrioridade',
                    color: AppTheme.error,
                    isActive: _priorityFilter == 3,
                    onTap: () => setState(() =>
                        _priorityFilter = _priorityFilter == 3 ? null : 3),
                  ),
                  const SizedBox(width: 10),
                  _PriorityCounter(
                    count: _mediumPriorityCount,
                    label: 'Média\nPrioridade',
                    color: const Color(0xFFFFA726),
                    isActive: _priorityFilter == 2,
                    onTap: () => setState(() =>
                        _priorityFilter = _priorityFilter == 2 ? null : 2),
                  ),
                  const SizedBox(width: 10),
                  _PriorityCounter(
                    count: _lowPriorityCount,
                    label: 'Baixa\nPrioridade',
                    color: AppTheme.primary,
                    isActive: _priorityFilter == 1,
                    onTap: () => setState(() =>
                        _priorityFilter = _priorityFilter == 1 ? null : 1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Lista agrupada por prioridade ─────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _activitiesForDay.isEmpty
                      ? const Center(
                          child: Text('Sem atividades para este dia',
                              style: TextStyle(color: AppTheme.textSecondary)))
                      : _filteredActivities.isEmpty
                          ? const Center(
                              child: Text('Sem atividades com esta prioridade',
                                  style: TextStyle(color: AppTheme.textSecondary)))
                          : RefreshIndicator(
                              color: AppTheme.primary,
                              onRefresh: _loadActivities,
                              child: _buildGroupedList(),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = _groupedByPriority;
    final sections = <Widget>[];

    final labels = {3: 'Alta Prioridade', 2: 'Média Prioridade', 1: 'Baixa Prioridade'};
    final colors = {3: AppTheme.error, 2: const Color(0xFFFFA726), 1: AppTheme.primary};

    for (final priority in [3, 2, 1]) {
      final items = groups[priority] ?? [];
      if (items.isEmpty) continue;

      sections.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Text(
          labels[priority]!,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors[priority],
          ),
        ),
      ));

      for (final activity in items) {
        sections.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ActivityRow(
            activity: activity,
            borderColor: colors[priority]!,
            onComplete: () => _completeActivity(activity),
            onTap: () => _showActivityDetail(context, activity),
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: sections,
    );
  }

  Future<void> _completeActivity(Map<String, dynamic> activity) async {
    final activityId = activity['activity_id'] as int?;
    if (activityId == null || activityId < 0) {
      // Atividade ainda não sincronizada (ID local). Para a marcar como
      // concluída, alteramos a sua escrita otimista directamente.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta atividade ainda não foi sincronizada — '
              'só pode ser concluída depois de voltar online.'),
        ),
      );
      return;
    }
    final payload = <String, dynamic>{
      'activity_id': activityId,
      'activity_status': 1,
    };
    final result = await OfflineMutation.run(
      apiCall: () => _api.patch(
        AppConstants.activityDetail(activityId),
        data: {'activity_status': 1},
      ),
      operationType: 'complete_activity',
      queueData: payload,
      applyOptimistic: () async {
        // Atualiza a entrada na lista local imediatamente
        final updated = _activities.map((a) {
          if (a is Map && a['activity_id'] == activityId) {
            return {...a, 'activity_status': 1};
          }
          return a;
        }).toList();
        if (mounted) setState(() => _activities = updated);
      },
    );
    if (!mounted) return;
    if (result.queued) {
      context.read<SyncProvider>().refreshCounts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marcado offline — sincroniza quando voltares online.'),
          backgroundColor: Color(0xFF7B1FA2),
        ),
      );
    }
    await _loadActivities();
  }

  void _showActivityDetail(BuildContext context, Map<String, dynamic> activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityDetailSheet(
        activity: activity,
        onComplete: () async {
          Navigator.pop(context);
          await _completeActivity(activity);
        },
      ),
    );
  }

  /// Mostra um bottom sheet com TODAS as atividades em atraso,
  /// agrupadas e ordenadas. Tocar numa abre o detalhe.
  void _showOverdueActivitiesSheet(BuildContext context) {
    final today = DateTime.now();
    final overdue = _activities.where((a) {
      final status = a['activity_status'] as int? ?? 0;
      if (status != 0) return false;
      final d = DateTime.tryParse(
          a['activity_date_planned']?.toString() ?? '');
      return d != null &&
          d.isBefore(DateTime(today.year, today.month, today.day));
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(
            a['activity_date_planned']?.toString() ?? '');
        final db = DateTime.tryParse(
            b['activity_date_planned']?.toString() ?? '');
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da); // mais recentes primeiro
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Pega de arrastar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Cabeçalho
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppTheme.error, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${overdue.length} ${overdue.length == 1 ? "atividade em atraso" : "atividades em atraso"}',
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
              // Lista
              Expanded(
                child: overdue.isEmpty
                    ? const Center(
                        child: Text(
                          'Sem atividades em atraso',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: overdue.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildOverdueListTile(sheetCtx, overdue[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverdueListTile(
      BuildContext sheetCtx, Map<String, dynamic> activity) {
    final name = activity['activity_name']?.toString() ?? 'Sem nome';
    final landName = activity['land_name']?.toString() ?? '';
    final priority = activity['activity_priority'] as int? ?? 1;
    final priorityColor = priority == 3
        ? AppTheme.error
        : priority == 2
            ? const Color(0xFFF57C00)
            : AppTheme.primary;
    final dateStr = (() {
      final d = DateTime.tryParse(
          activity['activity_date_planned']?.toString() ?? '');
      return d != null ? DateFormat('dd/MM/yyyy', 'pt_PT').format(d) : '';
    })();
    final daysLate = (() {
      final d = DateTime.tryParse(
          activity['activity_date_planned']?.toString() ?? '');
      if (d == null) return 0;
      final today = DateTime.now();
      return DateTime(today.year, today.month, today.day)
          .difference(DateTime(d.year, d.month, d.day))
          .inDays;
    })();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(sheetCtx).pop();
        _showActivityDetail(context, activity);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: priorityColor, width: 4),
            top: BorderSide(color: AppTheme.divider),
            right: BorderSide(color: AppTheme.divider),
            bottom: BorderSide(color: AppTheme.divider),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysLate == 1
                        ? '1 dia'
                        : daysLate > 1
                            ? '$daysLate dias'
                            : 'hoje',
                    style: const TextStyle(
                      fontSize: 11,
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
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                if (landName.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.terrain,
                      size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(landName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNewActivityModal(BuildContext context) {
    showCreateActivityDialog(context).then((created) {
      if (created == true) _loadActivities();
    });
  }
}

// ── Contador de prioridade (clicável) ─────────────────────────

class _PriorityCounter extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _PriorityCounter({
    required this.count,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                : [],
          ),
          child: Column(
            children: [
              Text('$count',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.white,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row de atividade com borda colorida ───────────────────────

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> activity;
  final Color borderColor;
  final VoidCallback onComplete;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.activity,
    required this.borderColor,
    required this.onComplete,
    required this.onTap,
  });

  String _translateType(String type) {
    const map = {
      'irrigation': 'Rega', 'fertilization': 'Fertilização',
      'pruning': 'Poda', 'harvest': 'Colheita',
      'treatment': 'Tratamento', 'inspection': 'Inspeção',
      'maintenance': 'Manutenção', 'other': 'Outra',
    };
    return map[type] ?? (type.isNotEmpty ? type[0].toUpperCase() + type.substring(1) : type);
  }

  @override
  Widget build(BuildContext context) {
    final name     = activity['activity_name']?.toString() ?? '';
    final type     = activity['activity_type']?.toString() ?? '';
    final landName = activity['land_name']?.toString() ?? '';
    final assignee = activity['assigned_to']?.toString() ?? '';
    final isDone   = (activity['activity_status'] as int? ?? 0) == 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            // Barra colorida lateral
            Container(
              width: 4,
              height: 62,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : _translateType(type),
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(landName,
                              style: const TextStyle(fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    if (assignee.isNotEmpty) ...[
                      Text(assignee,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 10),
                    ],
                    Builder(
                      builder: (ctx) {
                        final canAct = ctx.read<FarmProvider>().selectedFarm?.canContribute ?? false;
                        if (!canAct && !isDone) {
                          return const SizedBox.shrink();
                        }
                        return GestureDetector(
                          onTap: isDone ? null : onComplete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDone ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isDone ? 'Feito' : 'Concluir',
                              style: TextStyle(
                                color: isDone ? AppTheme.primary : Colors.white,
                                fontSize: 12, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet detalhe da atividade ────────────────────────

class _ActivityDetailSheet extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onComplete;

  const _ActivityDetailSheet({required this.activity, required this.onComplete});

  String _translateType(String type) {
    const map = {
      'irrigation': 'Rega', 'fertilization': 'Fertilização',
      'pruning': 'Poda', 'harvest': 'Colheita',
      'treatment': 'Tratamento', 'inspection': 'Inspeção',
      'maintenance': 'Manutenção', 'other': 'Outra',
    };
    return map[type] ?? (type.isNotEmpty ? type[0].toUpperCase() + type.substring(1) : type);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM, yyyy', 'pt_PT').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name        = activity['activity_name']?.toString() ?? '';
    final type        = activity['activity_type']?.toString() ?? '';
    final landName    = activity['land_name']?.toString() ?? '';
    final cropName    = activity['crop_name']?.toString() ?? '';
    final description = activity['activity_description']?.toString() ?? '';
    final dateStr     = activity['activity_date_planned']?.toString();
    final isDone      = (activity['activity_status'] as int? ?? 0) == 1;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Detalhes Atividade',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Card Terreno & Cultura
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Text('Terreno & Cultura',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                  ),
                  const Divider(height: 1, color: AppTheme.divider),
                  // Terreno — tappable
                  InkWell(
                    onTap: () => context.go('/lands'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Center(
                        child: Text(
                          landName.isNotEmpty ? landName : '—',
                          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                  if (cropName.isNotEmpty) ...[
                    const Divider(height: 1, color: AppTheme.divider),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Center(
                        child: Text(
                          cropName,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Card Observações
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Text('Observações',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                  ),
                  const Divider(height: 1, color: AppTheme.divider),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : _translateType(type),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                        ),
                        if (dateStr != null && dateStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(_formatDate(dateStr),
                              style: const TextStyle(fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(description,
                              style: const TextStyle(fontSize: 13,
                                  color: AppTheme.textPrimary, height: 1.5)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Botão Concluir
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: isDone ? null : onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? AppTheme.textSecondary : AppTheme.primary,
              ),
              child: Text(isDone ? 'Já concluída' : 'Concluir'),
            ),
          ),
        ],
      ),
    );
  }
}
