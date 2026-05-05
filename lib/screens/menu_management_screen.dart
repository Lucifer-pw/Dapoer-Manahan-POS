import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import 'add_edit_menu_screen.dart';
import 'category_management_screen.dart';

class MenuManagementScreen extends StatelessWidget {
  const MenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Kelola Menu', style: AppTextStyles.heading2),
        actions: [
          IconButton(
            icon: const Icon(Icons.category, color: AppColors.primary),
            tooltip: 'Kelola Kategori',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<MenuProvider>(
        builder: (context, menuProv, _) {
          if (menuProv.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final items = menuProv.filteredMenuItems;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (value) => menuProv.setSearchQuery(value),
                  decoration: InputDecoration(
                    hintText: 'Cari menu...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: AppTextStyles.body,
                ),
              ),
              if (items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_menu,
                            size: 60, color: AppColors.textHint.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          menuProv.searchQuery.isEmpty ? 'Belum ada menu' : 'Menu tidak ditemukan',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildMenuItemCard(context, item);
                    },
                  ),
                ),
              const SizedBox(height: 80), // Space for FAB
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditMenuScreen()),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Tambah Menu', style: AppTextStyles.button),
      ),
    );
  }

  Widget _buildMenuItemCard(BuildContext context, MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: item.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(item.imageUrl, fit: BoxFit.cover),
                )
              : const Icon(Icons.fastfood, color: AppColors.textHint),
        ),
        title: Text(item.name, style: AppTextStyles.subtitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(AppFormatter.formatRupiah(item.price), style: AppTextStyles.priceSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.isAvailable ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.isAvailable ? 'Tersedia' : 'Habis',
                  style: AppTextStyles.caption.copyWith(
                    color: item.isAvailable ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: AppColors.primary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddEditMenuScreen(menuItem: item)),
            );
          },
        ),
      ),
    );
  }
}
