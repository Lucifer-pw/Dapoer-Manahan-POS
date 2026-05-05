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

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 80,
                    color: AppColors.textHint.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat pembayaran',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.xl),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final record = history[index];
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
            },
          );
        },
      ),
    );
  }
}
