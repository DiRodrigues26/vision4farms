import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/theme/app_theme.dart';

class WorkerJoinScreen extends StatefulWidget {
  const WorkerJoinScreen({super.key});

  @override
  State<WorkerJoinScreen> createState() => _WorkerJoinScreenState();
}

class _WorkerJoinScreenState extends State<WorkerJoinScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiService();

  // Tab 1 — Código de convite
  final _codeController = TextEditingController();
  bool _codeLoading = false;
  String? _codeError;
  String? _codeSuccess;

  // Tab 2 — Pesquisar exploração
  final _searchController = TextEditingController();
  bool _searchLoading = false;
  String? _searchError;
  List<dynamic> _searchResults = [];
  int? _requestedFarmId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Entrar com código ──────────────────────────────────
  Future<void> _joinWithCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _codeError = 'Introduz o código de convite.');
      return;
    }
    setState(() { _codeLoading = true; _codeError = null; _codeSuccess = null; });
    try {
      final response = await _api.post('/farms/invite/join/', data: {'invite_code': code});
      setState(() => _codeSuccess = response.data['detail']);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/farms');
    } catch (e) {
      setState(() => _codeError = _parseError(e));
    } finally {
      if (mounted) setState(() => _codeLoading = false);
    }
  }

  // ── Pesquisar exploração ───────────────────────────────
  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchError = 'Introduz o nome da exploração.');
      return;
    }
    setState(() { _searchLoading = true; _searchError = null; _searchResults = []; });
    try {
      final response = await _api.post('/farms/access/search/', data: {'query': query});
      setState(() => _searchResults = ApiService.extractResults(response.data));
    } catch (e) {
      setState(() => _searchError = _parseError(e));
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _requestAccess(int farmId, String farmName) async {
    setState(() => _requestedFarmId = farmId);
    try {
      await _api.post('/farms/access/$farmId/request/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido enviado a "$farmName". Aguarda aprovação do gestor.'),
            backgroundColor: AppTheme.success,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/farms');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e)), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _requestedFarmId = null);
    }
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) return data['detail'];
    }
    return 'Erro inesperado. Tenta novamente.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding/role'),
        ),
        title: const Text('Entrar numa exploração',
            style: TextStyle(color: AppTheme.textPrimary)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Código de convite', icon: Icon(Icons.vpn_key_outlined)),
            Tab(text: 'Pesquisar', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCodeTab(),
          _buildSearchTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Código ──────────────────────────────────────
  Widget _buildCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.vpn_key_outlined, size: 48, color: AppTheme.primary),
          const SizedBox(height: 16),
          const Text('Tens um código de convite?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Pede ao gestor da exploração que gere um código e introduz-o aqui.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 32),

          if (_codeSuccess != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_codeSuccess!,
                      style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_codeError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_codeError!, style: const TextStyle(color: AppTheme.error)),
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Código de convite (ex: ABC12345)',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _codeLoading ? null : _joinWithCode,
            child: _codeLoading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Entrar na exploração'),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Pesquisa ────────────────────────────────────
  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da exploração',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onFieldSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _searchLoading ? null : _search,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(60, 52),
                  padding: EdgeInsets.zero,
                ),
                child: _searchLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search),
              ),
            ],
          ),
        ),

        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_searchError!, style: const TextStyle(color: AppTheme.error)),
            ),
          ),

        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.agriculture_outlined, size: 64,
                          color: AppTheme.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      const Text('Pesquisa uma exploração pelo nome',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final farm = _searchResults[index];
                    final farmId = farm['farm_id'];
                    final isRequesting = _requestedFarmId == farmId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.agriculture_outlined,
                                  color: AppTheme.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(farm['farm_name'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w600)),
                                  if (farm['farm_city'] != null)
                                    Text('${farm['farm_city']}, ${farm['farm_district'] ?? ''}',
                                        style: const TextStyle(
                                            fontSize: 13, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: isRequesting
                                  ? null
                                  : () => _requestAccess(farmId, farm['farm_name']),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(80, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: isRequesting
                                  ? const SizedBox(height: 16, width: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('Pedir acesso'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}