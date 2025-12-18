import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Helper class untuk tracking metrics
class TrackingHelper {
  /// Deteksi kondisi pencahayaan dari CameraImage
  /// Returns: 'normal' atau 'low-light'
  static String detectLightingCondition(CameraImage? image) {
    if (image == null) return 'unknown';
    
    try {
      final Plane yPlane = image.planes.first; // Y channel dari YUV
      final bytes = yPlane.bytes;
      
      if (bytes.isEmpty) return 'unknown';
      
      int sum = 0;
      int count = 0;
      
      // Sampling setiap 8 byte untuk efisiensi
      for (int i = 0; i < bytes.length; i += 8) {
        sum += bytes[i];
        count++;
      }
      
      if (count == 0) return 'unknown';
      
      double avgLuminance = sum / count; // 0..255
      
      // Threshold: < 45 dianggap low-light
      return avgLuminance < 45.0 ? 'low-light' : 'normal';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Estimasi luminance tanpa CameraImage (dari metadata atau kondisi lain)
  static String estimateLightingFromCondition(bool isLowLight) {
    return isLowLight ? 'low-light' : 'normal';
  }

  /// Convert similarity score geometric (0 = perfect, higher = worse) ke confidence percentage
  /// Score geometric optimal: 0.055 - 0.11
  /// Output: 0-100%
  static double convertGeometricScoreToConfidence(double score) {
    // Geometric matching: semakin kecil semakin baik
    // Perfect match: ~0.05 = 100% confidence
    // Good match: ~0.11 = 85-90% confidence
    // Poor match: >0.2 = <70% confidence
    
    if (score <= 0.05) {
      return 100.0; // Perfect match
    } else if (score <= 0.11) {
      // Linear interpolation antara 100% (score=0.05) dan 85% (score=0.11)
      // 100 - ((score - 0.05) / (0.11 - 0.05)) * 15
      double factor = (score - 0.05) / 0.06;
      return 100.0 - (factor * 15.0);
    } else if (score <= 0.20) {
      // Linear interpolation antara 85% (score=0.11) dan 50% (score=0.20)
      double factor = (score - 0.11) / 0.09;
      return 85.0 - (factor * 35.0);
    } else {
      // Score > 0.20: confidence menurun drastis
      double confidence = 50.0 * (0.3 / score).clamp(0.0, 1.0);
      return confidence.clamp(0.0, 50.0);
    }
  }

  /// Convert Regula SDK similarity (0-100%) ke confidence score
  /// Regula: 88%+ dianggap match
  static double convertRegulaScoreToConfidence(double regulaSimilarity) {
    // Regula SDK: 0-100%, higher is better
    // Threshold: 88% untuk match
    // Map ke confidence yang lebih intuitif
    
    if (regulaSimilarity >= 95) {
      return 98.0; // Sangat yakin
    } else if (regulaSimilarity >= 88) {
      // Linear map 88-95% ke 85-98%
      double factor = (regulaSimilarity - 88) / 7;
      return 85.0 + (factor * 13.0);
    } else {
      // Di bawah threshold, confidence = similarity
      return regulaSimilarity.clamp(0.0, 84.0);
    }
  }

  /// Get face detection mode dari FaceDetectorOptions
  static String getFaceDetectionMode(FaceDetectorMode mode) {
    switch (mode) {
      case FaceDetectorMode.fast:
        return 'fast';
      case FaceDetectorMode.accurate:
        return 'accurate';
      default:
        return 'unknown';
    }
  }

  /// Get current user ID (wali kelas) dari Firebase Auth
  static String getCurrentUserId(String? email, String? nip) {
    if (nip != null && nip.isNotEmpty) {
      return nip;
    } else if (email != null && email.isNotEmpty) {
      return email;
    } else {
      return 'unknown';
    }
  }

  /// Calculate response time dari startTime ke endTime
  static int calculateResponseTime(DateTime startTime, DateTime endTime) {
    return endTime.difference(startTime).inMilliseconds;
  }

  /// Determine error type dari kondisi failure
  static String getErrorType({
    required int facesDetectedCount,
    required double? matchScore,
    required double threshold,
  }) {
    if (facesDetectedCount == 0) {
      return 'no_face_detected';
    } else if (facesDetectedCount > 1) {
      return 'multiple_faces';
    } else if (matchScore == null) {
      return 'feature_extraction_failed';
    } else if (matchScore > threshold) {
      return 'no_match_found';
    } else {
      return 'unknown_error';
    }
  }

  /// Get error message yang user-friendly
  static String getErrorMessage(String errorType) {
    switch (errorType) {
      case 'no_face_detected':
        return 'Tidak ada wajah terdeteksi';
      case 'multiple_faces':
        return 'Terdeteksi lebih dari satu wajah';
      case 'feature_extraction_failed':
        return 'Gagal mengekstrak fitur wajah';
      case 'no_match_found':
        return 'Wajah tidak cocok dengan database';
      case 'time_restriction':
        return 'Di luar waktu presensi';
      case 'duplicate_attendance':
        return 'Sudah melakukan presensi hari ini';
      default:
        return 'Kesalahan tidak diketahui';
    }
  }

  /// Validate if metrics should be logged (untuk menghindari spam)
  static bool shouldLogMetrics({
    required DateTime? lastLogTime,
    int cooldownSeconds = 2,
  }) {
    if (lastLogTime == null) return true;
    
    final timeSinceLastLog = DateTime.now().difference(lastLogTime).inSeconds;
    return timeSinceLastLog >= cooldownSeconds;
  }
}

