import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/printer_provider.dart';
import '../utils/constants.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  bool _isGuideExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PrinterProvider>(context, listen: false).getDevices();
    });
  }

  bool _isLikelyPrinter(String? name) {
    if (name == null || name.isEmpty) return false;
    final n = name.toLowerCase();
    return n.contains('rpp') ||
        n.contains('pos') ||
        n.contains('print') ||
        n.contains('pt-') ||
        n.contains('mpt') ||
        n.contains('xp-') ||
        n.contains('pma') ||
        n.contains('thermal') ||
        n.contains('58') ||
        n.contains('80') ||
        n.contains('bt-') ||
        n.contains('innerprinter') ||
        n.contains('epson') ||
        n.contains('zj-');
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Panduan Printer Kasir', style: AppTextStyles.heading3),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepItem(
                '1',
                'Nyalakan Printer & Pasang Kertas',
                'Pastikan tombol power printer thermal menyala (lampu biru/hijau) dan kertas thermal 58mm/80mm sudah terpasang dengan arah gulungan yang benar.',
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                '2',
                'Pairing di Pengaturan Bluetooth HP',
                'Buka menu Pengaturan/Bluetooth di HP Android Anda, scan perangkat baru, lalu klik nama printer (misal: RPP02N, PT-210, PMA 9320) untuk melakukan Pairing (Sandingkan).',
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                '3',
                'Masukkan PIN Bluetooth Default',
                'Jika HP meminta PIN/Sandi saat pairing, masukkan PIN standar printer: 0000 atau 1234.',
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                '4',
                'Pilih Printer di Aplikasi & Hubungkan',
                'Kembali ke halaman ini di aplikasi POS, cari nama printer yang sudah dipasangkan, lalu tekan tombol "Hubung".',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Perangkat seperti TWS, Headset, atau Smartwatch yang terdeteksi di daftar Bluetooth bukan merupakan printer struk.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String stepNum, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNum,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pengaturan Printer', style: AppTextStyles.heading3),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Panduan Menghubungkan Printer',
            onPressed: () => _showHelpDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Pindai Ulang Perangkat',
            onPressed: () => Provider.of<PrinterProvider>(context, listen: false).getDevices(),
          ),
        ],
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, printerProv, child) {
          // Web Bluetooth Interface for Laptop/Web Browser
          if (printerProv.isWeb) {
            return _buildWebPrinterSettings(context, printerProv);
          }

          if (printerProv.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final devices = printerProv.devices;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Status Printer Terhubung Saat Ini
                if (printerProv.isConnected && printerProv.selectedDevice != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.success.withOpacity(0.4), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    printerProv.selectedDevice!.name ?? 'Thermal Printer',
                                    style: AppTextStyles.heading3.copyWith(color: AppColors.success, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Status: Terhubung (${printerProv.selectedDevice!.address})',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                label: const Text('Tes Cetak Struk', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final ok = await printerProv.printTestReceipt();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? '✅ Tes cetak struk berhasil terkirim!' : '❌ Gagal mencetak struk.'),
                                        backgroundColor: ok ? AppColors.success : AppColors.error,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.link_off_rounded, size: 18),
                              label: const Text('Putus'),
                              onPressed: () async {
                                await printerProv.disconnect();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // 2. Panduan Koneksi Cepat (Collapsible Card)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border.withOpacity(0.3)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _isGuideExpanded,
                      onExpansionChanged: (val) => setState(() => _isGuideExpanded = val),
                      leading: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFFA726)),
                      title: Text(
                        'Panduan Cara Hubungkan Printer',
                        style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              _buildStepItem(
                                '1',
                                'Nyalakan Printer & Pasang Kertas',
                                'Pastikan printer thermal menyala dan kertas struk 58mm sudah terpasang rapi.',
                              ),
                              const SizedBox(height: 10),
                              _buildStepItem(
                                '2',
                                'Pasangkan (Pair) di Bluetooth HP',
                                'Buka Pengaturan Bluetooth HP ➔ Pasangkan (Pair) printer Anda (PIN: 0000 atau 1234).',
                              ),
                              const SizedBox(height: 10),
                              _buildStepItem(
                                '3',
                                'Tekan Tombol "Hubung" di Bawah',
                                'Cari nama printer Anda (misal: RPP02N, PT-210, PMA 9320) pada daftar perangkat di bawah lalu tekan "Hubung".',
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Perangkat seperti TWS, Headset, atau Smartwatch bukan printer struk.',
                                        style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Header Daftar Perangkat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daftar Perangkat Bluetooth (${devices.length})', style: AppTextStyles.heading3.copyWith(fontSize: 14)),
                    TextButton.icon(
                      onPressed: () => printerProv.getDevices(),
                      icon: const Icon(Icons.sync_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Refresh', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 4. Daftar Perangkat Bluetooth
                if (devices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_disabled_rounded, size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text('Tidak ada perangkat Bluetooth ditemukan', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Pastikan Bluetooth HP aktif dan printer sudah di-pair di pengaturan HP.',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final bool isConnected = printerProv.isConnected && printerProv.selectedDevice?.address == device.address;
                      final bool isPrinter = _isLikelyPrinter(device.name);

                      return Card(
                        color: isConnected ? AppColors.success.withOpacity(0.08) : AppColors.surface,
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: BorderSide(
                            color: isConnected
                                ? AppColors.success
                                : isPrinter
                                    ? AppColors.primary.withOpacity(0.4)
                                    : AppColors.border.withOpacity(0.2),
                            width: isConnected || isPrinter ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? AppColors.success.withOpacity(0.2)
                                  : isPrinter
                                      ? AppColors.primary.withOpacity(0.15)
                                      : AppColors.surfaceDark,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPrinter ? Icons.print_rounded : Icons.bluetooth_rounded,
                              color: isConnected
                                  ? AppColors.success
                                  : isPrinter
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  device.name ?? 'Perangkat Bluetooth',
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: isConnected || isPrinter ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPrinter) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Printer',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              device.address ?? '',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11),
                            ),
                          ),
                          trailing: isConnected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: const Text(
                                    'Terhubung',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isPrinter ? AppColors.primary : AppColors.surfaceDark,
                                    foregroundColor: isPrinter ? Colors.white : AppColors.textPrimary,
                                    elevation: isPrinter ? 2 : 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  ),
                                  onPressed: () async {
                                    final success = await printerProv.connect(device);
                                    if (success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ Berhasil terhubung ke ${device.name}'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } else if (!success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('❌ Gagal terhubung ke printer. Pastikan printer menyala dan sudah di-pair di Bluetooth HP.'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Hubung', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Web Bluetooth Settings UI ──
  Widget _buildWebPrinterSettings(BuildContext context, PrinterProvider printerProv) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Status Connection Card
          if (printerProv.isWebConnected) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withOpacity(0.18),
                    AppColors.success.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.success.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.print_rounded, color: AppColors.success, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Printer Web Bluetooth Terhubung',
                                  style: AppTextStyles.subtitle.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              printerProv.webDeviceName.isNotEmpty ? printerProv.webDeviceName : 'Iware Bluetooth Printer',
                              style: AppTextStyles.heading3.copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final success = await printerProv.printTestReceipt();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Tes cetak berhasil dikirim ke printer!' : 'Gagal mengirim tes cetak.'),
                                  backgroundColor: success ? AppColors.success : AppColors.error,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.receipt_long_rounded, size: 18),
                          label: const Text('Tes Cetak Struk'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await printerProv.disconnectWebBluetooth();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Koneksi printer Bluetooth diputus.'),
                                backgroundColor: AppColors.info,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.link_off_rounded, size: 18),
                        label: const Text('Putus'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bluetooth_searching_rounded, size: 38, color: AppColors.primary),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hubungkan Printer Bluetooth di Laptop',
                    style: AppTextStyles.heading3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sambungkan printer Iware / thermal Bluetooth langsung dari Google Chrome atau Microsoft Edge tanpa perlu install driver Windows.',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Button 1: Web Serial (Bluetooth SPP & USB) - Recommended for Iware Windows
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: printerProv.isLoading
                          ? null
                          : () async {
                              try {
                                final ok = await printerProv.connectWebSerial();
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Printer ${printerProv.webDeviceName} berhasil terhubung!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal menghubungkan: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: printerProv.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.usb_rounded, size: 20),
                      label: Text(
                        printerProv.isLoading ? 'Menghubungkan...' : 'Hubungkan Iware (Bluetooth SPP / USB)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Button 2: Web Bluetooth BLE
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: printerProv.isLoading
                          ? null
                          : () async {
                              try {
                                final ok = await printerProv.connectWebBle();
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Printer ${printerProv.webDeviceName} berhasil terhubung!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal menghubungkan: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.bluetooth_rounded, size: 18),
                      label: const Text(
                        'Hubungkan via Bluetooth BLE',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // 2. Panduan Singkat
          Text('Panduan Hubungkan Printer Iware di Laptop:', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildWebStepItem('1', 'Pairing Printer di Windows Laptop', 'Buka Settings Windows > Bluetooth & devices > Add device > Sambungkan printer Iware (PIN standar: 0000 atau 1234). Jika memakai kabel USB, cukup tancapkan kabel ke laptop.'),
          const SizedBox(height: 10),
          _buildWebStepItem('2', 'Klik Tombol Oranye di Atas', 'Tekan tombol "Hubungkan Iware (Bluetooth SPP / USB)" di atas.'),
          const SizedBox(height: 10),
          _buildWebStepItem('3', 'Pilih Port Printer & Klik "Connect / Hubungkan"', 'Pada jendela popup browser Google Chrome / Edge, pilih port printer Iware Anda lalu klik Connect.'),
          const SizedBox(height: 10),
          _buildWebStepItem('4', 'Selesai!', 'Printer Iware akan langsung terhubung (Status Hijau) dan siap mencetak struk secara otomatis saat transaksi POS.'),

          const SizedBox(height: 24),
          // 3. Alternative info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Alternatif USB / System Print: Jika tidak menggunakan Web Bluetooth, Anda juga dapat menghubungkan printer via kabel USB dan mencetak menggunakan jendela cetak browser standar.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.info, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStepItem(String stepNum, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNum,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(desc, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

