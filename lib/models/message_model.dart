import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../config/security_constants.dart';

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

  /// Deriva claves separadas para AES y HMAC desde una clave base
  /// 
  /// Retorna un Map con:
  /// - 'aes': Clave de 32 bytes para cifrado AES
  /// - 'hmac': Clave de 32 bytes para HMAC
  /// 
  /// Esto previene ataques de reutilización de claves
  static Map<String, String> _deriveKeys(String baseKey) {
    // Derivar clave AES
    final aesHmac = Hmac(sha256, utf8.encode(baseKey));
    final aesDigest = aesHmac.convert(utf8.encode('AES_KEY'));
    final aesKey = aesDigest.toString().substring(0, 32);
    
    // Derivar clave HMAC
    final hmacHmac = Hmac(sha256, utf8.encode(baseKey));
    final hmacDigest = hmacHmac.convert(utf8.encode('HMAC_KEY'));
    final hmacKey = hmacDigest.toString().substring(0, 32);
    
    return {
      'aes': aesKey,
      'hmac': hmacKey,
    };
  }

  /// Genera HMAC-SHA256 para verificación de integridad
  static String _generateHMAC(String data, String key) {
    final hmacKey = utf8.encode(key);
    final hmac = Hmac(sha256, hmacKey);
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  /// Encripta un mensaje con validación de clave y HMAC para integridad
  /// Lanza ArgumentError si la clave es demasiado corta
  /// Retorna formato: iv:encrypted:hmac
  static String encryptMessage(String plainText, String key) {
    // Validar longitud de clave ANTES de cifrar
    if (key.length < SecurityConstants.minKeyLength) {
      throw ArgumentError(
        'La clave de cifrado debe tener al menos ${SecurityConstants.minKeyLength} caracteres. '
        'Longitud actual: ${key.length}. NO use claves cortas, son inseguras.'
      );
    }

    try {
      // Derivar claves separadas para AES y HMAC
      final derivedKeys = _deriveKeys(key);
      final aesKey = derivedKeys['aes']!;
      final hmacKey = derivedKeys['hmac']!;
      
      // Cifrar con clave AES derivada
      final keyBytes = encrypt.Key.fromUtf8(aesKey);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      
      // Generar HMAC con clave HMAC derivada
      final dataToSign = '${iv.base64}:${encrypted.base64}';
      final hmac = _generateHMAC(dataToSign, hmacKey);
      
      return '$dataToSign:$hmac';
    } catch (e) {
      throw Exception('Error al cifrar mensaje: $e');
    }
  }

  /// Desencripta un mensaje validando HMAC e integridad
  /// 
  /// Soporta dos formatos para backward compatibility:
  /// - Formato nuevo (3 partes): iv:encrypted:hmac (verifica HMAC)
  /// - Formato legacy (2 partes): iv:encrypted (sin HMAC, DEPRECADO)
  /// 
  /// NOTA: El formato legacy (2 partes) se deprecará en futuras versiones.
  /// Se recomienda migrar todos los mensajes al formato con HMAC.
  /// 
  /// Lanza ArgumentError si la clave es demasiado corta
  /// Retorna '' si el HMAC no coincide o hay error (mensaje comprometido)
  static String decryptMessage(String encryptedText, String key) {
    try {
      final parts = encryptedText.split(':');
      
      // Detectar formato del mensaje PRIMERO (antes de validar longitud de clave)
      if (parts.length == 3) {
        // Formato NUEVO con HMAC (seguro)
        // Validar longitud de clave para formato nuevo
        if (key.length < SecurityConstants.minKeyLength) {
          throw ArgumentError(
            'La clave de descifrado debe tener al menos ${SecurityConstants.minKeyLength} caracteres. '
            'Longitud actual: ${key.length}. NO use claves cortas, son inseguras.'
          );
        }
        
        // Derivar claves separadas para AES y HMAC
        final derivedKeys = _deriveKeys(key);
        final aesKey = derivedKeys['aes']!;
        final hmacKey = derivedKeys['hmac']!;
        
        final ivBase64 = parts[0];
        final encryptedBase64 = parts[1];
        final receivedHmac = parts[2];
        
        // Verificar HMAC ANTES de descifrar usando clave HMAC derivada
        final dataToVerify = '$ivBase64:$encryptedBase64';
        final calculatedHmac = _generateHMAC(dataToVerify, hmacKey);
        
        if (calculatedHmac != receivedHmac) {
          print('[SECURITY] HMAC inválido. Mensaje comprometido o clave incorrecta.');
          print('[SECURITY] Esperado: $calculatedHmac');
          print('[SECURITY] Recibido: $receivedHmac');
          return '';
        }
        
        // HMAC válido, proceder a descifrar con clave AES derivada
        final keyBytes = encrypt.Key.fromUtf8(aesKey);
        final iv = encrypt.IV.fromBase64(ivBase64);
        final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes));
        
        return encrypter.decrypt64(encryptedBase64, iv: iv);
        
      } else if (parts.length == 2) {
        // Formato LEGACY sin HMAC (inseguro, solo para backward compatibility)
        // NO validar longitud para mensajes legacy (backward compatibility)
        print('[SECURITY WARNING] Mensaje en formato legacy sin HMAC detectado.');
        print('[SECURITY WARNING] Este formato está DEPRECADO y será removido en futuras versiones.');
        print('[SECURITY WARNING] Se recomienda re-encriptar el mensaje con el formato nuevo.');
        
        final ivBase64 = parts[0];
        final encryptedBase64 = parts[1];
        
        // Usar la CLAVE ORIGINAL (padded) para mensajes legacy
        final legacyKey = key.padRight(32, '0').substring(0, 32);
        final keyBytes = encrypt.Key.fromUtf8(legacyKey);
        final iv = encrypt.IV.fromBase64(ivBase64);
        final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes));
        
        return encrypter.decrypt64(encryptedBase64, iv: iv);
        
      } else {
        // Formato inválido
        print('[SECURITY] Formato de mensaje inválido. Esperado 2 o 3 partes, recibido ${parts.length}');
        return '';
      }
    } on ArgumentError {
      // Re-lanzar ArgumentError (problema de política de seguridad, no error de descifrado)
      rethrow;
    } catch (e) {
      // Otros errores (descifrado fallido, formato corrupto, etc.)
      print('[SECURITY] Error al descifrar mensaje: $e');
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
