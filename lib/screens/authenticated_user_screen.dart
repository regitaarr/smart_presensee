import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer';

class AuthenticatedUserScreen extends StatefulWidget {
  final UserModel user;
  const AuthenticatedUserScreen({super.key, required this.user});

  @override
  State<AuthenticatedUserScreen> createState() =>
      _AuthenticatedUserScreenState();
}

class _AuthenticatedUserScreenState extends State<AuthenticatedUserScreen> {
  bool _isLoading = false;
  String? studentName;
  String? studentClass;

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
    _saveAttendanceRecord();
  }

  Future<void> _loadStudentInfo() async {
    if (widget.user.nisn != null) {
      try {
        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('siswa')
            .doc(widget.user.nisn)
            .get();

        if (studentDoc.exists) {
          Map<String, dynamic> studentData =
              studentDoc.data() as Map<String, dynamic>;
          setState(() {
            studentName = studentData['nama_siswa'] ?? widget.user.name;
            studentClass = studentData['kelas'] ?? 'Tidak diketahui';
          });
        }
      } catch (e) {
        log('Error loading student info: $e');
      }
    }
  }

  Future<void> _saveAttendanceRecord() async {
    if (widget.user.nisn == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if attendance record already exists for today
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      QuerySnapshot existingRecord = await FirebaseFirestore.instance
          .collection('kehadiran')
          .where('nisn', isEqualTo: widget.user.nisn)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (existingRecord.docs.isEmpty) {
        // Create new attendance record
        String docId =
            FirebaseFirestore.instance.collection('kehadiran').doc().id;

        await FirebaseFirestore.instance
            .collection('kehadiran')
            .doc(docId)
            .set({
          'id': docId,
          'nisn': widget.user.nisn,
          'nama_siswa': studentName ?? widget.user.name,
          'kelas': studentClass ?? 'Tidak diketahui',
          'status': 'Hadir',
          'timestamp': Timestamp.now(),
          'id_wajah': widget.user.idWajah,
        });

        _showSuccessToast('Presensi berhasil dicatat!');
      } else {
        _showInfoToast('Anda sudah melakukan presensi hari ini');
      }
    } catch (e) {
      log('Error saving attendance: $e');
      _showErrorToast('Gagal menyimpan data presensi');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void _showInfoToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          "Presensi Berhasil",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Success card
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Success icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 80,
                        color: Color(0xFF4CAF50),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Greeting text
                    Text(
                      "Selamat, ${studentName ?? widget.user.name}!",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "Presensi Berhasil Dicatat",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                        color: Color(0xFF4CAF50),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

                    // Student info card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                              'NISN', widget.user.nisn ?? 'Tidak tersedia'),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                              'Nama',
                              studentName ??
                                  widget.user.name ??
                                  'Tidak tersedia'),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                              'Kelas', studentClass ?? 'Tidak diketahui'),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                              'Waktu', _formatDateTime(DateTime.now())),
                          const SizedBox(height: 12),
                          _buildInfoRow('Status', 'Hadir'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    if (_isLoading)
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                      )
                    else
                      Column(
                        children: [
                          // Back to dashboard button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: const Text(
                                'Kembali ke Beranda',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    List<String> days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
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

    String dayName = days[dateTime.weekday % 7];
    String monthName = months[dateTime.month];
    String time =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return '$dayName, ${dateTime.day} $monthName ${dateTime.year} - $time';
  }
}
