import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class AdminStudentList extends StatefulWidget {
  const AdminStudentList({super.key});

  @override
  State<AdminStudentList> createState() => _AdminStudentListState();
}

class _AdminStudentListState extends State<AdminStudentList> {
  bool isLoading = true;
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filteredStudents = [];
  List<Map<String, dynamic>> walikelasList = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedClass;
  String? _selectedGender;
  final List<String> _classList = [
    '1A',
    '1B',
    '2A',
    '2B',
    '3A',
    '3B',
    '4A',
    '4B',
    '5A',
    '5B',
    '6A',
    '6B'
  ];

  final List<String> classOptions = [
    '1A',
    '1B',
    '2A',
    '2B',
    '3A',
    '3B',
    '4A',
    '4B',
    '5A',
    '5B',
    '6A',
    '6B'
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadWalikelas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStudents(String query) {
    setState(() {
      filteredStudents = students.where((student) {
        final name = student['nama_siswa']?.toString().toLowerCase() ?? '';
        final nis = student['nisn']?.toString().toLowerCase() ?? '';
        final kelas = _formatClass(student['kelas_sw']).toLowerCase();
        final gender = student['jenis_kelamin']?.toString().toLowerCase() ?? '';

        final matchesQuery = name.contains(query.toLowerCase()) ||
            nis.contains(query.toLowerCase());
        final matchesClass =
            _selectedClass == null || kelas == _selectedClass!.toLowerCase();
        final matchesGender =
            _selectedGender == null || gender == _selectedGender!.toLowerCase();

        return matchesQuery && matchesClass && matchesGender;
      }).toList();
    });
  }

  Future<void> _loadStudents() async {
    setState(() {
      isLoading = true;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('siswa').get();
      students = snapshot.docs.map((doc) => doc.data()).toList();
      _filterStudents(_searchController.text);
    } catch (e) {
      developer.log('Error loading students: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data siswa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWalikelas() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('walikelas')
          .get();
      
      setState(() {
        walikelasList = snapshot.docs.map((doc) {
          var data = doc.data();
          data['nip'] = doc.id; // Use document ID as NIP
          return data;
        }).toList();
      });
      
      developer.log('Loaded ${walikelasList.length} wali kelas');
    } catch (e) {
      developer.log('Error loading walikelas: $e');
    }
  }

  String _formatClass(String? kelas) {
    if (kelas == null) return 'Kelas tidak tersedia';
    return kelas.replaceAll('_', ' ').toUpperCase();
  }

  String _formatGender(String? gender) {
    if (gender == null) return 'Tidak tersedia';
    if (gender.toUpperCase() == 'L') return 'Laki-laki';
    if (gender.toUpperCase() == 'P') return 'Perempuan';
    return 'Tidak tersedia';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Daftar Data Siswa',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddStudentDialog,
            tooltip: 'Tambah Siswa',
          ),
        ],
      ),
      body: _buildStudentList(),
    );
  }

  Widget _buildStudentList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cari & Filter',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari siswa...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: _filterStudents,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedClass,
                          hint: const Text('Semua Kelas'),
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: 'Semua Kelas',
                              child: Text('Semua Kelas'),
                            ),
                            ..._classList.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedClass = newValue;
                              _filterStudents(_searchController.text);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedGender,
                          hint: const Text('Semua Jenis Kelamin'),
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'L',
                              child: Text('Laki-laki'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'P',
                              child: Text('Perempuan'),
                            ),
                          ],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedGender = newValue;
                              _filterStudents(_searchController.text);
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Student List
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
            )
          else if (filteredStudents.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada siswa ditemukan',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF4CAF50),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Student Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['nama_siswa'] ?? 'Nama tidak tersedia',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'NISN: ${student['nisn']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kelas: ${_formatClass(student['kelas_sw'])}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Jenis Kelamin: ${_formatGender(student['jenis_kelamin'])}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Action Buttons
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit',
                              onPressed: () => _showEditStudentDialog(student),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.withOpacity(0.1),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Hapus',
                              onPressed: () => _showDeleteConfirmation(student),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    final formKey = GlobalKey<FormState>();
    final nisnController = TextEditingController();
    final namaController = TextEditingController();
    final emailOrangtuaController = TextEditingController();
    final telpOrangtuaController = TextEditingController();
    String? selectedClass;
    String? selectedGender;
    String? selectedNip;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tambah Data Siswa',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NISN Field
                        TextFormField(
                          controller: nisnController,
                          decoration: InputDecoration(
                            labelText: 'NISN *',
                            hintText: 'Masukkan 10 digit NISN',
                            prefixIcon: const Icon(Icons.badge),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'NISN harus diisi';
                            }
                            if (value.length != 10) {
                              return 'NISN harus 10 digit';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Nama Siswa Field
                        TextFormField(
                          controller: namaController,
                          decoration: InputDecoration(
                            labelText: 'Nama Siswa *',
                            hintText: 'Masukkan nama lengkap siswa',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama siswa harus diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Jenis Kelamin Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedGender,
                          decoration: InputDecoration(
                            labelText: 'Jenis Kelamin *',
                            prefixIcon: const Icon(Icons.wc),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: const [
                            DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                            DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedGender = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Jenis kelamin harus dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Kelas Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedClass,
                          decoration: InputDecoration(
                            labelText: 'Kelas *',
                            prefixIcon: const Icon(Icons.class_),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: classOptions.map((kelas) {
                            return DropdownMenuItem(
                              value: kelas.toLowerCase(),
                              child: Text(kelas),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedClass = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Kelas harus dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Wali Kelas Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedNip,
                          decoration: InputDecoration(
                            labelText: 'Wali Kelas *',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: walikelasList.map<DropdownMenuItem<String>>((walikelas) {
                            return DropdownMenuItem<String>(
                              value: walikelas['nip'] as String,
                              child: Text('${walikelas['nip']} - Kelas ${walikelas['kelasku']?.toString().toUpperCase()}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedNip = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Wali kelas harus dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email Orang Tua Field
                        TextFormField(
                          controller: emailOrangtuaController,
                          decoration: InputDecoration(
                            labelText: 'Email Orang Tua',
                            hintText: 'contoh@email.com',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (!value.contains('@')) {
                                return 'Email tidak valid';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Telp Orang Tua Field
                        TextFormField(
                          controller: telpOrangtuaController,
                          decoration: InputDecoration(
                            labelText: 'Telepon Orang Tua',
                            hintText: '08xxxxxxxxxx',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () {
                    nisnController.dispose();
                    namaController.dispose();
                    emailOrangtuaController.dispose();
                    telpOrangtuaController.dispose();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setDialogState(() {
                        isSubmitting = true;
                      });

                      try {
                        final String nisn = nisnController.text.trim();

                        // Check if NISN already exists
                        final existingDoc = await FirebaseFirestore.instance
                            .collection('siswa')
                            .doc(nisn)
                            .get();

                        if (existingDoc.exists) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('NISN sudah terdaftar!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          setDialogState(() {
                            isSubmitting = false;
                          });
                          return;
                        }

                        // Save student data
                        await FirebaseFirestore.instance
                            .collection('siswa')
                            .doc(nisn)
                            .set({
                          'nisn': nisn,
                          'nama_siswa': namaController.text.trim(),
                          'jenis_kelamin': selectedGender,
                          'kelas_sw': selectedClass,
                          'nip': selectedNip,
                          'email_orangtua': emailOrangtuaController.text.trim(),
                          'telp_orangtua': telpOrangtuaController.text.trim(),
                        });

                        // Clean up controllers
                        nisnController.dispose();
                        namaController.dispose();
                        emailOrangtuaController.dispose();
                        telpOrangtuaController.dispose();

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Data siswa berhasil ditambahkan!'),
                              backgroundColor: Colors.green,
                            ),
                          );

                          // Reload students
                          _loadStudents();
                        }
                      } catch (e) {
                        developer.log('Error adding student: $e');
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Gagal menambahkan siswa: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        setDialogState(() {
                          isSubmitting = false;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    final formKey = GlobalKey<FormState>();
    final nisnController = TextEditingController(text: student['nisn']);
    final namaController = TextEditingController(text: student['nama_siswa']);
    final emailOrangtuaController = TextEditingController(text: student['email_orangtua'] ?? '');
    final telpOrangtuaController = TextEditingController(text: student['telp_orangtua'] ?? '');
    String? selectedClass = student['kelas_sw'];
    // Normalize gender to uppercase to match dropdown values
    String? selectedGender = student['jenis_kelamin']?.toString().toUpperCase();
    // Check if NIP exists in walikelas list
    String? selectedNip = walikelasList.any((w) => w['nip'] == student['nip']) 
        ? student['nip'] 
        : null;
    bool isSubmitting = false;
    final String oldNisn = student['nisn'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Data Siswa',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NISN Field
                        TextFormField(
                          controller: nisnController,
                          decoration: InputDecoration(
                            labelText: 'NISN *',
                            hintText: 'Masukkan 10 digit NISN',
                            prefixIcon: const Icon(Icons.badge),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'NISN harus diisi';
                            }
                            if (value.length != 10) {
                              return 'NISN harus 10 digit';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Nama Siswa Field
                        TextFormField(
                          controller: namaController,
                          decoration: InputDecoration(
                            labelText: 'Nama Siswa *',
                            hintText: 'Masukkan nama lengkap siswa',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama siswa harus diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Jenis Kelamin Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedGender,
                          decoration: InputDecoration(
                            labelText: 'Jenis Kelamin *',
                            prefixIcon: const Icon(Icons.wc),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: const [
                            DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                            DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedGender = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Jenis kelamin harus dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Kelas Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedClass,
                          decoration: InputDecoration(
                            labelText: 'Kelas *',
                            prefixIcon: const Icon(Icons.class_),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: classOptions.map((kelas) {
                            return DropdownMenuItem(
                              value: kelas.toLowerCase(),
                              child: Text(kelas),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedClass = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Kelas harus dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Wali Kelas Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedNip,
                          decoration: InputDecoration(
                            labelText: 'Wali Kelas *',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: walikelasList.map<DropdownMenuItem<String>>((walikelas) {
                            return DropdownMenuItem<String>(
                              value: walikelas['nip'] as String,
                              child: Text('${walikelas['nip']} - Kelas ${walikelas['kelasku']?.toString().toUpperCase()}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedNip = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Wali kelas harus dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email Orang Tua Field
                        TextFormField(
                          controller: emailOrangtuaController,
                          decoration: InputDecoration(
                            labelText: 'Email Orang Tua',
                            hintText: 'contoh@email.com',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (!value.contains('@')) {
                                return 'Email tidak valid';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Telp Orang Tua Field
                        TextFormField(
                          controller: telpOrangtuaController,
                          decoration: InputDecoration(
                            labelText: 'Telepon Orang Tua',
                            hintText: '08xxxxxxxxxx',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () {
                    nisnController.dispose();
                    namaController.dispose();
                    emailOrangtuaController.dispose();
                    telpOrangtuaController.dispose();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setDialogState(() {
                        isSubmitting = true;
                      });

                      try {
                        final String newNisn = nisnController.text.trim();

                        // If NISN changed, check if new NISN already exists
                        if (newNisn != oldNisn) {
                          final existingDoc = await FirebaseFirestore.instance
                              .collection('siswa')
                              .doc(newNisn)
                              .get();

                          if (existingDoc.exists) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('NISN baru sudah terdaftar!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            return;
                          }

                          // Create new document with new NISN
                          await FirebaseFirestore.instance
                              .collection('siswa')
                              .doc(newNisn)
                              .set({
                            'nisn': newNisn,
                            'nama_siswa': namaController.text.trim(),
                            'jenis_kelamin': selectedGender,
                            'kelas_sw': selectedClass,
                            'nip': selectedNip,
                            'email_orangtua': emailOrangtuaController.text.trim(),
                            'telp_orangtua': telpOrangtuaController.text.trim(),
                          });

                          // Update related records (attendance & face)
                          // Update presensi
                          QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
                              .collection('presensi')
                              .where('nisn', isEqualTo: oldNisn)
                              .get();
                          
                          for (var doc in attendanceSnapshot.docs) {
                            await doc.reference.update({'nisn': newNisn});
                          }

                          // Update wajah_siswa
                          QuerySnapshot faceSnapshot = await FirebaseFirestore.instance
                              .collection('wajah_siswa')
                              .where('nisn', isEqualTo: oldNisn)
                              .get();
                          
                          for (var doc in faceSnapshot.docs) {
                            await doc.reference.update({'nisn': newNisn});
                          }

                          // Delete old document
                          await FirebaseFirestore.instance
                              .collection('siswa')
                              .doc(oldNisn)
                              .delete();
                        } else {
                          // Just update existing document
                          await FirebaseFirestore.instance
                              .collection('siswa')
                              .doc(oldNisn)
                              .update({
                            'nisn': newNisn,
                            'nama_siswa': namaController.text.trim(),
                            'jenis_kelamin': selectedGender,
                            'kelas_sw': selectedClass,
                            'nip': selectedNip,
                            'email_orangtua': emailOrangtuaController.text.trim(),
                            'telp_orangtua': telpOrangtuaController.text.trim(),
                          });
                        }

                        // Clean up controllers
                        nisnController.dispose();
                        namaController.dispose();
                        emailOrangtuaController.dispose();
                        telpOrangtuaController.dispose();

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Data siswa berhasil diperbarui!'),
                              backgroundColor: Colors.green,
                            ),
                          );

                          // Reload students
                          _loadStudents();
                        }
                      } catch (e) {
                        developer.log('Error updating student: $e');
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Gagal memperbarui siswa: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        setDialogState(() {
                          isSubmitting = false;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Konfirmasi Hapus',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apakah Anda yakin ingin menghapus data siswa ini?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['nama_siswa'] ?? 'Nama tidak tersedia',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('NISN: ${student['nisn']}'),
                    Text('Kelas: ${_formatClass(student['kelas_sw'])}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data presensi dan wajah terdaftar juga akan terhapus!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteStudent(student);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    try {
      final String nisn = student['nisn'];

      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Delete related presensi records
      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get();
      
      for (var doc in attendanceSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete related wajah_siswa records
      QuerySnapshot faceSnapshot = await FirebaseFirestore.instance
          .collection('wajah_siswa')
          .where('nisn', isEqualTo: nisn)
          .get();
      
      for (var doc in faceSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete student document
      await FirebaseFirestore.instance
          .collection('siswa')
          .doc(nisn)
          .delete();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data siswa berhasil dihapus!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload students
        _loadStudents();
      }
    } catch (e) {
      developer.log('Error deleting student: $e');
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menghapus siswa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
