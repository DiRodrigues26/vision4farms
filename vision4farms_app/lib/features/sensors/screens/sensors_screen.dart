import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sensor_provider.dart';
import '../../../shared/theme/app_theme.dart';

void _showAssociationSheet(BuildContext context) {
  context.push('/sensor-setup');
}

class SensorsScreen extends StatelessWidget {
  const SensorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final farmId = context.watch<FarmProvider>().selectedFarm?.farmId;
    if (farmId == null) return const _WeatherSensorsScreen();

    // Verifica se a exploração tem sensores associados via v4f_links
    return FutureBuilder(
      future: context
          .read<SensorProvider>()
          .loadFarmAssociations(farmId, notify: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }
        final hasFirebase = (snap.data ?? const []).isNotEmpty;
        if (hasFirebase) return const _FirebaseSensorsScreen();
        return const _WeatherSensorsScreen();
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ECRÃ FIREBASE — Quinta do Vale Verde
// ══════════════════════════════════════════════════════════════

class _FirebaseSensorsScreen extends StatefulWidget {
  const _FirebaseSensorsScreen();

  @override
  State<_FirebaseSensorsScreen> createState() =>
      _FirebaseSensorsScreenState();
}

class _FirebaseSensorsScreenState extends State<_FirebaseSensorsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _db = FirebaseFirestore.instanceFor(app: Firebase.app('sensors'));

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text('Sensores'),
        actions: [
          if (context.read<FarmProvider>().selectedFarm?.canManage ?? false)
            IconButton(
              icon: const Icon(Icons.settings_input_antenna),
              tooltip: 'Gerir sensores',
              onPressed: () async {
                _showAssociationSheet(context);
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Nós'),
            Tab(text: 'Alertas'),
            Tab(text: 'Decisões'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _NosTab(db: _db),
          _AlertasTab(db: _db),
          _DecisoesTab(db: _db),
        ],
      ),
    );
  }
}

// ── Tab Nós ────────────────────────────────────────────────────

class _NosTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _NosTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('nos').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _FirebaseErrorView(message: 'Erro: ${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _FirebaseEmptyView(message: 'Sem nós registados');
        }
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _ApiWeatherPanel()),
            SliverToBoxAdapter(child: _UltimasLeiturasPanel(db: db)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return _NoCard(data: d, noId: docs[i].id, db: db);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UltimasLeiturasPanel extends StatelessWidget {
  final FirebaseFirestore db;
  const _UltimasLeiturasPanel({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('leituras')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        double tempSum = 0, humArSum = 0, pressaoSum = 0;
        int tempN = 0, humArN = 0, pressaoN = 0;
        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          final t = double.tryParse(m['temperatura_ar']?.toString() ?? '');
          final h = double.tryParse(m['humidade_ar']?.toString() ?? '');
          final p = double.tryParse(m['pressao']?.toString() ?? '');
          if (t != null) { tempSum += t; tempN++; }
          if (h != null) { humArSum += h; humArN++; }
          if (p != null) { pressaoSum += p; pressaoN++; }
        }
        final lastTs =
            (docs.first.data() as Map<String, dynamic>)['timestamp']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.sensors, color: Colors.white70, size: 14),
                  SizedBox(width: 6),
                  Text('Médias dos sensores (últimas 10 leituras)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (tempN > 0)
                    Expanded(
                      child: _LiveMetric(
                        icon: Icons.thermostat,
                        label: 'Temperatura',
                        value: '${(tempSum / tempN).toStringAsFixed(1)}°C',
                      ),
                    ),
                  if (humArN > 0)
                    Expanded(
                      child: _LiveMetric(
                        icon: Icons.water_drop_outlined,
                        label: 'Humidade ar',
                        value: '${(humArSum / humArN).toStringAsFixed(1)}%',
                      ),
                    ),
                  if (pressaoN > 0)
                    Expanded(
                      child: _LiveMetric(
                        icon: Icons.speed,
                        label: 'Pressão',
                        value:
                            '${(pressaoSum / pressaoN).toStringAsFixed(0)} hPa',
                      ),
                    ),
                ],
              ),
              if (lastTs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 11, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text('Última leitura: ${_fmtTs(lastTs)}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white54)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _fmtTs(String ts) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ts));
    } catch (_) {
      return ts;
    }
  }
}

class _LiveMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _LiveMetric(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      );
}

// ── Card Open-Meteo da exploração ──────────────────────────────

class _ApiWeatherPanel extends StatefulWidget {
  const _ApiWeatherPanel();

  @override
  State<_ApiWeatherPanel> createState() => _ApiWeatherPanelState();
}

class _ApiWeatherPanelState extends State<_ApiWeatherPanel> {
  double? _temp;
  double? _hum;
  double? _wind;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    final gps = farm?.farmGps;
    if (gps == null || gps.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final parts = gps.split(',');
    if (parts.length < 2) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
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
        _temp = (current['temperature_2m'] as num?)?.toDouble();
        _hum = (current['relative_humidity_2m'] as num?)?.toDouble();
        _wind = (current['wind_speed_10m'] as num?)?.toDouble();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_outlined,
                  color: AppTheme.textSecondary, size: 14),
              SizedBox(width: 6),
              Text('Meteorologia da exploração (Open-Meteo)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('A carregar dados meteorológicos…',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            )
          else if (_temp == null && _hum == null && _wind == null)
            const Text('Sem dados meteorológicos.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary))
          else
            Row(
              children: [
                if (_temp != null)
                  Expanded(
                    child: _ApiMetric(
                      icon: Icons.thermostat,
                      value: '${_temp!.toStringAsFixed(1)}°C',
                      label: 'Temperatura',
                      color: AppTheme.primary,
                    ),
                  ),
                if (_hum != null)
                  Expanded(
                    child: _ApiMetric(
                      icon: Icons.water_drop_outlined,
                      value: '${_hum!.toStringAsFixed(0)}%',
                      label: 'Humidade',
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                if (_wind != null)
                  Expanded(
                    child: _ApiMetric(
                      icon: Icons.air,
                      value: '${_wind!.toStringAsFixed(1)} km/h',
                      label: 'Vento',
                      color: const Color(0xFF7B1FA2),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ApiMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _ApiMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      );
}

class _NoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String noId;
  final FirebaseFirestore db;
  const _NoCard(
      {required this.data, required this.noId, required this.db});

  @override
  Widget build(BuildContext context) {
    final nome = data['nome']?.toString() ?? 'Nó $noId';
    final status = data['status']?.toString() ?? 'offline';
    final tipo = data['tipo']?.toString() ?? '';
    final zona = data['zona']?.toString() ?? '';
    final ultimoContacto = data['ultimo_contacto']?.toString() ?? '';
    final isOnline = status == 'online';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? AppTheme.primary.withValues(alpha: 0.4)
              : AppTheme.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(
                  tipo == 'fixo' ? Icons.sensors : Icons.sensors_outlined,
                  color: isOnline ? AppTheme.primary : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      if (zona.isNotEmpty)
                        Text(zona,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : AppTheme.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOnline
                                ? AppTheme.primary
                                : AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('leituras')
                .where('no_id', isEqualTo: int.tryParse(noId) ?? noId)
                .orderBy('timestamp', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, lSnap) {
              if (!lSnap.hasData || lSnap.data!.docs.isEmpty) {
                if (ultimoContacto.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text('Último contacto: $ultimoContacto',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
                  );
                }
                return const SizedBox.shrink();
              }
              final l = lSnap.data!.docs.first.data()
                  as Map<String, dynamic>;
              return _LeituraInline(leitura: l);
            },
          ),
        ],
      ),
    );
  }
}

class _LeituraInline extends StatelessWidget {
  final Map<String, dynamic> leitura;
  const _LeituraInline({required this.leitura});

  String _fmt(dynamic v) {
    final d = double.tryParse(v.toString());
    return d != null ? d.toStringAsFixed(1) : v.toString();
  }

  Color _tempColor(dynamic v) {
    final d = double.tryParse(v.toString()) ?? 20;
    if (d >= 35) return AppTheme.error;
    if (d >= 28) return const Color(0xFFF57C00);
    if (d <= 5) return const Color(0xFF1565C0);
    return AppTheme.primary;
  }

  String _fmtTs(String ts) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ts));
    } catch (_) { return ts; }
  }

  @override
  Widget build(BuildContext context) {
    final temp    = leitura['temperatura_ar'];
    final humAr   = leitura['humidade_ar'];
    final humSolo = leitura['humidade_solo'];
    final pressao = leitura['pressao'];
    final ts      = leitura['timestamp']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppTheme.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (temp != null)
                    _SensorChip(
                        icon: Icons.thermostat,
                        value: '${_fmt(temp)}°C',
                        color: _tempColor(temp)),
                  if (humAr != null)
                    _SensorChip(
                        icon: Icons.water_drop_outlined,
                        value: '${_fmt(humAr)}%',
                        color: const Color(0xFF1565C0)),
                  if (humSolo != null)
                    _SensorChip(
                        icon: Icons.grass,
                        value: 'Solo ${_fmt(humSolo)}%',
                        color: const Color(0xFF4CAF50)),
                  if (pressao != null)
                    _SensorChip(
                        icon: Icons.speed,
                        value: '${_fmt(pressao)} hPa',
                        color: AppTheme.textSecondary),
                ],
              ),
              if (ts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Última leitura: ${_fmtTs(ts)}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SensorChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _SensorChip(
      {required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      );
}

// ── Tab Alertas ───────────────────────────────────────────────

class _AlertasTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _AlertasTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('alertas')
          .orderBy('criado_em', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _FirebaseErrorView(message: 'Erro: ${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _FirebaseEmptyView(message: 'Sem alertas registados');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _AlertaCard(data: d);
          },
        );
      },
    );
  }
}

class _AlertaCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AlertaCard({required this.data});

  String _fmtTs(String ts) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ts));
    } catch (_) { return ts; }
  }

  @override
  Widget build(BuildContext context) {
    final mensagem   = data['mensagem']?.toString() ?? '';
    final severidade = data['severidade']?.toString() ?? '';
    final tipo       = data['tipo']?.toString() ?? '';
    final noNome     = data['no_nome']?.toString() ?? '';
    final criadoEm   = data['criado_em']?.toString() ?? '';
    final resolvido  = data['resolvido_em'] != null;

    final color = severidade == 'alta'
        ? AppTheme.error
        : severidade == 'media'
            ? const Color(0xFFF57C00)
            : const Color(0xFF1565C0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: resolvido
                ? AppTheme.divider
                : color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tipo == 'anomalia'
                    ? Icons.warning_amber_rounded
                    : Icons.notifications_outlined,
                color: resolvido ? AppTheme.textSecondary : color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  noNome.isNotEmpty ? noNome : tipo,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: resolvido
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary),
                ),
              ),
              if (severidade.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(severidade.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
            ],
          ),
          if (mensagem.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(mensagem,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    height: 1.4)),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 11, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(_fmtTs(criadoEm),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              if (resolvido) ...[
                const SizedBox(width: 12),
                const Icon(Icons.check_circle_outline,
                    size: 11, color: AppTheme.primary),
                const SizedBox(width: 4),
                const Text('Resolvido',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.primary)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab Decisões ──────────────────────────────────────────────

class _DecisoesTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _DecisoesTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('decisoes')
          .orderBy('criado_em', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _FirebaseErrorView(message: 'Erro: ${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _FirebaseEmptyView(
              message: 'Sem decisões registadas');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _DecisaoCard(data: d);
          },
        );
      },
    );
  }
}

class _DecisaoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DecisaoCard({required this.data});

  String _fmtTs(String ts) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ts));
    } catch (_) { return ts; }
  }

  String _fmtConfianca(dynamic v) {
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    return d <= 1 ? '${(d * 100).toStringAsFixed(0)}%' : '${d.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final acao        = data['acao_sugerida']?.toString() ?? '';
    final tipoAnom    = data['tipo_anomalia']?.toString() ?? '';
    final noNome      = data['no_nome']?.toString() ?? '';
    final resultado   = data['resultado']?.toString() ?? '';
    final criadoEm    = data['criado_em']?.toString() ?? '';
    final confianca   = data['confianca'];
    Map<String, dynamic> valores = {};
    try {
      valores = jsonDecode(data['valores_sensores']?.toString() ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {}

    final isAprovado  = resultado == 'aprovado';
    final color       = isAprovado ? AppTheme.primary : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _humanizeAnomalia(tipoAnom),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(resultado.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ],
          ),
          if (noNome.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Nó: $noNome',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (acao.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(acao,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary)),
                  ),
                ],
              ),
            ),
          ],
          if (valores.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: valores.entries.map((e) {
                final v = double.tryParse(e.value.toString());
                return Text(
                  '${_labelSensor(e.key)}: ${v != null ? v.toStringAsFixed(1) : e.value}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 11, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(_fmtTs(criadoEm),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              if (confianca != null) ...[
                const SizedBox(width: 12),
                Text('Confiança: ${_fmtConfianca(confianca)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _humanizeAnomalia(String tipo) {
    const map = {
      'temperatura_alta': 'Temperatura alta',
      'temperatura_baixa': 'Temperatura baixa',
      'humidade_alta': 'Humidade alta',
      'humidade_baixa': 'Humidade baixa',
      'pressao_anormal': 'Pressão anormal',
      'praga_detetada': 'Praga detetada',
    };
    return map[tipo] ?? tipo;
  }

  String _labelSensor(String key) {
    const map = {
      'temperatura_ar': 'Temp.',
      'humidade_ar': 'Hum. ar',
      'pressao': 'Pressão',
    };
    return map[key] ?? key;
  }
}

// ── Widgets auxiliares Firebase ────────────────────────────────

class _FirebaseErrorView extends StatelessWidget {
  final String message;
  const _FirebaseErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
}

class _FirebaseEmptyView extends StatelessWidget {
  final String message;
  const _FirebaseEmptyView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sensors_off_outlined,
                size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// ECRÃ OPEN-METEO — outras explorações
// ══════════════════════════════════════════════════════════════

class _WeatherSensorsScreen extends StatefulWidget {
  const _WeatherSensorsScreen();

  @override
  State<_WeatherSensorsScreen> createState() =>
      _WeatherSensorsScreenState();
}

class _WeatherSensorsScreenState extends State<_WeatherSensorsScreen> {
  bool _isLoading = true;
  String? _error;

  List<DateTime> _times = [];
  List<double> _temperatures = [];
  List<double> _humidities = [];

  double? _currentTemp;
  double? _currentHumidity;
  double? _currentWind;
  String _location = '';

  // 0=24h, 1=3 dias, 2=7 dias
  int _period = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  double? _parseLat() {
    final gps = context.read<FarmProvider>().selectedFarm?.farmGps;
    if (gps == null) return null;
    final p = gps.split(',');
    return p.length >= 2 ? double.tryParse(p[0].trim()) : null;
  }

  double? _parseLng() {
    final gps = context.read<FarmProvider>().selectedFarm?.farmGps;
    if (gps == null) return null;
    final p = gps.split(',');
    return p.length >= 2 ? double.tryParse(p[1].trim()) : null;
  }

  Future<void> _fetchData() async {
    final lat = _parseLat();
    final lng = _parseLng();
    final farmCity =
        context.read<FarmProvider>().selectedFarm?.farmCity ?? '';
    if (lat == null || lng == null) {
      setState(() {
        _isLoading = false;
        _error = 'GPS da exploração não definido';
      });
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await Dio().get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'hourly':
              'temperature_2m,relative_humidity_2m,wind_speed_10m',
          'current':
              'temperature_2m,relative_humidity_2m,wind_speed_10m',
          'timezone': 'Europe/Lisbon',
          'past_days': 7,
          'forecast_days': 1,
        },
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      final data = response.data as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>? ?? {};
      final hourly = data['hourly'] as Map<String, dynamic>? ?? {};

      final allTimes = (hourly['time'] as List?)
              ?.map((t) => DateTime.parse(t as String))
              .toList() ??
          [];
      final allTemps = (hourly['temperature_2m'] as List?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          [];
      final allHumids = (hourly['relative_humidity_2m'] as List?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          [];

      _location = farmCity;

      _currentTemp =
          (current['temperature_2m'] as num?)?.toDouble();
      _currentHumidity =
          (current['relative_humidity_2m'] as num?)?.toDouble();
      _currentWind =
          (current['wind_speed_10m'] as num?)?.toDouble();

      setState(() {
        _times = allTimes;
        _temperatures = allTemps;
        _humidities = allHumids;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Sem ligação ou GPS inválido.';
        _isLoading = false;
      });
    }
  }

  List<DateTime> get _filteredTimes {
    final now = DateTime.now();
    final cutoff = _period == 0
        ? now.subtract(const Duration(hours: 24))
        : _period == 1
            ? now.subtract(const Duration(days: 3))
            : now.subtract(const Duration(days: 7));
    return _times
        .where((t) => t.isAfter(cutoff) && t.isBefore(now))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: Text(_location.isNotEmpty
            ? 'Sensores · $_location'
            : 'Sensores'),
        actions: [
          if (context.read<FarmProvider>().selectedFarm?.canManage ?? false)
            IconButton(
              icon: const Icon(Icons.settings_input_antenna),
              tooltip: 'Associar sensores',
              onPressed: () => _showAssociationSheet(context),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _WeatherError(message: _error!, onRetry: _fetchData)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final filtered = _filteredTimes;
    final tempFiltered = <double>[];
    final humFiltered = <double>[];
    for (final t in filtered) {
      final i = _times.indexOf(t);
      if (i < _temperatures.length) tempFiltered.add(_temperatures[i]);
      if (i < _humidities.length) humFiltered.add(_humidities[i]);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cards de resumo
        Row(
          children: [
            Expanded(
              child: _WeatherCard(
                label: 'Temperatura',
                value: _currentTemp != null
                    ? '${_currentTemp!.toStringAsFixed(1)}°C'
                    : '—',
                icon: Icons.thermostat,
                color: _currentTemp != null && _currentTemp! > 30
                    ? AppTheme.error
                    : AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WeatherCard(
                label: 'Humidade',
                value: _currentHumidity != null
                    ? '${_currentHumidity!.toStringAsFixed(0)}%'
                    : '—',
                icon: Icons.water_drop_outlined,
                color: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WeatherCard(
                label: 'Vento',
                value: _currentWind != null
                    ? '${_currentWind!.toStringAsFixed(1)} km/h'
                    : '—',
                icon: Icons.air,
                color: const Color(0xFF7B1FA2),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Seletor de período
        Row(
          children: [
            _PeriodBtn(
                label: '24h',
                active: _period == 0,
                onTap: () => setState(() => _period = 0)),
            const SizedBox(width: 8),
            _PeriodBtn(
                label: '3 dias',
                active: _period == 1,
                onTap: () => setState(() => _period = 1)),
            const SizedBox(width: 8),
            _PeriodBtn(
                label: '7 dias',
                active: _period == 2,
                onTap: () => setState(() => _period = 2)),
          ],
        ),

        const SizedBox(height: 16),

        if (tempFiltered.isNotEmpty) ...[
          _ChartSection(
            title: 'Temperatura (°C)',
            times: filtered,
            values: tempFiltered,
            color: AppTheme.primary,
            unit: '°C',
          ),
          const SizedBox(height: 16),
          _ChartSection(
            title: 'Humidade (%)',
            times: filtered,
            values: humFiltered,
            color: const Color(0xFF1565C0),
            unit: '%',
          ),
        ],
      ],
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _WeatherCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      );
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PeriodBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? AppTheme.primary : AppTheme.divider),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppTheme.textPrimary)),
        ),
      );
}

class _ChartSection extends StatelessWidget {
  final String title;
  final List<DateTime> times;
  final List<double> values;
  final Color color;
  final String unit;
  const _ChartSection(
      {required this.title,
      required this.times,
      required this.values,
      required this.color,
      required this.unit});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final minY = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 2;

    final spots = List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.divider, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        color.withValues(alpha: 0.9),
                    getTooltipItems: (spots) => spots.map((s) {
                      final i = s.x.toInt();
                      final time =
                          i < times.length ? times[i] : null;
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(1)}$unit\n'
                        '${time != null ? DateFormat('dd/MM HH:mm').format(time) : ''}',
                        const TextStyle(
                            color: Colors.white, fontSize: 11),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _WeatherError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente')),
          ],
        ),
      );
}
