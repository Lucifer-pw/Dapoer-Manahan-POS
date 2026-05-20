import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../models/order.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  DateTime? _filterDate;
  List<Order>? _searchResults;
  bool _isSearching = false;

  Future<void> _selectDate(BuildContext context) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
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

      // Perform search
      final start = DateTime(picked.year, picked.month, picked.day);
      final end = start.add(const Duration(days: 1));
      
      final results = await provider.getOrdersByDateRange(start, end);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    }
  }

  void _clearFilter() {
    setState(() {
      _filterDate = null;
      _searchResults = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Riwayat Transaksi', style: AppTextStyles.heading2),
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
      body: Consumer<OrderProvider>(
        builder: (context, orderProv, _) {
          if (orderProv.isLoading || _isSearching) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final orders = _filterDate != null ? (_searchResults ?? []) : orderProv.allOrders;

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 60, color: AppColors.textHint.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    _filterDate != null 
                      ? 'Tidak ada transaksi pada tanggal ${AppFormatter.formatDate(_filterDate!)}'
                      : 'Belum ada transaksi', 
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                  if (_filterDate != null) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _clearFilter,
                      child: const Text('Lihat Semua Transaksi', style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ],
              ),
            );
          }

          // Grouping orders by date
          final groupedOrders = <String, List<Order>>{};
          for (final order in orders) {
            final dateStr = AppFormatter.formatDate(order.createdAt);
            if (!groupedOrders.containsKey(dateStr)) {
              groupedOrders[dateStr] = [];
            }
            groupedOrders[dateStr]!.add(order);
          }

          final dates = groupedOrders.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final dayOrders = groupedOrders[date]!;
              final dailyTotal = dayOrders
                  .where((o) => o.status == OrderStatus.completed)
                  .fold(0, (sum, o) => sum + o.total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateHeader(date, dailyTotal),
                  const SizedBox(height: 12),
                  ...dayOrders.map((order) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildOrderCard(context, order),
                  )),
                  const SizedBox(height: 12),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(String date, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                date,
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Total Pendapatan', style: AppTextStyles.caption.copyWith(fontSize: 10)),
              Text(
                AppFormatter.formatRupiah(total),
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.success,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    Color statusColor;
    String statusText;

    switch (order.status) {
      case OrderStatus.completed:
        statusColor = AppColors.success;
        statusText = 'Selesai';
        break;
      case OrderStatus.pending:
        statusColor = AppColors.warning;
        statusText = 'Pending';
        break;
      case OrderStatus.cancelled:
        statusColor = AppColors.error;
        statusText = 'Batal';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(order.orderNumber, style: AppTextStyles.heading3.copyWith(fontSize: 16)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: order.paymentMethod == 'QRIS' ? AppColors.info.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.paymentMethod == 'Tunai' ? 'Cash' : order.paymentMethod,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: order.paymentMethod == 'QRIS' ? AppColors.info : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: AppColors.textHint),
                const SizedBox(width: 6),
                Text(AppFormatter.formatDateTime(order.createdAt), style: AppTextStyles.caption),
                const Spacer(),
                Icon(Icons.table_restaurant, size: 14, color: AppColors.textHint),
                const SizedBox(width: 6),
                Text('Meja ${order.tableNumber}', style: AppTextStyles.caption),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.border, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${order.items.length} Item', style: AppTextStyles.bodySecondary),
                Text(AppFormatter.formatRupiah(order.total), style: AppTextStyles.price),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
