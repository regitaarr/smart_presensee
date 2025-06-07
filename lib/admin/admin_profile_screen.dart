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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isEditing = false;
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
        });
      }
    } catch (e) {
      print('Error loading admin NIK: $e');
    }
  }

  Future<void> _saveNIK() async {
    if (_nikController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NIK tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_nikController.text.trim().length != 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NIK harus 16 digit'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String nik = _nikController.text.trim();
      QuerySnapshot existingAdmin = await FirebaseFirestore.instance
          .collection('admin')
          .where('id_pengguna', isEqualTo: adminId)
          .limit(1)
          .get();

      if (existingAdmin.docs.isNotEmpty) {
        // Update existing admin record
        await FirebaseFirestore.instance
            .collection('admin')
            .doc(existingAdmin.docs.first.id)
            .update({
          'nik': nik,
        });
      } else {
        // Create new admin record using NIK as document ID
        await FirebaseFirestore.instance.collection('admin').doc(nik).set({
          'id_pengguna': adminId,
          'nik': nik,
        });
      }

      setState(() {
        adminNIK = nik;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NIK berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan NIK: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changePasswordDialog() async {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ubah Kata Sandi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Kata Sandi Saat Ini',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Kata Sandi Baru',
                  prefixIcon: Icon(Icons.lock_open),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Kata Sandi Baru',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final current = currentPasswordController.text.trim();
              final newPass = newPasswordController.text.trim();
              final confirm = confirmPasswordController.text.trim();
              if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                _showSnackBar('Semua field harus diisi', isError: true);
                return;
              }
              if (newPass != confirm) {
                _showSnackBar('Konfirmasi kata sandi tidak cocok',
                    isError: true);
                return;
              }
              if (newPass.length < 6) {
                _showSnackBar('Kata sandi baru minimal 6 karakter',
                    isError: true);
                return;
              }
              if (adminData?['password'] != current) {
                _showSnackBar('Kata sandi saat ini salah', isError: true);
                return;
              }
              try {
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
                    'password': newPass,
                  });
                  _showSnackBar('Kata sandi berhasil diubah');
                  if (mounted) Navigator.of(context).pop();
                }
              } catch (e) {
                _showSnackBar('Gagal mengubah kata sandi: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Ubah', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Keluar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    List<String> months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
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
          onTap: _changePasswordDialog,
        ),
        const SizedBox(height: 16),
        _buildModernActionButton(
          icon: Icons.logout,
          title: 'Keluar',
          subtitle: 'Logout dari aplikasi',
          gradient: const [Color(0xFFE53E3E), Color(0xFFFC8181)],
          onTap: _showLogoutDialog,
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

  void _showEditProfileDialog() {
    _nameController.text = adminData?['nama'] ?? '';
    _nikController.text = adminNIK ?? '';
    _whatsappController.text = adminData?['whatsapp'] ?? '';
    _emailController.text = adminData?['email'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profil'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nikController,
                  decoration: InputDecoration(
                    labelText: 'NIK',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.badge),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'NIK tidak boleh kosong';
                    }
                    if (value.length != 16) {
                      return 'NIK harus 16 digit';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value)) {
                      return 'NIK harus berupa angka';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _whatsappController,
                  decoration: InputDecoration(
                    labelText: 'WhatsApp',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'WhatsApp tidak boleh kosong';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value)) {
                      return 'WhatsApp harus berupa angka';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _updateProfile();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    try {
      // Update pengguna collection
      await FirebaseFirestore.instance
          .collection('pengguna')
          .doc(adminId)
          .update({
        'nama': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
      });

      // Update admin collection
      final nik = _nikController.text.trim();
      await FirebaseFirestore.instance.collection('admin').doc(nik).set({
        'nik': nik,
        'id_pengguna': adminId,
      });

      setState(() {
        adminNIK = nik;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui profil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
