import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smart_presensee/screens/student_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<StudentAttendanceModel> studentList = [];
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();
  String? errorMessage;

  // Status options
  final List<String> statusOptions = ['hadir', 'sakit', 'izin', 'alpha'];
  final Map<String, Color> statusColors = {
    'hadir': Colors.green,
    'sakit': Colors.orange,
    'izin': Colors.blue,
    'alpha': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      log('=== MULAI LOAD DATA SISWA ===');

      // Step 1: Load all students with detailed logging
      QuerySnapshot studentSnapshot = await FirebaseFirestore.instance
          .collection('siswa')
          .orderBy('nama_siswa')
          .get();

      log('Jumlah dokumen siswa ditemukan: ${studentSnapshot.docs.length}');

      if (studentSnapshot.docs.isEmpty) {
        setState(() {
          errorMessage = 'Tidak ada data siswa di database';
          isLoading = false;
        });
        return;
      }

      List<StudentAttendanceModel> tempList = [];

      for (var doc in studentSnapshot.docs) {
        try {
          Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
          log('Processing siswa: ${doc.id} - ${studentData['nama_siswa']}');

          // Step 2: Check if face is registered
          QuerySnapshot faceSnapshot = await FirebaseFirestore.instance
              .collection('wajah_siswa')
              .where('nisn', isEqualTo: doc.id)
              .limit(1)
              .get();

          bool hasFaceRegistered = faceSnapshot.docs.isNotEmpty;
          log('Wajah terdaftar untuk ${doc.id}: $hasFaceRegistered');

          // Step 3: Check today's attendance
          DateTime startOfDay =
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          DateTime endOfDay = DateTime(selectedDate.year, selectedDate.month,
              selectedDate.day, 23, 59, 59);

          log('Mencari presensi untuk ${doc.id} dari $startOfDay sampai $endOfDay');

          QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
              .collection('presensi')
              .where('nisn', isEqualTo: doc.id)
              .where('tanggal_waktu',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('tanggal_waktu',
                  isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
              .limit(1)
              .get();

          String? todayStatus;
          if (attendanceSnapshot.docs.isNotEmpty) {
            Map<String, dynamic>? attendanceData =
                attendanceSnapshot.docs.first.data() as Map<String, dynamic>?;
            todayStatus =
                attendanceData != null ? attendanceData['status'] : null;
            log('Status presensi untuk ${doc.id}: $todayStatus');
          } else {
            log('Tidak ada presensi hari ini untuk ${doc.id}');
          }

          tempList.add(StudentAttendanceModel(
            nisn: doc.id,
            nama: studentData['nama_siswa'] ?? 'Nama tidak tersedia',
            kelas: studentData['kelas'] ?? 'Tidak diketahui',
            jenisKelamin: studentData['jenis_kelamin'] ?? 'Tidak diketahui',
            hasFaceRegistered: hasFaceRegistered,
            todayAttendanceStatus: todayStatus,
          ));

          log('Berhasil memproses siswa: ${doc.id}');
        } catch (e) {
          log('Error processing siswa ${doc.id}: $e');
          // Continue dengan siswa berikutnya jika ada error
        }
      }

      log('Total siswa berhasil diproses: ${tempList.length}');

      setState(() {
        studentList = tempList;
        isLoading = false;
      });

      if (tempList.isEmpty) {
        setState(() {
          errorMessage = 'Data siswa berhasil dimuat tapi kosong';
        });
      }
    } catch (e) {
      log('ERROR saat load data siswa: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
      _showToast('Gagal memuat data siswa: ${e.toString()}');
    }
  }

  // Method untuk debugging Firestore
  Future<void> _debugFirestore() async {
    try {
      // Test koneksi Firestore
      log('=== DEBUG FIRESTORE ===');

      // Test collection siswa
      var siswaTest =
          await FirebaseFirestore.instance.collection('siswa').limit(1).get();
      log('Test siswa collection: ${siswaTest.docs.length} docs');

      // Test collection wajah_siswa
      var wajahTest = await FirebaseFirestore.instance
          .collection('wajah_siswa')
          .limit(1)
          .get();
      log('Test wajah_siswa collection: ${wajahTest.docs.length} docs');

      // Test collection presensi
      var presensiTest = await FirebaseFirestore.instance
          .collection('presensi')
          .limit(1)
          .get();
      log('Test presensi collection: ${presensiTest.docs.length} docs');

      // List all collections (if possible)
      log('=== END DEBUG ===');
    } catch (e) {
      log('Debug Firestore error: $e');
    }
  }

  // Generate attendance ID
  Future<String> _generateAttendanceId() async {
    const String prefix = 'idpr04';
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('presensi').get();

    final int attendanceCount = snapshot.docs.length + 1;
    final String formattedNumber = attendanceCount.toString().padLeft(4, '0');

    return prefix + formattedNumber;
  }

  Future<void> _markAttendance(String nisn, String status) async {
    try {
      log('Marking attendance untuk NISN: $nisn dengan status: $status');

      // Check if attendance already exists for today
      DateTime startOfDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime endOfDay = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

      QuerySnapshot existingAttendance = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        // Update existing attendance
        String docId = existingAttendance.docs.first.id;
        await FirebaseFirestore.instance
            .collection('presensi')
            .doc(docId)
            .update({
          'status': status,
          'tanggal_waktu': Timestamp.now(),
        });
        log('Updated existing attendance: $docId');
      } else {
        // Create new attendance record
        String attendanceId = await _generateAttendanceId();
        await FirebaseFirestore.instance
            .collection('presensi')
            .doc(attendanceId)
            .set({
          'id_presensi': attendanceId,
          'nisn': nisn,
          'tanggal_waktu': Timestamp.now(),
          'status': status,
        });
        log('Created new attendance: $attendanceId');
      }

      _showToast('Status presensi berhasil diperbarui');
      _loadStudentData(); // Reload data
    } catch (e) {
      log('Error marking attendance: $e');
      _showToast('Gagal memperbarui status presensi: ${e.toString()}');
    }
  }

  void _showAttendanceHistory(StudentAttendanceModel student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceHistoryScreen(student: student),
      ),
    );
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  String _formatDate(DateTime date) {
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

    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month]} ${date.year}';
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
          'Daftar Kehadiran Siswa',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StudentScreen(),
                ),
              ).then((_) => _loadStudentData());
            },
            icon: const Icon(Icons.person_add, color: Colors.white),
            tooltip: 'Tambah Siswa',
          ),
          // Debug button (hapus di production)
          IconButton(
            onPressed: _debugFirestore,
            icon: const Icon(Icons.bug_report, color: Colors.white),
            tooltip: 'Debug',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tanggal Presensi',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                      _loadStudentData();
                    }
                  },
                  icon: const Icon(Icons.calendar_today,
                      color: Color(0xFF4CAF50)),
                ),
              ],
            ),
          ),

          // Error message display
          if (errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadStudentData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          // Student list
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Memuat data siswa...'),
                        ],
                      ),
                    )
                  : studentList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum ada data siswa',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tambah data siswa terlebih dahulu',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const StudentScreen(),
                                    ),
                                  ).then((_) => _loadStudentData());
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text('Tambah Siswa'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadStudentData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: studentList.length,
                            itemBuilder: (context, index) {
                              final student = studentList[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => _showAttendanceHistory(student),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            // Student info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student.nama,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'NISN: ${student.nisn} | Kelas: ${student.kelas.toUpperCase()}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        student.hasFaceRegistered
                                                            ? Icons.face
                                                            : Icons
                                                                .face_retouching_off,
                                                        size: 16,
                                                        color: student
                                                                .hasFaceRegistered
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        student.hasFaceRegistered
                                                            ? 'Wajah Terdaftar'
                                                            : 'Wajah Belum Terdaftar',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: student
                                                                  .hasFaceRegistered
                                                              ? Colors.green
                                                              : Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Status indicator
                                            if (student.todayAttendanceStatus !=
                                                null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColors[student
                                                          .todayAttendanceStatus]!
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: statusColors[student
                                                        .todayAttendanceStatus]!,
                                                  ),
                                                ),
                                                child: Text(
                                                  student.todayAttendanceStatus!
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusColors[student
                                                        .todayAttendanceStatus],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Attendance status buttons
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: statusOptions.map((status) {
                                            bool isSelected =
                                                student.todayAttendanceStatus ==
                                                    status;
                                            return Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 2),
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _markAttendance(
                                                          student.nisn, status),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: isSelected
                                                        ? statusColors[status]
                                                        : Colors.grey[200],
                                                    foregroundColor: isSelected
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    status[0].toUpperCase() +
                                                        status.substring(1),
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadStudentData,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

// Student attendance model (tidak berubah)
class StudentAttendanceModel {
  final String nisn;
  final String nama;
  final String kelas;
  final String jenisKelamin;
  final bool hasFaceRegistered;
  final String? todayAttendanceStatus;

  StudentAttendanceModel({
    required this.nisn,
    required this.nama,
    required this.kelas,
    required this.jenisKelamin,
    required this.hasFaceRegistered,
    this.todayAttendanceStatus,
  });
}

// Attendance History Screen (tetap sama seperti sebelumnya)
class AttendanceHistoryScreen extends StatefulWidget {
  final StudentAttendanceModel student;

  const AttendanceHistoryScreen({super.key, required this.student});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceRecord> attendanceHistory = [];
  bool isLoading = true;

  final Map<String, Color> statusColors = {
    'hadir': Colors.green,
    'sakit': Colors.orange,
    'izin': Colors.blue,
    'alpha': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      setState(() {
        isLoading = true;
      });

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: widget.student.nisn)
          .orderBy('tanggal_waktu', descending: true)
          .get();

      List<AttendanceRecord> tempList = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        tempList.add(AttendanceRecord(
          id: doc.id,
          tanggalWaktu: (data['tanggal_waktu'] as Timestamp).toDate(),
          status: data['status'] ?? 'hadir',
        ));
      }

      setState(() {
        attendanceHistory = tempList;
        isLoading = false;
      });
    } catch (e) {
      log('Error loading attendance history: $e');
      setState(() {
        isLoading = false;
      });
    }
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
          'Riwayat Presensi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Student info header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.nama,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'NISN: ${widget.student.nisn}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Kelas: ${widget.student.kelas.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Attendance history list
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : attendanceHistory.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada riwayat presensi',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: attendanceHistory.length,
                          itemBuilder: (context, index) {
                            final record = attendanceHistory[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: statusColors[record.status]!
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    record.status == 'hadir'
                                        ? Icons.check_circle
                                        : record.status == 'sakit'
                                            ? Icons.sick
                                            : record.status == 'izin'
                                                ? Icons.assignment
                                                : Icons.cancel,
                                    color: statusColors[record.status],
                                  ),
                                ),
                                title: Text(
                                  _formatDateTime(record.tanggalWaktu),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColors[record.status]!
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColors[record.status]!,
                                    ),
                                  ),
                                  child: Text(
                                    record.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: statusColors[record.status],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// Model for attendance record
class AttendanceRecord {
  final String id;
  final DateTime tanggalWaktu;
  final String status;

  AttendanceRecord({
    required this.id,
    required this.tanggalWaktu,
    required this.status,
  });
}
