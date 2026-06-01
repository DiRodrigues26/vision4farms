import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import 'farm_list_screen.dart';
import '../../onboarding/screens/join_screen.dart';

class FarmShellScreen extends StatefulWidget {
  const FarmShellScreen({super.key});

  @override
  State<FarmShellScreen> createState() => _FarmShellScreenState();
}

class _FarmShellScreenState extends State<FarmShellScreen> {
  int _currentIndex = 0;

  final List<_Tab> _tabs = const [
    _Tab(label: 'Explorações', icon: Icons.agriculture_outlined, activeIcon: Icons.agriculture),
    _Tab(label: 'Juntar',      icon: Icons.group_add_outlined,   activeIcon: Icons.group_add),
  ];

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return const FarmListBody();
      case 1: return const JoinScreen();
      default: return const FarmListBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withOpacity(0.15),
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          selectedIcon: Icon(t.activeIcon, color: AppTheme.primary),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _Tab({required this.label, required this.icon, required this.activeIcon});
}