class ReservationInfo {
  // Property
  // final String dateText;
  // final String timeText;
  // final String stationCode;

  // final String imagePath;
  final int? reservation_id;
  final int user_id;
  final int station_id;
  final DateTime time;
  final int is_cancel;
  final String? imagePath;

  // Constructor
  ReservationInfo({
    //
    this.reservation_id,
    required this.user_id,
    required this.station_id,
    required this.time,
    required this.is_cancel,
    this.imagePath,
  });
  //

  factory ReservationInfo.fromJson(Map<String, dynamic> json) {
    final String rawTime = json['time']?.toString() ?? '';
    return ReservationInfo(
      //
      reservation_id: json['reservation_id'] as int? ?? 0,
      user_id: json['user_id'] as int? ?? 0,
      station_id: json['station_id'] as int? ?? 0,
      time: DateTime.tryParse(rawTime) ?? DateTime.now(),
      is_cancel: json['is_cancel'] as int? ?? 0,
      // notice: json['notice'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? 'images/beangle_back.png',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      //
      'reservation_id': reservation_id,
      'user_id': user_id,
      'station_id': station_id,
      'time': time.toIso8601String(),
      'is_cancel': is_cancel,
      // 'notice': notice,
      //'imagePath': imagePath,
    };
  }

  factory ReservationInfo.empty() {
    return ReservationInfo(
      //
      reservation_id: 0,
      user_id: 0,
      station_id: 0,
      time: DateTime.now(),
      is_cancel: 0,
      imagePath: 'images/beangle_back.png',
    );
  }
}
