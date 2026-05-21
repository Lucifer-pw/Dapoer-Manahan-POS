import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/update_dialog.dart';
import '../services/update_service.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'billing_screen.dart';
import 'customer_order_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    // After splash animation and auth initialization, check if the URL is a table QR route.
    String currentPath = Uri.base.path;
    // For hash‑based URLs (fallback on some browsers), also consider the fragment.
    if ((currentPath == '/' || currentPath.isEmpty) && Uri.base.fragment.isNotEmpty) {
      // When using hash‑based URLs (e.g., http://example.com/#/table/1),
      // Uri.base.path will be '/' or empty and the fragment will contain the route.
      // Remove any leading slash from the fragment to avoid a double slash.
      final cleanedFragment = Uri.base.fragment.replaceFirst(RegExp(r'^/'), '');
      currentPath = '/$cleanedFragment';
    }
    // Normalize path: remove trailing slash if present.
    if (currentPath.endsWith('/') && currentPath.length > 1) {
      currentPath = currentPath.substring(0, currentPath.length - 1);
    }
    debugPrint('SplashScreen: currentPath = $currentPath');
    if (currentPath.startsWith('/table/')) {
      // Direct navigation to CustomerOrderScreen without login requirement
      final tableNumber = currentPath.replaceFirst('/table/', '');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CustomerOrderScreen(tableNumber: tableNumber),
          ),
        );
      });
      return;
    }
    // 1. Wait for splash animation (min 2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    // 2. Wait for Auth state to be checked (Persistent Login)
    int retryCount = 0;
    while (!authProvider.isAuthChecked && retryCount < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retryCount++;
    }

    // 3. Check Subscription
    await subProvider.checkStatus();

    if (!mounted) return;

    // 4. Check for app updates
    await _checkForUpdates();

    if (!mounted) return;

    // Double check if we are on a table route to prevent any automatic redirects to cashier dashboard/login
    String recheckedPath = Uri.base.path;
    if ((recheckedPath == '/' || recheckedPath.isEmpty) && Uri.base.fragment.isNotEmpty) {
      final cleanedFragment = Uri.base.fragment.replaceFirst(RegExp(r'^/'), '');
      recheckedPath = '/$cleanedFragment';
    }
    if (recheckedPath.endsWith('/') && recheckedPath.length > 1) {
      recheckedPath = recheckedPath.substring(0, recheckedPath.length - 1);
    }
    if (recheckedPath.startsWith('/table/')) {
      debugPrint('SplashScreen: Bypassing auth navigation because we are on a table route: $recheckedPath');
      return;
    }

    // 5. Handle Navigation logic
    if (subProvider.status == SubscriptionStatus.blocked) {
      // ★ ADMIN BYPASS: Admin tidak diblokir oleh billing screen
      // Admin harus bisa masuk ke app untuk update status pembayaran user
      if (authProvider.isLoggedIn && authProvider.isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BillingScreen()),
        );
      }
      return;
    }

    if (authProvider.isLoggedIn) {
      // User is already logged in from previous session!
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      // First time or logged out
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }

  }

  /// Mengecek apakah ada versi baru aplikasi
  Future<void> _checkForUpdates() async {
    try {
      debugPrint('🔍 Checking for updates...');
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdate();

      if (!mounted) return;

      if (updateInfo.hasUpdate) {
        debugPrint('🆕 Update detected! Showing dialog...');
        // Tampilkan dialog update dan TUNGGU sampai user merespons
        await _showUpdateDialog(updateInfo);
      } else {
        debugPrint('✅ No update needed.');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking updates: $e');
      // Fail silently, don't block app startup
    }
  }

  /// Menampilkan dialog notifikasi update
  Future<void> _showUpdateDialog(AppUpdateInfo updateInfo) async {
    if (!mounted) return;

    // Gunakan widget dialog standar yang mendukung auto-download & install
    await UpdateDialog.show(context, updateInfo);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      DefaultData.restaurantName,
                      style: AppTextStyles.heading1.copyWith(
                        fontSize: 32,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DefaultData.restaurantTagline,
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
