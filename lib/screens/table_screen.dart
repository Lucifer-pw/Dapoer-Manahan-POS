import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';
import '../widgets/table_card.dart';
import '../widgets/chat_room_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/printer_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/firestore_service.dart';
import '../models/order.dart' as app;
import '../utils/formatter.dart';
import 'order_detail_screen.dart';
import '../providers/auth_provider.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  late final TableProvider _tableProv;

  @override
  void initState() {
    super.initState();
    _tableProv = Provider.of<TableProvider>(context, listen: false);
    _tableProv.addListener(_checkForPendingHighlight);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPendingHighlight();
    });
  }

  @override
  void dispose() {
    _tableProv.removeListener(_checkForPendingHighlight);
    super.dispose();
  }

  void _checkForPendingHighlight() {
    if (!mounted) return;
    final highlightNumber = _tableProv.pendingHighlightTableNumber;
    if (highlightNumber != null) {
      final table = _tableProv.getTableByNumber(highlightNumber);
      if (table != null) {
        _showTableOrderHistoryDialog(context, table);
      }
      _tableProv.pendingHighlightTableNumber = null;
    }
  }

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
    final firestoreService = FirestoreService();

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

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreService.streamActiveQrOrders(),
            builder: (context, activeOrdersSnapshot) {
              final activeQrOrders = activeOrdersSnapshot.data ?? [];

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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double width = constraints.maxWidth;
                        final bool isMobile = width < 600;
                        
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: isMobile
                              ? const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.35,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                )
                              : const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 180,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                          itemCount: tableProv.tables.length,
                          itemBuilder: (context, index) {
                            final table = tableProv.tables[index];
                            
                            // Filter active QR orders for this table
                            final tableActiveOrders = activeQrOrders.where((o) {
                              final tableNum = o['tableNumber'];
                              return tableNum?.toString() == table.number.toString();
                            }).toList();

                            return TableCard(
                              table: table,
                              activeOrders: tableActiveOrders,
                              onTap: () {
                                _showTableOptions(context, table, tableProv);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
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
                ListTile(
                  leading: const Icon(Icons.chat_rounded, color: AppColors.secondary),
                  title: const Text('Chat dengan Pelanggan'),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => ChatRoomDialog(
                        tableNumber: table.number.toString(),
                        role: 'admin',
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded, color: AppColors.info),
                  title: const Text('Riwayat Pemesanan Meja'),
                  onTap: () {
                    Navigator.pop(context);
                    _showTableOrderHistoryDialog(context, table);
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

  void _showTableOrderHistoryDialog(BuildContext context, RestaurantTable table) {
    final firestoreService = FirestoreService();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final cashierName = authProv.cashierName;
    final cashierId = authProv.user?.uid ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: firestoreService.streamQrOrdersByTable(table.number.toString()),
              builder: (context, qrSnapshot) {
                return StreamBuilder<List<app.Order>>(
                  stream: firestoreService.streamOrdersByTable(table.number),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        qrSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    final orders = snapshot.data ?? [];
                    final qrOrders = qrSnapshot.data ?? [];


                    // Active QR orders (pending, accepted)
                    final activeQrOrders = qrOrders.where((o) {
                      final st = o['status'] as String? ?? '';
                      return st == 'pending' || st == 'accepted' || st == 'delivered';
                    }).toList();

                    // Filter today's completed orders for revenue calculation
                    final today = DateTime.now();
                    final todayCompletedOrders = orders.where((o) =>
                        o.status == app.OrderStatus.completed &&
                        o.createdAt.year == today.year &&
                        o.createdAt.month == today.month &&
                        o.createdAt.day == today.day);
                    
                    final totalEarningsToday = todayCompletedOrders.fold(0, (sum, o) => sum + o.total);

                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Riwayat Meja ${table.number}',
                                    style: AppTextStyles.heading3,
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Hari Ini: ${AppFormatter.formatRupiah(totalEarningsToday)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: (activeQrOrders.isEmpty && orders.isEmpty)
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textHint.withOpacity(0.4)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Belum ada riwayat pesanan\nuntuk Meja ${table.number}',
                                        style: AppTextStyles.bodySecondary,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  children: [
                                    // === ACTIVE QR ORDERS SECTION ===
                                    if (activeQrOrders.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Pesanan QR Aktif (${activeQrOrders.length})',
                                            style: AppTextStyles.subtitle.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...activeQrOrders.map((qr) => _buildActiveQrOrderTile(
                                        context,
                                        qr,
                                        firestoreService,
                                        cashierName: cashierName,
                                        cashierId: cashierId,
                                      )),
                                      const SizedBox(height: 16),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                    ],
                                    // === COMPLETED ORDERS SECTION ===
                                    if (orders.isNotEmpty) ...[
                                      Text(
                                        'Riwayat Transaksi',
                                        style: AppTextStyles.subtitle.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...orders.map((order) {
                                        Color statusColor = AppColors.warning;
                                        String statusText = 'Pending';
                                        
                                        if (order.status == app.OrderStatus.completed) {
                                          statusColor = AppColors.success;
                                          statusText = 'Selesai';
                                        } else if (order.status == app.OrderStatus.cancelled) {
                                          statusColor = AppColors.error;
                                          statusText = 'Batal';
                                        }

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            border: Border.all(
                                              color: AppColors.border.withOpacity(0.2),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        order.orderNumber,
                                                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: order.paymentMethod == 'QRIS' 
                                                              ? AppColors.info.withOpacity(0.15) 
                                                              : AppColors.success.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          order.paymentMethod,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: order.paymentMethod == 'QRIS' 
                                                                ? AppColors.info 
                                                                : AppColors.success,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      statusText,
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    AppFormatter.formatDateTime(order.createdAt),
                                                    style: AppTextStyles.caption,
                                                  ),
                                                  Text(
                                                    AppFormatter.formatRupiah(order.total),
                                                    style: AppTextStyles.priceSmall,
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 16),
                                              ListView.builder(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: order.items.length,
                                                itemBuilder: (context, itemIndex) {
                                                  final item = order.items[itemIndex];
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 4.0),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          '${item.quantity}x',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.primary,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                item.menuItemName,
                                                                style: AppTextStyles.body.copyWith(fontSize: 12),
                                                              ),
                                                              if (item.variant != null && item.variant!.isNotEmpty)
                                                                Text(
                                                                  'Minuman: ${item.variant}',
                                                                  style: AppTextStyles.caption.copyWith(
                                                                    color: AppColors.secondary,
                                                                    fontSize: 10,
                                                                  ),
                                                                ),
                                                              if (item.notes.isNotEmpty)
                                                                Text(
                                                                  'Catatan: "${item.notes}"',
                                                                  style: AppTextStyles.caption.copyWith(
                                                                    fontStyle: FontStyle.italic,
                                                                    fontSize: 10,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        Text(
                                                          AppFormatter.formatRupiah(item.price * item.quantity),
                                                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => OrderDetailScreen(order: order),
                                                      ),
                                                    );
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                  ),
                                                  child: Text(
                                                    'Lihat Detail Transaksi',
                                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Build a single active QR order tile with accept/reject, mark paid, mark delivered actions
  Widget _buildActiveQrOrderTile(
    BuildContext context, 
    Map<String, dynamic> qr, 
    FirestoreService firestoreService, {
    String? cashierName,
    String? cashierId,
  }) {
    final String orderId = qr['id'] ?? '';
    final String status = qr['status'] as String? ?? 'pending';
    final String paymentMethod = qr['paymentMethod'] as String? ?? 'Tunai';
    final String paymentStatus = qr['paymentStatus'] as String? ?? 'belum_bayar';
    final int total = _toInt(qr['totalPrice'] ?? qr['total']);
    final List<dynamic> items = qr['items'] as List<dynamic>? ?? [];

    final timestamp = qr['createdAt'];
    DateTime date = DateTime.now();
    if (timestamp != null) {
      try { date = (timestamp as dynamic).toDate(); } catch (_) {}
    }

    // Payment status badge
    Color payColor;
    String payText;
    if (paymentStatus == 'sudah_bayar') {
      payColor = AppColors.success;
      payText = 'Lunas';
    } else if (paymentMethod == 'QRIS') {
      payColor = AppColors.info;
      payText = 'Menunggu QRIS';
    } else {
      payColor = AppColors.primary;
      payText = 'Belum Dibayar';
    }

    // Order status badge
    Color statusColor;
    String statusText;
    switch (status) {
      case 'accepted':
        statusColor = AppColors.info;
        statusText = 'Sedang Diproses';
        break;
      case 'delivered':
        statusColor = AppColors.success;
        statusText = 'Sudah Dianter';
        break;
      case 'pending':
      default:
        statusColor = AppColors.warning;
        statusText = 'Menunggu Konfirmasi';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: time + badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppFormatter.formatDateTime(date),
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Metode: $paymentMethod',
                      style: AppTextStyles.caption.copyWith(fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _badge(payText, payColor),
                  _badge(statusText, statusColor),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          // Items
          ...items.map((it) {
            final String name = it['name'] ?? it['menuItemName'] ?? '';
            final int qty = _toInt(it['quantity'], fallback: 1);
            final int price = _toInt(it['price']);
            final String? variant = it['variant'];
            final String notes = it['notes'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${qty}x', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (variant != null && variant.isNotEmpty)
                          Text('Opsi: $variant', style: AppTextStyles.caption.copyWith(color: AppColors.secondary, fontSize: 10)),
                        if (notes.isNotEmpty)
                          Text('Catatan: "$notes"', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic, fontSize: 10)),
                      ],
                    ),
                  ),
                  Text(AppFormatter.formatRupiah(price * qty), style: AppTextStyles.caption.copyWith(fontSize: 12)),
                ],
              ),
            );
          }),
          const Divider(height: 16),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              Text(AppFormatter.formatRupiah(total), style: AppTextStyles.price),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          if (status == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await firestoreService.updateQrOrderStatus(orderId, 'rejected');
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Tolak', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await firestoreService.updateQrOrderStatus(orderId, 'accepted', cashierName: cashierName, cashierId: cashierId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Terima & Proses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'accepted') ...[
            Row(
              children: [
                if (paymentStatus != 'sudah_bayar')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await firestoreService.updateQrOrderPaymentStatus(orderId, 'sudah_bayar', cashierName: cashierName, cashierId: cashierId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pesanan ditandai Lunas!'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                      icon: const Icon(Icons.payments_rounded, size: 16),
                      label: const Text('Tandai Lunas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                if (paymentStatus != 'sudah_bayar') const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await firestoreService.updateQrOrderStatus(orderId, 'delivered', cashierName: cashierName, cashierId: cashierId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pesanan ditandai sudah Dianter!'), backgroundColor: AppColors.success),
                        );
                      }
                    },
                    icon: const Icon(Icons.delivery_dining_rounded, size: 16),
                    label: const Text('Tandai Dianter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'delivered' && paymentStatus != 'sudah_bayar') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await firestoreService.updateQrOrderPaymentStatus(orderId, 'sudah_bayar', cashierName: cashierName, cashierId: cashierId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pesanan ditandai Lunas!'), backgroundColor: AppColors.success),
                    );
                  }
                },
                icon: const Icon(Icons.payments_rounded, size: 16),
                label: const Text('Tandai Lunas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
