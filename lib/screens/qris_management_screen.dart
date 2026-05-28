import 'dart:io';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class QrisManagementScreen extends StatefulWidget {
  const QrisManagementScreen({super.key});

  @override
  State<QrisManagementScreen> createState() => _QrisManagementScreenState();
}

class _QrisManagementScreenState extends State<QrisManagementScreen> {
  final _firestore = FirestoreService();
  final _storage = StorageService();
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _imageFile;
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _storage.pickImage();
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  Future<void> _uploadQris() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih foto QRIS terlebih dahulu'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final label = _labelController.text.trim();
      final imageUrl = await _storage.uploadQrisImage(
        _imageFile!,
        label,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      await _firestore.addQrisImage(label, imageUrl);

      setState(() {
        _imageFile = null;
        _labelController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QRIS berhasil diunggah'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah QRIS: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteQris(String docId, String imageUrl, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Hapus QRIS', style: AppTextStyles.heading3),
        content: Text('Apakah Anda yakin ingin menghapus QRIS "$label"?', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Check if it's currently selected as active
      final activeConfig = await _firestore.getActiveQrisConfig();
      if (activeConfig['customer']?['id'] == docId) {
        await _firestore.setActiveQris('customer', '', '', '');
      }
      if (activeConfig['cashier']?['id'] == docId) {
        await _firestore.setActiveQris('cashier', '', '', '');
      }

      // Delete storage file
      await _storage.deleteImageByUrl(imageUrl);
      // Delete firestore record
      await _firestore.deleteQrisImage(docId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QRIS berhasil dihapus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus QRIS: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setActiveQris(String target, String docId, String label, String imageUrl) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.setActiveQris(target, docId, label, imageUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QRIS aktif untuk ${target == 'customer' ? 'Pelanggan' : 'Kasir'} berhasil diperbarui'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui QRIS aktif: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel: Configuration & Form
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _buildLeftPanelContents(),
          ),
        ),

        // Divider
        Container(
          width: 1,
          color: AppColors.border.withOpacity(0.2),
          height: double.infinity,
        ),

        // Right Panel: List of Uploaded QRIS
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _buildRightPanelContents(isMobile: false),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeftPanelContents(),
          const SizedBox(height: 32),
          Divider(color: AppColors.border.withOpacity(0.2)),
          const SizedBox(height: 16),
          _buildRightPanelContents(isMobile: true),
        ],
      ),
    );
  }

  Widget _buildLeftPanelContents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active QRIS Configuration Header
        Text('QRIS Aktif Saat Ini', style: AppTextStyles.heading3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 16),
        StreamBuilder<Map<String, dynamic>>(
          stream: _firestore.streamActiveQrisConfig(),
          builder: (context, snapshot) {
            final config = snapshot.data ?? {};
            final customerQris = config['customer'];
            final cashierQris = config['cashier'];

            return Row(
              children: [
                // Customer Active QRIS
                Expanded(
                  child: _buildActiveQrisCard(
                    title: 'Untuk Pelanggan',
                    label: customerQris?['label'],
                    imageUrl: customerQris?['imageUrl'],
                  ),
                ),
                const SizedBox(width: 16),
                // Cashier Active QRIS
                Expanded(
                  child: _buildActiveQrisCard(
                    title: 'Untuk Kasir (Manual)',
                    label: cashierQris?['label'],
                    imageUrl: cashierQris?['imageUrl'],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),

        // Upload New QRIS Section
        Text('Unggah QRIS Baru', style: AppTextStyles.heading3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border.withOpacity(0.2)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Selection Box
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickImage,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 50, color: AppColors.textHint),
                                const SizedBox(height: 12),
                                Text('Pilih Foto QRIS', style: AppTextStyles.bodySecondary),
                                const SizedBox(height: 4),
                                Text('(Klik untuk memilih)', style: AppTextStyles.caption),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Label Textfield
                TextFormField(
                  controller: _labelController,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    labelText: 'Keterangan QRIS (Contoh: QRIS Danang)',
                    labelStyle: AppTextStyles.bodySecondary,
                    prefixIcon: const Icon(Icons.label_outline_rounded, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Keterangan tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Upload Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _uploadQris,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('UNGGAH QRIS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelContents({required bool isMobile}) {
    final streamBuilder = StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestore.streamQrisImages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('Belum ada foto QRIS yang diunggah', style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<Map<String, dynamic>>(
          stream: _firestore.streamActiveQrisConfig(),
          builder: (context, activeSnapshot) {
            final activeConfig = activeSnapshot.data ?? {};
            final activeCustId = activeConfig['customer']?['id'];
            final activeCashId = activeConfig['cashier']?['id'];

            return GridView.builder(
              shrinkWrap: isMobile,
              physics: isMobile ? const NeverScrollableScrollPhysics() : null,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.68,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final docId = item['id'] as String;
                final label = item['label'] as String;
                final imageUrl = item['imageUrl'] as String;

                final isCustActive = activeCustId == docId;
                final isCashActive = activeCashId == docId;

                return _buildQrisItemCard(
                  docId: docId,
                  label: label,
                  imageUrl: imageUrl,
                  isCustActive: isCustActive,
                  isCashActive: isCashActive,
                );
              },
            );
          },
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daftar QRIS Toko', style: AppTextStyles.heading3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 16),
        isMobile ? streamBuilder : Expanded(child: streamBuilder),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Foto QRIS'),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          isMobile ? _buildMobileLayout() : _buildDesktopLayout(),

          // Uploading & Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _uploadProgress > 0 && _uploadProgress < 1.0
                          ? Column(
                              children: [
                                Text('Mengunggah Gambar...', style: AppTextStyles.heading3),
                                const SizedBox(height: 16),
                                LinearProgressIndicator(
                                  value: _uploadProgress,
                                  backgroundColor: AppColors.surface,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                                const SizedBox(height: 8),
                                Text('${(_uploadProgress * 100).toInt()}%', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            )
                          : Column(
                              children: [
                                const CircularProgressIndicator(color: AppColors.primary),
                                const SizedBox(height: 16),
                                Text('Memproses Data...', style: AppTextStyles.body),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveQrisCard({required String title, String? label, String? imageUrl}) {
    final hasActive = label != null && label.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: hasActive ? AppColors.primary.withOpacity(0.5) : AppColors.border.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: hasActive
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.network(
                        imageUrl,
                        key: ValueKey(imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.error));
                        },
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.qr_code_2_rounded, size: 40, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              hasActive ? label : 'Belum diatur',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.bold,
                color: hasActive ? AppColors.textPrimary : AppColors.textHint,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrisItemCard({
    required String docId,
    required String label,
    required String imageUrl,
    required bool isCustActive,
    required bool isCashActive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (isCustActive || isCashActive) ? AppColors.primary.withOpacity(0.5) : AppColors.border.withOpacity(0.2),
          width: (isCustActive || isCashActive) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QRIS Image Thumbnail
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.md),
                    topRight: Radius.circular(AppRadius.md),
                  ),
                  child: Image.network(
                    imageUrl,
                    key: ValueKey(imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.error, size: 40));
                    },
                  ),
                ),
                // Delete button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _deleteQris(docId, imageUrl, label),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                // Target badges
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCustActive)
                        _buildStatusBadge('Pelanggan', AppColors.primary),
                      if (isCashActive) ...[
                        if (isCustActive) const SizedBox(height: 4),
                        _buildStatusBadge('Kasir', AppColors.success),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details & Actions
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Button Pilih Pelanggan
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: isCustActive
                        ? null
                        : () => _setActiveQris('customer', docId, label, imageUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.2),
                      disabledForegroundColor: AppColors.textHint,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                    child: Text(
                      isCustActive ? 'Aktif Pelanggan' : 'Pilih Pelanggan',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Button Pilih Kasir
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: isCashActive
                        ? null
                        : () => _setActiveQris('cashier', docId, label, imageUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.success.withOpacity(0.2),
                      disabledForegroundColor: AppColors.textHint,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                    child: Text(
                      isCashActive ? 'Aktif Kasir' : 'Pilih Kasir',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
