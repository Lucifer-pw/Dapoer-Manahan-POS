import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class BillingHistoryScreen extends StatelessWidget {
  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Pembayaran'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subProvider, child) {
          final history = subProvider.history;
          final expiryDate = subProvider.effectiveExpiryDate;
          final remaining = subProvider.remainingDays;
          final isBlocked = subProvider.status == SubscriptionStatus.blocked;
          final isWarning = subProvider.status == SubscriptionStatus.warning;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              // Info Card Masa Aktif Billing
              Container(
                margin: const EdgeInsets.only(bottom: 24),
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
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text('Masa Aktif Aplikasi', style: AppTextStyles.heading3),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isBlocked
                                    ? AppColors.error
                                    : (isWarning ? AppColors.warning : AppColors.success))
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            isBlocked ? 'Terkunci' : (isWarning ? 'Mendekati Expired' : 'Aktif Normal'),
                            style: TextStyle(
                              color: isBlocked ? AppColors.error : (isWarning ? AppColors.warning : AppColors.success),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                                style: AppTextStyles.heading2.copyWith(
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
                                style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Text('Riwayat Transaksi Langganan', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              if (history.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 64,
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada riwayat pembayaran',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...history.map((record) {
                  final isPaid = record.status.toLowerCase() == 'paid' || 
                                 record.status.toLowerCase() == 'berhasil' ||
                                 record.status.toLowerCase() == 'lunas';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.3),
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isPaid ? AppColors.success : AppColors.warning)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                            color: isPaid ? AppColors.success : AppColors.warning,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pembayaran Bulan ${AppFormatter.getMonthName(record.month)} ${record.year}',
                                style: AppTextStyles.subtitle.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppFormatter.formatDate(record.date),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatter.formatRupiah(record.amount),
                              style: AppTextStyles.priceSmall.copyWith(
                                color: isPaid ? AppColors.success : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (isPaid ? AppColors.success : AppColors.warning)
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                record.status.toUpperCase(),
                                style: TextStyle(
                                  color: isPaid ? AppColors.success : AppColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
