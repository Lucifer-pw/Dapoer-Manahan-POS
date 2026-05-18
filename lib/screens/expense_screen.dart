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
  String _paymentMethod = 'Cash';

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<ExpenseProvider>(context);
    if (provider.filterDate != null && provider.filterDate != _filterDate) {
      final dateToApply = provider.filterDate!;
      Future.microtask(() {
        if (mounted) {
          provider.setFilterDate(null);
          _applyFilterDate(dateToApply);
        }
      });
    }
  }

  Future<void> _applyFilterDate(DateTime picked) async {
    setState(() {
      _filterDate = picked;
      _isSearching = true;
    });

    final start = DateTime(picked.year, picked.month, picked.day);
    final end = start.add(const Duration(days: 1));
    
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final results = await provider.getExpensesByDateRange(start, end);
    
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
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
      await _applyFilterDate(picked);
    }
  }

  void _clearFilter() {
    setState(() {
      _filterDate = null;
      _searchResults = null;
    });
  }

  void _showAddDialog() {
    _paymentMethod = 'Cash'; // reset to default
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setStateDialog(() => _paymentMethod = 'Cash');
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _paymentMethod == 'Cash' ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: _paymentMethod == 'Cash' ? AppColors.primary : AppColors.border.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Text('Cash', style: TextStyle(
                              color: _paymentMethod == 'Cash' ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setStateDialog(() => _paymentMethod = 'QRIS');
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _paymentMethod == 'QRIS' ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: _paymentMethod == 'QRIS' ? AppColors.primary : AppColors.border.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Text('QRIS', style: TextStyle(
                              color: _paymentMethod == 'QRIS' ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
        paymentMethod: _paymentMethod,
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
          final totalCash = expenses.where((e) => e.paymentMethod == 'Cash').fold(0, (sum, e) => sum + e.price);
          final totalQris = expenses.where((e) => e.paymentMethod == 'QRIS').fold(0, (sum, e) => sum + e.price);
          final total = totalCash + totalQris;

          return Column(
            children: [
              _buildDailyTotal(totalCash, totalQris, total, _filterDate != null ? AppFormatter.formatDate(_filterDate!) : 'Hari Ini'),
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

  Widget _buildDailyTotal(int totalCash, int totalQris, int total, String label) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Belanja (Cash + QRIS)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(AppFormatter.formatRupiah(total),
                      style: AppTextStyles.heading2.copyWith(color: Colors.white)),
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
              const Icon(Icons.shopping_cart_checkout,
                  color: Colors.white30, size: 40),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Belanja (Cash)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(AppFormatter.formatRupiah(totalCash), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Belanja (QRIS)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(AppFormatter.formatRupiah(totalQris), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
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
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: expense.paymentMethod == 'QRIS' ? AppColors.info.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  expense.paymentMethod,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: expense.paymentMethod == 'QRIS' ? AppColors.info : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
