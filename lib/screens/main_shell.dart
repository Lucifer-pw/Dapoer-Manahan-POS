import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';

import '../utils/constants.dart';
import '../utils/formatter.dart';
import '../services/firestore_service.dart';
import '../providers/table_provider.dart';
import '../providers/auth_provider.dart';

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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
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

  // Draggable notification fields
  Offset _notificationPosition = const Offset(20, 100);
  bool _isPositionInitialized = false;
  
  late final FirestoreService _firestoreService;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingOrdersSubscription;
  final Set<String> _notifiedOrderIds = {};
  bool _isFirstSnapshot = true;
  Map<String, dynamic>? _activeAlertOrder;

  // ============================================================
  // INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    _firestoreService = FirestoreService();
    _startListeningToPendingOrders();
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
    WidgetsBinding.instance.removeObserver(this);
    try {
      final printerProv = Provider.of<PrinterProvider>(context, listen: false);
      printerProv.removeListener(_onPrinterStateChanged);
    } catch (_) {}
    try {
      final connProv = Provider.of<ConnectivityProvider>(context, listen: false);
      connProv.removeListener(_onConnectivityChanged);
    } catch (_) {}
    _pendingOrdersSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.isLoggedIn) {
      if (state == AppLifecycleState.resumed) {
        authProv.updateOnlineStatus(true);
      } else if (state == AppLifecycleState.paused || 
                 state == AppLifecycleState.detached) {
        authProv.updateOnlineStatus(false);
      }
    }
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
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  navProv.setIndex(index);
                },
                children: _screens,
              ),
              _buildFloatingNotification(context, navProv),
            ],
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

  void _startListeningToPendingOrders() {
    _pendingOrdersSubscription = _firestoreService.streamPendingQrOrders().listen((orders) {
      if (_isFirstSnapshot) {
        for (var o in orders) {
          final id = o['id'] as String?;
          if (id != null) {
            _notifiedOrderIds.add(id);
          }
        }
        _isFirstSnapshot = false;
        return;
      }

      for (var o in orders) {
        final id = o['id'] as String?;
        if (id != null && !_notifiedOrderIds.contains(id)) {
          _notifiedOrderIds.add(id);
          
          setState(() {
            _activeAlertOrder = o;
          });
        }
      }
    });
  }

  Widget _buildFloatingNotification(BuildContext context, NavigationProvider navProv) {
    if (_activeAlertOrder == null) return const SizedBox.shrink();

    final order = _activeAlertOrder!;
    final tableNumberStr = order['tableNumber']?.toString() ?? '';
    final int? tableNumber = int.tryParse(tableNumberStr);
    final totalPrice = order['totalPrice'] as int? ?? 0;
    final List<dynamic> items = order['items'] as List<dynamic>? ?? [];

    final size = MediaQuery.of(context).size;
    
    if (!_isPositionInitialized) {
      _notificationPosition = Offset(size.width - 320.0, 100.0);
      _isPositionInitialized = true;
    }

    return Positioned(
      left: _notificationPosition.dx,
      top: _notificationPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final double newX = (_notificationPosition.dx + details.delta.dx).clamp(10.0, size.width - 310.0);
          final double newY = (_notificationPosition.dy + details.delta.dy).clamp(80.0, size.height - 240.0);
          setState(() {
            _notificationPosition = Offset(newX, newY);
          });
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surface.withOpacity(0.95),
                  AppColors.surfaceDark.withOpacity(0.98),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.primary, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pesanan Baru!',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Meja $tableNumberStr • ${AppFormatter.formatRupiah(totalPrice)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textHint, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _activeAlertOrder = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 8),
                ...items.take(2).map((item) {
                  final name = item['name'] ?? '';
                  final qty = item['quantity'] ?? 1;
                  final variant = item['variant'] as String?;
                  final hasVariant = variant != null && variant.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name ${hasVariant ? "($variant)" : ""}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'x$qty',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
                if (items.length > 2)
                  Text(
                    '+ ${items.length - 2} item lainnya...',
                    style: TextStyle(color: AppColors.textHint, fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        side: BorderSide(color: AppColors.textHint.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed: () {
                        setState(() {
                          _activeAlertOrder = null;
                        });
                      },
                      child: Text(
                        'Tutup',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed: () {
                        if (tableNumber != null) {
                          final tableProv = Provider.of<TableProvider>(context, listen: false);
                          tableProv.pendingHighlightTableNumber = tableNumber;
                          navProv.setIndex(2);
                        }
                        setState(() {
                          _activeAlertOrder = null;
                        });
                      },
                      child: const Text(
                        'Kelola',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
