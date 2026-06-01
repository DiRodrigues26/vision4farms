import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';

class FarmCreateScreen extends StatefulWidget {
  const FarmCreateScreen({super.key});

  @override
  State<FarmCreateScreen> createState() => _FarmCreateScreenState();
}

class _FarmCreateScreenState extends State<FarmCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _dateController        = TextEditingController();
  final _valueController       = TextEditingController();
  final _addressController     = TextEditingController();
  final _postalController      = TextEditingController();
  final _localidadeController  = TextEditingController();
  final _concelhoController    = TextEditingController();
  final _distritoController    = TextEditingController();
  final _paisController        = TextEditingController(text: 'Portugal');

  bool _isLoading = false;
  bool _isLoadingPostal = false;
  String? _error;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _postalController.addListener(_onPostalChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _valueController.dispose();
    _addressController.dispose();
    _postalController.dispose();
    _localidadeController.dispose();
    _concelhoController.dispose();
    _distritoController.dispose();
    _paisController.dispose();
    super.dispose();
  }

  // Debounce para o código postal
  DateTime? _lastPostalChange;
  void _onPostalChanged() {
    final postal = _postalController.text.replaceAll('-', '').replaceAll(' ', '');
    if (postal.length == 7) {
      _lastPostalChange = DateTime.now();
      final snapshot = _lastPostalChange;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_lastPostalChange == snapshot) _lookupPostal(postal);
      });
    }
  }

  Future<void> _lookupPostal(String postal) async {
    // Formatar: XXXX-XXX
    final formatted = '${postal.substring(0, 4)}-${postal.substring(4)}';
    setState(() => _isLoadingPostal = true);
    try {
      final response = await Dio().get(
        'https://json.geoapi.pt/cp/$formatted',
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _localidadeController.text = data['Localidade']?.toString() ?? data['localidade']?.toString() ?? '';
          _concelhoController.text   = data['Concelho']?.toString()   ?? data['concelho']?.toString()   ?? '';
          _distritoController.text   = data['Distrito']?.toString()   ?? data['distrito']?.toString()   ?? '';
        });
      }
    } catch (_) {
      // Silencioso — utilizador pode preencher manualmente
    } finally {
      if (mounted) setState(() => _isLoadingPostal = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      await _api.post(AppConstants.farmsCreate, data: {
        'farm_name':     _nameController.text.trim(),
        'farm_address':  _addressController.text.trim(),
        'farm_zipcode':  _postalController.text.trim(),
        'farm_city':     _localidadeController.text.trim(),
        'farm_location': _concelhoController.text.trim(),
        'farm_district': _distritoController.text.trim(),
        'farm_country':  _paisController.text.trim(),
        'farm_description': '',
        'farm_status': 1,
      });

      if (!mounted) return;
      await context.read<FarmProvider>().loadFarms();
      if (!mounted) return;

      // Dialog de confirmação
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SuccessDialog(
          onOk: () {
            Navigator.pop(context);
            context.go('/farms');
          },
        ),
      );
    } catch (e) {
      String msg = 'Erro ao criar exploração.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data.containsKey('detail')) msg = data['detail'];
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                    onPressed: () => context.go('/farms'),
                  ),
                  const Expanded(
                    child: Text('Nova Exploração',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                  ),
                  const SizedBox(width: 48), // balanço
                ],
              ),
            ),

            // Formulário
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Identificação ───────────────────
                      const _SectionTitle(title: 'Identificação da exploração'),
                      const SizedBox(height: 16),

                      _FieldLabel(label: 'Nome'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(hintText: 'Insira o nome'),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),

                      _FieldLabel(label: 'Data de fundação / aquisição'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          hintText: 'dd/mm/aaaa',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_outlined,
                                size: 18, color: AppTheme.textSecondary),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                                locale: const Locale('pt', 'PT'),
                              );
                              if (date != null) {
                                _dateController.text =
                                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                              }
                            },
                          ),
                        ),
                        readOnly: true,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),

                      _FieldLabel(label: 'Valor de aquisição'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _valueController,
                        decoration: const InputDecoration(hintText: '0,00€'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 28),

                      // ── Morada ──────────────────────────
                      const _SectionTitle(title: 'Morada'),
                      const SizedBox(height: 16),

                      _FieldLabel(label: 'Morada'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(hintText: 'Insira a morada da exploração'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(label: 'Código-Postal'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _postalController,
                                  decoration: InputDecoration(
                                    hintText: 'Insira o código postal',
                                    suffixIcon: _isLoadingPostal
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(width: 16, height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2,
                                                    color: AppTheme.primary)))
                                        : null,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(7),
                                    _PostalCodeFormatter(),
                                  ],
                                  textInputAction: TextInputAction.next,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(label: 'Localidade'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _localidadeController,
                                  decoration: const InputDecoration(hintText: 'Insira a localidade'),
                                  textInputAction: TextInputAction.next,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(label: 'Concelho'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _concelhoController,
                                  decoration: const InputDecoration(hintText: 'Insira o concelho'),
                                  textInputAction: TextInputAction.next,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(label: 'Distrito'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _distritoController,
                                  decoration: const InputDecoration(hintText: 'Insira o distrito'),
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),

            // Botão fixo na base
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add, color: Colors.white),
                  label: const Text('Adicionar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog de sucesso ──────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final VoidCallback onOk;
  const _SuccessDialog({required this.onOk});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Exploração adicionada com sucesso!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onOk,
              child: const Text('Ok'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary),
    textAlign: TextAlign.center,
  );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary),
  );
}

// Formata automaticamente XXXX-XXX
class _PostalCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('-', '');
    if (digits.length <= 4) return newValue.copyWith(text: digits);
    final formatted = '${digits.substring(0, 4)}-${digits.substring(4)}';
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}