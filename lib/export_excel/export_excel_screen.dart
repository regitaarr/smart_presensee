import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';

class ExportExcelScreen extends StatefulWidget {
  const ExportExcelScreen({super.key});

  @override
  State<ExportExcelScreen> createState() => _ExportExcelScreen();
}

class _ExportExcelScreen extends State<ExportExcelScreen> {
  List<Map<String, String>> dataPresensi = <Map<String, String>>[
    {
      "nama": "John Doe",
      "absen": "Hadir",
      "tanggal": "2022-01-01",
    },
    {
      "nama": "Jane Doe",
      "absen": "Hadir",
      "tanggal": "2022-01-02",
    },
    {
      "nama": "Alice Smith",
      "absen": "Sakit",
      "tanggal": "2022-01-03",
    },
    {
      "nama": "Bob Johnson",
      "absen": "Izin",
      "tanggal": "2022-01-04",
    },
  ];

  bool isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Excel'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Presensi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Total data: ${dataPresensi.length} record',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Preview Data:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Preview table
                      Table(
                        border: TableBorder.all(color: Colors.grey),
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Colors.grey),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Nama',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Tanggal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...dataPresensi
                              .map((data) => TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(data['nama'] ?? ''),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(data['absen'] ?? ''),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(data['tanggal'] ?? ''),
                                      ),
                                    ],
                                  ))
                              .toList(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Export Button
              ElevatedButton.icon(
                onPressed: isExporting ? null : _exportToExcel,
                icon: isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download),
                label: Text(isExporting ? 'Mengekspor...' : 'Export ke Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 10),

              // Info text
              Text(
                'File akan disimpan di folder Download',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      setState(() {
        isExporting = true;
      });

      // Create a new Excel document
      final excel.Workbook workbook = excel.Workbook();
      final excel.Worksheet sheet = workbook.worksheets[0];

      // Set sheet name
      sheet.name = 'Data Presensi';

      // Create headers
      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Nama');
      sheet.getRangeByName('C1').setText('Status Absen');
      sheet.getRangeByName('D1').setText('Tanggal');

      // Style headers (optional - might not work on all versions)
      try {
        final excel.Range headerRange = sheet.getRangeByName('A1:D1');
        headerRange.cellStyle.bold = true;
        headerRange.cellStyle.backColor = '#4CAF50';
        headerRange.cellStyle.fontColor = '#FFFFFF';
      } catch (e) {
        print('Header styling not supported: $e');
        // Continue without styling
      }

      // Add data
      for (int i = 0; i < dataPresensi.length; i++) {
        final rowIndex = i + 2; // Start from row 2 (after header)
        sheet.getRangeByName('A$rowIndex').setNumber(i + 1);
        sheet
            .getRangeByName('B$rowIndex')
            .setText(dataPresensi[i]['nama'] ?? '');
        sheet
            .getRangeByName('C$rowIndex')
            .setText(dataPresensi[i]['absen'] ?? '');
        sheet
            .getRangeByName('D$rowIndex')
            .setText(dataPresensi[i]['tanggal'] ?? '');
      }

      // Auto-fit columns (optional)
      try {
        sheet.autoFitColumn(1);
        sheet.autoFitColumn(2);
        sheet.autoFitColumn(3);
        sheet.autoFitColumn(4);
      } catch (e) {
        print('Auto-fit not supported: $e');
        // Continue without auto-fit
      }

      // Save the document as bytes
      final List<int> bytes = workbook.saveAsStream();

      // Dispose workbook
      workbook.dispose();

      // Try multiple download paths
      final List<String> possiblePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];

      bool fileSaved = false;
      String savedPath = '';
      String fileName = '';

      // Create filename with timestamp
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      fileName = 'DataPresensi_$timestamp.xlsx';

      for (String path in possiblePaths) {
        try {
          print('Trying to save to: $path');

          final directory = Directory(path);

          // Create directory if it doesn't exist
          if (!await directory.exists()) {
            await directory.create(recursive: true);
            print('Created directory: $path');
          }

          final filePath = '$path/$fileName';
          final File file = File(filePath);

          await file.writeAsBytes(bytes, flush: true);

          if (await file.exists()) {
            final fileSize = await file.length();
            print('File saved successfully: $filePath (${fileSize} bytes)');
            fileSaved = true;
            savedPath = filePath;
            break;
          }
        } catch (e) {
          print('Failed to save to $path: $e');
          continue;
        }
      }

      setState(() {
        isExporting = false;
      });

      if (fileSaved) {
        _showToast('File berhasil disimpan: $fileName', Colors.green);
        _showSuccessDialog(savedPath, fileName);
      } else {
        _showToast('Gagal menyimpan file ke semua lokasi', Colors.red);
      }
    } catch (e) {
      setState(() {
        isExporting = false;
      });

      print('Error exporting Excel: $e');
      print('Stack trace: ${StackTrace.current}');
      _showToast('Gagal mengekspor file: ${e.toString()}', Colors.red);
    }
  }

  void _showToast(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _showSuccessDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Export Berhasil'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File Excel berhasil dibuat:'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Lokasi: Download folder',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openFile(filePath);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Buka File'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        _showToast(
            'Tidak dapat membuka file. Silakan buka secara manual dari folder Download.',
            Colors.orange);
      }
    } catch (e) {
      _showToast('Tidak dapat membuka file: ${e.toString()}', Colors.red);
    }
  }
}
