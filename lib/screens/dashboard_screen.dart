import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:smart_presensee/screens/authenticate_screen.dart';
import 'package:smart_presensee/screens/profile_screen.dart';

class DashboardPage extends StatefulWidget {
  final String userName;

  const DashboardPage({super.key, required this.userName});

  @override
  State<DashboardPage> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107), // Yellow background
      body: SafeArea(
        child: Column(
          children: [
            // Header dengan greeting dan user icon di kiri atas
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Profile icon di sebelah kiri
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(userName: widget.userName),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF36C340),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Greeting text
                  Text(
                    'Hi, ${widget.userName}!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Card utama dengan konten
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Ganti icon dan teks dengan logo dan slogan
                    const SizedBox(height: 40),
                    Image.asset(
                      'assets/images/logo1.png',
                      width: 150,
                      height: 150,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'SMART PRESENSEE',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF36C340),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Absen Digital. Sekolah Makin Pintar!',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFFFFC107),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Informasi jadwal
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF36C340),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'Selasa, 11 Maret 2025',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '09:00-10:00',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Akidah Akhlak',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Tombol aksi presensi
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AuthenticateScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Mulai Presensi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
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

            // Navigate berdasarkan index
            switch (index) {
              case 0:
                // Already on dashboard
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuthenticateScreen(),
                  ),
                );
                break;
              case 2:
                // Riwayat/History - bisa ditambahkan nanti
                break;
              case 3:
                // Jadwal - bisa ditambahkan nanti
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF36C340),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: [
            // Hapus 'const' di sini
            const BottomNavigationBarItem(
              // Biarkan 'const' untuk item yang iconnya konstanta
              icon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              // Hapus 'const' di sini
              icon: Icon(MdiIcons.faceRecognition),
              label: 'Presensi',
            ),
            const BottomNavigationBarItem(
              // Biarkan 'const' untuk item yang iconnya konstanta
              icon: Icon(Icons.check_circle),
              label: 'Kehadiran',
            ),
            const BottomNavigationBarItem(
              // Biarkan 'const' untuk item yang iconnya konstanta
              icon: Icon(Icons.calendar_today),
              label: 'Jadwal',
            ),
          ],
        ),
      ),
    );
  }
}
