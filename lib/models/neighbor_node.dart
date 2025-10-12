import 'package:hive/hive.dart';

part 'neighbor_node.g.dart';

@HiveType(typeId: 2)
class NeighborNode extends HiveObject {
  @HiveField(0)
  final String nodeId;

  @HiveField(1)
  final String? nodeName;

  @HiveField(2)
  final int lastRssi;

  @HiveField(3)
  final DateTime lastSeen;

  @HiveField(4)
  final double? latitude;

  @HiveField(5)
  final double? longitude;

  @HiveField(6)
  final int successfulRelays;

  @HiveField(7)
  final int failedRelays;

  @HiveField(8)
  final DateTime firstSeen;

  @HiveField(9)
  final int batteryLevel;

  NeighborNode({
    required this.nodeId,
    this.nodeName,
    required this.lastRssi,
    required this.lastSeen,
    this.latitude,
    this.longitude,
    this.successfulRelays = 0,
    this.failedRelays = 0,
    DateTime? firstSeen,
    this.batteryLevel = 100,
  }) : firstSeen = firstSeen ?? DateTime.now();

  NeighborNode copyWith({
    String? nodeName,
    int? lastRssi,
    DateTime? lastSeen,
    double? latitude,
    double? longitude,
    int? successfulRelays,
    int? failedRelays,
    int? batteryLevel,
  }) {
    return NeighborNode(
      nodeId: nodeId,
      nodeName: nodeName ?? this.nodeName,
      lastRssi: lastRssi ?? this.lastRssi,
      lastSeen: lastSeen ?? this.lastSeen,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      successfulRelays: successfulRelays ?? this.successfulRelays,
      failedRelays: failedRelays ?? this.failedRelays,
      firstSeen: firstSeen,
      batteryLevel: batteryLevel ?? this.batteryLevel,
    );
  }

  double get reliabilityScore {
    final total = successfulRelays + failedRelays;
    if (total == 0) return 0.5; // Neutral para nodos nuevos
    return successfulRelays / total;
  }

  bool get isReliable => reliabilityScore > 0.7;

  int get signalStrength {
    if (lastRssi > -60) return 4; // Excelente
    if (lastRssi > -70) return 3; // Bueno
    if (lastRssi > -80) return 2; // Regular
    if (lastRssi > -90) return 1; // Pobre
    return 0; // Muy pobre
  }

  Duration get timeSinceLastSeen => DateTime.now().difference(lastSeen);

  bool get isActive => timeSinceLastSeen.inMinutes < 5;
}
