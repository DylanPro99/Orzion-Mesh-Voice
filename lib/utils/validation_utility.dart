import '../config/security_constants.dart';

/// Excepción personalizada para errores de validación
class ValidationException implements Exception {
  final String message;
  
  ValidationException(this.message);
  
  @override
  String toString() => 'ValidationException: $message';
}

/// Utilidad estática para validación de datos en Orzion Mesh
/// Provee métodos de validación y sanitización para asegurar integridad de datos
class ValidationUtility {
  ValidationUtility._();

  /// Valida el contenido de un mensaje
  /// Lanza [ValidationException] si el contenido es inválido
  /// 
  /// Reglas:
  /// - Longitud mínima: [SecurityConstants.minMessageLength]
  /// - Longitud máxima: [SecurityConstants.maxMessageLength]
  /// 
  /// TODO: Añadir test para contenido vacío
  /// TODO: Añadir test para mensajes muy largos
  static bool validateMessageContent(String content) {
    if (content.isEmpty) {
      throw ValidationException(
        'El contenido del mensaje no puede estar vacío'
      );
    }

    if (content.length < SecurityConstants.minMessageLength) {
      throw ValidationException(
        'El mensaje es demasiado corto. Mínimo: ${SecurityConstants.minMessageLength} caracteres'
      );
    }

    if (content.length > SecurityConstants.maxMessageLength) {
      throw ValidationException(
        'El mensaje excede el tamaño máximo permitido. '
        'Máximo: ${SecurityConstants.maxMessageLength} caracteres, '
        'Actual: ${content.length} caracteres'
      );
    }

    return true;
  }

  /// Valida el TTL (Time To Live) de un mensaje
  /// Lanza [ValidationException] si el TTL es inválido
  /// 
  /// Reglas:
  /// - Debe ser mayor o igual a 1
  /// - Debe ser menor o igual a [SecurityConstants.maxTTL]
  /// 
  /// TODO: Añadir test para TTL = 0
  /// TODO: Añadir test para TTL negativo
  /// TODO: Añadir test para TTL > maxTTL
  static bool validateTTL(int ttl) {
    if (ttl < 1) {
      throw ValidationException(
        'El TTL debe ser al menos 1. Valor recibido: $ttl'
      );
    }

    if (ttl > SecurityConstants.maxTTL) {
      throw ValidationException(
        'El TTL excede el máximo permitido. '
        'Máximo: ${SecurityConstants.maxTTL}, '
        'Valor recibido: $ttl'
      );
    }

    return true;
  }

  /// Valida el ID de un nodo
  /// Lanza [ValidationException] si el nodeId es inválido
  /// 
  /// Reglas:
  /// - No puede estar vacío
  /// - Longitud mínima: [SecurityConstants.minNodeIdLength]
  /// - Longitud máxima: [SecurityConstants.maxNodeIdLength]
  /// - Solo caracteres alfanuméricos y guiones
  /// 
  /// TODO: Añadir test para nodeId vacío
  /// TODO: Añadir test para nodeId con caracteres especiales
  /// TODO: Añadir test para longitud inválida
  static bool validateNodeId(String nodeId) {
    if (nodeId.isEmpty) {
      throw ValidationException(
        'El ID del nodo no puede estar vacío'
      );
    }

    if (nodeId.length < SecurityConstants.minNodeIdLength) {
      throw ValidationException(
        'El ID del nodo es demasiado corto. '
        'Mínimo: ${SecurityConstants.minNodeIdLength} caracteres, '
        'Actual: ${nodeId.length} caracteres'
      );
    }

    if (nodeId.length > SecurityConstants.maxNodeIdLength) {
      throw ValidationException(
        'El ID del nodo excede el tamaño máximo. '
        'Máximo: ${SecurityConstants.maxNodeIdLength} caracteres, '
        'Actual: ${nodeId.length} caracteres'
      );
    }

    // Validar que solo contenga caracteres seguros (alfanuméricos y guiones)
    final validPattern = RegExp(r'^[a-zA-Z0-9\-_]+$');
    if (!validPattern.hasMatch(nodeId)) {
      throw ValidationException(
        'El ID del nodo contiene caracteres inválidos. '
        'Solo se permiten letras, números, guiones y guiones bajos'
      );
    }

    return true;
  }

  /// Valida coordenadas GPS
  /// Lanza [ValidationException] si las coordenadas son inválidas
  /// 
  /// Reglas:
  /// - Latitud: entre -90 y 90 grados
  /// - Longitud: entre -180 y 180 grados
  /// - null es válido (ubicación no disponible)
  /// 
  /// TODO: Añadir test para coordenadas válidas
  /// TODO: Añadir test para latitud fuera de rango
  /// TODO: Añadir test para longitud fuera de rango
  /// TODO: Añadir test para valores null
  static bool validateGPS(double? latitude, double? longitude) {
    // null es válido (ubicación no disponible)
    if (latitude == null && longitude == null) {
      return true;
    }

    // Si uno está presente, ambos deben estarlo
    if (latitude == null || longitude == null) {
      throw ValidationException(
        'Si se proporciona una coordenada GPS, ambas (latitud y longitud) deben estar presentes'
      );
    }

    // Validar rango de latitud
    if (latitude < SecurityConstants.minLatitude || 
        latitude > SecurityConstants.maxLatitude) {
      throw ValidationException(
        'Latitud fuera de rango. '
        'Debe estar entre ${SecurityConstants.minLatitude} y ${SecurityConstants.maxLatitude}. '
        'Valor recibido: $latitude'
      );
    }

    // Validar rango de longitud
    if (longitude < SecurityConstants.minLongitude || 
        longitude > SecurityConstants.maxLongitude) {
      throw ValidationException(
        'Longitud fuera de rango. '
        'Debe estar entre ${SecurityConstants.minLongitude} y ${SecurityConstants.maxLongitude}. '
        'Valor recibido: $longitude'
      );
    }

    return true;
  }

  /// Sanitiza un string eliminando caracteres peligrosos
  /// 
  /// Elimina:
  /// - Caracteres de control
  /// - Scripts potencialmente maliciosos
  /// - Null bytes
  /// - Caracteres no imprimibles
  /// 
  /// Retorna el string limpio
  /// 
  /// TODO: Añadir test para strings con caracteres de control
  /// TODO: Añadir test para strings con null bytes
  /// TODO: Añadir test para strings limpios (sin cambios)
  static String sanitizeString(String input) {
    if (input.isEmpty) {
      return input;
    }

    // Eliminar caracteres de control (excepto saltos de línea y tabs normales)
    String sanitized = input.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');
    
    // Eliminar null bytes
    sanitized = sanitized.replaceAll('\u0000', '');
    
    // Eliminar etiquetas de script obvias (básico)
    sanitized = sanitized.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '');
    
    // Eliminar intentos de inyección SQL básicos
    sanitized = sanitized.replaceAll(RegExp(r'(\b(DROP|DELETE|INSERT|UPDATE|SELECT)\b.*\b(TABLE|FROM|WHERE)\b)', caseSensitive: false), '');
    
    return sanitized;
  }

  /// Valida múltiples campos a la vez para un mensaje completo
  /// Lanza [ValidationException] al primer campo inválido
  /// 
  /// TODO: Añadir test para validación completa de mensaje
  static bool validateMessage({
    required String content,
    required int ttl,
    required String senderId,
    required String destinationId,
    double? latitude,
    double? longitude,
  }) {
    validateMessageContent(content);
    validateTTL(ttl);
    validateNodeId(senderId);
    validateNodeId(destinationId);
    validateGPS(latitude, longitude);
    
    return true;
  }
}
