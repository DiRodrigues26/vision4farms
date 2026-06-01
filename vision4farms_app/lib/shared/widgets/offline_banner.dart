import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../shared/theme/app_theme.dart';

/// Envolve toda a app via MaterialApp.builder.
/// Mostra banner persistente quando offline.
/// Mostra "A sincronizar..." quando volta online.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;

  bool _bannerVisible = false;
  bool _showSyncing   = false;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(
      begin: const Offset(0, -1), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _update(bool isOnline) {
    if (!isOnline && !_bannerVisible) {
      setState(() { _bannerVisible = true; _showSyncing = false; });
      _ctrl.forward();
    } else if (isOnline && _bannerVisible && !_showSyncing) {
      setState(() => _showSyncing = true);
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        _ctrl.reverse().then((_) {
          if (mounted) setState(() {
            _bannerVisible = false;
            _showSyncing   = false;
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, conn, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _update(conn.isOnline));
        return Stack(
          children: [
            widget.child,
            if (_bannerVisible)
              Positioned(
                top: 0, left: 0, right: 0,
                child: SlideTransition(
                  position: _slide,
                  child: SafeArea(
                    bottom: false,
                    child: _showSyncing
                        ? const _SyncingBanner()
                        : const _OfflineBannerBar(),
                  ),
                ),
              ),
            // Banner persistente de pendentes (mostrado quando não há offline banner)
            if (!_bannerVisible)
              const Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _PendingOpsChip(),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Chip discreto no topo que mostra a contagem de operações pendentes/falhadas
/// e abre o ecrã de operações pendentes ao tocar.
class _PendingOpsChip extends StatelessWidget {
  const _PendingOpsChip();

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, sync, _) {
        if (sync.isSyncing) {
          return _ChipBubble(
            color: const Color(0xFF1565C0),
            icon: Icons.sync,
            label: 'A sincronizar...',
            onTap: () => context.go('/sync/pending'),
            spinning: true,
          );
        }
        if (sync.failedCount > 0) {
          return _ChipBubble(
            color: AppTheme.error,
            icon: Icons.error_outline,
            label: '${sync.failedCount} falhada(s)',
            onTap: () => context.go('/sync/pending'),
          );
        }
        if (sync.pendingCount > 0) {
          return _ChipBubble(
            color: const Color(0xFFFFA726),
            icon: Icons.cloud_upload_outlined,
            label: '${sync.pendingCount} pendente(s)',
            onTap: () => context.go('/sync/pending'),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ChipBubble extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool spinning;

  const _ChipBubble({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (spinning)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              else
                Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBannerBar extends StatelessWidget {
  const _OfflineBannerBar();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF212121),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8,
          offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 18),
      const SizedBox(width: 10),
      const Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sem ligação à internet',
              style: TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text('A mostrar dados guardados',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      )),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.white12,
            borderRadius: BorderRadius.circular(8)),
        child: const Text('OFFLINE',
            style: TextStyle(color: Colors.white70, fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    ]),
  );
}

class _SyncingBanner extends StatelessWidget {
  const _SyncingBanner();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.success,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8,
          offset: const Offset(0, 2))],
    ),
    child: const Row(children: [
      SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      SizedBox(width: 10),
      Expanded(child: Text('A sincronizar dados...',
          style: TextStyle(color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w600))),
      Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
    ]),
  );
}

/// Ecrã de erro quando não há cache nem rede.
class OfflineEmptyScreen extends StatelessWidget {
  final VoidCallback? onRetry;
  const OfflineEmptyScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: AppTheme.divider,
                shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, size: 40,
                color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('Sem ligação', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Não foi possível carregar os dados.\nLiga-te à internet e tenta novamente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary,
                height: 1.5),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
