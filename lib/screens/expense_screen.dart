import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Tambah Belanja', style: AppTextStyles.heading3),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                  _nameController, 'Nama Bahan', Icons.shopping_basket),
              const SizedBox(height: 12),
              _buildTextField(
                  _qtyController, 'Jumlah (Qty/Kg/Liter)', Icons.scale,
                  isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_priceController, 'Harga', Icons.payments,
                  isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: _submitExpense,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _submitExpense() async {
    if (_nameController.text.isEmpty ||
        _qtyController.text.isEmpty ||
        _priceController.text.isEmpty) return;

    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      await provider.addExpense(
        name: _nameController.text,
        qty: double.parse(_qtyController.text),
        price: int.parse(_priceController.text),
      );

      if (mounted) {
        Navigator.pop(context);
        _nameController.clear();
        _qtyController.clear();
        _priceController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berhasil menyimpan belanja')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Belanja Bahan Harian'),
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          return Column(
            children: [
              _buildDailyTotal(provider.dailyTotal),
              Expanded(
                child: provider.todayExpenses.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: provider.todayExpenses.length,
                        itemBuilder: (context, index) {
                          final expense = provider.todayExpenses[index];
                          return _buildExpenseCard(expense);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDailyTotal(int total) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Belanja Hari Ini',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(AppFormatter.formatRupiah(total),
                  style: AppTextStyles.heading2.copyWith(color: Colors.white)),
            ],
          ),
          const Icon(Icons.shopping_cart_checkout,
              color: Colors.white30, size: 40),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: AppColors.textHint.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Belum ada belanja hari ini',
              style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child:
                const Icon(Icons.receipt, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.name,
                    style: AppTextStyles.subtitle
                        .copyWith(fontWeight: FontWeight.bold)),
                Text(
                    '${expense.qty} x ${AppFormatter.formatRupiah(expense.price)}',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppFormatter.formatRupiah(expense.total),
                  style: AppTextStyles.priceSmall),
            ],
          ),
        ],
      ),
    );
  }
}
