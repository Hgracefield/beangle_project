class WorkRecord {
  const WorkRecord({
    this.workId,
    required this.workerId,
    required this.stationId,
    required this.count,
    required this.worktime
  });

  final int? workId;
  final int workerId;
  final int stationId;
  final int count;
  final DateTime worktime;

  factory WorkRecord.fromJson(Map<String, dynamic> json) {
    final String rawTime = json['time']?.toString() ?? '';
    return WorkRecord(
      workId: int.tryParse(json['work_id']?.toString() ?? ''),
      workerId: int.tryParse(json['worker_id']?.toString() ?? '') ?? 0,
      stationId: int.tryParse(json['station_id']?.toString() ?? '') ?? 0,
      count: int.tryParse(json['count']?.toString() ?? '') ?? 0,
      worktime: DateTime.tryParse(rawTime) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'work_id': workId ?? 0,
      'worker_id': workerId,
      'station_id': stationId,
      'count': count,
      'worktime': worktime.toString(),
    };
  }
}
