import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/subscription_provider.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import 'billing_history_screen.dart';
import 'main_shell.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  // Ganti dengan nomor WhatsApp Anda (Gunakan kode negara, misal 628123456789)
  static const String adminWhatsApp = "6281328580511";

  Future<void> _launchWhatsApp(BuildContext context) async {
    final url = Uri.parse(
        "https://wa.me/$adminWhatsApp?text=Halo%20Admin,%20saya%20sudah%20melakukan%20pembayaran%20untuk%20aplikasi%20POS.");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_clock_rounded,
                  color: AppColors.error,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'Aplikasi Terkunci',
                  style: AppTextStyles.heading1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Masa berlaku aplikasi telah habis. Silakan lakukan pembayaran untuk melanjutkan penggunaan.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border:
                        Border.all(color: AppColors.border.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatter.formatRupiah(50000),
                        style: AppTextStyles.heading2
                            .copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 24),

                      // QR Code Placeholder / Image
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Image.asset(
                            'assets/images/payment_qr.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.qr_code_2,
                                    size: 100, color: Colors.black54),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'Scan QR di atas untuk membayar',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Consumer<SubscriptionProvider>(builder: (context, sub, _) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: sub.isLoading
                          ? null
                          : () async {
                              await sub.checkStatus();

                              if (!context.mounted) return;

                              if (sub.status == SubscriptionStatus.active) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Pembayaran terverifikasi! Membuka aplikasi...')),
                                );
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => const MainShell()),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Status belum berubah. Pastikan Admin sudah mengonfirmasi pembayaran Anda.')),
                                );
                              }
                            },
                      icon: sub.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh),
                      label: Text(sub.isLoading
                          ? 'MENGECEK...'
                          : 'CEK STATUS PEMBAYARAN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _launchWhatsApp(context),
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(
                    'Hubungi Admin via WhatsApp',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BillingHistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: Text(
                    'Lihat Riwayat Pembayaran',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
