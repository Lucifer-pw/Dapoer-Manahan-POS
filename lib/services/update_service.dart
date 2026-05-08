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
      final currentVersion = packageInfo.version; // e.g. "1.0.0"
      
      debugPrint('📱 Current app version: $currentVersion');

      // Ambil versi terbaru dari GitHub
      final latestVersion = await _getLatestVersionFromGitHub();
      
      if (latestVersion == null) {
        debugPrint('⚠️ Could not fetch version from GitHub');
        return AppUpdateInfo(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
        );
      }

      debugPrint('🌐 Latest version from GitHub: $latestVersion');

      // Bandingkan versi
      final hasUpdate = _isNewerVersion(currentVersion, latestVersion);
      
      String? downloadUrl;
      String? releaseMessage;
      
      if (hasUpdate) {
        debugPrint('🆕 Update available: $currentVersion → $latestVersion');
        
        // Coba ambil info dari GitHub Releases (download URL & release notes)
        final releaseInfo = await _getLatestReleaseInfo();
        downloadUrl = releaseInfo?['downloadUrl'];
        releaseMessage = releaseInfo?['message'];
      } else {
        debugPrint('✅ App is up to date');
      }

      return AppUpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl ?? _releasesPageUrl,
        message: releaseMessage,
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
  // GITHUB RAW CONTENT - Read pubspec.yaml
  // ============================================================

  /// Baca versi terbaru dari pubspec.yaml di GitHub
  Future<String?> _getLatestVersionFromGitHub() async {
    try {
      final response = await http.get(
        Uri.parse(_pubspecUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final content = response.body;
        
        // Parse version dari pubspec.yaml
        // Format: version: 1.0.0+1
        final versionRegex = RegExp(r'version:\s*(\d+\.\d+\.\d+)');
        final match = versionRegex.firstMatch(content);
        
        if (match != null) {
          return match.group(1);
        }
      }
      
      debugPrint('⚠️ GitHub raw content status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('⚠️ Error fetching pubspec from GitHub: $e');
      return null;
    }
  }

  // ============================================================
  // GITHUB RELEASES API - Get download URL & release notes
  // ============================================================

  /// Ambil info release terbaru dari GitHub (download URL, release notes)
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
        
        // Ambil release notes
        final message = data['body'] as String? ?? '';
        final releaseName = data['name'] as String? ?? '';
        
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
          'downloadUrl': downloadUrl,
          'message': releaseName.isNotEmpty 
              ? '$releaseName\n$message'
              : message,
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
  /// Format: "major.minor.patch" (e.g. "1.2.3")
  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      // Pastikan kedua list punya 3 elemen
      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (latestParts.length < 3) {
        latestParts.add(0);
      }

      // Bandingkan: major > minor > patch
      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return false; // Versi sama
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }
}
