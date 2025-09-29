import 'dart:developer';

import 'package:smart_presensee/model/face_features.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

Future<FaceFeatures?> extractFaceFeatures(
    InputImage inputImage, FaceDetector faceDetector) async {
  try {
    List<Face> faceList = await faceDetector.processImage(inputImage);
    if (faceList.isEmpty) {
      return null;
    }
    Face face = faceList.first;

    FaceFeatures faceFeatures = FaceFeatures(
      rightEar: Points(
          x: (face.landmarks[FaceLandmarkType.rightEar])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.rightEar])?.position.y.round()),
      leftEar: Points(
          x: (face.landmarks[FaceLandmarkType.leftEar])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.leftEar])?.position.y.round()),
      rightMouth: Points(
          x: (face.landmarks[FaceLandmarkType.rightMouth])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.rightMouth])?.position.y.round()),
      leftMouth: Points(
          x: (face.landmarks[FaceLandmarkType.leftMouth])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.leftMouth])?.position.y.round()),
      rightEye: Points(
          x: (face.landmarks[FaceLandmarkType.rightEye])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.rightEye])?.position.y.round()),
      leftEye: Points(
          x: (face.landmarks[FaceLandmarkType.leftEye])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.leftEye])?.position.y.round()),
      rightCheek: Points(
          x: (face.landmarks[FaceLandmarkType.rightCheek])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.rightCheek])?.position.y.round()),
      leftCheek: Points(
          x: (face.landmarks[FaceLandmarkType.leftCheek])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.leftCheek])?.position.y.round()),
      noseBase: Points(
          x: (face.landmarks[FaceLandmarkType.noseBase])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.noseBase])?.position.y.round()),
      bottomMouth: Points(
          x: (face.landmarks[FaceLandmarkType.bottomMouth])?.position.x.round(),
          y: (face.landmarks[FaceLandmarkType.bottomMouth])?.position.y.round()),
    );
    return faceFeatures;
  } on Exception catch (error, stacktrace) {
    log('Error -------> $error');
    log('Stacktrace -------> $stacktrace');
  }
  return null;
}

/// Konversi langsung dari objek Face (hasil deteksi) menjadi FaceFeatures
FaceFeatures? extractFaceFeaturesFromFace(Face face) {
  try {
    return FaceFeatures(
      rightEar: Points(
          x: face.landmarks[FaceLandmarkType.rightEar]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.rightEar]?.position.y.round()),
      leftEar: Points(
          x: face.landmarks[FaceLandmarkType.leftEar]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.leftEar]?.position.y.round()),
      rightMouth: Points(
          x: face.landmarks[FaceLandmarkType.rightMouth]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.rightMouth]?.position.y.round()),
      leftMouth: Points(
          x: face.landmarks[FaceLandmarkType.leftMouth]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.leftMouth]?.position.y.round()),
      rightEye: Points(
          x: face.landmarks[FaceLandmarkType.rightEye]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.rightEye]?.position.y.round()),
      leftEye: Points(
          x: face.landmarks[FaceLandmarkType.leftEye]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.leftEye]?.position.y.round()),
      rightCheek: Points(
          x: face.landmarks[FaceLandmarkType.rightCheek]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.rightCheek]?.position.y.round()),
      leftCheek: Points(
          x: face.landmarks[FaceLandmarkType.leftCheek]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.leftCheek]?.position.y.round()),
      noseBase: Points(
          x: face.landmarks[FaceLandmarkType.noseBase]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.noseBase]?.position.y.round()),
      bottomMouth: Points(
          x: face.landmarks[FaceLandmarkType.bottomMouth]?.position.x.round(),
          y: face.landmarks[FaceLandmarkType.bottomMouth]?.position.y.round()),
    );
  } catch (_) {
    return null;
  }
}
