import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/menu_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/table_provider.dart';
import '../models/menu_item.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import '../widgets/menu_grid_item.dart';
import '../widgets/cart_item_widget.dart';
import '../widgets/category_chip.dart';
import 'payment_screen.dart';
import '../providers/draft_provider.dart';
import '../models/draft_order.dart';
import '../widgets/drafts_dialog.dart';
import '../providers/order_provider.dart';
import 'package:uuid/uuid.dart';
import '../widgets/qr_order_floating_card.dart';
import '../widgets/table_chat_floating_card.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleMenuItemTap(MenuItem item) {
    final menuProv = Provider.of<MenuProvider>(context, listen: false);
    final cartProv = Provider.of<CartProvider>(context, listen: false);
    final categoryName = menuProv.getCategoryName(item.categoryId);

    if (categoryName.toLowerCase().contains('paket')) {
      _showDrinkOptionsDialog(item, cartProv);
    } else {
      cartProv.addItem(item);
    }
  }

  void _showDrinkOptionsDialog(MenuItem item, CartProvider cartProv) {
    final menuProv = Provider.of<MenuProvider>(context, listen: false);

    // Ambil opsi dinamis dari kategori "Botolan"
    final botolanCatIds = menuProv.categories
        .where((c) => c.name.toLowerCase().contains('botol'))
        .map((c) => c.id)
        .toList();

    final dynamicOptions = menuProv.allMenuItems
        .where((m) => botolanCatIds.contains(m.categoryId) && m.isAvailable)
        .map((m) => m.name)
        .toList();

    // Gabungkan dengan opsi tetap (Air Mineral, Es Teh, Teh Anget)
    final options = {'Air Mineral', 'Es Teh', 'Teh Anget', ...dynamicOptions}.toList();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Pilih Minuman - ${item.name}', style: AppTextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) => ListTile(
            title: Text(opt, style: AppTextStyles.body),
            onTap: () {
              cartProv.addItem(item, variant: opt);
              Navigator.pop(ctx);
            },
            trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false, // Prevents keyboard from causing overflow
      body: SafeArea(
        child: Stack(
          children: [
            isWide ? _buildWideLayout() : _buildNarrowLayout(),
            Positioned(
              bottom: 16,
              right: 16,
              left: isWide ? null : 16,
              width: isWide ? 320 : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const TableChatFloatingCard(),
                  const SizedBox(height: 12),
                  const QrOrderFloatingCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(children: [
      Expanded(flex: 6, child: _buildMenuSection()),
      Container(width: 1, color: AppColors.border.withOpacity(0.2)),
      Expanded(flex: 4, child: _buildCartSection()),
    ]);
  }

  Widget _buildNarrowLayout() {
    return Column(children: [
      Expanded(flex: 5, child: _buildMenuSection()), // Reduced flex to give cart more room
      Container(height: 1, color: AppColors.border.withOpacity(0.2)),
      Expanded(flex: 5, child: _buildCartSection()),
    ]);
  }

  Widget _buildMenuSection() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(children: [
          Row(children: [
            Text('Kasir', style: AppTextStyles.heading2),
            const SizedBox(width: 12),
            // Drafts Button
            IconButton(
              onPressed: () => showDialog(context: context, builder: (_) => const DraftsDialog()),
              icon: Consumer<DraftProvider>(builder: (context, dp, _) => Badge(
                label: Text('${dp.drafts.length}'),
                isLabelVisible: dp.drafts.isNotEmpty,
                child: const Icon(Icons.pending_actions, color: AppColors.primary),
              )),
            ),
            const Spacer(),
            Container(
              width: 180, height: 40,
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: AppColors.border.withOpacity(0.3))),
              child: TextField(
                controller: _searchController,
                style: AppTextStyles.body.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari menu...',
                  hintStyle: AppTextStyles.caption,
                  prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textHint),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: AppColors.textHint),
                          onPressed: () {
                            _searchController.clear();
                            Provider.of<MenuProvider>(context, listen: false).setSearchQuery('');
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  Provider.of<MenuProvider>(context, listen: false).setSearchQuery(val);
                  setState(() {}); // Refresh to show/hide clear button
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Consumer<MenuProvider>(builder: (context, menuProv, _) {
            return SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                CategoryChip(label: 'Semua', emoji: '🍽️', isSelected: menuProv.selectedCategoryId == null, onTap: () => menuProv.selectCategory(null)),
                const SizedBox(width: 8),
                ...menuProv.categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CategoryChip(label: cat.name, emoji: cat.icon, isSelected: menuProv.selectedCategoryId == cat.id, onTap: () => menuProv.selectCategory(cat.id)),
                )),
              ]),
            );
          }),
        ]),
      ),
      Expanded(
        child: Consumer2<MenuProvider, CartProvider>(builder: (context, menuProv, cartProv, _) {
          final items = menuProv.availableMenuItems;
          if (menuProv.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.restaurant_menu, size: 60, color: AppColors.textHint.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('Belum ada menu', style: AppTextStyles.bodySecondary),
            ]));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final cartQty = _getCartQty(cartProv, item);
              return MenuGridItem(
                menuItem: item,
                cartQuantity: cartQty,
                onTap: () => _handleMenuItemTap(item),
              );
            },
          );
        }),
      ),
    ]);
  }

  int _getCartQty(CartProvider cart, MenuItem item) {
    int qty = 0;
    for (final ci in cart.items) {
      if (ci.menuItemId == item.id) qty += ci.quantity;
    }
    return qty;
  }

  Widget _buildCartSection() {
    return Consumer2<CartProvider, TableProvider>(builder: (context, cartProv, tableProv, _) {
      return Container(
        color: AppColors.surface,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const Icon(Icons.shopping_cart, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Pesanan', style: AppTextStyles.heading3),
              const Spacer(),
              if (cartProv.items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Text('${cartProv.totalQuantity} item', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border.withOpacity(0.3))),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: cartProv.isTakeAway ? -1 : (cartProv.tableNumber > 0 ? cartProv.tableNumber : null),
                  hint: Text('Pilih Meja', style: AppTextStyles.bodySecondary.copyWith(fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.textHint),
                  items: [
                    DropdownMenuItem(
                      value: -1,
                      child: Row(children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Dibawa Pulang (Take Away)', style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.primary)),
                      ]),
                    ),
                    ...tableProv.tables.map((t) => DropdownMenuItem(value: t.number, child: Row(children: [
                      Icon(Icons.table_restaurant, size: 16, color: t.status == TableStatus.available ? AppColors.success : AppColors.error),
                      const SizedBox(width: 8),
                      Text('Meja ${t.number} (${t.capacity} Kursi)', style: AppTextStyles.body.copyWith(fontSize: 13)),
                    ]))),
                  ],
                  onChanged: (val) { 
                    if (val == -1) {
                      cartProv.setTakeAway(true);
                    } else if (val != null) {
                      cartProv.setTableNumber(val);
                    } 
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                if (cartProv.activeDraftId != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Mengedit Pesanan #${cartProv.activeDraftNumber}',
                          style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: cartProv.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_shopping_cart, size: 48, color: AppColors.textHint.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          Text('Keranjang kosong', style: AppTextStyles.bodySecondary),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: cartProv.items.length,
                          itemBuilder: (context, index) {
                            final item = cartProv.items[index];
                            return CartItemWidget(
                              item: item, index: index,
                              onIncrement: () => cartProv.incrementItem(index),
                              onDecrement: () => cartProv.decrementItem(index),
                              onRemove: () => cartProv.removeItem(index),
                              onBonusToggle: () => cartProv.toggleBonus(index),
                              onNotesChanged: (notes) => cartProv.updateNotes(index, notes),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          if (cartProv.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.2))),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Subtotal', style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
                  Text(AppFormatter.formatRupiah(cartProv.subtotal), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
                const SizedBox(height: 2),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: AppTextStyles.heading3.copyWith(fontSize: 16)),
                  Text(AppFormatter.formatRupiah(cartProv.total), style: AppTextStyles.price.copyWith(fontSize: 18)),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: Row(children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: cartProv.isEmpty ? null : () async {
                          final draftProv = Provider.of<DraftProvider>(context, listen: false);
                          final orderProv = Provider.of<OrderProvider>(context, listen: false);
                          
                          String draftId = cartProv.activeDraftId ?? const Uuid().v4();
                          int? draftNumber = cartProv.activeDraftNumber;
                          
                          // Jika draf baru, ambil nomor urut berikutnya
                          if (draftNumber == null) {
                            try {
                              // 1. Ambil nomor urut dari transaksi yang sudah lunas (database)
                              final nextOrderSeq = await orderProv.getNextSequenceNumber();
                              
                              // 2. Ambil nomor urut tertinggi dari draf yang sedang ada di list tertunda
                              int maxDraftNum = 0;
                              if (draftProv.drafts.isNotEmpty) {
                                maxDraftNum = draftProv.drafts
                                    .map((d) => d.draftNumber ?? 0)
                                    .reduce((a, b) => a > b ? a : b);
                              }
                              
                              // 3. Gunakan angka yang paling besar di antara keduanya
                              draftNumber = (nextOrderSeq > maxDraftNum) ? nextOrderSeq : (maxDraftNum + 1);
                            } catch (e) {
                              // Fallback jika gagal
                              draftNumber = 60 + draftProv.drafts.length;
                            }
                          }

                          final draft = DraftOrder(
                            id: draftId,
                            draftNumber: draftNumber,
                            customerName: 'Pesanan #$draftNumber',
                            tableNumber: cartProv.tableNumber > 0 ? cartProv.tableNumber : null,
                            isTakeAway: cartProv.isTakeAway,
                            items: List.from(cartProv.items),
                            createdAt: DateTime.now(),
                          );
                          
                          await draftProv.saveDraft(draft);
                          cartProv.clear();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Pesanan #$draftNumber berhasil disimpan'),
                              backgroundColor: AppColors.success,
                            ));
                          }
                        },
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text('SIMPAN', style: AppTextStyles.button.copyWith(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: (cartProv.tableNumber > 0 || cartProv.isTakeAway)
                            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()))
                            : null,
                        icon: const Icon(Icons.payment, size: 18),
                        label: Text('BAYAR', style: AppTextStyles.button.copyWith(letterSpacing: 1.2, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.textHint.withOpacity(0.3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
        ]),
      );
    });
  }
}
