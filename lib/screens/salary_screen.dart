import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});
  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final FirestoreService _fs = FirestoreService();
  final int _ratePerDay = 50000;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<String> _cashierNames = [];
  String? _selectedCashier;
  Map<String, dynamic>? _workData;
  bool _isLoading = true;
  bool _isLoadingWork = false;

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
    final start = DateTime(_selectedYear, _selectedMonth, 1);
    final end = DateTime(_selectedYear, _selectedMonth + 1, 1);
    final data = await _fs.getWorkingDays(_selectedCashier!, start, end);
    if (!mounted) return;
    setState(() {
      _workData = data;
      _isLoadingWork = false;
    });
  }

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
              color: AppColors.textHint.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Pilih Bulan & Tahun', style: AppTextStyles.heading3),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _arrowBtn(Icons.chevron_left_rounded, () => setS(() => tY--)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                child: Text('$tY', style: AppTextStyles.heading2.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: 16),
              _arrowBtn(Icons.chevron_right_rounded,
                  tY < DateTime.now().year ? () => setS(() => tY++) : null),
            ]),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, childAspectRatio: 2.2, crossAxisSpacing: 8, mainAxisSpacing: 8),
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
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(child: Text(
                      _shortMonth(m),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13,
                        color: sel ? Colors.white : future ? AppColors.textHint.withOpacity(0.4) : AppColors.textPrimary),
                    )),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _arrowBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.card : AppColors.card.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border.withOpacity(0.2))),
        child: Icon(icon, size: 24, color: onTap != null ? AppColors.textPrimary : AppColors.textHint),
      ),
    );
  }

  String _shortMonth(int m) {
    const ms = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return ms[m];
  }

  void _showPaySalaryDialog() {
    if (_workData == null || _selectedCashier == null) return;
    final days = _workData!['workingDays'] as int;
    final totalSalary = days * _ratePerDay;
    final nominalCtrl = TextEditingController(text: totalSalary.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) {
          final nominal = int.tryParse(nominalCtrl.text) ?? 0;
          final calcDays = nominal ~/ _ratePerDay;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Bayar Gaji', style: AppTextStyles.heading3),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Kasir', _selectedCashier!),
                _infoRow('Periode', '${AppFormatter.getMonthName(_selectedMonth)} $_selectedYear'),
                _infoRow('Hari Kerja', '$days hari'),
                _infoRow('Rate/Hari', AppFormatter.formatRupiah(_ratePerDay)),
                const SizedBox(height: 16),
                TextField(
                  controller: nominalCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.textPrimary),
                  onChanged: (_) => setD(() {}),
                  decoration: InputDecoration(
                    labelText: 'Nominal Gaji', prefixText: 'Rp ',
                    filled: true, fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.info.withOpacity(0.3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Setara $calcDays hari kerja',
                        style: AppTextStyles.body.copyWith(color: AppColors.info, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Via Transfer Bank BCA',
                        style: AppTextStyles.caption.copyWith(color: AppColors.info, fontSize: 11)),
                    Text('Tanggal: ${AppFormatter.formatDate(DateTime.now())}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.info, fontSize: 11)),
                  ]),
                ),
              ],
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
              ElevatedButton(
                onPressed: nominal > 0 ? () async {
                  await _fs.addSalaryPayment({
                    'cashierName': _selectedCashier,
                    'month': _selectedMonth,
                    'year': _selectedYear,
                    'workingDays': days,
                    'ratePerDay': _ratePerDay,
                    'nominal': nominal,
                    'paidDays': calcDays,
                    'paidAt': Timestamp.fromDate(DateTime.now()),
                    'paymentMethod': 'Transfer Bank BCA',
                  });
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Gaji ${AppFormatter.formatRupiah(nominal)} berhasil dicatat'),
                        backgroundColor: AppColors.success));
                  }
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Bayar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

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
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]),
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
          : ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
              // Cashier selector
              _buildCashierSelector(),
              const SizedBox(height: 20),
              // Working days info
              _buildWorkInfo(),
              const SizedBox(height: 20),
              // Payment history
              _buildPaymentHistory(),
              const SizedBox(height: 20),
            ]),
    );
  }

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
                  Icon(Icons.person_rounded, size: 16, color: sel ? Colors.white : AppColors.textSecondary),
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

  Widget _buildWorkInfo() {
    if (_isLoadingWork) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_workData == null) return const SizedBox.shrink();

    final days = _workData!['workingDays'] as int;
    final transactions = _workData!['totalTransactions'] as int;
    final totalSalary = days * _ratePerDay;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withOpacity(0.08), AppColors.secondary.withOpacity(0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.work_history_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedCashier ?? '', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
            Text('${AppFormatter.getMonthName(_selectedMonth)} $_selectedYear', style: AppTextStyles.caption),
          ])),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _miniStat(Icons.calendar_today_rounded, AppColors.info, '$days', 'Hari Kerja')),
          const SizedBox(width: 12),
          Expanded(child: _miniStat(Icons.receipt_long_rounded, AppColors.success, '$transactions', 'Transaksi')),
          const SizedBox(width: 12),
          Expanded(child: _miniStat(Icons.payments_rounded, AppColors.primary,
              AppFormatter.formatCompact(totalSalary), 'Total Gaji')),
        ]),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '$days hari × ${AppFormatter.formatRupiah(_ratePerDay)} = ${AppFormatter.formatRupiah(totalSalary)}',
              style: AppTextStyles.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w500))),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: days > 0 ? _showPaySalaryDialog : null,
            icon: const Icon(Icons.payment_rounded, size: 20),
            label: const Text('Bayar Gaji', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
          ),
        ),
      ]),
    );
  }

  Widget _miniStat(IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.8), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ]),
    );
  }

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
                Icon(Icons.payment_rounded, size: 48, color: AppColors.textHint.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('Belum ada pembayaran gaji', style: AppTextStyles.bodySecondary),
              ]),
            );
          }
          return Column(children: payments.map((p) {
            final nominal = p['nominal'] as int? ?? 0;
            final paidDays = p['paidDays'] as int? ?? 0;
            final month = p['month'] as int? ?? 1;
            final year = p['year'] as int? ?? 2024;
            final cashier = p['cashierName'] as String? ?? '';
            final method = p['paymentMethod'] as String? ?? '';
            final paidAt = p['paidAt'];
            String paidDate = '';
            if (paidAt is Timestamp) {
              paidDate = AppFormatter.formatDate(paidAt.toDate());
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border.withOpacity(0.15))),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cashier, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${AppFormatter.getMonthName(month)} $year • $paidDays hari',
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  Text('$method • $paidDate',
                      style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textHint)),
                ])),
                Text(AppFormatter.formatRupiah(nominal),
                    style: AppTextStyles.priceSmall.copyWith(color: AppColors.success)),
              ]),
            );
          }).toList());
        },
      ),
    ]);
  }
}
