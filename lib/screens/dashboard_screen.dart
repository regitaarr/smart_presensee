import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:smart_presensee/screens/attendance_screen.dart';
import 'package:smart_presensee/screens/authenticate_screen.dart';
import 'package:smart_presensee/screens/profile_screen.dart';
import 'package:smart_presensee/screens/schedule_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class DashboardPage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String idPengguna;
  final String? userNip;

  const DashboardPage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.idPengguna,
    this.userNip,
  });

  @override
  State<DashboardPage> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  List<ScheduleModel> todaySchedule = [];
  bool isLoadingSchedule = true;
  ScheduleModel? currentSchedule;
  ScheduleModel? nextSchedule;

  // Attendance statistics
  Map<String, int> attendanceStats = {
    'hadir': 0,
    'sakit': 0,
    'izin': 0,
    'alpha': 0,
    'total': 0,
  };
  bool isLoadingAttendance = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadTodaySchedule();
    _loadAttendanceStatistics();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Helper function to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _loadAttendanceStatistics() async {
    try {
      setState(() {
        isLoadingAttendance = true;
      });

      DateTime today = DateTime.now();
      log('Loading attendance statistics for: ${today.toIso8601String().substring(0, 10)}');

      // Get all students first
      Query studentQuery = FirebaseFirestore.instance.collection('siswa');

      // Filter students by NIP if user is walikelas
      if (widget.userNip != null) {
        studentQuery = studentQuery.where('nip', isEqualTo: widget.userNip);
      }

      QuerySnapshot studentSnapshot = await studentQuery.get();

      log('Found ${studentSnapshot.docs.length} students');

      Map<String, int> stats = {
        'hadir': 0,
        'sakit': 0,
        'izin': 0,
        'alpha': 0,
        'total': studentSnapshot.docs.length,
      };

      // Get attendance records for today
      Query attendanceQuery = FirebaseFirestore.instance.collection('presensi');

      // Filter attendance records for today
      attendanceQuery = attendanceQuery
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(today.year, today.month, today.day)))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(
                  DateTime(today.year, today.month, today.day, 23, 59, 59)));

      QuerySnapshot attendanceSnapshot = await attendanceQuery.get();

      log('Found ${attendanceSnapshot.docs.length} attendance records for today');

      // Create a set of NISN for students filtered by NIP
      Set<String> relevantStudentNisns =
          studentSnapshot.docs.map((doc) => doc.id).toSet();

      // Process each attendance record
      for (var attendanceDoc in attendanceSnapshot.docs) {
        Map<String, dynamic> attendanceData =
            attendanceDoc.data() as Map<String, dynamic>;

        String nisn = attendanceData['nisn'] ?? '';
        String status = attendanceData['status'] ?? 'alpha';

        // Only count attendance for relevant students
        if (relevantStudentNisns.contains(nisn)) {
          stats[status] = (stats[status] ?? 0) + 1;
        }
      }

      // Calculate alpha (students without attendance records)
      int totalMarked = stats['hadir']! + stats['sakit']! + stats['izin']!;
      stats['alpha'] = stats['total']! - totalMarked;

      log('Attendance stats: $stats');

      setState(() {
        attendanceStats = stats;
        isLoadingAttendance = false;
      });
    } catch (e) {
      log('Error loading attendance statistics: $e');
      setState(() {
        isLoadingAttendance = false;
      });
    }
  }

  Future<void> _loadTodaySchedule() async {
    try {
      setState(() {
        isLoadingSchedule = true;
      });

      String currentDay = _getCurrentDay();
      log('Loading schedule for: $currentDay');

      Query scheduleQuery = FirebaseFirestore.instance
          .collection('jadwal')
          .where('hari', isEqualTo: currentDay);

      // Filter schedule by NIP if user is walikelas
      if (widget.userNip != null) {
        scheduleQuery = scheduleQuery.where('nip', isEqualTo: widget.userNip);
      }

      QuerySnapshot scheduleSnapshot = await scheduleQuery.get();

      log('Found ${scheduleSnapshot.docs.length} schedules for today');

      List<ScheduleModel> tempList = [];

      for (var doc in scheduleSnapshot.docs) {
        try {
          Map<String, dynamic> scheduleData =
              doc.data() as Map<String, dynamic>;

          // Convert Timestamp to TimeOfDay
          TimeOfDay jamMulai = const TimeOfDay(hour: 8, minute: 0);
          TimeOfDay jamSelesai = const TimeOfDay(hour: 9, minute: 0);

          if (scheduleData['jam_mulai'] != null) {
            DateTime jamMulaiDate =
                (scheduleData['jam_mulai'] as Timestamp).toDate();
            jamMulai =
                TimeOfDay(hour: jamMulaiDate.hour, minute: jamMulaiDate.minute);
          }

          if (scheduleData['jam_selesai'] != null) {
            DateTime jamSelesaiDate =
                (scheduleData['jam_selesai'] as Timestamp).toDate();
            jamSelesai = TimeOfDay(
                hour: jamSelesaiDate.hour, minute: jamSelesaiDate.minute);
          }

          tempList.add(ScheduleModel(
            id: doc.id,
            hari: scheduleData['hari'] ?? '',
            jamMulai: jamMulai,
            jamSelesai: jamSelesai,
            mataPelajaran: scheduleData['mata_pelajaran'] ?? '',
            kelas: scheduleData['kelas'] ?? '',
          ));
        } catch (e) {
          log('Error processing schedule ${doc.id}: $e');
        }
      }

      // Sort by time
      tempList.sort((a, b) {
        int aMinutes = a.jamMulai.hour * 60 + a.jamMulai.minute;
        int bMinutes = b.jamMulai.hour * 60 + b.jamMulai.minute;
        return aMinutes.compareTo(bMinutes);
      });

      setState(() {
        todaySchedule = tempList;
        isLoadingSchedule = false;
      });

      _findCurrentAndNextSchedule();

      log('Successfully loaded ${tempList.length} schedules for today');
    } catch (e) {
      log('Error loading today schedule: $e');
      setState(() {
        isLoadingSchedule = false;
      });
    }
  }

  void _findCurrentAndNextSchedule() {
    if (todaySchedule.isEmpty) return;

    TimeOfDay now = TimeOfDay.now();
    int nowMinutes = now.hour * 60 + now.minute;

    ScheduleModel? current;
    ScheduleModel? next;

    for (int i = 0; i < todaySchedule.length; i++) {
      ScheduleModel schedule = todaySchedule[i];
      int startMinutes = schedule.jamMulai.hour * 60 + schedule.jamMulai.minute;
      int endMinutes =
          schedule.jamSelesai.hour * 60 + schedule.jamSelesai.minute;

      // Check if current time is within this schedule
      if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) {
        current = schedule;
        // Next schedule is the following one (if exists)
        if (i + 1 < todaySchedule.length) {
          next = todaySchedule[i + 1];
        }
        break;
      }
      // Check if this is the next upcoming schedule
      else if (nowMinutes < startMinutes && next == null) {
        next = schedule;
      }
    }

    setState(() {
      currentSchedule = current;
      nextSchedule = next;
    });
  }

  Widget _buildAttendanceStatisticsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF81C784).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF81C784),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF81C784),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistik Kehadiran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    Text(
                      'Data hari ini',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadAttendanceStatistics,
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF81C784),
                  size: 20,
                ),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isLoadingAttendance)
            const Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Memuat data kehadiran...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Total Attendance Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81C784).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF81C784),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total presensi hari ini:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        '${attendanceStats['total']} siswa',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Statistics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Hadir',
                        attendanceStats['hadir']!,
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Sakit',
                        attendanceStats['sakit']!,
                        Icons.sick,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Izin',
                        attendanceStats['izin']!,
                        Icons.assignment,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Alpha',
                        attendanceStats['alpha']!,
                        Icons.cancel,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF81C784),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    if (isLoadingSchedule) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA5D6A7), // Light green
              Color(0xFF81C784), // Medium green
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF81C784).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Memuat jadwal...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (todaySchedule.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFCC80), // Light orange
              Color(0xFFFF8A65), // Medium orange
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8A65).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              color: Colors.white,
              size: 40,
            ),
            SizedBox(height: 12),
            Text(
              'Tidak Ada Jadwal Hari Ini',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Selamat menikmati hari libur!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Determine which schedule to show
    ScheduleModel scheduleToShow;
    String statusText;
    List<Color> gradientColors;
    IconData statusIcon;

    if (currentSchedule != null) {
      scheduleToShow = currentSchedule!;
      statusText = 'Sedang Berlangsung';
      gradientColors = [
        const Color(0xFF81C784),
        const Color(0xFF66BB6A)
      ]; // Green gradient
      statusIcon = Icons.play_circle_filled;
    } else if (nextSchedule != null) {
      scheduleToShow = nextSchedule!;
      statusText = 'Selanjutnya';
      gradientColors = [
        const Color(0xFF64B5F6),
        const Color(0xFF42A5F5)
      ]; // Blue gradient
      statusIcon = Icons.schedule;
    } else {
      // Show first schedule or indicate all done
      if (todaySchedule.isNotEmpty) {
        TimeOfDay now = TimeOfDay.now();
        int nowMinutes = now.hour * 60 + now.minute;
        int lastScheduleEnd = todaySchedule.last.jamSelesai.hour * 60 +
            todaySchedule.last.jamSelesai.minute;

        if (nowMinutes > lastScheduleEnd) {
          // All schedules for today are done
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF81C784), // Green
                  Color(0xFF4CAF50), // Darker green
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Semua Jadwal Selesai',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total ${todaySchedule.length} jadwal mata pelajaran hari ini',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        } else {
          // Show first schedule as upcoming
          scheduleToShow = todaySchedule.first;
          statusText = 'Akan Datang';
          gradientColors = [
            const Color(0xFFFFCC80),
            const Color(0xFFFF8A65)
          ]; // Orange gradient
          statusIcon = Icons.upcoming;
        }
      } else {
        scheduleToShow = todaySchedule.first;
        statusText = 'Hari Ini';
        gradientColors = [const Color(0xFF81C784), const Color(0xFF66BB6A)];
        statusIcon = Icons.today;
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // Main content - Centered both horizontally and vertically
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date
                  Text(
                    _formatDate(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Time
                  Text(
                    '${_formatTimeOfDay(scheduleToShow.jamMulai)} - ${_formatTimeOfDay(scheduleToShow.jamSelesai)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Subject
                  Text(
                    scheduleToShow.mataPelajaran,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Class
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Kelas ${scheduleToShow.kelas.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Show additional info if there are more schedules
                  if (todaySchedule.length > 1) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '+${todaySchedule.length - 1} jadwal mata pelajaran lainnya',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      // Profile icon
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                userEmail: widget.userEmail,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF81C784),
                                Color(0xFF66BB6A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF81C784).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Greeting text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selamat datang,',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Refresh button
                      GestureDetector(
                        onTap: () {
                          _loadTodaySchedule();
                          _loadAttendanceStatistics();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Color(0xFF81C784),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main content
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Logo and title
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/logo1.png',
                                width: 120,
                                height: 120,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'SMART PRESENSEE',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF36C340),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Absen Digital. Sekolah Makin Pintar!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFC107),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Schedule Card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildScheduleCard(),
                        ),

                        const SizedBox(height: 16),

                        // Attendance Statistics Card
                        _buildAttendanceStatisticsCard(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });

            // Navigate based on index
            switch (index) {
              case 0:
                // Already on dashboard - refresh data
                _loadTodaySchedule();
                _loadAttendanceStatistics();
                setState(() {
                  _selectedIndex = 0;
                });
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuthenticateScreen(),
                  ),
                ).then((_) {
                  setState(() {
                    _selectedIndex = 0;
                  });
                  // Refresh attendance data after potential new attendance
                  _loadAttendanceStatistics();
                });
                break;
              case 2:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceScreen(
                      userEmail: widget.userEmail,
                      userNip: widget.userNip,
                    ),
                  ),
                ).then((_) {
                  setState(() {
                    _selectedIndex = 0;
                  });
                });
                break;
              case 3:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScheduleScreen(
                      userNip: widget.userNip,
                    ),
                  ),
                ).then((_) {
                  _loadTodaySchedule();
                  setState(() {
                    _selectedIndex = 0;
                  });
                });
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF81C784),
          unselectedItemColor: const Color(0xFF9CA3AF),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(MdiIcons.faceRecognition),
              label: 'Presensi',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.check_circle),
              label: 'Kehadiran',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'Jadwal',
            ),
          ],
        ),
      ),
    );
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
