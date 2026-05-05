import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/starting_cash_provider.dart';
import '../models/order.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';
import 'printer_settings_screen.dart';
import 'app_settings_screen.dart';
import 'billing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _filterDate;
  Map<String, dynamic>? _filteredStats;
  int _filteredExpense = 0;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).loadStats();
    });
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

      try {
        final orderProv = Provider.of<OrderProvider>(context, listen: false);
        final expenseProv = Provider.of<ExpenseProvider>(context, listen: false);
        final cashProv = Provider.of<StartingCashProvider>(context, listen: false);
        
        final stats = await orderProv.getStatsForDate(picked);
        await cashProv.loadStartingCash(picked);
        
        final start = DateTime(picked.year, picked.month, picked.day);
        final end = start.add(const Duration(days: 1));
        final expenses = await expenseProv.getExpensesByDateRange(start, end);
        final totalExpense = expenses.fold(0, (sum, e) => sum + e.price);

        setState(() {
          _filteredStats = stats;
          _filteredExpense = totalExpense;
          _isSearching = false;
        });
      } catch (e) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _clearFilter() {
    setState(() {
      _filterDate = null;
      _filteredStats = null;
      _filteredExpense = 0;
    });
    Provider.of<StartingCashProvider>(context, listen: false).loadStartingCash(DateTime.now());
  }

  void _showStartingCashDialog(int currentAmount) {
    final controller = TextEditingController(text: currentAmount > 0 ? currentAmount.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Modal Awal Hari Ini', style: AppTextStyles.heading3),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Masukkan Jumlah Modal',
            prefixText: 'Rp ',
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final amount = int.tryParse(controller.text) ?? 0;
                await Provider.of<StartingCashProvider>(context, listen: false)
                    .updateStartingCash(_filterDate ?? DateTime.now(), amount);
                if (mounted) Navigator.pop(ctx);
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
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            if (_filterDate == null) {
              await Provider.of<OrderProvider>(context, listen: false).loadStats();
              if (mounted) {
                await Provider.of<StartingCashProvider>(context, listen: false).loadStartingCash(DateTime.now());
              }
            }
            if (mounted) {
              await Provider.of<SubscriptionProvider>(context, listen: false).checkStatus();
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _buildBillingBanner(),
              _buildAppBar(),
              const SizedBox(height: 20),
              if (_isSearching)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ))
              else
                _buildStatsSection(),
              const SizedBox(height: 20),
              if (_filterDate == null) ...[
                _buildWeeklyChart(),
                const SizedBox(height: 20),
              ],
              _buildOrdersSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Consumer<AuthProvider>(builder: (context, auth, _) {
      return Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(
            auth.cashierName.isNotEmpty ? auth.cashierName[0].toUpperCase() : 'K',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          )),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Halo, ${auth.cashierName} 👋', style: AppTextStyles.subtitle),
          Text(_filterDate != null ? 'Laporan: ${AppFormatter.formatDate(_filterDate!)}' : AppFormatter.formatDate(DateTime.now()), style: AppTextStyles.caption),
        ])),
        if (_filterDate != null)
          IconButton(
            onPressed: _clearFilter,
            icon: const Icon(Icons.close, color: AppColors.error, size: 22),
            tooltip: 'Hapus Filter',
          ),
        IconButton(
          onPressed: () => _selectDate(context),
          icon: Icon(Icons.calendar_month_rounded, color: _filterDate != null ? AppColors.primary : AppColors.textHint, size: 22),
          tooltip: 'Filter Tanggal',
        ),
        IconButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AppSettingsScreen()));
          },
          icon: const Icon(Icons.settings_rounded, color: AppColors.textHint, size: 22),
        ),
        IconButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
          },
          icon: const Icon(Icons.print_rounded, color: AppColors.textHint, size: 22),
        ),
        IconButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Logout', style: AppTextStyles.heading3),
              content: Text('Yakin ingin keluar?', style: AppTextStyles.body),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.error))),
              ],
            ));
            if (confirm == true && mounted) {
              await auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            }
          },
          icon: const Icon(Icons.logout_rounded, color: AppColors.textHint, size: 22),
        ),
      ]);
    });
  }

  Widget _buildStatsSection() {
    return Consumer3<OrderProvider, ExpenseProvider, StartingCashProvider>(
        builder: (context, orderProv, expenseProv, cashProv, _) {
      
      final stats = _filterDate != null ? (_filteredStats ?? {}) : orderProv.todayStats;
      final grossRevenue = stats['totalRevenue'] ?? 0;
      final totalExpense = _filterDate != null ? _filteredExpense : expenseProv.dailyTotal;
      final netRevenue = grossRevenue - totalExpense;
      final transactions = stats['totalTransactions'] ?? 0;
      final average = stats['averageTransaction'] ?? 0;
      
      final modalAwal = cashProv.startingCash;
      
      // Calculate Cash in Hand (Starting Cash + Cash Payments - Expenses)
      final orders = stats['orders'] as List<Order>? ?? [];
      final cashPayments = orders
          .where((o) =>
              o.status == OrderStatus.completed && o.paymentMethod == 'Tunai')
          .fold(0, (sum, o) => sum + o.total);
      final cashInHand = modalAwal + cashPayments - totalExpense;
      final walletCash = cashInHand - 50000;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_filterDate != null ? 'Data Terfilter' : 'Hari Ini', style: AppTextStyles.heading3),
          if (_filterDate == null || _filterDate!.day == DateTime.now().day)
            TextButton.icon(
              onPressed: () => _showStartingCashDialog(modalAwal),
              icon: const Icon(Icons.edit, size: 14, color: AppColors.primary),
              label: Text(modalAwal > 0 ? 'Edit Modal' : 'Input Modal', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 14),
        StatCard(
            title: 'Modal Awal (Kasir)',
            value: AppFormatter.formatRupiah(modalAwal),
            icon: Icons.payments,
            iconColor: AppColors.secondary,
            subtitle: 'Uang awal di laci kasir'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: StatCard(
                  title: 'Pendapatan Kotor',
                  value: AppFormatter.formatRupiah(grossRevenue),
                  icon: Icons.account_balance_wallet,
                  iconColor: AppColors.success)),
          const SizedBox(width: 12),
          Expanded(
              child: StatCard(
                  title: 'Total Belanja',
                  value: AppFormatter.formatRupiah(totalExpense),
                  icon: Icons.shopping_bag,
                  iconColor: AppColors.error)),
        ]),
        const SizedBox(height: 12),
        StatCard(
            title: 'Pendapatan Bersih (Profit)',
            value: AppFormatter.formatRupiah(netRevenue),
            icon: Icons.monetization_on,
            iconColor: AppColors.primary),
        const SizedBox(height: 12),
        StatCard(
            title: 'Total Uang di Kasir (Tunai)',
            value: AppFormatter.formatRupiah(cashInHand),
            icon: Icons.point_of_sale,
            iconColor: AppColors.info,
            subtitle: 'Modal + Tunai - Belanja'),
        const SizedBox(height: 12),
        StatCard(
            title: 'Uang Cash Masuk Dompet',
            value: AppFormatter.formatRupiah(walletCash > 0 ? walletCash : 0),
            icon: Icons.account_balance,
            iconColor: AppColors.success,
            subtitle: 'Uang di Kasir - Rp 50.000 (Sisa Laci)'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: StatCard(
                  title: 'Transaksi',
                  value: '$transactions',
                  icon: Icons.receipt_long,
                  iconColor: AppColors.info)),
          const SizedBox(width: 12),
          Expanded(
              child: StatCard(
                  title: 'Rata-rata',
                  value: AppFormatter.formatRupiah(average),
                  icon: Icons.trending_up,
                  iconColor: AppColors.secondary)),
        ]),
      ]);
    });
  }

  Widget _buildWeeklyChart() {
    return Consumer<OrderProvider>(builder: (context, orderProv, _) {
      final weeklyData = orderProv.weeklyRevenue;
      if (weeklyData.isEmpty) return const SizedBox.shrink();
      final maxRevenue = weeklyData.map((d) => (d['revenue'] as int).toDouble()).reduce((a, b) => a > b ? a : b);
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(gradient: AppColors.cardGradient, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Penjualan 7 Hari', style: AppTextStyles.heading3),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 100000,
            barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(AppFormatter.formatCompact(rod.toY.toInt()), AppTextStyles.caption.copyWith(color: Colors.white)),
            )),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= weeklyData.length) return const SizedBox();
                final date = weeklyData[i]['date'] as DateTime;
                final days = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];
                return Padding(padding: const EdgeInsets.only(top: 8), child: Text(days[date.weekday - 1], style: AppTextStyles.caption.copyWith(fontSize: 10)));
              })),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            barGroups: List.generate(weeklyData.length, (i) {
              return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: (weeklyData[i]['revenue'] as int).toDouble(), width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)), gradient: AppColors.primaryGradient)]);
            }),
          ))),
        ]),
      );
    });
  }

  Widget _buildOrdersSection() {
    return Consumer<OrderProvider>(builder: (context, orderProv, _) {
      final orders = _filterDate != null 
          ? (_filteredStats?['orders'] as List?)?.where((o) => o.status == OrderStatus.completed).toList() ?? []
          : orderProv.todayOrders.where((o) => o.status == OrderStatus.completed).toList();

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_filterDate != null ? 'Transaksi Tanggal Tersebut' : 'Transaksi Terakhir', style: AppTextStyles.heading3),
          Text('${orders.length} transaksi', style: AppTextStyles.caption),
        ]),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppColors.card.withOpacity(0.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textHint.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text('Belum ada transaksi', style: AppTextStyles.bodySecondary),
            ]),
          )
        else
          ...orders.take(10).map((order) => Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card.withOpacity(0.5), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border.withOpacity(0.2))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.orderNumber, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Meja ${order.tableNumber} • ${order.items.length} item', style: AppTextStyles.caption),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(AppFormatter.formatRupiah(order.total), style: AppTextStyles.priceSmall),
                Text(AppFormatter.formatTime(order.createdAt), style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ]),
            ]),
          )),
      ]);
    });
  }

  Widget _buildBillingBanner() {
    return Consumer<SubscriptionProvider>(
      builder: (context, sub, _) {
        if (sub.status != SubscriptionStatus.warning) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jatuh Tempo Pembayaran',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Segera lakukan pembayaran Rp 50.000 sebelum tanggal 6 agar aplikasi tidak terkunci.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingScreen()));
                },
                child: const Text('BAYAR', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
