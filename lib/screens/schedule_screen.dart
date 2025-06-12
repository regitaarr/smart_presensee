import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class ScheduleScreen extends StatefulWidget {
  final String? userNip;

  const ScheduleScreen({super.key, this.userNip});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<ScheduleModel> scheduleList = [];
  List<ScheduleModel> filteredScheduleList = [];
  bool isLoading = true;
  String? errorMessage;
  String? selectedDayFilter;

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

  @override
  void initState() {
    super.initState();
    _loadScheduleData();
  }

  void _applyFilters() {
    filteredScheduleList = scheduleList.where((schedule) {
      // Day filter
      bool matchesDay = selectedDayFilter == null ||
          schedule.hari.toLowerCase() == selectedDayFilter!.toLowerCase();

      return matchesDay;
    }).toList();

    // Sort by day and time
    filteredScheduleList.sort((a, b) {
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

      log('=== LOADING SCHEDULE DATA ===');

      Query scheduleQuery = FirebaseFirestore.instance.collection('jadwal');

      if (widget.userNip != null) {
        scheduleQuery = scheduleQuery.where('nip', isEqualTo: widget.userNip);
        log('Filtering schedule by NIP: ${widget.userNip}');
      }

      QuerySnapshot scheduleSnapshot = await scheduleQuery.get();

      log('Found ${scheduleSnapshot.docs.length} schedule records');

      List<ScheduleModel> tempList = [];

      for (var doc in scheduleSnapshot.docs) {
        try {
          Map<String, dynamic> scheduleData =
              doc.data() as Map<String, dynamic>;
          String scheduleId = doc.id;

          log('Processing document: $scheduleId');

          // Convert Timestamp to TimeOfDay
          TimeOfDay jamMulai = const TimeOfDay(hour: 8, minute: 0); // default
          TimeOfDay jamSelesai = const TimeOfDay(hour: 9, minute: 0); // default

          if (scheduleData['jam_mulai'] != null) {
            try {
              DateTime jamMulaiDate =
                  (scheduleData['jam_mulai'] as Timestamp).toDate();
              jamMulai = TimeOfDay(
                  hour: jamMulaiDate.hour, minute: jamMulaiDate.minute);
            } catch (e) {
              log('Error parsing jam_mulai: $e');
            }
          }

          if (scheduleData['jam_selesai'] != null) {
            try {
              DateTime jamSelesaiDate =
                  (scheduleData['jam_selesai'] as Timestamp).toDate();
              jamSelesai = TimeOfDay(
                  hour: jamSelesaiDate.hour, minute: jamSelesaiDate.minute);
            } catch (e) {
              log('Error parsing jam_selesai: $e');
            }
          }

          String hari = scheduleData['hari'] ?? '';
          String mataPelajaran = scheduleData['mata_pelajaran'] ?? '';
          String kelas = scheduleData['kelas'] ?? '';

          tempList.add(ScheduleModel(
            id: scheduleId,
            hari: hari,
            jamMulai: jamMulai,
            jamSelesai: jamSelesai,
            mataPelajaran: mataPelajaran,
            kelas: kelas,
          ));

          log('Successfully processed schedule: $scheduleId');
        } catch (e) {
          log('Error processing schedule ${doc.id}: $e');
          continue;
        }
      }

      setState(() {
        scheduleList = tempList;
        filteredScheduleList = tempList;
        isLoading = false;
      });

      // Apply initial filter
      _applyFilters();

      log('Successfully loaded ${tempList.length} schedules');
    } catch (e) {
      log('ERROR loading schedule data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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

  List<ScheduleModel> _getTodaySchedule() {
    String today = _getCurrentDay();
    return filteredScheduleList
        .where((schedule) => schedule.hari.toLowerCase() == today)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final todaySchedule = _getTodaySchedule();

    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC107),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        title: const Text(
          'Jadwal Mata Pelajaran',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            onPressed: _loadScheduleData,
            icon: const Icon(Icons.refresh, color: Colors.black87),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Today's schedule card at top
            if (!isLoading && todaySchedule.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF36C340),
                  borderRadius: BorderRadius.circular(16),
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
                    Row(
                      children: [
                        const Icon(Icons.today, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Jadwal Mata Pelajaran Hari Ini (${dayLabels[_getCurrentDay()]})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...todaySchedule.take(3).map((schedule) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_formatTimeOfDay(schedule.jamMulai)}-${_formatTimeOfDay(schedule.jamSelesai)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${schedule.mataPelajaran} (${schedule.kelas.toUpperCase()})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (todaySchedule.length > 3)
                      Text(
                        '... dan ${todaySchedule.length - 3} jadwal mata pelajaran lainnya',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),

            // Day filter
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
              child: DropdownButtonFormField<String>(
                value: selectedDayFilter,
                decoration: InputDecoration(
                  labelText: 'Filter Hari',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF36C340)),
                            ),
                            SizedBox(height: 16),
                            Text('Memuat jadwal...'),
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
                                const Text(
                                  'Error memuat data',
                                  style: TextStyle(
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.search_off,
                                            size: 64, color: Colors.grey),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Tidak ada jadwal untuk hari ini',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Total jadwal mata peelajaran: ${scheduleList.length}',
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
                                              _applyFilters();
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF36C340),
                                          ),
                                          child: const Text('Lihat Semua Hari'),
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadScheduleData,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _buildScheduleByDay().length,
                                      itemBuilder: (context, index) {
                                        final dayGroup =
                                            _buildScheduleByDay()[index];
                                        return _buildDayScheduleCard(dayGroup);
                                      },
                                    ),
                                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Belum ada jadwal mata pelajaran',
            style: TextStyle(
                fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hubungi admin untuk menambahkan jadwal',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadScheduleData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF36C340),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildScheduleByDay() {
    Map<String, List<ScheduleModel>> scheduleByDay = {};

    // Group schedules by day
    for (var schedule in filteredScheduleList) {
      String day = schedule.hari.toLowerCase();
      if (scheduleByDay[day] == null) {
        scheduleByDay[day] = [];
      }
      scheduleByDay[day]!.add(schedule);
    }

    // Sort each day's schedules by time
    scheduleByDay.forEach((day, schedules) {
      schedules.sort((a, b) {
        int aMinutes = a.jamMulai.hour * 60 + a.jamMulai.minute;
        int bMinutes = b.jamMulai.hour * 60 + b.jamMulai.minute;
        return aMinutes.compareTo(bMinutes);
      });
    });

    // Convert to list and sort by day order
    List<Map<String, dynamic>> result = [];
    for (String day in dayOptions) {
      if (scheduleByDay[day] != null && scheduleByDay[day]!.isNotEmpty) {
        result.add({
          'day': day,
          'schedules': scheduleByDay[day]!,
        });
      }
    }

    return result;
  }

  Widget _buildDayScheduleCard(Map<String, dynamic> dayGroup) {
    String day = dayGroup['day'];
    List<ScheduleModel> schedules = dayGroup['schedules'];
    bool isToday = day == _getCurrentDay();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isToday ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? const BorderSide(color: Color(0xFF36C340), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFF36C340)
                        : const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isToday)
                        const Icon(Icons.today, size: 16, color: Colors.white),
                      if (isToday) const SizedBox(width: 4),
                      Text(
                        dayLabels[day]!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isToday ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${schedules.length} jadwal mata pelajaran',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Schedule items
            ...schedules.map((schedule) => _buildScheduleItem(schedule)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(ScheduleModel schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF36C340).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  _formatTimeOfDay(schedule.jamMulai),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF36C340),
                  ),
                ),
                const Text(
                  '―',
                  style: TextStyle(
                    fontSize: 8,
                    color: Color(0xFF36C340),
                  ),
                ),
                Text(
                  _formatTimeOfDay(schedule.jamSelesai),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF36C340),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Subject info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.mataPelajaran,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.class_,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kelas ${schedule.kelas.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _calculateDuration(schedule.jamMulai, schedule.jamSelesai),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDuration(TimeOfDay start, TimeOfDay end) {
    int startMinutes = start.hour * 60 + start.minute;
    int endMinutes = end.hour * 60 + end.minute;
    int duration = endMinutes - startMinutes;

    if (duration < 60) {
      return '${duration}m';
    } else {
      int hours = duration ~/ 60;
      int minutes = duration % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
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
