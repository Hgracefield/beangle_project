import 'package:latlong2/latlong.dart';
class CycleStation {
  const CycleStation({
    required this.id,
    required this.name,
    required this.rackCount,
    required this.parkingCount,
    required this.location,
  });

  final String id;
  final String name;
  final int rackCount;
  final int parkingCount;
  final LatLng location;
}