import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/table_provider.dart';
import '../providers/draft_provider.dart';
import '../models/order.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import '../widgets/custom_numpad.dart';
import 'receipt_screen.dart';
import '../services/firestore_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _amountStr = '';
  String _paymentMethod = 'Tunai'; // 'Tunai' atau 'QRIS'
  bool _isProcessing = false; // Guard: prevent double-click

  int get _amountPaid {
    if (_paymentMethod == 'QRIS') {
      final cart = Provider.of<CartProvider>(context, listen: false);
      return cart.total;
    }
    return int.tryParse(_amountStr) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final change = _amountPaid - cart.total;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: _isProcessing ? null : () => Navigator.pop(context)),
        title: Text('Pembayaran', style: AppTextStyles.heading3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // Order summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: AppColors.cardGradient, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border.withOpacity(0.2))),
              child: Column(children: [
                Text(
                  cart.isTakeAway ? 'DIBAWA PULANG' : 'Meja ${cart.tableNumber}',
                  style: AppTextStyles.subtitle.copyWith(
                    color: cart.isTakeAway ? AppColors.primary : AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...cart.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text('${item.menuItemName} x${item.quantity}', style: AppTextStyles.body.copyWith(fontSize: 13))),
                    Text(AppFormatter.formatRupiah(item.subtotal), style: AppTextStyles.body.copyWith(fontSize: 13)),
                  ]),
                )),
                Divider(color: AppColors.border, height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('TOTAL', style: AppTextStyles.heading3),
                  Text(AppFormatter.formatRupiah(cart.total), style: AppTextStyles.price.copyWith(fontSize: 22)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // Payment Method Selection
            Text('Metode Pembayaran', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isProcessing ? null : () => setState(() => _paymentMethod = 'Tunai'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'Tunai' ? AppColors.primary.withOpacity(0.15) : AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _paymentMethod == 'Tunai' ? AppColors.primary : AppColors.border.withOpacity(0.3),
                          width: _paymentMethod == 'Tunai' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.money, size: 20, color: _paymentMethod == 'Tunai' ? AppColors.primary : AppColors.textHint),
                          const SizedBox(width: 8),
                          Text('Tunai', style: AppTextStyles.body.copyWith(
                            color: _paymentMethod == 'Tunai' ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: _paymentMethod == 'Tunai' ? FontWeight.bold : FontWeight.normal,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _isProcessing ? null : () => setState(() {
                      _paymentMethod = 'QRIS';
                      _amountStr = cart.total.toString();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'QRIS' ? AppColors.primary.withOpacity(0.15) : AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _paymentMethod == 'QRIS' ? AppColors.primary : AppColors.border.withOpacity(0.3),
                          width: _paymentMethod == 'QRIS' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, size: 20, color: _paymentMethod == 'QRIS' ? AppColors.primary : AppColors.textHint),
                          const SizedBox(width: 8),
                          Text('QRIS', style: AppTextStyles.body.copyWith(
                            color: _paymentMethod == 'QRIS' ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: _paymentMethod == 'QRIS' ? FontWeight.bold : FontWeight.normal,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border.withOpacity(0.3))),
              child: Column(children: [
                Text('Jumlah Bayar', style: AppTextStyles.caption),
                const SizedBox(height: 8),
                Text(
                  _amountStr.isEmpty ? 'Rp 0' : AppFormatter.formatRupiah(_amountPaid),
                  style: AppTextStyles.heading1.copyWith(fontSize: 32, color: _amountPaid >= cart.total ? AppColors.success : AppColors.textPrimary),
                ),
                if (_amountPaid >= cart.total && cart.total > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text('Kembalian: ${AppFormatter.formatRupiah(change)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // Numpad (Only show for Cash)
            if (_paymentMethod == 'Tunai') ...[
              // Quick amount buttons
              Row(children: [
                _buildQuickBtn('50rb', 50000, cart),
                const SizedBox(width: 8),
                _buildQuickBtn('100rb', 100000, cart),
                const SizedBox(width: 8),
                _buildQuickBtn('Uang Pas', cart.total, cart),
              ]),
              const SizedBox(height: 16),

              CustomNumpad(
                onNumberTap: _isProcessing ? (_) {} : (val) => setState(() => _amountStr += val),
                onDelete: _isProcessing ? () {} : () => setState(() { if (_amountStr.isNotEmpty) _amountStr = _amountStr.substring(0, _amountStr.length - 1); }),
                onClear: _isProcessing ? () {} : () => setState(() => _amountStr = ''),
              ),
              const SizedBox(height: 20),
            ] else ...[
              // QRIS Image Placeholder
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border.withOpacity(0.3)),
                ),
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: FirestoreService().streamActiveQrisConfig(),
                  builder: (context, snapshot) {
                    final config = snapshot.data ?? {};
                    final cashierQris = config['cashier'];
                    final imageUrl = cashierQris?['imageUrl'] as String?;
                    final label = cashierQris?['label'] as String?;

                    Widget buildFallback() {
                      return Image.asset(
                        'assets/images/payment_qr_cs.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.qr_code_2, size: 100, color: AppColors.textPrimary);
                        },
                      );
                    }

                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  key: ValueKey(imageUrl),
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => buildFallback(),
                                )
                              : buildFallback(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          label != null && label.isNotEmpty
                              ? 'Minta pelanggan memindai QRIS ($label)'
                              : 'Minta pelanggan memindai QRIS',
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: 8),
                        Text('Total: ${AppFormatter.formatRupiah(cart.total)}', style: AppTextStyles.heading3),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Confirm button — disabled during processing
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: (!_isProcessing && _amountPaid >= cart.total && cart.total > 0) ? () => _processPayment(context) : null,
                icon: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle, size: 22),
                label: Text(
                  _isProcessing ? 'MEMPROSES...' : 'KONFIRMASI PEMBAYARAN',
                  style: AppTextStyles.button.copyWith(letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor: _isProcessing ? AppColors.success.withOpacity(0.7) : AppColors.textHint.withOpacity(0.3),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildQuickBtn(String label, int amount, CartProvider cart) {
    return Expanded(
      child: OutlinedButton(
        onPressed: _isProcessing ? null : () => setState(() => _amountStr = '$amount'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    // === IDEMPOTENT GUARD: prevent double-click ===
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final cart = Provider.of<CartProvider>(context, listen: false);
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tableProv = Provider.of<TableProvider>(context, listen: false);
    final draftProv = Provider.of<DraftProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Hitung nomor urut yang benar (Database vs Draf)
      int finalSequenceNumber = cart.activeDraftNumber ?? 0;

      if (finalSequenceNumber == 0) {
        // Jika ini transaksi langsung (bukan draf), cari nomor baru
        final nextFromDb = await orderProv.getNextSequenceNumber();
        int maxDraftNum = 0;
        if (draftProv.drafts.isNotEmpty) {
          maxDraftNum = draftProv.drafts
              .map((d) => d.draftNumber ?? 0)
              .reduce((a, b) => a > b ? a : b);
        }
        // Ambil yang paling besar agar tidak bentrok
        finalSequenceNumber = (nextFromDb > maxDraftNum) ? nextFromDb : (maxDraftNum + 1);
      }

      final order = Order(
        id: '',
        tableNumber: cart.tableNumber,
        cashierName: auth.cashierName,
        cashierId: auth.user?.uid ?? '',
        items: cart.items,
        subtotal: cart.subtotal,
        tax: cart.tax,
        total: cart.total,
        paymentMethod: _paymentMethod,
        amountPaid: _amountPaid,
        change: _paymentMethod == 'QRIS' ? 0 : (_amountPaid - cart.total),
        status: OrderStatus.completed,
        isTakeAway: cart.isTakeAway,
      );

      final completedOrder = await orderProv.createOrder(
        order, 
        sequenceNumber: finalSequenceNumber,
      );
      
      // Update table status if not takeaway
      if (!cart.isTakeAway) {
        final table = tableProv.getTableByNumber(cart.tableNumber);
        if (table != null) {
          await tableProv.setAvailable(table.id);
        }
        // Auto-finalize any lingering active QR orders for this table
        await FirestoreService().finalizeQrOrdersForTable(cart.tableNumber);
      }

      // Delete draft if this was a resumed order
      if (cart.activeDraftId != null) {
        await draftProv.deleteDraft(cart.activeDraftId!);
      }

      cart.clear();

      if (mounted) {
        navigator.pushReplacement(MaterialPageRoute(builder: (_) => ReceiptScreen(order: completedOrder)));
      }
    } catch (e) {
      // Reset processing state on error so user can retry
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal memproses pembayaran: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}


