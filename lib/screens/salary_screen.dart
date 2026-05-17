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

  // Data
  int _totalWorkDays = 0;
  int _totalPaid = 0;
  int _totalTransactions = 0;
  bool _isLoading = true;
  bool _isLoadingWork = false;

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

    final start = DateTime(_selectedYear, _selectedMonth, 1);
    final end = DateTime(_selectedYear, _selectedMonth + 1, 1);

    // Run both queries in parallel for speed
    final results = await Future.wait([
      _fs.getWorkingDays(_selectedCashier!, start, end),
      _fs.getTotalPaidForCashier(_selectedCashier!, _selectedMonth, _selectedYear),
    ]);

    if (!mounted) return;
    final workData = results[0] as Map<String, dynamic>;
    final paid = results[1] as int;
    setState(() {
      _totalWorkDays = workData['workingDays'] as int;
      _totalTransactions = workData['totalTransactions'] as int;
      _totalPaid = paid;
      _isLoadingWork = false;
    });
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

  // ── Input Gaji Dialog ──
  void _showPaySalaryDialog() {
    if (_selectedCashier == null || _remainingDays <= 0) return;
    final nominalCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) {
          final nominal = int.tryParse(nominalCtrl.text) ?? 0;
          final calcDays = nominal ~/ _ratePerDay;
          final isValid = nominal > 0 && calcDays <= _remainingDays;

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
                const SizedBox(height: 12),
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
                    ] else
                      Text('Masukkan nominal untuk menghitung',
                          style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    const SizedBox(height: 6),
                    Text('Via Transfer Bank BCA',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint, fontSize: 11)),
                    Text('Tanggal: ${AppFormatter.formatDate(DateTime.now())}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint, fontSize: 11)),
                  ]),
                ),
              ],
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
              ElevatedButton(
                onPressed: isValid ? () async {
                  await _fs.addSalaryPayment({
                    'cashierName': _selectedCashier,
                    'month': _selectedMonth,
                    'year': _selectedYear,
                    'workingDays': _totalWorkDays,
                    'ratePerDay': _ratePerDay,
                    'nominal': nominal,
                    'paidDays': calcDays,
                    'paidAt': Timestamp.fromDate(DateTime.now()),
                    'paymentMethod': 'Transfer Bank BCA',
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _loadWorkingDays(); // refresh data
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text('Gaji ${AppFormatter.formatRupiah(nominal)} ($calcDays hari) berhasil dicatat'),
                    backgroundColor: AppColors.success));
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
                _buildSalaryCard(),
                const SizedBox(height: 20),
                _buildPaymentHistory(),
                const SizedBox(height: 20),
              ]),
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

        // Pay button
        SizedBox(
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
        ),
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
                // Nominal (prominent)
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Nominal', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                  Text(AppFormatter.formatRupiah(nominal),
                      style: AppTextStyles.heading3.copyWith(
                          color: AppColors.success, fontSize: 18)),
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
