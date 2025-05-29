// ignore_for_file: unused_local_variable, unused_element

import 'dart:developer';
import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smart_presensee/screens/student_screen.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
import 'package:csv/csv.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<StudentAttendanceModel> studentList = [];
  List<StudentAttendanceModel> filteredStudentList = [];
  bool isLoading = true;
  bool isExporting = false;
  DateTime selectedDate = DateTime.now();
  String? errorMessage;
  String searchQuery = '';
  String? selectedGenderFilter;
  String? selectedClassFilter;

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

      // Class filter
      bool matchesClass = selectedClassFilter == null ||
          student.kelas.toLowerCase() == selectedClassFilter!.toLowerCase();

      return matchesSearch && matchesGender && matchesClass;
    }).toList();
  }

  // Export Excel Function
  Future<void> _exportAttendanceToExcel() async {
    try {
      setState(() {
        isExporting = true;
      });

      _showToast('Memulai export data presensi...');

      // Create Excel workbook
      final excel.Workbook workbook = excel.Workbook();
      final excel.Worksheet sheet = workbook.worksheets[0];

      // Set sheet name
      sheet.name = 'Data Presensi';

      // Add headers
      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('NISN');
      sheet.getRangeByName('C1').setText('Nama Siswa');
      sheet.getRangeByName('D1').setText('Kelas');
      sheet.getRangeByName('E1').setText('Jenis Kelamin');
      sheet.getRangeByName('F1').setText('Tanggal');
      sheet.getRangeByName('G1').setText('Waktu');
      sheet.getRangeByName('H1').setText('Status');
      sheet.getRangeByName('I1').setText('Metode');

      // Style headers
      final excel.Range headerRange = sheet.getRangeByName('A1:I1');
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.backColor = '#4CAF50';
      headerRange.cellStyle.fontColor = '#FFFFFF';

      // Fetch attendance data from Firestore
      QuerySnapshot attendanceSnapshot =
          await FirebaseFirestore.instance.collection('presensi').get();

      log('📊 Found ${attendanceSnapshot.docs.length} attendance records');

      // Convert to list and sort manually
      List<QueryDocumentSnapshot> attendanceDocs =
          attendanceSnapshot.docs.toList();

      // Sort by timestamp if available
      attendanceDocs.sort((a, b) {
        try {
          Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
          Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;

          if (dataA['tanggal_waktu'] != null &&
              dataB['tanggal_waktu'] != null) {
            DateTime dateA = (dataA['tanggal_waktu'] as Timestamp).toDate();
            DateTime dateB = (dataB['tanggal_waktu'] as Timestamp).toDate();
            return dateB.compareTo(dateA); // Descending order
          }
          return 0;
        } catch (e) {
          return 0;
        }
      });

      int rowIndex = 2;
      int no = 1;

      for (var attendanceDoc in attendanceDocs) {
        try {
          Map<String, dynamic> attendanceData =
              attendanceDoc.data() as Map<String, dynamic>;

          String nisn = attendanceData['nisn'] ?? '';
          String status = attendanceData['status'] ?? 'alpha';
          String metode = attendanceData['metode'] ?? 'manual';

          if (attendanceData['tanggal_waktu'] != null) {
            DateTime dateTime =
                (attendanceData['tanggal_waktu'] as Timestamp).toDate();

            // Get student data from siswa collection
            DocumentSnapshot studentDoc = await FirebaseFirestore.instance
                .collection('siswa')
                .doc(nisn)
                .get();

            String namaStudent = '';
            String kelas = '';
            String jenisKelamin = '';

            if (studentDoc.exists) {
              Map<String, dynamic> studentData =
                  studentDoc.data() as Map<String, dynamic>;
              namaStudent = studentData['nama_siswa'] ?? 'Nama tidak diketahui';
              kelas = studentData['kelas'] ?? 'Tidak diketahui';
              jenisKelamin = studentData['jenis_kelamin'] ?? 'Tidak diketahui';
            } else {
              namaStudent = 'Data siswa tidak ditemukan';
              kelas = '-';
              jenisKelamin = '-';
            }

            // Format date and time
            String tanggal =
                '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
            String waktu =
                '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

            // Add data to Excel
            sheet.getRangeByName('A$rowIndex').setNumber(no.toDouble());
            sheet.getRangeByName('B$rowIndex').setText(nisn);
            sheet.getRangeByName('C$rowIndex').setText(namaStudent);
            sheet.getRangeByName('D$rowIndex').setText(kelas.toUpperCase());
            sheet
                .getRangeByName('E$rowIndex')
                .setText(genderLabels[jenisKelamin] ?? jenisKelamin);
            sheet.getRangeByName('F$rowIndex').setText(tanggal);
            sheet.getRangeByName('G$rowIndex').setText(waktu);
            sheet.getRangeByName('H$rowIndex').setText(status.toUpperCase());
            sheet.getRangeByName('I$rowIndex').setText(
                metode == 'face_recognition' ? 'Face Recognition' : 'Manual');

            // Color rows based on status
            final excel.Range rowRange =
                sheet.getRangeByName('A$rowIndex:I$rowIndex');
            switch (status) {
              case 'hadir':
                rowRange.cellStyle.backColor = '#E8F5E8';
                break;
              case 'sakit':
                rowRange.cellStyle.backColor = '#FFF3E0';
                break;
              case 'izin':
                rowRange.cellStyle.backColor = '#E3F2FD';
                break;
              case 'alpha':
                rowRange.cellStyle.backColor = '#FFEBEE';
                break;
            }

            rowIndex++;
            no++;
          }
        } catch (e) {
          log('Error processing attendance record: $e');
          continue;
        }
      }

      // Auto-fit columns
      for (int i = 1; i <= 9; i++) {
        sheet.autoFitColumn(i);
      }

      // Save the document
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // Get download path - same as export_excel_screen.dart
      var path = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD);

      // Create filename with current date
      String fileName =
          'Data_Presensi_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}_${DateTime.now().hour}${DateTime.now().minute}.xlsx';

      // Save file
      File file = File('$path/$fileName');
      await file.writeAsBytes(bytes);

      setState(() {
        isExporting = false;
      });

      _showToast('✅ File Excel berhasil disimpan ke Downloads/$fileName');

      // Show success dialog
      _showExportSuccessDialog(fileName, path);
    } catch (e) {
      setState(() {
        isExporting = false;
      });

      log('💥 Error exporting to Excel: $e');
      _showToast('❌ Gagal mengexport data: ${e.toString()}');

      // Show error dialog
      _showExportErrorDialog(e.toString());
    }
  }

  void _showExportSuccessDialog(String fileName, String path) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Export Berhasil!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File Excel berhasil dibuat dengan detail:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.file_present,
                            size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.folder,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            path,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'File dapat ditemukan di folder Downloads pada perangkat Anda.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showExportErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 48),
          title: const Text('Export Gagal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Terjadi kesalahan saat mengexport data:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  error,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Silakan coba lagi atau periksa koneksi internet Anda.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _exportAttendanceToExcel();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Coba Lagi'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadStudentData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      log('=== MULAI LOAD DATA SISWA ===');

      // Load semua siswa dari collection 'siswa'
      QuerySnapshot studentSnapshot = await FirebaseFirestore.instance
          .collection('siswa')
          .orderBy('nama_siswa')
          .get();

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

          // QUICK FIX: Jika method utama bermasalah, uncomment baris di bawah
          // String todayStatus = await _getTodayAttendanceStatusAlternative(nisn);
          String todayStatus = await _getTodayAttendanceStatus(nisn);

          tempList.add(StudentAttendanceModel(
            nisn: nisn,
            nama: studentData['nama_siswa'] ?? 'Nama tidak tersedia',
            kelas: studentData['kelas'] ?? 'Tidak diketahui',
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

      log('🔍 Checking attendance for NISN: $nisn');
      log('📅 Selected date: ${selectedDate.toIso8601String().substring(0, 10)}');
      log('⏰ Start of day: ${startOfDay.toIso8601String()}');
      log('⏰ End of day: ${endOfDay.toIso8601String()}');

      // Pertama, cek semua data presensi untuk NISN ini (tanpa filter tanggal)
      QuerySnapshot allAttendance = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get();

      log('📊 Total attendance records for NISN $nisn: ${allAttendance.docs.length}');

      // Debug: Print semua data presensi
      for (var doc in allAttendance.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        log('📝 Record: ${doc.id}');
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

      log('🔎 Filtering records manually...');

      for (var doc in attendanceSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['tanggal_waktu'] != null) {
          DateTime recordDate = (data['tanggal_waktu'] as Timestamp).toDate();

          // Check apakah tanggal sama
          if (_isSameDay(recordDate, selectedDate)) {
            String status = data['status'] ?? 'alpha';
            log('✅ Found matching attendance for $nisn: $status');
            log('📅 Record date: ${recordDate.toIso8601String()}');
            return status;
          }
        }
      }

      log('❌ No attendance found for $nisn on selected date');
      return 'alpha';
    } catch (e) {
      log('💥 Error getting attendance status for $nisn: $e');
      return 'alpha';
    }
  }

  // Helper function to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Alternative method jika debugging menunjukkan data ada tapi query bermasalah
  Future<String> _getTodayAttendanceStatusAlternative(String nisn) async {
    try {
      log('🔄 Using alternative method for NISN: $nisn');

      // Method 1: Get all records for this NISN, then filter locally
      QuerySnapshot allRecords = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get();

      log('📊 Total records found: ${allRecords.docs.length}');

      for (var doc in allRecords.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['tanggal_waktu'] != null) {
          DateTime recordDate = (data['tanggal_waktu'] as Timestamp).toDate();

          if (_isSameDay(recordDate, selectedDate)) {
            String status = data['status'] ?? 'alpha';
            log('✅ Found: $status for date ${recordDate.toIso8601String()}');
            return status;
          }
        }
      }

      // Method 2: Jika masih tidak ada, coba query dengan format tanggal yang berbeda
      log('🔄 Trying different date format...');

      String dateString =
          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

      QuerySnapshot dateQuery = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get();

      for (var doc in dateQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Cek jika ada field date dalam format string
        if (data.containsKey('tanggal')) {
          String? dateStr = data['tanggal'];
          if (dateStr != null && dateStr.startsWith(dateString)) {
            return data['status'] ?? 'alpha';
          }
        }
      }

      log('❌ No matching record found');
      return 'alpha';
    } catch (e) {
      log('💥 Error in alternative method: $e');
      return 'alpha';
    }
  }

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

  // Save quick manual attendance
  Future<void> _saveQuickManualAttendance(String nisn, String status) async {
    try {
      // Check if attendance already exists for selected date
      DateTime startOfDay = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
      DateTime endOfDay = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Export Excel Button
          IconButton(
            onPressed: isExporting ? null : _exportAttendanceToExcel,
            icon: isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.file_download, color: Colors.white),
            tooltip: 'Export ke Excel',
          ),
          // Export CSV Button
          IconButton(
            onPressed: isExporting ? null : _exportAttendanceToCSV,
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export ke CSV',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentScreen()),
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

                // Filters
                Row(
                  children: [
                    // Gender filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedGenderFilter,
                        decoration: InputDecoration(
                          labelText: 'Jenis Kelamin',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Semua'),
                          ),
                          ...genderOptions
                              .map((gender) => DropdownMenuItem<String>(
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
                    ),
                    const SizedBox(width: 12),

                    // Class filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedClassFilter,
                        decoration: InputDecoration(
                          labelText: 'Kelas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Semua'),
                          ),
                          ...classOptions
                              .map((kelas) => DropdownMenuItem<String>(
                                    value: kelas,
                                    child: Text(kelas.toUpperCase()),
                                  )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedClassFilter = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _loadStudentData,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.refresh, color: Colors.white),
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
                            builder: (context) => const StudentScreen()))
                    .then((_) => _loadStudentData());
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
                        Text(student.nama,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
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
                              'JK: ${genderLabels[student.jenisKelamin] ?? student.jenisKelamin}',
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
                  // Status indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColors[student.todayAttendanceStatus]!
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: statusColors[student.todayAttendanceStatus]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcons[student.todayAttendanceStatus],
                          size: 16,
                          color: statusColors[student.todayAttendanceStatus],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.todayAttendanceStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColors[student.todayAttendanceStatus],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      child: ElevatedButton(
                        onPressed: () => _markAttendance(student.nisn, status),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? statusColors[status]
                              : Colors.grey[200],
                          foregroundColor:
                              isSelected ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: const TextStyle(fontSize: 12),
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

  // Export CSV Function
  Future<void> _exportAttendanceToCSV() async {
    try {
      setState(() {
        isExporting = true;
      });

      _showToast('Memulai export data presensi ke CSV...');

      // Header CSV
      List<List<dynamic>> rows = [
        [
          'No',
          'NISN',
          'Nama Siswa',
          'Kelas',
          'Jenis Kelamin',
          'Tanggal',
          'Waktu',
          'Status',
          'Metode'
        ]
      ];

      // Fetch attendance data from Firestore
      QuerySnapshot attendanceSnapshot =
          await FirebaseFirestore.instance.collection('presensi').get();

      List<QueryDocumentSnapshot> attendanceDocs =
          attendanceSnapshot.docs.toList();

      // Sort by timestamp if available
      attendanceDocs.sort((a, b) {
        try {
          Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
          Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
          if (dataA['tanggal_waktu'] != null &&
              dataB['tanggal_waktu'] != null) {
            DateTime dateA = (dataA['tanggal_waktu'] as Timestamp).toDate();
            DateTime dateB = (dataB['tanggal_waktu'] as Timestamp).toDate();
            return dateB.compareTo(dateA); // Descending order
          }
          return 0;
        } catch (e) {
          return 0;
        }
      });

      int no = 1;
      for (var attendanceDoc in attendanceDocs) {
        try {
          Map<String, dynamic> attendanceData =
              attendanceDoc.data() as Map<String, dynamic>;

          String nisn = attendanceData['nisn'] ?? '';
          String status = attendanceData['status'] ?? 'alpha';
          String metode = attendanceData['metode'] ?? 'manual';

          if (attendanceData['tanggal_waktu'] != null) {
            DateTime dateTime =
                (attendanceData['tanggal_waktu'] as Timestamp).toDate();

            // Get student data from siswa collection
            DocumentSnapshot studentDoc = await FirebaseFirestore.instance
                .collection('siswa')
                .doc(nisn)
                .get();

            String namaStudent = '';
            String kelas = '';
            String jenisKelamin = '';

            if (studentDoc.exists) {
              Map<String, dynamic> studentData =
                  studentDoc.data() as Map<String, dynamic>;
              namaStudent = studentData['nama_siswa'] ?? 'Nama tidak diketahui';
              kelas = studentData['kelas'] ?? 'Tidak diketahui';
              jenisKelamin = studentData['jenis_kelamin'] ?? 'Tidak diketahui';
            } else {
              namaStudent = 'Data siswa tidak ditemukan';
              kelas = '-';
              jenisKelamin = '-';
            }

            // Format date and time
            String tanggal =
                '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
            String waktu =
                '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

            // Add row to CSV
            rows.add([
              no,
              nisn,
              namaStudent,
              kelas.toUpperCase(),
              genderLabels[jenisKelamin] ?? jenisKelamin,
              tanggal,
              waktu,
              status.toUpperCase(),
              metode == 'face_recognition' ? 'Face Recognition' : 'Manual'
            ]);
            no++;
          }
        } catch (e) {
          continue;
        }
      }

      String csvData = const ListToCsvConverter().convert(rows);

      // Get download path
      var path = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD);

      String fileName =
          'Data_Presensi_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}_${DateTime.now().hour}${DateTime.now().minute}.csv';

      File file = File('$path/$fileName');
      await file.writeAsString(csvData);

      setState(() {
        isExporting = false;
      });

      _showToast('✅ File CSV berhasil disimpan ke Downloads/$fileName');
      _showExportSuccessDialog(fileName, path);
    } catch (e) {
      setState(() {
        isExporting = false;
      });
      _showToast('❌ Gagal mengexport data: ${e.toString()}');
      _showExportErrorDialog(e.toString());
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

      log('🔍 Loading attendance history for NISN: ${widget.student.nisn}');

      // Query collection presensi berdasarkan NISN
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: widget.student.nisn)
          .get(); // Hapus orderBy dulu untuk debugging

      log('📊 Found ${snapshot.docs.length} attendance records');

      List<AttendanceRecord> tempList = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          log('📝 Processing record: ${doc.id}');
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

            log('   ✅ Added: $status on ${recordDate.toIso8601String()}');
          } else {
            log('   ❌ No tanggal_waktu field found');
          }
        } catch (e) {
          log('   💥 Error processing record ${doc.id}: $e');
        }
      }

      // Sort manual berdasarkan tanggal (terbaru dulu)
      tempList.sort((a, b) => b.tanggalWaktu.compareTo(a.tanggalWaktu));

      setState(() {
        attendanceHistory = tempList;
        filteredHistory = tempList;
        isLoading = false;
      });

      log('✅ Successfully loaded ${tempList.length} attendance records');
    } catch (e) {
      log('💥 Error loading attendance history: $e');
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

  // Helper function untuk menghitung statistik
  Map<String, int> _getAttendanceStats() {
    Map<String, int> stats = {
      'total': filteredHistory.length,
      'hadir': filteredHistory.where((r) => r.status == 'hadir').length,
      'sakit': filteredHistory.where((r) => r.status == 'sakit').length,
      'izin': filteredHistory.where((r) => r.status == 'izin').length,
      'alpha': filteredHistory.where((r) => r.status == 'alpha').length,
    };
    return stats;
  }

  // Function untuk edit/tambah presensi manual
  Future<void> _showEditAttendanceDialog({AttendanceRecord? record}) async {
    String selectedStatus = record?.status ?? 'sakit';
    DateTime selectedDate = record?.tanggalWaktu ?? DateTime.now();
    final dateController = TextEditingController(
      text:
          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
    );
    final timeController = TextEditingController(
      text:
          '${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                  record == null ? 'Tambah Presensi Manual' : 'Edit Presensi'),
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
                            child: Text(
                              widget.student.nama,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date picker
                    TextFormField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: 'Tanggal (DD/MM/YYYY)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                          dateController.text =
                              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Time picker
                    TextFormField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Waktu (HH:MM)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (picked != null) {
                          selectedDate = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            picked.hour,
                            picked.minute,
                          );
                          timeController.text =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        }
                      },
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

                    // Info note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Presensi ini akan tersimpan sebagai "Manual Entry"',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                if (record != null) // Show delete button for existing records
                  TextButton(
                    onPressed: () => Navigator.of(context).pop({
                      'action': 'delete',
                      'record': record,
                    }),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Hapus'),
                  ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop({
                    'action': record == null ? 'create' : 'update',
                    'status': selectedStatus,
                    'dateTime': selectedDate,
                    'record': record,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: Text(record == null ? 'Simpan' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _handleAttendanceAction(result);
    }
  }

  // Handle create, update, delete attendance
  Future<void> _handleAttendanceAction(Map<String, dynamic> data) async {
    try {
      setState(() {
        isLoading = true;
      });

      final action = data['action'];

      if (action == 'delete') {
        await _deleteAttendance(data['record']);
      } else if (action == 'create') {
        await _createManualAttendance(
          data['status'],
          data['dateTime'],
        );
      } else if (action == 'update') {
        await _updateAttendance(
          data['record'],
          data['status'],
          data['dateTime'],
        );
      }

      // Refresh data
      await _loadAttendanceHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getSuccessMessage(action)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      log('💥 Error handling attendance action: $e');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Gagal ${_getActionText(data['action'])}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Create new manual attendance
  Future<void> _createManualAttendance(String status, DateTime dateTime) async {
    // Check if attendance already exists for this date
    DateTime startOfDay =
        DateTime(dateTime.year, dateTime.month, dateTime.day, 0, 0, 0);
    DateTime endOfDay =
        DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59);

    QuerySnapshot existingAttendance = await FirebaseFirestore.instance
        .collection('presensi')
        .where('nisn', isEqualTo: widget.student.nisn)
        .get();

    // Check manually for same date
    for (var doc in existingAttendance.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['tanggal_waktu'] != null) {
        DateTime recordDate = (data['tanggal_waktu'] as Timestamp).toDate();
        if (_isSameDay(recordDate, dateTime)) {
          throw Exception(
              'Presensi sudah ada untuk tanggal ${_formatDate(dateTime)}');
        }
      }
    }

    // Generate new attendance ID
    String attendanceId = await _generateManualAttendanceId();

    // Create new record
    await FirebaseFirestore.instance
        .collection('presensi')
        .doc(attendanceId)
        .set({
      'id_presensi': attendanceId,
      'nisn': widget.student.nisn,
      'tanggal_waktu': Timestamp.fromDate(dateTime),
      'status': status,
      'metode': 'manual',
      'created_at': FieldValue.serverTimestamp(),
    });

    log('✅ Created manual attendance: $attendanceId');
  }

  // Update existing attendance
  Future<void> _updateAttendance(
      AttendanceRecord record, String status, DateTime dateTime) async {
    await FirebaseFirestore.instance
        .collection('presensi')
        .doc(record.id)
        .update({
      'status': status,
      'tanggal_waktu': Timestamp.fromDate(dateTime),
      'metode': 'manual', // Always mark as manual when edited
      'updated_at': FieldValue.serverTimestamp(),
    });

    log('✅ Updated attendance: ${record.id}');
  }

  // Delete attendance record
  Future<void> _deleteAttendance(AttendanceRecord record) async {
    await FirebaseFirestore.instance
        .collection('presensi')
        .doc(record.id)
        .delete();

    log('✅ Deleted attendance: ${record.id}');
  }

  // Generate manual attendance ID
  Future<String> _generateManualAttendanceId() async {
    const String prefix = 'idpr04';
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('presensi').get();
    final int attendanceCount = snapshot.docs.length + 1;
    final String formattedNumber = attendanceCount.toString().padLeft(4, '0');
    return prefix + formattedNumber;
  }

  // Helper methods
  String _getSuccessMessage(String action) {
    switch (action) {
      case 'create':
        return 'Presensi manual berhasil ditambahkan';
      case 'update':
        return 'Presensi berhasil diupdate';
      case 'delete':
        return 'Presensi berhasil dihapus';
      default:
        return 'Aksi berhasil';
    }
  }

  String _getActionText(String action) {
    switch (action) {
      case 'create':
        return 'menambah presensi';
      case 'update':
        return 'mengupdate presensi';
      case 'delete':
        return 'menghapus presensi';
      default:
        return 'memproses';
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

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Helper function to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getAttendanceStats();

    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text('Riwayat Presensi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showEditAttendanceDialog(),
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Tambah Presensi Manual',
          ),
          IconButton(
            onPressed: _loadAttendanceHistory,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
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
          if (!isLoading && attendanceHistory.isNotEmpty)
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
                    tooltip: 'Edit Presensi',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
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
                      record.metode == 'face_recognition' ? 'Wajah' : 'Manual',
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
