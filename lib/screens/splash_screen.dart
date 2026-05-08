import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/update_service.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'billing_screen.dart';

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
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdate();

      if (!mounted) return;

      if (updateInfo.hasUpdate) {
        // Tampilkan dialog update
        await _showUpdateDialog(updateInfo);
      }
    } catch (e) {
      debugPrint('Error checking updates: $e');
      // Fail silently, don't block app startup
    }
  }

  /// Menampilkan dialog notifikasi update
  Future<void> _showUpdateDialog(AppUpdateInfo updateInfo) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !updateInfo.forceUpdate,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Update icon with animation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.info,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Tersedia! 🎉',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'v${updateInfo.currentVersion} → v${updateInfo.latestVersion}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (updateInfo.message != null && updateInfo.message!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    updateInfo.message!,
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (updateInfo.forceUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Update wajib dilakukan',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!updateInfo.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'NANTI',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            if (updateInfo.downloadUrl != null &&
                updateInfo.downloadUrl!.isNotEmpty)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await launchUrl(
                        Uri.parse(updateInfo.downloadUrl!),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Gagal membuka link: $e')),
                        );
                      }
                    }
                    if (!updateInfo.forceUpdate && ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('UPDATE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              )
            else if (!updateInfo.forceUpdate)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text('OK'),
              ),
          ],
        ),
      ),
    );
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
