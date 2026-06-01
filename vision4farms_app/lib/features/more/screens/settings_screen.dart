import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _language = 'pt';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _language = prefs.getString('language') ?? 'pt';
      _loading = false;
    });
  }

  Future<void> _setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    setState(() => _language = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Definições')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Notificações
                _SectionHeader(title: 'Notificações'),
                _SettingsCard(
                  children: [
                    SwitchListTile(
                      title: const Text('Ativar notificações',
                          style: TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                      subtitle: const Text('Receber alertas de atividades e regas',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      value: _notificationsEnabled,
                      onChanged: _setNotifications,
                      activeColor: AppTheme.primary,
                      secondary: Icon(
                        _notificationsEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        color: _notificationsEnabled
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Idioma
                _SectionHeader(title: 'Idioma'),
                _SettingsCard(
                  children: [
                    RadioListTile<String>(
                      value: 'pt',
                      groupValue: _language,
                      onChanged: (v) => _setLanguage(v!),
                      title: const Text('Português',
                          style: TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                      activeColor: AppTheme.primary,
                      secondary: const Text('🇵🇹', style: TextStyle(fontSize: 20)),
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      value: 'en',
                      groupValue: _language,
                      onChanged: (v) => _setLanguage(v!),
                      title: const Text('English',
                          style: TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                      activeColor: AppTheme.primary,
                      secondary: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Sobre
                _SectionHeader(title: 'Sobre'),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
                      title: const Text('Versão',
                          style: TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                      trailing: const Text(AppConstants.appVersion,
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 13,
        fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(children: children),
  );
}
