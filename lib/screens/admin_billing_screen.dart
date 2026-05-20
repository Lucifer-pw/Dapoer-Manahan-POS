import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  State<AdminBillingScreen> createState() => _AdminBillingScreenState();
}

class _AdminBillingScreenState extends State<AdminBillingScreen> {
  final _firestoreService = FirestoreService();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin: Kelola Billing'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text('Update Status Pembayaran', style: AppTextStyles.heading3),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Pilih bulan dan tahun terakhir yang sudah dibayar oleh toko ini.', 
                    style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 24),
                  
                  // Month Picker
                  _buildLabel('Bulan'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedMonth,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: AppColors.card,
                      items: List.generate(12, (index) => index + 1).map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(AppFormatter.getMonthName(m)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedMonth = val!),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Year Picker
                  _buildLabel('Tahun'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: AppColors.card,
                      items: [2024, 2025, 2026, 2027].map((y) {
                        return DropdownMenuItem(
                          value: y,
                          child: Text(y.toString()),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedYear = val!),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('UPDATE STATUS PEMBAYARAN'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold));
  }

  Future<void> _saveStatus() async {
    setState(() => _isSaving = true);
    final subProv = Provider.of<SubscriptionProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreService.updateBillingStatus(_selectedMonth, _selectedYear);
      
      await subProv.checkStatus();
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Status billing berhasil diperbarui!')),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
