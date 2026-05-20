import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class ApkUpdateService {
  static Future<void> downloadAndInstallApk(
    BuildContext context,
    String apkUrl,
  ) async {
    // Progress download
    double progress = 0;
    void Function(void Function())? setDialogState;
    bool isDialogOpen = false;

    try {
      // Request permission (hanya jika diperlukan)
      if (Platform.isAndroid) {
        // Izin REQUEST_INSTALL_PACKAGES harus diaktifkan oleh user secara manual jika belum
        // Namun kita tetap bisa mencoba mendownload dulu.
        
        // Pengecekan izin storage hanya untuk Android 12 kebawah
        // Pada Android 13+, kita tidak butuh izin storage untuk folder privat aplikasi
        // (getExternalStorageDirectory)
      }

      // Lokasi penyimpanan APK (menggunakan cache/temp agar lebih aman dari masalah permission)
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';

      // Hapus file lama jika ada
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Loading dialog dengan progress
      if (context.mounted) {
        isDialogOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => StatefulBuilder(
            builder: (context, setState) {
              setDialogState = setState;
              return AlertDialog(
                title: const Text('Mendownload Update'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      progress > 0 
                        ? '${(progress * 100).toStringAsFixed(0)}%' 
                        : 'Menghubungkan...',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ).then((_) {
          isDialogOpen = false;
        });
      }

      // Download APK
      await Dio().download(
        apkUrl,
        filePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            setDialogState?.call(() {
              progress = count / total;
            });
          }
        },
      ).timeout(const Duration(minutes: 5));

      // Tutup loading
      if (context.mounted && isDialogOpen) {
        Navigator.pop(context);
      }

      // Pastikan file benar-benar ada
      if (await File(filePath).exists()) {
        debugPrint('📦 APK Downloaded to: $filePath. Opening installer...');
        final result = await OpenFilex.open(filePath);
        debugPrint('🚀 Installer result: ${result.message}');
      } else {
        throw Exception('File APK tidak ditemukan setelah download');
      }
    } catch (e) {
      debugPrint('❌ Update Error: $e');
      if (context.mounted) {
        // Cek jika dialog masih terbuka, tutup secara aman
        if (isDialogOpen) {
          Navigator.pop(context);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
