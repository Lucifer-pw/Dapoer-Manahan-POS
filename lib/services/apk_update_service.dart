import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ApkUpdateService {
  static Future<void> downloadAndInstallApk(
    BuildContext context,
    String apkUrl,
  ) async {
    try {
      // Request permission (hanya jika diperlukan)
      if (Platform.isAndroid) {
        // Izin REQUEST_INSTALL_PACKAGES harus diaktifkan oleh user secara manual jika belum
        // Namun kita tetap bisa mencoba mendownload dulu.
        
        // Pengecekan izin storage hanya untuk Android 12 kebawah
        // Pada Android 13+, kita tidak butuh izin storage untuk folder privat aplikasi
        // (getExternalStorageDirectory)
      }

      // Lokasi penyimpanan APK
      final dir = await getExternalStorageDirectory();

      if (dir == null) {
        throw Exception('Storage tidak ditemukan');
      }

      final filePath = '${dir.path}/update.apk';

      // Progress download
      double progress = 0;

      // Fungsi untuk update state dialog
      void Function(void Function())? setDialogState;

      // Loading dialog dengan progress
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
      );

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
      );



      // Tutup loading
      Navigator.pop(context);

      // Buka installer
      await OpenFilex.open(filePath);
    } catch (e) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal update: $e'),
        ),
      );
    }
  }
}
