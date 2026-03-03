class AckMessage {
  final String originalMessageId;
  final String ackType;
  final String senderId;
  final String recipientId;
  final DateTime timestamp;

  AckMessage({
    required this.originalMessageId,
    required this.ackType,
    required this.senderId,
    required this.recipientId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'originalMessageId': originalMessageId,
        'ackType': ackType,
        'senderId': senderId,
        'recipientId': recipientId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AckMessage.fromJson(Map<String, dynamic> json) => AckMessage(
        originalMessageId: json['originalMessageId'],
        ackType: json['ackType'],
        senderId: json['senderId'],
        recipientId: json['recipientId'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}