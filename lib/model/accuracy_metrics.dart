import 'package:cloud_firestore/cloud_firestore.dart';

/// Model untuk tracking akurasi dan performa sistem face recognition
class AccuracyMetrics {
  final String kodeMetric;
  final DateTime timestamp;
  final String? nisn;
  final String status; // 'success', 'failure', 'no_face', 'no_match', 'multiple_faces'
  final double? confidenceScore; // 0-100
  final int responseTimeMs;
  final String lightingCondition; // 'normal', 'low-light'
  final String faceDetectionMode; // 'fast', 'accurate'
  final int attemptNumber;
  final String? errorType; // null jika success
  final String? errorMessage;
  final int? facesDetectedCount;
  final double? matchScore; // similarity score dari matching algorithm
  final String recognitionMode; // 'auto', 'manual'

  AccuracyMetrics({
    required this.kodeMetric,
    required this.timestamp,
    this.nisn,
    required this.status,
    this.confidenceScore,
    required this.responseTimeMs,
    required this.lightingCondition,
    required this.faceDetectionMode,
    this.attemptNumber = 1,
    this.errorType,
    this.errorMessage,
    this.facesDetectedCount,
    this.matchScore,
    this.recognitionMode = 'auto',
  });

  /// Convert to Map untuk Firestore (semua field bahasa Indonesia)
  Map<String, dynamic> toMap() {
    return {
      'kode_metric': kodeMetric,
      'tanggal_waktu': Timestamp.fromDate(timestamp),
      'nisn': nisn,
      'status': status,
      'skor_keyakinan': confidenceScore,
      'waktu_respon_ms': responseTimeMs,
      'kondisi_cahaya': lightingCondition,
      'mode_deteksi': faceDetectionMode,
      'nomor_percobaan': attemptNumber,
      'tipe_kesalahan': errorType,
      'pesan_kesalahan': errorMessage,
      'jumlah_wajah_terdeteksi': facesDetectedCount,
      'skor_kemiripan': matchScore,
      'mode_pengenalan': recognitionMode,
      'tanggal': DateTime(timestamp.year, timestamp.month, timestamp.day).toIso8601String(),
    };
  }

  /// Create from Firestore document (membaca field bahasa Indonesia)
  factory AccuracyMetrics.fromMap(Map<String, dynamic> map, String docId) {
    return AccuracyMetrics(
      kodeMetric: map['kode_metric'] ?? docId,
      timestamp: (map['tanggal_waktu'] as Timestamp).toDate(),
      nisn: map['nisn'],
      status: map['status'] ?? 'unknown',
      confidenceScore: map['skor_keyakinan']?.toDouble(),
      responseTimeMs: map['waktu_respon_ms'] ?? 0,
      lightingCondition: map['kondisi_cahaya'] ?? 'unknown',
      faceDetectionMode: map['mode_deteksi'] ?? 'fast',
      attemptNumber: map['nomor_percobaan'] ?? 1,
      errorType: map['tipe_kesalahan'],
      errorMessage: map['pesan_kesalahan'],
      facesDetectedCount: map['jumlah_wajah_terdeteksi'],
      matchScore: map['skor_kemiripan']?.toDouble(),
      recognitionMode: map['mode_pengenalan'] ?? 'auto',
    );
  }

  /// Get confidence level category
  String getConfidenceLevel() {
    if (confidenceScore == null) return 'unknown';
    if (confidenceScore! >= 95) return 'high'; // Hijau
    if (confidenceScore! >= 85) return 'medium'; // Kuning
    return 'low'; // Merah
  }

  /// Get confidence color for UI
  String getConfidenceColor() {
    switch (getConfidenceLevel()) {
      case 'high':
        return '#4CAF50'; // Green
      case 'medium':
        return '#FFC107'; // Amber/Yellow
      case 'low':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }

  /// Check if this was a successful recognition
  bool get isSuccess => status == 'success';

  @override
  String toString() {
    return 'AccuracyMetrics(status: $status, confidence: $confidenceScore%, responseTime: ${responseTimeMs}ms, lighting: $lightingCondition)';
  }
}

