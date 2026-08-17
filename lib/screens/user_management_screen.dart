import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../utils/constants.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'kasir';
    bool obscurePassword = true;
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Tambah Akun Baru', style: AppTextStyles.heading3),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama Lengkap
                    Text('Nama Lengkap', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Luci Handayani',
                        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textHint, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    // Email
                    Text('Email Akun', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Contoh: kasir.luci@gmail.com',
                        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.textHint, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
                        if (!val.contains('@')) return 'Format email tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password
                    Text('Password Awal', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Minimal 6 karakter',
                        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.textHint, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textHint,
                            size: 20,
                          ),
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 6) return 'Password minimal 6 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Role Dropdown
                    Text('Peran (Role)', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          items: const [
                            DropdownMenuItem(
                              value: 'kasir',
                              child: Row(
                                children: [
                                  Icon(Icons.point_of_sale_rounded, color: Color(0xFF66BB6A), size: 18),
                                  SizedBox(width: 10),
                                  Text('Kasir (Staf Operasional POS)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'owner',
                              child: Row(
                                children: [
                                  Icon(Icons.workspace_premium_rounded, color: Color(0xFF42A5F5), size: 18),
                                  SizedBox(width: 10),
                                  Text('Owner (Pemilik Restoran)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 18),
                                  SizedBox(width: 10),
                                  Text('Admin (Akses Penuh Sistem)'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: AppColors.textHint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);

                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      FirebaseApp? tempApp;
                      try {
                        // Inisialisasi Firebase App sekunder agar admin TIDAK ter-logout
                        tempApp = await Firebase.initializeApp(
                          name: 'CreateUserApp_${DateTime.now().millisecondsSinceEpoch}',
                          options: Firebase.app().options,
                        );

                        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
                        final cred = await tempAuth.createUserWithEmailAndPassword(
                          email: email,
                          password: password,
                        );

                        if (cred.user != null) {
                          await cred.user!.updateDisplayName(name);

                          // Simpan data profil & role ke koleksi users di Firestore
                          await _db.collection('users').doc(cred.user!.uid).set({
                            'name': name,
                            'email': email,
                            'role': selectedRole,
                            'createdAt': FieldValue.serverTimestamp(),
                            'isOnline': false,
                          });
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text('Akun $selectedRole "$name" ($email) berhasil dibuat!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.error,
                              content: Text('Gagal membuat akun: $e'),
                            ),
                          );
                        }
                      } finally {
                        await tempApp?.delete();
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Buat Akun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRoleDialog(String docId, String name, String currentRole) {
    String selectedRole = currentRole.toLowerCase();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text('Ubah Role Pengguna', style: AppTextStyles.heading3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih Role Baru untuk "$name":', style: AppTextStyles.body),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(
                        value: 'admin',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 18),
                            SizedBox(width: 10),
                            Text('Admin (Akses Penuh)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'owner',
                        child: Row(
                          children: [
                            Icon(Icons.workspace_premium_rounded, color: Color(0xFF42A5F5), size: 18),
                            SizedBox(width: 10),
                            Text('Owner (Pemilik Restoran)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'kasir',
                        child: Row(
                          children: [
                            Icon(Icons.point_of_sale_rounded, color: Color(0xFF66BB6A), size: 18),
                            SizedBox(width: 10),
                            Text('Kasir (Staf POS)'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: AppColors.textHint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _db.collection('users').doc(docId).set({
                    'role': selectedRole,
                  }, SetOptions(merge: true));

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Role untuk "$name" berhasil diubah menjadi ${selectedRole.toUpperCase()}!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('Gagal mengubah role: $e'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Simpan Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(String targetUid, String targetName, String targetEmail, String targetRole) {
    final adminPasswordController = TextEditingController();
    bool obscureAdminPassword = true;
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();
    final currentAdmin = Provider.of<app_auth.AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA726).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.key_rounded, color: Color(0xFFFFA726), size: 22),
              ),
              const SizedBox(width: 12),
              Text('Reset Password Pengguna', style: AppTextStyles.heading3),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target User Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF66BB6A).withOpacity(0.2),
                            child: const Icon(Icons.person, color: Color(0xFF66BB6A), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  targetName,
                                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$targetEmail (${targetRole.toUpperCase()})',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Link reset password resmi dari Google Firebase akan otomatis dikirimkan ke email akun ini. Demi keamanan, mohon verifikasi password Admin Anda.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Password Admin untuk Verifikasi Keamanan
                    Text('Password Admin Anda (Verifikasi Keamanan)',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: adminPasswordController,
                      obscureText: obscureAdminPassword,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Masukkan password admin Anda',
                        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                        prefixIcon: Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureAdminPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textHint,
                            size: 20,
                          ),
                          onPressed: () => setDialogState(() => obscureAdminPassword = !obscureAdminPassword),
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Password Admin wajib diisi untuk verifikasi';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: AppColors.textHint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);

                      final adminPassword = adminPasswordController.text.trim();

                      try {
                        // 1. Verifikasi Re-autentikasi Admin terlebih dahulu
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser == null || currentUser.email == null) {
                          throw Exception('Sesi login admin tidak valid');
                        }

                        final cred = EmailAuthProvider.credential(
                          email: currentUser.email!,
                          password: adminPassword,
                        );
                        await currentUser.reauthenticateWithCredential(cred);

                        // 2. Kirim email reset password resmi dari Firebase
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: targetEmail);

                        // 3. Rekam jejak audit log keamanan di Firestore
                        await _db.collection('audit_logs').add({
                          'action': 'RESET_PASSWORD_REQUEST',
                          'targetUserId': targetUid,
                          'targetName': targetName,
                          'targetEmail': targetEmail,
                          'targetRole': targetRole,
                          'performedByUid': currentAdmin.user?.uid,
                          'performedByName': currentAdmin.cashierName,
                          'performedByRole': currentAdmin.role,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.success,
                              duration: const Duration(seconds: 4),
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Berhasil! Link reset password telah dikirim ke $targetEmail dan log keamanan telah tercatat.',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                          String errorMsg = 'Verifikasi Admin gagal: ${e.message}';
                          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                            errorMsg = 'Password Admin yang Anda masukkan salah! Reset password dibatalkan.';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: AppColors.error, content: Text(errorMsg)),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: AppColors.error, content: Text('Gagal melakukan reset: $e')),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Kirim Link Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteUser(String docId, String name, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Hapus Akun Pengguna', style: AppTextStyles.heading3),
        content: Text(
          'Yakin ingin menghapus akun "$name" ($email)? Pengguna ini tidak akan bisa lagi login ke sistem.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _db.collection('users').doc(docId).delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('Akun "$name" berhasil dihapus.'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('Gagal menghapus akun: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(Map<String, dynamic> data, bool isOnline) {
    if (isOnline) return 'Online';

    final dynamic lastActiveField = data['lastActive'] ?? data['lastLogin'] ?? data['createdAt'];
    if (lastActiveField == null) return 'Offline';

    DateTime lastActive;
    if (lastActiveField is Timestamp) {
      lastActive = lastActiveField.toDate();
    } else if (lastActiveField is DateTime) {
      lastActive = lastActiveField;
    } else {
      return 'Offline';
    }

    final diff = DateTime.now().difference(lastActive);
    if (diff.inMinutes < 1) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j lalu';
    } else if (diff.inDays == 1) {
      return 'Kemarin';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}h lalu';
    } else {
      return '${lastActive.day}/${lastActive.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = Provider.of<app_auth.AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kelola Akun Pengguna', style: AppTextStyles.heading3),
            Text('Khusus Hak Akses Administrator', style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: const Text('Tambah Akun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error memuat data: ${snapshot.error}', style: TextStyle(color: AppColors.error)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textHint.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Belum ada akun pengguna terdaftar', style: AppTextStyles.subtitle),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddUserDialog,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Buat Akun Pertama'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? 'Tanpa Nama';
              final email = data['email'] as String? ?? '-';
              final role = (data['role'] as String? ?? 'kasir').toLowerCase();
              final isOnline = data['isOnline'] as bool? ?? false;
              final isSelf = doc.id == currentAdmin.user?.uid;

              Color roleColor;
              IconData roleIcon;
              String roleLabel;

              switch (role) {
                case 'admin':
                  roleColor = AppColors.primary;
                  roleIcon = Icons.admin_panel_settings_rounded;
                  roleLabel = 'ADMINISTRATOR';
                  break;
                case 'owner':
                  roleColor = const Color(0xFF42A5F5);
                  roleIcon = Icons.workspace_premium_rounded;
                  roleLabel = 'OWNER';
                  break;
                default:
                  roleColor = const Color(0xFF66BB6A);
                  roleIcon = Icons.point_of_sale_rounded;
                  roleLabel = 'KASIR';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelf ? AppColors.primary.withOpacity(0.4) : AppColors.border.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar Icon
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(roleIcon, color: roleColor, size: 24),
                    ),
                    const SizedBox(width: 14),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Anda',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(email, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),

                    // Role Badge & Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: roleColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            roleLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: roleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isOnline ? const Color(0xFF4CAF50) : AppColors.textHint.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatLastSeen(data, isOnline),
                              style: AppTextStyles.caption.copyWith(
                                color: isOnline ? const Color(0xFF4CAF50) : AppColors.textHint,
                                fontSize: 10,
                                fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Action Buttons (Reset Password, Ubah Role & Hapus)
                    if (!isSelf) ...[
                      const SizedBox(width: 6),
                      if ((currentAdmin.isOwner || (currentAdmin.isAdmin && role == 'kasir')) && role != 'owner')
                        IconButton(
                          icon: const Icon(Icons.key_rounded, color: Color(0xFFFFA726), size: 20),
                          tooltip: 'Reset Password',
                          onPressed: () => _showResetPasswordDialog(doc.id, name, email, role),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                        tooltip: 'Ubah Role',
                        onPressed: () => _showEditRoleDialog(doc.id, name, role),
                      ),
                      if (role != 'admin' && role != 'owner')
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                          tooltip: 'Hapus Akun',
                          onPressed: () => _confirmDeleteUser(doc.id, name, email),
                        ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
