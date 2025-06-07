import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smart_presensee/screens/register_screen.dart';

class StudentScreen extends StatefulWidget {
  final String userEmail;

  const StudentScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nisnController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();

  String? _selectedGender;
  String? _selectedClass;
  bool _isLoading = false;
  String? _walikelasNip;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Gender options with modern styling
  final List<Map<String, String>> _genderOptions = [
    {'label': 'Laki-laki', 'value': 'l'},
    {'label': 'Perempuan', 'value': 'p'},
  ];

  // Class options with modern styling
  final List<Map<String, String>> _classOptions = [
    {'label': '1A', 'value': '1a'},
    {'label': '1B', 'value': '1b'},
    {'label': '2A', 'value': '2a'},
    {'label': '2B', 'value': '2b'},
    {'label': '3A', 'value': '3a'},
    {'label': '3B', 'value': '3b'},
    {'label': '4A', 'value': '4a'},
    {'label': '4B', 'value': '4b'},
    {'label': '5A', 'value': '5a'},
    {'label': '5B', 'value': '5b'},
    {'label': '6A', 'value': '6a'},
    {'label': '6B', 'value': '6b'},
  ];

  @override
  void initState() {
    super.initState();
    _loadWalikelasData();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _nisnController.dispose();
    _namaController.dispose();
    super.dispose();
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
              // Modern App Bar with enhanced animation
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF2E7D32),
                          size: 24,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Tambah Data Siswa',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Content with enhanced animations
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Enhanced Header with icon
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF81C784),
                                          Color(0xFF66BB6A)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.person_add,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Form Data Siswa',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                        Text(
                                          'Lengkapi informasi siswa dengan benar',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Enhanced form fields with better spacing
                              _buildModernTextField(
                                controller: _nisnController,
                                label: 'NISN',
                                hint: 'Masukkan NISN siswa (10 digit)',
                                icon: Icons.badge_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'NISN tidak boleh kosong';
                                  }
                                  if (value.trim().length < 10) {
                                    return 'NISN minimal 10 digit';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              _buildModernTextField(
                                controller: _namaController,
                                label: 'Nama Siswa',
                                hint: 'Masukkan nama lengkap siswa',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Nama siswa tidak boleh kosong';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Nama minimal 2 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              _buildModernDropdown(
                                label: 'Jenis Kelamin',
                                value: _selectedGender,
                                items: _genderOptions,
                                hint: 'Pilih jenis kelamin',
                                icon: Icons.people_outline,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGender = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Jenis kelamin harus dipilih';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              _buildModernDropdown(
                                label: 'Kelas',
                                value: _selectedClass,
                                items: _classOptions,
                                hint: 'Pilih kelas',
                                icon: Icons.class_outlined,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedClass = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Kelas harus dipilih';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 36),

                              // Enhanced Save Button with better animation
                              _buildModernButton(
                                onPressed: _isLoading ? null : _saveStudentData,
                                isLoading: _isLoading,
                                gradient: const [
                                  Color(0xFF81C784),
                                  Color(0xFF66BB6A)
                                ],
                                icon: Icons.save,
                                text: 'Simpan Data',
                              ),
                              const SizedBox(height: 16),

                              // Enhanced Photo Registration Button
                              _buildModernButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                                gradient: const [
                                  Color(0xFFFF8A65),
                                  Color(0xFFFF7043)
                                ],
                                icon: Icons.camera_alt,
                                text: 'Daftarkan Foto Wajah',
                              ),
                              const SizedBox(height: 20),

                              // Info card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFBAE6FD)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Color(0xFF0369A1),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Setelah menyimpan data siswa, jangan lupa untuk mendaftarkan foto wajah untuk sistem presensi.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue[800],
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF81C784),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<Map<String, String>> items,
    required String hint,
    required IconData icon,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF81C784),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item['value'],
              child: Text(
                item['label']!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF374151),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildModernButton({
    required VoidCallback? onPressed,
    required List<Color> gradient,
    required IconData icon,
    required String text,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: gradient),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
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

  Future<void> _loadWalikelasData() async {
    try {
      // First get the user ID from pengguna collection
      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorToast('Data pengguna tidak ditemukan');
        return;
      }

      String userId = userQuery.docs.first.id;

      // Then get the wali kelas data
      QuerySnapshot walikelasQuery = await FirebaseFirestore.instance
          .collection('walikelas')
          .where('id_pengguna', isEqualTo: userId)
          .limit(1)
          .get();

      if (walikelasQuery.docs.isEmpty) {
        _showErrorToast('Data wali kelas tidak ditemukan');
        return;
      }

      Map<String, dynamic> walikelasData =
          walikelasQuery.docs.first.data() as Map<String, dynamic>;

      setState(() {
        _walikelasNip = walikelasData['nip'];
      });
    } catch (e) {
      _showErrorToast('Gagal memuat data wali kelas: ${e.toString()}');
    }
  }

  Future<void> _saveStudentData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_walikelasNip == null) {
      _showErrorToast('Data wali kelas tidak ditemukan');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String nisn = _nisnController.text.trim();
      final String nama = _namaController.text.trim();

      // Check if NISN already exists
      final QuerySnapshot existingStudent = await FirebaseFirestore.instance
          .collection('siswa')
          .where('nisn', isEqualTo: nisn)
          .limit(1)
          .get();

      if (existingStudent.docs.isNotEmpty) {
        _showErrorToast('NISN sudah terdaftar');
        return;
      }

      // Save student data with wali kelas NIP
      await FirebaseFirestore.instance.collection('siswa').doc(nisn).set({
        'nisn': nisn,
        'nama_siswa': nama,
        'jenis_kelamin': _selectedGender,
        'kelas_sw': _selectedClass,
        'nip': _walikelasNip, // Add the wali kelas NIP
      });

      _showSuccessToast('Data siswa berhasil disimpan!');

      // Clear form with animation
      _clearForm();
    } catch (e) {
      _showErrorToast('Terjadi kesalahan: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    _nisnController.clear();
    _namaController.clear();
    setState(() {
      _selectedGender = null;
      _selectedClass = null;
    });
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF81C784),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFFFF8A65),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
