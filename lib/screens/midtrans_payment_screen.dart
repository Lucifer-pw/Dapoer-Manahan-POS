import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/midtrans_service.dart';
import '../utils/constants.dart';

/// Screen yang menampilkan halaman pembayaran Midtrans Snap via WebView.
/// Nominal otomatis Rp 50.000 untuk pembayaran billing bulanan.
/// Mendukung semua metode pembayaran: Transfer Bank, GoPay, QRIS, dll.
class MidtransPaymentScreen extends StatefulWidget {
  const MidtransPaymentScreen({super.key});

  @override
  State<MidtransPaymentScreen> createState() => _MidtransPaymentScreenState();
}

class _MidtransPaymentScreenState extends State<MidtransPaymentScreen> {
  final MidtransService _midtransService = MidtransService();
  
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _isCreatingTransaction = true;
  String? _errorMessage;
  String? _paymentUrl;

  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  Future<void> _initPayment() async {
    try {
      setState(() {
        _isCreatingTransaction = true;
        _errorMessage = null;
      });

      // Buat transaksi Midtrans Snap
      final result = await _midtransService.createBillingTransaction();
      final redirectUrl = result['redirect_url'] as String;

      if (!mounted) return;

      setState(() {
        _paymentUrl = redirectUrl;
        _isCreatingTransaction = false;
      });

      // Inisialisasi WebView
      _setupWebView(redirectUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isCreatingTransaction = false;
        _isLoading = false;
      });
    }
  }

  void _setupWebView(String url) {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            debugPrint('🔗 Navigating to: $url');

            // Detect jika pembayaran selesai/finish
            if (url.contains('status_code=200') ||
                url.contains('transaction_status=settlement') ||
                url.contains('transaction_status=capture')) {
              _onPaymentSuccess();
              return NavigationDecision.prevent;
            }

            // Detect jika pembayaran pending
            if (url.contains('transaction_status=pending')) {
              _onPaymentPending();
              return NavigationDecision.prevent;
            }

            // Detect jika pembayaran gagal/expired
            if (url.contains('transaction_status=deny') ||
                url.contains('transaction_status=cancel') ||
                url.contains('transaction_status=expire')) {
              _onPaymentFailed();
              return NavigationDecision.prevent;
            }

            // Detect finish callback URL
            if (url.contains('payment/finish') || 
                url.contains('finish')) {
              // Parse URL parameters untuk status
              final uri = Uri.parse(url);
              final status = uri.queryParameters['transaction_status'];
              
              if (status == 'settlement' || status == 'capture') {
                _onPaymentSuccess();
              } else if (status == 'pending') {
                _onPaymentPending();
              } else {
                _onPaymentPending(); // Default to pending for finish URLs
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('❌ WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {});
  }

  void _onPaymentSuccess() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 64),
            ),
            const SizedBox(height: 20),
            Text('Pembayaran Berhasil!', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              'Pembayaran Rp 50.000 telah diterima.\nHubungi admin untuk mengaktifkan aplikasi.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, 'success');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text('KEMBALI'),
            ),
          ),
        ],
      ),
    );
  }

  void _onPaymentPending() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: AppColors.warning, size: 64),
            ),
            const SizedBox(height: 20),
            Text('Menunggu Pembayaran', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              'Silakan selesaikan pembayaran sesuai instruksi.\nStatus akan diperbarui otomatis setelah pembayaran diterima.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, 'pending');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text('KEMBALI'),
            ),
          ),
        ],
      ),
    );
  }

  void _onPaymentFailed() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded,
                  color: AppColors.error, size: 64),
            ),
            const SizedBox(height: 20),
            Text('Pembayaran Gagal', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text(
              'Pembayaran tidak berhasil.\nSilakan coba lagi atau hubungi admin.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, 'failed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text('KEMBALI'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Pembayaran Billing', style: AppTextStyles.heading3),
        centerTitle: true,
        actions: [
          if (_paymentUrl != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textHint),
              onPressed: () => _webViewController?.reload(),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Creating transaction state
    if (_isCreatingTransaction) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text('Mempersiapkan pembayaran...', style: AppTextStyles.subtitle),
            const SizedBox(height: 8),
            Text('Nominal: Rp 50.000', style: AppTextStyles.bodySecondary),
          ],
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    color: AppColors.error, size: 56),
              ),
              const SizedBox(height: 24),
              Text('Gagal Membuat Pembayaran', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _initPayment,
                  icon: const Icon(Icons.refresh),
                  label: const Text('COBA LAGI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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

    // WebView state
    if (_webViewController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoading)
            Container(
              color: AppColors.background.withOpacity(0.8),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
