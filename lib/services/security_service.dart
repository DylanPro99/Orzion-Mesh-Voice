import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final Random _random = Random.secure();

  /// Genera un hash seguro para validación de integridad
  String generateSecureHash(String data) {
    try {
      final bytes = utf8.encode(data);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      if (kDebugMode) {
        print('[SECURITY] ❌ Error generando hash: $e');
      }
      return '';
    }
  }

  /// Genera bytes aleatorios seguros
  List<int> generateSecureBytes(int length) {
    try {
      final bytes = <int>[];
      for (int i = 0; i < length; i++) {
        bytes.add(_random.nextInt(256));
      }
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        print('[SECURITY] ❌ Error generando bytes aleatorios: $e');
      }
      return List.filled(length, 0);
    }
  }

  /// Genera un ID único seguro
  String generateSecureId() {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomBytes = generateSecureBytes(16);
      final combined = '$timestamp${randomBytes.join()}';
      final hash = generateSecureHash(combined);
      return hash.substring(0, 32);
    } catch (e) {
      if (kDebugMode) {
        print('[SECURITY] ❌ Error generando ID seguro: $e');
      }
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Valida la integridad de un mensaje
  bool validateMessageIntegrity(String message, String expectedHash) {
    try {
      final calculatedHash = generateSecureHash(message);
      return calculatedHash == expectedHash;
    } catch (e) {
      if (kDebugMode) {
        print('[SECURITY] ❌ Error validando integridad: $e');
      }
      return false;
    }
  }

  /// Genera un nonce único para prevenir ataques de repetición
  String generateNonce() {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = _random.nextInt(1000000);
      final combined = '$timestamp$random';
      return generateSecureHash(combined).substring(0, 16);
    } catch (e) {
      if (kDebugMode) {
        print('[SECURITY] ❌ Error generando nonce: $e');
      }
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Verifica si una clave cumple con los requisitos de seguridad
  bool validateKeyStrength(String key) {
    try {
      if (key.length < 32) return false;
      
      // Verificar diversidad de caracteres
      final uniqueChars = key.split('').toSet().length;
      if (uniqueChars < 16) return false;
      
      // Verificar que no sea una secuencia simple
      if (_isSimpleSequence(key)) return false;
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[SECURITY] ❌ Error validando fuerza de clave: $e');
      }
      return false;
    }
  }

  /// Detecta si una clave es una secuencia simple
  bool _isSimpleSequence(String key) {
    try {
      // Detectar patrones simples como "1234567890" o "abcdefghij"
      final asciiValues = key.codeUnits;
      
      // Verificar secuencia ascendente
      int ascendingCount = 0;
      int descendingCount = 0;
      
      for (int i = 1; i < asciiValues.length; i++) {
        if (asciiValues[i] == asciiValues[i - 1] + 1) {
          ascendingCount++;
        } else if (asciiValues[i] == asciiValues[i - 1] - 1) {
          descendingCount++;
        }
      }
      
      // Si más del 50% de los caracteres están en secuencia, es sospechoso
      final sequenceRatio = (ascendingCount + descendingCount) / asciiValues.length;
      return sequenceRatio > 0.5;
    } catch (e) {
      return false;
    }
  }

  /// Limpia datos sensibles de la memoria
  void secureWipe(List<int> data) {
    try {
      for (int i = 0; i < data.length; i++) {
        data[i] = _random.nextInt(256);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SECURITY] ❌ Error en limpieza segura: $e');
      }
    }
  }

  /// Genera un timestamp seguro con jitter para prevenir timing attacks
  DateTime generateSecureTimestamp() {
    try {
      final now = DateTime.now();
      final jitter = _random.nextInt(1000); // 0-999ms de jitter
      return now.add(Duration(milliseconds: jitter));
    } catch (e) {
      if (kDebugMode) {
        print('[SECURITY] ❌ Error generando timestamp seguro: $e');
      }
      return DateTime.now();
    }
  }
}