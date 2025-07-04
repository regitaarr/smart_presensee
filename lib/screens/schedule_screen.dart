import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class ScheduleScreen extends StatefulWidget {
  final String? userNip;

  const ScheduleScreen({super.key, this.userNip});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin {
  List<ScheduleModel> scheduleList = [];
  List<ScheduleModel> filteredScheduleList = [];
  bool isLoading = true;
  String? errorMessage;
  String? selectedDayFilter;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _initializeAnimations();
    _loadScheduleData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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

  bool _isCurrentSchedule(ScheduleModel schedule) {
    final now = TimeOfDay.now();
    final startMinutes = schedule.jamMulai.hour * 60 + schedule.jamMulai.minute;
    final endMinutes =
        schedule.jamSelesai.hour * 60 + schedule.jamSelesai.minute;
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8), // Light pastel green
              Color(0xFFFFF3E0), // Light pastel orange
              Color(0xFFE8F5E8), // Light pastel green
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern App Bar
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFF2E7D32), size: 24),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jadwal Mata Pelajaran',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Day filter
              SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Filter Jadwal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedDayFilter,
                        decoration: InputDecoration(
                          labelText: 'Pilih Hari',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFFF8A65), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          prefixIcon: const Icon(Icons.calendar_today,
                              color: Color(0xFF36C340)),
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
                    ],
                  ),
                ),
              ),

              // Schedule list
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: isLoading
                      ? _buildLoadingState()
                      : errorMessage != null
                          ? _buildErrorState()
                          : scheduleList.isEmpty
                              ? _buildEmptyState()
                              : filteredScheduleList.isEmpty
                                  ? _buildNoFilteredDataState()
                                  : _buildScheduleList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A65)),
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Memuat jadwal...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFFE53E3E),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadScheduleData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A65),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.schedule,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Jadwal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hubungi admin untuk menambahkan jadwal mata pelajaran',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadScheduleData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A65),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilteredDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search_off,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tidak Ada Jadwal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada jadwal untuk hari yang dipilih\nTotal jadwal: ${scheduleList.length}',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  selectedDayFilter = null;
                  _applyFilters();
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Lihat Semua Hari'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A65),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return RefreshIndicator(
      onRefresh: _loadScheduleData,
      color: const Color(0xFFFF8A65),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _buildScheduleByDay().length,
        itemBuilder: (context, index) {
          final dayGroup = _buildScheduleByDay()[index];
          return _buildDayScheduleCard(dayGroup);
        },
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

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Hijau pastel untuk semua card
        borderRadius: BorderRadius.circular(16),
        border: isToday
            ? Border.all(
                color: const Color(0xFFFFC107),
                width: 2) // Orange untuk hari ini
            : Border.all(
                color: const Color(0xFF81C784), width: 1), // Hijau untuk lain
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFFFFC107)
                        : const Color(0xFF36C340),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.today, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        dayLabels[day]!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFFFFC107)
                        : const Color(0xFF36C340),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${schedules.length} jadwal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Schedule items
            ...schedules
                .map((schedule) => _buildScheduleItem(schedule, isToday)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(ScheduleModel schedule, bool isToday) {
    final isCurrent = _isCurrentSchedule(schedule);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Hijau pastel untuk semua card
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? Colors.white.withOpacity(0.2)
              : const Color(0xFFFF8A65).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF36C340),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _formatTimeOfDay(schedule.jamMulai),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  width: 20,
                  height: 1,
                  color: Colors.white.withOpacity(0.5),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
                Text(
                  _formatTimeOfDay(schedule.jamSelesai),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Subject info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.mataPelajaran,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87, // Hitam
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.class_,
                      size: 18,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kelas ${schedule.kelas.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF36C340),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _calculateDuration(schedule.jamMulai, schedule.jamSelesai),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
