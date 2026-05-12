import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Model data untuk informasi update
class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? downloadUrl;
  final String? message;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.downloadUrl,
    this.message,
    this.forceUpdate = false,
  });
}

/// Service untuk mengecek apakah ada versi terbaru aplikasi.
///
/// Cara kerja:
/// 1. Baca pubspec.yaml dari GitHub repo (raw content)
/// 2. Parse versi terbaru dari file tersebut
/// 3. Bandingkan dengan versi app yang terinstall
/// 4. Jika ada update, cek GitHub Releases untuk link download APK
///
/// Workflow developer:
/// 1. Update version di pubspec.yaml (misal: 1.0.0 → 1.1.0)
/// 2. Commit & push ke GitHub
/// 3. (Opsional) Buat Release di GitHub dengan upload APK
/// 4. App otomatis deteksi versi baru saat dibuka
class UpdateService {
  // ============================================================
  // GITHUB CONFIGURATION
  // ============================================================

  /// GitHub repository owner
  static const String _repoOwner = 'Lucifer-pw';

  /// GitHub repository name
  static const String _repoName = 'Dapoer-Manahan-POS';

  /// Branch utama (main/master)
  static const String _branch = 'main';

  /// URL raw pubspec.yaml dari GitHub
  static String get _pubspecUrl =>
      'https://raw.githubusercontent.com/$_repoOwner/$_repoName/$_branch/pubspec.yaml';

  /// URL GitHub Releases API
  static String get _releasesUrl =>
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  /// URL halaman releases (fallback jika tidak ada APK di release)
  static String get _releasesPageUrl =>
      'https://github.com/$_repoOwner/$_repoName/releases';

  // ============================================================
  // CHECK FOR UPDATE
  // ============================================================

  /// Mengecek apakah ada versi terbaru yang tersedia
  Future<AppUpdateInfo> checkForUpdate() async {
    try {
      // Ambil versi current dari package info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}'; // e.g. "1.0.4+7"

      debugPrint('📱 Current app version: $currentVersion');

      // Ambil info rilis terbaru dari GitHub
      // Kita langsung cek rilis karena di situ ada file APK-nya
      final releaseInfo = await _getLatestReleaseInfo();

      if (releaseInfo == null) {
        debugPrint('⚠️ Could not fetch release info from GitHub');
        return AppUpdateInfo(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
        );
      }

      final latestVersion = releaseInfo['version']!;
      debugPrint('🌐 Latest version from GitHub Release: $latestVersion');

      // Bandingkan versi
      final hasUpdate = _isNewerVersion(currentVersion, latestVersion);

      if (hasUpdate) {
        debugPrint('🆕 Update available: $currentVersion → $latestVersion');
      } else {
        debugPrint('✅ App is up to date');
      }

      return AppUpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: releaseInfo['downloadUrl'] ?? _releasesPageUrl,
        message: releaseInfo['message'],
        forceUpdate: false,
      );
    } catch (e) {
      debugPrint('⚠️ Error checking for update: $e');
      // Fail safe: return no update
      return AppUpdateInfo(
        hasUpdate: false,
        currentVersion: '1.0.0',
        latestVersion: '1.0.0',
      );
    }
  }

  // ============================================================
  // GITHUB RELEASES API - Get version, download URL & release notes
  // ============================================================

  /// Ambil info release terbaru dari GitHub
  Future<Map<String, String>?> _getLatestReleaseInfo() async {
    try {
      final response = await http.get(
        Uri.parse(_releasesUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Ambil info dasar
        final message = data['body'] as String? ?? '';
        final releaseName = data['name'] as String? ?? '';
        final tagName = data['tag_name'] as String? ?? '';

        // Parse versi dari tag_name (misal: v1.0.1+8 -> 1.0.1+8)
        String version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        
        // Cari APK di assets release
        String? downloadUrl;
        final assets = data['assets'] as List<dynamic>? ?? [];

        for (final asset in assets) {
          final assetName = (asset['name'] as String).toLowerCase();
          if (assetName.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }

        // Fallback ke halaman release jika tidak ada APK
        downloadUrl ??= data['html_url'] as String? ?? _releasesPageUrl;

        return {
          'version': version,
          'downloadUrl': downloadUrl,
          'message':
              releaseName.isNotEmpty ? '$releaseName\n$message' : message,
        };
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Error fetching GitHub release: $e');
      return null;
    }
  }

  // ============================================================
  // VERSION COMPARISON
  // ============================================================

  /// Membandingkan versi: apakah latestVersion lebih baru dari currentVersion
  /// Format: "major.minor.patch+build" (e.g. "1.0.4+8")
  bool _isNewerVersion(String current, String latest) {
    try {
      // Pisahkan versi utama dan build number
      final currentFull = current.split('+');
      final latestFull = latest.split('+');
      
      final currentVer = currentFull[0];
      final latestVer = latestFull[0];
      
      // 1. Bandingkan versi utama (major.minor.patch)
      final currentParts = currentVer.split('.').map(int.parse).toList();
      final latestParts = latestVer.split('.').map(int.parse).toList();

      while (currentParts.length < 3) currentParts.add(0);
      while (latestParts.length < 3) latestParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      // 2. Jika versi utama sama, bandingkan build number (setelah +)
      if (currentFull.length > 1 && latestFull.length > 1) {
        final currentBuild = int.tryParse(currentFull[1]) ?? 0;
        final latestBuild = int.tryParse(latestFull[1]) ?? 0;
        return latestBuild > currentBuild;
      } else if (latestFull.length > 1) {
        // Jika versi sekarang tidak punya build number tapi yang terbaru punya
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }
}
