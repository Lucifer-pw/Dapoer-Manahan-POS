import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/midtrans_config.dart';

/// Service untuk integrasi Midtrans Snap API
/// Membuat transaksi pembayaran billing otomatis Rp 50.000
class MidtransService {
  // ============================================================
  // CREDENTIALS (dari config file yang di-gitignore)
  // ============================================================
  
  static const String merchantId = MidtransConfig.merchantId;
  static const String _serverKey = MidtransConfig.serverKey;
  static const String clientKey = MidtransConfig.clientKey;
  
  /// Set ke true untuk testing dengan Sandbox environment
  /// Set ke false untuk Production (transaksi nyata)
  static const bool isSandbox = true;
  
  // ============================================================
  // API ENDPOINTS
  // ============================================================
  
  static String get _snapApiUrl => isSandbox
      ? 'https://app.sandbox.midtrans.com/snap/v1/transactions'
      : 'https://app.midtrans.com/snap/v1/transactions';
  
  static String get snapBaseUrl => isSandbox
      ? 'https://app.sandbox.midtrans.com/snap/v2/vtweb/'
      : 'https://app.midtrans.com/snap/v2/vtweb/';
  
  /// Mendapatkan Authorization header (Base64 encoded ServerKey)
  String get _authHeader {
    final credentials = base64Encode(utf8.encode('$_serverKey:'));
    return 'Basic $credentials';
  }
  
  // ============================================================
  // CREATE SNAP TRANSACTION
  // ============================================================
  
  /// Membuat transaksi Snap dengan nominal Rp 50.000
  /// Returns: { 'token': String, 'redirect_url': String }
  Future<Map<String, dynamic>> createBillingTransaction({
    String? customerName,
    String? customerEmail,
  }) async {
    // Generate unique order ID berdasarkan timestamp
    final orderId = 'BILLING-${DateTime.now().millisecondsSinceEpoch}';
    
    final requestBody = {
      'transaction_details': {
        'order_id': orderId,
        'gross_amount': 50000,
      },
      'item_details': [
        {
          'id': 'POS_BILLING_MONTHLY',
          'price': 50000,
          'quantity': 1,
          'name': 'Pembayaran Bulanan Aplikasi POS',
        }
      ],
      'customer_details': {
        'first_name': customerName ?? 'Dapoer Manahan',
        'email': customerEmail ?? 'billing@dapoermanahan.com',
      },
      // Enable semua payment methods
      'enabled_payments': [
        'credit_card',
        'bca_va', 'bni_va', 'bri_va', 'permata_va', 'other_va',
        'gopay', 'shopeepay',
        'bank_transfer',
        'echannel',  // Mandiri Bill
        'indomaret', 'alfamart',
        'akulaku',
        'qris',
      ],
      'callbacks': {
        'finish': 'https://dapoermanahan.com/payment/finish',
      },
    };
    
    try {
      debugPrint('🔄 Creating Midtrans Snap transaction...');
      debugPrint('📋 Order ID: $orderId');
      debugPrint('💰 Amount: Rp 50.000');
      
      final response = await http.post(
        Uri.parse(_snapApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _authHeader,
        },
        body: jsonEncode(requestBody),
      );
      
      debugPrint('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Snap token created successfully');
        debugPrint('🔗 Redirect URL: ${data['redirect_url']}');
        
        return {
          'token': data['token'] as String,
          'redirect_url': data['redirect_url'] as String,
          'order_id': orderId,
        };
      } else {
        final errorBody = jsonDecode(response.body);
        debugPrint('❌ Midtrans error: ${response.body}');
        throw MidtransException(
          'Gagal membuat transaksi: ${errorBody['error_messages'] ?? response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is MidtransException) rethrow;
      debugPrint('❌ Network error: $e');
      throw MidtransException('Gagal terhubung ke server pembayaran: $e');
    }
  }
  
  /// Mendapatkan Snap redirect URL langsung
  Future<String> getPaymentUrl({
    String? customerName,
    String? customerEmail,
  }) async {
    final result = await createBillingTransaction(
      customerName: customerName,
      customerEmail: customerEmail,
    );
    return result['redirect_url'] as String;
  }
}

/// Custom exception untuk error Midtrans
class MidtransException implements Exception {
  final String message;
  final int? statusCode;
  
  MidtransException(this.message, {this.statusCode});
  
  @override
  String toString() => message;
}
