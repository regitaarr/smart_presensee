import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/model/attendance_settings.dart';

class AttendanceTimeHelper {
  static const String _settingsCollection = 'attendance_settings';
  static const String _defaultDocId = 'default_settings';

  // Cek apakah waktu sekarang dalam rentang waktu presensi
  static Future<Map<String, dynamic>> checkAttendanceTime() async {
    try {
      // Ambil setting dari Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection(_settingsCollection)
          .doc(_defaultDocId)
          .get();

      AttendanceSettings settings;
      if (doc.exists) {
        settings = AttendanceSettings.fromJson(
            doc.data() as Map<String, dynamic>);
      } else {
        // Jika belum ada setting, buat default
        settings = AttendanceSettings(
          id: _defaultDocId,
          jamMulai: '06:30',
          jamSelesai: '13:55',
          aktif: true,
        );
        
        // Simpan default settings
        await FirebaseFirestore.instance
            .collection(_settingsCollection)
            .doc(_defaultDocId)
            .set(settings.toJson());
      }

      // Jika setting tidak aktif, izinkan presensi kapan saja
      if (settings.aktif == false) {
        return {
          'allowed': true,
          'message': 'Pembatasan waktu presensi tidak aktif',
        };
      }

      // Parse jam mulai dan selesai
      DateTime now = DateTime.now();
      DateTime jamMulaiDT = _parseTime(settings.jamMulai ?? '06:30');
      DateTime jamSelesaiDT = _parseTime(settings.jamSelesai ?? '13:55');

      // Cek apakah waktu sekarang dalam rentang
      if (now.hour < jamMulaiDT.hour ||
          (now.hour == jamMulaiDT.hour && now.minute < jamMulaiDT.minute)) {
        return {
          'allowed': false,
          'message':
              'Presensi belum dibuka. Waktu presensi mulai pukul ${settings.jamMulai} WIB',
        };
      }

      if (now.hour > jamSelesaiDT.hour ||
          (now.hour == jamSelesaiDT.hour && now.minute > jamSelesaiDT.minute)) {
        return {
          'allowed': false,
          'message':
              'Waktu presensi sudah berakhir. Presensi ditutup pukul ${settings.jamSelesai} WIB',
        };
      }

      // Waktu presensi valid
      return {
        'allowed': true,
        'message': 'Waktu presensi valid',
        'jam_mulai': settings.jamMulai,
        'jam_selesai': settings.jamSelesai,
      };
    } catch (e) {
      log('Error checking attendance time: $e');
      // Jika ada error, izinkan presensi (fail-safe)
      return {
        'allowed': true,
        'message': 'Error checking time, allowing attendance',
      };
    }
  }

  // Parse string time ke DateTime
  static DateTime _parseTime(String timeString) {
    List<String> parts = timeString.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);

    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  // Get current settings
  static Future<AttendanceSettings> getSettings() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection(_settingsCollection)
          .doc(_defaultDocId)
          .get();

      if (doc.exists) {
        return AttendanceSettings.fromJson(
            doc.data() as Map<String, dynamic>);
      } else {
        // Return default settings
        return AttendanceSettings(
          id: _defaultDocId,
          jamMulai: '06:30',
          jamSelesai: '13:55',
          aktif: true,
        );
      }
    } catch (e) {
      log('Error getting settings: $e');
      return AttendanceSettings(
        id: _defaultDocId,
        jamMulai: '06:30',
        jamSelesai: '13:55',
        aktif: true,
      );
    }
  }

  // Update settings
  static Future<bool> updateSettings(AttendanceSettings settings) async {
    try {
      await FirebaseFirestore.instance
          .collection(_settingsCollection)
          .doc(_defaultDocId)
          .set(settings.toJson());
      
      log('✅ Settings updated successfully');
      return true;
    } catch (e) {
      log('❌ Error updating settings: $e');
      return false;
    }
  }

  // Format time string untuk display
  static String formatTimeDisplay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '-';
    return '$timeString WIB';
  }
}
