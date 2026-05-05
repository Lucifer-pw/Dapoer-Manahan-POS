import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  
  DateTime? _filterDate;
  List<Expense>? _searchResults;
  bool _isSearching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _filterDate) {
      setState(() {
        _filterDate = picked;
        _isSearching = true;
      });

      final start = DateTime(picked.year, picked.month, picked.day);
      final end = start.add(const Duration(days: 1));
      
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final results = await provider.getExpensesByDateRange(start, end);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _filterDate = null;
      _searchResults = null;
    });
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
                  _unitController, 'Ukuran (Pcs/Kg/Liter)', Icons.scale),
              const SizedBox(height: 12),
              _buildTextField(_priceController, 'Harga Total', Icons.payments,
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
        _unitController.text.isEmpty ||
        _priceController.text.isEmpty) return;

    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      await provider.addExpense(
        name: _nameController.text,
        unit: _unitController.text,
        price: int.parse(_priceController.text),
      );

      if (mounted) {
        Navigator.pop(context);
        _nameController.clear();
        _unitController.clear();
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
        actions: [
          if (_filterDate != null)
            IconButton(
              onPressed: _clearFilter,
              icon: const Icon(Icons.close, color: AppColors.error),
              tooltip: 'Hapus Filter',
            ),
          IconButton(
            onPressed: () => _selectDate(context),
            icon: Icon(
              Icons.calendar_month_rounded, 
              color: _filterDate != null ? AppColors.primary : AppColors.textHint
            ),
            tooltip: 'Filter Tanggal',
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading || _isSearching) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final expenses = _filterDate != null ? (_searchResults ?? []) : provider.todayExpenses;
          final total = _filterDate != null 
              ? expenses.fold(0, (sum, e) => sum + e.price) 
              : provider.dailyTotal;

          return Column(
            children: [
              _buildDailyTotal(total, _filterDate != null ? AppFormatter.formatDate(_filterDate!) : 'Hari Ini'),
              Expanded(
                child: expenses.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
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

  Widget _buildDailyTotal(int total, String label) {
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
              Text('Total Belanja ($label)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
          Text(
            _filterDate != null 
              ? 'Tidak ada data belanja pada ${AppFormatter.formatDate(_filterDate!)}'
              : 'Belum ada belanja hari ini',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
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
                Text(expense.unit, style: AppTextStyles.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppFormatter.formatRupiah(expense.price),
                  style: AppTextStyles.priceSmall),
            ],
          ),
        ],
      ),
    );
  }
}
