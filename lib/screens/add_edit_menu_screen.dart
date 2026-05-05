import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/menu_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class AddEditMenuScreen extends StatefulWidget {
  final MenuItem? menuItem;

  const AddEditMenuScreen({super.key, this.menuItem});

  @override
  State<AddEditMenuScreen> createState() => _AddEditMenuScreenState();
}

class _AddEditMenuScreenState extends State<AddEditMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedCategory;
  bool _isAvailable = true;
  File? _imageFile;
  String _imageUrl = '';
  bool _isLoading = false;

  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    if (widget.menuItem != null) {
      _nameController.text = widget.menuItem!.name;
      _priceController.text = widget.menuItem!.price.toString();
      _descController.text = widget.menuItem!.description;
      _selectedCategory = widget.menuItem!.categoryId;
      _isAvailable = widget.menuItem!.isAvailable;
      _imageUrl = widget.menuItem!.imageUrl;
    } else {
      // Set default category if available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final categories = Provider.of<MenuProvider>(context, listen: false).categories;
        if (categories.isNotEmpty) {
          setState(() {
            _selectedCategory = categories.first.id;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _storage.pickImage();
    if (file != null) {
      setState(() {
        _imageFile = file;
      });
    }
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String finalImageUrl = _imageUrl;
      final isNew = widget.menuItem == null;
      final docId = isNew ? DateTime.now().millisecondsSinceEpoch.toString() : widget.menuItem!.id;

      // Upload image if new file selected
      if (_imageFile != null) {
        finalImageUrl = await _storage.uploadMenuImage(_imageFile!, docId);
      }

      final newItem = MenuItem(
        id: isNew ? '' : widget.menuItem!.id,
        categoryId: _selectedCategory!,
        name: _nameController.text.trim(),
        price: int.parse(_priceController.text.trim()),
        description: _descController.text.trim(),
        imageUrl: finalImageUrl,
        isAvailable: _isAvailable,
      );

      if (isNew) {
        await _firestore.addMenuItem(newItem);
      } else {
        await _firestore.updateMenuItem(newItem);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNew ? 'Menu ditambahkan' : 'Menu diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
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

  Future<void> _deleteMenu() async {
    if (widget.menuItem == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Hapus Menu', style: AppTextStyles.heading3),
        content: Text('Yakin ingin menghapus ${widget.menuItem!.name}?', style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _firestore.deleteMenuItem(widget.menuItem!.id);
        if (widget.menuItem!.imageUrl.isNotEmpty) {
           await _storage.deleteMenuImage(widget.menuItem!.id);
        }
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.menuItem != null;
    final categories = Provider.of<MenuProvider>(context).categories;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(isEditing ? 'Edit Menu' : 'Tambah Menu', style: AppTextStyles.heading3),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: _isLoading ? null : _deleteMenu,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                                )
                              : _imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.lg),
                                      child: Image.network(_imageUrl, fit: BoxFit.cover),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo, size: 40, color: AppColors.textHint),
                                        const SizedBox(height: 8),
                                        Text('Pilih Foto', style: AppTextStyles.caption),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category Dropdown
                    Text('Kategori', style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          dropdownColor: AppColors.card,
                          hint: Text('Pilih Kategori', style: AppTextStyles.bodySecondary),
                          items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: AppTextStyles.body))).toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nama Menu',
                      validator: (val) => val == null || val.isEmpty ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 16),

                    // Price
                    _buildTextField(
                      controller: _priceController,
                      label: 'Harga (Rp)',
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Harga tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildTextField(
                      controller: _descController,
                      label: 'Deskripsi (Opsional)',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Availability Toggle
                    SwitchListTile(
                      title: Text('Menu Tersedia', style: AppTextStyles.body),
                      subtitle: Text('Matikan jika menu sedang habis', style: AppTextStyles.caption),
                      value: _isAvailable,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _isAvailable = val),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saveMenu,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        child: Text('SIMPAN', style: AppTextStyles.button),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTextStyles.body,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.bodySecondary,
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }
}
