import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';

class CctvScreen extends StatefulWidget {
  const CctvScreen({super.key});

  @override
  State<CctvScreen> createState() => _CctvScreenState();
}

class _CctvScreenState extends State<CctvScreen> {
  // ============================================================
  // CCTV CONFIG
  // ============================================================
  static const String _cctvAlias = 'umkssig5d5vu';
  static const String _cctvPlayerUrl =
      'https://ipcamlive.com/player/player.php?alias=$_cctvAlias';
  static const String _cctvEmbedUrl =
      'https://ipcamlive.com/player/player.php?alias=$_cctvAlias&autoplay=1';
  static const String _cctvPlatform = 'IPCamLive';

  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasAccess = false;
  bool _isAdmin = false;
  bool _showIpKeyPanel = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  void _checkAccess() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Admin dan Owner bisa akses CCTV
    if (auth.isAdmin || auth.isOwner) {
      setState(() {
        _hasAccess = true;
        _isAdmin = auth.isAdmin;
      });
      if (!kIsWeb) {
        _initWebView();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akses Ditolak: Fitur khusus Admin & Owner!'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.backgroundDark)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            debugPrint('❌ WebView CCTV error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_cctvEmbedUrl));
  }

  Future<void> _launchInBrowser() async {
    final url = Uri.parse(_cctvPlayerUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka link CCTV di browser!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin ke clipboard!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CCTV Monitor Restoran',
          style: AppTextStyles.heading3.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          // Tombol toggle IPKey panel - HANYA untuk Admin
          if (_isAdmin)
            IconButton(
              icon: Icon(
                _showIpKeyPanel ? Icons.info : Icons.info_outline_rounded,
                color: _showIpKeyPanel ? AppColors.secondary : Colors.white,
              ),
              onPressed: () {
                setState(() => _showIpKeyPanel = !_showIpKeyPanel);
              },
              tooltip: 'Detail IPKey',
            ),
          if (!kIsWeb && _webViewController != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => _webViewController?.reload(),
              tooltip: 'Refresh',
            ),
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
              onPressed: _launchInBrowser,
              tooltip: 'Buka di Browser',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // IPKey Detail Panel - ADMIN ONLY
        if (_isAdmin && _showIpKeyPanel) _buildIpKeyPanel(),

        // Stream Viewer
        Expanded(child: _buildStreamViewer()),
      ],
    );
  }

  // ============================================================
  // IP KEY DETAIL PANEL - ADMIN ONLY
  // ============================================================

  Widget _buildIpKeyPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.3)),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.vpn_key_rounded,
                    color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konfigurasi IPKey CCTV',
                      style: AppTextStyles.heading3
                          .copyWith(fontSize: 14, color: AppColors.secondary),
                    ),
                    Text(
                      'Informasi sensitif • Hanya Admin',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Collapse button
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded,
                    color: AppColors.textSecondaryDark, size: 24),
                onPressed: () => setState(() => _showIpKeyPanel = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Detail rows
          _buildDetailRow(
            icon: Icons.fingerprint_rounded,
            label: 'Alias / IPKey',
            value: _cctvAlias,
            canCopy: true,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            icon: Icons.cloud_rounded,
            label: 'Platform',
            value: _cctvPlatform,
            canCopy: false,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            icon: Icons.link_rounded,
            label: 'Player URL',
            value: _cctvPlayerUrl,
            canCopy: true,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            icon: Icons.code_rounded,
            label: 'Embed URL',
            value: _cctvEmbedUrl,
            canCopy: true,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            icon: Icons.integration_instructions_rounded,
            label: 'Embed Code (iframe)',
            value:
                '<iframe src="$_cctvEmbedUrl" width="640" height="480" frameborder="0" allowfullscreen></iframe>',
            canCopy: true,
          ),
          const SizedBox(height: 14),

          // Status indicator
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border:
                  Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Kamera Aktif • Streaming Real-Time',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool canCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption
                    .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: AppColors.textPrimaryDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (canCopy)
          GestureDetector(
            onTap: () => _copyToClipboard(value, label),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.copy_rounded,
                  size: 14, color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // STREAM VIEWER
  // ============================================================

  Widget _buildStreamViewer() {
    if (kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  color: AppColors.primary,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'CCTV Web Mode',
                style: AppTextStyles.heading2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Untuk performa terbaik di browser web, pantau CCTV dengan membukanya di tab baru.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 250,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _launchInBrowser,
                  icon: const Icon(Icons.open_in_new_rounded,
                      color: Colors.white),
                  label: const Text(
                    'Buka CCTV Tab Baru',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_webViewController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoading)
            Container(
              color: AppColors.backgroundDark.withOpacity(0.85),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Menyambungkan ke Kamera CCTV...',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return const Center(
      child: Text(
        'Gagal memuat player CCTV!',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
