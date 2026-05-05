import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';
import '../widgets/table_card.dart';

class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  void _showAddEditDialog(BuildContext context, {RestaurantTable? table}) {
    final tableProv = Provider.of<TableProvider>(context, listen: false);
    final numberController =
        TextEditingController(text: table?.number.toString() ?? '');
    final capacityController =
        TextEditingController(text: table?.capacity.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(table == null ? 'Tambah Meja' : 'Edit Meja',
            style: AppTextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nomor Meja',
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacityController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Kapasitas (Kursi)',
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final number = int.tryParse(numberController.text) ?? 0;
              final capacity = int.tryParse(capacityController.text) ?? 0;
              if (number > 0) {
                if (table == null) {
                  await tableProv.addTable(number, capacity);
                } else {
                  await tableProv.updateTable(table.id, number, capacity);
                }
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: Consumer<TableProvider>(
        builder: (context, tableProv, _) {
          if (tableProv.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (tableProv.tables.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_restaurant_outlined,
                      size: 60, color: AppColors.textHint.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Belum ada meja', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _showAddEditDialog(context),
                    child: const Text('Tambah Meja Pertama'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Legend
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                      bottom: BorderSide(
                          color: AppColors.border.withOpacity(0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem(
                        'Tersedia', AppColors.success, tableProv.availableCount),
                    _buildLegendItem(
                        'Terisi', AppColors.error, tableProv.occupiedCount),
                    _buildLegendItem(
                        'Reserved',
                        AppColors.warning,
                        tableProv.tables
                            .where((t) => t.status == TableStatus.reserved)
                            .length),
                  ],
                ),
              ),

              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: tableProv.tables.length,
                  itemBuilder: (context, index) {
                    final table = tableProv.tables[index];
                    return TableCard(
                      table: table,
                      onTap: () {
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
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ($count)', style: AppTextStyles.caption),
      ],
    );
  }

  void _showTableOptions(
      BuildContext context, RestaurantTable table, TableProvider tableProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Meja ${table.number}',
                      style: AppTextStyles.heading3),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.check_circle, color: AppColors.success),
                  title: const Text('Set Tersedia'),
                  onTap: () {
                    tableProv.setAvailable(table.id);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people, color: AppColors.error),
                  title: const Text('Set Terisi'),
                  onTap: () {
                    tableProv.setOccupied(table.id, '');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark, color: AppColors.warning),
                  title: const Text('Set Reserved'),
                  onTap: () {
                    tableProv.setReserved(table.id);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.info),
                  title: const Text('Edit Meja (Nomor/Kursi)'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddEditDialog(context, table: table);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text('Hapus Meja'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Hapus Meja'),
                        content: Text('Yakin ingin menghapus Meja ${table.number}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: AppColors.error))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await tableProv.deleteTable(table.id);
                      if (context.mounted) Navigator.pop(context);
                    }
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
