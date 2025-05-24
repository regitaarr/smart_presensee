import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  List<ScheduleModel> scheduleList = [];
  List<ScheduleModel> filteredScheduleList = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  String? selectedDayFilter;
  String? selectedClassFilter;

  final TextEditingController _searchController = TextEditingController();

  final List<String> dayOptions = [
    'senin',
    'selasa',
    'rabu',
    'kamis',
    'jumat',
    'sabtu'
  ];

  final Map<String, String> dayLabels = {
    'senin': 'Senin',
    'selasa': 'Selasa',
    'rabu': 'Rabu',
    'kamis': 'Kamis',
    'jumat': 'Jumat',
    'sabtu': 'Sabtu',
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
    _loadScheduleData();
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
    log('=== APPLYING FILTERS ===');
    log('Original scheduleList length: ${scheduleList.length}');
    log('Search query: "$searchQuery"');
    log('Day filter: $selectedDayFilter');
    log('Class filter: $selectedClassFilter');

    filteredScheduleList = scheduleList.where((schedule) {
      // Search filter
      bool matchesSearch = searchQuery.isEmpty ||
          schedule.mataPelajaran
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          schedule.kelas.toLowerCase().contains(searchQuery.toLowerCase());

      // Day filter
      bool matchesDay = selectedDayFilter == null ||
          schedule.hari.toLowerCase() == selectedDayFilter!.toLowerCase();

      // Class filter
      bool matchesClass = selectedClassFilter == null ||
          schedule.kelas.toLowerCase() == selectedClassFilter!.toLowerCase();

      bool result = matchesSearch && matchesDay && matchesClass;

      if (!result) {
        log('Filtered out: ${schedule.mataPelajaran} - Search: $matchesSearch, Day: $matchesDay, Class: $matchesClass');
      }

      return result;
    }).toList();

    log('Filtered scheduleList length: ${filteredScheduleList.length}');

    // Pastikan setState dipanggil dari main thread jika diperlukan
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadScheduleData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      log('=== MULAI LOAD DATA JADWAL ===');

      // Hapus orderBy yang multiple untuk menghindari composite index error
      QuerySnapshot scheduleSnapshot =
          await FirebaseFirestore.instance.collection('jadwal').get();

      log('Jumlah jadwal ditemukan: ${scheduleSnapshot.docs.length}');

      // Debug: Print semua dokumen yang ditemukan
      for (var doc in scheduleSnapshot.docs) {
        log('Document ID: ${doc.id}');
        log('Document data: ${doc.data()}');
      }

      List<ScheduleModel> tempList = [];

      for (var doc in scheduleSnapshot.docs) {
        try {
          Map<String, dynamic> scheduleData =
              doc.data() as Map<String, dynamic>;
          String scheduleId = doc.id;

          log('=== Processing document: $scheduleId ===');
          log('Raw data: $scheduleData');

          // Debug: Print semua field yang ada
          scheduleData.forEach((key, value) {
            log('Field: $key = $value (${value.runtimeType})');
          });

          // Convert Timestamp to TimeOfDay for display
          TimeOfDay jamMulai = const TimeOfDay(hour: 8, minute: 0); // default
          TimeOfDay jamSelesai = const TimeOfDay(hour: 9, minute: 0); // default

          if (scheduleData['jam_mulai'] != null) {
            try {
              DateTime jamMulaiDate =
                  (scheduleData['jam_mulai'] as Timestamp).toDate();
              jamMulai = TimeOfDay(
                  hour: jamMulaiDate.hour, minute: jamMulaiDate.minute);
              log('Jam mulai berhasil diparse: ${_formatTimeOfDay(jamMulai)}');
            } catch (e) {
              log('Error parsing jam_mulai: $e');
            }
          } else {
            log('jam_mulai field is null');
          }

          if (scheduleData['jam_selesai'] != null) {
            try {
              DateTime jamSelesaiDate =
                  (scheduleData['jam_selesai'] as Timestamp).toDate();
              jamSelesai = TimeOfDay(
                  hour: jamSelesaiDate.hour, minute: jamSelesaiDate.minute);
              log('Jam selesai berhasil diparse: ${_formatTimeOfDay(jamSelesai)}');
            } catch (e) {
              log('Error parsing jam_selesai: $e');
            }
          } else {
            log('jam_selesai field is null');
          }

          String hari = scheduleData['hari'] ?? '';
          String mataPelajaran = scheduleData['mata_pelajaran'] ?? '';
          String kelas = scheduleData['kelas'] ?? '';

          log('Extracted values:');
          log('- hari: $hari');
          log('- mata_pelajaran: $mataPelajaran');
          log('- kelas: $kelas');
          log('- jamMulai: ${_formatTimeOfDay(jamMulai)}');
          log('- jamSelesai: ${_formatTimeOfDay(jamSelesai)}');

          tempList.add(ScheduleModel(
            id: scheduleId,
            hari: hari,
            jamMulai: jamMulai,
            jamSelesai: jamSelesai,
            mataPelajaran: mataPelajaran,
            kelas: kelas,
          ));

          log('✅ Berhasil memproses jadwal: $scheduleId');
        } catch (e) {
          log('❌ Error processing schedule ${doc.id}: $e');
          log('Stack trace: ${StackTrace.current}');
          continue;
        }
      }

      // Sort manual berdasarkan hari dan jam
      tempList.sort((a, b) {
        // Sort by day first
        int dayComparison = dayOptions
            .indexOf(a.hari.toLowerCase())
            .compareTo(dayOptions.indexOf(b.hari.toLowerCase()));
        if (dayComparison != 0) return dayComparison;

        // Then sort by time
        int aMinutes = a.jamMulai.hour * 60 + a.jamMulai.minute;
        int bMinutes = b.jamMulai.hour * 60 + b.jamMulai.minute;
        return aMinutes.compareTo(bMinutes);
      });

      setState(() {
        scheduleList = tempList;
        filteredScheduleList = tempList;
        isLoading = false;
      });

      log('✅ Total jadwal berhasil diproses: ${tempList.length}');
      log('Schedule list items:');
      for (var schedule in tempList) {
        log('- ${schedule.hari}: ${schedule.mataPelajaran} (${schedule.kelas}) ${_formatTimeOfDay(schedule.jamMulai)}-${_formatTimeOfDay(schedule.jamSelesai)}');
      }
    } catch (e) {
      log('💥 ERROR saat load data jadwal: $e');
      log('Stack trace: ${StackTrace.current}');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
      _showToast('Gagal memuat data jadwal: ${e.toString()}');
    }
  }

  Future<String> _generateScheduleId() async {
    try {
      const String prefix = 'idjd04';

      // Query untuk mendapatkan ID terakhir dengan prefix yang sama
      QuerySnapshot lastRecords = await FirebaseFirestore.instance
          .collection('jadwal')
          .where('id_jadwal', isGreaterThanOrEqualTo: prefix)
          .where('id_jadwal', isLessThan: prefix + 'z')
          .orderBy('id_jadwal', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1; // Default jika belum ada data

      if (lastRecords.docs.isNotEmpty) {
        String lastId = lastRecords.docs.first.get('id_jadwal') as String;
        log('Last schedule ID found: $lastId');

        // Extract 4 digit terakhir dari ID
        if (lastId.length >= 10 && lastId.startsWith(prefix)) {
          String lastNumberStr = lastId.substring(6); // Ambil 4 digit terakhir
          int lastNumber = int.tryParse(lastNumberStr) ?? 0;
          nextNumber = lastNumber + 1;
        }
      }

      // Format 4 digit dengan leading zeros
      String formattedNumber = nextNumber.toString().padLeft(4, '0');
      String newId = '$prefix$formattedNumber';

      // Validasi panjang ID (harus tepat 10 karakter)
      if (newId.length != 10) {
        throw Exception('Generated ID length is not 10 characters: $newId');
      }

      // Double-check apakah ID sudah ada (untuk menghindari duplicate)
      DocumentSnapshot existingDoc = await FirebaseFirestore.instance
          .collection('jadwal')
          .doc(newId)
          .get();

      if (existingDoc.exists) {
        // Jika ID sudah ada, coba lagi dengan increment
        log('ID $newId already exists, trying next number...');
        nextNumber++;
        formattedNumber = nextNumber.toString().padLeft(4, '0');
        newId = '$prefix$formattedNumber';
      }

      log('Generated schedule ID: $newId');
      return newId;
    } catch (e) {
      log('Error generating schedule ID: $e');

      // Fallback: gunakan timestamp sebagai 4 digit terakhir
      DateTime now = DateTime.now();
      String timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      String fallbackId = 'idjd04$timeString';

      log('Using fallback ID: $fallbackId');
      return fallbackId;
    }
  }

  // Helper function to convert TimeOfDay to Timestamp
  Timestamp _timeOfDayToTimestamp(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return Timestamp.fromDate(dateTime);
  }

  // Helper function to format TimeOfDay
  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showAddEditScheduleDialog({ScheduleModel? schedule}) async {
    String selectedHari = schedule?.hari ?? 'senin';
    String selectedKelas = schedule?.kelas ?? '1a';
    TimeOfDay selectedJamMulai =
        schedule?.jamMulai ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay selectedJamSelesai =
        schedule?.jamSelesai ?? const TimeOfDay(hour: 9, minute: 0);
    final TextEditingController mataPelajaranController =
        TextEditingController(text: schedule?.mataPelajaran ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(schedule == null ? 'Tambah Jadwal' : 'Edit Jadwal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mata Pelajaran
                    TextFormField(
                      controller: mataPelajaranController,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Mata Pelajaran (Max 50 karakter)',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kelas dropdown
                    DropdownButtonFormField<String>(
                      value: selectedKelas,
                      decoration: const InputDecoration(
                        labelText: 'Kelas',
                        border: OutlineInputBorder(),
                      ),
                      items: classOptions
                          .map((kelas) => DropdownMenuItem<String>(
                                value: kelas,
                                child: Text(kelas.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedKelas = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Hari dropdown
                    DropdownButtonFormField<String>(
                      value: selectedHari,
                      decoration: const InputDecoration(
                        labelText: 'Hari',
                        border: OutlineInputBorder(),
                      ),
                      items: dayOptions
                          .map((hari) => DropdownMenuItem<String>(
                                value: hari,
                                child: Text(dayLabels[hari]!),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedHari = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Jam Mulai Time Picker
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jam Mulai',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: selectedJamMulai,
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedJamMulai = picked;
                                });
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.access_time,
                                    color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimeOfDay(selectedJamMulai),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Jam Selesai Time Picker
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jam Selesai',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: selectedJamSelesai,
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedJamSelesai = picked;
                                });
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.access_time,
                                    color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimeOfDay(selectedJamSelesai),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
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
                if (schedule != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop({
                      'action': 'delete',
                      'schedule': schedule,
                    }),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Hapus'),
                  ),
                ElevatedButton(
                  onPressed: () {
                    if (mataPelajaranController.text.trim().isEmpty) {
                      _showToast('Mata pelajaran tidak boleh kosong');
                      return;
                    }

                    if (mataPelajaranController.text.trim().length > 50) {
                      _showToast('Mata pelajaran maksimal 50 karakter');
                      return;
                    }

                    // Validate jam selesai > jam mulai
                    final jamMulaiMinutes =
                        selectedJamMulai.hour * 60 + selectedJamMulai.minute;
                    final jamSelesaiMinutes = selectedJamSelesai.hour * 60 +
                        selectedJamSelesai.minute;

                    if (jamSelesaiMinutes <= jamMulaiMinutes) {
                      _showToast(
                          'Jam selesai harus lebih besar dari jam mulai');
                      return;
                    }

                    Navigator.of(context).pop({
                      'action': schedule == null ? 'create' : 'update',
                      'mata_pelajaran': mataPelajaranController.text.trim(),
                      'kelas': selectedKelas,
                      'hari': selectedHari,
                      'jam_mulai': selectedJamMulai,
                      'jam_selesai': selectedJamSelesai,
                      'schedule': schedule,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: Text(schedule == null ? 'Simpan' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _handleScheduleAction(result);
    }

    // Dispose controllers
    mataPelajaranController.dispose();
  }

  Future<void> _handleScheduleAction(Map<String, dynamic> data) async {
    try {
      setState(() {
        isLoading = true;
      });

      final action = data['action'];

      if (action == 'delete') {
        await _deleteSchedule(data['schedule']);
      } else if (action == 'create') {
        await _createSchedule(data);
      } else if (action == 'update') {
        await _updateSchedule(data['schedule'], data);
      }

      await _loadScheduleData();

      if (mounted) {
        _showToast(_getSuccessMessage(action));
      }
    } catch (e) {
      log('Error handling schedule action: $e');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        _showToast('Gagal ${_getActionText(data['action'])}: ${e.toString()}');
      }
    }
  }

  Future<void> _createSchedule(Map<String, dynamic> data) async {
    String scheduleId = await _generateScheduleId();

    await FirebaseFirestore.instance.collection('jadwal').doc(scheduleId).set({
      'id_jadwal': scheduleId,
      'mata_pelajaran': data['mata_pelajaran'],
      'kelas': data['kelas'],
      'hari': data['hari'],
      'jam_mulai': _timeOfDayToTimestamp(data['jam_mulai']),
      'jam_selesai': _timeOfDayToTimestamp(data['jam_selesai']),
    });

    log('Created schedule: $scheduleId');
  }

  Future<void> _updateSchedule(
      ScheduleModel schedule, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('jadwal')
        .doc(schedule.id)
        .update({
      'mata_pelajaran': data['mata_pelajaran'],
      'kelas': data['kelas'],
      'hari': data['hari'],
      'jam_mulai': _timeOfDayToTimestamp(data['jam_mulai']),
      'jam_selesai': _timeOfDayToTimestamp(data['jam_selesai']),
    });

    log('Updated schedule: ${schedule.id}');
  }

  Future<void> _deleteSchedule(ScheduleModel schedule) async {
    await FirebaseFirestore.instance
        .collection('jadwal')
        .doc(schedule.id)
        .delete();

    log('Deleted schedule: ${schedule.id}');
  }

  String _getSuccessMessage(String action) {
    switch (action) {
      case 'create':
        return 'Jadwal berhasil ditambahkan';
      case 'update':
        return 'Jadwal berhasil diupdate';
      case 'delete':
        return 'Jadwal berhasil dihapus';
      default:
        return 'Aksi berhasil';
    }
  }

  String _getActionText(String action) {
    switch (action) {
      case 'create':
        return 'menambah jadwal';
      case 'update':
        return 'mengupdate jadwal';
      case 'delete':
        return 'menghapus jadwal';
      default:
        return 'memproses';
    }
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Debug Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total docs in scheduleList: ${scheduleList.length}'),
                Text(
                    'Total docs in filteredList: ${filteredScheduleList.length}'),
                Text('Is Loading: $isLoading'),
                Text('Error Message: ${errorMessage ?? "None"}'),
                Text('Search Query: "$searchQuery"'),
                Text('Day Filter: ${selectedDayFilter ?? "None"}'),
                Text('Class Filter: ${selectedClassFilter ?? "None"}'),
                const SizedBox(height: 16),
                const Text('Schedule Data:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...scheduleList.take(3).map((schedule) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        '${schedule.id}: ${schedule.hari} - ${schedule.mataPelajaran} (${schedule.kelas})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                if (scheduleList.length > 3)
                  Text('... dan ${scheduleList.length - 3} lainnya'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadScheduleData();
              },
              child: const Text('Reload Data'),
            ),
          ],
        );
      },
    );
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
      backgroundColor: const Color(0xFF4CAF50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Kelola Jadwal Pelajaran',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Debug button (hapus setelah testing selesai)
          IconButton(
            onPressed: () => _showDebugInfo(),
            icon: const Icon(Icons.bug_report, color: Colors.white),
            tooltip: 'Debug Info',
          ),
          IconButton(
            onPressed: () => _showAddEditScheduleDialog(),
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Tambah Jadwal',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters
          Container(
            margin: const EdgeInsets.all(16),
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
                    hintText: 'Cari mata pelajaran atau kelas...',
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
                    // Day filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedDayFilter,
                        decoration: InputDecoration(
                          labelText: 'Hari',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Semua Hari'),
                          ),
                          ...dayOptions.map((day) => DropdownMenuItem<String>(
                                value: day,
                                child: Text(dayLabels[day]!),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedDayFilter = value;
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
                            child: Text('Semua Kelas'),
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
                      onPressed: _loadScheduleData, child: const Text('Retry')),
                ],
              ),
            ),

          // Summary Card
          if (!isLoading && filteredScheduleList.isNotEmpty)
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
                  _buildSummaryItem('Total Jadwal',
                      filteredScheduleList.length.toString(), Colors.blue),
                  _buildSummaryItem(
                      'Hari Ini',
                      filteredScheduleList
                          .where((s) =>
                              s.hari.toLowerCase() ==
                              _getCurrentDay().toLowerCase())
                          .length
                          .toString(),
                      Colors.green),
                ],
              ),
            ),

          // Schedule list
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
                          Text('Memuat data jadwal...'),
                        ],
                      ),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                'Error memuat data',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadScheduleData,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : scheduleList.isEmpty
                          ? _buildEmptyState()
                          : filteredScheduleList.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.search_off,
                                          size: 64, color: Colors.grey),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Tidak ada jadwal sesuai filter',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Total jadwal: ${scheduleList.length}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            selectedDayFilter = null;
                                            selectedClassFilter = null;
                                            _searchController.clear();
                                            searchQuery = '';
                                            _applyFilters();
                                          });
                                        },
                                        child: const Text('Reset Filter'),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadScheduleData,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: filteredScheduleList.length,
                                    itemBuilder: (context, index) {
                                      final schedule =
                                          filteredScheduleList[index];
                                      return _buildScheduleCard(schedule);
                                    },
                                  ),
                                ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditScheduleDialog(),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Tambah Jadwal',
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
          const Icon(Icons.schedule, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            scheduleList.isEmpty
                ? 'Belum ada jadwal pelajaran'
                : 'Tidak ada jadwal yang sesuai filter',
            style: const TextStyle(
                fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            scheduleList.isEmpty
                ? 'Tambah jadwal pelajaran terlebih dahulu'
                : 'Total jadwal tersimpan: ${scheduleList.length}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (scheduleList.isEmpty)
            ElevatedButton.icon(
              onPressed: () => _showAddEditScheduleDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Jadwal'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white),
            )
          else
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedDayFilter = null;
                      selectedClassFilter = null;
                      _searchController.clear();
                      searchQuery = '';
                      _applyFilters();
                    });
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Reset Filter'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showDebugInfo,
                  icon: const Icon(Icons.info),
                  label: const Text('Debug Info'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAddEditScheduleDialog(schedule: schedule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Day and time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${dayLabels[schedule.hari]} - ${schedule.kelas.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatTimeOfDay(schedule.jamMulai)} - ${_formatTimeOfDay(schedule.jamSelesai)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Edit button
                  IconButton(
                    onPressed: () =>
                        _showAddEditScheduleDialog(schedule: schedule),
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.grey[600],
                    tooltip: 'Edit Jadwal',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Subject
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.mataPelajaran,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.class_,
                            size: 16, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 4),
                        Text(
                          'Kelas ${schedule.kelas.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentDay() {
    final days = [
      'senin',
      'selasa',
      'rabu',
      'kamis',
      'jumat',
      'sabtu',
      'minggu'
    ];
    return days[DateTime.now().weekday - 1];
  }
}

// Schedule Model
class ScheduleModel {
  final String id;
  final String hari;
  final TimeOfDay jamMulai;
  final TimeOfDay jamSelesai;
  final String mataPelajaran;
  final String kelas;

  ScheduleModel({
    required this.id,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    required this.mataPelajaran,
    required this.kelas,
  });
}
