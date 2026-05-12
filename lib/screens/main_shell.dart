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
  }

  @override
  void dispose() {
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
