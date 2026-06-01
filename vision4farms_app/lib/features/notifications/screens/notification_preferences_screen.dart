import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/safe_back.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Tipos de notificação
  bool _notifyActivity = true;
  bool _notifyAgenda = true;
  bool _notifyObservation = true;
  bool _notifyIrrigation = true;
  bool _notifySystem = true;

  // Tempo de antecedência do lembrete
  double _reminderHours = 24.0;

  static const List<Map<String, dynamic>> _reminderOptions = [
    {'label': '1 minuto antes', 'hours': 0.0167},
    {'label': '15 minutos antes', 'hours': 0.25},
    {'label': '30 minutos antes', 'hours': 0.5},
    {'label': '1 hora antes', 'hours': 1.0},
    {'label': '2 horas antes', 'hours': 2.0},
    {'label': '6 horas antes', 'hours': 6.0},
    {'label': '12 horas antes', 'hours': 12.0},
    {'label': '24 horas antes', 'hours': 24.0},
    {'label': '48 horas antes', 'hours': 48.0},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get(AppConstants.notificationPreferences);
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _notifyActivity = (data['notify_activity'] ?? 1) == 1;
        _notifyAgenda = (data['notify_agenda'] ?? 1) == 1;
        _notifyObservation = (data['notify_observation'] ?? 1) == 1;
        _notifyIrrigation = (data['notify_irrigation'] ?? 1) == 1;
        _notifySystem = (data['notify_system'] ?? 1) == 1;
        _reminderHours = double.tryParse(data['reminder_hours']?.toString() ?? '24') ?? 24.0;
      });
    } catch (_) {
      // Usar defaults se falhar
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      await _api.patch(AppConstants.notificationPreferences, data: {
        'notify_activity': _notifyActivity ? 1 : 0,
        'notify_agenda': _notifyAgenda ? 1 : 0,
        'notify_observation': _notifyObservation ? 1 : 0,
        'notify_irrigation': _notifyIrrigation ? 1 : 0,
        'notify_system': _notifySystem ? 1 : 0,
        'reminder_hours': _reminderHours,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferências guardadas.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao guardar preferências.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                    onPressed: () => safeBack(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Preferências de Notificações',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Notificações imediatas (sem lembrete)
                        const Text(
                          'Notificações imediatas',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Recebidas no momento em que são criadas',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        _NotifToggle(
                          icon: Icons.checklist,
                          label: 'Atividades',
                          subtitle: 'Novas atividades',
                          value: _notifyActivity,
                          color: AppTheme.primary,
                          onChanged: (v) => setState(() => _notifyActivity = v),
                        ),
                        _NotifToggle(
                          icon: Icons.visibility_outlined,
                          label: 'Observações',
                          subtitle: 'Novas observações de campo',
                          value: _notifyObservation,
                          color: const Color(0xFF1565C0),
                          onChanged: (v) => setState(() => _notifyObservation = v),
                        ),
                        _NotifToggle(
                          icon: Icons.info_outline,
                          label: 'Sistema',
                          subtitle: 'Alertas e atualizações do sistema',
                          value: _notifySystem,
                          color: AppTheme.textSecondary,
                          onChanged: (v) => setState(() => _notifySystem = v),
                        ),

                        const SizedBox(height: 28),

                        // Notificações com lembrete
                        const Text(
                          'Notificações com lembrete',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Avisam-te com antecedência antes do evento',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        _NotifToggle(
                          icon: Icons.calendar_today,
                          label: 'Agenda',
                          subtitle: 'Novos eventos e tarefas do calendário',
                          value: _notifyAgenda,
                          color: const Color(0xFFFFA726),
                          onChanged: (v) => setState(() => _notifyAgenda = v),
                        ),
                        _NotifToggle(
                          icon: Icons.water_drop_outlined,
                          label: 'Rega',
                          subtitle: 'Planeamento e registos de rega',
                          value: _notifyIrrigation,
                          color: const Color(0xFF00ACC1),
                          onChanged: (v) => setState(() => _notifyIrrigation = v),
                        ),

                        const SizedBox(height: 20),

                        // Tempo de lembrete (aplica-se apenas a Agenda/Rega)
                        const Text(
                          'Antecedência do lembrete',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Quanto tempo antes queres ser avisado',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Column(
                            children: _reminderOptions.map((opt) {
                              final hours = (opt['hours'] as double);
                              final isSelected = (_reminderHours - hours).abs() < 0.001;
                              return InkWell(
                                onTap: () => setState(() => _reminderHours = hours),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 20,
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        opt['label'] as String,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Botão guardar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _savePreferences,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Guardar preferências',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _NotifToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
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
