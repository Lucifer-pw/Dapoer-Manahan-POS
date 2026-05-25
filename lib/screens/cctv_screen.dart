import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';

class CctvScreen extends StatefulWidget {
  const CctvScreen({super.key});

  @override
  State<CctvScreen> createState() => _CctvScreenState();
}

class _CctvScreenState extends State<CctvScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  WebViewController? _webViewController;

  // State CCTV
  bool _isLoadingSettings = true;
  bool _isLoadingStream = true;
  bool _hasAccess = false;
  bool _isAdmin = false;
  bool _showIpKeyPanel = false;
  bool _showEditPanel = false;

  // Konfigurasi CCTV Aktif
  String _cctvAlias = 'umkssig5d5vu';
  String _cctvPlatform = 'IPCamLive';
  String _cctvType = 'ipcamlive'; // 'ipcamlive', 'xmeye_p2p', 'custom'
  String _cctvCustomUrl = '';

  // Controllers Edit
  final _aliasController = TextEditingController();
  final _platformController = TextEditingController();
  final _customUrlController = TextEditingController();
  String _tempType = 'ipcamlive';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _aliasController.text = _cctvAlias;
    _platformController.text = _cctvPlatform;
    _customUrlController.text = _cctvCustomUrl;
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _platformController.dispose();
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoad() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAdmin || auth.isOwner) {
      setState(() {
        _hasAccess = true;
        _isAdmin = auth.isAdmin;
      });
      await _loadCctvSettings();
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

  Future<void> _loadCctvSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final settings = await _firestoreService.getCctvSettings();
      setState(() {
        _cctvAlias = settings['alias'] ?? 'umkssig5d5vu';
        _cctvPlatform = settings['platform'] ?? 'IPCamLive';
        _cctvType = settings['type'] ?? 'ipcamlive';
        _cctvCustomUrl = settings['customUrl'] ?? '';

        _aliasController.text = _cctvAlias;
        _platformController.text = _cctvPlatform;
        _customUrlController.text = _cctvCustomUrl;
        _tempType = _cctvType;

        _isLoadingSettings = false;
        _isLoadingStream = true;
      });

      if (!kIsWeb && _cctvType != 'xmeye_p2p') {
        _initWebView();
      } else {
        setState(() => _isLoadingStream = false);
      }
    } catch (e) {
      setState(() => _isLoadingSettings = false);
      debugPrint('Error loading CCTV settings: $e');
    }
  }

  void _initWebView() {
    final String embedUrl = _getEmbedUrl();
    if (embedUrl.isEmpty) {
      setState(() => _isLoadingStream = false);
      return;
    }

    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.backgroundDark)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoadingStream = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoadingStream = false);
          },
          onWebResourceError: (error) {
            debugPrint('❌ WebView CCTV error: ${error.description}');
            if (mounted) setState(() => _isLoadingStream = false);
          },
        ),
      );

    // KUNCI UTAMA: Aktifkan DOM Storage secara dinamis untuk mencegah player stream (WebRTC/HLS) menjadi gelap/hitam di Android
    if (!kIsWeb && controller.platform.runtimeType.toString().contains('Android')) {
      try {
        (controller.platform as dynamic).setDomStorageEnabled(true);
      } catch (e) {
        debugPrint('Failed to set DOM Storage: $e');
      }
    }

    controller.loadRequest(Uri.parse(embedUrl));
    _webViewController = controller;
  }

  String _getEmbedUrl() {
    if (_cctvType == 'ipcamlive') {
      return 'https://ipcamlive.com/player/player.php?alias=$_cctvAlias&autoplay=1';
    } else if (_cctvType == 'custom') {
      return _cctvCustomUrl;
    }
    return '';
  }

  String _getPlayerUrl() {
    if (_cctvType == 'ipcamlive') {
      return 'https://ipcamlive.com/$_cctvAlias';
    } else if (_cctvType == 'custom') {
      return _cctvCustomUrl;
    }
    return '';
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final updatedData = {
        'alias': _aliasController.text.trim(),
        'platform': _platformController.text.trim(),
        'type': _tempType,
        'customUrl': _customUrlController.text.trim(),
      };

      await _firestoreService.updateCctvSettings(updatedData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfigurasi CCTV berhasil disimpan!'),
          backgroundColor: AppColors.success,
        ),
      );

      setState(() {
        _showEditPanel = false;
        _isSaving = false;
      });

      // Reload settings & streams
      _loadCctvSettings();
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan konfigurasi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka link: $urlString'),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CCTV Monitor Restoran',
          style: AppTextStyles.heading3.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          // Tombol edit CCTV - HANYA untuk Admin
          if (_isAdmin && !_isLoadingSettings)
            IconButton(
              icon: Icon(
                _showEditPanel ? Icons.settings_applications : Icons.settings_outlined,
                color: _showEditPanel ? AppColors.secondary : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showEditPanel = !_showEditPanel;
                  if (_showEditPanel) _showIpKeyPanel = false;
                });
              },
              tooltip: 'Edit Sumber CCTV',
            ),
          // Tombol detail IPKey - HANYA untuk Admin
          if (_isAdmin && !_isLoadingSettings)
            IconButton(
              icon: Icon(
                _showIpKeyPanel ? Icons.info : Icons.info_outline_rounded,
                color: _showIpKeyPanel ? AppColors.secondary : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showIpKeyPanel = !_showIpKeyPanel;
                  if (_showIpKeyPanel) _showEditPanel = false;
                });
              },
              tooltip: 'Detail IPKey',
            ),
          if (!kIsWeb && _cctvType != 'xmeye_p2p' && _webViewController != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => _webViewController?.reload(),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // 1. Edit Panel - Admin Only
        if (_isAdmin && _showEditPanel) _buildEditPanel(),

        // 2. IPKey Detail Panel - Admin Only
        if (_isAdmin && _showIpKeyPanel) _buildIpKeyPanel(),

        // 3. Main Stream Viewer or XMeye Hub
        Expanded(
          child: _cctvType == 'xmeye_p2p' ? _buildXmeyeHub() : _buildStreamViewer(),
        ),
      ],
    );
  }

  // ============================================================
  // EDIT PANEL - ADMIN ONLY
  // ============================================================

  Widget _buildEditPanel() {
    return Container(
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
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Edit Sumber CCTV',
                style: AppTextStyles.heading3.copyWith(fontSize: 14, color: AppColors.secondary),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.textHint, size: 20),
                onPressed: () => setState(() => _showEditPanel = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // Pilihan Tipe CCTV
          Text('Tipe Kamera CCTV:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTypeRadio('ipcamlive', 'IPCamLive'),
              const SizedBox(width: 16),
              _buildTypeRadio('xmeye_p2p', 'XMeye P2P (Cloud ID)'),
              const SizedBox(width: 16),
              _buildTypeRadio('custom', 'Custom URL / Web Stream'),
            ],
          ),
          const SizedBox(height: 16),

          // Fields berdasarkan Tipe
          if (_tempType == 'ipcamlive') ...[
            _buildTextField(
              controller: _aliasController,
              label: 'IPCamLive Alias / Camera Key',
              hint: 'Contoh: umkssig5d5vu',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _platformController,
              label: 'Platform Name',
              hint: 'IPCamLive',
            ),
          ] else if (_tempType == 'xmeye_p2p') ...[
            _buildTextField(
              controller: _aliasController,
              label: 'P2P Cloud ID / Serial Number (S/N)',
              hint: 'Contoh: umkssig5d5vu',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tipe P2P Cloud ID akan mengaktifkan Hub Pandu & Launcher Aplikasi di perangkat (XMeye/iCSee) karena enkripsi cloud ID tidak bisa dimasukkan ke WebPlayer biasa.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildTextField(
              controller: _customUrlController,
              label: 'Custom Embed / Stream URL',
              hint: 'Masukkan link web player, HLS player (.m3u8), dll',
            ),
          ],

          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => setState(() => _showEditPanel = false),
                child: Text('Batal', style: TextStyle(color: AppColors.textHint)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan Konfigurasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeRadio(String value, String label) {
    return InkWell(
      onTap: () => setState(() => _tempType = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: _tempType,
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) setState(() => _tempType = val);
            },
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.black26,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.primary),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // IPKEY PANEL - ADMIN ONLY
  // ============================================================

  Widget _buildIpKeyPanel() {
    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.vpn_key_rounded, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konfigurasi IPKey CCTV',
                      style: AppTextStyles.heading3.copyWith(fontSize: 14, color: AppColors.secondary),
                    ),
                    Text(
                      'Informasi sensitif • Hanya Admin',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.textSecondaryDark, size: 24),
                onPressed: () => setState(() => _showIpKeyPanel = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10),
          const SizedBox(height: 14),

          _buildDetailRow(
            icon: Icons.fingerprint_rounded,
            label: 'CCTV Alias / Cloud ID',
            value: _cctvAlias,
            canCopy: true,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            icon: Icons.bubble_chart_rounded,
            label: 'Tipe Koneksi CCTV',
            value: _cctvType.toUpperCase(),
            canCopy: false,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            icon: Icons.cloud_rounded,
            label: 'Platform Layanan',
            value: _cctvPlatform,
            canCopy: false,
          ),
          if (_cctvType != 'xmeye_p2p') ...[
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.link_rounded,
              label: 'Embed Player URL',
              value: _getEmbedUrl(),
              canCopy: true,
            ),
          ],
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
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
                  'Sistem Online • Konfigurasi Aktif',
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
                style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
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
              child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // XMEYE HUB / P2P CARD PANEL
  // ============================================================

  Widget _buildXmeyeHub() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.router_rounded,
              color: AppColors.primary,
              size: 64,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Koneksi Cloud P2P CCTV',
            style: AppTextStyles.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Kamera CCTV ini menggunakan enkripsi Xiongmai / XMeye P2P dengan Cloud ID.',
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Card Cloud ID
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'CLOUD ID / SERIAL NUMBER (S/N)',
                  style: TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SelectableText(
                      _cctvAlias,
                      style: AppTextStyles.heading1.copyWith(color: AppColors.secondary, letterSpacing: 2, fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.secondary, size: 20),
                      onPressed: () => _copyToClipboard(_cctvAlias, 'Cloud ID'),
                      tooltip: 'Salin Cloud ID',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pilihan Cara Memantau
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Cara Memantau CCTV:',
              style: AppTextStyles.heading3.copyWith(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),

          // Cara 1: Buka Web Player (HTML5 Plugin-Free)
          _buildMethodCard(
            number: '1',
            title: 'Gunakan Web Browser (Bebas Plugin)',
            description: 'Masuk ke portal web resmi XMeye HTML5, lalu pilih mode "By Device ID", masukkan serial number di atas, login tanpa perlu install ActiveX.',
            icon: Icons.open_in_browser_rounded,
            actionLabel: 'Buka Web Player XMeye',
            onAction: () => _launchUrl('https://v2.xmeye.net/'),
          ),
          const SizedBox(height: 16),

          // Cara 2: Aplikasi iCSee / XMeye di Handphone
          _buildMethodCard(
            number: '2',
            title: 'Pantau dari Aplikasi Handphone (iCSee / XMeye)',
            description: 'Ini adalah metode paling stabil. Download aplikasi di Play Store atau App Store, daftar akun, lalu tambahkan device baru menggunakan metode "Add by Device Serial Number".',
            icon: Icons.phone_android_rounded,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchUrl('https://play.google.com/store/apps/details?id=com.xm.xmcamera'),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Unduh iCSee (Android)', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchUrl('https://apps.apple.com/us/app/icsee/id1130250579'),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Unduh iCSee (iOS)', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark, height: 1.4),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.launch_rounded, size: 14, color: Colors.white),
                      label: Text(actionLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ),
                ],
                if (child != null) child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMBED STREAM VIEWER (WEBVIEW)
  // ============================================================

  Widget _buildStreamViewer() {
    final String embedUrl = _getEmbedUrl();
    if (embedUrl.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada link URL CCTV yang dikonfigurasi!',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

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
                  onPressed: () => _launchUrl(_getPlayerUrl()),
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                  label: const Text(
                    'Buka CCTV Tab Baru',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          if (_isLoadingStream)
            Container(
              color: AppColors.backgroundDark.withOpacity(0.85),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Menghubungkan ke Saluran CCTV...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
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
