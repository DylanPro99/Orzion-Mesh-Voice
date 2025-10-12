import 'package:hive/hive.dart';

part 'stored_message.g.dart';

@HiveType(typeId: 0)
class StoredMessage extends HiveObject {
  @HiveField(0)
  final String messageId;

  @HiveField(1)
  final String senderId;

  @HiveField(2)
  final String destinationId;

  @HiveField(3)
  final String encryptedContent;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final int hopCount;

  @HiveField(6)
  final MessageStatus status;

  @HiveField(7)
  final bool isOutgoing;

  @HiveField(8)
  final String? decryptedContent;

  StoredMessage({
    required this.messageId,
    required this.senderId,
    required this.destinationId,
    required this.encryptedContent,
    required this.timestamp,
    required this.hopCount,
    required this.status,
    required this.isOutgoing,
    this.decryptedContent,
  });

  StoredMessage copyWith({
    MessageStatus? status,
    String? decryptedContent,
  }) {
    return StoredMessage(
      messageId: messageId,
      senderId: senderId,
      destinationId: destinationId,
      encryptedContent: encryptedContent,
      timestamp: timestamp,
      hopCount: hopCount,
      status: status ?? this.status,
      isOutgoing: isOutgoing,
      decryptedContent: decryptedContent ?? this.decryptedContent,
    );
  }
}

@HiveType(typeId: 1)
enum MessageStatus {
  @HiveField(0)
  sending, // Enviando
  
  @HiveField(1)
  sent, // Enviado (pero no confirmado)
  
  @HiveField(2)
  delivered, // Entregado (confirmación recibida)
  
  @HiveField(3)
  read, // Leído por el destinatario
  
  @HiveField(4)
  received, // Recibido (para mensajes entrantes)
  
  @HiveField(5)
  failed, // Falló el envío
}
