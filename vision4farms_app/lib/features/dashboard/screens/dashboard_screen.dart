import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sensor_provider.dart';
import '../../../core/models/dashboard_model.dart';
import '../../../core/models/sensor_association_model.dart';
import '../../../core/services/sensor_data_resolver_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../notifications/screens/notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final farm = context.read<FarmProvider>().selectedFarm;
      if (farm != null) context.read<FarmProvider>().loadDashboard(farm.farmId);
    });
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM', 'pt_PT').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmProvider = context.watch<FarmProvider>();
    final farm         = farmProvider.selectedFarm;
    final dashboard    = farmProvider.dashboard;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: farmProvider.isLoading && dashboard == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async {
                if (farm != null) await farmProvider.loadDashboard(farm.farmId);
              },
              child: CustomScrollView(
                slivers: [
                  // ── Header verde ─────────────────────────────
                  SliverToBoxAdapter(
                    child: _DashboardHeader(
                      farmName: farm?.farmName ?? '',
                      userRole: farm?.userRole ?? 1,
                      unread: dashboard?.summary.unreadNotifications ?? 0,
                      onNotifications: () async {
                        await showNotificationsOverlay(context);
                        if (context.mounted && farm != null) {
                          context.read<FarmProvider>().loadDashboard(farm.farmId);
                        }
                      },
                      onProfile: () => context.go('/profile'),
                      onFarmTap: () => context.go('/farms'),
                    ),
                  ),

                  if (dashboard == null)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('Sem dados',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    )
                  else ...[

                    // ── Área cultivada ──────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        // PATCH 2: onTap navega para tab Terrenos
                        child: _AreaCard(
                          totalHa: dashboard.summary.totalAreaHa,
                          totalLands: dashboard.summary.totalLands,
                          onTap: () => context.go('/lands'),
                        ),
                      ),
                    ),

                    // ── Tempo ───────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _WeatherCard(
                          farmGps: farm?.farmGps,
                          location: farm?.farmCity ?? farm?.farmDistrict ?? '',
                        ),
                      ),
                    ),

                    // ── Sensores ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _BackendSensorsCard(farmId: farm?.farmId),
                      ),
                    ),

                    // ── Atividades ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _ActivitiesCard(
                          activities: dashboard.activities,
                          formatDate: _formatDate,
                          onTap: () => context.go('/activities'),
                        ),
                      ),
                    ),

                    // ── Agenda ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: GestureDetector(
                          onTap: () => context.go('/agenda'),
                          child: _Card(
                            title: 'Agenda',
                            trailing: const Icon(Icons.chevron_right,
                                color: AppTheme.textSecondary, size: 18),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.calendar_month,
                                      color: AppTheme.primary, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${dashboard.agenda.pending} eventos pendentes',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${dashboard.agenda.thisMonth} este mês',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Rega ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        // PATCH 3: envolve _IrrigationCard com GestureDetector
                        child: GestureDetector(
                          onTap: () => context.go('/irrigation'),
                          child: _IrrigationCard(
                            irrigation: dashboard.irrigation,
                            formatDate: _formatDate,
                          ),
                        ),
                      ),
                    ),

                    // ── Análises ─────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _AnalysesCard(analyses: dashboard.analyses),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Header verde ──────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String farmName;
  final int userRole;
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onFarmTap;

  const _DashboardHeader({
    required this.farmName,
    required this.userRole,
    required this.unread,
    required this.onNotifications,
    required this.onProfile,
    required this.onFarmTap,
  });

  static String _roleLabel(int role) {
    const labels = {1: 'Gestor', 2: 'Colaborador', 3: 'Consultor'};
    return labels[role] ?? 'Membro';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              // Ícone de perfil
              GestureDetector(
                onTap: onProfile,
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_outline, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              // Nome da quinta — toca para voltar à lista de explorações
              Expanded(
                child: GestureDetector(
                  onTap: onFarmTap,
                  child: Column(
                    children: [
                      Text(
                        farmName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _roleLabel(userRole),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sino de notificações
              GestureDetector(
                onTap: onNotifications,
                child: Stack(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('$unread',
                                style: const TextStyle(color: Colors.white, fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card Área cultivada ───────────────────────────────────────

class _AreaCard extends StatelessWidget {
  final double totalHa;
  final int totalLands;
  final VoidCallback? onTap; // PATCH 2: novo parâmetro

  const _AreaCard({
    required this.totalHa,
    required this.totalLands,
    this.onTap, // PATCH 2
  });

  @override
  Widget build(BuildContext context) {
    // PATCH 2: envolve com GestureDetector
    return GestureDetector(
      onTap: onTap,
      child: _Card(
        title: 'Área cultivada',
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${totalHa.toStringAsFixed(0)} ha',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Text('Total cultivado',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalLands',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Text('Número de terrenos',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card Tempo (Open-Meteo) ───────────────────────────────────

// WMO weather codes → ícone + descrição
IconData _wmoIcon(int code) {
  if (code == 0)              return Icons.wb_sunny_outlined;
  if (code <= 2)              return Icons.wb_cloudy_outlined;
  if (code == 3)              return Icons.cloud_outlined;
  if (code <= 49)             return Icons.foggy;
  if (code <= 67)             return Icons.grain;        // chuva/drizzle
  if (code <= 77)             return Icons.ac_unit;      // neve
  if (code <= 82)             return Icons.water_drop;   // aguaceiros
  if (code <= 99)             return Icons.thunderstorm; // trovoada
  return Icons.wb_cloudy_outlined;
}

class _WeatherSlot {
  final String hour;
  final int code;
  final double temp;
  final bool isNow;
  const _WeatherSlot({
    required this.hour,
    required this.code,
    required this.temp,
    this.isNow = false,
  });
}

class _WeatherCard extends StatefulWidget {
  final String? farmGps;
  final String location;
  const _WeatherCard({required this.farmGps, required this.location});

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> {
  // 0=Ontem, 1=Hoje, 2=Amanhã
  int _selectedDay = 1;
  bool _isLoading = true;
  String? _error;

  // [day][slot]
  final List<List<_WeatherSlot>> _days = [[], [], []];

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void didUpdateWidget(_WeatherCard old) {
    super.didUpdateWidget(old);
    if (old.farmGps != widget.farmGps) _fetchWeather();
  }

  double? _parseLat() {
    if (widget.farmGps == null) return null;
    final p = widget.farmGps!.split(',');
    return p.length >= 2 ? double.tryParse(p[0].trim()) : null;
  }

  double? _parseLng() {
    if (widget.farmGps == null) return null;
    final p = widget.farmGps!.split(',');
    return p.length >= 2 ? double.tryParse(p[1].trim()) : null;
  }

  Future<void> _fetchWeather() async {
    final lat = _parseLat();
    final lng = _parseLng();
    if (lat == null || lng == null) {
      setState(() { _isLoading = false; _error = 'GPS não definido'; });
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await Dio().get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude':            lat,
          'longitude':           lng,
          'hourly':              'temperature_2m,weathercode',
          'current_weather':     true,
          'timezone':            'Europe/Lisbon',
          'forecast_days':       3,
          'past_days':           1,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout:    const Duration(seconds: 8),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final times     = data['hourly']['time']            as List;
      final temps     = data['hourly']['temperature_2m']  as List;
      final codes     = data['hourly']['weathercode']     as List;
      final currentTime = data['current_weather']['time'] as String;

      final now = DateTime.parse(currentTime);

      // Separar em 3 dias: ontem, hoje, amanhã
      final List<List<_WeatherSlot>> days = [[], [], []];
      final dates = [
        now.subtract(const Duration(days: 1)),
        now,
        now.add(const Duration(days: 1)),
      ];

      for (int i = 0; i < times.length; i++) {
        final dt   = DateTime.parse(times[i] as String);
        final temp = (temps[i] as num).toDouble();
        final code = (codes[i] as num).toInt();
        // Filtrar apenas horas entre 8h e 20h
        if (dt.hour < 8 || dt.hour > 20) continue;
        // Apenas horas de 2 em 2 para caber no card (8,10,12,14,16,18,20 → 7 slots)
        if (dt.hour % 2 != 0) continue;

        for (int d = 0; d < 3; d++) {
          if (dt.year == dates[d].year &&
              dt.month == dates[d].month &&
              dt.day == dates[d].day) {
            final isNow = d == 1 &&
                dt.hour == (now.hour % 2 == 0 ? now.hour : now.hour - 1);
            days[d].add(_WeatherSlot(
              hour: '${dt.hour.toString().padLeft(2, '0')}h',
              code: code,
              temp: temp,
              isNow: isNow,
            ));
          }
        }
      }

      setState(() {
        for (int i = 0; i < 3; i++) _days[i] = days[i];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Sem dados de tempo';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Tempo',
      trailing: widget.location.isNotEmpty
          ? Text(widget.location,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))
          : null,
      child: _isLoading
          ? const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2),
              ),
            )
          : _error != null
              ? SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                )
              : Column(
                  children: [
                    // Seletor Ontem / Hoje / Amanhã
                    Row(
                      children: [
                        _DayChip(
                            label: 'Ontem',
                            selected: _selectedDay == 0,
                            onTap: () => setState(() => _selectedDay = 0)),
                        const SizedBox(width: 8),
                        _DayChip(
                            label: 'Hoje',
                            selected: _selectedDay == 1,
                            onTap: () => setState(() => _selectedDay = 1)),
                        const SizedBox(width: 8),
                        _DayChip(
                            label: 'Amanhã',
                            selected: _selectedDay == 2,
                            onTap: () => setState(() => _selectedDay = 2)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Slots
                    _days[_selectedDay].isEmpty
                        ? const Text('Sem dados',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: _days[_selectedDay].map((slot) {
                              return Expanded(
                                child: Column(children: [
                                  Text(slot.hour,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: slot.isNow
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                        fontWeight: slot.isNow
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      )),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: slot.isNow
                                        ? BoxDecoration(
                                            color: AppTheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(8))
                                        : null,
                                    child: Icon(
                                      _wmoIcon(slot.code),
                                      size: 20,
                                      color: slot.isNow
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${slot.temp.toStringAsFixed(0)}°',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: slot.isNow
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: slot.isNow
                                          ? AppTheme.primary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ]),
                              );
                            }).toList(),
                          ),
                  ],
                ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      );
}

// ── Card Atividades ───────────────────────────────────────────

class _ActivitiesCard extends StatelessWidget {
  final DashboardActivities activities;
  final String Function(String) formatDate;
  final VoidCallback onTap;

  const _ActivitiesCard({
    required this.activities,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Card(
        title: 'Atividades',
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondary,
          size: 18,
        ),
        child: Column(
          children: [
            _ActivityBullet(
              color: const Color(0xFFFFA726),
              label: 'A fazer',
              count: activities.pending,
            ),
            const SizedBox(height: 8),
            _ActivityBullet(
              color: AppTheme.error,
              label: 'Atrasadas',
              count: activities.overdue,
            ),
            const SizedBox(height: 8),
            _ActivityBullet(
              color: AppTheme.primary,
              label: 'Concluídas',
              count: activities.doneThisMonth,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityBullet extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _ActivityBullet({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ── Card Rega ─────────────────────────────────────────────────

class _IrrigationCard extends StatelessWidget {
  final DashboardIrrigation irrigation;
  final String Function(String) formatDate;

  const _IrrigationCard({required this.irrigation, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final lastDate = irrigation.last != null
        ? _relativeDate(irrigation.last!['date']?.toString() ?? '')
        : 'Sem registos';
    final lastLand = irrigation.last?['land_name']?.toString() ?? '';

    final nextDate = irrigation.next.isNotEmpty
        ? _nextDateLabel(irrigation.next.first['planned_date']?.toString() ?? '')
        : 'Sem regas';
    final nextTime = irrigation.next.isNotEmpty
        ? _extractTime(irrigation.next.first['planned_date']?.toString() ?? '')
        : '';
    final nextLand = irrigation.next.isNotEmpty
        ? irrigation.next.first['land_name']?.toString() ?? ''
        : '';

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Última Rega',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(lastDate,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                if (lastLand.isNotEmpty)
                  Text(lastLand,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Próxima Rega',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(nextDate,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                if (nextTime.isNotEmpty)
                  Text(nextTime,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (nextLand.isNotEmpty)
                  Text(nextLand,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _relativeDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date).inDays;
      if (diff == 0) return 'Hoje';
      if (diff == 1) return 'Ontem';
      return 'Há $diff dia/s';
    } catch (_) {
      return dateStr;
    }
  }

  String _nextDateLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = date.difference(DateTime.now()).inDays;
      if (diff == 0) return 'Hoje';
      if (diff == 1) return 'Amanhã';
      return DateFormat('dd MMM', 'pt_PT').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _extractTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ── Card Análises ─────────────────────────────────────────────

class _AnalysesCard extends StatelessWidget {
  final DashboardAnalyses analyses;
  const _AnalysesCard({required this.analyses});

  @override
  Widget build(BuildContext context) {
    final hasSoil = analyses.soil.isNotEmpty;
    final hasFoliar = analyses.foliar.isNotEmpty;

    return _Card(
      title: 'Análises',
      child: analyses.total == 0
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sem análises registadas',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            )
          : Column(
              children: [
                // Resumo
                Row(
                  children: [
                    Expanded(
                      child: _AnalysisStat(
                        icon: Icons.terrain,
                        label: 'Solo',
                        count: analyses.soil.length,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AnalysisStat(
                        icon: Icons.eco_outlined,
                        label: 'Foliar',
                        count: analyses.foliar.length,
                        color: const Color(0xFF7B1FA2),
                      ),
                    ),
                  ],
                ),
                // Últimas análises
                if (hasSoil || hasFoliar) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppTheme.divider),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Últimas análises',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(height: 8),
                  ...analyses.soil.take(2).map((a) => _AnalysisRow(
                    type: 'Solo',
                    date: a['soil_analysis_date']?.toString() ?? '',
                    sample: a['soil_analysis_sample']?.toString() ?? '',
                    color: const Color(0xFF1565C0),
                  )),
                  ...analyses.foliar.take(2).map((a) => _AnalysisRow(
                    type: 'Foliar',
                    date: a['yield_analysis_date']?.toString() ?? '',
                    sample: a['yield_analysis_sample']?.toString() ?? '',
                    color: const Color(0xFF7B1FA2),
                  )),
                ],
              ],
            ),
    );
  }
}

class _AnalysisStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _AnalysisStat({
    required this.icon, required this.label,
    required this.count, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count', style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11,
                  color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  final String type;
  final String date;
  final String sample;
  final Color color;
  const _AnalysisRow({
    required this.type, required this.date,
    required this.sample, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    String formatted = date;
    try {
      final d = DateTime.parse(date);
      formatted = DateFormat('d MMM yyyy', 'pt_PT').format(d);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(type, style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sample.isNotEmpty ? sample : 'Análise',
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(formatted, style: const TextStyle(fontSize: 12,
              color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ── Card base ─────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Card({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

// ── Sensores card dinâmico ─────────────────────────────────────

class _BackendSensorsCard extends StatelessWidget {
  final int? farmId;
  const _BackendSensorsCard({this.farmId});

  @override
  Widget build(BuildContext context) {
    if (farmId == null) return _SensorsCard._staticCard(context, null, null, null);

    return FutureBuilder(
      future: context
          .read<SensorProvider>()
          .loadFarmAssociations(farmId!, notify: false),
      builder: (context, snap) {
        final associations = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting &&
            associations.isEmpty) {
          return _SensorsCard._staticCard(context, null, null, null);
        }
        if (associations.isEmpty) return _WeatherSensorsCard(farmId: farmId!);

        return _CombinedSensorsCard(
          farmId: farmId!,
          associations: associations,
        );
      },
    );
  }
}

/// Card combinado: Open-Meteo no topo + médias por terreno em baixo.
class _CombinedSensorsCard extends StatefulWidget {
  final int farmId;
  final List<SensorAssociationModel> associations;
  const _CombinedSensorsCard({
    required this.farmId,
    required this.associations,
  });

  @override
  State<_CombinedSensorsCard> createState() => _CombinedSensorsCardState();
}

class _CombinedSensorsCardState extends State<_CombinedSensorsCard> {
  double? _apiTemp;
  double? _apiHum;
  double? _apiWind;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    final gps = farm?.farmGps;
    if (gps == null || gps.isEmpty) return;
    final parts = gps.split(',');
    if (parts.length < 2) return;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return;
    try {
      final r = await Dio().get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'current':
              'temperature_2m,relative_humidity_2m,wind_speed_10m',
          'timezone': 'Europe/Lisbon',
        },
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final current = r.data['current'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _apiTemp = (current['temperature_2m'] as num?)?.toDouble();
        _apiHum = (current['relative_humidity_2m'] as num?)?.toDouble();
        _apiWind = (current['wind_speed_10m'] as num?)?.toDouble();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/sensors'),
      child: _Card(
        title: 'Sensores',
        trailing: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tempo real',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500)),
            SizedBox(width: 6),
            Icon(Icons.chevron_right,
                color: AppTheme.textSecondary, size: 18),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha Open-Meteo (3 chips) — como estava
            Row(
              children: [
                Expanded(
                  child: _SensorMetricChip(
                    icon: Icons.thermostat,
                    value: _apiTemp != null
                        ? '${_apiTemp!.toStringAsFixed(1)}°C'
                        : '—',
                    label: 'Temperatura',
                    color: AppTheme.primary,
                  ),
                ),
                Expanded(
                  child: _SensorMetricChip(
                    icon: Icons.water_drop_outlined,
                    value: _apiHum != null
                        ? '${_apiHum!.toStringAsFixed(0)}%'
                        : '—',
                    label: 'Humidade',
                    color: const Color(0xFF1565C0),
                  ),
                ),
                Expanded(
                  child: _SensorMetricChip(
                    icon: Icons.air,
                    value: _apiWind != null
                        ? '${_apiWind!.toStringAsFixed(1)} km/h'
                        : '—',
                    label: 'Vento',
                    color: const Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Text(
              'Fonte: Open-Meteo',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 12),

            // Médias por terreno
            const Text(
              'Médias dos sensores',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<int, SensorAverages>>(
              future: context
                  .read<SensorProvider>()
                  .resolver
                  .landsAverages(widget.associations),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'A carregar leituras dos sensores…',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  );
                }
                final byLand = snap.data ?? const <int, SensorAverages>{};
                if (byLand.isEmpty) {
                  return const Text(
                    'Sem leituras recentes dos sensores.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  );
                }
                // Nome do terreno → vem das associations
                final landNames = <int, String>{};
                for (final assoc in widget.associations) {
                  landNames.putIfAbsent(assoc.landId, () => assoc.landName);
                }
                final entries = byLand.entries.toList()
                  ..sort((a, b) =>
                      (landNames[a.key] ?? '').compareTo(landNames[b.key] ?? ''));
                return Column(
                  children: entries.map((entry) {
                    final name = landNames[entry.key] ?? 'Terreno ${entry.key}';
                    return _LandAveragesRow(
                      landName: name,
                      averages: entry.value,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LandAveragesRow extends StatelessWidget {
  final String landName;
  final SensorAverages averages;
  const _LandAveragesRow({required this.landName, required this.averages});

  @override
  Widget build(BuildContext context) {
    final temp = averages.temperaturaAr;
    final hum = averages.humidadeAr;
    final hasData = temp != null || hum != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$landName:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (!hasData)
            const Text(
              'sem dados',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else ...[
            if (temp != null) ...[
              Icon(Icons.thermostat,
                  size: 14,
                  color: temp >= 35
                      ? AppTheme.error
                      : temp >= 28
                          ? const Color(0xFFF57C00)
                          : AppTheme.primary),
              const SizedBox(width: 2),
              Text(
                '${temp.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (hum != null) ...[
              const Icon(Icons.water_drop_outlined,
                  size: 14, color: Color(0xFF1565C0)),
              const SizedBox(width: 2),
              Text(
                '${hum.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SensorsCard extends StatelessWidget {
  final int? farmId;
  const _SensorsCard({this.farmId});

  @override
  Widget build(BuildContext context) {
    if (farmId == null) {
      return _staticCard(context, null, null, null);
    }

    // Tenta primeiro por farm_id escrito no Firebase,
    // depois tenta sem filtro (nós que ainda não têm farm_id associado
    // mas pertencem a uma exploração com Firebase).
    // Verifica se a exploração tem sensores em v4f_links
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instanceFor(app: Firebase.app('sensors'))
          .collection('v4f_links')
          .where('farm_id', isEqualTo: farmId)
          .snapshots(),
      builder: (context, linksSnap) {
        if (linksSnap.hasData && linksSnap.data!.docs.isNotEmpty) {
          // Recolhe todos os no_ids de todos os links da exploração
          final noIds = <int>[];
          for (final doc in linksSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ids = (data['no_ids'] as List?)
                    ?.map((e) => int.tryParse(e.toString()))
                    .where((id) => id != null)
                    .cast<int>()
                    .toList() ??
                [];
            noIds.addAll(ids);
          }
          if (noIds.isNotEmpty) {
            return _FirebaseSensorsCard(noIds: noIds, farmId: farmId!);
          }
        }
        return _WeatherSensorsCard(farmId: farmId!);
      },
    );
  }

  static Widget _staticCard(BuildContext context,
      double? temp, double? hum, double? pressure) {
    return GestureDetector(
      onTap: () => context.go('/sensors'),
      child: _Card(
        title: 'Sensores',
        trailing: const Icon(Icons.chevron_right,
            color: AppTheme.textSecondary, size: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sensors,
                  color: Color(0xFF1565C0), size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Temperatura & Humidade',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text('Ver gráficos e histórico',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseSensorsCard extends StatelessWidget {
  final List<int> noIds;
  final int farmId;
  const _FirebaseSensorsCard({required this.noIds, required this.farmId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instanceFor(app: Firebase.app('sensors'))
          .collection('leituras')
          .where('no_id', whereIn: noIds.take(10).toList())
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        double? temp, hum, pressure;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final readings = snap.data!.docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList();
          double tSum = 0, hSum = 0, pSum = 0;
          int tN = 0, hN = 0, pN = 0;
          for (final r in readings) {
            final t = double.tryParse(r['temperatura_ar']?.toString() ?? '');
            final h = double.tryParse(r['humidade_ar']?.toString() ?? '');
            final p = double.tryParse(r['pressao']?.toString() ?? '');
            if (t != null) { tSum += t; tN++; }
            if (h != null) { hSum += h; hN++; }
            if (p != null) { pSum += p; pN++; }
          }
          if (tN > 0) temp = tSum / tN;
          if (hN > 0) hum = hSum / hN;
          if (pN > 0) pressure = pSum / pN;
        }

        return GestureDetector(
          onTap: () => context.go('/sensors'),
          child: _Card(
            title: 'Sensores',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Em tempo real',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.primary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary, size: 18),
              ],
            ),
            child: Row(
              children: [
                if (temp != null)
                  Expanded(child: _SensorMetricChip(
                    icon: Icons.thermostat,
                    value: '${temp.toStringAsFixed(1)}°C',
                    label: 'Temperatura',
                    color: temp >= 35 ? AppTheme.error
                        : temp >= 28 ? const Color(0xFFF57C00)
                        : AppTheme.primary,
                  )),
                if (hum != null)
                  Expanded(child: _SensorMetricChip(
                    icon: Icons.water_drop_outlined,
                    value: '${hum.toStringAsFixed(0)}%',
                    label: 'Humidade',
                    color: const Color(0xFF1565C0),
                  )),
                if (pressure != null)
                  Expanded(child: _SensorMetricChip(
                    icon: Icons.speed,
                    value: '${pressure.toStringAsFixed(0)}',
                    label: 'hPa',
                    color: const Color(0xFF7B1FA2),
                  )),
                if (temp == null && hum == null)
                  const Text('A carregar...',
                      style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeatherSensorsCard extends StatefulWidget {
  final int farmId;
  const _WeatherSensorsCard({required this.farmId});

  @override
  State<_WeatherSensorsCard> createState() => _WeatherSensorsCardState();
}

class _WeatherSensorsCardState extends State<_WeatherSensorsCard> {
  double? _temp;
  double? _hum;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    final gps = farm?.farmGps;
    if (gps == null || gps.isEmpty) return;
    final parts = gps.split(',');
    if (parts.length < 2) return;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return;
    try {
      final r = await Dio().get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'current': 'temperature_2m,relative_humidity_2m',
          'timezone': 'Europe/Lisbon',
        },
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final current = r.data['current'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _temp = (current['temperature_2m'] as num?)?.toDouble();
        _hum = (current['relative_humidity_2m'] as num?)?.toDouble();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/sensors'),
      child: _Card(
        title: 'Sensores',
        trailing: const Icon(Icons.chevron_right,
            color: AppTheme.textSecondary, size: 18),
        child: Row(
          children: [
            Expanded(child: _SensorMetricChip(
              icon: Icons.thermostat,
              value: _temp != null ? '${_temp!.toStringAsFixed(1)}°C' : '—',
              label: 'Temperatura',
              color: AppTheme.primary,
            )),
            Expanded(child: _SensorMetricChip(
              icon: Icons.water_drop_outlined,
              value: _hum != null ? '${_hum!.toStringAsFixed(0)}%' : '—',
              label: 'Humidade',
              color: const Color(0xFF1565C0),
            )),
            Expanded(child: _SensorMetricChip(
              icon: Icons.cloud_outlined,
              value: 'Open-Meteo',
              label: 'Fonte',
              color: AppTheme.textSecondary,
            )),
          ],
        ),
      ),
    );
  }
}

class _SensorMetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _SensorMetricChip(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      );
}
