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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PrinterProvider>(context, listen: false).getDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pengaturan Printer', style: AppTextStyles.heading3),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => Provider.of<PrinterProvider>(context, listen: false).getDevices(),
          ),
        ],
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, printerProv, child) {
          // Show info message on web platform
          if (printerProv.isWeb) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.print_disabled_rounded, size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Fitur Printer Tidak Tersedia di Web',
                      style: AppTextStyles.heading3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Koneksi printer Bluetooth hanya tersedia pada aplikasi Android.\n\nSilakan gunakan aplikasi Android untuk menghubungkan dan mencetak struk.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Gunakan versi Android untuk fitur cetak struk via Bluetooth.',
                              style: AppTextStyles.caption.copyWith(color: AppColors.info),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (printerProv.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (printerProv.devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_disabled, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text('Tidak ada perangkat Bluetooth ditemukan.', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 8),
                  Text('Pastikan Bluetooth nyala dan printer sudah di-pair.', style: AppTextStyles.caption, textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: printerProv.devices.length,
            itemBuilder: (context, index) {
              final device = printerProv.devices[index];
              final isConnected = printerProv.isConnected && printerProv.selectedDevice?.address == device.address;

              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                child: ListTile(
                  leading: Icon(Icons.print, color: isConnected ? AppColors.success : AppColors.textSecondary),
                  title: Text(device.name ?? 'Unknown Device', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(device.address ?? '', style: AppTextStyles.caption),
                  trailing: isConnected
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error.withOpacity(0.1),
                            foregroundColor: AppColors.error,
                            elevation: 0,
                          ),
                          onPressed: () async {
                            await printerProv.disconnect();
                          },
                          child: const Text('Putus'),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final success = await printerProv.connect(device);
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Terhubung ke ${device.name}'), backgroundColor: AppColors.success),
                              );
                            } else if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gagal terhubung'), backgroundColor: AppColors.error),
                              );
                            }
                          },
                          child: const Text('Hubung'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
