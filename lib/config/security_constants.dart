/// Constantes de seguridad para el sistema de cifrado
class SecurityConstants {
  /// Longitud mínima requerida para claves de cifrado
  /// Esta es una política de seguridad estricta para prevenir ataques de fuerza bruta
  static const int minKeyLength = 32;
  
  /// Longitud máxima de claves de cifrado
  static const int maxKeyLength = 256;
  
  /// Tamaño del IV (Initialization Vector) para AES
  static const int ivSize = 16;
  
  /// Tamaño de la clave AES-256
  static const int aesKeySize = 32;
  
  /// Tamaño del HMAC
  static const int hmacSize = 32;
  
  /// Tiempo máximo de vida para mensajes (TTL)
  static const int maxTTL = 15;
  
  /// TTL por defecto para nuevos mensajes
  static const int defaultTTL = 10;
  
  /// Tamaño máximo de mensaje en bytes
  static const int maxMessageSize = 512;
  
  /// Número máximo de saltos permitidos
  static const int maxHops = 10;
  
  /// Tiempo de expiración para mensajes procesados (en horas)
  static const int messageExpirationHours = 24;
  
  /// Algoritmo de hash usado para derivación de claves
  static const String hashAlgorithm = 'SHA-256';
  
  /// Algoritmo de cifrado simétrico
  static const String encryptionAlgorithm = 'AES-256-CBC';
  
  /// Algoritmo de MAC (Message Authentication Code)
  static const String macAlgorithm = 'HMAC-SHA256';
}