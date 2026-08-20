import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/subscription_provider.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import 'admin_billing_screen.dart';
import 'billing_history_screen.dart';
import 'salary_screen.dart';
import 'qris_management_screen.dart';
import 'feature_management_screen.dart';
import 'user_management_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankAccountNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _ssidController.text = settings.wifiSsid;
    _passwordController.text = settings.wifiPassword;
    _nameController.text = auth.cashierName;
    _bankNameController.text = auth.bankName;
    _bankAccountController.text = auth.bankAccountNumber;
    _bankAccountNameController.text = auth.bankAccountName;
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankAccountNameController.dispose();
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

  Future<void> _saveProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.updateProfile(
      _nameController.text,
      _bankNameController.text,
      _bankAccountController.text,
      _bankAccountNameController.text,
    );
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil disimpan'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan profil: ${auth.error}'), backgroundColor: AppColors.error),
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
            _buildSectionHeader('Profil Saya'),
            const SizedBox(height: 16),
            Consumer<AuthProvider>(builder: (context, auth, _) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nama Lengkap / Kasir',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Email: ${auth.user?.email ?? "-"}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontStyle: FontStyle.italic),
                    ),
                    const Divider(height: 24),
                    Text('Informasi Rekening Bank (Untuk Gaji)', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _bankNameController,
                      label: 'Nama Bank (Contoh: BCA, Mandiri, BRI)',
                      icon: Icons.account_balance_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _bankAccountController,
                      label: 'Nomor Rekening',
                      icon: Icons.numbers_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _bankAccountNameController,
                      label: 'Nama Pemilik Rekening (Nama Asli/BCA)',
                      icon: Icons.person_pin_rounded,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('SIMPAN PROFIL', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
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
            Consumer2<SubscriptionProvider, AuthProvider>(
              builder: (context, sub, auth, _) {
                final expiryDate = sub.effectiveExpiryDate;
                final remaining = sub.remainingDays;
                final isBlocked = sub.status == SubscriptionStatus.blocked;
                final isWarning = sub.status == SubscriptionStatus.warning;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isBlocked
                          ? AppColors.error.withOpacity(0.5)
                          : (isWarning ? AppColors.warning.withOpacity(0.5) : AppColors.primary.withOpacity(0.3)),
                    ),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isBlocked
                                    ? Icons.lock_clock_rounded
                                    : (isWarning ? Icons.warning_amber_rounded : Icons.verified_user_rounded),
                                color: isBlocked ? AppColors.error : (isWarning ? AppColors.warning : AppColors.success),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text('Status Langganan POS', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isBlocked
                                      ? AppColors.error
                                      : (isWarning ? AppColors.warning : AppColors.success))
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              isBlocked ? 'Terkunci' : (isWarning ? 'Mendekati Expired' : 'Aktif'),
                              style: TextStyle(
                                color: isBlocked ? AppColors.error : (isWarning ? AppColors.warning : AppColors.success),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sisa Masa Aktif', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                                const SizedBox(height: 2),
                                Text(
                                  isBlocked ? '0 Hari' : '$remaining Hari Lagi',
                                  style: AppTextStyles.heading3.copyWith(
                                    color: isBlocked ? AppColors.error : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Berlaku Sampai', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                                const SizedBox(height: 2),
                                Text(
                                  expiryDate != null ? AppFormatter.formatDate(expiryDate) : '-',
                                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
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
            
            // Admin & Owner Section
            Consumer<AuthProvider>(builder: (context, auth, _) {
              if (!auth.isAdmin && !auth.isOwner) return const SizedBox.shrink();
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  _buildSectionHeader(auth.isAdmin ? 'Administrator' : 'Owner'),
                  const SizedBox(height: 16),
                  if (auth.isAdmin) ...[
                    _buildSettingsTile(
                      icon: Icons.manage_accounts_rounded,
                      title: 'Kelola Akun Pengguna (Admin)',
                      subtitle: 'Tambah akun kasir/owner & kelola staf',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsTile(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Kelola QRIS (Admin)',
                      subtitle: 'Atur foto QRIS pelanggan & kasir',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QrisManagementScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    _buildSettingsTile(
                      icon: Icons.tune_rounded,
                      title: 'Kontrol Akses Fitur (Admin)',
                      subtitle: 'ON/OFF fitur untuk Owner & Kasir',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FeatureManagementScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildSettingsTile(
                    icon: Icons.payments_rounded,
                    title: 'Kelola Gaji Karyawan',
                    subtitle: auth.isAdmin ? 'Cek hari kerja & bayar gaji kasir' : 'Cek hari kerja & riwayat gaji kasir',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SalaryScreen()),
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
