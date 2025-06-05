import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/screens/login_screen.dart';
import 'dart:developer';

class ProfileScreen extends StatefulWidget {
  final String userEmail;

  const ProfileScreen({super.key, required this.userEmail});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  bool isLoading = true;
  Map<String, dynamic>? userData;
  Map<String, dynamic>? walkelasData;
  String? errorMessage;
  String? userIdPengguna;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      log('Loading profile for email: ${widget.userEmail}');

      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        Map<String, dynamic> userDataTemp =
            userQuery.docs.first.data() as Map<String, dynamic>;
        String userId = userDataTemp['id_pengguna'] ?? userQuery.docs.first.id;

        setState(() {
          userData = userDataTemp;
          userIdPengguna = userId;
        });

        log('User data loaded successfully: $userData');
        log('User ID: $userIdPengguna');

        await _loadWalikelasData(userId);

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Data pengguna tidak ditemukan';
          isLoading = false;
        });
        log('User not found for email: ${widget.userEmail}');
      }
    } catch (e) {
      log('Error loading user profile: $e');
      setState(() {
        errorMessage = 'Terjadi kesalahan: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _loadWalikelasData(String idPengguna) async {
    try {
      log('Loading walikelas data for id_pengguna: $idPengguna');

      QuerySnapshot walkelasQuery = await FirebaseFirestore.instance
          .collection('walikelas')
          .where('id_pengguna', isEqualTo: idPengguna)
          .limit(1)
          .get();

      if (walkelasQuery.docs.isNotEmpty) {
        setState(() {
          walkelasData =
              walkelasQuery.docs.first.data() as Map<String, dynamic>;
        });
        log('Walikelas data loaded: $walkelasData');
      } else {
        setState(() {
          walkelasData = null;
        });
        log('No walikelas data found for id_pengguna: $idPengguna');
      }
    } catch (e) {
      log('Error loading walikelas data: $e');
      setState(() {
        walkelasData = null;
      });
    }
  }

  String _formatRole(String? role) {
    if (role == null) return 'Tidak diketahui';
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'walikelas':
        return 'Wali Kelas';
      default:
        return role.toUpperCase();
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tidak diketahui';

    DateTime date = timestamp.toDate();
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8), // Light pastel green
              Color(0xFFFFF3E0), // Light pastel orange
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern App Bar
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF2E7D32),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profil Saya',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            Text(
                              'Kelola informasi profil Anda',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Refresh button
                      GestureDetector(
                        onTap: _loadUserProfile,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Color(0xFF2E7D32),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Content
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: isLoading
                        ? _buildLoadingState()
                        : errorMessage != null
                            ? _buildErrorState()
                            : _buildProfileContent(),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Memuat profil...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFFE53E3E),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gagal Memuat Profil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
                ),
              ),
              child: ElevatedButton(
                onPressed: _loadUserProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
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

          // Logout Button
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Profile Picture with gradient background
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
            Icons.person,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        // User Name
        Text(
          userData?['nama'] ?? 'Nama tidak tersedia',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // User Role Badge
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
          child: Text(
            _formatRole(userData?['role']),
            style: const TextStyle(
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
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Profil',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 20),
          _buildModernInfoCard(
            icon: Icons.person_outline,
            label: 'Nama Lengkap',
            value: userData?['nama'] ?? 'Tidak tersedia',
            color: const Color(0xFF81C784),
          ),
          const SizedBox(height: 16),
          _buildModernInfoCard(
            icon: Icons.badge_outlined,
            label: 'NIP',
            value: walkelasData?['nip'] ?? 'Belum diisi',
            color: const Color(0xFFFF8A65),
          ),
          const SizedBox(height: 16),
          _buildModernInfoCard(
            icon: Icons.email_outlined,
            label: 'Email',
            value: userData?['email'] ?? 'Tidak tersedia',
            color: const Color(0xFF81C784),
          ),
          // Add WhatsApp number for 'walikelas' role
          if (userData?['role'] == 'walikelas' &&
              userData?['whatsapp'] != null) ...[
            const SizedBox(height: 16),
            _buildModernInfoCard(
              icon: Icons.phone_outlined,
              label: 'Nomor WhatsApp',
              value: userData?['whatsapp'] ?? 'Tidak tersedia',
              color: const Color(0xFF81C784),
            ),
          ],
          const SizedBox(height: 16),
          _buildModernInfoCard(
            icon: Icons.class_outlined,
            label: 'Kelas yang Diampu',
            value: walkelasData?['kelasku'] ?? 'Belum diisi',
            color: const Color(0xFFFF8A65),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
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
          subtitle: 'Ubah nama, NIP, dan kelas',
          gradient: const [Color(0xFF81C784), Color(0xFF66BB6A)],
          onTap: _showEditProfileDialog,
        ),
        const SizedBox(height: 16),
        _buildModernActionButton(
          icon: Icons.lock_outline,
          title: 'Ubah Kata Sandi',
          subtitle: 'Ganti password akun',
          gradient: const [Color(0xFFFF8A65), Color(0xFFFF7043)],
          onTap: _showChangePasswordDialog,
        ),
        const SizedBox(height: 16),
        _buildModernActionButton(
          icon: Icons.help_outline,
          title: 'Panduan Wali Kelas',
          subtitle: 'Cara Mengubah File CSV Menjadi File Excel (XLSX)',
          gradient: const [Color(0xFF64B5F6), Color(0xFF42A5F5)],
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text(
                      'Panduan Wali Kelas: Cara Mengubah File CSV Menjadi File Excel (XLSX) Supaya Datanya Rapi'),
                  content: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '📘 Panduan untuk Wali Kelas: Mengubah File CSV ke Excel (XLSX) Supaya Datanya Rapi'),
                        SizedBox(height: 8),
                        Text('Berikut cara mudah merapikan data CSV di Excel:'),
                        SizedBox(height: 8),
                        Text('✨ Langkah 1: Buka File CSV'),
                        Text('1. Buka aplikasi Microsoft Excel.'),
                        Text(
                            '2. Klik menu File > Open lalu cari file CSV yang diberikan (misalnya: `laporan_kehadiran_02052025.csv`).'),
                        Text(
                            '3. Setelah terbuka, mungkin datanya terlihat berantakan di satu kolom. Tidak perlu panik 😊'),
                        SizedBox(height: 8),
                        Text('✨ Langkah 2: Pisahkan Data ke Kolom'),
                        Text(
                            '1. Klik pada kolom A (tempat semua data berada).'),
                        Text('2. Klik menu Data di bagian atas Excel.'),
                        Text(
                            '3. Pilih tombol Text to Columns (ikon ini akan membantu kita memisahkan data ke kolom yang benar).'),
                        SizedBox(height: 8),
                        Text('✨ Langkah 3: Atur Pemisah Data'),
                        Text('1. Pilih opsi Delimited lalu klik Next.'),
                        Text('2. Cek pemisah (delimiter) yang digunakan:'),
                        Text('   * Centang Tab'),
                        Text('   * Centang Comma (koma)'),
                        Text('   * Centang Semicolon (titik koma)'),
                        Text('3. Klik Next, lalu klik Finish.'),
                        SizedBox(height: 8),
                        Text(
                            '📌 Sekarang data sudah terbagi rapi ke kolom masing-masing!'),
                        SizedBox(height: 8),
                        Text('✨ Langkah 4: Simpan Sebagai File Excel (XLSX)'),
                        Text('1. Klik menu File > Save As.'),
                        Text('2. Pilih lokasi penyimpanan.'),
                        Text(
                            '3. Ganti jenis file menjadi Excel Workbook (.xlsx).'),
                        Text('4. Klik Save.'),
                        SizedBox(height: 8),
                        Text('✅ Selesai!'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ],
                );
              },
            );
          },
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

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFE53E3E), Color(0xFFFC8181)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53E3E).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _showLogoutDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'Keluar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog methods (keeping the existing implementation but with modern styling)
  void _showEditProfileDialog() {
    final TextEditingController namaController =
        TextEditingController(text: userData?['nama'] ?? '');
    final TextEditingController nipController =
        TextEditingController(text: walkelasData?['nip'] ?? '');
    final TextEditingController kelasController =
        TextEditingController(text: walkelasData?['kelasku'] ?? '');
    final TextEditingController whatsappController =
        TextEditingController(text: userData?['whatsapp'] ?? '');

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
                // Show NIP, Kelas, WhatsApp, and info message only for 'walikelas'
                if (userData?['role'] == 'walikelas') ...[
                  _buildDialogTextField(
                    controller: nipController,
                    label: 'NIP',
                    icon: Icons.badge,
                    maxLength: 18,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: kelasController,
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
                            'Anda dapat mengubah Nama Lengkap saja.',
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
                  if (namaController.text.trim().isEmpty) {
                    _showSnackBar('Nama tidak boleh kosong', isError: true);
                    return;
                  }
                  if (namaController.text.trim().length < 2) {
                    _showSnackBar('Nama minimal 2 karakter', isError: true);
                    return;
                  }
                  if (userData?['role'] == 'walikelas') {
                    if (nipController.text.trim().length > 18) {
                      _showSnackBar('NIP maksimal 18 karakter', isError: true);
                      return;
                    }
                    if (kelasController.text.trim().length > 2) {
                      _showSnackBar('Kelas maksimal 2 karakter', isError: true);
                      return;
                    }
                  }

                  await _updateProfile(
                    nama: namaController.text.trim(),
                    nip: userData?['role'] == 'walikelas'
                        ? nipController.text.trim()
                        : null,
                    kelas: userData?['role'] == 'walikelas'
                        ? kelasController.text.trim()
                        : null,
                    whatsapp: userData?['role'] == 'walikelas'
                        ? whatsappController.text.trim()
                        : null,
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
        prefixIcon: Icon(icon, color: const Color(0xFF81C784)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
        ),
        counterText: '',
      ),
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
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
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
        backgroundColor:
            isError ? const Color(0xFFE53E3E) : const Color(0xFF81C784),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Keep existing update methods but add modern styling for success messages
  Future<void> _updateProfile({
    required String nama,
    String? nip,
    String? kelas,
    String? whatsapp,
  }) async {
    try {
      log('Starting profile update...');
      log('Nama: $nama, NIP: $nip, Kelas: $kelas, WhatsApp: $whatsapp');
      log('User ID Pengguna: $userIdPengguna');

      if (userIdPengguna == null) {
        throw Exception('User ID tidak ditemukan');
      }

      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;

        await FirebaseFirestore.instance
            .collection('pengguna')
            .doc(docId)
            .update({
          'nama': nama,
          'updated_at': FieldValue.serverTimestamp(),
        });

        log('Updated pengguna collection');

        await _updateWalikelasData(nip, kelas, whatsapp);

        _showSnackBar('Profil berhasil diperbarui');
        _loadUserProfile();
      }
    } catch (e) {
      log('Error updating profile: $e');
      _showSnackBar('Gagal memperbarui profil: ${e.toString()}', isError: true);
    }
  }

  Future<void> _updateWalikelasData(
      String? nip, String? kelas, String? whatsapp) async {
    try {
      if (nip == null && kelas == null && whatsapp == null) {
        await _deleteWalikelasData();
        return;
      }

      if (nip == null || kelas == null) {
        throw Exception(
            'NIP dan Kelas harus diisi bersamaan atau dikosongkan bersamaan');
      }

      QuerySnapshot existingWalikelas = await FirebaseFirestore.instance
          .collection('walikelas')
          .where('id_pengguna', isEqualTo: userIdPengguna)
          .limit(1)
          .get();

      if (existingWalikelas.docs.isNotEmpty) {
        String walkelasDocId = existingWalikelas.docs.first.id;

        await FirebaseFirestore.instance
            .collection('walikelas')
            .doc(walkelasDocId)
            .update({
          'nip': nip,
          'kelasku': kelas,
          'whatsapp': whatsapp,
          'updated_at': FieldValue.serverTimestamp(),
        });

        log('Updated existing walikelas record: $walkelasDocId');
      } else {
        await FirebaseFirestore.instance.collection('walikelas').doc(nip).set({
          'nip': nip,
          'id_pengguna': userIdPengguna,
          'kelasku': kelas,
          'whatsapp': whatsapp,
          'created_at': FieldValue.serverTimestamp(),
        });

        log('Created new walikelas record with NIP: $nip');
      }
    } catch (e) {
      log('Error updating walikelas data: $e');
      rethrow;
    }
  }

  Future<void> _deleteWalikelasData() async {
    try {
      QuerySnapshot existingWalikelas = await FirebaseFirestore.instance
          .collection('walikelas')
          .where('id_pengguna', isEqualTo: userIdPengguna)
          .limit(1)
          .get();

      if (existingWalikelas.docs.isNotEmpty) {
        String walkelasDocId = existingWalikelas.docs.first.id;

        await FirebaseFirestore.instance
            .collection('walikelas')
            .doc(walkelasDocId)
            .delete();

        log('Deleted walikelas record: $walkelasDocId');

        setState(() {
          walkelasData = null;
        });
      }
    } catch (e) {
      log('Error deleting walikelas data: $e');
      rethrow;
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
      if (userData?['password'] != currentPassword) {
        _showSnackBar('Kata sandi saat ini salah', isError: true);
        return;
      }

      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;

        await FirebaseFirestore.instance
            .collection('pengguna')
            .doc(docId)
            .update({
          'password': newPassword,
        });

        _showSnackBar('Kata sandi berhasil diubah');
        _loadUserProfile();
      }
    } catch (e) {
      log('Error changing password: $e');
      _showSnackBar('Gagal mengubah kata sandi: ${e.toString()}',
          isError: true);
    }
  }
}
