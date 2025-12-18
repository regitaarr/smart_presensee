import 'package:cloud_firestore/cloud_firestore.dart';

import 'face_features.dart';

class UserModel {
  String? idWajah; // Changed from 'id' to 'idWajah'
  String? nisn; // Added NISN as foreign key from siswa collection
  String? name;
  String? gambar;
  FaceFeatures? faceFeatures;
  List<List<double>>? faceEmbeddings;
  Timestamp? registeredOn;

  UserModel({
    this.idWajah,
    this.nisn,
    this.name,
    this.gambar,
    this.faceFeatures,
    this.faceEmbeddings,
    this.registeredOn,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<List<double>>? _parseEmbeddings(dynamic raw) {
      if (raw is List) {
        final parsed = <List<double>>[];
        for (final sample in raw) {
          if (sample is List) {
            parsed.add(sample.map((v) => (v as num).toDouble()).toList());
          }
        }
        if (parsed.isNotEmpty) return parsed;
      }
      return null;
    }

    return UserModel(
      idWajah: json['id_wajah'],
      nisn: json['nisn'],
      name: json['name'],
      gambar: json['gambar'],
      faceFeatures: json["faceFeatures"] != null
          ? FaceFeatures.fromJson(json["faceFeatures"])
          : null,
      faceEmbeddings: _parseEmbeddings(json['faceEmbeddings']),
      registeredOn: json['registeredOn'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_wajah': idWajah,
      'nisn': nisn,
      'name': name,
      'gambar': gambar,
      'faceFeatures': faceFeatures?.toJson() ?? {},
      'faceEmbeddings': faceEmbeddings,
      'registeredOn': registeredOn,
    };
  }
}
