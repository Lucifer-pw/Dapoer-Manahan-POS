import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/subscription_provider.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import 'billing_history_screen.dart';
import 'main_shell.dart';
import 'midtrans_payment_screen.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  // Ganti dengan nomor WhatsApp Anda (Gunakan kode negara, misal 628123456789)
  static const String adminWhatsApp = "6281328580511";

  Future<void> _launchWhatsApp(BuildContext context) async {
    const String message =
        "Halo Admin, saya sudah melakukan pembayaran aplikasi POS.";

    final Uri whatsappUrl = Uri.parse(
      "https://wa.me/6281328580511?text=${Uri.encodeComponent(message)}",
    );

    try {
      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Tidak dapat membuka WhatsApp: $e"),
          ),
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
                      const SizedBox(height: 16),

                      // Info pembayaran otomatis
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Bayar otomatis Rp 50.000 via Transfer Bank, GoPay, QRIS, dan lainnya.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // QR Payment Manual (Temporary)
                      Column(
                        children: [
                          Text(
                            'Metode Alternatif (QRIS)',
                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Image.asset(
                              'assets/images/payment_qr.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan QR di atas & Bayar Rp 50.000',
                            style: AppTextStyles.caption.copyWith(fontSize: 10),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () => _launchWhatsApp(context),
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text('KIRIM BUKTI BAYAR (WA)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Tombol Bayar via Midtrans
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _openMidtransPayment(context),
                          icon: const Icon(Icons.payment_rounded, size: 22),
                          label: Text(
                            'BAYAR VIA MIDTRANS (PROSES)',
                            style: AppTextStyles.button.copyWith(
                              letterSpacing: 1,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textHint, // Grayed out since it's pending
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Sub-icons metode pembayaran
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPaymentMethodIcon(
                              Icons.account_balance, 'Bank'),
                          const SizedBox(width: 16),
                          _buildPaymentMethodIcon(Icons.qr_code_2, 'QRIS'),
                          const SizedBox(width: 16),
                          _buildPaymentMethodIcon(
                              Icons.account_balance_wallet, 'E-Wallet'),
                          const SizedBox(width: 16),
                          _buildPaymentMethodIcon(Icons.store, 'Retail'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Cek Status Pembayaran
                Consumer<SubscriptionProvider>(builder: (context, sub, _) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
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
                                  strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.refresh),
                      label: Text(sub.isLoading
                          ? 'MENGECEK...'
                          : 'CEK STATUS PEMBAYARAN'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                            color: AppColors.primary.withOpacity(0.5)),
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
                      MaterialPageRoute(
                          builder: (_) => const BillingHistoryScreen()),
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

  Widget _buildPaymentMethodIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontSize: 9),
        ),
      ],
    );
  }

  void _openMidtransPayment(BuildContext context) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const MidtransPaymentScreen(),
      ),
    );

    if (result == 'success' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil! Menunggu konfirmasi admin...'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
