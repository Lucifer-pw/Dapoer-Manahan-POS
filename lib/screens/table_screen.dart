import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';
import '../widgets/table_card.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/printer_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  void _showAddEditDialog(BuildContext context, {RestaurantTable? table}) {
    final tableProv = Provider.of<TableProvider>(context, listen: false);
    final numberController =
        TextEditingController(text: table?.number.toString() ?? '');
    final capacityController =
        TextEditingController(text: table?.capacity.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(table == null ? 'Tambah Meja' : 'Edit Meja',
            style: AppTextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nomor Meja',
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacityController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Kapasitas (Kursi)',
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final number = int.tryParse(numberController.text) ?? 0;
              final capacity = int.tryParse(capacityController.text) ?? 0;
              if (number > 0) {
                if (table == null) {
                  await tableProv.addTable(number, capacity);
                } else {
                  await tableProv.updateTable(table.id, number, capacity);
                }
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
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
        title: Text('Manajemen Meja', style: AppTextStyles.heading2),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: Consumer<TableProvider>(
        builder: (context, tableProv, _) {
          if (tableProv.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (tableProv.tables.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_restaurant_outlined,
                      size: 60, color: AppColors.textHint.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Belum ada meja', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _showAddEditDialog(context),
                    child: const Text('Tambah Meja Pertama'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Legend
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                      bottom: BorderSide(
                          color: AppColors.border.withOpacity(0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem(
                        'Tersedia', AppColors.success, tableProv.availableCount),
                    _buildLegendItem(
                        'Terisi', AppColors.error, tableProv.occupiedCount),
                    _buildLegendItem(
                        'Reserved',
                        AppColors.warning,
                        tableProv.tables
                            .where((t) => t.status == TableStatus.reserved)
                            .length),
                  ],
                ),
              ),

              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: tableProv.tables.length,
                  itemBuilder: (context, index) {
                    final table = tableProv.tables[index];
                    return TableCard(
                      table: table,
                      onTap: () {
                        _showTableOptions(context, table, tableProv);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ($count)', style: AppTextStyles.caption),
      ],
    );
  }

  void _showTableOptions(
      BuildContext context, RestaurantTable table, TableProvider tableProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Meja ${table.number}',
                      style: AppTextStyles.heading3),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.check_circle, color: AppColors.success),
                  title: const Text('Set Tersedia'),
                  onTap: () {
                    tableProv.setAvailable(table.id);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people, color: AppColors.error),
                  title: const Text('Set Terisi'),
                  onTap: () {
                    tableProv.setOccupied(table.id, '');
                    Navigator.pop(context);
                  },
                ),
                 ListTile(
                  leading: const Icon(Icons.bookmark, color: AppColors.warning),
                  title: const Text('Set Reserved'),
                  onTap: () {
                    tableProv.setReserved(table.id);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                  title: const Text('Tampilkan QR Code Meja'),
                  onTap: () {
                    Navigator.pop(context);
                    _showTableQrDialog(context, table);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.info),
                  title: const Text('Edit Meja (Nomor/Kursi)'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddEditDialog(context, table: table);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text('Hapus Meja'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Hapus Meja'),
                        content: Text('Yakin ingin menghapus Meja ${table.number}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: AppColors.error))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await tableProv.deleteTable(table.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTableQrDialog(BuildContext context, RestaurantTable table) {
    final qrUrl = table.qrUrl ?? "https://pos-dapoer-manahan.web.app/table/${table.number}";
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Column(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 40),
            const SizedBox(height: 10),
            Text('QR Code Meja ${table.number}', style: AppTextStyles.heading3),
            const SizedBox(height: 4),
            Text(
              'Pelanggan dapat memindai QR ini untuk memesan mandiri',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: QrImageView(
                data: qrUrl,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F0F1A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F0F1A),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              qrUrl,
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _printTableQrPdf(context, table);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
            label: const Text('Cetak Sticker (PDF)', style: TextStyle(color: Colors.white)),
          ),
          if (!kIsWeb) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _printTableQr(context, table);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.card,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
              label: const Text('Cetak Thermal', style: TextStyle(color: Colors.white)),
            ),
          ],
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text('Tutup', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _printTableQrPdf(BuildContext context, RestaurantTable table) async {
    final doc = pw.Document();
    final qrUrl = table.qrUrl ?? "https://pos-dapoer-manahan.web.app/table/${table.number}";

    // Load restaurant logo from assets
    pw.ImageProvider? logoImage;
    try {
      logoImage = await imageFromAssetBundle('assets/images/app_logo.png');
    } catch (e) {
      debugPrint('Failed to load logo asset for PDF: $e');
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          10 * PdfPageFormat.cm,
          10 * PdfPageFormat.cm,
          marginTop: 0.5 * PdfPageFormat.cm,
          marginBottom: 0.5 * PdfPageFormat.cm,
          marginLeft: 0.5 * PdfPageFormat.cm,
          marginRight: 0.5 * PdfPageFormat.cm,
        ),
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              color: PdfColors.white,
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Top Row: Logo + Restaurant Name + Table Number Badge
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Logo + Text
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logoImage != null) ...[
                          pw.Image(logoImage, width: 32, height: 32),
                          pw.SizedBox(width: 6),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "DAPOER MANAHAN",
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF0F0F1A),
                              ),
                            ),
                            pw.Text(
                              "Pesan Online Mandiri",
                              style: const pw.TextStyle(
                                fontSize: 7,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Table Number Badge
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF0F0F1A),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            "MEJA",
                            style: pw.TextStyle(
                              color: PdfColors.grey400,
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.Text(
                            "${table.number}",
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Center QR Code
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey200, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrUrl,
                    width: 130,
                    height: 130,
                  ),
                ),
                
                // Bottom steps in a single row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfStepRow("1", "Pindai QR"),
                    _buildPdfStepRow("2", "Pilih Menu"),
                    _buildPdfStepRow("3", "Pesanan Diantar"),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'QR_Code_Meja_${table.number}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e')),
        );
      }
    }
  }

  pw.Widget _buildPdfStepRow(String number, String text) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 12,
          height: 12,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: PdfColors.orange,
          ),
          child: pw.Text(
            number,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          text,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey800,
          ),
        ),
      ],
    );
  }

  void _printTableQr(BuildContext context, RestaurantTable table) async {
    final printerProv = Provider.of<PrinterProvider>(context, listen: false);
    if (printerProv.isConnected) {
      try {
        final bluetooth = printerProv.bluetooth;
        bluetooth.printCustom(DefaultData.restaurantName, 3, 1);
        bluetooth.printCustom("Pindai Untuk Memesan", 1, 1);
        bluetooth.printCustom("Meja ${table.number}", 2, 1);
        bluetooth.printNewLine();
        
        final qrUrl = table.qrUrl ?? "https://pos-dapoer-manahan.web.app/table/${table.number}";
        bluetooth.printQRcode(qrUrl, 200, 200, 1);
        
        bluetooth.printNewLine();
        bluetooth.printCustom("Silakan pindai QR code diatas", 1, 1);
        bluetooth.printCustom("untuk langsung memesan menu mandiri.", 1, 1);
        bluetooth.printNewLine();
        bluetooth.printNewLine();
        bluetooth.printNewLine();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code Meja berhasil dicetak!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencetak QR Code: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer tidak terhubung! Silakan aktifkan koneksi printer.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
