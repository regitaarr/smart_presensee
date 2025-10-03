import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // Konfigurasi SMTP Gmail - Ganti dengan email dan app password Anda
  // Tutorial: https://support.google.com/accounts/answer/185833
  static const String _senderEmail = 'rgtamaa1412@gmail.com'; // Email pengirim
  static const String _senderPassword = 'oftd xmga jubj mkdb'; // App Password (bukan password biasa!)
  static const String _senderName = 'MIN 4 Ciamis - Smart Presensee';

  // Fungsi untuk kirim email notifikasi kehadiran
  static Future<bool> sendAttendanceNotification({
    required String studentName,
    required String nisn,
    required String parentEmail,
    required String attendanceStatus,
    required DateTime attendanceTime,
    String? className,
  }) async {
    try {
      // Validasi email
      if (parentEmail.isEmpty || !_isValidEmail(parentEmail)) {
        log('Email orang tua tidak valid: $parentEmail');
        return false;
      }

      // Format waktu (tanpa locale untuk menghindari error initialization)
      String formattedDate = _formatIndonesianDate(attendanceTime);
      String formattedTime = DateFormat('HH:mm').format(attendanceTime);

      // Status dalam bahasa Indonesia
      String statusText = _getStatusText(attendanceStatus);
      String statusEmoji = _getStatusEmoji(attendanceStatus);

      // Setup SMTP Gmail
      final smtpServer = gmail(_senderEmail, _senderPassword);

      // Buat message email dengan HTML
      final message = Message()
        ..from = const Address(_senderEmail, _senderName)
        ..recipients.add(parentEmail)
        ..subject = '📧 Notifikasi Kehadiran Siswa - $studentName (MIN 4 Ciamis)'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f9f9f9;
        }
        .header {
            background: linear-gradient(135deg, #81C784, #66BB6A);
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 10px 10px 0 0;
        }
        .content {
            background: white;
            padding: 30px;
            border-radius: 0 0 10px 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .info-box {
            background: #f5f5f5;
            padding: 15px;
            border-left: 4px solid #81C784;
            margin: 20px 0;
        }
        .info-row {
            padding: 8px 0;
            border-bottom: 1px solid #e0e0e0;
        }
        .label {
            font-weight: bold;
            color: #555;
            display: inline-block;
            width: 150px;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            padding-top: 20px;
            border-top: 2px solid #e0e0e0;
            color: #777;
            font-size: 12px;
        }
        .status {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-weight: bold;
        }
        .status-hadir {
            background: #E8F5E9;
            color: #2E7D32;
        }
        .status-izin {
            background: #E3F2FD;
            color: #1976D2;
        }
        .status-sakit {
            background: #FFF3E0;
            color: #F57C00;
        }
        .status-alpha {
            background: #FFEBEE;
            color: #C62828;
        }
        .message-hadir {
            background: #E8F5E9;
            color: #2E7D32;
        }
        .message-izin {
            background: #E3F2FD;
            color: #1976D2;
        }
        .message-sakit {
            background: #FFF3E0;
            color: #F57C00;
        }
        .message-alpha {
            background: #FFEBEE;
            color: #C62828;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 style="margin: 15px 0 10px; font-size: 32px; font-weight: bold;">Smart Presensee</h1>
            <h2 style="margin: 5px 0; font-size: 24px; font-weight: normal;">MIN 4 Ciamis</h2>
            <p style="margin: 10px 0 15px; font-size: 16px; opacity: 0.9;">Absen Digital. Sekolah Makin Pintar!</p>
        </div>
        
        <div class="content">
            <h2>Notifikasi Presensi Kehadiran</h2>
            <p>Assalamualaikum Wr. Wb. <br>Kepada Yth. Orang Tua/Wali dari <strong>$studentName</strong>,</p>
            
            <p>Kami informasikan bahwa putra/putri Anda telah melakukan presensi dengan detail sebagai berikut:</p>
            
            <div class="info-box">
                <div class="info-row">
                    <span class="label">👤 Nama Siswa</span>
                    <span>: $studentName</span>
                </div>
                <div class="info-row">
                    <span class="label">🆔 NISN</span>
                    <span>: $nisn</span>
                </div>
                <div class="info-row">
                    <span class="label">🏫 Kelas</span>
                    <span>: ${className ?? '-'}</span>
                </div>
                <div class="info-row">
                    <span class="label">📅 Tanggal</span>
                    <span>: $formattedDate</span>
                </div>
                <div class="info-row">
                    <span class="label">🕐 Waktu</span>
                    <span>: $formattedTime WIB</span>
                </div>
                <div class="info-row">
                    <span class="label">$statusEmoji Status</span>
                    <span>: <span class="status status-${attendanceStatus.toLowerCase()}">$statusText</span></span>
                </div>
            </div>
            
            <p class="message-${attendanceStatus.toLowerCase()}" style="padding: 15px; border-radius: 5px;">
                ${_getStatusMessage(attendanceStatus)}
            </p>
            
            <p>Terima kasih atas perhatian dan kerja sama Anda.<br> Wassalamualaikum Wr. Wb.</p>
            
            <p style="margin-top: 30px;">
                Hormat kami,<br>
                <strong>Admin Smart Presensee</strong>
            </p>
        </div>
        
        <div class="footer">
            <p>📧 Email ini dikirim secara otomatis oleh sistem.</p>
            <p>Jangan membalas email ini.</p>
        </div>
    </div>
</body>
</html>
''';

      // Kirim email
      final sendReport = await send(message, smtpServer);
      
      log('✅ Email berhasil dikirim ke: $parentEmail');
      log('Send report: ${sendReport.toString()}');
      
      // Simpan log email ke Firestore
      await _saveEmailLog(
        parentEmail: parentEmail,
        studentName: studentName,
        nisn: nisn,
        status: attendanceStatus,
        sentAt: DateTime.now(),
        success: true,
      );
      
      return true;
    } catch (e) {
      log('❌ Error saat kirim email: $e');
      
      await _saveEmailLog(
        parentEmail: parentEmail,
        studentName: studentName,
        nisn: nisn,
        status: attendanceStatus,
        sentAt: DateTime.now(),
        success: false,
        errorMessage: e.toString(),
      );
      
      return false;
    }
  }

  // Validasi format email
  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Format tanggal dalam bahasa Indonesia tanpa perlu locale initialization
  static String _formatIndonesianDate(DateTime date) {
    const List<String> days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    
    const List<String> months = [
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

    // weekday: 1=Monday, 7=Sunday
    String dayName = days[date.weekday - 1];
    String monthName = months[date.month - 1];
    
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  // Konversi status ke teks Indonesia
  static String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'HADIR';
      case 'izin':
        return 'IZIN';
      case 'sakit':
        return 'SAKIT';
      case 'alpha':
      case 'tidak hadir':
        return 'ALPHA (Tidak Hadir)';
      default:
        return status.toUpperCase();
    }
  }

  // Emoji untuk status
  static String _getStatusEmoji(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return '✅';
      case 'izin':
        return '📝';
      case 'sakit':
        return '🏥';
      case 'alpha':
      case 'tidak hadir':
        return '❌';
      default:
        return '📌';
    }
  }

  // Pesan tambahan berdasarkan status
  static String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return '✅ Putra/putri Anda telah hadir tepat waktu. Terima kasih atas kedisiplinannya!';
      case 'izin':
        return '📝 Putra/putri Anda tercatat izin. Pastikan surat izin telah disampaikan ke sekolah.';
      case 'sakit':
        return '🏥 Putra/putri Anda tercatat sakit. Semoga segera pulih dan dapat kembali belajar.';
      case 'alpha':
      case 'tidak hadir':
        return '❌ Putra/putri Anda tidak hadir tanpa keterangan. Mohon segera menghubungi wali kelas.';
      default:
        return 'Status presensi telah tercatat dalam sistem.';
    }
  }

  // Simpan log pengiriman email ke Firestore
  static Future<void> _saveEmailLog({
    required String parentEmail,
    required String studentName,
    required String nisn,
    required String status,
    required DateTime sentAt,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('email_logs').add({
        'parent_email': parentEmail,
        'student_name': studentName,
        'nisn': nisn,
        'attendance_status': status,
        'sent_at': Timestamp.fromDate(sentAt),
        'success': success,
        'error_message': errorMessage,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('Error saving email log: $e');
    }
  }

  // Kirim email test untuk konfigurasi
  static Future<bool> sendTestEmail(String testEmail) async {
    try {
      return await sendAttendanceNotification(
        studentName: 'Test Student',
        nisn: '1234567890',
        parentEmail: testEmail,
        attendanceStatus: 'hadir',
        attendanceTime: DateTime.now(),
        className: 'Test Class',
      );
    } catch (e) {
      log('Error sending test email: $e');
      return false;
    }
  }
}
