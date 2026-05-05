import 'package:flutter/material.dart';
import '../models/order.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import 'receipt_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Detail Transaksi', style: AppTextStyles.heading3),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppColors.primary),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(order: order)));
            },
            tooltip: 'Cetak Struk',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Order Header Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(order.orderNumber, style: AppTextStyles.heading1.copyWith(fontSize: 24)),
                  const SizedBox(height: 16),
                  _buildInfoRow('Tanggal', AppFormatter.formatDateTime(order.createdAt)),
                  _buildInfoRow('Meja', 'Meja ${order.tableNumber}'),
                  _buildInfoRow('Kasir', order.cashierName),
                  _buildInfoRow('Status', order.status.name.toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Items List
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daftar Pesanan', style: AppTextStyles.heading3),
                  const SizedBox(height: 16),
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text('${item.quantity}x', style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.menuItemName, style: AppTextStyles.body),
                              if (item.variant != null)
                                Text(item.variant!, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              if (item.notes.isNotEmpty)
                                Text('Catatan: ${item.notes}', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        Text(AppFormatter.formatRupiah(item.subtotal), style: AppTextStyles.body),
                      ],
                    ),
                  )),
                  const Divider(color: AppColors.border, height: 32),
                  _buildTotalRow('Subtotal', AppFormatter.formatRupiah(order.subtotal)),
                  if (order.tax > 0) _buildTotalRow('Pajak', AppFormatter.formatRupiah(order.tax)),
                  const SizedBox(height: 8),
                  _buildTotalRow('Total', AppFormatter.formatRupiah(order.total), isGrandTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pembayaran', style: AppTextStyles.heading3),
                  const SizedBox(height: 16),
                  _buildInfoRow('Metode', order.paymentMethod),
                  _buildInfoRow('Tunai', AppFormatter.formatRupiah(order.amountPaid)),
                  _buildInfoRow('Kembalian', AppFormatter.formatRupiah(order.change)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySecondary),
          Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isGrandTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isGrandTotal ? AppTextStyles.heading3 : AppTextStyles.bodySecondary),
        Text(value, style: isGrandTotal ? AppTextStyles.price.copyWith(fontSize: 20) : AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
