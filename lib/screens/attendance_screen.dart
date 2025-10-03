import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smart_presensee/screens/student_screen.dart';
import 'package:smart_presensee/services/email_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceScreen extends StatefulWidget {
  final String userEmail;
  final String? userNip; // Add userNip parameter

  const AttendanceScreen({
    super.key,
    required this.userEmail,
    this.userNip, // Make userNip optional
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<StudentAttendanceModel> studentList = [];
  List<StudentAttendanceModel> filteredStudentList = [];
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();
  String? errorMessage;
  String searchQuery = '';
  String? selectedGenderFilter;

  final TextEditingController _searchController = TextEditingController();

  final List<String> statusOptions = ['hadir', 'sakit', 'izin', 'alpha'];
  final Map<String, Color> statusColors = {
    'hadir': Colors.green,
    'sakit': Colors.orange,
    'izin': Colors.blue,
    'alpha': Colors.red,
  };

  final Map<String, IconData> statusIcons = {
    'hadir': Icons.check_circle,
    'sakit': Icons.sick,
    'izin': Icons.assignment,
    'alpha': Icons.cancel,
  };

  final List<String> genderOptions = ['l', 'p'];
  final Map<String, String> genderLabels = {
    'l': 'Laki-laki',
    'p': 'Perempuan',
  };

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    filteredStudentList = studentList.where((student) {
      // Search filter
      bool matchesSearch = searchQuery.isEmpty ||
          student.nama.toLowerCase().contains(searchQuery.toLowerCase()) ||
          student.nisn.contains(searchQuery);

      // Gender filter
      bool matchesGender = selectedGenderFilter == null ||
          student.jenisKelamin == selectedGenderFilter;

      return matchesSearch && matchesGender;
    }).toList();
  }

  Future<void> _loadStudentData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      log('=== MULAI LOAD DATA SISWA ===');

      // Load siswa from collection 'siswa'
      Query studentQuery = FirebaseFirestore.instance.collection('siswa');

      // Filter students by NIP if user is walikelas
      if (widget.userNip != null) {
        studentQuery = studentQuery.where('nip', isEqualTo: widget.userNip);
      }

      QuerySnapshot studentSnapshot = await studentQuery.get();

      log('Jumlah siswa ditemukan: ${studentSnapshot.docs.length}');

      if (studentSnapshot.docs.isEmpty) {
        setState(() {
          errorMessage = 'Tidak ada data siswa di database';
          isLoading = false;
        });
        return;
      }

      List<StudentAttendanceModel> tempList = [];

      // Proses setiap siswa
      for (var doc in studentSnapshot.docs) {
        try {
          Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
          String nisn = doc.id;

          log('Processing siswa: $nisn - ${studentData['nama_siswa']}');

          // Cek apakah wajah sudah terdaftar
          QuerySnapshot faceSnapshot = await FirebaseFirestore.instance
              .collection('wajah_siswa')
              .where('nisn', isEqualTo: nisn)
              .limit(1)
              .get();

          bool hasFaceRegistered = faceSnapshot.docs.isNotEmpty;

          String todayStatus = await _getTodayAttendanceStatus(nisn);

          tempList.add(StudentAttendanceModel(
            nisn: nisn,
            nama: studentData['nama_siswa'] ?? 'Nama tidak tersedia',
            kelas: studentData['kelas_sw'] ?? 'Tidak diketahui',
            jenisKelamin: studentData['jenis_kelamin'] ?? 'Tidak diketahui',
            hasFaceRegistered: hasFaceRegistered,
            todayAttendanceStatus: todayStatus,
          ));

          log('Berhasil memproses siswa: $nisn - Status: $todayStatus');
        } catch (e) {
          log('Error processing siswa ${doc.id}: $e');
          continue;
        }
      }

      log('Total siswa berhasil diproses: ${tempList.length}');

      setState(() {
        studentList = tempList;
        filteredStudentList = tempList;
        isLoading = false;
      });
    } catch (e) {
      log('ERROR saat load data siswa: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
      _showToast('Gagal memuat data siswa: ${e.toString()}');
    }
  }

  Future<String> _getTodayAttendanceStatus(String nisn) async {
    try {
      DateTime startOfDay = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
      DateTime endOfDay = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

      log('Checking attendance for NISN: $nisn');
      log('Selected date: ${selectedDate.toIso8601String().substring(0, 10)}');
      log('Start of day: ${startOfDay.toIso8601String()}');
      log('End of day: ${endOfDay.toIso8601String()}');

      // Pertama, cek semua data presensi untuk NISN ini (tanpa filter tanggal)
      QuerySnapshot allAttendance = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get();

      log('Total attendance records for NISN $nisn: ${allAttendance.docs.length}');

      // Debug: Print semua data presensi
      for (var doc in allAttendance.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        log('Record: ${doc.id}');
        log('   - NISN: ${data['nisn']}');
        log('   - Status: ${data['status']}');
        log('   - Tanggal: ${data['tanggal_waktu']}');
        if (data['tanggal_waktu'] != null) {
          DateTime recordDate = (data['tanggal_waktu'] as Timestamp).toDate();
          log('   - Converted Date: ${recordDate.toIso8601String()}');
          log('   - Same day? ${_isSameDay(recordDate, selectedDate)}');
        }
      }

      // Kemudian, cari yang sesuai tanggal yang dipilih
      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get(); // Hapus filter tanggal dulu, kita filter manual

      log('Filtering records manually...');

      for (var doc in attendanceSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['tanggal_waktu'] != null) {
          DateTime recordDate = (data['tanggal_waktu'] as Timestamp).toDate();

          // Check apakah tanggal sama
          if (_isSameDay(recordDate, selectedDate)) {
            String status = data['status'] ?? 'alpha';
            log('Found matching attendance for $nisn: $status');
            log('Record date: ${recordDate.toIso8601String()}');
            return status;
          }
        }
      }

      log('No attendance found for $nisn on selected date');
      return 'alpha';
    } catch (e) {
      log('Error getting attendance status for $nisn: $e');
      return 'alpha';
    }
  }

  // Helper function to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Optimized function to generate attendance ID
  Future<String> _generateAttendanceId() async {
    try {
      const String prefix = 'idpr04';

      // Query only the last record with the prefix to get the highest number
      QuerySnapshot lastRecords = await FirebaseFirestore.instance
          .collection('presensi')
          .where('id_presensi', isGreaterThanOrEqualTo: prefix)
          .where('id_presensi', isLessThan: '${prefix}z')
          .orderBy('id_presensi', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;

      if (lastRecords.docs.isNotEmpty) {
        String lastId = lastRecords.docs.first.get('id_presensi') as String;
        log('Last attendance ID found: $lastId');

        if (lastId.length >= 10 && lastId.startsWith(prefix)) {
          String lastNumberStr = lastId.substring(6);
          int lastNumber = int.tryParse(lastNumberStr) ?? 0;
          nextNumber = lastNumber + 1;
        }
      }

      String formattedNumber = nextNumber.toString().padLeft(4, '0');
      String newId = '$prefix$formattedNumber';

      if (newId.length != 10) {
        throw Exception('Generated ID length is not 10 characters: $newId');
      }

      // Check if the ID already exists (rare case)
      DocumentSnapshot existingDoc = await FirebaseFirestore.instance
          .collection('presensi')
          .doc(newId)
          .get();

      if (existingDoc.exists) {
        log('ID $newId already exists, trying next number...');
        nextNumber++;
        formattedNumber = nextNumber.toString().padLeft(4, '0');
        newId = '$prefix$formattedNumber';
      }

      log('Generated attendance ID: $newId');
      return newId;
    } catch (e) {
      log('Error generating attendance ID: $e');

      // Fallback: use timestamp-based ID
      DateTime now = DateTime.now();
      String timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      String fallbackId = 'idpr04$timeString';

      log('Using fallback ID: $fallbackId');
      return fallbackId;
    }
  }

  Future<void> _markAttendance(String nisn, String status) async {
    try {
      log('Marking attendance untuk NISN: $nisn dengan status: $status');

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
        });
        log('Updated existing attendance: $docId');
      } else {
        // Create new attendance record
        String attendanceId = await _generateAttendanceId();

        DateTime attendanceDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          DateTime.now().hour,
          DateTime.now().minute,
          DateTime.now().second,
        );

        await FirebaseFirestore.instance
            .collection('presensi')
            .doc(attendanceId)
            .set({
          'id_presensi': attendanceId,
          'nisn': nisn,
          'tanggal_waktu': Timestamp.fromDate(attendanceDateTime),
          'status': status,
        });
        log('Created new attendance: $attendanceId');
      }

      _showToast('Status presensi berhasil diperbarui');
      await _loadStudentData();
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

  // Function untuk tambah presensi manual dari attendance screen
  Future<void> _showQuickManualAttendance(
      StudentAttendanceModel student) async {
    String selectedStatus = 'sakit';

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Presensi Manual'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Student info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.nama,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'NISN: ${student.nisn}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status dropdown
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status Presensi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.assignment),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                      DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                      DropdownMenuItem(value: 'izin', child: Text('Izin')),
                      DropdownMenuItem(value: 'alpha', child: Text('Alpha')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tanggal: ${_formatDate(selectedDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selectedStatus),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _saveQuickManualAttendance(student.nisn, result);
    }
  }

  // Kirim email notifikasi untuk presensi manual (izin/sakit)
  Future<void> _sendEmailNotificationManual(
      String nisn, String status, DateTime attendanceTime) async {
    try {
      // Get student data untuk nama dan email orang tua
      DocumentSnapshot studentDoc =
          await FirebaseFirestore.instance.collection('siswa').doc(nisn).get();

      if (!studentDoc.exists) {
        log('❌ Student not found for NISN: $nisn');
        return;
      }

      Map<String, dynamic> studentData =
          studentDoc.data() as Map<String, dynamic>;
      String studentName = studentData['nama_siswa'] ?? 'Siswa';
      String? emailOrangtua = studentData['email_orangtua'];
      String? kelas = studentData['kelas_sw'];

      if (emailOrangtua == null || emailOrangtua.isEmpty) {
        log('⚠️ Email orang tua tidak tersedia untuk $studentName (NISN: $nisn)');
        return;
      }

      log('📧 Sending email notification to: $emailOrangtua for $studentName (Status: $status)');

      // Kirim email
      bool emailSent = await EmailService.sendAttendanceNotification(
        studentName: studentName,
        nisn: nisn,
        parentEmail: emailOrangtua,
        attendanceStatus: status,
        attendanceTime: attendanceTime,
        className: kelas,
      );

      if (emailSent) {
        log('✅ Email notifikasi berhasil dikirim ke $emailOrangtua');
      } else {
        log('❌ Gagal mengirim email notifikasi ke $emailOrangtua');
      }
    } catch (e) {
      log('❌ Error saat kirim email notifikasi: $e');
    }
  }

  // Save quick manual attendance
  Future<void> _saveQuickManualAttendance(String nisn, String status) async {
    try {
      // Check if attendance already exists for selected date
      QuerySnapshot existingAttendance = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get();

      // Check manually for same date
      for (var doc in existingAttendance.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['tanggal_waktu'] != null) {
          DateTime recordDate = (data['tanggal_waktu'] as Timestamp).toDate();
          if (_isSameDay(recordDate, selectedDate)) {
            // Update existing record
            await FirebaseFirestore.instance
                .collection('presensi')
                .doc(doc.id)
                .update({
              'status': status,
              'metode': 'manual',
              'updated_at': FieldValue.serverTimestamp(),
            });

            _showToast('Status presensi berhasil diupdate');
            
            // Kirim email notifikasi untuk status izin dan sakit
            if (status == 'izin' || status == 'sakit') {
              _sendEmailNotificationManual(nisn, status, recordDate);
            }
            
            await _loadStudentData();
            return;
          }
        }
      }

      // Create new record if not exists
      String attendanceId = await _generateAttendanceId();
      DateTime attendanceDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        DateTime.now().hour,
        DateTime.now().minute,
        DateTime.now().second,
      );

      await FirebaseFirestore.instance
          .collection('presensi')
          .doc(attendanceId)
          .set({
        'id_presensi': attendanceId,
        'nisn': nisn,
        'tanggal_waktu': Timestamp.fromDate(attendanceDateTime),
        'status': status,
        'metode': 'manual',
        'created_at': FieldValue.serverTimestamp(),
      });

      _showToast('Presensi manual berhasil ditambahkan');
      
      // Kirim email notifikasi ke orang tua untuk status izin dan sakit
      if (status == 'izin' || status == 'sakit') {
        _sendEmailNotificationManual(nisn, status, attendanceDateTime);
      }
      
      await _loadStudentData();
    } catch (e) {
      log('Error saving quick manual attendance: $e');
      _showToast('Gagal menyimpan presensi: ${e.toString()}');
    }
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

  String _formatDateForFilename(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadDailyReport() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get the latest report ID
      final latestReport = await FirebaseFirestore.instance
          .collection('laporan')
          .orderBy('id_laporan', descending: true)
          .limit(1)
          .get();

      String newId;
      if (latestReport.docs.isEmpty) {
        newId = 'idlpmi0001';
      } else {
        final lastId = latestReport.docs.first['id_laporan'];
        int lastNumber = 0;

        if (lastId is String) {
          String processedId = lastId;
          if (processedId.startsWith('idlpmi')) {
            processedId = processedId.substring(6);
          }
          String numericPart = processedId.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericPart.isNotEmpty) {
            try {
              lastNumber = int.parse(numericPart);
            } catch (e) {
              log('Warning: Could not parse numeric part "$numericPart" from last report ID "$lastId". Error: $e. Defaulting to 0.');
            }
          }
        }
        newId = 'idlpmi${(lastNumber + 1).toString().padLeft(4, '0')}';
      }

      // Query attendance records for the selected date
      DateTime startOfDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime endOfDay = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      // Get all students
      Query studentQuery = FirebaseFirestore.instance.collection('siswa');
      if (widget.userNip != null) {
        studentQuery = studentQuery.where('nip', isEqualTo: widget.userNip);
      }
      QuerySnapshot studentSnapshot = await studentQuery.get();

      // Create a map to store attendance status for each student
      Map<String, String> studentAttendance = {};
      Map<String, String> studentMethods = {};
      for (var doc in studentSnapshot.docs) {
        studentAttendance[doc.id] = 'alpha'; // Default status
        studentMethods[doc.id] = 'manual'; // Default method
      }

      // Update attendance status from records
      for (var doc in attendanceSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String nisn = data['nisn'];
        String status = data['status'] ?? 'alpha';
        String metode = data['metode'] ?? 'manual';
        studentAttendance[nisn] = status;
        studentMethods[nisn] = metode;
      }

      // Prepare CSV data
      List<List<dynamic>> csvData = [];

      // Add header row
      csvData.add([
        'NISN',
        'Nama Siswa',
        'Kelas',
        'Jenis Kelamin',
        'Status Kehadiran',
        'Metode'
      ]);

      // Add data rows
      for (var doc in studentSnapshot.docs) {
        Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
        String nisn = doc.id;
        String status = studentAttendance[nisn] ?? 'alpha';
        String metode = studentMethods[nisn] ?? 'manual';

        csvData.add([
          '="' + nisn + '"', // Format to preserve leading zeros
          studentData['nama_siswa'] ?? 'Nama tidak tersedia',
          studentData['kelas_sw']?.toUpperCase() ?? 'Tidak diketahui',
          studentData['jenis_kelamin'] == 'l' ? 'Laki-laki' : 'Perempuan',
          status.toUpperCase(),
          metode == 'face_recognition' ? 'Face Recognition' : 'Manual'
        ]);
      }

      // Add summary row
      Map<String, int> statusCount = {
        'hadir': 0,
        'sakit': 0,
        'izin': 0,
        'alpha': 0
      };

      for (var status in studentAttendance.values) {
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }

      csvData.add([]); // Empty row
      csvData.add(['REKAPITULASI KEHADIRAN']);
      csvData.add(['Tanggal', _formatDate(selectedDate)]);
      csvData.add(['Total Siswa', studentSnapshot.docs.length.toString()]);
      csvData.add(['Hadir', statusCount['hadir'].toString()]);
      csvData.add(['Sakit', statusCount['sakit'].toString()]);
      csvData.add(['Izin', statusCount['izin'].toString()]);
      csvData.add(['Alpha', statusCount['alpha'].toString()]);

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(csvData);

      // Generate filename
      String filename =
          'laporan_kehadiran_${_formatDateForFilename(selectedDate)}.csv';

      // Save report data to Firestore
      await FirebaseFirestore.instance.collection('laporan').doc(newId).set({
        'id_laporan': newId,
        'tanggal_laporan': Timestamp.fromDate(selectedDate),
        'file_laporan': filename,
      });

      if (kIsWeb) {
        // Web platform
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile platform
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(csv);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Laporan Kehadiran ${_formatDate(selectedDate)}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan berhasil diunduh'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      log('Error downloading report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh laporan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 1),
          child: Text(
            'Daftar Kehadiran Siswa',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.left,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _downloadDailyReport,
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Unduh Laporan',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      StudentScreen(userEmail: widget.userEmail),
                ),
              ).then((_) => _loadStudentData());
            },
            icon: const Icon(Icons.person_add, color: Colors.white),
            tooltip: 'Tambah Siswa',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    const Text('Tanggal Presensi',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(selectedDate),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
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

          // Search and filters
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau NISN siswa...',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF4CAF50)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Gender filter
                DropdownButtonFormField<String>(
                  value: selectedGenderFilter,
                  decoration: InputDecoration(
                    labelText: 'Jenis Kelamin',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Semua'),
                    ),
                    ...genderOptions.map((gender) => DropdownMenuItem<String>(
                          value: gender,
                          child: Text(genderLabels[gender]!),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedGenderFilter = value;
                      _applyFilters();
                    });
                  },
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
                      child: Text(errorMessage!,
                          style: const TextStyle(color: Colors.red))),
                  TextButton(
                      onPressed: _loadStudentData, child: const Text('Retry')),
                ],
              ),
            ),

          // Summary Card
          if (!isLoading && filteredStudentList.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Total',
                      filteredStudentList.length.toString(), Colors.blue),
                  _buildSummaryItem(
                      'Hadir',
                      filteredStudentList
                          .where((s) => s.todayAttendanceStatus == 'hadir')
                          .length
                          .toString(),
                      Colors.green),
                  _buildSummaryItem(
                      'Alpha',
                      filteredStudentList
                          .where((s) => s.todayAttendanceStatus == 'alpha')
                          .length
                          .toString(),
                      Colors.red),
                  _buildSummaryItem(
                      'Izin/Sakit',
                      filteredStudentList
                          .where((s) =>
                              s.todayAttendanceStatus == 'izin' ||
                              s.todayAttendanceStatus == 'sakit')
                          .length
                          .toString(),
                      Colors.orange),
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
                  : filteredStudentList.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadStudentData,
                          color: const Color(0xFF4CAF50),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredStudentList.length,
                            itemBuilder: (context, index) {
                              final student = filteredStudentList[index];
                              return _buildStudentCard(student);
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            studentList.isEmpty
                ? 'Belum ada data siswa'
                : 'Tidak ada siswa yang sesuai filter',
            style: const TextStyle(
                fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            studentList.isEmpty
                ? 'Tambah data siswa terlebih dahulu'
                : 'Coba ubah filter pencarian',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (studentList.isEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        StudentScreen(userEmail: widget.userEmail),
                  ),
                ).then((_) => _loadStudentData());
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Tambah Siswa'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(StudentAttendanceModel student) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(student.nama,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              onPressed: () => _showEditStudentDialog(student),
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.grey[600],
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: 'Edit Data Siswa',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NISN: ${student.nisn}',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Kelas: ${student.kelas.toUpperCase()}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Jenis Kelamin: ${genderLabels[student.jenisKelamin] ?? student.jenisKelamin}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              student.hasFaceRegistered
                                  ? Icons.face
                                  : Icons.face_retouching_off,
                              size: 16,
                              color: student.hasFaceRegistered
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
                                color: student.hasFaceRegistered
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status indicator has been removed
                ],
              ),
              const SizedBox(height: 12),
              // Attendance status buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: statusOptions.map((status) {
                  bool isSelected = student.todayAttendanceStatus == status;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? statusColors[status]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Manual attendance and history buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showQuickManualAttendance(student),
                      icon: const Icon(Icons.edit, size: 16),
                      label:
                          const Text('Manual', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAttendanceHistory(student),
                      icon: const Icon(Icons.history, size: 16),
                      label:
                          const Text('Riwayat', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modify the _showEditStudentDialog function to add a delete button
  Future<void> _showEditStudentDialog(StudentAttendanceModel student) async {
    final TextEditingController nameController =
        TextEditingController(text: student.nama);
    final TextEditingController nisnController =
        TextEditingController(text: student.nisn);
    final TextEditingController emailOrangtuaController =
        TextEditingController();
    final TextEditingController telpOrangtuaController =
        TextEditingController();
    String selectedClass = student.kelas;
    String selectedGender = student.jenisKelamin;

    // Load existing parent contact info
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('siswa')
          .doc(student.nisn)
          .get();
      if (studentDoc.exists) {
        Map<String, dynamic> data = studentDoc.data() as Map<String, dynamic>;
        emailOrangtuaController.text = data['email_orangtua'] ?? '';
        telpOrangtuaController.text = data['telp_orangtua'] ?? '';
      }
    } catch (e) {
      log('Error loading parent contact: $e');
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Data Siswa'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Student info header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.person, color: Color(0xFF4CAF50)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Data Siswa',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // NISN field
                    TextFormField(
                      controller: nisnController,
                      decoration: const InputDecoration(
                        labelText: 'NISN',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                        helperText: 'NISN harus 10 digit',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 16),

                    // Name field
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Siswa',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Class field
                    TextFormField(
                      initialValue: selectedClass,
                      decoration: const InputDecoration(
                        labelText: 'Kelas',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.class_),
                      ),
                      onChanged: (value) {
                        selectedClass = value;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender dropdown
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Kelamin',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.people),
                      ),
                      items: genderOptions.map((gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(genderLabels[gender]!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Divider for Parent Contact Info
                    const Divider(thickness: 1),
                    const SizedBox(height: 8),
                    const Text(
                      'Data Orang Tua / Wali',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Email Orang Tua
                    TextFormField(
                      controller: emailOrangtuaController,
                      decoration: const InputDecoration(
                        labelText: 'Email Orang Tua / Wali',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                        helperText: 'Email untuk notifikasi presensi',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Telepon Orang Tua
                    TextFormField(
                      controller: telpOrangtuaController,
                      decoration: const InputDecoration(
                        labelText: 'No. Telepon / WhatsApp',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                        helperText: 'Format: 08xxx atau 62xxx',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              actions: [
                // Delete button
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteStudent(student.nisn);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label:
                      const Text('Hapus', style: TextStyle(color: Colors.red)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama siswa tidak boleh kosong'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (nisnController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('NISN tidak boleh kosong'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (nisnController.text.trim().length != 10) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('NISN harus 10 digit'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (!RegExp(r'^\d+$')
                        .hasMatch(nisnController.text.trim())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('NISN harus berupa angka'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop({
                      'nisn': nisnController.text.trim(),
                      'nama': nameController.text.trim(),
                      'kelas': selectedClass,
                      'jenis_kelamin': selectedGender,
                      'email_orangtua': emailOrangtuaController.text.trim(),
                      'telp_orangtua': telpOrangtuaController.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _updateStudentData(student.nisn, result);
    }
  }

  // Add this function after _updateStudentData
  Future<void> _deleteStudent(String nisn) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Hapus Siswa'),
            content: const Text(
              'Apakah Anda yakin ingin menghapus data siswa ini? Tindakan ini tidak dapat dibatalkan.',
              style: TextStyle(color: Colors.red),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Hapus'),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        return;
      }

      // Delete student data
      await FirebaseFirestore.instance.collection('siswa').doc(nisn).delete();

      // Delete face registration data if exists
      QuerySnapshot faceSnapshot = await FirebaseFirestore.instance
          .collection('wajah_siswa')
          .where('nisn', isEqualTo: nisn)
          .get();

      for (var doc in faceSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete attendance records
      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get();

      for (var doc in attendanceSnapshot.docs) {
        await doc.reference.delete();
      }

      _showToast('Data siswa berhasil dihapus');
      await _loadStudentData();
    } catch (e) {
      log('Error deleting student: $e');
      _showToast('Gagal menghapus data siswa: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Update the _updateStudentData method to handle NISN changes
  Future<void> _updateStudentData(
      String oldNisn, Map<String, dynamic> data) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get the current student data to preserve NIP
      DocumentSnapshot currentStudent = await FirebaseFirestore.instance
          .collection('siswa')
          .doc(oldNisn)
          .get();

      Map<String, dynamic> currentData =
          currentStudent.data() as Map<String, dynamic>;
      String currentNip = currentData['nip'] ?? '';

      // If NISN is changed, we need to create a new document and delete the old one
      if (data['nisn'] != oldNisn) {
        // Create new document with new NISN as document ID
        await FirebaseFirestore.instance
            .collection('siswa')
            .doc(data['nisn'])
            .set({
          'nisn': data['nisn'],
          'nama_siswa': data['nama'],
          'kelas_sw': data['kelas'],
          'jenis_kelamin': data['jenis_kelamin'],
          'nip': currentNip,
          'email_orangtua': data['email_orangtua'] ?? '',
          'telp_orangtua': data['telp_orangtua'] ?? '',
        });

        // Update attendance records with new NISN
        QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
            .collection('presensi')
            .where('nisn', isEqualTo: oldNisn)
            .get();

        for (var doc in attendanceSnapshot.docs) {
          await doc.reference.update({
            'nisn': data['nisn'],
          });
        }

        // Update face registration records with new NISN
        QuerySnapshot faceSnapshot = await FirebaseFirestore.instance
            .collection('wajah_siswa')
            .where('nisn', isEqualTo: oldNisn)
            .get();

        for (var doc in faceSnapshot.docs) {
          await doc.reference.update({
            'nisn': data['nisn'],
          });
        }

        // Delete old document
        await FirebaseFirestore.instance
            .collection('siswa')
            .doc(oldNisn)
            .delete();
      } else {
        // Just update the existing document
        await FirebaseFirestore.instance
            .collection('siswa')
            .doc(oldNisn)
            .update({
          'nisn': data['nisn'],
          'nama_siswa': data['nama'],
          'kelas_sw': data['kelas'],
          'jenis_kelamin': data['jenis_kelamin'],
          'nip': currentNip,
          'email_orangtua': data['email_orangtua'] ?? '',
          'telp_orangtua': data['telp_orangtua'] ?? '',
        });
      }

      _showToast('Data siswa berhasil diperbarui');
      await _loadStudentData();
    } catch (e) {
      log('Error updating student data: $e');
      _showToast('Gagal memperbarui data siswa: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}

// Student attendance model
class StudentAttendanceModel {
  final String nisn;
  final String nama;
  final String kelas;
  final String jenisKelamin;
  final bool hasFaceRegistered;
  final String todayAttendanceStatus;

  StudentAttendanceModel({
    required this.nisn,
    required this.nama,
    required this.kelas,
    required this.jenisKelamin,
    required this.hasFaceRegistered,
    required this.todayAttendanceStatus,
  });
}

// Attendance History Screen
class AttendanceHistoryScreen extends StatefulWidget {
  final StudentAttendanceModel student;

  const AttendanceHistoryScreen({super.key, required this.student});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceRecord> attendanceHistory = [];
  List<AttendanceRecord> filteredHistory = [];
  bool isLoading = true;
  String selectedFilter = 'semua';
  String searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  final Map<String, Color> statusColors = {
    'hadir': Colors.green,
    'sakit': Colors.orange,
    'izin': Colors.blue,
    'alpha': Colors.red,
  };

  final Map<String, String> genderLabels = {
    'l': 'Laki-laki',
    'p': 'Perempuan',
  };

  final List<String> filterOptions = [
    'semua',
    'hadir',
    'sakit',
    'izin',
    'alpha'
  ];

  final Map<String, String> filterLabels = {
    'semua': 'Semua Status',
    'hadir': 'Hadir',
    'sakit': 'Sakit',
    'izin': 'Izin',
    'alpha': 'Alpha'
  };

  String _formatDateForFilename(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadDailyReport() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get the latest report ID
      final latestReport = await FirebaseFirestore.instance
          .collection('laporan')
          .orderBy('id_laporan', descending: true)
          .limit(1)
          .get();

      String newId;
      if (latestReport.docs.isEmpty) {
        newId = 'idlpmi0001';
      } else {
        final lastId = latestReport.docs.first['id_laporan'];
        int lastNumber = 0;

        if (lastId is String) {
          String processedId = lastId;
          if (processedId.startsWith('idlpmi')) {
            processedId = processedId.substring(6);
          }
          String numericPart = processedId.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericPart.isNotEmpty) {
            try {
              lastNumber = int.parse(numericPart);
            } catch (e) {
              log('Warning: Could not parse numeric part "$numericPart" from last report ID "$lastId". Error: $e. Defaulting to 0.');
            }
          }
        }
        newId = 'idlpmi${(lastNumber + 1).toString().padLeft(4, '0')}';
      }

      // Prepare CSV data
      List<List<dynamic>> csvData = [];

      // Add header row
      csvData.add(['Tanggal', 'Waktu', 'Status', 'Metode']);

      // Add data rows
      for (var record in attendanceHistory) {
        csvData.add([
          _formatDate(record.tanggalWaktu),
          _formatTime(record.tanggalWaktu),
          record.status.toUpperCase(),
          record.metode == 'face_recognition' ? 'Face Recognition' : 'Manual'
        ]);
      }

      // Add summary section
      Map<String, int> statusCount = {
        'hadir': 0,
        'sakit': 0,
        'izin': 0,
        'alpha': 0
      };

      for (var record in attendanceHistory) {
        statusCount[record.status] = (statusCount[record.status] ?? 0) + 1;
      }

      csvData.add([]); // Empty row
      csvData.add(['REKAPITULASI KEHADIRAN']);
      csvData.add(['Nama Siswa', widget.student.nama]);
      csvData.add([
        'NISN',
        '="${widget.student.nisn}"'
      ]); // Format to preserve leading zeros
      csvData.add(['Kelas', widget.student.kelas.toUpperCase()]);
      csvData.add(['Total Presensi', attendanceHistory.length.toString()]);
      csvData.add(['Hadir', statusCount['hadir'].toString()]);
      csvData.add(['Sakit', statusCount['sakit'].toString()]);
      csvData.add(['Izin', statusCount['izin'].toString()]);
      csvData.add(['Alpha', statusCount['alpha'].toString()]);

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(csvData);

      // Generate filename
      String filename =
          'laporan_kehadiran_${widget.student.nisn}_${_formatDateForFilename(DateTime.now())}.csv';

      // Save report data to Firestore
      await FirebaseFirestore.instance.collection('laporan').doc(newId).set({
        'id_laporan': newId,
        'tanggal_laporan': Timestamp.fromDate(DateTime.now()),
        'file_laporan': filename,
      });

      if (kIsWeb) {
        // Web platform
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile platform
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(csv);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Laporan Kehadiran ${widget.student.nama}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan berhasil diunduh'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      log('Error downloading report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh laporan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    filteredHistory = attendanceHistory.where((record) {
      // Status filter
      bool matchesStatus =
          selectedFilter == 'semua' || record.status == selectedFilter;

      // Date search filter (format: DD/MM/YYYY)
      bool matchesSearch = searchQuery.isEmpty ||
          _formatDate(record.tanggalWaktu)
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          _formatDateTime(record.tanggalWaktu)
              .toLowerCase()
              .contains(searchQuery.toLowerCase());

      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      setState(() {
        isLoading = true;
      });

      log('Loading attendance history for NISN: ${widget.student.nisn}');

      // Query collection presensi berdasarkan NISN
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: widget.student.nisn)
          .get(); // Hapus orderBy dulu untuk debugging

      log('Found ${snapshot.docs.length} attendance records');

      List<AttendanceRecord> tempList = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          log('Processing record: ${doc.id}');
          log('   - Data: $data');

          if (data['tanggal_waktu'] != null) {
            DateTime recordDate = (data['tanggal_waktu'] as Timestamp).toDate();
            String status = data['status'] ?? 'alpha';
            String metode = data['metode'] ?? 'manual';

            tempList.add(AttendanceRecord(
              id: doc.id,
              idPresensi: data['id_presensi'] ?? doc.id,
              tanggalWaktu: recordDate,
              status: status,
              metode: metode,
            ));

            log('Added: $status on ${recordDate.toIso8601String()}');
          } else {
            log('No tanggal_waktu field found');
          }
        } catch (e) {
          log('Error processing record ${doc.id}: $e');
        }
      }

      // Sort manual berdasarkan tanggal (terbaru dulu)
      tempList.sort((a, b) => b.tanggalWaktu.compareTo(a.tanggalWaktu));

      setState(() {
        attendanceHistory = tempList;
        filteredHistory = tempList;
        isLoading = false;
      });

      log('Successfully loaded ${tempList.length} attendance records');
    } catch (e) {
      log('Error loading attendance history: $e');
      setState(() {
        isLoading = false;
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat riwayat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods
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

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getAttendanceStats();

    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 1),
          child: Text(
            'Daftar Kehadiran Siswa',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.left,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _downloadDailyReport,
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Unduh Laporan',
          ),
          IconButton(
            onPressed: () => _showEditAttendanceDialog(),
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Tambah Presensi Manual',
          ),
        ],
      ),
      body: Column(
        children: [
          // Student info header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.student.nama,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 8),
                          Text('NISN: ${widget.student.nisn}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600])),
                          Text('Kelas: ${widget.student.kelas.toUpperCase()}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600])),
                          Text(
                              'Jenis Kelamin: ${genderLabels[widget.student.jenisKelamin] ?? widget.student.jenisKelamin}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    // Face registration status
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.student.hasFaceRegistered
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            widget.student.hasFaceRegistered
                                ? Icons.face
                                : Icons.face_retouching_off,
                            color: widget.student.hasFaceRegistered
                                ? Colors.green
                                : Colors.red,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.student.hasFaceRegistered
                                ? 'Terdaftar'
                                : 'Belum',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.student.hasFaceRegistered
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Statistics Summary
          if (!isLoading &&
              filteredHistory.isNotEmpty) // Use filteredHistory here
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistik Kehadiran',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Total', '${stats['total']}', Colors.blue),
                      _buildStatItem(
                          'Hadir', '${stats['hadir']}', Colors.green),
                      _buildStatItem(
                          'Sakit', '${stats['sakit']}', Colors.orange),
                      _buildStatItem('Izin', '${stats['izin']}', Colors.blue),
                      _buildStatItem('Alpha', '${stats['alpha']}', Colors.red),
                    ],
                  ),
                ],
              ),
            ),

          // Search and Filter
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari tanggal (DD/MM/YYYY)...',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF4CAF50)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Status filter
                DropdownButtonFormField<String>(
                  value: selectedFilter,
                  decoration: InputDecoration(
                    labelText: 'Filter Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: filterOptions
                      .map((filter) => DropdownMenuItem<String>(
                            value: filter,
                            child: Text(filterLabels[filter]!),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedFilter = value!;
                      _applyFilters();
                    });
                  },
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
                  ? const Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Memuat riwayat presensi...'),
                      ],
                    ))
                  : filteredHistory.isEmpty
                      ? Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              attendanceHistory.isEmpty
                                  ? 'Belum ada riwayat presensi'
                                  : 'Tidak ada data sesuai filter',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                            if (attendanceHistory.isEmpty)
                              const SizedBox(height: 8),
                            if (attendanceHistory.isEmpty)
                              const Text(
                                'Presensi akan muncul setelah siswa melakukan absen',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ))
                      : RefreshIndicator(
                          onRefresh: _loadAttendanceHistory,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredHistory.length,
                            itemBuilder: (context, index) {
                              final record = filteredHistory[index];
                              return _buildAttendanceCard(record);
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onLongPress: () => _showEditAttendanceDialog(record: record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Date and day
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(record.tanggalWaktu),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(record.tanggalWaktu),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Edit button
                  IconButton(
                    onPressed: () => _showEditAttendanceDialog(record: record),
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.grey[600],
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    tooltip: 'Edit Presensi',
                  ),
                  const SizedBox(width: 8),

                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColors[record.status]!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColors[record.status]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          record.status == 'hadir'
                              ? Icons.check_circle
                              : record.status == 'sakit'
                                  ? Icons.sick
                                  : record.status == 'izin'
                                      ? Icons.assignment
                                      : Icons.cancel,
                          size: 16,
                          color: statusColors[record.status],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColors[record.status],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Additional info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Jam: ${_formatTime(record.tanggalWaktu)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      record.metode == 'face_recognition'
                          ? Icons.face
                          : Icons.edit,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.metode == 'face_recognition'
                          ? 'Face Recognition'
                          : 'Manual',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // ID Presensi dan edit instruction
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ID: ${record.idPresensi}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  Text(
                    'Tekan & tahan untuk edit',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, int> _getAttendanceStats() {
    Map<String, int> stats = {
      'total': attendanceHistory.length,
      'hadir': 0,
      'sakit': 0,
      'izin': 0,
      'alpha': 0,
    };

    for (var record in attendanceHistory) {
      stats[record.status] = (stats[record.status] ?? 0) + 1;
    }

    return stats;
  }

  Future<void> _showEditAttendanceDialog({AttendanceRecord? record}) async {
    String selectedStatus = record?.status ?? 'hadir';
    DateTime selectedDate = record?.tanggalWaktu ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay(
      hour: record?.tanggalWaktu.hour ?? DateTime.now().hour,
      minute: record?.tanggalWaktu.minute ?? DateTime.now().minute,
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(record == null ? 'Tambah Presensi' : 'Edit Presensi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Student info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.student.nama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'NISN: ${widget.student.nisn}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status Presensi',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                        DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                        DropdownMenuItem(value: 'izin', child: Text('Izin')),
                        DropdownMenuItem(value: 'alpha', child: Text('Alpha')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedStatus = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date picker
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Tanggal'),
                      subtitle: Text(_formatDate(selectedDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Time picker
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Waktu'),
                      subtitle: Text(_formatTime(selectedDate)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                            selectedDate = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'status': selectedStatus,
                      'tanggal_waktu': selectedDate,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      try {
        setState(() {
          isLoading = true;
        });

        if (record == null) {
          // Create new attendance record
          String attendanceId = await _generateAttendanceId();
          await FirebaseFirestore.instance
              .collection('presensi')
              .doc(attendanceId)
              .set({
            'id_presensi': attendanceId,
            'nisn': widget.student.nisn,
            'tanggal_waktu': Timestamp.fromDate(result['tanggal_waktu']),
            'status': result['status'],
            'metode': 'manual',
            'created_at': FieldValue.serverTimestamp(),
          });
        } else {
          // Update existing record
          await FirebaseFirestore.instance
              .collection('presensi')
              .doc(record.id)
              .update({
            'tanggal_waktu': Timestamp.fromDate(result['tanggal_waktu']),
            'status': result['status'],
            'metode': 'manual',
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        _showToast(record == null
            ? 'Presensi berhasil ditambahkan'
            : 'Presensi berhasil diperbarui');
        await _loadAttendanceHistory();
      } catch (e) {
        log('Error saving attendance: $e');
        _showToast('Gagal menyimpan presensi: ${e.toString()}');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Add these helper methods before the build method in _AttendanceHistoryScreenState
  Future<String> _generateAttendanceId() async {
    try {
      const String prefix = 'idpr04';

      // Query only the last record with the prefix to get the highest number
      QuerySnapshot lastRecords = await FirebaseFirestore.instance
          .collection('presensi')
          .where('id_presensi', isGreaterThanOrEqualTo: prefix)
          .where('id_presensi', isLessThan: '${prefix}z')
          .orderBy('id_presensi', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;

      if (lastRecords.docs.isNotEmpty) {
        String lastId = lastRecords.docs.first.get('id_presensi') as String;
        log('Last attendance ID found: $lastId');

        if (lastId.length >= 10 && lastId.startsWith(prefix)) {
          String lastNumberStr = lastId.substring(6);
          int lastNumber = int.tryParse(lastNumberStr) ?? 0;
          nextNumber = lastNumber + 1;
        }
      }

      String formattedNumber = nextNumber.toString().padLeft(4, '0');
      String newId = '$prefix$formattedNumber';

      if (newId.length != 10) {
        throw Exception('Generated ID length is not 10 characters: $newId');
      }

      // Check if the ID already exists (rare case)
      DocumentSnapshot existingDoc = await FirebaseFirestore.instance
          .collection('presensi')
          .doc(newId)
          .get();

      if (existingDoc.exists) {
        log('ID $newId already exists, trying next number...');
        nextNumber++;
        formattedNumber = nextNumber.toString().padLeft(4, '0');
        newId = '$prefix$formattedNumber';
      }

      log('Generated attendance ID: $newId');
      return newId;
    } catch (e) {
      log('Error generating attendance ID: $e');

      // Fallback: use timestamp-based ID
      DateTime now = DateTime.now();
      String timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      String fallbackId = 'idpr04$timeString';

      log('Using fallback ID: $fallbackId');
      return fallbackId;
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Model for attendance record
class AttendanceRecord {
  final String id;
  final String idPresensi;
  final DateTime tanggalWaktu;
  final String status;
  final String metode;

  AttendanceRecord({
    required this.id,
    required this.idPresensi,
    required this.tanggalWaktu,
    required this.status,
    required this.metode,
  });
}