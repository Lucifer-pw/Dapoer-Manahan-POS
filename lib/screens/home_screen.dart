import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/starting_cash_provider.dart';
import '../providers/menu_provider.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../models/table_model.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      final expenseProv = Provider.of<ExpenseProvider>(context, listen: false);
      
      await orderProv.loadStats();
      if (mounted) {
        await expenseProv.loadPeriodTotal(orderProv.currentStart, orderProv.currentEnd);
      }
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
        final expenseProv =
            Provider.of<ExpenseProvider>(context, listen: false);
        final cashProv =
            Provider.of<StartingCashProvider>(context, listen: false);

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
    Provider.of<StartingCashProvider>(context, listen: false)
        .loadStartingCash(DateTime.now());
  }

  void _showStartingCashDialog(int currentAmount) {
    final controller = TextEditingController(
        text: currentAmount > 0 ? currentAmount.toString() : '');
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: TextStyle(color: AppColors.textSecondary))),
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
              await Provider.of<OrderProvider>(context, listen: false)
                  .loadStats();
              if (mounted) {
                await Provider.of<StartingCashProvider>(context, listen: false)
                    .loadStartingCash(DateTime.now());
              }
            }
            if (mounted) {
              final orderProv = Provider.of<OrderProvider>(context, listen: false);
              final expenseProv = Provider.of<ExpenseProvider>(context, listen: false);
              await expenseProv.loadPeriodTotal(orderProv.currentStart, orderProv.currentEnd);
              await Provider.of<SubscriptionProvider>(context, listen: false)
                  .checkStatus();
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _buildBillingBanner(),
              _buildAppBar(),
              const SizedBox(height: 20),
              _buildPeriodSelector(),
              const SizedBox(height: 20),
              if (_isSearching)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ))
              else
                _buildStatsSection(),
              const SizedBox(height: 20),
              if (_filterDate == null) ...[
                _buildDynamicChart(),
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
              child: Text(
            auth.cashierName.isNotEmpty
                ? auth.cashierName[0].toUpperCase()
                : 'K',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          )),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Halo, ${auth.cashierName} 👋', style: AppTextStyles.subtitle),
          Text(
              _filterDate != null
                  ? 'Laporan: ${AppFormatter.formatDate(_filterDate!)}'
                  : AppFormatter.formatDate(DateTime.now()),
              style: AppTextStyles.caption),
        ])),
        if (_filterDate != null)
          IconButton(
            onPressed: _clearFilter,
            icon: const Icon(Icons.close, color: AppColors.error, size: 22),
            tooltip: 'Hapus Filter',
          ),
        IconButton(
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen()));
          },
          icon: const Icon(Icons.print_rounded,
              color: AppColors.textHint, size: 22),
          tooltip: 'Pengaturan Printer',
        ),
        IconButton(
          onPressed: () => _selectDate(context),
          icon: Icon(Icons.calendar_month_rounded,
              color:
                  _filterDate != null ? AppColors.primary : AppColors.textHint,
              size: 22),
          tooltip: 'Filter Tanggal',
        ),
        IconButton(
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AppSettingsScreen()));
          },
          icon: const Icon(Icons.settings_rounded,
              color: AppColors.textHint, size: 22),
          tooltip: 'Pengaturan Aplikasi',
        ),
        IconButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: Text('Logout', style: AppTextStyles.heading3),
                      content: Text('Yakin ingin keluar?',
                          style: AppTextStyles.body),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Batal',
                                style:
                                    TextStyle(color: AppColors.textSecondary))),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout',
                                style: TextStyle(color: AppColors.error))),
                      ],
                    ));
            if (confirm == true && mounted) {
              await auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            }
          },
          icon: const Icon(Icons.logout_rounded,
              color: AppColors.textHint, size: 22),
          tooltip: 'Keluar',
        ),
      ]);
    });
  }

  Widget _buildPeriodSelector() {
    if (_filterDate != null) return const SizedBox.shrink();
    
    return Consumer<OrderProvider>(builder: (context, orderProv, _) {
      return Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            _buildPeriodItem(
              'Harian', 
              ReportPeriod.daily, 
              orderProv.currentPeriod == ReportPeriod.daily,
              orderProv,
            ),
            _buildPeriodItem(
              'Mingguan', 
              ReportPeriod.weekly, 
              orderProv.currentPeriod == ReportPeriod.weekly,
              orderProv,
            ),
            _buildPeriodItem(
              'Bulanan', 
              ReportPeriod.monthly, 
              orderProv.currentPeriod == ReportPeriod.monthly,
              orderProv,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPeriodItem(String title, ReportPeriod period, bool isActive, OrderProvider orderProv) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          await orderProv.changePeriod(period);
          if (mounted) {
            final expenseProv = Provider.of<ExpenseProvider>(context, listen: false);
            await expenseProv.loadPeriodTotal(orderProv.currentStart, orderProv.currentEnd);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: isActive ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Center(
            child: Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Consumer3<OrderProvider, ExpenseProvider, StartingCashProvider>(
        builder: (context, orderProv, expenseProv, cashProv, _) {
      final stats =
          _filterDate != null ? (_filteredStats ?? {}) : orderProv.todayStats;
      
      final currentPeriod = _filterDate != null ? 'Filter' : (orderProv.currentPeriod == ReportPeriod.daily ? 'Hari Ini' : (orderProv.currentPeriod == ReportPeriod.weekly ? 'Minggu Ini' : 'Bulan Ini'));

      final grossRevenue = stats['totalRevenue'] ?? 0;
      final totalExpense =
          _filterDate != null ? _filteredExpense : expenseProv.periodTotal;
      
      final netRevenue = grossRevenue - totalExpense;
      final transactions = stats['totalTransactions'] ?? 0;
      final average = stats['averageTransaction'] ?? 0;
      final avgDaily = stats['averageDailyRevenue'] ?? 0;
      final showAvgDaily = _filterDate == null && orderProv.currentPeriod != ReportPeriod.daily;

      final modalAwal = cashProv.startingCash;

      final orders = stats['orders'] as List? ?? [];
      // Support for both Order objects and Map objects from Firestore (if mixed)
      final cashPayments = orders.fold(0, (sum, o) {
        if (o is Order) {
          return o.status == OrderStatus.completed && o.paymentMethod == 'Tunai' ? sum + o.total : sum;
        } else {
          final data = o as Map<String, dynamic>;
          return data['status'] == 'completed' && data['paymentMethod'] == 'Tunai' ? sum + (data['total'] as int) : sum;
        }
      });

      final qrisPayments = orders.fold(0, (sum, o) {
        if (o is Order) {
          return o.status == OrderStatus.completed && o.paymentMethod == 'QRIS' ? sum + o.total : sum;
        } else {
          final data = o as Map<String, dynamic>;
          return data['status'] == 'completed' && data['paymentMethod'] == 'QRIS' ? sum + (data['total'] as int) : sum;
        }
      });

      final grandTotalTunai = modalAwal + cashPayments - totalExpense;
      final walletCash = grandTotalTunai - 50000;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_filterDate != null ? 'Data Terfilter' : currentPeriod,
              style: AppTextStyles.heading3),
          if (_filterDate == null && orderProv.currentPeriod == ReportPeriod.daily)
            TextButton.icon(
              onPressed: () => _showStartingCashDialog(modalAwal),
              icon: const Icon(Icons.edit, size: 14, color: AppColors.primary),
              label: Text(modalAwal > 0 ? 'Edit Modal' : 'Input Modal',
                  style:
                      const TextStyle(color: AppColors.primary, fontSize: 12)),
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
              title: 'Total Tunai',
              value: AppFormatter.formatRupiah(cashPayments),
              icon: Icons.payments,
              iconColor: AppColors.info,
              subtitle: 'Penjualan Tunai',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: 'Total QRIS',
              value: AppFormatter.formatRupiah(qrisPayments),
              icon: Icons.qr_code_scanner,
              iconColor: AppColors.primary,
              subtitle: 'Uang Digital',
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: StatCard(
                  title: 'Pendapatan Kotor',
                  value: AppFormatter.formatRupiah(grossRevenue),
                  icon: Icons.account_balance_wallet,
                  iconColor: AppColors.success,
                  subtitle: 'Total Tunai + Total QRIS')),
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
            iconColor: AppColors.primary,
            subtitle: 'Pendapatan Kotor - Total Belanja'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: StatCard(
              title: 'GrandTotal Tunai',
              value: AppFormatter.formatRupiah(grandTotalTunai),
              icon: Icons.point_of_sale,
              iconColor: AppColors.success,
              subtitle: '(Modal + Total Tunai - Belanja)',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: 'Masuk Dompet',
              value: AppFormatter.formatRupiah(walletCash > 0 ? walletCash : 0),
              icon: Icons.account_balance,
              iconColor: AppColors.secondary,
              subtitle: 'Uang Sisa Laci 50rb',
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: StatCard(
                  title: 'Transaksi',
                  value: '$transactions',
                  icon: Icons.receipt_long,
                  iconColor: AppColors.info,
                  subtitle: 'Jumlah Pesanan')),
          const SizedBox(width: 12),
          Expanded(
              child: StatCard(
                  title: showAvgDaily ? 'Rata-rata Harian' : 'Rata-rata',
                  value: AppFormatter.formatRupiah(showAvgDaily ? avgDaily : average),
                  icon: Icons.trending_up,
                  iconColor: AppColors.secondary,
                  subtitle: showAvgDaily ? 'Rerata Penjualan per Hari' : 'Rerata per Transaksi')),
        ]),
        const SizedBox(height: 12),
        Consumer<MenuProvider>(builder: (context, menuProv, _) {
          // Calculate Detailed Botolan Stats
          int totalBotol = 0;
          int countAirMineral = 0;
          int countFruitea = 0;
          int countTehBotol = 0;
          int countTebs = 0;

          final botolanCatId = menuProv.categories
              .where((c) => c.name.toLowerCase().contains('botol'))
              .map((c) => c.id)
              .toList();
          final paketCatId = menuProv.categories
              .where((c) => c.name.toLowerCase().contains('paket'))
              .map((c) => c.id)
              .toList();

          for (final order in orders) {
            if (order.status != OrderStatus.completed) continue;
            for (final item in order.items) {
              final itemName = item.menuItemName.toLowerCase();
              final variant = item.variant?.toLowerCase() ?? '';
              int qty = item.quantity;

              bool isFromBotolanCat = item.categoryId != null &&
                  botolanCatId.contains(item.categoryId);
              bool isAirMineralPaket = item.categoryId != null &&
                  paketCatId.contains(item.categoryId) &&
                  variant.contains('air mineral');

              if (isFromBotolanCat || isAirMineralPaket) {
                totalBotol += qty;

                if (itemName.contains('air mineral') || isAirMineralPaket) {
                  countAirMineral += qty;
                } else if (itemName.contains('fruitea')) {
                  countFruitea += qty;
                } else if (itemName.contains('teh botol') ||
                    itemName.contains('sosro')) {
                  countTehBotol += qty;
                } else if (itemName.contains('tebs')) {
                  countTebs += qty;
                }
              }
            }
          }

          return StatCard(
            title: 'Rincian Minuman Botol',
            value: '$totalBotol Botol',
            icon: Icons.local_drink,
            iconColor: Colors.blueAccent,
            subtitle:
                'Air Mineral: $countAirMineral\nFruitea: $countFruitea\nTeh Botol: $countTehBotol\nTebs: $countTebs',
          );
        }),
      ]);
    });
  }

  Widget _buildDynamicChart() {
    return Consumer<OrderProvider>(builder: (context, orderProv, _) {
      final chartData = orderProv.weeklyRevenue;
      if (chartData.isEmpty) return const SizedBox.shrink();

      final maxRevenue = chartData
          .map((d) => (d['revenue'] as int).toDouble())
          .fold(0.0, (a, b) => a > b ? a : b);

      String title = 'Penjualan 7 Hari';
      if (orderProv.currentPeriod == ReportPeriod.monthly) {
        title = 'Penjualan Bulan Ini';
      }

      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.heading3),
          const SizedBox(height: 20),
          SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 100000,
                barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final data = chartData[groupIndex];
                    final date = data['date'] as DateTime;
                    return BarTooltipItem(
                        '${AppFormatter.formatDate(date)}\n${AppFormatter.formatRupiah(rod.toY.toInt())}',
                        AppTextStyles.caption.copyWith(color: Colors.white, fontSize: 10));
                  },
                )),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          interval: orderProv.currentPeriod == ReportPeriod.monthly ? 5 : 1,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= chartData.length)
                              return const SizedBox();
                            final date = chartData[i]['date'] as DateTime;
                            
                            String label;
                            if (orderProv.currentPeriod == ReportPeriod.monthly) {
                              label = '${date.day}';
                            } else {
                              final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                              label = days[date.weekday - 1];
                            }
                            
                            return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(label,
                                    style: AppTextStyles.caption
                                        .copyWith(fontSize: 10)));
                          })),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(chartData.length, (i) {
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                        toY: (chartData[i]['revenue'] as int).toDouble(),
                        width: orderProv.currentPeriod == ReportPeriod.monthly ? 6 : 20,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        gradient: AppColors.primaryGradient)
                  ]);
                }),
              ))),
        ]),
      );
    });
  }

  Widget _buildOrdersSection() {
    return Consumer<OrderProvider>(builder: (context, orderProv, _) {
      final orders = _filterDate != null
          ? (_filteredStats?['orders'] as List?)
                  ?.where((o) => o.status == OrderStatus.completed)
                  .toList() ??
              []
          : orderProv.todayOrders
              .where((o) => o.status == OrderStatus.completed)
              .toList();

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
              _filterDate != null
                  ? 'Transaksi Tanggal Tersebut'
                  : 'Transaksi Terakhir',
              style: AppTextStyles.heading3),
          Text('${orders.length} transaksi', style: AppTextStyles.caption),
        ]),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: AppColors.textHint.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text('Belum ada transaksi', style: AppTextStyles.bodySecondary),
            ]),
          )
        else
          ...orders.take(10).map((order) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.card.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border:
                        Border.all(color: AppColors.border.withOpacity(0.2))),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Icon(Icons.check_circle,
                          color: AppColors.success, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(order.orderNumber,
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                            'Meja ${order.tableNumber} • ${order.items.length} item',
                            style: AppTextStyles.caption),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(AppFormatter.formatRupiah(order.total),
                        style: AppTextStyles.priceSmall),
                    Text(AppFormatter.formatTime(order.createdAt),
                        style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  ]),
                ]),
              )),
      ]);
    });
  }

  Widget _buildBillingBanner() {
    return Consumer2<SubscriptionProvider, AuthProvider>(
      builder: (context, sub, auth, _) {
        // ★ ADMIN BANNER: Saat status blocked dan user adalah admin
        // Admin tetap bisa masuk app, tapi tampilkan banner info
        if (sub.status == SubscriptionStatus.blocked && auth.isAdmin) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Billing Belum Dibayar',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Sebagai Admin, Anda bisa mengupdate status pembayaran di Pengaturan → Kelola Billing.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.info, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AppSettingsScreen()));
                  },
                  child: const Text('KELOLA',
                      style: TextStyle(
                          color: AppColors.info, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        // Warning banner untuk user biasa saat jatuh tempo
        if (sub.status != SubscriptionStatus.warning) {
          return const SizedBox.shrink();
        }

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
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
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
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BillingScreen()));
                },
                child: const Text('BAYAR',
                    style: TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
