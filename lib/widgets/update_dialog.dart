import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

class UpdateDialog {
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo info,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => WillPopScope(
        onWillPop: () async => !info.forceUpdate,
        child: AlertDialog(
          title: const Text(
            '🚀 Update Tersedia',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versi terbaru '
                '${info.latestVersion} '
                'tersedia.',
              ),
              const SizedBox(height: 8),
              Text(
                'Versi saat ini: '
                '${info.currentVersion}',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              if (info.message != null && info.message!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Perubahan:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(info.message!),
              ],
            ],
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('NANTI'),
              ),
            ElevatedButton(
              onPressed: () async {
                final url = Uri.parse(info.downloadUrl!);

                await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('UPDATE'),
            ),
          ],
        ),
      ),
    );
  }
}
