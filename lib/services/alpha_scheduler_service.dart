import 'dart:async';
import 'dart:developer';
import 'package:smart_presensee/services/auto_alpha_service.dart';
import 'package:smart_presensee/services/attendance_time_helper.dart';
import 'package:smart_presensee/model/attendance_settings.dart';

/// Service untuk menjadwalkan auto-alpha pada waktu tertentu
class AlphaSchedulerService {
  static Timer? _dailyTimer;
  static Timer? _checkTimer;
  static bool _isRunning = false;
  static DateTime? _lastExecutionDate;

  /// Start scheduler - akan mengecek setiap menit dan menjalankan di waktu yang tepat
  static void startScheduler() {
    if (_isRunning) {
      log('⚠️ Scheduler sudah berjalan');
      return;
    }

    log('🚀 Starting Alpha Scheduler...');
    _isRunning = true;

    // Check setiap 30 detik
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkAndExecuteAlpha();
    });

    log('✅ Alpha Scheduler started - checking every 30 seconds');
  }

  /// Stop scheduler
  static void stopScheduler() {
    log('🛑 Stopping Alpha Scheduler...');
    _checkTimer?.cancel();
    _dailyTimer?.cancel();
    _isRunning = false;
    log('✅ Alpha Scheduler stopped');
  }

  /// Check apakah sudah waktunya execute alpha
  static Future<void> _checkAndExecuteAlpha() async {
    try {
      DateTime now = DateTime.now();
      
      // Cek apakah sudah dijalankan hari ini
      if (_lastExecutionDate != null &&
          _lastExecutionDate!.year == now.year &&
          _lastExecutionDate!.month == now.month &&
          _lastExecutionDate!.day == now.day) {
        // Sudah dijalankan hari ini, skip
        return;
      }

      // Ambil settings untuk mengetahui jam selesai
      AttendanceSettings settings = await AttendanceTimeHelper.getSettings();
      
      if (settings.aktif != true) {
        log('⚠️ Attendance settings tidak aktif, skip auto-alpha');
        return;
      }

      // Parse jam selesai (default 13:55)
      String jamSelesai = settings.jamSelesai ?? '13:55';
      List<String> timeParts = jamSelesai.split(':');
      int targetHour = int.parse(timeParts[0]);
      int targetMinute = int.parse(timeParts[1]);
      
      // Tambah 1 menit dari jam selesai untuk execute (jadi 13:56 jika jam selesai 13:55)
      targetMinute += 1;
      if (targetMinute >= 60) {
        targetMinute = 0;
        targetHour += 1;
      }

      // Cek apakah sekarang adalah waktu yang tepat
      // Toleransi 1 menit untuk memastikan tidak terlewat
      if (now.hour == targetHour && now.minute == targetMinute) {
        log('⏰ Waktu auto-alpha: ${targetHour.toString().padLeft(2, '0')}:${targetMinute.toString().padLeft(2, '0')}');
        log('🔄 Executing auto-alpha generation...');
        
        // Execute auto-alpha
        Map<String, dynamic> result = await AutoAlphaService.generateAutoAlpha();
        
        if (result['success'] == true) {
          log('✅ Auto-alpha executed successfully');
          log('📊 Alpha count: ${result['alphaCount']}');
          log('📧 Emails sent: ${result['emailSentCount']}');
          
          // Tandai sudah dijalankan hari ini
          _lastExecutionDate = now;
        } else {
          log('❌ Auto-alpha execution failed: ${result['message']}');
        }
      }
    } catch (e) {
      log('❌ Error in alpha scheduler: $e');
    }
  }

  /// Execute alpha sekarang (manual trigger)
  static Future<Map<String, dynamic>> executeNow() async {
    log('🔄 Manual execution of auto-alpha...');
    try {
      Map<String, dynamic> result = await AutoAlphaService.generateAutoAlpha();
      
      if (result['success'] == true) {
        // Tandai sudah dijalankan hari ini
        _lastExecutionDate = DateTime.now();
      }
      
      return result;
    } catch (e) {
      log('❌ Error executing auto-alpha: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'alphaCount': 0,
      };
    }
  }

  /// Get scheduler status
  static Map<String, dynamic> getStatus() {
    DateTime now = DateTime.now();
    bool executedToday = _lastExecutionDate != null &&
        _lastExecutionDate!.year == now.year &&
        _lastExecutionDate!.month == now.month &&
        _lastExecutionDate!.day == now.day;

    return {
      'isRunning': _isRunning,
      'lastExecutionDate': _lastExecutionDate?.toString(),
      'executedToday': executedToday,
    };
  }

  /// Reset execution flag (untuk testing)
  static void resetExecutionFlag() {
    _lastExecutionDate = null;
    log('🔄 Execution flag reset');
  }
}

