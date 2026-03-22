class ReservationInfo {
  const ReservationInfo({
    required this.dateText,
    required this.timeText,
    required this.stationCode,
    required this.notice,
    required this.imagePath,
  });

  final String dateText;
  final String timeText;
  final String stationCode;
  final String notice;
  final String imagePath;

  factory ReservationInfo.fromJson(Map<String, dynamic> json) {
    return ReservationInfo(
      dateText: json['dateText'] as String? ?? '',
      timeText: json['timeText'] as String? ?? '',
      stationCode: json['stationCode'] as String? ?? '',
      notice: json['notice'] as String? ?? '',
      imagePath:
          json['imagePath'] as String? ?? 'images/beangle_back.png',
    );
  }

  factory ReservationInfo.empty() {
    return const ReservationInfo(
      dateText: '',
      timeText: '',
      stationCode: '',
      notice: '',
      imagePath: 'images/beangle_back.png',
    );
  }
}
