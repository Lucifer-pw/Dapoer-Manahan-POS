import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/starting_cash_provider.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class ShiftSelectionDialog extends StatefulWidget {
  final bool isDismissible;

  const ShiftSelectionDialog({
    super.key,
    this.isDismissible = false,
  });

  static Future<void> show(BuildContext context, {bool isDismissible = false}) async {
    return showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (_) => ShiftSelectionDialog(isDismissible: isDismissible),
    );
  }

  @override
  State<ShiftSelectionDialog> createState() => _ShiftSelectionDialogState();
}

class _ShiftSelectionDialogState extends State<ShiftSelectionDialog> {
  String _selectedShift = 'Shift 1 (Pagi)';
  final TextEditingController _cashController = TextEditingController(text: '100000');
  bool _isLoading = false;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _submitShift() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cashProv = Provider.of<StartingCashProvider>(context, listen: false);

    final amount = int.tryParse(_cashController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    setState(() => _isLoading = true);

    try {
      // 1. Simpan shift di AuthProvider
      auth.setShift(_selectedShift);

      // 2. Simpan modal awal kasir
      await cashProv.updateStartingCash(
        DateTime.now(),
        amount,
        cashierName: auth.cashierName,
        shift: _selectedShift,
      );

      // 3. Rekam kehadiran otomatis (menjamin hak gaji Rp 50.000)
      if (auth.role != 'owner') {
        await FirestoreService().recordWorkingDay(auth.cashierName, DateTime.now());
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Berhasil memulai $_selectedShift. Selamat bertugas, ${auth.cashierName}!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Gagal memulai shift: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return PopScope(
      canPop: widget.isDismissible,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pilih Shift Kerja', style: AppTextStyles.heading3),
                        const SizedBox(height: 2),
                        Text(
                          'Kasir: ${auth.cashierName}',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isDismissible)
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textHint),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              Text('Pilih Shift Tugas Anda:', style: AppTextStyles.subtitle.copyWith(fontSize: 14)),
              const SizedBox(height: 12),

              // Pilihan Shift Cards
              Row(
                children: [
                  Expanded(
                    child: _buildShiftCard(
                      title: 'Shift 1 (Pagi)',
                      time: '08.00 - 16.00',
                      icon: Icons.wb_sunny_rounded,
                      color: const Color(0xFFFFA726),
                      isSelected: _selectedShift == 'Shift 1 (Pagi)',
                      onTap: () => setState(() => _selectedShift = 'Shift 1 (Pagi)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildShiftCard(
                      title: 'Shift 2 (Malam)',
                      time: '15.45 - Tutup',
                      icon: Icons.nightlight_round,
                      color: const Color(0xFFAB47BC),
                      isSelected: _selectedShift == 'Shift 2 (Malam)',
                      onTap: () => setState(() => _selectedShift = 'Shift 2 (Malam)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Input Modal Awal Kas
              Text('Modal Kas Awal di Laci (Uang Kembalian):', style: AppTextStyles.subtitle.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: AppTextStyles.heading3.copyWith(color: AppColors.primary),
                  hintText: '0',
                  hintStyle: AppTextStyles.heading3.copyWith(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Quick Amount Buttons
              Wrap(
                spacing: 8,
                children: [50000, 100000, 150000, 200000].map((amt) {
                  return InkWell(
                    onTap: () => setState(() => _cashController.text = amt.toString()),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border.withOpacity(0.2)),
                      ),
                      child: Text(
                        AppFormatter.formatRupiah(amt),
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Tombol Buka & Mulai Shift
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitShift,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('Buka & Mulai $_selectedShift', style: AppTextStyles.button),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftCard({
    required String title,
    required String time,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? color : AppColors.border.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 18)
                else
                  Icon(Icons.circle_outlined, color: AppColors.textHint.withOpacity(0.4), size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: AppTextStyles.caption.copyWith(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
