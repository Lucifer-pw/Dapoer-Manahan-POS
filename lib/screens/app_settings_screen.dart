import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import 'admin_billing_screen.dart';
import 'billing_history_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _ssidController.text = settings.wifiSsid;
    _passwordController.text = settings.wifiPassword;
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    try {
      await settings.updateWifi(_ssidController.text, _passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan berhasil disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildThemeTile(
    BuildContext context,
    String title,
    IconData icon,
    ThemeMode mode,
    ThemeProvider themeProv,
  ) {
    final isSelected = themeProv.themeMode == mode;
    return ListTile(
      onTap: () => themeProv.setThemeMode(mode),
      leading: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textHint),
      title: Text(title, style: AppTextStyles.body),
      trailing: isSelected 
        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
        : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Toko'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Tampilan'),
            const SizedBox(height: 16),
            Consumer<ThemeProvider>(
              builder: (context, themeProv, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      _buildThemeTile(
                        context,
                        'Tema Terang',
                        Icons.light_mode_rounded,
                        ThemeMode.light,
                        themeProv,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildThemeTile(
                        context,
                        'Tema Gelap',
                        Icons.dark_mode_rounded,
                        ThemeMode.dark,
                        themeProv,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildThemeTile(
                        context,
                        'Ikuti Sistem HP',
                        Icons.settings_brightness_rounded,
                        ThemeMode.system,
                        themeProv,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Informasi WiFi'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _ssidController,
              label: 'Nama WiFi (SSID)',
              icon: Icons.wifi,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password WiFi',
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  return ElevatedButton(
                    onPressed: settings.isLoading ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: settings.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('SIMPAN PENGATURAN'),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Billing'),
            const SizedBox(height: 16),
            _buildSettingsTile(
              icon: Icons.history_rounded,
              title: 'Riwayat Pembayaran',
              subtitle: 'Lihat daftar pembayaran aplikasi',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillingHistoryScreen()),
                );
              },
            ),
            
            // Admin Section
            Consumer<AuthProvider>(builder: (context, auth, _) {
              if (!auth.isAdmin) return const SizedBox.shrink();
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  _buildSectionHeader('Administrator'),
                  const SizedBox(height: 16),
                  _buildSettingsTile(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Kelola Billing (Admin)',
                    subtitle: 'Update status pembayaran toko',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminBillingScreen()),
                      );
                    },
                  ),
                ],
              );
            }),
            const SizedBox(height: 40),

            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.hasData 
                      ? ' | v${snapshot.data!.version}+${snapshot.data!.buildNumber}' 
                      : '';
                  return Text(
                    'Powered by LUCIFAX$version',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint.withOpacity(0.5),
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: AppTextStyles.subtitle),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
