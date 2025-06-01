import 'package:cloud_firestore/cloud_firestore.dart';

import 'face_features.dart';

class UserModel {
  String? idWajah; // Changed from 'id' to 'idWajah'
  String? nisn; // Added NISN as foreign key from siswa collection
  String? name;
  String? gambar;
  FaceFeatures? faceFeatures;
  Timestamp? registeredOn;
  String? kelas_sw; // Added kelas_sw field

  UserModel({
    this.idWajah,
    this.nisn,
    this.name,
    this.gambar,
    this.faceFeatures,
    this.registeredOn,
    this.kelas_sw,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      idWajah: json['id_wajah'],
      nisn: json['nisn'],
      name: json['name'],
      gambar: json['gambar'],
      faceFeatures: json["faceFeatures"] != null
          ? FaceFeatures.fromJson(json["faceFeatures"])
          : null,
      registeredOn: json['registeredOn'],
      kelas_sw: json['kelas_sw'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_wajah': idWajah,
      'nisn': nisn,
      'name': name,
      'gambar': gambar,
      'faceFeatures': faceFeatures?.toJson() ?? {},
      'registeredOn': registeredOn,
      'kelas_sw': kelas_sw,
    };
  }
}
