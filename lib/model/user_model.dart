import 'package:cloud_firestore/cloud_firestore.dart';

import 'face_features.dart';

class UserModel {
  String? idWajah; // Changed from 'id' to 'idWajah'
  String? nisn; // Added NISN as foreign key from siswa collection
  String? name;
  String? image;
  FaceFeatures? faceFeatures;
  Timestamp? registeredOn;

  UserModel({
    this.idWajah,
    this.nisn,
    this.name,
    this.image,
    this.faceFeatures,
    this.registeredOn,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      idWajah: json['id_wajah'],
      nisn: json['nisn'],
      name: json['name'],
      image: json['image'],
      faceFeatures: json["faceFeatures"] != null
          ? FaceFeatures.fromJson(json["faceFeatures"])
          : null,
      registeredOn: json['registeredOn'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_wajah': idWajah,
      'nisn': nisn,
      'name': name,
      'image': image,
      'faceFeatures': faceFeatures?.toJson() ?? {},
      'registeredOn': registeredOn,
    };
  }
}
