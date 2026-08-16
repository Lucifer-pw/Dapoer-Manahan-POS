import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';
import '../utils/receipt_scanner.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});
  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final FirestoreService _fs = FirestoreService();
  int _ratePerDay = 50000;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<String> _cashierNames = [];
  String? _selectedCashier;
  List<String> _workingDates = [];
  List<Map<String, dynamic>> _shiftLogs = [];

  // Data
  int _totalWorkDays = 0;
  int _totalPaid = 0;
  int _totalTransactions = 0;
  String _cashierBankName = '';
  String _cashierBankAccount = '';
  String _cashierBankAccountName = '';
  String _cashierEmail = '';
  bool _isLoading = true;
  bool _isLoadingWork = false;

  List<String> get _unpaidDates {
    if (_paidDays >= _workingDates.length) return [];
    return _workingDates.sublist(_paidDays);
  }

  int get _paidDays => _totalPaid ~/ _ratePerDay;
  int get _remainingDays => (_totalWorkDays - _paidDays).clamp(0, 999999);
  int get _totalSalary => _totalWorkDays * _ratePerDay;
  int get _remainingSalary => _remainingDays * _ratePerDay;

  @override
  void initState() {
    super.initState();
    _loadCashiers();
  }

  Future<void> _loadCashiers() async {
    setState(() => _isLoading = true);
    final names = await _fs.getAllCashierNames();
    if (!mounted) return;
    setState(() {
      _cashierNames = names;
      _isLoading = false;
      if (names.isNotEmpty && _selectedCashier == null) {
        _selectedCashier = names.first;
        _loadWorkingDays();
      }
    });
  }

  Future<void> _loadWorkingDays() async {
    if (_selectedCashier == null) return;
    setState(() => _isLoadingWork = true);

    try {
      final start = DateTime(_selectedYear, _selectedMonth, 1);
      final end = DateTime(_selectedYear, _selectedMonth + 1, 1);

      // Run queries in parallel for speed
      final results = await Future.wait([
        _fs.getWorkingDays(_selectedCashier!, start, end),
        _fs.getTotalPaidForCashier(_selectedCashier!, _selectedMonth, _selectedYear),
        _fs.getCashierBankDetails(_selectedCashier!),
        _fs.getShiftLogsForMonth(_selectedCashier!, _selectedMonth, _selectedYear),
      ]);

      if (!mounted) return;
      final workData = results[0] as Map<String, dynamic>;
      final paid = results[1] as int;
      final bankData = results[2] as Map<String, dynamic>;
      final shiftLogs = results[3] as List<Map<String, dynamic>>;
      
      final List<String> rawDates = List<String>.from(workData['dates'] ?? []);
      // Sort dates chronologically
      rawDates.sort((a, b) {
        final da = _parseCustomDate(a);
        final db = _parseCustomDate(b);
        return da.compareTo(db);
      });

      setState(() {
        _workingDates = rawDates;
        _shiftLogs = shiftLogs;
        _totalWorkDays = workData['workingDays'] as int;
        _totalTransactions = workData['totalTransactions'] as int;
        _totalPaid = paid;
        _cashierBankName = bankData['bankName'] ?? '';
        _cashierBankAccount = bankData['bankAccountNumber'] ?? '';
        _cashierBankAccountName = bankData['bankAccountName'] ?? '';
        _cashierEmail = bankData['email'] ?? '';
        _ratePerDay = bankData['ratePerDay'] as int? ?? 50000;
      });
    } catch (e) {
      debugPrint('Error loading working days: $e');
      if (mounted) {
        setState(() {
          _workingDates = [];
          _shiftLogs = [];
          _totalWorkDays = 0;
          _totalTransactions = 0;
          _totalPaid = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWork = false);
      }
    }
  }

  // ── Month/Year Picker ──
  void _showMonthPicker() {
    int tM = _selectedMonth, tY = _selectedYear;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppColors.textHint.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Pilih Bulan & Tahun', style: AppTextStyles.heading3),
            const SizedBox(height: 20),
            // Year
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _arrowBtn(Icons.chevron_left_rounded, () => setS(() => tY--)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                child: Text('$tY', style: AppTextStyles.heading2.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: 16),
              _arrowBtn(Icons.chevron_right_rounded,
                  tY < DateTime.now().year ? () => setS(() => tY++) : null),
            ]),
            const SizedBox(height: 16),
            // Months grid
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, childAspectRatio: 2.2,
                crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: 12,
              itemBuilder: (_, i) {
                final m = i + 1;
                final sel = m == tM;
                final future = tY == DateTime.now().year && m > DateTime.now().month;
                return GestureDetector(
                  onTap: future ? null : () => setS(() => tM = m),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: sel ? AppColors.primaryGradient : null,
                      color: sel ? null : future ? AppColors.card.withOpacity(0.3) : AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Center(child: Text(_shortMonth(m),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        color: sel ? Colors.white : future
                            ? AppColors.textHint.withOpacity(0.4)
                            : AppColors.textPrimary))),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.textHint.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md))),
                child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() { _selectedMonth = tM; _selectedYear = tY; });
                  _loadWorkingDays();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md))),
                child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _arrowBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: onTap != null ? AppColors.card : AppColors.card.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border.withOpacity(0.2))),
      child: Icon(icon, size: 24,
          color: onTap != null ? AppColors.textPrimary : AppColors.textHint),
    ),
  );

  String _shortMonth(int m) {
    const ms = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return ms[m];
  }

  DateTime _parseCustomDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return DateTime.tryParse(dateStr) ?? DateTime.now();
  }

  // ── Edit Tarif Gaji Dialog ──
  void _showEditRateDialog() {
    if (_selectedCashier == null) return;
    final controller = TextEditingController(text: _ratePerDay.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Edit Tarif Gaji Harian', style: AppTextStyles.heading3),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Tarif Baru (Rp / Hari)',
            prefixText: 'Rp ',
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final rate = int.tryParse(controller.text) ?? 50000;
                final navigator = Navigator.of(ctx);
                
                try {
                  await _fs.updateCashierRate(_selectedCashier!, rate);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tarif gaji harian berhasil diperbarui'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                  navigator.pop();
                  _loadWorkingDays();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal memperbarui tarif: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Input Gaji Dialog ──
  void _showPaySalaryDialog() {
    if (_selectedCashier == null || _remainingDays <= 0) return;
    final nominalCtrl = TextEditingController();
    String selectedMethod = 'Transfer';
    DateTime selectedDate = DateTime.now();
    File? proofImage;
    bool isUploading = false;

    // State pemindaian OCR
    bool isScanning = false;
    DateTime? scannedDate;
    int? scannedAmount;
    bool? scannedNameMatched;
    bool? scannedAccountNumberMatched;
    bool? isFromGallery;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) {
          final nominal = int.tryParse(nominalCtrl.text) ?? 0;
          final calcDays = nominal ~/ _ratePerDay;
          final isValid = nominal > 0 && calcDays <= _remainingDays;

          final nameCheckActive = _cashierBankAccountName.isNotEmpty;
          final accountCheckActive = _cashierBankAccount.isNotEmpty;

          final isDateMatched = scannedDate == null || (scannedDate!.year == selectedDate.year && scannedDate!.month == selectedDate.month && scannedDate!.day == selectedDate.day);
          final isAmountMatched = scannedAmount == null || scannedAmount == nominal;
          final isNameMatched = !nameCheckActive || (scannedNameMatched == true);
          final isAccountNumberMatched = !accountCheckActive || (scannedAccountNumberMatched == true);

          final isFullyMatched = isDateMatched && isAmountMatched && isNameMatched && isAccountNumberMatched;
          
          List<String> datesToPay = [];
          if (isValid && calcDays > 0) {
            datesToPay = _unpaidDates.take(calcDays).toList();
          }

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Input Gaji', style: AppTextStyles.heading3),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Kasir', _selectedCashier!),
                _infoRow('Periode', '${AppFormatter.getMonthName(_selectedMonth)} $_selectedYear'),
                _infoRow('Total Hari Kerja', '$_totalWorkDays hari'),
                _infoRow('Sudah Dibayar', '$_paidDays hari (${AppFormatter.formatRupiah(_totalPaid)})'),
                _infoRow('Sisa Belum Dibayar', '$_remainingDays hari (${AppFormatter.formatRupiah(_remainingSalary)})'),
                const Divider(height: 24),
                TextField(
                  controller: nominalCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  onChanged: (_) => setD(() {}),
                  decoration: InputDecoration(
                    labelText: 'Nominal Gaji yang Dibayar',
                    prefixText: 'Rp ',
                    filled: true, fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 16),
                Text('Metode Pembayaran', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setD(() => selectedMethod = 'Cash'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedMethod == 'Cash' ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: selectedMethod == 'Cash' ? AppColors.primary : AppColors.border.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Text('Cash', style: TextStyle(
                              color: selectedMethod == 'Cash' ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setD(() => selectedMethod = 'Transfer'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedMethod == 'Transfer' ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: selectedMethod == 'Transfer' ? AppColors.primary : AppColors.border.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Text('Transfer', style: TextStyle(
                              color: selectedMethod == 'Transfer' ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Tanggal Pembayaran', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setD(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppFormatter.formatDate(selectedDate), style: AppTextStyles.body),
                        Icon(Icons.calendar_month_rounded, color: AppColors.textHint, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Live calculation
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isValid ? AppColors.info : AppColors.error).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: (isValid ? AppColors.info : AppColors.error).withOpacity(0.3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (nominal > 0) ...[
                      Text(
                        'Setara $calcDays hari kerja',
                        style: AppTextStyles.body.copyWith(
                          color: isValid ? AppColors.info : AppColors.error,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        '${AppFormatter.formatRupiah(nominal)} ÷ ${AppFormatter.formatRupiah(_ratePerDay)} = $calcDays hari',
                        style: AppTextStyles.caption.copyWith(
                          color: isValid ? AppColors.info : AppColors.error, fontSize: 11)),
                      if (!isValid && calcDays > _remainingDays)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '⚠ Melebihi sisa hari ($_remainingDays hari)',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      if (isValid && datesToPay.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Membayar untuk tanggal:\n${datesToPay.map((d) => AppFormatter.formatDate(_parseCustomDate(d))).join(", ")}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ] else
                      Text('Masukkan nominal untuk menghitung',
                          style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    const SizedBox(height: 6),
                    Text('Via $selectedMethod',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint, fontSize: 11)),
                    Text('Tanggal: ${AppFormatter.formatDate(selectedDate)}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint, fontSize: 11)),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('Bukti Pembayaran (Opsional)', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (proofImage != null) ...[
                  Stack(
                    children: [
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          image: DecorationImage(
                            image: FileImage(proofImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => setD(() {
                            proofImage = null;
                            scannedDate = null;
                            scannedAmount = null;
                            scannedNameMatched = null;
                            scannedAccountNumberMatched = null;
                            isFromGallery = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isScanning)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Memindai bukti transfer...',
                            style: AppTextStyles.caption.copyWith(color: AppColors.info, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else if (scannedDate != null || scannedAmount != null) ...[
                    Builder(
                      builder: (context) {
                        if (isFullyMatched) {
                          final successMessage = nameCheckActive && accountCheckActive
                            ? 'Teks terdeteksi cocok dengan input Anda (${AppFormatter.formatRupiah(scannedAmount ?? nominal)}, ${AppFormatter.formatDate(scannedDate ?? selectedDate)}) serta nama "$_cashierBankAccountName" dan no. rek "$_cashierBankAccount" terverifikasi.'
                            : nameCheckActive
                              ? 'Teks terdeteksi cocok dengan input Anda (${AppFormatter.formatRupiah(scannedAmount ?? nominal)}, ${AppFormatter.formatDate(scannedDate ?? selectedDate)}) dan transfer atas nama "$_cashierBankAccountName" terverifikasi.'
                              : 'Teks terdeteksi cocok dengan input Anda (${AppFormatter.formatRupiah(scannedAmount ?? nominal)}, ${AppFormatter.formatDate(scannedDate ?? selectedDate)}).';
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.success.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Bukti Transfer Valid & Riil!',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  successMessage,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.success, fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }

                        final colorToken = isFromGallery == true ? AppColors.error : AppColors.warning;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorToken.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: colorToken.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isFromGallery == true ? Icons.lock_rounded : Icons.warning_amber_rounded,
                                    color: colorToken,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isFromGallery == true 
                                      ? 'Unggahan Galeri Terkunci (Gagal Verifikasi):'
                                      : 'Detail Bukti Transfer Berbeda:',
                                    style: AppTextStyles.caption.copyWith(color: colorToken, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (scannedDate != null && !isDateMatched)
                                Text(
                                  '• Tanggal struk: ${AppFormatter.formatDate(scannedDate!)} (Input: ${AppFormatter.formatDate(selectedDate)})',
                                  style: AppTextStyles.caption.copyWith(color: colorToken, fontSize: 11),
                                ),
                              if (scannedAmount != null && !isAmountMatched)
                                Text(
                                  '• Nominal struk: ${AppFormatter.formatRupiah(scannedAmount!)} (Input: ${AppFormatter.formatRupiah(nominal)})',
                                  style: AppTextStyles.caption.copyWith(color: colorToken, fontSize: 11),
                                ),
                              if (nameCheckActive && scannedNameMatched == false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '• Rekening atas nama "$_cashierBankAccountName" tidak cocok/tidak terdeteksi',
                                    style: AppTextStyles.caption.copyWith(color: colorToken, fontSize: 11),
                                  ),
                                ),
                              if (accountCheckActive && scannedAccountNumberMatched == false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '• Nomor rekening "$_cashierBankAccount" tidak cocok/tidak terdeteksi',
                                    style: AppTextStyles.caption.copyWith(color: colorToken, fontSize: 11),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              if (isFromGallery == true) ...[
                                Text(
                                  'Verifikasi gagal. Unggahan Galeri harus 100% cocok. Silakan sesuaikan data input, unggah bukti yang benar, atau gunakan Kamera jika ingin bypass verifikasi.',
                                  style: AppTextStyles.caption.copyWith(color: colorToken, fontSize: 10, fontStyle: FontStyle.italic),
                                ),
                              ] else ...[
                                Text(
                                  'Kamera (Bypass Aktif): Anda tetap dapat menekan tombol Bayar jika yakin data sudah sesuai.',
                                  style: AppTextStyles.caption.copyWith(color: colorToken, fontSize: 10, fontStyle: FontStyle.italic),
                                ),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setD(() {
                                      if (scannedDate != null) selectedDate = scannedDate!;
                                      if (scannedAmount != null) {
                                        nominalCtrl.text = scannedAmount!.toString();
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                                  label: const Text('Terapkan dari Struk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorToken,
                                    padding: EdgeInsets.zero,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final storageService = StorageService();
                            final file = await storageService.takePhoto();
                            if (file != null) {
                              setD(() {
                                proofImage = file;
                                isScanning = true;
                                scannedDate = null;
                                scannedAmount = null;
                                scannedNameMatched = null;
                                scannedAccountNumberMatched = null;
                                isFromGallery = false;
                              });
                              final result = await ReceiptScanner.scanReceipt(
                                file,
                                inputAmount: nominal,
                                bankAccountName: _cashierBankAccountName,
                                bankAccountNumber: _cashierBankAccount,
                              );
                              setD(() {
                                isScanning = false;
                                if (result != null) {
                                  scannedDate = result['date'];
                                  scannedAmount = result['amount'];
                                  scannedNameMatched = result['isNameMatched'];
                                  scannedAccountNumberMatched = result['isAccountNumberMatched'];
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final storageService = StorageService();
                            final file = await storageService.pickImage();
                            if (file != null) {
                              setD(() {
                                proofImage = file;
                                isScanning = true;
                                scannedDate = null;
                                scannedAmount = null;
                                scannedNameMatched = null;
                                scannedAccountNumberMatched = null;
                                isFromGallery = true;
                              });
                              final result = await ReceiptScanner.scanReceipt(
                                file,
                                inputAmount: nominal,
                                bankAccountName: _cashierBankAccountName,
                                bankAccountNumber: _cashierBankAccount,
                              );
                              setD(() {
                                isScanning = false;
                                if (result != null) {
                                  scannedDate = result['date'];
                                  scannedAmount = result['amount'];
                                  scannedNameMatched = result['isNameMatched'];
                                  scannedAccountNumberMatched = result['isAccountNumberMatched'];
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.image_rounded, size: 18),
                          label: const Text('Galeri', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
              ],
            )),
            actions: [
              if (!isUploading)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
              ElevatedButton(
                onPressed: (isValid && !isUploading && !isScanning && (proofImage == null || isFromGallery != true || isFullyMatched)) ? () async {
                  setD(() => isUploading = true);
                  
                  String? proofUrl;
                  if (proofImage != null) {
                    try {
                      final storageService = StorageService();
                      proofUrl = await storageService.uploadSalaryProofImage(proofImage!, _selectedCashier!);
                    } catch (e) {
                      setD(() => isUploading = false);
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Gagal mengupload foto: $e'), backgroundColor: AppColors.error));
                      return;
                    }
                  }
                  DateTime finalDate = selectedDate;
                  if (selectedDate.year != DateTime.now().year || selectedDate.month != DateTime.now().month || selectedDate.day != DateTime.now().day) {
                    finalDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 12, 0);
                  }
                  
                  await _fs.addSalaryPayment({
                    'cashierName': _selectedCashier,
                    'month': _selectedMonth,
                    'year': _selectedYear,
                    'workingDays': _totalWorkDays,
                    'ratePerDay': _ratePerDay,
                    'nominal': nominal,
                    'paidDays': calcDays,
                    'paidAt': Timestamp.fromDate(finalDate),
                    'paymentMethod': selectedMethod,
                    if (proofUrl != null) 'proofUrl': proofUrl,
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  _loadWorkingDays(); // refresh data
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Gaji ${AppFormatter.formatRupiah(nominal)} ($calcDays hari) berhasil dicatat'),
                    backgroundColor: AppColors.success));
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Bayar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppTextStyles.caption),
      Flexible(child: Text(value,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
          textAlign: TextAlign.end)),
    ]),
  );

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20)),
        title: Text('Gaji Karyawan', style: AppTextStyles.heading3),
        actions: [
          GestureDetector(
            onTap: _showMonthPicker,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8, offset: const Offset(0, 2))]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text('${_shortMonth(_selectedMonth)} $_selectedYear',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _loadWorkingDays,
              child: ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
                _buildCashierSelector(),
                const SizedBox(height: 20),
                _buildBankDetailsCard(),
                const SizedBox(height: 20),
                _buildSalaryCard(),
                const SizedBox(height: 20),
                _buildPaymentHistory(),
                const SizedBox(height: 20),
              ]),
            ),
    );
  }

  // ── Bank Details Card ──
  Widget _buildBankDetailsCard() {
    if (_selectedCashier == null || _isLoadingWork) return const SizedBox.shrink();

    final hasBank = _cashierBankAccount.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info.withOpacity(0.15),
            AppColors.info.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.info, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informasi Rekening Kasir', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
                    Text(_cashierEmail.isNotEmpty ? _cashierEmail : 'Email tidak tersedia', style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasBank) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bank ${_cashierBankName.toUpperCase()}', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(_cashierBankAccount, style: AppTextStyles.heading3.copyWith(letterSpacing: 1)),
                        Text('a.n. ${_cashierBankAccountName.isNotEmpty ? _cashierBankAccountName : _selectedCashier}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _cashierBankAccount));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Nomor rekening $_cashierBankAccount berhasil disalin'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Kasir belum memasukkan data rekening bank di menu Pengaturan Toko.',
                style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tarif Gaji Harian',
                        style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatter.formatRupiah(_ratePerDay),
                        style: AppTextStyles.heading3.copyWith(letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (!auth.isAdmin && !auth.isOwner) return const SizedBox.shrink();
                    return ElevatedButton.icon(
                      onPressed: _showEditRateDialog,
                      icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                      label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cashier Selector ──
  Widget _buildCashierSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pilih Kasir', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_cashierNames.isEmpty)
          Text('Belum ada data kasir', style: AppTextStyles.bodySecondary)
        else
          Wrap(spacing: 8, runSpacing: 8, children: _cashierNames.map((name) {
            final sel = name == _selectedCashier;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedCashier = name);
                _loadWorkingDays();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: sel ? AppColors.primaryGradient : null,
                  color: sel ? null : AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: sel ? null : Border.all(color: AppColors.border.withOpacity(0.3)),
                  boxShadow: sel ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8)] : null),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_rounded, size: 16,
                      color: sel ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(name, style: AppTextStyles.body.copyWith(
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? Colors.white : AppColors.textPrimary, fontSize: 13)),
                ]),
              ),
            );
          }).toList()),
      ]),
    );
  }

  // ── Salary Calculation Card ──
  Widget _buildSalaryCard() {
    if (_isLoadingWork) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (_totalWorkDays == 0 && _shiftLogs.isEmpty && _totalPaid == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: AppColors.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Riwayat Kerja',
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Kasir "$_selectedCashier" belum memiliki catatan shift, kehadiran, atau transaksi pada periode ${AppFormatter.getMonthName(_selectedMonth)} $_selectedYear.',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.border.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    'Pilih kasir lain atau ubah bulan di pojok kanan atas',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withOpacity(0.08),
          AppColors.secondary.withOpacity(0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.work_history_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedCashier ?? '-',
                style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
            Text('${AppFormatter.getMonthName(_selectedMonth)} $_selectedYear',
                style: AppTextStyles.caption),
          ])),
        ]),
        const SizedBox(height: 20),

        // Stats row
        Row(children: [
          Expanded(child: _miniStat(Icons.calendar_today_rounded, AppColors.info,
              '$_totalWorkDays', 'Total Hari')),
          const SizedBox(width: 10),
          Expanded(child: _miniStat(Icons.check_circle_rounded, AppColors.success,
              '$_paidDays', 'Sudah Dibayar')),
          const SizedBox(width: 10),
          Expanded(child: _miniStat(Icons.pending_rounded,
              _remainingDays > 0 ? AppColors.warning : AppColors.success,
              '$_remainingDays', 'Sisa Hari')),
        ]),
        const SizedBox(height: 16),

        // Calculation detail
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _calcRow('Total Gaji', '$_totalWorkDays hari × ${AppFormatter.formatRupiah(_ratePerDay)}',
                AppFormatter.formatRupiah(_totalSalary)),
            const SizedBox(height: 6),
            _calcRow('Sudah Dibayar', '$_paidDays hari',
                '- ${AppFormatter.formatRupiah(_totalPaid)}'),
            Divider(color: AppColors.border.withOpacity(0.3), height: 16),
            _calcRow('Sisa Gaji', '$_remainingDays hari',
                AppFormatter.formatRupiah(_remainingSalary),
                isBold: true,
                color: _remainingDays > 0 ? AppColors.warning : AppColors.success),
          ]),
        ),
        
        if (_unpaidDates.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.error.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Tanggal Belum Dibayar (${_unpaidDates.length} hari):',
                      style: AppTextStyles.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  children: _unpaidDates.map((dateStr) {
                    final date = _parseCustomDate(dateStr);
                    final shiftForDate = _shiftLogs.where((l) => l['date'] == dateStr).toList();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.error.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(
                            AppFormatter.formatDate(date),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (shiftForDate.isNotEmpty) ...[
                            ...shiftForDate.map((s) {
                              final shiftName = s['shift']?.toString() ?? 'Kasir';
                              final isPagi = shiftName.toLowerCase().contains('pagi') || shiftName.contains('1');
                              final sTime = s['startTime'] is Timestamp ? (s['startTime'] as Timestamp).toDate() : null;
                              final eTime = s['endTime'] is Timestamp ? (s['endTime'] as Timestamp).toDate() : null;
                              String timeLabel = '';
                              if (sTime != null && eTime != null) {
                                timeLabel = '${AppFormatter.formatTime(sTime)} - ${AppFormatter.formatTime(eTime)}';
                              } else if (sTime != null) {
                                timeLabel = 'Masuk: ${AppFormatter.formatTime(sTime)}';
                              }
                              
                              return Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${isPagi ? "☀️" : "🌙"} $shiftName ${timeLabel.isNotEmpty ? "($timeLabel)" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
                          ] else ...[
                            Text(
                              'Shift Kasir',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        // Rincian Riwayat Jam Kerja Shift
        if (_shiftLogs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Riwayat Jam Masuk & Tutup Shift (${_shiftLogs.length} sesi):',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _shiftLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final log = _shiftLogs[idx];
                    final dateStr = log['date']?.toString() ?? '';
                    final date = _parseCustomDate(dateStr);
                    final shiftName = log['shift']?.toString() ?? 'Kasir';
                    final isPagi = shiftName.toLowerCase().contains('pagi') || shiftName.contains('1');
                    final sTime = log['startTime'] is Timestamp ? (log['startTime'] as Timestamp).toDate() : null;
                    final eTime = log['endTime'] is Timestamp ? (log['endTime'] as Timestamp).toDate() : null;
                    final status = log['status']?.toString() ?? 'closed';
                    final isLive = status == 'active';
                    final startingCash = log['startingCash'] as int? ?? 0;
                    final closingCash = log['closingCash'] as int?;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLive ? AppColors.success.withOpacity(0.08) : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: isLive ? AppColors.success.withOpacity(0.4) : AppColors.border.withOpacity(0.15),
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
                                  Text(isPagi ? '☀️' : '🌙', style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$shiftName • ${AppFormatter.formatDate(date)}',
                                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 12.5),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isLive ? AppColors.success.withOpacity(0.15) : AppColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  isLive ? '🟢 Sedang Bertugas' : '✅ Selesai',
                                  style: TextStyle(
                                    color: isLive ? AppColors.success : AppColors.textSecondary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 14, color: AppColors.textHint),
                              const SizedBox(width: 6),
                              Text(
                                sTime != null && eTime != null
                                    ? 'Jam Kerja: ${AppFormatter.formatTime(sTime)} - ${AppFormatter.formatTime(eTime)} WIB'
                                    : sTime != null
                                        ? 'Jam Masuk: ${AppFormatter.formatTime(sTime)} WIB ${isLive ? "(Belum tutup shift)" : ""}'
                                        : 'Waktu tidak tercatat',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
                              ),
                            ],
                          ),
                          if (startingCash > 0 || closingCash != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.textHint),
                                const SizedBox(width: 6),
                                Text(
                                  'Modal Awal: ${AppFormatter.formatRupiah(startingCash)}${closingCash != null ? " • Kas Akhir: ${AppFormatter.formatRupiah(closingCash)}" : ""}',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Transaksi info
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Row(children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.info, size: 16),
            const SizedBox(width: 8),
            Text('$_totalTransactions transaksi selesai bulan ini',
                style: AppTextStyles.caption.copyWith(color: AppColors.info, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 16),

        // Pay button (khusus admin)
        Consumer<AuthProvider>(builder: (context, auth, _) {
          if (!auth.isAdmin) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border.withOpacity(0.2)),
              ),
              child: Center(
                child: Text(
                  'Hak Akses Input Gaji Khusus Admin',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }

          return SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: _remainingDays > 0 ? _showPaySalaryDialog : null,
              icon: const Icon(Icons.payment_rounded, size: 20),
              label: Text(
                _remainingDays > 0
                    ? 'Input Gaji (Sisa ${AppFormatter.formatRupiah(_remainingSalary)})'
                    : 'Gaji Sudah Lunas ✓',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _remainingDays > 0 ? AppColors.primary : AppColors.success,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md))),
            ),
          );
        }),
      ]),
    );
  }

  Widget _calcRow(String label, String detail, String value,
      {bool isBold = false, Color? color}) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.body.copyWith(
          fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color)),
        Text(detail, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ])),
      Text(value, style: AppTextStyles.body.copyWith(
        fontSize: isBold ? 16 : 13,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
        color: color ?? AppColors.textPrimary)),
    ]);
  }

  Widget _miniStat(IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.subtitle.copyWith(
            fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ]),
    );
  }

  // ── Payment History ──
  Widget _buildPaymentHistory() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.history_rounded, color: AppColors.secondary, size: 22),
        const SizedBox(width: 8),
        Text('Riwayat Pembayaran Gaji', style: AppTextStyles.heading3),
      ]),
      const SizedBox(height: 14),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _fs.streamSalaryPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final payments = snapshot.data ?? [];
          if (payments.isEmpty) {
            return Container(
              width: double.infinity, padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Column(children: [
                Icon(Icons.payment_rounded, size: 48,
                    color: AppColors.textHint.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('Belum ada pembayaran gaji',
                    style: AppTextStyles.bodySecondary),
              ]),
            );
          }
          return Column(children: payments.map((p) {
            final nominal = p['nominal'] as int? ?? 0;
            final paidDays = p['paidDays'] as int? ?? 0;
            final cashier = p['cashierName'] as String? ?? '';
            final method = p['paymentMethod'] as String? ?? '';
            final month = p['month'] as int? ?? 1;
            final year = p['year'] as int? ?? 2024;
            final paidAt = p['paidAt'];
            String paidDate = '-';
            if (paidAt is Timestamp) {
              paidDate = AppFormatter.formatDateTime(paidAt.toDate());
            }

            final proofUrl = p['proofUrl'] as String?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border.withOpacity(0.15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header: Cashier name + days badge
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(cashier,
                      style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Text('$paidDays hari',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ]),
                const SizedBox(height: 12),
                // Detail rows with labels
                _historyDetailRow('Tanggal', paidDate, Icons.calendar_today_rounded),
                const SizedBox(height: 6),
                _historyDetailRow('Periode', '${AppFormatter.getMonthName(month)} $year', Icons.date_range_rounded),
                const SizedBox(height: 6),
                _historyDetailRow('Via', method, Icons.account_balance_rounded),
                Divider(color: AppColors.border.withOpacity(0.2), height: 16),
                // Nominal & Proof Button (prominent)
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  if (proofUrl != null && proofUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            title: const Text('Bukti Pembayaran'),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 450,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: InteractiveViewer(
                                  maxScale: 4.0,
                                  child: Image.network(
                                    proofUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(color: AppColors.primary),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.broken_image_rounded, size: 48, color: AppColors.error),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Tutup'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Lihat Bukti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Nominal', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                      Text(AppFormatter.formatRupiah(nominal),
                          style: AppTextStyles.heading3.copyWith(
                              color: AppColors.success, fontSize: 18)),
                    ],
                  ),
                ]),
              ]),
            );
          }).toList());
        },
      ),
    ]);
  }

  Widget _historyDetailRow(String label, String value, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: AppColors.textHint),
      const SizedBox(width: 8),
      Text('$label:', style: AppTextStyles.caption.copyWith(fontSize: 11)),
      const SizedBox(width: 6),
      Expanded(child: Text(value,
          style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
          textAlign: TextAlign.end)),
    ]);
  }
}
