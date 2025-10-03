class AttendanceSettings {
  String? id;
  String? jamMulai; // Format: "06:30"
  String? jamSelesai; // Format: "13:55"
  bool? aktif;

  AttendanceSettings({
    this.id,
    this.jamMulai,
    this.jamSelesai,
    this.aktif,
  });

  factory AttendanceSettings.fromJson(Map<String, dynamic> json) {
    return AttendanceSettings(
      id: json['id'],
      jamMulai: json['jam_mulai'] ?? '06:30',
      jamSelesai: json['jam_selesai'] ?? '13:55',
      aktif: json['aktif'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'aktif': aktif,
    };
  }
}
