import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class CustomerOrderScreen extends StatefulWidget {
  final String tableNumber;
  const CustomerOrderScreen({super.key, required this.tableNumber});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  // Local cart state
  // Structure: { menuItemId: { 'item': MenuItem, 'quantity': int, 'notes': String } }
  final Map<String, Map<String, dynamic>> _cart = {};

  String? _localSelectedCategoryId;
  String _localSearchQuery = '';
  bool _isSubmitting = false;
  bool _isSuccess = false;

  final FirestoreService _firestoreService = FirestoreService();

  int get totalItems => _cart.values.fold(0, (acc, elem) => acc + (elem['quantity'] as int));
  int get totalPrice => _cart.values.fold(0, (acc, elem) {
        final item = elem['item'] as MenuItem;
        final qty = elem['quantity'] as int;
        return acc + (item.price * qty);
      });

  void _addToCart(MenuItem item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!['quantity'] = (_cart[item.id]!['quantity'] as int) + 1;
      } else {
        _cart[item.id] = {
          'item': item,
          'quantity': 1,
          'notes': '',
        };
      }
    });
  }

  void _removeFromCart(MenuItem item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        final currentQty = _cart[item.id]!['quantity'] as int;
        if (currentQty > 1) {
          _cart[item.id]!['quantity'] = currentQty - 1;
        } else {
          _cart.remove(item.id);
        }
      }
    });
  }

  void _updateNotes(String itemId, String newNotes) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        _cart[itemId]!['notes'] = newNotes;
      }
    });
  }

  void _showNotesDialog(MenuItem item) {
    final currentNotes = _cart[item.id]?['notes'] as String? ?? '';
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
                _updateNotes(item.id, controller.text.trim());
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
        return {
          'id': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': qty,
          'notes': notes,
        };
      }).toList();

      final Map<String, dynamic> qrOrderData = {
        'tableNumber': widget.tableNumber,
        'items': orderItems,
        'totalPrice': totalPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestoreService.createQrOrder(qrOrderData);

      setState(() {
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
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  _showNotesDialog(item);
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
                                                        _removeFromCart(item);
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
                                                        _addToCart(item);
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
                        children: [
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
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

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
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final qty = _cart[item.id]?['quantity'] as int? ?? 0;

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
                                    child: Container(
                                      color: AppColors.surfaceDark,
                                      width: double.infinity,
                                      child: item.imageUrl.isNotEmpty
                                          ? Image.network(
                                              item.imageUrl,
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
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
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
                                                    onTap: () => _removeFromCart(item),
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
                                                    onTap: () => _addToCart(item),
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
                                                onTap: () => _addToCart(item),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
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
              Text(
                'Mohon tunggu beberapa saat. Kasir kami akan segera memverifikasi dan pelayan akan mengantarkan hidangan lezat Anda.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
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
    );
  }
}
