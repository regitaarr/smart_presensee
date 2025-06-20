import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html; // For web download
import 'dart:io'; // For mobile/desktop download
import 'package:path_provider/path_provider.dart'; // For mobile/desktop path
import 'package:share_plus/share_plus.dart'; // For mobile/desktop share
import 'package:flutter/foundation.dart' show kIsWeb; // Check if running on web
import 'package:intl/intl.dart'; // For date formatting

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool isLoading = false;
  String _newId = 'idlpmi0001'; // Add class-level variable
  String? errorMessage;
  List<Map<String, dynamic>> attendanceData = [];

  @override
  void initState() {
    super.initState();
    // Data will be loaded based on selected date before download
  }

  Future<void> _loadAttendanceDataForSelectedDate() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      attendanceData = []; // Clear previous data
    });

    log('=== Loading attendance data for date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)} ===');

    try {
      DateTime startOfDay = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, 23, 59, 59);

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          errorMessage = 'Tidak ada data presensi untuk tanggal ini.';
          isLoading = false;
        });
        log('No attendance data found for selected date.');
        return;
      }

      List<Map<String, dynamic>> tempList = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        tempList.add(data);
        log('Loaded attendance record: ${data['nisn']} - ${data['tanggal_waktu']} - ${data['status']}');
      }

      // Sort data by nisn for better readability in report
      tempList.sort((a, b) => (a['nisn'] ?? '').compareTo(b['nisn'] ?? ''));

      setState(() {
        attendanceData = tempList;
        isLoading = false;
      });

      log('Successfully loaded ${attendanceData.length} attendance records for selected date.');
    } catch (e) {
      log('Error loading attendance data for selected date: $e', error: e);
      setState(() {
        errorMessage = 'Gagal memuat data presensi: ${e.toString()}';
        isLoading = false;
      });
      _showToast('Gagal memuat data presensi');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        // Clear previous data and error message when date changes
        attendanceData = [];
        errorMessage = null;
      });
    }
  }

  Future<void> _generateAndDownloadCsv() async {
    if (isLoading) {
      _showToast('Sedang memuat data...');
      return;
    }

    try {
      // Load data if not already loaded for the selected date
      if (attendanceData.isEmpty && errorMessage == null) {
        await _loadAttendanceDataForSelectedDate();
        if (attendanceData.isEmpty) {
          _showToast(errorMessage ?? 'Tidak ada data untuk tanggal ini.');
          return;
        }
      }
      if (attendanceData.isEmpty) {
        // Check again after loading attempt
        _showToast(errorMessage ?? 'Tidak ada data untuk tanggal ini.');
        return;
      }

      log('Generating Excel for date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');

      // Get all students data first
      QuerySnapshot studentSnapshot =
          await FirebaseFirestore.instance.collection('siswa').get();

      // Create a map of NISN to student data for quick lookup
      Map<String, Map<String, dynamic>> studentMap = {};
      for (var doc in studentSnapshot.docs) {
        studentMap[doc.id] = doc.data() as Map<String, dynamic>;
      }

      // Create a map to store attendance status for each student
      Map<String, Map<String, dynamic>> attendanceMap = {};

      // Query attendance records for the selected date
      DateTime startOfDay = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, 23, 59, 59);

      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      for (var doc in attendanceSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String nisn = data['nisn'] ?? '-';
        attendanceMap[nisn] = data;
      }

      // Group students by class
      Map<String, List<Map<String, dynamic>>> classGroups = {};
      for (var doc in studentSnapshot.docs) {
        String nisn = doc.id;
        Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
        String kelas = studentData['kelas_sw']?.toString().toUpperCase() ??
            'TIDAK DIKETAHUI';

        if (!classGroups.containsKey(kelas)) {
          classGroups[kelas] = [];
        }

        // Add student data with attendance status
        Map<String, dynamic> studentWithAttendance = {
          'nisn': nisn,
          'nama': studentData['nama_siswa'] ?? '-',
          'kelas': kelas,
        };

        if (attendanceMap.containsKey(nisn)) {
          var record = attendanceMap[nisn]!;
          studentWithAttendance['status'] = record['status'] ?? 'alpha';
          studentWithAttendance['metode'] = record['metode'] ?? 'manual';
          Timestamp? timestamp = record['tanggal_waktu'] as Timestamp?;
          studentWithAttendance['tanggal'] = timestamp != null
              ? DateFormat('yyyy-MM-dd').format(timestamp.toDate())
              : '-';
          studentWithAttendance['waktu'] = timestamp != null
              ? DateFormat('HH:mm:ss').format(timestamp.toDate())
              : '-';
        } else {
          studentWithAttendance['status'] = 'alpha';
          studentWithAttendance['metode'] = 'manual';
          studentWithAttendance['tanggal'] =
              DateFormat('yyyy-MM-dd').format(_selectedDate);
          studentWithAttendance['waktu'] = '-';
        }

        classGroups[kelas]!.add(studentWithAttendance);
      }

      // Generate Excel for each class
      for (var kelas in classGroups.keys) {
        var excel = Excel.createExcel();
        var sheet = excel.sheets.values.first;

        // Add field headers
        sheet.appendRow(
            ['NISN', 'Nama', 'Tanggal', 'Waktu', 'Status', 'Metode']);

        // Add students for this class
        var students = classGroups[kelas]!;
        students.sort(
            (a, b) => (a['nisn'] as String).compareTo(b['nisn'] as String));

        for (var student in students) {
          sheet.appendRow([
            student['nisn'],
            student['nama'],
            student['tanggal'],
            student['waktu'],
            student['status'],
            student['metode'],
          ]);
        }

        // Add summary section
        Map<String, int> statusCount = {
          'hadir': 0,
          'sakit': 0,
          'izin': 0,
          'alpha': 0
        };

        for (var student in students) {
          statusCount[student['status']] =
              (statusCount[student['status']] ?? 0) + 1;
        }

        sheet.appendRow([]); // Empty row before summary
        sheet.appendRow(['REKAPITULASI KEHADIRAN KELAS $kelas']);
        sheet.appendRow(['Tanggal', _formatDate(_selectedDate)]);
        sheet.appendRow(['Total Siswa', students.length.toString()]);
        sheet.appendRow(['Hadir', statusCount['hadir'].toString()]);
        sheet.appendRow(['Sakit', statusCount['sakit'].toString()]);
        sheet.appendRow(['Izin', statusCount['izin'].toString()]);
        sheet.appendRow(['Alpha', statusCount['alpha'].toString()]);

        // Generate filename
        String filename =
            'laporan_kehadiran_${kelas}_${_formatDateForFilename(_selectedDate)}.xlsx';

        // Save report data to Firestore
        await FirebaseFirestore.instance.collection('laporan').doc(_newId).set({
          'id_laporan': _newId,
          'tanggal_laporan': Timestamp.fromDate(_selectedDate),
          'file_laporan': filename,
          'kelas': kelas,
        });

        if (kIsWeb) {
          // Web platform
          final bytes = excel.encode();
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
          await file.writeAsBytes(excel.encode()!);
          await Share.shareXFiles(
            [XFile(file.path)],
            text:
                'Laporan Kehadiran Kelas $kelas ${_formatDate(_selectedDate)}',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan per kelas berhasil diunduh'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      log('Error downloading class report: $e');
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

  Future<void> _downloadClassReport() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get all students data first to get unique classes
      QuerySnapshot studentSnapshot =
          await FirebaseFirestore.instance.collection('siswa').get();

      // Get unique classes
      Set<String> uniqueClasses = {};
      for (var doc in studentSnapshot.docs) {
        Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
        String kelas = studentData['kelas_sw']?.toString().toUpperCase() ??
            'TIDAK DIKETAHUI';
        uniqueClasses.add(kelas);
      }

      // Sort classes
      List<String> sortedClasses = uniqueClasses.toList()..sort();

      // Show class selection dialog
      String? selectedClass = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Pilih Kelas'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedClasses.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(sortedClasses[index]),
                    onTap: () {
                      Navigator.of(context).pop(sortedClasses[index]);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Batal'),
              ),
            ],
          );
        },
      );

      if (selectedClass == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get the latest report ID
      final latestReport = await FirebaseFirestore.instance
          .collection('laporan')
          .orderBy('id_laporan', descending: true)
          .limit(1)
          .get();

      if (latestReport.docs.isNotEmpty) {
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
        _newId = 'idlpmi${(lastNumber + 1).toString().padLeft(4, '0')}';
      }

      // Create a map of NISN to student data for quick lookup
      Map<String, Map<String, dynamic>> studentMap = {};
      for (var doc in studentSnapshot.docs) {
        studentMap[doc.id] = doc.data() as Map<String, dynamic>;
      }

      // Query attendance records for the selected date
      DateTime startOfDay = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, 23, 59, 59);

      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      // Create a map to store attendance status for each student
      Map<String, Map<String, dynamic>> attendanceMap = {};
      for (var doc in attendanceSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String nisn = data['nisn'] ?? '-';
        attendanceMap[nisn] = data;
      }

      // Filter students by selected class
      List<Map<String, dynamic>> classStudents = [];
      for (var doc in studentSnapshot.docs) {
        String nisn = doc.id;
        Map<String, dynamic> studentData = doc.data() as Map<String, dynamic>;
        String kelas = studentData['kelas_sw']?.toString().toUpperCase() ??
            'TIDAK DIKETAHUI';

        if (kelas == selectedClass) {
          // Add student data with attendance status
          Map<String, dynamic> studentWithAttendance = {
            'nisn': nisn,
            'nama': studentData['nama_siswa'] ?? '-',
            'kelas': kelas,
          };

          if (attendanceMap.containsKey(nisn)) {
            var record = attendanceMap[nisn]!;
            studentWithAttendance['status'] = record['status'] ?? 'alpha';
            studentWithAttendance['metode'] = record['metode'] ?? 'manual';
            Timestamp? timestamp = record['tanggal_waktu'] as Timestamp?;
            studentWithAttendance['tanggal'] = timestamp != null
                ? DateFormat('yyyy-MM-dd').format(timestamp.toDate())
                : '-';
            studentWithAttendance['waktu'] = timestamp != null
                ? DateFormat('HH:mm:ss').format(timestamp.toDate())
                : '-';
          } else {
            studentWithAttendance['status'] = 'alpha';
            studentWithAttendance['metode'] = 'manual';
            studentWithAttendance['tanggal'] =
                DateFormat('yyyy-MM-dd').format(_selectedDate);
            studentWithAttendance['waktu'] = '-';
          }

          classStudents.add(studentWithAttendance);
        }
      }

      // Sort students by NISN
      classStudents
          .sort((a, b) => (a['nisn'] as String).compareTo(b['nisn'] as String));

      // Generate Excel
      var excel = Excel.createExcel();
      var sheet = excel.sheets.values.first;

      // Add field headers
      sheet.appendRow(['NISN', 'Nama', 'Tanggal', 'Waktu', 'Status', 'Metode']);

      // Add students
      for (var student in classStudents) {
        sheet.appendRow([
          student['nisn'],
          student['nama'],
          student['tanggal'],
          student['waktu'],
          student['status'],
          student['metode'],
        ]);
      }

      // Add summary section
      Map<String, int> statusCount = {
        'hadir': 0,
        'sakit': 0,
        'izin': 0,
        'alpha': 0
      };

      for (var student in classStudents) {
        statusCount[student['status']] =
            (statusCount[student['status']] ?? 0) + 1;
      }

      sheet.appendRow([]); // Empty row before summary
      sheet.appendRow(['REKAPITULASI KEHADIRAN KELAS $selectedClass']);
      sheet.appendRow(['Tanggal', _formatDate(_selectedDate)]);
      sheet.appendRow(['Total Siswa', classStudents.length.toString()]);
      sheet.appendRow(['Hadir', statusCount['hadir'].toString()]);
      sheet.appendRow(['Sakit', statusCount['sakit'].toString()]);
      sheet.appendRow(['Izin', statusCount['izin'].toString()]);
      sheet.appendRow(['Alpha', statusCount['alpha'].toString()]);

      // Generate filename
      String filename =
          'laporan_kehadiran_${selectedClass}_${_formatDateForFilename(_selectedDate)}.xlsx';

      // Save report data to Firestore
      await FirebaseFirestore.instance.collection('laporan').doc(_newId).set({
        'id_laporan': _newId,
        'tanggal_laporan': Timestamp.fromDate(_selectedDate),
        'file_laporan': filename,
        'kelas': selectedClass,
      });

      if (kIsWeb) {
        // Web platform
        final bytes = excel.encode();
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
        await file.writeAsBytes(excel.encode()!);
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              'Laporan Kehadiran Kelas $selectedClass ${_formatDate(_selectedDate)}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan per kelas berhasil diunduh'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      log('Error downloading class report: $e');
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

  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      textColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Kehadiran',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(28.0),
          margin: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 5,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      size: 60, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Unduh Laporan Kehadiran',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilih tanggal laporan yang diinginkan dan tekan tombol unduh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                  label: Text(
                    'Tanggal: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF4CAF50).withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _generateAndDownloadCsv,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.download, color: Colors.white),
                      label: Text(
                        isLoading ? 'Memuat Data...' : 'Unduh Semua',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0xFF4CAF50).withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _downloadClassReport,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.class_, color: Colors.white),
                      label: Text(
                        isLoading ? 'Memuat Data...' : 'Unduh Per Kelas',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0xFF4CAF50).withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
