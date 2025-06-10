import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFaces,
            tooltip: 'Refresh Data',
          ),
        ],
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
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.face,
                                          color: Color(0xFF4CAF50),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
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
}
