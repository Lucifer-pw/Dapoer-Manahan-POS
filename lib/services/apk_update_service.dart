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
      // Request permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();

        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin storage ditolak'),
            ),
          );
          return;
        }
      }

      // Lokasi penyimpanan APK
      final dir = await getExternalStorageDirectory();

      if (dir == null) {
        throw Exception('Storage tidak ditemukan');
      }

      final filePath = '${dir.path}/update.apk';

      // Loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                child: Text('Sedang mendownload update...'),
              ),
            ],
          ),
        ),
      );

      // Download APK
      await Dio().download(
        apkUrl,
        filePath,
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
