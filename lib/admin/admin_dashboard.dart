import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/screens/login_screen.dart';
import 'package:smart_presensee/screens/student_screen.dart';
import 'package:smart_presensee/screens/attendance_screen.dart';
import 'package:smart_presensee/screens/register_screen.dart';
import 'package:smart_presensee/admin/admin_schedule.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        title: const Text(
          'Beranda Admin',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(),
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat datang, ${widget.adminName}!',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Administrator Smart Presensee',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statistics Cards
                      const Text(
                        'Statistik Hari Ini',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (isLoadingStats)
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF4CAF50)),
                          ),
                        )
                      else
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.5,
                          children: [
                            _buildStatCard(
                              'Total Siswa',
                              totalStudents.toString(),
                              Icons.people,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              'Wajah Terdaftar',
                              totalFaceRegistered.toString(),
                              Icons.face,
                              Colors.purple,
                            ),
                            _buildStatCard(
                              'Hadir Hari Ini',
                              todayPresent.toString(),
                              Icons.check_circle,
                              Colors.green,
                            ),
                            _buildStatCard(
                              'Belum Hadir',
                              todayAbsent.toString(),
                              Icons.cancel,
                              Colors.red,
                            ),
                          ],
                        ),

                      const SizedBox(height: 30),

                      // Quick Actions
                      const Text(
                        'Aksi Cepat',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                        children: [
                          _buildActionCard(
                            'Kelola Siswa',
                            'Tambah & kelola data siswa',
                            Icons.people_outline,
                            const Color(0xFF2196F3),
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StudentScreen(),
                              ),
                            ).then((_) => _loadStatistics()),
                          ),
                          _buildActionCard(
                            'Daftar Wajah',
                            'Registrasi wajah siswa',
                            Icons.face_retouching_natural,
                            const Color(0xFF9C27B0),
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            ).then((_) => _loadStatistics()),
                          ),
                          _buildActionCard(
                            'Data Presensi',
                            'Lihat & kelola presensi',
                            Icons.assignment,
                            const Color(0xFF4CAF50),
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AttendanceScreen(),
                              ),
                            ),
                          ),
                          _buildActionCard(
                            'Kelola Jadwal',
                            'Atur jadwal pelajaran',
                            Icons.schedule,
                            const Color(0xFFFF5722),
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AdminScheduleScreen(),
                              ),
                            ),
                          ),
                          _buildActionCard(
                            'Laporan',
                            'Generate laporan presensi',
                            Icons.assessment,
                            const Color(0xFFFF9800),
                            () => _showComingSoonDialog('Laporan'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Recent Activity
                      const Text(
                        'Aktivitas Terbaru',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            _buildActivityItem(
                              Icons.person_add,
                              'Siswa baru terdaftar',
                              'Total $totalStudents siswa aktif',
                              Colors.blue,
                            ),
                            const Divider(),
                            _buildActivityItem(
                              Icons.face,
                              'Wajah terdaftar',
                              '$totalFaceRegistered dari $totalStudents siswa',
                              Colors.purple,
                            ),
                            const Divider(),
                            _buildActivityItem(
                              Icons.check_circle,
                              'Presensi hari ini',
                              '$todayPresent siswa hadir',
                              Colors.green,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            _handleBottomNavigation(index);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF4CAF50),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Siswa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Presensi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule),
              label: 'Jadwal',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadStatistics,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Refresh Data',
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(
      IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
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
    );
  }

  void _handleBottomNavigation(int index) {
    switch (index) {
      case 0:
        // Already on dashboard
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StudentScreen(),
          ),
        ).then((_) => _loadStatistics());
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AttendanceScreen(),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminScheduleScreen(),
          ),
        );
        break;
    }
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$feature - Coming Soon'),
          content:
              Text('Fitur $feature akan segera hadir dalam update berikutnya.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFF4CAF50)),
              ),
            ),
          ],
        );
      },
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
