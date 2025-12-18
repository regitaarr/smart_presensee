import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/model/accuracy_metrics.dart';

/// Service untuk tracking dan logging akurasi sistem face recognition
class AccuracyTrackingService {
  static const String _metricsCollection = 'accuracy_metrics';

  /// Log metrics ke Firestore
  static Future<void> logMetrics(AccuracyMetrics metrics) async {
    try {
      await FirebaseFirestore.instance
          .collection(_metricsCollection)
          .doc(metrics.kodeMetric)
          .set(metrics.toMap());
      
      log('📊 Metrics logged: ${metrics.toString()}', name: 'AccuracyTracking');
    } catch (e) {
      log('❌ Error logging metrics: $e', name: 'AccuracyTracking');
    }
  }

  /// Log attempt yang sukses (hanya 1x per siswa per hari)
  static Future<void> logSuccessAttempt({
    required String nisn,
    required double confidenceScore,
    required int responseTimeMs,
    required String lightingCondition,
    required String faceDetectionMode,
    required double matchScore,
    String recognitionMode = 'auto',
    int attemptNumber = 1,
  }) async {
    // Cek apakah siswa ini sudah punya metrics success hari ini
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    try {
      QuerySnapshot existingMetrics = await FirebaseFirestore.instance
          .collection(_metricsCollection)
          .where('nisn', isEqualTo: nisn)
          .where('status', isEqualTo: 'success')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (existingMetrics.docs.isNotEmpty) {
        log('⚠️ Metrics already logged for NISN $nisn today, skipping', name: 'AccuracyTracking');
        return; // Sudah ada metrics hari ini, skip
      }
    } catch (e) {
      log('⚠️ Error checking existing metrics: $e', name: 'AccuracyTracking');
      // Lanjutkan logging meskipun cek gagal
    }

    // Belum ada metrics hari ini, log baru
    final metrics = AccuracyMetrics(
      kodeMetric: _generateKodeMetric(),
      timestamp: DateTime.now(),
      nisn: nisn,
      status: 'success',
      confidenceScore: confidenceScore,
      responseTimeMs: responseTimeMs,
      lightingCondition: lightingCondition,
      faceDetectionMode: faceDetectionMode,
      matchScore: matchScore,
      recognitionMode: recognitionMode,
      attemptNumber: attemptNumber,
      facesDetectedCount: 1,
    );

    await logMetrics(metrics);
  }

  /// Log attempt yang gagal (TIDAK di-log untuk menghindari spam data)
  /// Hanya success yang di-log untuk tracking akurasi final
  static Future<void> logFailureAttempt({
    required String errorType,
    required String errorMessage,
    required int responseTimeMs,
    required String lightingCondition,
    required String faceDetectionMode,
    String? nisn,
    int? facesDetectedCount,
    double? matchScore,
    String recognitionMode = 'auto',
    int attemptNumber = 1,
  }) async {
    // Tidak log failure untuk menghindari data berlebihan
    // Hanya success yang dicatat sebagai metrics final
    log('⚠️ Failure attempt not logged (by design): $errorType', name: 'AccuracyTracking');
    return;
  }


  /// Generate unique kode metric
  static String _generateKodeMetric() {
    DateTime now = DateTime.now();
    String timestamp = now.millisecondsSinceEpoch.toString();
    return 'METRIC_$timestamp';
  }

  /// Get metrics for a specific student (untuk analisis per siswa)
  static Future<List<AccuracyMetrics>> getMetricsForStudent({
    required String nisn,
    int limit = 50,
  }) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(_metricsCollection)
          .where('nisn', isEqualTo: nisn)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AccuracyMetrics.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      log('❌ Error getting metrics for student: $e', name: 'AccuracyTracking');
      return [];
    }
  }

  /// Calculate student-specific success rate
  static Future<double> getStudentSuccessRate(String nisn) async {
    try {
      List<AccuracyMetrics> metrics = await getMetricsForStudent(nisn: nisn);
      
      if (metrics.isEmpty) return 0.0;

      int successCount = metrics.where((m) => m.isSuccess).length;
      return (successCount / metrics.length) * 100;
    } catch (e) {
      log('❌ Error calculating student success rate: $e', name: 'AccuracyTracking');
      return 0.0;
    }
  }

  /// Get students with low success rate (need attention)
  static Future<List<Map<String, dynamic>>> getStudentsNeedingAttention({
    double threshold = 70.0,
    int minAttempts = 3,
  }) async {
    try {
      // Get recent metrics grouped by student
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(_metricsCollection)
          .where('nisn', isNotEqualTo: null)
          .orderBy('nisn')
          .orderBy('timestamp', descending: true)
          .get();

      // Group by student and calculate success rates
      Map<String, List<AccuracyMetrics>> studentMetrics = {};
      
      for (var doc in snapshot.docs) {
        AccuracyMetrics metric = AccuracyMetrics.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
        
        if (metric.nisn != null) {
          if (!studentMetrics.containsKey(metric.nisn)) {
            studentMetrics[metric.nisn!] = [];
          }
          studentMetrics[metric.nisn!]!.add(metric);
        }
      }

      List<Map<String, dynamic>> needsAttention = [];

      studentMetrics.forEach((nisn, metrics) {
        if (metrics.length >= minAttempts) {
          int successCount = metrics.where((m) => m.isSuccess).length;
          double successRate = (successCount / metrics.length) * 100;

          if (successRate < threshold) {
            needsAttention.add({
              'nisn': nisn,
              'success_rate': successRate,
              'total_attempts': metrics.length,
              'success_count': successCount,
            });
          }
        }
      });

      // Sort by success rate (lowest first)
      needsAttention.sort((a, b) => a['success_rate'].compareTo(b['success_rate']));

      return needsAttention;
    } catch (e) {
      log('❌ Error getting students needing attention: $e', name: 'AccuracyTracking');
      return [];
    }
  }
}

