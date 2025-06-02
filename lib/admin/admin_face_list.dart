import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class AdminFaceList extends StatefulWidget {
  const AdminFaceList({super.key});

  @override
  State<AdminFaceList> createState() => _AdminFaceListState();
}

class _AdminFaceListState extends State<AdminFaceList> {
  bool isLoading = true;
  List<Map<String, dynamic>> faceList = [];
  List<Map<String, dynamic>> filteredFaceList = [];
  String searchQuery = '';
  String selectedClass = 'Semua';

  final List<String> classOptions = [
    '1a',
    '1b',
    '2a',
    '2b',
    '3a',
    '3b',
    '4a',
    '4b',
    '5a',
    '5b',
    '6a',
    '6b'
  ];

  @override
  void initState() {
    super.initState();
    _loadFaceData();
  }

  Future<void> _loadFaceData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get all registered faces
      QuerySnapshot faceSnapshot =
          await FirebaseFirestore.instance.collection('wajah_siswa').get();

      List<Map<String, dynamic>> tempList = [];
      for (var doc in faceSnapshot.docs) {
        Map<String, dynamic> faceData = doc.data() as Map<String, dynamic>;

        // Get student data
        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('siswa')
            .doc(faceData['nisn'])
            .get();

        if (studentDoc.exists) {
          Map<String, dynamic> studentData =
              studentDoc.data() as Map<String, dynamic>;
          faceData['nama_siswa'] = studentData['nama_siswa'];
          faceData['kelas_sw'] = studentData['kelas_sw'];
          faceData['jenis_kelamin'] = studentData['jenis_kelamin'];
          tempList.add(faceData);
        }
      }

      setState(() {
        faceList = tempList;
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      developer.log('Error loading face data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading face data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      filteredFaceList = faceList.where((face) {
        bool matchesSearch = face['nama_siswa']
            .toString()
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
        bool matchesClass = selectedClass == 'Semua' ||
            face['kelas_sw'].toString().toLowerCase() ==
                selectedClass.toLowerCase();
        return matchesSearch && matchesClass;
      }).toList();
    });
  }

  List<String> _getUniqueClasses() {
    return ['Semua', ...classOptions];
  }

  String _formatGender(String? gender) {
    if (gender == null) return '-';
    return gender.toLowerCase() == 'l' ? 'Laki-laki' : 'Perempuan';
  }

  String _formatClass(String? kelas) {
    if (kelas == null || kelas.isEmpty) return '-';
    if (kelas.length >= 2) {
      final number = kelas.substring(0, kelas.length - 1);
      final letter = kelas.substring(kelas.length - 1).toUpperCase();
      return '$number$letter';
    }
    return kelas.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Data Wajah Terdaftar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFaceData,
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
                      searchQuery = value;
                      _applyFilters();
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
                      value: selectedClass,
                      isExpanded: true,
                      items: _getUniqueClasses().map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedClass = newValue;
                            _applyFilters();
                          });
                        }
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
                : filteredFaceList.isEmpty
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
                        itemCount: filteredFaceList.length,
                        itemBuilder: (context, index) {
                          final face = filteredFaceList[index];
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
