import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
import 'dashboard_screen.dart';
import '../../lands/screens/create_land_dialog.dart';
import '../../crops/screens/create_crop_dialog.dart';
import '../../activities/screens/activity_create_screen.dart';
import '../../observations/screens/observation_create_dialog.dart';
import '../../agenda/screens/agenda_create_dialog.dart';

/// Widget wrapper para o conteúdo do Dashboard (rota /home)
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});
  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

class MainShellScreen extends StatefulWidget {
  final Widget child;
  const MainShellScreen({super.key, required this.child});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with SingleTickerProviderStateMixin {
  bool _menuOpen = false;

  late final AnimationController _menuController;
  late final Animation<double> _menuFade;
  late final Animation<Offset> _menuSlide;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _menuFade = CurvedAnimation(parent: _menuController, curve: Curves.easeOut);
    _menuSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _menuController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    HapticFeedback.lightImpact();
    if (_menuOpen) {
      _menuController.reverse().then((_) => setState(() => _menuOpen = false));
    } else {
      setState(() => _menuOpen = true);
      _menuController.forward();
    }
  }

  void _closeMenu() {
    if (_menuOpen) {
      _menuController.reverse().then((_) => setState(() => _menuOpen = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc    = GoRouterState.of(context).matchedLocation;
    final onHome = loc == '/home';

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          if (_menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMenu,
                child: FadeTransition(
                  opacity: _menuFade,
                  child: SlideTransition(
                    position: _menuSlide,
                    child: _AddMenu(onClose: _closeMenu),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, loc),
      floatingActionButton: _buildFAB(context, onHome),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ── Bottom nav ────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context, String loc) {
    return BottomAppBar(
      color: AppTheme.surface,
      elevation: 8,
      notchMargin: 6,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomNavItem(
              icon: Icons.map_outlined, activeIcon: Icons.map,
              label: 'Mapa',
              isActive: loc.startsWith('/map'),
              onTap: () { _closeMenu(); context.go('/map'); },
            ),
            _BottomNavItem(
              icon: Icons.checklist_outlined, activeIcon: Icons.checklist,
              label: 'Atividades',
              isActive: loc.startsWith('/activities'),
              onTap: () { _closeMenu(); context.go('/activities'); },
            ),
            const SizedBox(width: 60), // espaço para o FAB
            _BottomNavItem(
              icon: Icons.grass_outlined, activeIcon: Icons.grass,
              label: 'Terrenos',
              isActive: loc.startsWith('/lands'),
              onTap: () { _closeMenu(); context.go('/lands'); },
            ),
            _BottomNavItem(
              icon: Icons.energy_savings_leaf_outlined,
              activeIcon: Icons.energy_savings_leaf,
              label: 'Culturas',
              isActive: loc.startsWith('/crops'),
              onTap: () { _closeMenu(); context.go('/crops'); },
            ),
          ],
        ),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context, bool onHome) {
    final bgColor = _menuOpen ? AppTheme.primaryDark : AppTheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onHome
            ? _toggleMenu
            : () { _closeMenu(); context.go('/home'); },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: onHome
            ? AnimatedRotation(
                turns: _menuOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 280),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              )
            : const Icon(Icons.home_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

// ── Menu verde ────────────────────────────────────────────────

class _AddMenu extends StatelessWidget {
  final VoidCallback onClose;
  const _AddMenu({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MenuItem(
                    label: 'Agendar evento',
                    onTap: () { onClose(); showCreateAgendaDialog(context); },
                  ),
                  const _MenuDivider(),
                  _MenuItem(
                    label: 'Adicionar observação',
                    onTap: () { onClose(); showCreateObservationDialog(context); },
                  ),
                  const _MenuDivider(),
                  _MenuItem(
                    label: 'Adicionar Atividade',
                    onTap: () { onClose(); showCreateActivityDialog(context); },
                  ),
                  const _MenuDivider(),
                  _MenuItem(
                    label: 'Adicionar Terreno',
                    onTap: () {
                      onClose();
                      showDialog(
                        context: context,
                        barrierColor: Colors.black54,
                        builder: (_) => const CreateLandDialog(),
                      );
                    },
                  ),
                  const _MenuDivider(),
                  _MenuItem(
                    label: 'Adicionar Cultura',
                    onTap: () {
                      onClose();
                      showDialog(
                        context: context,
                        barrierColor: Colors.black54,
                        builder: (_) => const CreateCropDialog(),
                      );
                    },
                  ),
                  const _MenuDivider(),
                  _MenuItem(
                    label: 'Adicionar Exploração',
                    onTap: () { onClose(); context.go('/farms/create'); },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();
  @override
  Widget build(BuildContext context) => Divider(
    color: Colors.white.withOpacity(0.3), height: 1, thickness: 1);
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon, required this.activeIcon,
    required this.label, required this.isActive, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? AppTheme.primary : AppTheme.textSecondary,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              )),
        ],
      ),
    ),
  );
}
