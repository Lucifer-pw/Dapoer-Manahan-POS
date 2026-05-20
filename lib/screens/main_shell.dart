import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/constants.dart';

import 'home_screen.dart';
import 'pos_screen.dart';
import 'table_screen.dart';
import 'menu_management_screen.dart';
import 'order_history_screen.dart';
import 'expense_screen.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/connectivity_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late PageController _pageController;

  final List<Widget> _screens = const [
    HomeScreen(),
    PosScreen(),
    TableScreen(),
    MenuManagementScreen(),
    ExpenseScreen(),
    OrderHistoryScreen(),
  ];

  bool? _lastPrinterState;
  bool? _lastConnectivityState;

  // ============================================================
  // INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();
    final navProv = Provider.of<NavigationProvider>(context, listen: false);
    _pageController = PageController(initialPage: navProv.currentIndex);
    
    // Sync PageController when index changes from outside
    navProv.addListener(() {
      if (_pageController.hasClients) {
        if (_pageController.page?.round() != navProv.currentIndex) {
          _pageController.animateToPage(
            navProv.currentIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    // Setup state listeners for printer & network connectivity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final printerProv = Provider.of<PrinterProvider>(context, listen: false);
      _lastPrinterState = printerProv.isConnected;
      printerProv.addListener(_onPrinterStateChanged);

      final connProv = Provider.of<ConnectivityProvider>(context, listen: false);
      _lastConnectivityState = connProv.isOnline;
      connProv.addListener(_onConnectivityChanged);
    });
  }

  void _onPrinterStateChanged() {
    if (!mounted) return;
    final printerProv = Provider.of<PrinterProvider>(context, listen: false);
    final isConnected = printerProv.isConnected;
    if (_lastPrinterState != isConnected) {
      _lastPrinterState = isConnected;
      _showPrinterNotification(isConnected);
    }
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    final connProv = Provider.of<ConnectivityProvider>(context, listen: false);
    final isOnline = connProv.isOnline;
    if (_lastConnectivityState != isOnline) {
      _lastConnectivityState = isOnline;
      _showNetworkNotification(isOnline);
    }
  }

  void _showPrinterNotification(bool isConnected) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isConnected ? const Color(0xFF00B4D8) : AppColors.primary,
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        content: Row(
          children: [
            Icon(
              isConnected ? Icons.print_rounded : Icons.print_disabled_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? 'Printer Terhubung' : 'Printer Terputus',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isConnected
                        ? 'Printer siap mencetak struk transaksi Anda.'
                        : 'Hubungkan printer kembali melalui menu Pengaturan.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showNetworkNotification(bool isOnline) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isOnline ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        content: Row(
          children: [
            Icon(
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'Koneksi Online' : 'Koneksi Terputus (Mode Lokal)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isOnline
                        ? 'Sistem berhasil terhubung kembali ke server cloud.'
                        : 'Aplikasi berjalan dalam mode offline. Data disimpan lokal.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    try {
      final printerProv = Provider.of<PrinterProvider>(context, listen: false);
      printerProv.removeListener(_onPrinterStateChanged);
    } catch (_) {}
    try {
      final connProv = Provider.of<ConnectivityProvider>(context, listen: false);
      connProv.removeListener(_onConnectivityChanged);
    } catch (_) {}
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProv, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              navProv.setIndex(index);
            },
            children: _screens,
          ),
          bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.border.withOpacity(0.2),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ============================================================
              // POWERED BY
              // ============================================================

              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.hasData 
                      ? ' | v${snapshot.data!.version}+${snapshot.data!.buildNumber}' 
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Powered by LUCIFAX$version',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint.withOpacity(0.3),
                        fontSize: 8,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),

              // ============================================================
              // NAVIGATION
              // ============================================================

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      0,
                      Icons.dashboard_rounded,
                      'Dashboard',
                      navProv,
                    ),
                    _buildNavItem(
                      1,
                      Icons.point_of_sale_rounded,
                      'Kasir',
                      navProv,
                    ),
                    _buildNavItem(
                      2,
                      Icons.table_restaurant_rounded,
                      'Meja',
                      navProv,
                    ),
                    _buildNavItem(
                      3,
                      Icons.restaurant_menu_rounded,
                      'Menu',
                      navProv,
                    ),
                    _buildNavItem(
                      4,
                      Icons.shopping_cart_rounded,
                      'Belanja',
                      navProv,
                    ),
                    _buildNavItem(
                      5,
                      Icons.receipt_long_rounded,
                      'Riwayat',
                      navProv,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ),
        );
      },
    );
  }

  // ============================================================
  // NAVIGATION ITEM
  // ============================================================

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    NavigationProvider navProv,
  ) {
    final isSelected = navProv.currentIndex == index;

    return GestureDetector(
      onTap: () {
        navProv.setIndex(index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            AppRadius.xl,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textHint,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
