// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/screens/login_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  final String adminEmail;
  const AdminProfileScreen({super.key, required this.adminEmail});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool isLoading = true;
  Map<String, dynamic>? adminData;
  String? errorMessage;
  final TextEditingController _nikController = TextEditingController();
  String? adminId;
  String? adminNIK;
  String? adminDocId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  // ignore: unused_field
  final bool _isEditing = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('email', isEqualTo: widget.adminEmail)
          .limit(1)
          .get();
      if (userQuery.docs.isNotEmpty) {
        setState(() {
          adminData = userQuery.docs.first.data() as Map<String, dynamic>;
          adminId = userQuery.docs.first.id;
          // ignore: duplicate_ignore
          // ignore: avoid_print
          print(
              '[_loadAdminProfile] Admin ID loaded: $adminId for email: ${widget.adminEmail}');
          isLoading = false;
        });

        // Load existing NIK if available
        await _loadAdminNIK();
      } else {
        setState(() {
          errorMessage = 'Data admin tidak ditemukan';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
      print('[_loadAdminProfile] Error loading admin profile: $e');
    }
  }

  Future<void> _loadAdminNIK() async {
    try {
      QuerySnapshot adminQuery = await FirebaseFirestore.instance
          .collection('admin')
          .where('id_pengguna', isEqualTo: adminId)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        Map<String, dynamic> adminData =
            adminQuery.docs.first.data() as Map<String, dynamic>;
        setState(() {
          adminNIK = adminData['nik'] ?? '';
          _nikController.text = adminData['nik'] ?? '';
          adminDocId = adminQuery.docs.first.id;
          print(
              '[_loadAdminNIK] Existing NIK loaded: $adminNIK for adminId: $adminId');
        });
      }
    } catch (e) {
      print('[_loadAdminNIK] Error loading admin NIK: $e');
    }
  }

  Future<void> _saveNIK() async {
    if (_nikController.text.trim().isEmpty) {
      _showSnackBar('NIK tidak boleh kosong', isError: true);
      return;
    }

    if (_nikController.text.trim().length != 16) {
      _showSnackBar('NIK harus 16 digit', isError: true);
      return;
    }

    // Re-fetch adminId to ensure it's the most current
    String? currentAdminId;
    try {
      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('email', isEqualTo: widget.adminEmail)
          .limit(1)
          .get();
      if (userQuery.docs.isNotEmpty) {
        currentAdminId = userQuery.docs.first.id;
      } else {
        _showSnackBar('Error: Data pengguna admin tidak ditemukan.',
            isError: true);
        print(
            '[_saveNIK] Error: Admin user data not found for email: ${widget.adminEmail}');
        return;
      }
    } catch (e) {
      _showSnackBar('Error memuat ID admin: $e', isError: true);
      print('[_saveNIK] Error re-fetching admin ID: $e');
      return;
    }

    try {
      String newNik = _nikController.text.trim();
      print(
          '[_saveNIK] Attempting to save new NIK: $newNik for adminId: $currentAdminId');

      // Step 1: Find all existing admin documents associated with this adminId
      QuerySnapshot existingAdminQuery = await FirebaseFirestore.instance
          .collection('admin')
          .where('id_pengguna', isEqualTo: currentAdminId)
          .get();

      print(
          '[_saveNIK] Found ${existingAdminQuery.docs.length} existing NIK documents for adminId: $currentAdminId');

      // Step 2: Collect all deletion futures
      List<Future<void>> deleteFutures = [];
      for (var doc in existingAdminQuery.docs) {
        // Log details of documents being considered for deletion
        print(
            '[_saveNIK] Attempting to delete document with ID: ${doc.id} and NIK: ${doc['nik']} for adminId: $currentAdminId');
        deleteFutures.add(FirebaseFirestore.instance
            .collection('admin')
            .doc(doc.id)
            .delete());
      }

      // Step 3: Wait for all deletion operations to complete
      await Future.wait(deleteFutures);
      print(
          '[_saveNIK] All previous NIK documents for adminId: $currentAdminId have been deleted.');

      // Optional: Add a small delay to ensure Firestore consistency, though usually not strictly necessary for single-client operations.
      // await Future.delayed(const Duration(milliseconds: 100));

      // Step 4: Create a new admin record with the new NIK as document ID
      await FirebaseFirestore.instance.collection('admin').doc(newNik).set({
        'id_pengguna': currentAdminId,
        'nik': newNik,
      });

      setState(() {
        adminNIK = newNik; // Update local state
        adminId = currentAdminId; // Ensure adminId in state is also consistent
      });

      _showSnackBar('NIK berhasil disimpan');
      print(
          '[_saveNIK] New NIK $newNik successfully saved for adminId: $currentAdminId');
    } catch (e) {
      print('[_saveNIK] Error saving NIK: $e'); // Log the actual error
      _showSnackBar('Gagal menyimpan NIK: $e', isError: true);
    }
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)), // Green color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        counterText: '',
      ),
    );
  }

  void _showEditProfileDialog() {
    final TextEditingController namaController =
        TextEditingController(text: adminData?['nama'] ?? '');
    // Initialize _nikController with the current adminNIK when the dialog opens
    _nikController.text = adminNIK ?? '';
    final TextEditingController whatsappController =
        TextEditingController(text: adminData?['whatsapp'] ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit Profil',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  controller: namaController,
                  label: 'Nama Lengkap',
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),
                // Add NIK field for admin role
                if (adminData?['role'] == 'admin') ...[
                  _buildDialogTextField(
                    controller: _nikController,
                    label: 'NIK',
                    icon: Icons.credit_card,
                    maxLength: 16,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                ],
                // Show NIP, Kelas, WhatsApp, and info message only for 'walikelas'
                if (adminData?['role'] == 'walikelas') ...[
                  _buildDialogTextField(
                    controller:
                        TextEditingController(text: adminData?['nip'] ?? ''),
                    label: 'NIP',
                    icon: Icons.badge,
                    maxLength: 18,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: TextEditingController(
                        text: adminData?['kelasku'] ?? ''),
                    label: 'Kelas yang Diampu',
                    icon: Icons.class_,
                    maxLength: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: whatsappController,
                    label: 'Nomor WhatsApp',
                    icon: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF81C784).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'NIP, Kelas, dan Nomor WhatsApp akan disimpan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (adminData?['role'] == 'admin') ...[
                  // Info message specifically for admin
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF81C784).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Anda dapat mengubah Nama Lengkap, NIK, dan Nomor WhatsApp.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Info message for other roles
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF81C784).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Anda dapat mengubah Nama Lengkap dan Nomor WhatsApp.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  // Validate Nama
                  if (namaController.text.trim().isEmpty) {
                    _showSnackBar('Nama tidak boleh kosong', isError: true);
                    return;
                  }
                  if (namaController.text.trim().length < 2) {
                    _showSnackBar('Nama minimal 2 karakter', isError: true);
                    return;
                  }

                  // Handle NIK update for admin role
                  if (adminData?['role'] == 'admin') {
                    if (_nikController.text.trim().isEmpty) {
                      _showSnackBar('NIK tidak boleh kosong', isError: true);
                      return;
                    }
                    if (_nikController.text.trim().length != 16) {
                      _showSnackBar('NIK harus 16 digit', isError: true);
                      return;
                    }
                    // Call _saveNIK() only if the NIK value has actually changed
                    if (_nikController.text.trim() != adminNIK) {
                      await _saveNIK(); // This handles its own success/error messages
                    }
                  }

                  // Other profile fields update (nama and whatsapp)
                  await _updateProfile(
                    nama: namaController.text.trim(),
                    whatsapp: whatsappController.text.trim(),
                  );

                  if (mounted) Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child:
                    const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Ubah Kata Sandi',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  controller: currentPasswordController,
                  label: 'Kata Sandi Saat Ini',
                  icon: Icons.lock,
                ),
                const SizedBox(height: 16),
                _buildDialogTextField(
                  controller: newPasswordController,
                  label: 'Kata Sandi Baru',
                  icon: Icons.lock_open,
                ),
                const SizedBox(height: 16),
                _buildDialogTextField(
                  controller: confirmPasswordController,
                  label: 'Konfirmasi Kata Sandi Baru',
                  icon: Icons.lock_outline,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A65), Color(0xFFFF7043)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  await _changePassword(
                    currentPassword: currentPasswordController.text.trim(),
                    newPassword: newPasswordController.text.trim(),
                    confirmPassword: confirmPasswordController.text.trim(),
                  );
                  if (mounted) Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child:
                    const Text('Ubah', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateProfile({
    required String nama,
    String? whatsapp,
  }) async {
    try {
      print('Starting profile update...');
      print('Nama: $nama, WhatsApp: $whatsapp');
      print('Admin ID: $adminId');

      if (adminId == null) {
        throw Exception('Admin ID tidak ditemukan');
      }

      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('email', isEqualTo: widget.adminEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;

        await FirebaseFirestore.instance
            .collection('pengguna')
            .doc(docId)
            .update({
          'nama': nama,
          'whatsapp': whatsapp,
        });

        print('Updated pengguna collection');

        _showSnackBar('Profil berhasil diperbarui');
        _loadAdminProfile(); // Reload to refresh displayed data
      }
    } catch (e) {
      print('Error updating profile: $e');
      _showSnackBar('Gagal memperbarui profil: ${e.toString()}', isError: true);
    }
  }

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar('Semua field harus diisi', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('Konfirmasi kata sandi tidak cocok', isError: true);
      return;
    }
    if (newPassword.length < 6) {
      _showSnackBar('Kata sandi baru minimal 6 karakter', isError: true);
      return;
    }

    try {
      // Re-fetch current password from Firestore for verification
      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('email', isEqualTo: widget.adminEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        Map<String, dynamic> userDataFromDb =
            userQuery.docs.first.data() as Map<String, dynamic>;
        if (userDataFromDb['password'] != currentPassword) {
          _showSnackBar('Kata sandi saat ini salah', isError: true);
          return;
        }

        String docId = userQuery.docs.first.id;
        await FirebaseFirestore.instance
            .collection('pengguna')
            .doc(docId)
            .update({
          'password': newPassword,
        });

        _showSnackBar('Kata sandi berhasil diubah');
        _loadAdminProfile(); // Reload profile to update local state if needed
      } else {
        _showSnackBar('Error: Data pengguna tidak ditemukan.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Gagal mengubah kata sandi: ${e.toString()}',
          isError: true);
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Konfirmasi Keluar',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari aplikasi?',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53E3E), Color(0xFFFC8181)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (mounted) Navigator.of(context).pop();
                  if (mounted)
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child:
                    const Text('Keluar', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFE53E3E)
            : const Color(0xFF4CAF50), // Changed to green for success
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profil Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFFFF3E0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Main Content
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                        ? Center(child: Text(errorMessage!))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              children: [
                                // Profile Header
                                _buildProfileHeader(),
                                const SizedBox(height: 32),
                                // Profile Information
                                _buildProfileInformation(),
                                const SizedBox(height: 32),
                                // Action Buttons
                                _buildActionButtons(),
                                const SizedBox(height: 24),
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

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
            ),
            borderRadius: BorderRadius.circular(60),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF81C784).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          adminData?['nama'] ?? 'Nama tidak tersedia',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFF7043)],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8A65).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Text(
            'Administrator',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInformation() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Profil',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            icon: Icons.person_outline,
            title: 'Nama Lengkap',
            value: adminData?['nama'] ?? 'Belum diisi',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.email_outlined,
            title: 'Email',
            value: adminData?['email'] ?? 'Belum diisi',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.badge_outlined,
            title: 'NIK',
            value: adminNIK ?? 'Belum diisi',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.phone_outlined,
            title: 'WhatsApp',
            value: adminData?['whatsapp'] ?? 'Belum diisi',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF2D3748),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildModernActionButton(
          icon: Icons.edit_outlined,
          title: 'Edit Profil',
          subtitle: 'Ubah nama, NIK, email, dan whatsapp',
          gradient: const [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
          onTap: _showEditProfileDialog,
        ),
        const SizedBox(height: 16),
        _buildModernActionButton(
          icon: Icons.lock_outline,
          title: 'Ubah Kata Sandi',
          subtitle: 'Ganti password admin',
          gradient: const [Color(0xFF81C784), Color(0xFF66BB6A)],
          onTap: _showChangePasswordDialog,
        ),
        const SizedBox(height: 16),
        _buildModernActionButton(
          icon: Icons.logout,
          title: 'Keluar',
          subtitle: 'Logout dari aplikasi',
          gradient: const [Color(0xFFE53E3E), Color(0xFFFC8181)],
          onTap: () => _showLogoutDialog(context),
        ),
      ],
    );
  }

  Widget _buildModernActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient.map((c) => c.withOpacity(0.1)).toList()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gradient[0].withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
