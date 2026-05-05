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
    final options = ['Teh Anget', 'Esteh', 'Air Mineral'];
    
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
        child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
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
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textHint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  Provider.of<MenuProvider>(context, listen: false).setSearchQuery(val);
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
                  value: cartProv.tableNumber > 0 ? cartProv.tableNumber : null,
                  hint: Text('Pilih Meja', style: AppTextStyles.bodySecondary.copyWith(fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.textHint),
                  items: tableProv.tables.map((t) => DropdownMenuItem(value: t.number, child: Row(children: [
                    Icon(Icons.table_restaurant, size: 16, color: t.status == TableStatus.available ? AppColors.success : AppColors.error),
                    const SizedBox(width: 8),
                    Text('Meja ${t.number} (${t.capacity} Kursi)', style: AppTextStyles.body.copyWith(fontSize: 13)),
                  ]))).toList(),
                  onChanged: (val) { if (val != null) cartProv.setTableNumber(val); },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                        onNotesChanged: (notes) => cartProv.updateNotes(index, notes),
                      );
                    },
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
                  child: ElevatedButton.icon(
                    onPressed: cartProv.tableNumber > 0
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
      );
    });
  }
}
