import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/screens/login_screen.dart';
import 'package:smart_presensee/admin/admin_schedule.dart';
import 'package:smart_presensee/admin/admin_student_list.dart';
import 'package:smart_presensee/admin/admin_attendance_list.dart';
import 'package:smart_presensee/admin/admin_face_list.dart';
import 'package:smart_presensee/admin/admin_user_list.dart';
import 'package:smart_presensee/admin/admin_profile_screen.dart';
import 'package:smart_presensee/admin/admin_report_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer';

class AdminDashboard extends StatefulWidget {
  final String adminName;
  final String adminEmail;

  const AdminDashboard({
    super.key,
    required this.adminName,
    required this.adminEmail,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _showProfile = false;

  // Statistics variables
  int totalStudents = 0;
  int totalFaceRegistered = 0;
  int todayPresent = 0;
  int todayAbsent = 0;
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        isLoadingStats = true;
      });

      // Get total students
      QuerySnapshot studentsSnapshot =
          await FirebaseFirestore.instance.collection('siswa').get();

      // Get total face registered
      QuerySnapshot facesSnapshot =
          await FirebaseFirestore.instance.collection('wajah_siswa').get();

      // Get today's attendance
      DateTime today = DateTime.now();
      DateTime startOfDay =
          DateTime(today.year, today.month, today.day, 0, 0, 0);
      DateTime endOfDay =
          DateTime(today.year, today.month, today.day, 23, 59, 59);

      QuerySnapshot todayAttendanceSnapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      int presentCount = 0;
      for (var doc in todayAttendanceSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'hadir') {
          presentCount++;
        }
      }

      setState(() {
        totalStudents = studentsSnapshot.docs.length;
        totalFaceRegistered = facesSnapshot.docs.length;
        todayPresent = presentCount;
        todayAbsent = totalStudents - presentCount;
        isLoadingStats = false;
      });

      log('Statistics loaded: Students=$totalStudents, Faces=$totalFaceRegistered, Present=$todayPresent');
    } catch (e) {
      log('Error loading statistics: $e');
      setState(() {
        isLoadingStats = false;
      });
    }
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSidebarCollapsed ? 80 : 250,
      color: const Color(0xFF4CAF50),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Image.asset(
              'assets/images/logo3.png',
              height: _isSidebarCollapsed ? 60 : 60,
              width: _isSidebarCollapsed ? 60 : 60,
            ),
          ),
          const SizedBox(height: 16),
          // Logo and Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: _isSidebarCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!_isSidebarCollapsed) ...[
                  const Flexible(
                    child: Text(
                      'Smart Presensee',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(
                    _isSidebarCollapsed ? Icons.menu_open : Icons.menu,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Menu Items
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem(
                icon: Icons.dashboard,
                title: 'Dashboard',
                index: 0,
              ),
              _buildMenuItem(
                icon: Icons.people,
                title: 'Data Siswa',
                index: 1,
              ),
              _buildMenuItem(
                icon: Icons.face,
                title: 'Data Wajah',
                index: 2,
              ),
              _buildMenuItem(
                icon: Icons.calendar_today,
                title: 'Kelola Jadwal',
                index: 3,
              ),
              _buildMenuItem(
                icon: Icons.assignment,
                title: 'Data Presensi',
                index: 4,
              ),
              _buildMenuItem(
                icon: Icons.person,
                title: 'Data Pengguna',
                index: 5,
              ),
              _buildMenuItem(
                icon: Icons.description,
                title: 'Laporan',
                index: 6,
              ),
            ],
          ),
          const Spacer(),
          // Profile Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _showProfile = true;
                });
              },
              child: Row(
                mainAxisAlignment: _isSidebarCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  if (!_isSidebarCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.adminName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Administrator',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _showProfile = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: _isSidebarCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
              size: 20,
            ),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _buildContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadStatistics,
        backgroundColor: const Color(0xFF4CAF50),
        tooltip: 'Refresh Data',
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    if (_showProfile) {
      return AdminProfileScreen(
        adminEmail: widget.adminEmail,
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const AdminStudentList();
      case 2:
        return const AdminFaceList();
      case 3:
        return const AdminScheduleScreen();
      case 4:
        return const AdminAttendanceList();
      case 5:
        return const AdminUserList();
      case 6:
        return const AdminReportScreen();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFF4CAF50),
                    size: 36,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat datang, ${widget.adminName}!',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Administrator Smart Presensee',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Statistics Cards
          const Text(
            'Statistik Hari Ini',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          if (isLoadingStats)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard(
                  'Total Siswa',
                  totalStudents.toString(),
                  Icons.people,
                  Colors.blueAccent,
                ),
                _buildStatCard(
                  'Wajah Terdaftar',
                  totalFaceRegistered.toString(),
                  Icons.face,
                  Colors.deepPurpleAccent,
                ),
                _buildStatCard(
                  'Hadir Hari Ini',
                  todayPresent.toString(),
                  Icons.check_circle,
                  Colors.greenAccent[700]!,
                ),
                _buildStatCard(
                  'Belum Hadir',
                  todayAbsent.toString(),
                  Icons.cancel,
                  Colors.redAccent,
                ),
              ],
            ),

          const SizedBox(height: 40),

          // Quick Actions
          const Text(
            'Aksi Cepat',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.3,
            children: [
              _buildActionCard(
                'Data Siswa',
                'Lihat data siswa',
                Icons.people_outline,
                Colors.blueAccent,
                () => setState(() => _selectedIndex = 1),
              ),
              _buildActionCard(
                'Data Wajah',
                'Lihat data wajah terdaftar',
                Icons.face_retouching_natural,
                Colors.deepPurpleAccent,
                () => setState(() => _selectedIndex = 2),
              ),
              _buildActionCard(
                'Data Presensi',
                'Lihat & kelola presensi',
                Icons.assignment,
                Colors.greenAccent[700]!,
                () => setState(() => _selectedIndex = 4),
              ),
              _buildActionCard(
                'Kelola Jadwal',
                'Atur jadwal mata pelajaran',
                Icons.schedule,
                Colors.orangeAccent,
                () => setState(() => _selectedIndex = 3),
              ),
              _buildActionCard(
                'Data Pengguna',
                'Lihat semua pengguna',
                Icons.supervised_user_circle,
                Colors.blueGrey,
                () => setState(() => _selectedIndex = 5),
              ),
              _buildActionCard(
                'Laporan',
                'Unduh laporan kehadiran',
                Icons.description_outlined,
                Colors.teal,
                () => setState(() => _selectedIndex = 6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text(
              'Apakah Anda yakin ingin keluar dari admin dashboard?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
                Fluttertoast.showToast(
                  msg: 'Logout berhasil',
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
