import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/starting_cash_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/feature_flags_provider.dart';
import '../widgets/pulsing_badge.dart';
import '../models/order.dart';
import '../utils/constants.dart';
import '../services/firestore_service.dart';
import '../utils/formatter.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';
import 'printer_settings_screen.dart';
import 'app_settings_screen.dart';
import 'billing_screen.dart';
import 'best_seller_screen.dart';
import 'salary_screen.dart';
import 'user_guide_screen.dart';
import 'cctv_screen.dart';
import '../widgets/shift_selection_dialog.dart';
import '../widgets/close_shift_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final expenseProv = Provider.of<ExpenseProvider>(context, listen: false);
    final cashProv = Provider.of<StartingCashProvider>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: orderProv.targetDate,
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

    if (picked != null && picked != orderProv.targetDate) {
      setState(() {
        _isSearching = true;
      });

      try {
        await orderProv.setTargetDate(picked);
        await expenseProv.loadPeriodTotal(orderProv.currentStart, orderProv.currentEnd);
        await cashProv.loadStartingCash(picked);

        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
      }
    }
  }

  void _clearFilter() async {
    setState(() {
      _isSearching = true;
    });

    try {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      final expenseProv = Provider.of<ExpenseProvider>(context, listen: false);
      final cashProv = Provider.of<StartingCashProvider>(context, listen: false);
      await orderProv.setTargetDate(DateTime.now());
      await expenseProv.loadPeriodTotal(orderProv.currentStart, orderProv.currentEnd);
      await cashProv.loadStartingCash(DateTime.now());

      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showStartingCashDialog(int currentAmount, DateTime targetDate) {
    final controller = TextEditingController(
        text: currentAmount > 0 ? currentAmount.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Modal Awal', style: AppTextStyles.heading3),
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
                final cashProv = Provider.of<StartingCashProvider>(context, listen: false);
                final navigator = Navigator.of(ctx);
                await cashProv.updateStartingCash(targetDate, amount);
                navigator.pop();
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
    final featureFlags = Provider.of<FeatureFlagsProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final role = authProv.role;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            final orderProv = Provider.of<OrderProvider>(context, listen: false);
            final startingCashProv = Provider.of<StartingCashProvider>(context, listen: false);
            final expenseProv = Provider.of<ExpenseProvider>(context, listen: false);
            final subProv = Provider.of<SubscriptionProvider>(context, listen: false);

            await orderProv.loadStats();
            await startingCashProv.loadStartingCash(orderProv.targetDate);
            await expenseProv.loadPeriodTotal(orderProv.currentStart, orderProv.currentEnd);
            await subProv.checkStatus();
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _buildBillingBanner(),
              _buildAppBar(),
              if (featureFlags.isFeatureEnabled(role, 'user_guide'))
                _buildUserGuideBanner(),
              if (featureFlags.isFeatureEnabled(role, 'online_users'))
                _buildOnlineUsersSection(),
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
              if (featureFlags.isFeatureEnabled(role, 'best_seller')) ...[
                _buildBestSellerBanner(),
                const SizedBox(height: 12),
              ],
              Consumer<AuthProvider>(builder: (context, auth, _) {
                if (!auth.isAdmin && !auth.isOwner) return const SizedBox.shrink();
                if (!featureFlags.isFeatureEnabled(role, 'salary')) return const SizedBox.shrink();
                return Column(children: [
                  _buildSalaryBanner(),
                  const SizedBox(height: 20),
                ]);
              }),
              if (featureFlags.isFeatureEnabled(role, 'sales_chart')) ...[
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
    return Consumer2<AuthProvider, OrderProvider>(builder: (context, auth, orderProv, _) {
      final isToday = orderProv.targetDate.year == DateTime.now().year &&
          orderProv.targetDate.month == DateTime.now().month &&
          orderProv.targetDate.day == DateTime.now().day;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Halo, ${auth.cashierName} 👋',
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    !isToday
                        ? 'Laporan: ${AppFormatter.formatDate(orderProv.targetDate)}'
                        : AppFormatter.formatDate(DateTime.now()),
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  if (auth.role == 'kasir' && auth.currentShift.isNotEmpty)
                    GestureDetector(
                      onTap: () => ShiftSelectionDialog.show(context, isDismissible: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: auth.currentShift.contains('1')
                              ? const Color(0xFFFFA726).withOpacity(0.18)
                              : const Color(0xFFAB47BC).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: auth.currentShift.contains('1')
                                ? const Color(0xFFFFA726)
                                : const Color(0xFFAB47BC),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              auth.currentShift.contains('1')
                                  ? Icons.wb_sunny_rounded
                                  : Icons.nightlight_round,
                              size: 10,
                              color: auth.currentShift.contains('1')
                                  ? const Color(0xFFFFA726)
                                  : const Color(0xFFCE93D8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              auth.currentShift,
                              style: AppTextStyles.caption.copyWith(
                                color: auth.currentShift.contains('1')
                                    ? const Color(0xFFFFA726)
                                    : const Color(0xFFCE93D8),
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!isToday)
                    GestureDetector(
                      onTap: _clearFilter,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.error,
                          size: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Consumer2<ConnectivityProvider, PrinterProvider>(
          builder: (context, connProv, printerProv, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PulsingStatusBadge(
                  isActive: connProv.isOnline,
                  activeLabel: 'Cloud Aktif',
                  inactiveLabel: 'Offline',
                  activeColor: const Color(0xFF4CAF50),
                  inactiveColor: const Color(0xFFEF5350),
                ),
                const SizedBox(height: 4),
                PulsingStatusBadge(
                  isActive: printerProv.isConnected,
                  activeLabel: 'Printer Siap',
                  inactiveLabel: 'Printer Offline',
                  activeColor: const Color(0xFF00B4D8),
                  inactiveColor: AppColors.primary,
                ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => _selectDate(context),
          icon: Icon(Icons.calendar_month_rounded,
              color:
                  !isToday ? AppColors.primary : AppColors.textHint,
              size: 22),
          tooltip: 'Filter Tanggal',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: AppColors.textHint, size: 22),
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1),
          ),
          onSelected: (value) async {
            if (value == 'printer') {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrinterSettingsScreen()));
            } else if (value == 'guide') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserGuideScreen(role: auth.role),
                ),
              );
            } else if (value == 'cctv') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CctvScreen()),
              );
            } else if (value == 'close_shift') {
              CloseShiftDialog.show(context);
            } else if (value == 'change_shift') {
              ShiftSelectionDialog.show(context, isDismissible: true);
            } else if (value == 'settings') {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppSettingsScreen()));
            } else if (value == 'logout') {
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
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'printer',
              child: Row(
                children: [
                  Icon(Icons.print_rounded, color: AppColors.textHint, size: 20),
                  const SizedBox(width: 12),
                  Text('Printer Settings', style: AppTextStyles.body),
                ],
              ),
            ),
            if ((auth.isAdmin || auth.isOwner) && Provider.of<FeatureFlagsProvider>(context, listen: false).isFeatureEnabled(auth.role, 'cctv'))
              PopupMenuItem<String>(
                value: 'cctv',
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('CCTV Monitor', style: AppTextStyles.body),
                  ],
                ),
              ),
            if (!auth.isAdmin && Provider.of<FeatureFlagsProvider>(context, listen: false).isFeatureEnabled(auth.role, 'user_guide'))
              PopupMenuItem<String>(
                value: 'guide',
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Panduan', style: AppTextStyles.body),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_rounded, color: AppColors.textHint, size: 20),
                  const SizedBox(width: 12),
                  Text('Pengaturan', style: AppTextStyles.body),
                ],
              ),
            ),
            if (auth.role == 'kasir') ...[
              PopupMenuItem<String>(
                value: 'change_shift',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(auth.currentShift.isNotEmpty ? 'Ganti Shift (${auth.currentShift})' : 'Pilih Shift', style: AppTextStyles.body),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'close_shift',
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Text('Tutup Shift & Rekap Kas', style: AppTextStyles.body.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ]);
    });
  }

  Widget _buildPeriodSelector() {
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
      final stats = orderProv.todayStats;
      
      final isToday = orderProv.targetDate.year == DateTime.now().year &&
          orderProv.targetDate.month == DateTime.now().month &&
          orderProv.targetDate.day == DateTime.now().day;

      String currentPeriod = '';
      if (orderProv.currentPeriod == ReportPeriod.daily) {
        currentPeriod = isToday ? 'Hari Ini' : 'Harian (${AppFormatter.formatDate(orderProv.targetDate)})';
      } else if (orderProv.currentPeriod == ReportPeriod.weekly) {
        currentPeriod = isToday ? 'Minggu Ini' : 'Mingguan (7 Hari)';
      } else {
        final monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
        currentPeriod = isToday ? 'Bulan Ini' : 'Bulan ${monthNames[orderProv.targetDate.month - 1]} ${orderProv.targetDate.year}';
      }

      final grossRevenue = stats['totalRevenue'] ?? 0;
      final isDailyToday = orderProv.currentPeriod == ReportPeriod.daily && isToday;
      final totalExpense = isDailyToday ? expenseProv.dailyTotal : expenseProv.periodTotal;
      
      final netRevenue = grossRevenue - totalExpense;
      final transactions = stats['totalTransactions'] ?? 0;
      final average = stats['averageTransaction'] ?? 0;
      final avgDaily = stats['averageDailyRevenue'] ?? 0;
      final showAvgDaily = orderProv.currentPeriod != ReportPeriod.daily;

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

      final totalExpenseCash = isDailyToday
          ? expenseProv.todayExpenses.where((e) => e.paymentMethod == 'Cash').fold(0, (sum, e) => sum + e.price)
          : expenseProv.periodTotalCash;

      final grandTotalTunai = modalAwal + cashPayments - totalExpenseCash;
      final walletCash = grandTotalTunai - 50000;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(currentPeriod, style: AppTextStyles.heading3),
          if (orderProv.currentPeriod == ReportPeriod.daily)
            TextButton.icon(
              onPressed: () => _showStartingCashDialog(modalAwal, orderProv.targetDate),
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
                  onTap: () {
                    if (!isToday) {
                      Provider.of<ExpenseProvider>(context, listen: false).setFilterDate(orderProv.targetDate);
                    } else {
                      Provider.of<ExpenseProvider>(context, listen: false).setFilterDate(null);
                    }
                    Provider.of<NavigationProvider>(context, listen: false).setIndex(4);
                  },
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
              subtitle: '(Modal + Total Tunai - Belanja Cash)',
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
              bool isBotolPaket = item.categoryId != null &&
                  paketCatId.contains(item.categoryId) &&
                  (variant.contains('air mineral') ||
                      variant.contains('teh botol') ||
                      variant.contains('fruitea') ||
                      variant.contains('fruit tea') ||
                      variant.contains('tebs'));

              if (isFromBotolanCat || isBotolPaket) {
                totalBotol += qty;

                if (itemName.contains('air mineral') ||
                    variant.contains('air mineral')) {
                  countAirMineral += qty;
                } else if (itemName.contains('fruitea') ||
                    variant.contains('fruitea') ||
                    variant.contains('fruit tea')) {
                  countFruitea += qty;
                } else if (itemName.contains('teh botol') ||
                    itemName.contains('sosro') ||
                    variant.contains('teh botol')) {
                  countTehBotol += qty;
                } else if (itemName.contains('tebs') ||
                    variant.contains('tebs')) {
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
      if (orderProv.currentPeriod == ReportPeriod.daily) return const SizedBox.shrink();
      final chartData = orderProv.weeklyRevenue;
      if (chartData.isEmpty) return const SizedBox.shrink();

      final maxRevenue = chartData
          .map((d) => (d['revenue'] as int).toDouble())
          .fold(0.0, (a, b) => a > b ? a : b);

      String title = 'Penjualan 7 Hari';
      if (orderProv.currentPeriod == ReportPeriod.monthly) {
        final monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
        title = 'Penjualan Bulan ${monthNames[orderProv.targetDate.month - 1]} ${orderProv.targetDate.year}';
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
                             if (i < 0 || i >= chartData.length) {
                               return const SizedBox();
                             }
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
      final isToday = orderProv.targetDate.year == DateTime.now().year &&
          orderProv.targetDate.month == DateTime.now().month &&
          orderProv.targetDate.day == DateTime.now().day;
      final isDailyToday = orderProv.currentPeriod == ReportPeriod.daily && isToday;

      final rawOrders = isDailyToday ? orderProv.todayOrders : (orderProv.todayStats['orders'] as List? ?? []);
      final orders = rawOrders.where((o) {
        if (o is Order) return o.status == OrderStatus.completed;
        return false;
      }).map((o) => o as Order).toList();

      String title = 'Transaksi Terakhir';
      if (!isDailyToday) {
        if (orderProv.currentPeriod == ReportPeriod.daily) {
          title = 'Transaksi (${AppFormatter.formatDate(orderProv.targetDate)})';
        } else if (orderProv.currentPeriod == ReportPeriod.weekly) {
          title = 'Transaksi (Mingguan)';
        } else {
          title = 'Transaksi (Bulanan)';
        }
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: AppTextStyles.heading3),
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
                        Row(
                          children: [
                            Text(order.orderNumber,
                                style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: order.paymentMethod == 'QRIS' ? AppColors.info.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                order.paymentMethod == 'Tunai' ? 'Cash' : order.paymentMethod,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: order.paymentMethod == 'QRIS' ? AppColors.info : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
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

  Widget _buildBestSellerBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BestSellerScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.15),
              const Color(0xFFFFB347).withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Best Seller 🔥',
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lihat menu paling laku bulan ini',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalaryScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF42A5F5).withOpacity(0.15),
              const Color(0xFF66BB6A).withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.info.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.info.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gaji Karyawan 💰',
                    style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('Kelola gaji & cek hari kerja kasir',
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.info, size: 16),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildUserGuideBanner() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAdmin) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.08),
                AppColors.secondary.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserGuideScreen(role: auth.role),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Butuh Bantuan? Pelajari Panduan',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tata cara dan alur operasional lengkap untuk role ${auth.role.toUpperCase()}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.primary.withOpacity(0.8),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnlineUsersSection() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAdmin && !auth.isOwner) return const SizedBox.shrink();

        final FirestoreService firestoreService = FirestoreService();

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: firestoreService.streamUsers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final users = snapshot.data!;
            if (users.isEmpty) return const SizedBox.shrink();

            final now = DateTime.now();
            
            // Helper to check if a user is online
            bool checkIsOnline(Map<String, dynamic> u) {
              final bool isOnlineField = u['isOnline'] as bool? ?? false;
              final dynamic lastActiveField = u['lastActive'];
              
              if (!isOnlineField) return false;
              if (lastActiveField == null) return false;

              DateTime lastActive;
              if (lastActiveField is Timestamp) {
                lastActive = lastActiveField.toDate();
              } else if (lastActiveField is DateTime) {
                lastActive = lastActiveField;
              } else {
                return isOnlineField;
              }

              // Fallback: if last active was more than 5 minutes ago, consider offline
              return now.difference(lastActive).inMinutes <= 5;
            }

            // Helper to format last seen text
            String formatLastSeen(Map<String, dynamic> u, bool isOnline) {
              if (isOnline) return 'Online';

              final dynamic lastActiveField = u['lastActive'] ?? u['lastLogin'] ?? u['createdAt'];
              if (lastActiveField == null) return 'Offline';

              DateTime lastActive;
              if (lastActiveField is Timestamp) {
                lastActive = lastActiveField.toDate();
              } else if (lastActiveField is DateTime) {
                lastActive = lastActiveField;
              } else {
                return 'Offline';
              }

              final diff = now.difference(lastActive);
              if (diff.inMinutes < 1) {
                return 'Baru saja';
              } else if (diff.inMinutes < 60) {
                return '${diff.inMinutes}m lalu';
              } else if (diff.inHours < 24) {
                return '${diff.inHours}j lalu';
              } else if (diff.inDays == 1) {
                return 'Kemarin';
              } else if (diff.inDays < 7) {
                return '${diff.inDays}h lalu';
              } else {
                return '${lastActive.day}/${lastActive.month}';
              }
            }

            // Helper for detailed tooltip
            String getFullLastSeenText(Map<String, dynamic> u, bool isOnline) {
              final String name = u['name'] ?? 'Staff';
              final String role = (u['role'] ?? 'kasir').toString().toUpperCase();
              final String currentShift = u['currentShift'] as String? ?? '';
              final dynamic shiftStartField = u['shiftStartedAt'];
              
              String shiftTimeInfo = '';
              if (shiftStartField != null) {
                DateTime? sTime;
                if (shiftStartField is Timestamp) sTime = shiftStartField.toDate();
                if (shiftStartField is DateTime) sTime = shiftStartField;
                if (sTime != null) {
                  final h = sTime.hour.toString().padLeft(2, '0');
                  final m = sTime.minute.toString().padLeft(2, '0');
                  shiftTimeInfo = ' • Masuk: $h:$m WIB';
                }
              }

              if (isOnline) {
                if (currentShift.isNotEmpty) {
                  final isPagi = currentShift.toLowerCase().contains('pagi') || currentShift.contains('1');
                  return '$name ($role)\n${isPagi ? "☀️" : "🌙"} $currentShift\n🟢 Sedang Bertugas$shiftTimeInfo';
                }
                return '$name ($role)\n🟢 Sedang Online';
              }

              final dynamic lastActiveField = u['lastActive'] ?? u['lastLogin'];
              if (lastActiveField == null) return '$name ($role)\n⚪ Status: Offline';

              DateTime lastActive;
              if (lastActiveField is Timestamp) {
                lastActive = lastActiveField.toDate();
              } else if (lastActiveField is DateTime) {
                lastActive = lastActiveField;
              } else {
                return '$name ($role)\n⚪ Status: Offline';
              }

              final hour = lastActive.hour.toString().padLeft(2, '0');
              final minute = lastActive.minute.toString().padLeft(2, '0');
              return '$name ($role)\n⚪ Terakhir aktif: ${lastActive.day}/${lastActive.month}/${lastActive.year} $hour:$minute';
            }

            final onlineUsers = users.where((u) => checkIsOnline(u)).toList();
            final offlineUsers = users.where((u) => !checkIsOnline(u)).toList();

            // Combine them so online shows first
            final sortedUsers = [...onlineUsers, ...offlineUsers];

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Status Karyawan',
                            style: AppTextStyles.heading3.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${onlineUsers.length} Aktif',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sortedUsers.length,
                      itemBuilder: (context, index) {
                        final u = sortedUsers[index];
                        final String name = u['name'] ?? 'Staff';
                        final bool isOnline = checkIsOnline(u);
                        final String lastSeen = formatLastSeen(u, isOnline);
                        final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
                        final String tooltipText = getFullLastSeenText(u, isOnline);
                        
                        return Tooltip(
                          message: tooltipText,
                          preferBelow: false,
                          child: Container(
                            width: 62,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        gradient: isOnline 
                                            ? AppColors.primaryGradient 
                                            : LinearGradient(colors: [AppColors.card, AppColors.border.withOpacity(0.3)]),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: isOnline ? AppColors.success : AppColors.textHint,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.background, width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: isOnline ? Colors.white : AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: isOnline ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOnline && (u['currentShift'] as String? ?? '').isNotEmpty
                                      ? ((u['currentShift'] as String).toLowerCase().contains('pagi') || (u['currentShift'] as String).contains('1') ? '☀️ Shift 1' : '🌙 Shift 2')
                                      : lastSeen,
                                  style: TextStyle(
                                    color: isOnline ? AppColors.success : AppColors.textHint.withOpacity(0.85),
                                    fontSize: 8.5,
                                    fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
