import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/web_bluetooth/esc_pos_builder.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import 'main_shell.dart';

class ReceiptScreen extends StatelessWidget {
  final Order order;
  const ReceiptScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Success icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
              ),
              const SizedBox(height: 16),
              Text('Pembayaran Berhasil!', style: AppTextStyles.heading2.copyWith(color: AppColors.success)),
              const SizedBox(height: 24),

              // Receipt card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Column(children: [
                  // Header
                  Text(DefaultData.restaurantName, style: AppTextStyles.heading2.copyWith(color: Colors.black87, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text('Struk Pembayaran', style: AppTextStyles.caption.copyWith(color: Colors.black54)),
                  const Divider(height: 24),

                  // Order info
                  _receiptRow('No. Pesanan', order.orderNumber, Colors.black87),
                  _receiptRow('Tanggal', AppFormatter.formatDateTime(order.createdAt), Colors.black54),
                  if (order.customerName.isNotEmpty) _receiptRow('Pelanggan', order.customerName, Colors.black87),
                  _receiptRow(order.isTakeAway ? 'Tipe' : 'Meja', order.isTakeAway ? 'DIBAWA PULANG' : '${order.tableNumber}', Colors.black54),
                  _receiptRow('Kasir', order.cashierName, Colors.black54),
                  const Divider(height: 20),

                  // Items
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(item.menuItemName, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
                          if (item.isBonus)
                            const Text(' (Bonus)', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                        if (item.variant != null)
                          Text('(${item.variant})', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('${item.quantity} x ${AppFormatter.formatRupiah(item.price)}', 
                          style: TextStyle(color: Colors.black54, fontSize: 11, decoration: item.isBonus ? TextDecoration.lineThrough : null)),
                      ])),
                      Text(AppFormatter.formatRupiah(item.subtotal), style: const TextStyle(color: Colors.black87, fontSize: 13)),
                    ]),
                  )),
                  const Divider(height: 20),

                  // Totals
                  _receiptRow('Subtotal', AppFormatter.formatRupiah(order.subtotal), Colors.black54),
                  if (order.tax > 0) _receiptRow('Pajak', AppFormatter.formatRupiah(order.tax), Colors.black54),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('TOTAL', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(AppFormatter.formatRupiah(order.total), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
                  const Divider(height: 20),
                  _receiptRow('Bayar (${order.paymentMethod})', AppFormatter.formatRupiah(order.amountPaid), Colors.black54),
                  _receiptRow('Kembalian', AppFormatter.formatRupiah(order.change), Colors.black87),
                  const Divider(height: 24),
                  
                  // WiFi Info
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi, size: 14, color: Colors.black45),
                              const SizedBox(width: 6),
                              Text('WIFI: ${settings.wifiSsid}', style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('Password: ${settings.wifiPassword}', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  const Text('Terima kasih!', style: TextStyle(color: Colors.black54, fontSize: 12, fontStyle: FontStyle.italic)),
                  const Text(DefaultData.restaurantName, style: TextStyle(color: Colors.black45, fontSize: 10)),
                ]),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printReceipt(context),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Cetak'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (route) => false),
                    icon: const Icon(Icons.home, size: 18),
                    label: const Text('Selesai'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    final printerProv = Provider.of<PrinterProvider>(context, listen: false);

    // 1. Web Bluetooth Direct Printing (Laptop / Google Chrome / Edge)
    if (printerProv.isWeb && printerProv.isWebConnected) {
      try {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final builder = EscPosBuilder();
        builder.feed(1);
        builder.text(DefaultData.restaurantName, align: 1, bold: true, size: 2);
        builder.text("Struk Pembayaran", align: 1);
        builder.feed(1);

        builder.row("No. Pesanan", order.orderNumber);
        final receiptDate = AppFormatter.formatDateTime(order.createdAt)
            .replaceAll(', ', ' ')
            .replaceAll('2026', '26');
        builder.row("Tanggal", receiptDate);
        if (order.customerName.isNotEmpty) {
          builder.row("Pelanggan", order.customerName);
        }
        builder.row(order.isTakeAway ? "Tipe" : "Meja", order.isTakeAway ? "TAKE AWAY" : '${order.tableNumber}');
        builder.row("Kasir", order.cashierName);
        builder.feed(1);

        builder.divider();
        for (var item in order.items) {
          builder.text(item.menuItemName, align: 0, bold: true);
          if (item.variant != null) {
            builder.text("(${item.variant})", align: 0);
          }
          builder.row(
            "${item.quantity} x ${AppFormatter.formatRupiah(item.price)}",
            AppFormatter.formatRupiah(item.subtotal),
          );
        }
        builder.divider();

        builder.row("Subtotal", AppFormatter.formatRupiah(order.subtotal));
        if (order.tax > 0) {
          builder.row("Pajak", AppFormatter.formatRupiah(order.tax));
        }
        builder.row("TOTAL", AppFormatter.formatRupiah(order.total), bold: true);
        builder.feed(1);

        builder.row("Bayar (${order.paymentMethod})", AppFormatter.formatRupiah(order.amountPaid));
        builder.row("Kembalian", AppFormatter.formatRupiah(order.change), bold: true);
        builder.feed(1);

        builder.divider();
        builder.text("WIFI: ${settings.wifiSsid}", align: 1, bold: true);
        builder.text("Pass: ${settings.wifiPassword}", align: 1);
        builder.divider();
        builder.feed(1);

        builder.text("Terima kasih!", align: 1);
        builder.text(DefaultData.restaurantName, align: 1);
        builder.cut();

        await printerProv.printWebBytes(builder.toBytes());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Struk berhasil dicetak via Web Bluetooth!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mencetak Web Bluetooth: $e. Mengalihkan ke jendela cetak...'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        // Fallback continues to PDF below
      }
    }

    // 2. Android Native Bluetooth Printing
    if (!printerProv.isWeb && printerProv.isConnected) {
      try {
        final bluetooth = printerProv.bluetooth;
        bluetooth.printCustom(DefaultData.restaurantName, 3, 1);
        bluetooth.printCustom("Struk Pembayaran", 1, 1);
        bluetooth.printNewLine();
        
        bluetooth.printLeftRight("No. Pesanan", order.orderNumber, 1);
        final receiptDate = AppFormatter.formatDateTime(order.createdAt)
            .replaceAll(', ', ' ')
            .replaceAll('2026', '26'); // Shorten year to fit
        bluetooth.printLeftRight("Tanggal", receiptDate, 1);
        if (order.customerName.isNotEmpty) bluetooth.printLeftRight("Pelanggan", order.customerName, 1);
        bluetooth.printLeftRight(order.isTakeAway ? "Tipe" : "Meja", order.isTakeAway ? "TAKE AWAY" : '${order.tableNumber}', 1);
        bluetooth.printLeftRight("Kasir", order.cashierName, 1);
        bluetooth.printNewLine();
        
        bluetooth.printCustom("--------------------------------", 1, 1);
        for (var item in order.items) {
          bluetooth.printCustom(item.menuItemName, 1, 0);
          if (item.variant != null) {
            bluetooth.printCustom("(${item.variant})", 1, 0);
          }
          bluetooth.printLeftRight("${item.quantity} x ${AppFormatter.formatRupiah(item.price)}", AppFormatter.formatRupiah(item.subtotal), 1);
        }
        bluetooth.printCustom("--------------------------------", 1, 1);
        
        bluetooth.printLeftRight("Subtotal", AppFormatter.formatRupiah(order.subtotal), 1);
        if (order.tax > 0) {
          bluetooth.printLeftRight("Pajak", AppFormatter.formatRupiah(order.tax), 1);
        }
        bluetooth.printLeftRight("TOTAL", AppFormatter.formatRupiah(order.total), 1);
        bluetooth.printNewLine();
        
        bluetooth.printLeftRight("Bayar (${order.paymentMethod})", AppFormatter.formatRupiah(order.amountPaid), 1);
        bluetooth.printLeftRight("Kembalian", AppFormatter.formatRupiah(order.change), 1);
        bluetooth.printNewLine();

        final settings = Provider.of<SettingsProvider>(context, listen: false);
        bluetooth.printCustom("--------------------------------", 1, 1);
        bluetooth.printCustom("WIFI: ${settings.wifiSsid}", 1, 1);
        bluetooth.printCustom("Pass: ${settings.wifiPassword}", 1, 1);
        bluetooth.printCustom("--------------------------------", 1, 1);
        bluetooth.printNewLine();
        
        bluetooth.printCustom("Terima kasih!", 1, 1);
        bluetooth.printCustom(DefaultData.restaurantName, 0, 1);
        bluetooth.printNewLine();
        bluetooth.printNewLine();
        bluetooth.printNewLine();
        bluetooth.paperCut();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mencetak Bluetooth: $e'), backgroundColor: AppColors.error));
        }
      }
      return;
    }

    // 3. Fallback to PDF / System Print Dialog (USB or Unpaired)
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    DefaultData.restaurantName,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text('Struk Pembayaran', style: const pw.TextStyle(fontSize: 12)),
                ),
                pw.Divider(height: 20),

                // Order Info
                _pdfRow('No. Pesanan', order.orderNumber),
                _pdfRow('Tanggal', AppFormatter.formatDateTime(order.createdAt)),
                if (order.customerName.isNotEmpty) _pdfRow('Pelanggan', order.customerName),
                _pdfRow(order.isTakeAway ? 'Tipe' : 'Meja', order.isTakeAway ? 'TAKE AWAY' : '${order.tableNumber}'),
                _pdfRow('Kasir', order.cashierName),
                pw.Divider(height: 20),

                // Items
                ...order.items.map((item) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(item.menuItemName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                if (item.variant != null)
                                  pw.Text('(${item.variant})', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                pw.Text('${item.quantity} x ${AppFormatter.formatRupiah(item.price)}', style: const pw.TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                          pw.Text(AppFormatter.formatRupiah(item.subtotal), style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    )),
                pw.Divider(height: 20),

                // Totals
                _pdfRow('Subtotal', AppFormatter.formatRupiah(order.subtotal)),
                if (order.tax > 0) _pdfRow('Pajak', AppFormatter.formatRupiah(order.tax)),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text(AppFormatter.formatRupiah(order.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                ),
                pw.Divider(height: 20),
                
                // Payment
                _pdfRow('Bayar (${order.paymentMethod})', AppFormatter.formatRupiah(order.amountPaid)),
                _pdfRow('Kembalian', AppFormatter.formatRupiah(order.change)),
                pw.Divider(height: 20),
                
                // WiFi Info
                pw.Center(child: pw.Text('WIFI: ${settings.wifiSsid}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Center(child: pw.Text('Pass: ${settings.wifiPassword}', style: const pw.TextStyle(fontSize: 10))),
                pw.SizedBox(height: 20),
                
                // Footer
                pw.Center(child: pw.Text('Terima kasih!', style: const pw.TextStyle(fontSize: 10))),
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text(DefaultData.restaurantName, style: const pw.TextStyle(fontSize: 8))),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Struk_${order.orderNumber}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
