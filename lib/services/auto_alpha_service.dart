import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/services/attendance_time_helper.dart';
import 'package:smart_presensee/services/email_service.dart';
import 'package:smart_presensee/model/attendance_settings.dart';

class AutoAlphaService {
  static const String _presensiCollection = 'presensi';
  static const String _siswaCollection = 'siswa';

  /// Generate presensi alpha untuk siswa yang belum absen hari ini
  static Future<Map<String, dynamic>> generateAutoAlpha() async {
    try {
      log('🔄 Starting auto-alpha generation...');

      // 1. Get attendance settings
      AttendanceSettings settings = await AttendanceTimeHelper.getSettings();
      
      // 2. Check if restriction is active and if current time is past end time
      if (settings.aktif == true) {
        DateTime now = DateTime.now();
        List<String> endTimeParts = (settings.jamSelesai ?? '13:55').split(':');
        int endHour = int.parse(endTimeParts[0]);
        int endMinute = int.parse(endTimeParts[1]);
        
        // Only generate alpha if current time is past the end time
        if (now.hour < endHour || (now.hour == endHour && now.minute < endMinute)) {
          return {
            'success': false,
            'message': 'Belum waktunya generate alpha. Presensi masih berlangsung sampai ${settings.jamSelesai} WIB',
            'alphaCount': 0,
          };
        }
      }

      // 3. Get all students
      QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance
          .collection(_siswaCollection)
          .get();

      if (studentsSnapshot.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Tidak ada data siswa',
          'alphaCount': 0,
        };
      }

      // 4. Get today's attendance records
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      QuerySnapshot todayAttendanceSnapshot = await FirebaseFirestore.instance
          .collection(_presensiCollection)
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      // 5. Create a set of NISNs who already have attendance today
      Set<String> attendedNISNs = {};
      for (var doc in todayAttendanceSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String? nisn = data['nisn'];
        if (nisn != null && nisn.isNotEmpty) {
          attendedNISNs.add(nisn);
        }
      }

      log('📊 Total students: ${studentsSnapshot.docs.length}');
      log('📊 Already attended: ${attendedNISNs.length}');

      // 6. Generate alpha for students who haven't attended
      int alphaCount = 0;
      List<String> alphaStudents = [];
      int emailSentCount = 0;

      for (var studentDoc in studentsSnapshot.docs) {
        Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
        String nisn = studentDoc.id;
        String studentName = studentData['nama_siswa'] ?? 'Unknown';

        // Skip if student already attended today
        if (attendedNISNs.contains(nisn)) {
          continue;
        }

        // Generate alpha record
        String alphaId = await _generateAlphaId();
        DateTime alphaTime = DateTime.now();
        
        Map<String, dynamic> alphaData = {
          'id_presensi': alphaId,
          'nisn': nisn,
          'tanggal_waktu': Timestamp.fromDate(alphaTime),
          'status': 'alpha',
          'metode': 'auto_generated',
        };

        await FirebaseFirestore.instance
            .collection(_presensiCollection)
            .doc(alphaId)
            .set(alphaData);

        alphaCount++;
        alphaStudents.add(studentName);
        
        log('✅ Generated alpha for: $studentName (NISN: $nisn)');
        
        // Kirim email notifikasi ke orang tua
        String? emailOrangtua = studentData['email_orangtua'];
        String? kelas = studentData['kelas_sw'];
        
        if (emailOrangtua != null && emailOrangtua.isNotEmpty) {
          try {
            bool emailSent = await EmailService.sendAttendanceNotification(
              studentName: studentName,
              nisn: nisn,
              parentEmail: emailOrangtua,
              attendanceStatus: 'alpha',
              attendanceTime: alphaTime,
              className: kelas,
            );
            
            if (emailSent) {
              emailSentCount++;
              log('📧 Email alpha sent to: $emailOrangtua for $studentName');
            }
          } catch (e) {
            log('❌ Failed to send email for $studentName: $e');
          }
        } else {
          log('⚠️ No email for $studentName (NISN: $nisn)');
        }
      }

      log('✅ Auto-alpha generation completed. Total alpha: $alphaCount');
      log('📧 Emails sent: $emailSentCount/$alphaCount');

      String message = alphaCount > 0
          ? 'Berhasil generate $alphaCount siswa alpha. Email dikirim ke $emailSentCount orang tua.'
          : 'Semua siswa sudah presensi hari ini';

      return {
        'success': true,
        'message': message,
        'alphaCount': alphaCount,
        'alphaStudents': alphaStudents,
        'emailSentCount': emailSentCount,
      };
    } catch (e) {
      log('❌ Error generating auto-alpha: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'alphaCount': 0,
      };
    }
  }

  /// Generate unique ID for alpha record (following same format as attendance)
  static Future<String> _generateAlphaId() async {
    try {
      const String prefix = 'idpr04';

      // Query last record to get the latest ID
      QuerySnapshot lastRecords = await FirebaseFirestore.instance
          .collection(_presensiCollection)
          .where('id_presensi', isGreaterThanOrEqualTo: prefix)
          .where('id_presensi', isLessThan: '${prefix}z')
          .orderBy('id_presensi', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;

      if (lastRecords.docs.isNotEmpty) {
        String lastId = lastRecords.docs.first.get('id_presensi') as String;
        log('Last presensi ID found: $lastId');

        if (lastId.length >= 10 && lastId.startsWith(prefix)) {
          String lastNumberStr = lastId.substring(6); // Skip "idpr04"
          int lastNumber = int.tryParse(lastNumberStr) ?? 0;
          nextNumber = lastNumber + 1;
        }
      }

      // Format: idpr04 + 4 digit number (e.g., idpr040001, idpr040002)
      String formattedNumber = nextNumber.toString().padLeft(4, '0');
      String newId = '$prefix$formattedNumber';

      log('Generated alpha ID: $newId (next number: $nextNumber)');
      return newId;
    } catch (e) {
      log('Error generating sequential alpha ID: $e');
      
      // Fallback: use timestamp-based ID
      DateTime now = DateTime.now();
      String timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      String fallbackId = 'idpr04$timeString';
      
      log('Using fallback ID: $fallbackId');
      return fallbackId;
    }
  }

  /// Check how many students need alpha today
  static Future<int> getAbsentStudentsCount() async {
    try {
      // Get all students
      QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance
          .collection(_siswaCollection)
          .get();

      // Get today's attendance
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      QuerySnapshot todayAttendanceSnapshot = await FirebaseFirestore.instance
          .collection(_presensiCollection)
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      Set<String> attendedNISNs = {};
      for (var doc in todayAttendanceSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String? nisn = data['nisn'];
        if (nisn != null && nisn.isNotEmpty) {
          attendedNISNs.add(nisn);
        }
      }

      int absentCount = studentsSnapshot.docs.length - attendedNISNs.length;
      return absentCount > 0 ? absentCount : 0;
    } catch (e) {
      log('Error getting absent students count: $e');
      return 0;
    }
  }
}
