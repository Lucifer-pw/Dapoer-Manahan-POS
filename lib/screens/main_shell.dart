import 'package:flutter/material.dart';

import '../utils/constants.dart';

import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

import 'home_screen.dart';
import 'pos_screen.dart';
import 'table_screen.dart';
import 'menu_management_screen.dart';
import 'order_history_screen.dart';
import 'expense_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

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

    _checkForUpdates();
  }

  // ============================================================
  // CHECK UPDATE APK
  // ============================================================

  Future<void> _checkForUpdates() async {
    try {
      debugPrint('🔍 Checking for app updates...');

      final updateInfo = await UpdateService().checkForUpdate();

      if (!mounted) return;

      if (updateInfo.hasUpdate) {
        debugPrint(
          '🆕 Update available: '
          '${updateInfo.currentVersion} '
          '→ '
          '${updateInfo.latestVersion}',
        );

        // Delay agar UI stabil dulu
        await Future.delayed(
          const Duration(seconds: 2),
        );

        if (!mounted) return;

        await UpdateDialog.show(
          context,
          updateInfo,
        );
      } else {
        debugPrint('✅ App already up to date');
      }
    } catch (e) {
      debugPrint(
        '⚠️ Error checking update: $e',
      );
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
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

              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Powered by LUCIFAX',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint.withOpacity(0.3),
                    fontSize: 8,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // ============================================================
              // NAVIGATION BAR
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
                    ),
                    _buildNavItem(
                      1,
                      Icons.point_of_sale_rounded,
                      'Kasir',
                    ),
                    _buildNavItem(
                      2,
                      Icons.table_restaurant_rounded,
                      'Meja',
                    ),
                    _buildNavItem(
                      3,
                      Icons.restaurant_menu_rounded,
                      'Menu',
                    ),
                    _buildNavItem(
                      4,
                      Icons.shopping_cart_rounded,
                      'Belanja',
                    ),
                    _buildNavItem(
                      5,
                      Icons.receipt_long_rounded,
                      'Riwayat',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION ITEM
  // ============================================================

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
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
