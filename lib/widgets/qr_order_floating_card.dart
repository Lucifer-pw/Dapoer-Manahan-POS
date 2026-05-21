import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/qr_order_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class QrOrderFloatingCard extends StatefulWidget {
  const QrOrderFloatingCard({super.key});

  @override
  State<QrOrderFloatingCard> createState() => _QrOrderFloatingCardState();
}

class _QrOrderFloatingCardState extends State<QrOrderFloatingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QrOrderProvider>(
      builder: (context, qrProv, child) {
        if (qrProv.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _bounceAnimation.value),
              child: child,
            );
          },
          child: InkWell(
            onTap: () => _showReviewBottomSheet(context, qrProv),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.glow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pesanan QR Baru',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${qrProv.pendingCount} pesanan meja siap ditinjau',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: const Text(
                      'TINJAU',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReviewBottomSheet(BuildContext context, QrOrderProvider qrProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer3<QrOrderProvider, CartProvider, NavigationProvider>(
          builder: (context, qrProv, cartProv, navProv, _) {
            final orders = qrProv.pendingOrders;
            if (orders.isEmpty) {
              Navigator.pop(context);
              return const SizedBox.shrink();
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.qr_code_2_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tinjau QR Orders (${orders.length})',
                            style: AppTextStyles.heading3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final String orderId = order['id'] ?? '';
                          final int tableNum = _toInt(order['tableNumber']);
                          final int total = _toInt(order['totalPrice'] ?? order['total']);
                          final List<dynamic> items = order['items'] as List<dynamic>? ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: AppColors.border.withOpacity(0.3),
                              ),
                              boxShadow: AppShadows.card,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'MEJA $tableNum',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      AppFormatter.formatRupiah(total),
                                      style: AppTextStyles.price,
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: items.length,
                                  itemBuilder: (context, itemIdx) {
                                    final item = items[itemIdx];
                                    final String name = item['name'] ?? item['menuItemName'] ?? '';
                                    final String? variant = item['variant'];
                                    final String notes = item['notes'] ?? '';
                                    final int qty = _toInt(item['quantity'], fallback: 1);
                                    final int price = _toInt(item['price']);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${qty}x',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: AppTextStyles.body.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (variant != null && variant.isNotEmpty)
                                                  Text(
                                                    'Opsi: $variant',
                                                    style: AppTextStyles.caption.copyWith(
                                                      color: AppColors.secondary,
                                                    ),
                                                  ),
                                                if (notes.isNotEmpty)
                                                  Text(
                                                    'Catatan: "$notes"',
                                                    style: AppTextStyles.caption.copyWith(
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            AppFormatter.formatRupiah(price * qty),
                                            style: AppTextStyles.caption.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final bool confirm = await _showConfirmReject(context);
                                          if (confirm) {
                                            await qrProv.rejectQrOrder(orderId);
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppColors.error,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Tolak',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await qrProv.acceptQrOrder(
                                            orderId,
                                            context,
                                            cartProv,
                                            navProv,
                                          );
                                          if (context.mounted) {
                                            Navigator.pop(context); // Close sheet
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Pesanan QR Meja $tableNum berhasil dimuat ke Keranjang!',
                                                ),
                                                backgroundColor: AppColors.success,
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Terima & Proses',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _showConfirmReject(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Tolak Pesanan QR'),
            content: const Text(
              'Yakin ingin menolak dan membatalkan pesanan mandiri ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Batal',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Tolak',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Safely converts a Firestore dynamic value (String, int, double, null)
  /// to int. Prevents 'type String is not a subtype of type int' errors.
  int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
