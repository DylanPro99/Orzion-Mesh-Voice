import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class HopData {
  final String nodeId;
  final DateTime timestamp;
  final Map<String, double>? gpsCoords;

  HopData({
    required this.nodeId,
    required this.timestamp,
    this.gpsCoords,
  });

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'timestamp': timestamp.toIso8601String(),
        'gpsCoords': gpsCoords,
      };

  factory HopData.fromJson(Map<String, dynamic> json) => HopData(
        nodeId: json['nodeId'],
        timestamp: DateTime.parse(json['timestamp']),
        gpsCoords: json['gpsCoords'] != null
            ? Map<String, double>.from(json['gpsCoords'])
            : null,
      );
}

class MessageModel {
  final String messageId;
  final String senderId;
  final String destinationId;
  final String encryptedContent;
  final int ttl;
  final List<HopData> hopHistory;
  final DateTime createdAt;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.destinationId,
    required this.encryptedContent,
    required this.ttl,
    required this.hopHistory,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static String encryptMessage(String plainText, String key) {
    final keyBytes = encrypt.Key.fromUtf8(key.padRight(32, '0').substring(0, 32));
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decryptMessage(String encryptedText, String key) {
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) return '';
      
      final keyBytes = encrypt.Key.fromUtf8(key.padRight(32, '0').substring(0, 32));
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (e) {
      return '';
    }
  }

  MessageModel copyWithDecrementedTTL() {
    return MessageModel(
      messageId: messageId,
      senderId: senderId,
      destinationId: destinationId,
      encryptedContent: encryptedContent,
      ttl: ttl - 1,
      hopHistory: hopHistory,
      createdAt: createdAt,
    );
  }

  MessageModel copyWithNewHop(HopData hop) {
    return MessageModel(
      messageId: messageId,
      senderId: senderId,
      destinationId: destinationId,
      encryptedContent: encryptedContent,
      ttl: ttl,
      hopHistory: [...hopHistory, hop],
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'senderId': senderId,
        'destinationId': destinationId,
        'encryptedContent': encryptedContent,
        'ttl': ttl,
        'hopHistory': hopHistory.map((h) => h.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        messageId: json['messageId'],
        senderId: json['senderId'],
        destinationId: json['destinationId'],
        encryptedContent: json['encryptedContent'],
        ttl: json['ttl'],
        hopHistory: (json['hopHistory'] as List)
            .map((h) => HopData.fromJson(h))
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
      );

  String toJsonString() => jsonEncode(toJson());

  factory MessageModel.fromJsonString(String jsonString) =>
      MessageModel.fromJson(jsonDecode(jsonString));
}
