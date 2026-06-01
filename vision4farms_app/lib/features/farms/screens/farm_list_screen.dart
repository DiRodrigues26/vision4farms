import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/models/farm_model.dart';
import '../../../shared/theme/app_theme.dart';
import 'farm_shell_screen.dart';

class FarmListScreen extends StatelessWidget {
  const FarmListScreen({super.key});

  @override
  Widget build(BuildContext context) => const FarmShellScreen();
}

class FarmListBody extends StatefulWidget {
  const FarmListBody({super.key});

  @override
  State<FarmListBody> createState() => _FarmListBodyState();
}

class _FarmListBodyState extends State<FarmListBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FarmProvider>().loadFarms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final farmProvider = context.watch<FarmProvider>();
    final farms = farmProvider.farms;
    final isManager = farms.any((f) => f.isManager);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: farmProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () => farmProvider.loadFarms(),
                child: CustomScrollView(
                  slivers: [
                    // Título
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Text(
                          'As Suas Explorações',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    // Label da lista
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: _SectionLabel(label: 'Todas as suas explorações'),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // Lista de farms
                    farms.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmpty(isManager))
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _FarmCard(farm: farms[index]),
                                ),
                                childCount: farms.length,
                              ),
                            ),
                          ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),

      // Botão fixo na base — só para gestores
      bottomNavigationBar: isManager
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await context.push('/farms/create');
                    if (context.mounted) context.read<FarmProvider>().loadFarms();
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Adicionar nova exploração'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmpty(bool isManager) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.agriculture_outlined, size: 64,
                color: AppTheme.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('Nenhuma exploração',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(
              isManager
                  ? 'Cria a tua primeira exploração'
                  : 'Aguarda que um gestor te adicione',
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Label de secção ────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary,
        fontWeight: FontWeight.w500),
  );
}

// ── Card de farm ───────────────────────────────────────────
class _FarmCard extends StatefulWidget {
  final FarmModel farm;
  const _FarmCard({required this.farm});

  @override
  State<_FarmCard> createState() => _FarmCardState();
}

class _FarmCardState extends State<_FarmCard> {
  bool _loading = false;

  static String _roleLabel(int role) {
    const labels = {1: 'Gestor', 2: 'Colaborador', 3: 'Consultor'};
    return labels[role] ?? 'Membro';
  }

  static Color _roleBadgeColor(int role) {
    const colors = {1: AppTheme.primary, 2: Color(0xFFFFA726), 3: Color(0xFF1565C0)};
    return colors[role] ?? AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _loading ? null : () async {
          setState(() => _loading = true);
          final router = GoRouter.of(context);
          final farmProvider = context.read<FarmProvider>();
          await farmProvider.selectFarm(widget.farm);
          router.go('/home');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(widget.farm.farmName,
                              style: const TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _roleBadgeColor(widget.farm.userRole).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _roleLabel(widget.farm.userRole),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _roleBadgeColor(widget.farm.userRole),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14,
                          color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        [widget.farm.farmCity, widget.farm.farmDistrict]
                            .where((e) => e != null && e.isNotEmpty).join(', '),
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      if (widget.farm.farmSize != null) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.crop_square_outlined, size: 14,
                            color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text('${widget.farm.farmSize!.toStringAsFixed(0)} ha',
                            style: const TextStyle(fontSize: 13,
                                color: AppTheme.textSecondary)),
                      ],
                    ]),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
              else
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}