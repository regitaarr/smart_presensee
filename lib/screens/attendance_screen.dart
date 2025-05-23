import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();
  List<AttendanceModel> attendanceList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _editNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    try {
      setState(() {
        isLoading = true;
      });

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('kehadiran')
          .orderBy('name')
          .get();

      attendanceList = snapshot.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      log('Error loading attendance data: $e');
      setState(() {
        isLoading = false;
      });
      _showToast('Gagal memuat data kehadiran');
    }
  }

  Future<void> _addAttendanceData() async {
    if (_nameController.text.trim().isEmpty) {
      _showToast('Nama tidak boleh kosong');
      return;
    }

    try {
      String docId =
          FirebaseFirestore.instance.collection('kehadiran').doc().id;

      AttendanceModel newAttendance = AttendanceModel(
        id: docId,
        name: _nameController.text.trim(),
        status: 'Hadir',
        timestamp: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('kehadiran')
          .doc(docId)
          .set(newAttendance.toFirestore());

      _nameController.clear();
      Navigator.of(context).pop();
      _loadAttendanceData();
      _showToast('Data berhasil ditambahkan');
    } catch (e) {
      log('Error adding attendance: $e');
      _showToast('Gagal menambahkan data');
    }
  }

  Future<void> _editAttendanceData(AttendanceModel attendance) async {
    if (_editNameController.text.trim().isEmpty) {
      _showToast('Nama tidak boleh kosong');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('kehadiran')
          .doc(attendance.id)
          .update({
        'name': _editNameController.text.trim(),
        'status': attendance.status,
        'timestamp': Timestamp.now(),
      });

      _editNameController.clear();
      Navigator.of(context).pop();
      _loadAttendanceData();
      _showToast('Data berhasil diubah');
    } catch (e) {
      log('Error editing attendance: $e');
      _showToast('Gagal mengubah data');
    }
  }

  Future<void> _deleteAttendanceData(String id) async {
    try {
      await FirebaseFirestore.instance.collection('kehadiran').doc(id).delete();

      _loadAttendanceData();
      _showToast('Data berhasil dihapus');
    } catch (e) {
      log('Error deleting attendance: $e');
      _showToast('Gagal menghapus data');
    }
  }

  Future<void> _toggleAttendanceStatus(AttendanceModel attendance) async {
    try {
      String newStatus = attendance.status == 'Hadir' ? 'Sakit' : 'Hadir';

      await FirebaseFirestore.instance
          .collection('kehadiran')
          .doc(attendance.id)
          .update({
        'status': newStatus,
        'timestamp': Timestamp.now(),
      });

      _loadAttendanceData();
      _showToast('Status kehadiran berhasil diubah');
    } catch (e) {
      log('Error updating status: $e');
      _showToast('Gagal mengubah status');
    }
  }

  void _showAddDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Data Kehadiran'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nama Siswa',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: _addAttendanceData,
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(AttendanceModel attendance) {
    _editNameController.text = attendance.name;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Data Kehadiran'),
          content: TextField(
            controller: _editNameController,
            decoration: const InputDecoration(
              labelText: 'Nama Siswa',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => _editAttendanceData(attendance),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(AttendanceModel attendance) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Data'),
          content: Text(
              'Apakah Anda yakin ingin menghapus data ${attendance.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAttendanceData(attendance.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _downloadData() {
    // Implementasi download data (bisa berupa CSV, Excel, etc.)
    _showToast('Fitur unduh data akan segera tersedia');
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50), // Green background
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Kehadiran',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Action buttons row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showAddDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107), // Yellow
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Tambah Data',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Edit functionality - could show a list of items to edit
                      _showToast('Pilih item dari daftar untuk mengedit');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107), // Yellow
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Edit Data',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Delete functionality - could show a list of items to delete
                      _showToast('Pilih item dari daftar untuk menghapus');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Hapus',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Student name input section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Muhammad Daniel',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Hadir button functionality
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Hadir'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Password field (if needed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: '••••••••••••••••••••',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Sakit button functionality
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Sakit'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Attendance list
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : attendanceList.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada data kehadiran',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: attendanceList.length,
                          itemBuilder: (context, index) {
                            final attendance = attendanceList[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: attendance.status == 'Hadir'
                                      ? Colors.green
                                      : Colors.red,
                                  child: Text(
                                    attendance.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  attendance.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Status: ${attendance.status}',
                                  style: TextStyle(
                                    color: attendance.status == 'Hadir'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _showEditDialog(attendance);
                                        break;
                                      case 'delete':
                                        _showDeleteDialog(attendance);
                                        break;
                                      case 'toggle_status':
                                        _toggleAttendanceStatus(attendance);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 16),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'toggle_status',
                                      child: Row(
                                        children: [
                                          Icon(Icons.swap_horiz, size: 16),
                                          SizedBox(width: 8),
                                          Text('Ubah Status'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Hapus',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () =>
                                    _toggleAttendanceStatus(attendance),
                              ),
                            );
                          },
                        ),
            ),
          ),

          // Download button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _downloadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107), // Yellow
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Unduh Data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceModel {
  final String id;
  final String name;
  final String status;
  final Timestamp timestamp;

  AttendanceModel({
    required this.id,
    required this.name,
    required this.status,
    required this.timestamp,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      name: data['name'] ?? '',
      status: data['status'] ?? 'Hadir',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'status': status,
      'timestamp': timestamp,
    };
  }
}
