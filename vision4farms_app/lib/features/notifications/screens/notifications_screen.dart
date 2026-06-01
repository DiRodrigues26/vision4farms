import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/services/local_database.dart';

// ═══════════════════════════════════════════════════════════════
// Helpers públicos — chamados de qualquer sítio
// ═══════════════════════════════════════════════════════════════

/// Overlay (dialog) — para o sino da dashboard
Future<void> showNotificationsOverlay(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    barrierDismissible: true,
    builder: (_) => const _NotificationsOverlayDialog(),
  );
}

/// Ecrã completo — para o perfil
Future<void> openNotificationsPage(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
  );
}

// ═══════════════════════════════════════════════════════════════
//  Mixin com lógica partilhada (load, toggle, mark)
// ═══════════════════════════════════════════════════════════════

mixin _NotificationLogic<T extends StatefulWidget> on State<T> {
  final ApiService nApi = ApiService();
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  String? error;

  Future<void> loadNotifications() async {
    setState(() { isLoading = true; error = null; });
    final farm = context.read<FarmProvider>().selectedFarm;
    try {
      final params = farm != null ? {'farm_id': farm.farmId} : null;
      final response = await nApi.get(AppConstants.notifications, params: params);
      final data = ApiService.extractResults(response.data);
      if (farm != null) await LocalDatabase.saveNotifications(farm.farmId, data);
      setState(() => notifications = data.cast<Map<String, dynamic>>());
    } catch (e) {
      final cached = farm != null
          ? await LocalDatabase.getNotifications(farm.farmId)
          : <Map<String, dynamic>>[];
      if (cached.isNotEmpty) {
        setState(() => notifications = cached);
      } else {
        setState(() => error = 'Sem ligação e sem dados guardados.');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> toggleRead(int index) async {
    final n = notifications[index];
    final id = n['notification_id'] as int;
    final wasRead = n['notification_read'] == 1;
    setState(() => notifications[index] = {...n, 'notification_read': wasRead ? 0 : 1});
    try {
      await nApi.patch(AppConstants.notificationToggleRead(id));
      if (!wasRead) await LocalDatabase.markNotificationRead(id);
    } catch (_) {
      if (mounted) setState(() => notifications[index] = {...n, 'notification_read': wasRead ? 1 : 0});
    }
  }

  Future<void> markAsRead(int index) async {
    final n = notifications[index];
    if (n['notification_read'] == 1) return;
    final id = n['notification_id'] as int;
    setState(() => notifications[index] = {...n, 'notification_read': 1});
    try {
      await nApi.patch(AppConstants.notificationRead(id));
      await LocalDatabase.markNotificationRead(id);
    } catch (_) {}
  }

  int get unreadCount => notifications.where((n) => n['notification_read'] != 1).length;
}

// ═══════════════════════════════════════════════════════════════
//  1) OVERLAY DIALOG — sino da dashboard
// ═══════════════════════════════════════════════════════════════

class _NotificationsOverlayDialog extends StatefulWidget {
  const _NotificationsOverlayDialog();

  @override
  State<_NotificationsOverlayDialog> createState() => _NotificationsOverlayDialogState();
}

class _NotificationsOverlayDialogState extends State<_NotificationsOverlayDialog>
    with _NotificationLogic<_NotificationsOverlayDialog> {

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Notificações',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ),
                  if (unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, color: AppTheme.divider),

            // Conteúdo
            Flexible(
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : error != null
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text(error!, textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.textSecondary)),
                        )
                      : notifications.isEmpty
                          ? const _EmptyNotifications()
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemCount: notifications.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final n = notifications[index];
                                final isRead = n['notification_read'] == 1;
                                return NotificationCard(
                                  notification: n,
                                  isRead: isRead,
                                  onTap: () {
                                    markAsRead(index);
                                    showNotificationDetail(context, n);
                                  },
                                  onToggleRead: () => toggleRead(index),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  2) ECRÃ COMPLETO — perfil
// ═══════════════════════════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with _NotificationLogic<NotificationsScreen> {

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Notificações'),
        backgroundColor: const Color(0xFFF5F5F0),
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: loadNotifications, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : notifications.isEmpty
                  ? const _EmptyNotifications()
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: loadNotifications,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = notifications[index];
                          final isRead = n['notification_read'] == 1;
                          return NotificationCard(
                            notification: n,
                            isRead: isRead,
                            onTap: () {
                              markAsRead(index);
                              showNotificationDetail(context, n);
                            },
                            onToggleRead: () => toggleRead(index),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Widgets partilhados
// ═══════════════════════════════════════════════════════════════

/// Mostra detalhe de uma notificação em bottom sheet
void showNotificationDetail(BuildContext context, Map<String, dynamic> n) {
  final title = n['notification_title']?.toString() ?? '';
  final body = n['notification_body']?.toString() ?? '';
  final type = n['notification_type']?.toString() ?? '';
  final dateLabel = _formatDateTime(n['created_at']?.toString());

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildTypeIcon(type),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (dateLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(dateLabel, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Text(body, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5)),
          ),
          const SizedBox(height: 16),
          _buildTypeBadge(type),
        ],
      ),
    ),
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_outlined, size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('Sem notificações',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            SizedBox(height: 6),
            Text(
              'As notificações aparecerão aqui quando\ncriares atividades, eventos ou observações.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.isRead,
    required this.onTap,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final title = notification['notification_title']?.toString() ?? '';
    final body = notification['notification_body']?.toString() ?? '';
    final type = notification['notification_type']?.toString() ?? '';
    final dateLabel = _formatDateTime(notification['created_at']?.toString());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? AppTheme.surface : AppTheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? AppTheme.divider : AppTheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _buildTypeIcon(type),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                        ),
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                              color: AppTheme.textPrimary,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(body,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(dateLabel, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onToggleRead,
              child: Tooltip(
                message: isRead ? 'Marcar como não lida' : 'Marcar como lida',
                child: Icon(
                  isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                  size: 20,
                  color: isRead ? AppTheme.textSecondary : AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers visuais ──────────────────────────────────────────

Widget _buildTypeIcon(String type) {
  IconData icon;
  Color color;
  switch (type) {
    case 'activity':
      icon = Icons.assignment_outlined;
      color = AppTheme.primary;
    case 'agenda':
      icon = Icons.calendar_today_outlined;
      color = const Color(0xFFFFA000);
    case 'observation':
      icon = Icons.visibility_outlined;
      color = const Color(0xFF1976D2);
    case 'irrigation':
      icon = Icons.water_drop_outlined;
      color = const Color(0xFF0288D1);
    default:
      icon = Icons.notifications_outlined;
      color = AppTheme.textSecondary;
  }
  return Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, size: 20, color: color),
  );
}

Widget _buildTypeBadge(String type) {
  final labels = {
    'activity': 'Atividade',
    'agenda': 'Agenda',
    'observation': 'Observação',
    'irrigation': 'Rega',
    'system': 'Sistema',
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      labels[type] ?? type,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primary),
    ),
  );
}

String _formatDateTime(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final date = DateTime.parse(dateStr);
    return '${date.day} ${DateFormat('MMM', 'pt_PT').format(date)} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return dateStr;
  }
}
