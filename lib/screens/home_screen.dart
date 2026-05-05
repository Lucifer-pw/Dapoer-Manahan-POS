import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/subscription_provider.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).loadStats();
    });
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
            await Provider.of<OrderProvider>(context, listen: false).loadStats();
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
              _buildStatsSection(),
              const SizedBox(height: 20),
              _buildWeeklyChart(),
              const SizedBox(height: 20),
              _buildTodayOrders(),
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
          Text(AppFormatter.formatDate(DateTime.now()), style: AppTextStyles.caption),
        ])),
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
    return Consumer<OrderProvider>(builder: (context, orderProv, _) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hari Ini', style: AppTextStyles.heading3),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: StatCard(title: 'Total Pendapatan', value: AppFormatter.formatRupiah(orderProv.todayRevenue), icon: Icons.account_balance_wallet, iconColor: AppColors.success)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(title: 'Transaksi', value: '${orderProv.todayTransactions}', icon: Icons.receipt_long, iconColor: AppColors.info)),
        ]),
        const SizedBox(height: 12),
        StatCard(title: 'Rata-rata per Transaksi', value: AppFormatter.formatRupiah(orderProv.averageTransaction), icon: Icons.trending_up, iconColor: AppColors.secondary),
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

  Widget _buildTodayOrders() {
    return Consumer<OrderProvider>(builder: (context, orderProv, _) {
      final orders = orderProv.todayOrders.where((o) => o.status.name == 'completed').toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Transaksi Terakhir', style: AppTextStyles.heading3),
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
              Text('Belum ada transaksi hari ini', style: AppTextStyles.bodySecondary),
            ]),
          )
        else
          ...orders.take(5).map((order) => Container(
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
