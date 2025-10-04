import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
// ignore: unused_import
import 'dart:developer' as developer;

class AdminFaceList extends StatefulWidget {
  const AdminFaceList({super.key});

  @override
  State<AdminFaceList> createState() => _AdminFaceListState();
}

class _AdminFaceListState extends State<AdminFaceList> {
  bool isLoading = true;
  List<Map<String, dynamic>> faces = [];
  List<Map<String, dynamic>> filteredFaces = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedClass;
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

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFaces(String query) {
    setState(() {
      filteredFaces = faces.where((face) {
        final name = face['nama_siswa']?.toString().toLowerCase() ?? '';
        final nisn = face['nisn']?.toString().toLowerCase() ?? '';
        final kelas = _formatClass(face['kelas_sw']).toLowerCase();
        final matchesQuery = name.contains(query.toLowerCase()) ||
            nisn.contains(query.toLowerCase());
        final matchesClass =
            _selectedClass == null || kelas == _selectedClass!.toLowerCase();
        return matchesQuery && matchesClass;
      }).toList();
    });
  }

  Future<void> _loadFaces() async {
    setState(() {
      isLoading = true;
    });
    try {
      final faceSnapshot =
          await FirebaseFirestore.instance.collection('wajah_siswa').get();
      List<Map<String, dynamic>> tempList = [];
      for (var doc in faceSnapshot.docs) {
        Map<String, dynamic> faceData = doc.data();
        String nisn = faceData['nisn'] ?? '';

        if (nisn.isNotEmpty) {
          final studentDoc = await FirebaseFirestore.instance
              .collection('siswa')
              .doc(nisn)
              .get();
          if (studentDoc.exists) {
            Map<String, dynamic> studentData =
                studentDoc.data() as Map<String, dynamic>;
            faceData['nama_siswa'] = studentData['nama_siswa'];
            faceData['kelas_sw'] = studentData['kelas_sw'];
            faceData['jenis_kelamin'] = studentData['jenis_kelamin'];
          }
        }
        tempList.add(faceData);
      }
      faces = tempList;
      _filterFaces(_searchController.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal memuat data wajah: $e'),
              backgroundColor: Colors.red),
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
          'Daftar Data Wajah',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan nama...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filterFaces(value);
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Class Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
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
                          _filterFaces(_searchController.text);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Face List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                    ),
                  )
                : filteredFaces.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.face_retouching_natural,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada data wajah terdaftar',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredFaces.length,
                        itemBuilder: (context, index) {
                          final face = filteredFaces[index];
                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Foto Wajah
                                  GestureDetector(
                                    onTap: () {
                                      // Tampilkan gambar full screen saat diklik
                                      if (face['gambar'] != null && face['gambar'].toString().isNotEmpty) {
                                        _showFullImage(context, face['gambar'], face['nama_siswa'] ?? 'Foto Siswa');
                                      }
                                    },
                                    child: Container(
                                      width: 100,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF4CAF50),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: face['gambar'] != null && face['gambar'].toString().isNotEmpty
                                            ? _buildImageFromBase64(face['gambar'])
                                            : _buildNoImagePlaceholder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Info Siswa
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    face['nama_siswa'] ??
                                                        'Nama tidak tersedia',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'NISN: ${face['nisn']}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Terdaftar',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                            'Kelas',
                                            _formatClass(
                                                face['kelas_sw']?.toString())),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          'Jenis Kelamin',
                                          _formatGender(face['jenis_kelamin']),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Delete Button
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Hapus',
                                    onPressed: () => _showDeleteConfirmation(face),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.red.withOpacity(0.1),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Build image from base64 string
  Widget _buildImageFromBase64(String base64String) {
    try {
      Uint8List bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildNoImagePlaceholder();
        },
      );
    } catch (e) {
      developer.log('Error decoding base64 image: $e');
      return _buildNoImagePlaceholder();
    }
  }

  // Placeholder widget untuk foto yang tidak tersedia
  Widget _buildNoImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada\nfoto',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // Build full size image from base64
  Widget _buildFullImageFromBase64(String base64String) {
    try {
      Uint8List bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat gambar',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      developer.log('Error decoding full base64 image: $e');
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat gambar',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
  }

  // Method untuk menampilkan gambar full screen
  void _showFullImage(BuildContext context, String imageUrl, String studentName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header dengan nama siswa
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Gambar
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _buildFullImageFromBase64(imageUrl),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> face) {
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
                'Apakah Anda yakin ingin menghapus data wajah ini?',
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
                      face['nama_siswa'] ?? 'Nama tidak tersedia',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('NISN: ${face['nisn'] ?? 'Tidak tersedia'}'),
                    Text('Kelas: ${_formatClass(face['kelas_sw'])}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Siswa perlu mendaftar ulang wajah jika ingin presensi lagi.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
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
                await _deleteFace(face);
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

  Future<void> _deleteFace(Map<String, dynamic> face) async {
    try {
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

      // Get the face document ID
      // We need to find the document by NISN since we don't have the doc ID
      QuerySnapshot faceSnapshot = await FirebaseFirestore.instance
          .collection('wajah_siswa')
          .where('nisn', isEqualTo: face['nisn'])
          .limit(1)
          .get();

      if (faceSnapshot.docs.isNotEmpty) {
        // Delete the face document
        await faceSnapshot.docs.first.reference.delete();

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Data wajah berhasil dihapus!'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload faces
          _loadFaces();
        }
      } else {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Data wajah tidak ditemukan!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      developer.log('Error deleting face: $e');
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menghapus data wajah: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
