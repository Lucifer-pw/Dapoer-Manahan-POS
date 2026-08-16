import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/order_provider.dart';
import '../providers/starting_cash_provider.dart';
import '../services/firestore_service.dart';
import '../screens/login_screen.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class CloseShiftDialog extends StatelessWidget {
  const CloseShiftDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (_) => const CloseShiftDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProv = Provider.of<OrderProvider>(context);
    final expenseProv = Provider.of<ExpenseProvider>(context);
    final cashProv = Provider.of<StartingCashProvider>(context);

    final modalAwal = cashProv.startingCash;
    final orders = orderProv.todayOrders;

    // Filter transaksi tunai & QRIS
    final cashPayments = orders.where((o) => o.status == OrderStatus.completed && o.paymentMethod == 'Tunai')
        .fold(0, (sum, o) => sum + o.total);

    final qrisPayments = orders.where((o) => o.status == OrderStatus.completed && o.paymentMethod == 'QRIS')
        .fold(0, (sum, o) => sum + o.total);

    final expenseCash = expenseProv.todayExpenses
        .where((e) => e.paymentMethod == 'Cash')
        .fold(0, (sum, e) => sum + e.price);

    final totalKasLaci = modalAwal + cashPayments - expenseCash;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tutup Shift & Rekap Kas', style: AppTextStyles.heading3),
                      const SizedBox(height: 2),
                      Text(
                        '${auth.cashierName} • ${auth.currentShift.isNotEmpty ? auth.currentShift : "Kasir"}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textHint),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Rincian Keuangan Shift
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    label: 'Modal Kas Awal di Laci',
                    value: AppFormatter.formatRupiah(modalAwal),
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.secondary,
                  ),
                  Divider(height: 20, color: AppColors.border),
                  _buildSummaryRow(
                    label: 'Penjualan Tunai (Cash)',
                    value: '+ ${AppFormatter.formatRupiah(cashPayments)}',
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.success,
                  ),
                  const SizedBox(height: 10),
                  _buildSummaryRow(
                    label: 'Penjualan QRIS (Masuk Rek. Bank)',
                    value: '+ ${AppFormatter.formatRupiah(qrisPayments)}',
                    icon: Icons.qr_code_2_rounded,
                    iconColor: AppColors.info,
                  ),
                  const SizedBox(height: 10),
                  _buildSummaryRow(
                    label: 'Pengeluaran Belanja Kasir',
                    value: '- ${AppFormatter.formatRupiah(expenseCash)}',
                    icon: Icons.shopping_bag_outlined,
                    iconColor: AppColors.error,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Total Kas Fisik di Laci (Highlight)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.2), AppColors.secondary.withOpacity(0.15)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Fisik Uang Kas di Laci:',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatter.formatRupiah(totalKasLaci),
                          style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Catatan Serah Terima
            Text(
              '⚠️ Harap hitung fisik uang tunai di laci bersama kasir shift berikutnya sebelum melakukan serah terima dan logout.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11),
            ),
            const SizedBox(height: 24),

            // Tombol Aksi
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Batal / Lanjut Kerja'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context, rootNavigator: true);
                      navigator.pop();

                      // 1. Catat jam tutup shift & closing cash di Firestore
                      await FirestoreService().closeShiftLog(
                        shiftLogId: auth.currentShiftLogId,
                        cashierName: auth.cashierName,
                        closingCash: totalKasLaci,
                        date: DateTime.now(),
                      );

                      // 2. Clear shift state & logout
                      await auth.clearShift();
                      await auth.signOut();
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Tutup Shift & Logout', style: AppTextStyles.button),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
