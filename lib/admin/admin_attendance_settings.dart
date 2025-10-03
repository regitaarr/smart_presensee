import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:smart_presensee/model/attendance_settings.dart';
import 'package:smart_presensee/services/attendance_time_helper.dart';

class AdminAttendanceSettingsScreen extends StatefulWidget {
  const AdminAttendanceSettingsScreen({super.key});

  @override
  State<AdminAttendanceSettingsScreen> createState() =>
      _AdminAttendanceSettingsScreenState();
}

class _AdminAttendanceSettingsScreenState
    extends State<AdminAttendanceSettingsScreen> {
  bool _isLoading = true;
  
  TimeOfDay? _jamMulai;
  TimeOfDay? _jamSelesai;
  bool _aktif = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      AttendanceSettings settings = await AttendanceTimeHelper.getSettings();
      
      setState(() {
        _aktif = settings.aktif ?? true;
        
        // Parse jam mulai
        if (settings.jamMulai != null) {
          List<String> parts = settings.jamMulai!.split(':');
          _jamMulai = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        
        // Parse jam selesai
        if (settings.jamSelesai != null) {
          List<String> parts = settings.jamSelesai!.split(':');
          _jamSelesai = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        
        _isLoading = false;
      });
    } catch (e) {
      log('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_jamMulai == null || _jamSelesai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih jam mulai dan jam selesai!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String jamMulaiStr = '${_jamMulai!.hour.toString().padLeft(2, '0')}:${_jamMulai!.minute.toString().padLeft(2, '0')}';
    String jamSelesaiStr = '${_jamSelesai!.hour.toString().padLeft(2, '0')}:${_jamSelesai!.minute.toString().padLeft(2, '0')}';

    AttendanceSettings newSettings = AttendanceSettings(
      id: 'default_settings',
      jamMulai: jamMulaiStr,
      jamSelesai: jamSelesaiStr,
      aktif: _aktif,
    );

    bool success = await AttendanceTimeHelper.updateSettings(newSettings);

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pengaturan berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Gagal menyimpan pengaturan!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickTime(bool isStart) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart 
          ? (_jamMulai ?? const TimeOfDay(hour: 6, minute: 30))
          : (_jamSelesai ?? const TimeOfDay(hour: 13, minute: 55)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF81C784),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _jamMulai = picked;
        } else {
          _jamSelesai = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF81C784),
        title: const Text(
          'Pengaturan Waktu Presensi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Atur Waktu Presensi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Status: ${_aktif ? "AKTIF ✅" : "NON-AKTIF ⛔"}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Enable/Disable Switch
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Aktifkan Pembatasan Waktu',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        _aktif
                            ? 'Siswa hanya bisa presensi pada waktu yang ditentukan'
                            : 'Siswa bisa presensi kapan saja',
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: _aktif,
                      activeColor: const Color(0xFF81C784),
                      onChanged: (bool value) {
                        setState(() => _aktif = value);
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Jam Mulai
                  _buildTimeCard(
                    title: 'Jam Mulai Presensi',
                    icon: Icons.login,
                    time: _jamMulai,
                    onTap: () => _pickTime(true),
                    color: const Color(0xFF4CAF50),
                  ),

                  const SizedBox(height: 15),

                  // Jam Selesai
                  _buildTimeCard(
                    title: 'Jam Selesai Presensi',
                    icon: Icons.logout,
                    time: _jamSelesai,
                    onTap: () => _pickTime(false),
                    color: const Color(0xFFFF7043),
                  ),

                  const SizedBox(height: 30),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2196F3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF2196F3),
                          size: 30,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informasi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _aktif
                                    ? 'Siswa hanya dapat melakukan presensi antara pukul ${_formatTime(_jamMulai)} - ${_formatTime(_jamSelesai)} WIB'
                                    : 'Pembatasan waktu tidak aktif. Siswa dapat presensi kapan saja.',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81C784),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Simpan Pengaturan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Extra space at bottom to avoid overlay
                  const SizedBox(height: 20),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String title,
    required IconData icon,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    time != null
                        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} WIB'
                        : 'Belum diatur',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '-';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
