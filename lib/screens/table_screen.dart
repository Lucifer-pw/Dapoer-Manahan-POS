import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';
import '../widgets/table_card.dart';

class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Manajemen Meja', style: AppTextStyles.heading2),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur tambah meja belum diimplementasi')),
              );
            },
          ),
        ],
      ),
      body: Consumer<TableProvider>(
        builder: (context, tableProv, _) {
          if (tableProv.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (tableProv.tables.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_restaurant_outlined, size: 60, color: AppColors.textHint.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Belum ada meja', style: AppTextStyles.bodySecondary),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Legend
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem('Tersedia', AppColors.success, tableProv.availableCount),
                    _buildLegendItem('Terisi', AppColors.error, tableProv.occupiedCount),
                    _buildLegendItem('Reserved', AppColors.warning, tableProv.tables.where((t) => t.status == TableStatus.reserved).length),
                  ],
                ),
              ),

              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: tableProv.tables.length,
                  itemBuilder: (context, index) {
                    final table = tableProv.tables[index];
                    return TableCard(
                      table: table,
                      onTap: () {
                        // Show options
                        _showTableOptions(context, table, tableProv);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ($count)', style: AppTextStyles.caption),
      ],
    );
  }

  void _showTableOptions(BuildContext context, RestaurantTable table, TableProvider tableProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ubah Status Meja ${table.number}', style: AppTextStyles.heading3),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: AppColors.success),
                  title: Text('Tersedia', style: AppTextStyles.body),
                  onTap: () {
                    tableProv.setAvailable(table.id);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people, color: AppColors.error),
                  title: Text('Terisi', style: AppTextStyles.body),
                  onTap: () {
                    tableProv.setOccupied(table.id, '');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark, color: AppColors.warning),
                  title: Text('Reserved', style: AppTextStyles.body),
                  onTap: () {
                    tableProv.setReserved(table.id);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
