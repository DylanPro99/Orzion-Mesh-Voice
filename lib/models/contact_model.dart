import 'package:hive/hive.dart';

part 'contact_model.g.dart';

@HiveType(typeId: 3)
class ContactModel extends HiveObject {
  @HiveField(0)
  final String nodeId;

  @HiveField(1)
  final String alias;

  @HiveField(2)
  final DateTime addedAt;

  @HiveField(3)
  final DateTime? lastSeen;

  @HiveField(4)
  final int messageCount;

  ContactModel({
    required this.nodeId,
    required this.alias,
    required this.addedAt,
    this.lastSeen,
    this.messageCount = 0,
  });

  ContactModel copyWith({
    String? alias,
    DateTime? lastSeen,
    int? messageCount,
  }) {
    return ContactModel(
      nodeId: nodeId,
      alias: alias ?? this.alias,
      addedAt: addedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Duration get timeSinceLastSeen {
    if (lastSeen == null) return const Duration(days: 999);
    return DateTime.now().difference(lastSeen!);
  }

  bool get isActive => timeSinceLastSeen.inHours < 24;
}