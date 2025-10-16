import 'package:flutter/foundation.dart';

class ValidationUtility {
  /// Valida si un Node ID tiene el formato correcto
  static bool isValidNodeId(String nodeId) {
    if (nodeId.isEmpty) return false;
    
    // Node ID debe tener al menos 8 caracteres y máximo 64
    if (nodeId.length < 8 || nodeId.length > 64) return false;
    
    // Solo permitir caracteres alfanuméricos
    final alphanumericRegex = RegExp(r'^[a-zA-Z0-9]+$');
    return alphanumericRegex.hasMatch(nodeId);
  }

  /// Valida si un alias de contacto es válido
  static bool isValidContactAlias(String alias) {
    if (alias.isEmpty) return false;
    
    // Alias debe tener entre 1 y 32 caracteres
    if (alias.length > 32) return false;
    
    // No permitir solo espacios
    if (alias.trim().isEmpty) return false;
    
    return true;
  }

  /// Valida si un mensaje tiene contenido válido
  static bool isValidMessage(String message) {
    if (message.isEmpty) return false;
    
    // Mensaje no puede ser solo espacios
    if (message.trim().isEmpty) return false;
    
    // Mensaje no puede ser demasiado largo (máximo 1000 caracteres)
    if (message.length > 1000) return false;
    
    return true;
  }

  /// Valida si un TTL es válido
  static bool isValidTTL(int ttl) {
    return ttl > 0 && ttl <= 15;
  }

  /// Sanitiza un string para uso seguro
  static String sanitizeString(String input) {
    if (input.isEmpty) return '';
    
    // Remover caracteres de control y caracteres especiales peligrosos
    final sanitized = input.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '');
    
    // Limitar longitud
    return sanitized.length > 1000 ? sanitized.substring(0, 1000) : sanitized;
  }

  /// Valida si una coordenada GPS es válida
  static bool isValidGPSCoordinate(double coordinate, bool isLatitude) {
    if (isLatitude) {
      return coordinate >= -90.0 && coordinate <= 90.0;
    } else {
      return coordinate >= -180.0 && coordinate <= 180.0;
    }
  }

  /// Valida si un RSSI es válido
  static bool isValidRSSI(int rssi) {
    // RSSI típicamente va de -100 dBm a 0 dBm
    return rssi >= -100 && rssi <= 0;
  }

  /// Valida si un nivel de batería es válido
  static bool isValidBatteryLevel(int batteryLevel) {
    return batteryLevel >= 0 && batteryLevel <= 100;
  }

  /// Valida formato de UUID
  static bool isValidUUID(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }

  /// Valida si una clave de cifrado es segura
  static bool isSecureEncryptionKey(String key) {
    if (key.length < 32) return false;
    
    // Verificar diversidad de caracteres
    final uniqueChars = key.split('').toSet().length;
    if (uniqueChars < 16) return false;
    
    // No permitir secuencias simples
    if (_hasSimplePattern(key)) return false;
    
    return true;
  }

  /// Detecta patrones simples en una clave
  static bool _hasSimplePattern(String key) {
    // Detectar repeticiones excesivas
    final chars = key.split('');
    final charCounts = <String, int>{};
    
    for (final char in chars) {
      charCounts[char] = (charCounts[char] ?? 0) + 1;
    }
    
    // Si algún carácter aparece en más del 30% de la clave, es sospechoso
    final maxCount = charCounts.values.reduce((a, b) => a > b ? a : b);
    return maxCount > key.length * 0.3;
  }

  /// Valida si un timestamp es razonable
  static bool isValidTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp).abs();
    
    // El timestamp no puede ser más de 1 año en el pasado o futuro
    return diff.inDays <= 365;
  }

  /// Valida si un mensaje JSON es válido
  static bool isValidMessageJSON(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      
      // Verificar campos requeridos
      if (decoded is! Map<String, dynamic>) return false;
      
      final requiredFields = ['messageId', 'senderId', 'destinationId', 'encryptedContent', 'ttl'];
      
      for (final field in requiredFields) {
        if (!decoded.containsKey(field)) return false;
      }
      
      // Validar tipos
      if (decoded['messageId'] is! String) return false;
      if (decoded['senderId'] is! String) return false;
      if (decoded['destinationId'] is! String) return false;
      if (decoded['encryptedContent'] is! String) return false;
      if (decoded['ttl'] is! int) return false;
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[VALIDATION] ❌ JSON inválido: $e');
      }
      return false;
    }
  }
}