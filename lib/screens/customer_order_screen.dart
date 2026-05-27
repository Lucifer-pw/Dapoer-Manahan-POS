import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import '../models/category.dart';
import '../models/order.dart' as app;
import '../services/firestore_service.dart';
import '../widgets/chat_room_dialog.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import '../utils/file_saver.dart';

class CustomerOrderScreen extends StatefulWidget {
  final String tableNumber;
  const CustomerOrderScreen({super.key, required this.tableNumber});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  @override
  void initState() {
    super.initState();
    _saveTableNumber();
  }

  Future<void> _saveTableNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_table_number', widget.tableNumber);
      debugPrint('Saved active table number: ${widget.tableNumber}');
    } catch (e) {
      debugPrint('Error saving table number: $e');
    }
  }

  // Local cart state
  // Structure: { menuItemId: { 'item': MenuItem, 'quantity': int, 'notes': String } }
  final Map<String, Map<String, dynamic>> _cart = {};

  String? _localSelectedCategoryId;
  String _localSearchQuery = '';
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String _selectedPaymentMethod = 'QRIS';
  int _submittedTotalPrice = 0;

  final FirestoreService _firestoreService = FirestoreService();

  int get totalItems => _cart.values.fold(0, (acc, elem) => acc + (elem['quantity'] as int));
  int get totalPrice => _cart.values.fold(0, (acc, elem) {
        final item = elem['item'] as MenuItem;
        final qty = elem['quantity'] as int;
        return acc + (item.price * qty);
      });

  int _getItemTotalQuantity(String itemId) {
    int total = 0;
    _cart.forEach((key, val) {
      if (key.startsWith(itemId)) {
        total += val['quantity'] as int;
      }
    });
    return total;
  }

  void _addToCart(MenuItem item, {String? variant}) {
    setState(() {
      final key = variant != null ? '${item.id}_$variant' : item.id;
      if (_cart.containsKey(key)) {
        _cart[key]!['quantity'] = (_cart[key]!['quantity'] as int) + 1;
      } else {
        _cart[key] = {
          'item': item,
          'quantity': 1,
          'notes': '',
          'variant': variant,
        };
      }
    });
  }

  void _removeFromCart(MenuItem item, {String? variant}) {
    setState(() {
      final key = variant != null ? '${item.id}_$variant' : item.id;
      if (_cart.containsKey(key)) {
        final currentQty = _cart[key]!['quantity'] as int;
        if (currentQty > 1) {
          _cart[key]!['quantity'] = currentQty - 1;
        } else {
          _cart.remove(key);
        }
      }
    });
  }

  void _removeFromCartFromGrid(MenuItem item) {
    setState(() {
      String? targetKey;
      for (final key in _cart.keys) {
        if (key.startsWith(item.id)) {
          targetKey = key;
          break;
        }
      }
      if (targetKey != null) {
        final currentQty = _cart[targetKey]!['quantity'] as int;
        if (currentQty > 1) {
          _cart[targetKey]!['quantity'] = currentQty - 1;
        } else {
          _cart.remove(targetKey);
        }
      }
    });
  }

  void _updateNotes(String key, String newNotes) {
    setState(() {
      if (_cart.containsKey(key)) {
        _cart[key]!['notes'] = newNotes;
      }
    });
  }

  void _showDrinkOptionsBottomSheet(MenuItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        final options = ['Air Mineral', 'Esteh', 'Teh Anget'];
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Minuman Paket',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 4),
              Text(
                'Silakan pilih minuman pendamping untuk ${item.name}:',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                return Card(
                  color: AppColors.surfaceDark,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.local_drink_rounded, color: AppColors.primary),
                    title: Text(
                      opt,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    onTap: () {
                      _addToCart(item, variant: opt);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showNotesDialog(String key, MenuItem item) {
    final currentNotes = _cart[key]?['notes'] as String? ?? '';
    final controller = TextEditingController(text: currentNotes);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
          title: Text(
            'Catatan untuk ${item.name}',
            style: AppTextStyles.heading3,
          ),
          content: TextField(
            controller: controller,
            maxLength: 80,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Contoh: Pedas sekali, tidak pakai bawang...',
              hintStyle: TextStyle(color: AppColors.textHint),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _updateNotes(key, controller.text.trim());
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: const Text(
                'Simpan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final List<Map<String, dynamic>> orderItems = _cart.values.map((elem) {
        final item = elem['item'] as MenuItem;
        final qty = elem['quantity'] as int;
        final notes = elem['notes'] as String;
        final variant = elem['variant'] as String?;
        return {
          'id': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': qty,
          'notes': notes,
          'variant': variant,
        };
      }).toList();

      final Map<String, dynamic> qrOrderData = {
        'tableNumber': widget.tableNumber,
        'items': orderItems,
        'totalPrice': totalPrice,
        'status': 'pending',
        'paymentMethod': _selectedPaymentMethod,
        'paymentStatus': 'belum_bayar',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final finalPrice = totalPrice;
      await _firestoreService.createQrOrder(qrOrderData);

      setState(() {
        _submittedTotalPrice = finalPrice;
        _isSubmitting = false;
        _isSuccess = true;
        _cart.clear();
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim pesanan: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showCartReviewBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tinjau Pesanan', style: AppTextStyles.heading2),
                          Text(
                            'Meja ${widget.tableNumber}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: _cart.isEmpty
                          ? Center(
                              child: Text(
                                'Keranjang masih kosong',
                                style: AppTextStyles.bodySecondary,
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final key = _cart.keys.elementAt(index);
                                final entry = _cart[key]!;
                                final item = entry['item'] as MenuItem;
                                final qty = entry['quantity'] as int;
                                final notes = entry['notes'] as String;
                                final variant = entry['variant'] as String?;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Card(
                                    color: AppColors.card,
                                    margin: EdgeInsets.zero,
                                    elevation: 0,
                                    child: Padding(
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.name,
                                                  style: AppTextStyles.heading3,
                                                ),
                                              ),
                                              Text(
                                                AppFormatter.formatRupiah(item.price * qty),
                                                style: AppTextStyles.priceSmall,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppFormatter.formatRupiah(item.price),
                                            style: AppTextStyles.caption,
                                          ),
                                          if (variant != null && variant.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Minuman: $variant',
                                              style: AppTextStyles.caption.copyWith(
                                                color: AppColors.secondary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  _showNotesDialog(key, item);
                                                  setModalState(() {});
                                                },
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      notes.isNotEmpty
                                                          ? Icons.edit_note_rounded
                                                          : Icons.note_add_outlined,
                                                      size: 18,
                                                      color: notes.isNotEmpty
                                                          ? AppColors.primary
                                                          : AppColors.textSecondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      notes.isNotEmpty
                                                          ? notes
                                                          : 'Tambah catatan...',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: notes.isNotEmpty
                                                            ? AppColors.primary
                                                            : AppColors.textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle_outline_rounded,
                                                        color: AppColors.error),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () {
                                                      setModalState(() {
                                                        _removeFromCart(item, variant: variant);
                                                      });
                                                      setState(() {});
                                                    },
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                                    child: Text(
                                                      qty.toString(),
                                                      style: AppTextStyles.heading3,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.add_circle_outline_rounded,
                                                        color: AppColors.success),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () {
                                                      setModalState(() {
                                                        _addToCart(item, variant: variant);
                                                      });
                                                      setState(() {});
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Metode Pembayaran',
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _selectedPaymentMethod = 'QRIS';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedPaymentMethod == 'QRIS'
                                          ? AppColors.primary.withOpacity(0.12)
                                          : AppColors.surfaceDark,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: _selectedPaymentMethod == 'QRIS'
                                            ? AppColors.primary
                                            : AppColors.border.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.qr_code_2_rounded,
                                          color: _selectedPaymentMethod == 'QRIS'
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          size: 22,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'QRIS (Bayar Sekarang)',
                                          style: AppTextStyles.caption.copyWith(
                                            fontWeight: _selectedPaymentMethod == 'QRIS'
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _selectedPaymentMethod == 'QRIS'
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _selectedPaymentMethod = 'Tunai';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedPaymentMethod == 'Tunai'
                                          ? AppColors.primary.withOpacity(0.12)
                                          : AppColors.surfaceDark,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: _selectedPaymentMethod == 'Tunai'
                                            ? AppColors.primary
                                            : AppColors.border.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.payments_rounded,
                                          color: _selectedPaymentMethod == 'Tunai'
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          size: 22,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tunai (Bayar di Kasir)',
                                          style: AppTextStyles.caption.copyWith(
                                            fontWeight: _selectedPaymentMethod == 'Tunai'
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _selectedPaymentMethod == 'Tunai'
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedPaymentMethod == 'QRIS'
                                ? '* Pindai kode QRIS setelah mengirim pesanan untuk langsung membayar'
                                : '* Silakan bayar ke meja kasir setelah hidangan disajikan/selesai makan',
                            style: AppTextStyles.caption.copyWith(
                              fontStyle: FontStyle.italic,
                              color: AppColors.secondary,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Pembayaran', style: AppTextStyles.subtitle),
                              Text(
                                AppFormatter.formatRupiah(totalPrice),
                                style: AppTextStyles.price,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _cart.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(ctx);
                                      _submitOrder();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                elevation: 4,
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      'Kirim Pesanan Sekarang',
                                      style: AppTextStyles.button,
                                    ),
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isSuccess) {
          setState(() {
            _isSuccess = false;
          });
        }
      },
      child: _isSuccess ? _buildSuccessScreen() : _buildMenuScreen(context),
    );
  }

  Widget _buildMenuScreen(BuildContext context) {
    final menuProv = Provider.of<MenuProvider>(context);

    // Dynamic filtering for independent customer screen
    final availableItems = menuProv.allMenuItems.where((item) => item.isAvailable).toList();
    var filteredItems = availableItems;
    if (_localSelectedCategoryId != null) {
      filteredItems = filteredItems.where((item) => item.categoryId == _localSelectedCategoryId).toList();
    }
    if (_localSearchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) => item.name.toLowerCase().contains(_localSearchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Welcome Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DefaultData.restaurantName,
                          style: AppTextStyles.heading1.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Pesan menu lezat langsung dari mejamu',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: AppShadows.glow,
                    ),
                    child: Text(
                      'Meja ${widget.tableNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Beautiful Interactive Guide Banner
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: 12),
              child: GestureDetector(
                onTap: _showCustomerGuideBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panduan Memesan & Membayar',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ketuk di sini untuk melihat langkah mudah memesan hidangan Anda',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 12),
                    ],
                  ),
                ),
              ),
            ),

            // Warning Banner for unpaid QRIS orders
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.streamQrOrdersByTable(widget.tableNumber),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const SizedBox.shrink();
                }

                final unpaidQrisOrders = snapshot.data!.where((o) {
                  final method = o['paymentMethod'] as String? ?? '';
                  final payStatus = o['paymentStatus'] as String? ?? '';
                  final orderStatus = o['status'] as String? ?? '';

                  return method == 'QRIS' &&
                         payStatus == 'belum_bayar' &&
                         orderStatus != 'rejected';
                }).toList();

                if (unpaidQrisOrders.isEmpty) {
                  return const SizedBox.shrink();
                }

                final activeOrder = unpaidQrisOrders.first;
                final orderPrice = activeOrder['totalPrice'] as int? ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.error.withOpacity(0.25), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pembayaran QRIS Belum Selesai',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tagihan sebesar ${AppFormatter.formatRupiah(orderPrice)} belum terbayar.',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _showQrisInvoiceDialog(context, activeOrder);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: const Text(
                            'Bayar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _localSearchQuery = val;
                  });
                },
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari makanan atau minuman...',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Categories list
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: menuProv.categories.length + 1,
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final Category? cat = isAll ? null : menuProv.categories[index - 1];
                  final isSelected = isAll
                      ? _localSelectedCategoryId == null
                      : _localSelectedCategoryId == cat?.id;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        isAll ? 'Semua' : '${cat?.icon ?? "🍛"} ${cat?.name}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _localSelectedCategoryId = isAll ? null : cat?.id;
                        });
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceDark,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border.withOpacity(0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      showCheckmark: false,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Menu Items Grid
            Expanded(
              child: menuProv.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fastfood_outlined, size: 64, color: AppColors.textHint),
                              const SizedBox(height: 12),
                              Text('Menu tidak ditemukan', style: AppTextStyles.bodySecondary),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                            childAspectRatio: MediaQuery.of(context).size.width > 600
                                ? 0.8
                                : (MediaQuery.of(context).size.width < 360 ? 0.64 : 0.7),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final qty = _getItemTotalQuantity(item.id);
                            final categoryName = menuProv.getCategoryName(item.categoryId);
                            final isPaket = categoryName.toLowerCase().contains('paket') || item.name.toLowerCase().contains('paket');

                            return Card(
                              color: AppColors.card,
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                side: BorderSide(color: AppColors.border.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showProductDetailBottomSheet(context, item.id),
                                      child: Container(
                                        color: AppColors.surfaceDark,
                                        width: double.infinity,
                                        child: item.imageUrl.isNotEmpty
                                            ? Image.network(
                                                item.imageUrl,
                                                key: ValueKey(item.imageUrl),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.fastfood_rounded,
                                                  color: AppColors.primary,
                                                  size: 40,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.fastfood_rounded,
                                                color: AppColors.primary,
                                                size: 40,
                                              ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _showProductDetailBottomSheet(context, item.id),
                                          behavior: HitTestBehavior.opaque,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.description,
                                                  style: AppTextStyles.caption,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                AppFormatter.formatRupiah(item.price),
                                                style: AppTextStyles.priceSmall,
                                              ),
                                            ),
                                            if (qty > 0)
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () {
                                                      if (isPaket) {
                                                        _removeFromCartFromGrid(item);
                                                      } else {
                                                        _removeFromCart(item);
                                                      }
                                                    },
                                                    child: const Icon(
                                                      Icons.remove_circle_rounded,
                                                      color: AppColors.primary,
                                                      size: 22,
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                    child: Text(
                                                      qty.toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () {
                                                      if (isPaket) {
                                                        _showDrinkOptionsBottomSheet(item);
                                                      } else {
                                                        _addToCart(item);
                                                      }
                                                    },
                                                    child: const Icon(
                                                      Icons.add_circle_rounded,
                                                      color: AppColors.primary,
                                                      size: 22,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              GestureDetector(
                                                onTap: () {
                                                  if (isPaket) {
                                                    _showDrinkOptionsBottomSheet(item);
                                                  } else {
                                                    _addToCart(item);
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                                    border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(Icons.add, color: AppColors.primary, size: 14),
                                                      Text(
                                                        'Tambah',
                                                        style: TextStyle(
                                                          color: AppColors.primary,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: totalItems > 0 ? _buildFloatingCartBar() : null,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildHistoryFAB(),
          const SizedBox(height: 12),
          _buildChatFAB(),
        ],
      ),
    );
  }

  Widget _buildChatFAB() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.streamCustomerUnreadMessages(widget.tableNumber),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.length ?? 0;

        return FloatingActionButton(
          heroTag: 'chat_fab',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => ChatRoomDialog(
                tableNumber: widget.tableNumber,
                role: 'customer',
              ),
            );
          },
          backgroundColor: AppColors.primary,
          child: Badge(
            label: Text(unreadCount.toString()),
            isLabelVisible: unreadCount > 0,
            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildHistoryFAB() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.streamQrOrdersByTable(widget.tableNumber),
      builder: (context, snapshot) {
        final activeQrOrders = snapshot.data?.where((o) {
          final status = o['status'] as String? ?? '';
          return status == 'pending' || status == 'accepted';
        }).toList() ?? [];
        final count = activeQrOrders.length;

        return FloatingActionButton(
          heroTag: 'history_fab',
          onPressed: () => _showOrderHistoryBottomSheet(context),
          backgroundColor: AppColors.secondary,
          child: Badge(
            label: Text(count.toString()),
            isLabelVisible: count > 0,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  void _showOrderHistoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.streamQrOrdersByTable(widget.tableNumber),
              builder: (context, qrSnapshot) {
                return StreamBuilder<List<app.Order>>(
                  stream: _firestoreService.streamTodayOrdersByTable(int.tryParse(widget.tableNumber) ?? 0),
                  builder: (context, orderSnapshot) {
                    if (qrSnapshot.connectionState == ConnectionState.waiting &&
                        orderSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    final qrOrders = qrSnapshot.data ?? [];
                    final completedOrders = orderSnapshot.data ?? [];

                    final hasData = qrOrders.isNotEmpty || completedOrders.isNotEmpty;

                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Riwayat Pesanan', style: AppTextStyles.heading2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'Meja ${widget.tableNumber}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: !hasData
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textHint),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Belum ada pesanan hari ini',
                                        style: AppTextStyles.bodySecondary,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                                  children: [
                                    if (qrOrders.isNotEmpty) ...[
                                      Text(
                                        'Pesanan Aktif',
                                        style: AppTextStyles.heading3.copyWith(color: AppColors.secondary),
                                      ),
                                      const SizedBox(height: 8),
                                      ...qrOrders.map((qr) => _buildQrOrderCard(qr)),
                                      const SizedBox(height: 16),
                                    ],
                                    if (completedOrders.isNotEmpty) ...[
                                      Text(
                                        'Riwayat Transaksi',
                                        style: AppTextStyles.heading3.copyWith(color: AppColors.success),
                                      ),
                                      const SizedBox(height: 8),
                                      ...completedOrders.map((order) => _buildCompletedOrderCard(order)),
                                    ],
                                  ],
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
      },
    );
  }

  Widget _buildQrOrderCard(Map<String, dynamic> qr) {
    final status = qr['status'] as String? ?? 'pending';
    final items = qr['items'] as List<dynamic>? ?? [];
    final totalPrice = qr['totalPrice'] as int? ?? 0;
    final paymentMethod = qr['paymentMethod'] as String? ?? 'Tunai';
    final paymentStatus = qr['paymentStatus'] as String? ?? 'belum_bayar';
    
    final timestamp = qr['createdAt'];
    DateTime date = DateTime.now();
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    }

    Color payColor;
    String payText;
    if (paymentStatus == 'sudah_bayar') {
      payColor = AppColors.success;
      payText = 'Lunas';
    } else {
      if (paymentMethod == 'QRIS') {
        payColor = AppColors.info;
        payText = 'Menunggu Verifikasi QRIS';
      } else {
        payColor = AppColors.primary;
        payText = 'Belum Dibayar (Kasir)';
      }
    }

    Color statusColor;
    String statusText;
    switch (status) {
      case 'accepted':
        statusColor = AppColors.info;
        statusText = 'Sedang Diproses';
        break;
      case 'delivered':
        statusColor = AppColors.success;
        statusText = 'Pesanan Sudah Dianter';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = 'Ditolak';
        break;
      case 'pending':
      default:
        statusColor = AppColors.warning;
        statusText = 'Menunggu Konfirmasi';
        break;
    }

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppFormatter.formatDateTime(date),
                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Metode: $paymentMethod',
                        style: AppTextStyles.caption.copyWith(fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: payColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: payColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        payText,
                        style: TextStyle(
                          color: payColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            ...items.map((it) {
              final name = it['name'] as String? ?? '';
              final qty = it['quantity'] as int? ?? 0;
              final price = it['price'] as int? ?? 0;
              final notes = it['notes'] as String? ?? '';
              final variant = it['variant'] as String?;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$qty x $name',
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          AppFormatter.formatRupiah(price * qty),
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (variant != null && variant.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Minuman: $variant',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Catatan: "$notes"',
                        style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              );
            }),
            
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Harga',
                  style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  AppFormatter.formatRupiah(totalPrice),
                  style: AppTextStyles.priceSmall.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            if (paymentMethod == 'QRIS' && paymentStatus == 'belum_bayar' && status != 'rejected') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Close the bottom sheet first, then open dialog
                    Navigator.pop(context);
                    _showQrisInvoiceDialog(context, qr);
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Lanjutkan Pembayaran QRIS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedOrderCard(app.Order order) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatter.formatDateTime(order.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Selesai & Lunas',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            ...order.items.map((it) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${it.quantity} x ${it.menuItemName}',
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          AppFormatter.formatRupiah(it.subtotal),
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (it.variant != null && it.variant!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Minuman: ${it.variant}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (it.notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Catatan: "${it.notes}"',
                        style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Pembayaran',
                  style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  AppFormatter.formatRupiah(order.total),
                  style: AppTextStyles.priceSmall.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Metode Pembayaran',
                  style: AppTextStyles.caption,
                ),
                Text(
                  order.paymentMethod,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCartBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalItems Item Terpilih',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatter.formatRupiah(totalPrice),
                  style: AppTextStyles.price,
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _showCartReviewBottomSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                elevation: 4,
              ),
              child: Row(
                children: [
                  Text('Tinjau Pesanan', style: AppTextStyles.button),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success.withOpacity(0.4), width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pesanan Dikirim!',
                    style: AppTextStyles.heading1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pesanan untuk Meja ${widget.tableNumber} berhasil dikirim ke Kasir.',
                    style: AppTextStyles.subtitle.copyWith(color: AppColors.success),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_selectedPaymentMethod == 'QRIS') ...[
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border.withOpacity(0.4)),
                        boxShadow: AppShadows.card,
                      ),
                      child: StreamBuilder<Map<String, dynamic>>(
                        stream: _firestoreService.streamActiveQrisConfig(),
                        builder: (context, snapshot) {
                          final config = snapshot.data ?? {};
                          final customerQris = config['customer'];
                          final imageUrl = customerQris?['imageUrl'] as String?;
                          final label = customerQris?['label'] as String?;

                          return _buildQrisPaymentSection(imageUrl, label, _submittedTotalPrice);
                        },
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Silakan lakukan pembayaran langsung sebesar ${AppFormatter.formatRupiah(_submittedTotalPrice)} di meja kasir.',
                      style: AppTextStyles.subtitle.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mohon tunggu beberapa saat. Kasir kami akan segera memverifikasi dan pelayan akan mengantarkan hidangan lezat Anda.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 28),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isSuccess = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    child: const Text(
                      'Pesan Lagi',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomerGuideBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        'Panduan Memesan & Membayar',
                        style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ikuti 4 langkah praktis berikut untuk memesan hidangan favorit Anda:',
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildGuideStepTile(
                          stepNumber: '1',
                          title: 'Pilih Hidangan',
                          description: 'Cari makanan dan minuman lezat kesukaan Anda di daftar menu. Ketuk tombol "+ Tambah" untuk memasukkannya ke dalam keranjang belanja.',
                          detailText: 'Tips: Ketuk item untuk menambahkan catatan khusus (misalnya: "es sedikit", "tidak pedas") atau untuk paket makanan, Anda bisa memilih rasa minumannya.',
                          icon: Icons.restaurant_menu_rounded,
                          color: AppColors.primary,
                        ),
                        _buildGuideStepTile(
                          stepNumber: '2',
                          title: 'Tinjau Keranjang',
                          description: 'Setelah selesai memilih hidangan, klik tombol "Tinjau Pesanan" berwarna oranye di bagian bawah layar untuk meninjau pesanan Anda.',
                          detailText: 'Di halaman Tinjau Pesanan, Anda dapat menaikkan/menurunkan jumlah porsi atau membatalkan item sebelum benar-benar mengirimkannya.',
                          icon: Icons.shopping_basket_rounded,
                          color: AppColors.secondary,
                        ),
                        _buildGuideStepTile(
                          stepNumber: '3',
                          title: 'Pilih Metode Pembayaran',
                          description: 'Di bagian bawah keranjang, pilih salah satu dari dua metode pembayaran berikut yang paling nyaman bagi Anda:',
                          detailText: '• QRIS (Otomatis): Bayar langsung menggunakan saldo E-Wallet (GoPay, OVO, Dana, ShopeePay) or M-Banking dengan memindai kode QRIS.\n• Bayar Tunai di Kasir: Lakukan pembayaran secara manual menggunakan uang tunai langsung di meja kasir setelah pesanan dikonfirmasi.',
                          icon: Icons.payments_rounded,
                          color: AppColors.success,
                        ),
                        _buildGuideStepTile(
                          stepNumber: '4',
                          title: 'Kirim & Selesaikan',
                          description: 'Tekan tombol "Kirim Pesanan" untuk mengirimkan pesanan Anda ke dapur dan kasir secara realtime.',
                          detailText: '• Jika memilih QRIS: Pindai kode QRIS dinamis yang muncul di layar sukses, selesaikan transfer, lalu tunjukkan bukti bayar ke pelayan saat mengantarkan makanan.\n• Jika memilih Bayar Tunai di Kasir: Silakan konfirmasi dan selesaikan pembayaran tunai Anda langsung di meja kasir.\n\nSelamat menikmati hidangan lezat Anda!',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF2196F3),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuideStepTile({
    required String stepNumber,
    required String title,
    required String description,
    required String detailText,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              Container(
                width: 2,
                height: 120,
                color: AppColors.border.withOpacity(0.15),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border.withOpacity(0.15)),
                  ),
                  child: Text(
                    detailText,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, height: 1.4, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Integrasi QRIS & E-Wallet Baru ---

  Future<void> _openEWallet(String urlScheme, String appName) async {
    try {
      final Uri uri = Uri.parse(urlScheme);
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak dapat membuka aplikasi $appName. Pastikan aplikasi sudah terinstal.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka $appName: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildEWalletButton({required String appName, required Color color, required String urlScheme}) {
    return ElevatedButton(
      onPressed: () => _openEWallet(urlScheme, appName),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        elevation: 1,
      ),
      child: Text(
        appName,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildQrisPaymentSection(String? imageUrl, String? label, int amount) {
    Widget buildFallback() {
      return Image.asset(
        'assets/images/qris_code_customer.png',
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 180,
          height: 180,
          color: Colors.white10,
          child: const Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.white30),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label != null && label.isNotEmpty
                    ? 'PINDAI KODE QRIS ($label)'
                    : 'PINDAI KODE QRIS UNTUK MEMBAYAR',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => buildFallback(),
                )
              : buildFallback(),
        ),
        const SizedBox(height: 12),

        // Simpan / Buka QRIS button
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () {
              try {
                downloadFile(imageUrl, 'qris_dapoer_manahan_${label ?? "payment"}.png');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal mengunduh gambar: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.primary),
            label: const Text(
              'Unduh Gambar QRIS',
              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Total Tagihan: ${AppFormatter.formatRupiah(amount)}',
          style: AppTextStyles.subtitle.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),

        // E-Wallet instruction & buttons
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cara Bayar Lewat HP:',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Tekan tombol "Unduh Gambar QRIS" di atas untuk menyimpan ke HP Anda.\n'
                '2. Buka salah satu aplikasi e-wallet pilihan Anda di bawah ini:',
                style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              // E-Wallet buttons row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildEWalletButton(
                    appName: 'DANA',
                    color: const Color(0xFF118EEA),
                    urlScheme: 'dana://',
                  ),
                  _buildEWalletButton(
                    appName: 'GoPay',
                    color: const Color(0xFF00AED6),
                    urlScheme: 'gojek://',
                  ),
                  _buildEWalletButton(
                    appName: 'OVO',
                    color: const Color(0xFF4C2A86),
                    urlScheme: 'ovo://',
                  ),
                  _buildEWalletButton(
                    appName: 'ShopeePay',
                    color: const Color(0xFFEE4D2D),
                    urlScheme: 'shopeepay://',
                  ),
                  _buildEWalletButton(
                    appName: 'LinkAja',
                    color: const Color(0xFFE61C24),
                    urlScheme: 'linkaja://',
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Text(
                '3. Di aplikasi e-wallet, pilih "Scan" / "Bayar" lalu ketuk ikon galeri untuk mengunggah gambar QRIS.',
                style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Mendukung Gopay, OVO, ShopeePay, Dana, LinkAja & M-Banking',
          style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showQrisInvoiceDialog(BuildContext context, Map<String, dynamic> qr) {
    final items = qr['items'] as List<dynamic>? ?? [];
    final totalPrice = qr['totalPrice'] as int? ?? 0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Invoice Pembayaran',
                        style: AppTextStyles.heading2,
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Detail Pesanan Meja ${widget.tableNumber}',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Item list
                  ...items.map((it) {
                    final name = it['name'] as String? ?? '';
                    final qty = it['quantity'] as int? ?? 0;
                    final price = it['price'] as int? ?? 0;
                    final notes = it['notes'] as String? ?? '';
                    final variant = it['variant'] as String?;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$qty x $name',
                                  style: AppTextStyles.body.copyWith(fontSize: 13),
                                ),
                              ),
                              Text(
                                AppFormatter.formatRupiah(price * qty),
                                style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (variant != null && variant.isNotEmpty) ...[
                            Text(
                              '  Minuman: $variant',
                              style: AppTextStyles.caption.copyWith(color: AppColors.secondary, fontSize: 11),
                            ),
                          ],
                          if (notes.isNotEmpty) ...[
                            Text(
                              '  Catatan: "$notes"',
                              style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 20),

                  // QRIS stream
                  StreamBuilder<Map<String, dynamic>>(
                    stream: _firestoreService.streamActiveQrisConfig(),
                    builder: (context, snapshot) {
                      final config = snapshot.data ?? {};
                      final customerQris = config['customer'];
                      final imageUrl = customerQris?['imageUrl'] as String?;
                      final label = customerQris?['label'] as String?;

                      return _buildQrisPaymentSection(imageUrl, label, totalPrice);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  void _showProductDetailBottomSheet(BuildContext context, String itemId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return Consumer<MenuProvider>(
          builder: (context, menuProv, _) {
            final itemIndex = menuProv.allMenuItems.indexWhere((it) => it.id == itemId);
            if (itemIndex == -1) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_rounded, size: 60, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Menu tidak lagi tersedia', style: AppTextStyles.body),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            }

            final item = menuProv.allMenuItems[itemIndex];
            final categoryName = menuProv.getCategoryName(item.categoryId);
            final isPaket = categoryName.toLowerCase().contains('paket') || item.name.toLowerCase().contains('paket');

            return StatefulBuilder(
              builder: (context, setSheetState) {
                final qty = _getItemTotalQuantity(item.id);

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.textHint.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                        ),
                        if (item.imageUrl.isNotEmpty)
                          Container(
                            height: 250,
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              color: AppColors.surfaceDark,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                // Layer 1: Blurred background cover
                                Positioned.fill(
                                  child: ImageFiltered(
                                    imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Image.network(
                                      item.imageUrl,
                                      key: ValueKey('blur_${item.imageUrl}'),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox(),
                                    ),
                                  ),
                                ),
                                // Layer 2: Dark semi-transparent overlay to merge with dark theme
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.25),
                                  ),
                                ),
                                // Layer 3: Crisp uncropped front image (contain)
                                Positioned.fill(
                                  child: Image.network(
                                    item.imageUrl,
                                    key: ValueKey('contain_${item.imageUrl}'),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        color: AppColors.primary,
                                        size: 80,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            height: 200,
                            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              color: AppColors.surfaceDark,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.fastfood_rounded,
                                color: AppColors.primary,
                                size: 80,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  categoryName,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.name,
                                style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppFormatter.formatRupiah(item.price),
                                style: AppTextStyles.price.copyWith(fontSize: 20),
                              ),
                              const SizedBox(height: 16),
                              Divider(color: AppColors.border.withOpacity(0.2)),
                              const SizedBox(height: 12),
                              Text(
                                'Deskripsi Menu',
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.description.isNotEmpty ? item.description : 'Tidak ada deskripsi untuk menu ini.',
                                style: AppTextStyles.bodySecondary.copyWith(height: 1.5),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Jumlah Pesanan',
                                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (qty > 0)
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_rounded,
                                            color: AppColors.primary,
                                            size: 28,
                                          ),
                                          onPressed: () {
                                            setSheetState(() {
                                              if (isPaket) {
                                                _removeFromCartFromGrid(item);
                                              } else {
                                                _removeFromCart(item);
                                              }
                                            });
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                          child: Text(
                                            qty.toString(),
                                            style: AppTextStyles.heading3.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_rounded,
                                            color: AppColors.primary,
                                            size: 28,
                                          ),
                                          onPressed: () {
                                            if (isPaket) {
                                              Navigator.pop(ctx);
                                              _showDrinkOptionsBottomSheet(item);
                                            } else {
                                              setSheetState(() {
                                                _addToCart(item);
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (isPaket) {
                                          Navigator.pop(ctx);
                                          _showDrinkOptionsBottomSheet(item);
                                        } else {
                                          setSheetState(() {
                                            _addToCart(item);
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                                      label: const Text(
                                        'Tambah',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
