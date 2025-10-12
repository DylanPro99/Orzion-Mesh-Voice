import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _secureStorage = const FlutterSecureStorage();
  static const String _keyStorageKey = 'mesh_encryption_key';
  
  String? _cachedKey;

  /// Obtener o generar la clave de cifrado
  Future<String> getOrCreateEncryptionKey() async {
    // Usar caché en memoria si está disponible
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    try {
      // Intentar leer clave almacenada
      String? storedKey = await _secureStorage.read(key: _keyStorageKey);
      
      if (storedKey != null && storedKey.isNotEmpty) {
        _cachedKey = storedKey;
        return storedKey;
      }

      // Generar nueva clave si no existe
      final newKey = _generateSecureKey();
      await _secureStorage.write(key: _keyStorageKey, value: newKey);
      _cachedKey = newKey;
      
      return newKey;
    } catch (e) {
      // Fallback a clave basada en ID de dispositivo si SecureStorage falla
      // Esto no es ideal pero es mejor que una clave hardcodeada
      final deviceKey = _generateDeviceBasedKey();
      _cachedKey = deviceKey;
      return deviceKey;
    }
  }

  /// Generar clave criptográficamente segura de 32 caracteres
  String _generateSecureKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).substring(0, 32);
  }

  /// Generar clave basada en características del dispositivo (fallback)
  String _generateDeviceBasedKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = Random().nextInt(999999).toString().padLeft(6, '0');
    final combined = '$timestamp-$randomPart-orzion-mesh';
    final hash = sha256.convert(utf8.encode(combined)).toString();
    return hash.substring(0, 32);
  }

  /// Limpiar clave de la caché (útil para cerrar sesión)
  void clearCachedKey() {
    _cachedKey = null;
  }

  /// Regenerar clave completamente
  Future<String> regenerateKey() async {
    await _secureStorage.delete(key: _keyStorageKey);
    _cachedKey = null;
    return await getOrCreateEncryptionKey();
  }
}
