
class ContactModel {
  final String nodeId;
  final String alias;
  final DateTime addedAt;

  ContactModel({
    required this.nodeId,
    required this.alias,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'alias': alias,
        'addedAt': addedAt.toIso8601String(),
      };

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
        nodeId: json['nodeId'],
        alias: json['alias'],
        addedAt: DateTime.parse(json['addedAt']),
      );
}
