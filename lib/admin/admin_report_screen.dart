import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html; // For web download
import 'dart:io'; // For mobile/desktop download
import 'package:path_provider/path_provider.dart'; // For mobile/desktop path
import 'package:share_plus/share_plus.dart'; // For mobile/desktop share
import 'package:flutter/foundation.dart' show kIsWeb; // Check if running on web
import 'package:intl/intl.dart'; // For date formatting
import 'dart:convert'; // Required for utf8

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  bool isLoading = false;
  String? errorMessage;
  List<Map<String, dynamic>> attendanceData = [];
  DateTime _selectedDate = DateTime.now(); // Add state for selected date

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

    log('Generating CSV for date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');

    List<List<dynamic>> csvData = [
      // CSV Header
      ['ID Presensi', 'NISN', 'Status', 'Tanggal & Waktu'],
    ];

    for (var record in attendanceData) {
      String idPresensi = record['id_presensi'] ?? '-';
      String nisn = record['nisn'] ?? '-';
      String status = record['status'] ?? '-';
      Timestamp? timestamp = record['tanggal_waktu'] as Timestamp?;

      String tanggalWaktu = timestamp != null
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate())
          : '-';

      csvData.add([idPresensi, nisn, status, tanggalWaktu]);
    }

    String csvString = const ListToCsvConverter().convert(csvData);

    // Generate filename laporan_kehadiran_DDMMYY.csv (using the selected date)
    String formattedDateFilename = DateFormat('ddMMyy').format(_selectedDate);
    String filename = 'laporan_kehadiran_$formattedDateFilename.csv';

    log('CSV generated. Attempting to download/share...');
    log('Filename: $filename');

    if (kIsWeb) {
      // Web download
      try {
        final bytes = utf8.encode(csvString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
        log('Web download initiated.');
        _showToast('Laporan berhasil diunduh');
      } catch (e) {
        log('Error during web download: $e', error: e);
        _showToast('Gagal mengunduh laporan di web');
      }
    } else {
      // Mobile/Desktop share or save
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(csvString);
        log('File saved to: ${file.path}');

        // Use share_plus for cross-platform sharing
        await Share.shareXFiles([XFile(file.path)], text: 'Laporan Kehadiran');
        log('Share dialog shown.');
        _showToast('Laporan siap dibagikan');
      } catch (e) {
        log('Error during mobile/desktop share: $e', error: e);
        _showToast('Gagal membagikan laporan');
      }
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
          padding: const EdgeInsets.all(28.0), // Increased padding
          margin: const EdgeInsets.all(24.0), // Added margin
          decoration: BoxDecoration(
            color: Colors.white, // White background for the card
            borderRadius: BorderRadius.circular(16.0), // Rounded corners
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2), // Subtle shadow
                spreadRadius: 5,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            // Allow content to scroll if needed
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Use minimum space
              children: <Widget>[
                // Icon
                Container(
                  padding: const EdgeInsets.all(16), // Padding around icon
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50)
                        .withOpacity(0.1), // Light green background
                    borderRadius: BorderRadius.circular(50), // Make it circular
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      size: 60, color: Color(0xFF4CAF50)), // Modern icon
                ),
                const SizedBox(height: 28), // Increased spacing
                // Title
                const Text(
                  'Unduh Laporan Kehadiran',
                  style: TextStyle(
                    fontSize: 26, // Slightly larger title
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12), // Spacing
                // Instruction Text
                const Text(
                  'Pilih tanggal laporan yang diinginkan dan tekan tombol unduh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 28), // Spacing
                // Date Picker Button
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_today,
                      color: Colors.white), // White icon
                  label: Text(
                    'Tanggal: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                    style: const TextStyle(
                        fontSize: 18, color: Colors.white), // White text
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF4CAF50), // Green background
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14), // Increased padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                    elevation: 5, // Add shadow
                    shadowColor: const Color(0xFF4CAF50)
                        .withOpacity(0.3), // Green shadow
                  ),
                ),
                const SizedBox(height: 24), // Spacing
                // Download Button
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
                      : const Icon(Icons.download,
                          color: Colors.white), // White icon
                  label: Text(
                    isLoading ? 'Memuat Data...' : 'Unduh Laporan CSV',
                    style: const TextStyle(
                        fontSize: 18, color: Colors.white), // White text
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF4CAF50), // Green background
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14), // Increased padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                    elevation: 5, // Add shadow
                    shadowColor: const Color(0xFF4CAF50)
                        .withOpacity(0.3), // Green shadow
                  ),
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
