import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feature_flags_provider.dart';
import '../utils/constants.dart';

class FeatureManagementScreen extends StatefulWidget {
  const FeatureManagementScreen({super.key});

  @override
  State<FeatureManagementScreen> createState() => _FeatureManagementScreenState();
}

class _FeatureManagementScreenState extends State<FeatureManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // List of all features to manage
  final List<FeatureItem> _features = [
    FeatureItem(
      id: 'dashboard',
      title: 'Dashboard',
      description: 'Berisi ringkasan pendapatan, pesanan, dan analytics toko.',
      icon: Icons.dashboard_rounded,
      color: const Color(0xFF42A5F5),
    ),
    FeatureItem(
      id: 'pos',
      title: 'Kasir (POS)',
      description: 'Fitur utama untuk melayani pesanan, pembayaran, dan cetak struk.',
      icon: Icons.shopping_cart_rounded,
      color: const Color(0xFFFF6B35),
    ),
    FeatureItem(
      id: 'table',
      title: 'Manajemen Meja',
      description: 'Kelola tata letak meja, pesanan aktif per meja, dan status ketersediaan.',
      icon: Icons.table_restaurant_rounded,
      color: const Color(0xFF66BB6A),
    ),
    FeatureItem(
      id: 'menu',
      title: 'Manajemen Menu',
      description: 'Tambah, edit, hapus, dan atur ketersediaan menu makanan/minuman.',
      icon: Icons.restaurant_menu_rounded,
      color: const Color(0xFFEC407A),
    ),
    FeatureItem(
      id: 'expense',
      title: 'Belanja (Pengeluaran)',
      description: 'Pencatatan pengeluaran harian dan modal belanja dapur.',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFFAB47BC),
    ),
    FeatureItem(
      id: 'order_history',
      title: 'Riwayat Pesanan',
      description: 'Melihat semua transaksi pesanan yang telah selesai atau batal.',
      icon: Icons.history_rounded,
      color: const Color(0xFF26A69A),
    ),
    FeatureItem(
      id: 'cctv',
      title: 'CCTV Monitor',
      description: 'Monitor live feed CCTV restoran langsung dari aplikasi.',
      icon: Icons.videocam_rounded,
      color: const Color(0xFFFFB300),
    ),
    FeatureItem(
      id: 'best_seller',
      title: 'Best Seller',
      description: 'Menampilkan menu paling populer dan paling laris terjual.',
      icon: Icons.auto_awesome_rounded,
      color: const Color(0xFFFF7043),
    ),
    FeatureItem(
      id: 'salary',
      title: 'Gaji Karyawan',
      description: 'Sistem slip gaji, bonus, dan pencatatan kasbon karyawan.',
      icon: Icons.payments_rounded,
      color: const Color(0xFF26C6DA),
    ),
    FeatureItem(
      id: 'user_guide',
      title: 'Panduan Pengguna',
      description: 'Dokumentasi dan petunjuk penggunaan aplikasi lengkap.',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF78909C),
    ),
    FeatureItem(
      id: 'online_users',
      title: 'Status Karyawan Online',
      description: 'Melihat siapa saja karyawan yang sedang aktif membuka aplikasi.',
      icon: Icons.people_outline_rounded,
      color: const Color(0xFF5C6BC0),
    ),
    FeatureItem(
      id: 'sales_chart',
      title: 'Grafik Penjualan',
      description: 'Visualisasi performa penjualan mingguan/bulanan.',
      icon: Icons.bar_chart_rounded,
      color: const Color(0xFF8D6E63),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final featureProvider = Provider.of<FeatureFlagsProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kontrol Akses Fitur'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: AppTextStyles.bodySecondary,
          tabs: const [
            Tab(text: 'Role Owner'),
            Tab(text: 'Role Kasir'),
          ],
        ),
      ),
      body: featureProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFeatureList('owner', featureProvider),
                _buildFeatureList('kasir', featureProvider),
              ],
            ),
    );
  }

  Widget _buildFeatureList(String role, FeatureFlagsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.05), AppColors.secondary.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kontrol Real-time',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Perubahan akses fitur untuk role ${role.toUpperCase()} akan langsung diterapkan secara langsung di perangkat mereka.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Features Toggles
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _features.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _features[index];
              final isEnabled = provider.isFeatureEnabled(role, item.id);

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isEnabled
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.border.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // Icon with styled colored circle background
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTextStyles.subtitle.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isEnabled ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textHint,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: isEnabled,
                        activeColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withOpacity(0.3),
                        onChanged: (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await provider.updateFeature(role, item.id, value);
                            if (mounted) {
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Fitur "${item.title}" untuk ${role.toUpperCase()} berhasil di-${value ? "ON" : "OFF"}-kan',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: value ? AppColors.success : AppColors.error,
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Gagal memperbarui fitur: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class FeatureItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  FeatureItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
