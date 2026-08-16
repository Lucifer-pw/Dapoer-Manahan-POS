import 'package:flutter/material.dart';
import '../utils/constants.dart';

class UserGuideScreen extends StatefulWidget {
  final String role; // 'kasir' or 'owner'

  const UserGuideScreen({super.key, required this.role});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Default to owner tab if the user is owner, else cashier tab
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.role == 'owner' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Panduan Penggunaan',
          style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surface,
            child: Container(
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.glow,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.point_of_sale_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Panduan Kasir'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Panduan Owner'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCashierGuide(),
          _buildOwnerGuide(),
        ],
      ),
    );
  }

  // ============================================================
  // CASHIER GUIDE TAB
  // ============================================================

  Widget _buildCashierGuide() {
    final List<Map<String, dynamic>> steps = [
      {
        'title': 'Isi Modal Awal (Shift Baru)',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF4CAF50),
        'desc': 'Setiap kali memulai shift kerja baru, Kasir wajib menginput modal awal kas di dashboard utama.',
        'details': [
          'Ketuk tombol "Isi Modal Awal" di Dashboard.',
          'Masukkan jumlah uang tunai fisik yang ada di laci kasir saat itu.',
          'Ini penting agar laporan uang masuk dan kembalian tercatat dengan akurat.',
        ]
      },
      {
        'title': 'Melakukan Penjualan (POS)',
        'icon': Icons.shopping_basket_rounded,
        'color': AppColors.primary,
        'desc': 'Melayani pemesanan pelanggan dengan cepat menggunakan sistem POS yang responsif.',
        'details': [
          'Pilih menu "Kasir" di navigasi bawah.',
          'Ketuk menu makanan/minuman untuk menambahkannya ke keranjang.',
          'Ketuk item di keranjang untuk mengubah jumlah porsi atau memberikan catatan khusus (misal: "tidak pedas", "es dipisah").',
        ]
      },
      {
        'title': 'Pemilihan Meja (Dine-in)',
        'icon': Icons.table_bar_rounded,
        'color': const Color(0xFF2196F3),
        'desc': 'Menghubungkan pesanan ke nomor meja makan pelanggan.',
        'details': [
          'Tekan tombol "Pilih Meja" di bagian bawah keranjang belanja.',
          'Pilih meja makan yang kosong. Status meja otomatis akan berubah menjadi "terisi" setelah pesanan diproses.',
          'Anda juga dapat memesankan meja lewat menu "Meja" di navigasi bawah.',
        ]
      },
      {
        'title': 'Proses Pembayaran & Transaksi',
        'icon': Icons.payment_rounded,
        'color': const Color(0xFFFFB347),
        'desc': 'Menerima pembayaran baik cash (tunai) maupun digital secara instan.',
        'details': [
          'Tekan tombol "Bayar" di keranjang belanja.',
          'Pilih metode pembayaran: Tunai (Cash) atau QRIS/Transfer Digital.',
          'Untuk pembayaran Tunai, gunakan tombol nominal cepat untuk menghitung uang kembalian secara presisi.',
        ]
      },
      {
        'title': 'Sambung & Cetak Struk Printer',
        'icon': Icons.print_rounded,
        'color': const Color(0xFF9C27B0),
        'desc': 'Mencetak bukti transaksi menggunakan printer thermal Bluetooth.',
        'details': [
          'Nyalakan printer thermal dan pasang kertas struk 58mm/80mm.',
          'Buka menu Bluetooth di pengaturan HP/Tablet Anda, lakukan Pairing (Sandingkan) dengan printer (PIN standar: 0000 atau 1234).',
          'Buka aplikasi POS, ketuk ikon "Printer" di pojok kanan atas Dashboard untuk masuk ke Pengaturan Printer.',
          'Cari nama printer Anda (misal: RPP02N, PT-210, PMA 9320) pada daftar perangkat, lalu tekan tombol "Hubung".',
          'Tekan tombol "Tes Cetak Struk" untuk memastikan printer berfungsi dengan baik.',
        ]
      },
      {
        'title': 'Pencatatan Belanja Toko',
        'icon': Icons.shopping_cart_rounded,
        'color': const Color(0xFFE91E63),
        'desc': 'Mencatat pengeluaran operasional kedai yang dikeluarkan langsung dari laci kasir.',
        'details': [
          'Pilih menu "Belanja" di navigasi bawah.',
          'Tekan ikon tambah (+) untuk memasukkan belanjaan baru (misal: membeli es batu, gas elpiji, kemasan plastik).',
          'Masukkan nominal dan deskripsi dengan detail agar laporan keuangan akhir Owner tetap seimbang.',
        ]
      },
      {
        'title': 'Lengkapi Profil & Rekening Gaji',
        'icon': Icons.manage_accounts_rounded,
        'color': const Color(0xFF00BCD4),
        'desc': 'Melengkapi identitas diri agar proses penerimaan gaji bulanan terverifikasi otomatis.',
        'details': [
          'Buka "Pengaturan Aplikasi" (ikon roda gerigi di pojok kanan atas Dashboard).',
          'Masukkan detail bank Anda pada kolom Rekening Bank.',
          'PENTING: Masukkan nama asli pemilik rekening Anda pada kolom "Nama Pemilik Rekening (Nama Asli/BCA)". Ini digunakan untuk mendeteksi kecocokan transfer gaji oleh sistem Owner.',
        ]
      },
    ];

    return _buildTimelineList(steps);
  }

  // ============================================================
  // OWNER GUIDE TAB
  // ============================================================

  Widget _buildOwnerGuide() {
    final List<Map<String, dynamic>> steps = [
      {
        'title': 'Pemantauan Keuangan Real-Time',
        'icon': Icons.insights_rounded,
        'color': const Color(0xFF4CAF50),
        'desc': 'Melihat arus kas, omset harian, pengeluaran, dan grafik keuntungan secara instan.',
        'details': [
          'Gunakan Dashboard Utama untuk memantau ringkasan finansial kedai.',
          'Ubah filter periode tanggal menggunakan tombol Kalender di bagian atas untuk melihat riwayat hari sebelumnya.',
          'Tinjau total laba bersih setelah dikurangi modal kas awal dan operasional belanja kasir.',
        ]
      },
      {
        'title': 'Analisis Menu Terlaris (Best Seller)',
        'icon': Icons.star_rounded,
        'color': const Color(0xFFFFC107),
        'desc': 'Mengetahui menu makanan atau minuman yang paling disukai oleh pelanggan kedai.',
        'details': [
          'Tekan banner berwarna "Menu Terlaris" di Dashboard.',
          'Lihat grafik dan daftar menu dengan penjualan tertinggi untuk membantu menyusun strategi stok bahan baku.',
        ]
      },
      {
        'title': 'Kelola Menu & Ketersediaan Produk',
        'icon': Icons.restaurant_menu_rounded,
        'color': AppColors.primary,
        'desc': 'Menambahkan menu baru, mengatur kategori, harga, dan ketersediaan stok.',
        'details': [
          'Masuk ke menu "Menu" di navigasi bawah.',
          'Kelola kategori menu (misal: Makanan Utama, Kopi, Camilan) melalui Kelola Kategori.',
          'Tambah menu baru dengan gambar pendukung, tentukan harga jual, dan matikan opsi "Tersedia" jika bahan baku habis.',
        ]
      },
      {
        'title': 'Pembayaran Gaji Kasir (Anti-Fraud OCR)',
        'icon': Icons.monetization_on_rounded,
        'color': const Color(0xFF00BCD4),
        'desc': 'Proses pembayaran gaji bulanan kasir dengan perlindungan verifikasi struk transfer otomatis.',
        'details': [
          'Tekan tombol "Gaji Kasir" di Dashboard (hanya muncul untuk role Owner).',
          'Pilih nama kasir yang ingin digaji. Sistem akan menampilkan detail rekap total hari kerja kasir tersebut.',
          'Transfer gaji ke nomor rekening kasir yang tertera (nama pemilik rekening asli kasir akan muncul otomatis, misal: "a.n. Vidya").',
          'Unggah foto bukti transfer (melalui Kamera HP atau Galeri).',
          'Sistem OCR pintar akan secara otomatis memverifikasi kecocokan Tanggal, Nominal, dan Nama Pemilik Rekening asli kasir untuk memastikan keaslian bukti transfer.',
        ]
      },
      {
        'title': 'Persetujuan Operasional Belanja',
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFFE91E63),
        'desc': 'Meninjau pengeluaran toko yang dilaporkan oleh kasir.',
        'details': [
          'Masuk ke menu "Belanja" untuk meninjau rincian barang yang dibeli oleh kasir.',
          'Pastikan nominal pengeluaran kasir sesuai dengan kebutuhan riil kedai.',
        ]
      },
      {
        'title': 'Pemantauan & Pembatalan Transaksi',
        'icon': Icons.history_rounded,
        'color': const Color(0xFF9C27B0),
        'desc': 'Melihat riwayat transaksi penjualan secara komprehensif.',
        'details': [
          'Masuk ke menu "Riwayat" di navigasi bawah.',
          'Ketuk transaksi tertentu untuk melihat rincian item, waktu bayar, kasir yang melayani, dan metode pembayaran.',
          'Sebagai Owner, Anda memiliki wewenang untuk melakukan pembatalan transaksi (void) jika terjadi kesalahan input oleh kasir.',
        ]
      },
    ];

    return _buildTimelineList(steps);
  }

  // ============================================================
  // REUSABLE TIMELINE WIDGET
  // ============================================================

  Widget _buildTimelineList(List<Map<String, dynamic>> steps) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line and indicator
            Column(
              children: [
                // Glowing Circle Indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: step['color'].withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step['color'],
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: step['color'].withOpacity(0.25),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      step['icon'],
                      color: step['color'],
                      size: 18,
                    ),
                  ),
                ),
                // Line connector
                if (!isLast)
                  Container(
                    width: 2,
                    height: 140, // Height matching step content
                    color: AppColors.border.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Guide details card
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LANGKAH ${index + 1}',
                    style: AppTextStyles.caption.copyWith(
                      color: step['color'],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['title'],
                    style: AppTextStyles.heading3.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step['desc'],
                    style: AppTextStyles.bodySecondary.copyWith(
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Expansion-like box for detailed steps
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (step['details'] as List<String>).map((detail) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: step['color'],
                                  size: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  detail,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 11.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
