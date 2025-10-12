/// Constantes de seguridad para Orzion Mesh
class SecurityConstants {
  // Límites de mensajes
  static const int maxMessageLength = 10000; // 10KB máximo por mensaje
  static const int minMessageLength = 1;
  static const int maxTTL = 10; // Máximo 10 saltos
  static const int defaultTTL = 5;
  
  // Rate limiting
  static const int maxMessagesPerMinute = 30;
  static const int maxMessagesPerHour = 500;
  static const Duration rateLimitWindow = Duration(minutes: 1);
  
  // Detección de duplicados
  static const Duration duplicateDetectionWindow = Duration(minutes: 30);
  static const int maxDuplicateCache = 1000;
  
  // Blacklist
  static const int maxBlacklistSize = 100;
  static const Duration blacklistDuration = Duration(hours: 24);
  static const int suspiciousActivityThreshold = 10; // Acciones sospechosas antes de blacklist
  
  // Encriptación
  static const int minKeyLength = 32;
  static const int ivLength = 16;
  
  // Validación de nodos
  static const int maxNodeIdLength = 128;
  static const int minNodeIdLength = 8;
  
  // Timeouts
  static const Duration messageTimeout = Duration(minutes: 5);
  static const Duration ackTimeout = Duration(seconds: 30);
  
  // Limpieza automática
  static const Duration messageRetentionPeriod = Duration(days: 30);
  static const Duration neighborInactivityPeriod = Duration(hours: 24);
  
  // Validación GPS
  static const double maxLatitude = 90.0;
  static const double minLatitude = -90.0;
  static const double maxLongitude = 180.0;
  static const double minLongitude = -180.0;
}

/// Tipos de eventos de seguridad
enum SecurityEventType {
  rateLimitExceeded,
  invalidMessage,
  duplicateMessage,
  blacklistedNode,
  encryptionFailure,
  invalidTTL,
  messageTooBig,
  suspiciousActivity,
}

/// Evento de seguridad
class SecurityEvent {
  final SecurityEventType type;
  final String nodeId;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  SecurityEvent({
    required this.type,
    required this.nodeId,
    required this.description,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.toString(),
        'nodeId': nodeId,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };
}
