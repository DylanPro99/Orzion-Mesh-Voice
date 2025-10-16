import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../config/security_constants.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static FlutterSecureStorage? _storage;
  
  static const String _keyName = 'orzion_mesh_encryption_key';

  Future<String> getOrCreateEncryptionKey() async {
    try {
      if (kDebugMode) {
        print('[ENCRYPTION] 🔐 Obteniendo o creando clave de cifrado...');
      }

      // Inicializar storage de forma segura
      _storage ??= const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

      // Intentar obtener clave existente
      final existingKey = await _storage!.read(key: _keyName);
      
      if (existingKey != null && existingKey.length >= SecurityConstants.minKeyLength) {
        if (kDebugMode) {
          print('[ENCRYPTION] ✅ Clave existente encontrada (${existingKey.length} caracteres)');
        }
        return existingKey;
      }

      // Generar nueva clave si no existe o es muy corta
      if (kDebugMode) {
        print('[ENCRYPTION] 🔑 Generando nueva clave de cifrado...');
      }

      final newKey = _generateSecureKey();
      
      // Guardar nueva clave
      await _storage!.write(key: _keyName, value: newKey);
      
      if (kDebugMode) {
        print('[ENCRYPTION] ✅ Nueva clave generada y guardada (${newKey.length} caracteres)');
      }
      
      return newKey;
    } catch (e) {
      if (kDebugMode) {
        print('[ENCRYPTION] ❌ Error obteniendo/creando clave: $e');
      }
      
      // Fallback: generar clave temporal (menos segura pero funcional)
      final fallbackKey = _generateFallbackKey();
      if (kDebugMode) {
        print('[ENCRYPTION] ⚠️ Usando clave de respaldo temporal');
      }
      
      return fallbackKey;
    }
  }

  String _generateSecureKey() {
    // Generar múltiples UUIDs y concatenarlos para crear una clave larga
    const uuid = Uuid();
    final parts = <String>[];
    
    // Generar 8 UUIDs (cada uno ~36 caracteres) = ~288 caracteres total
    for (int i = 0; i < 8; i++) {
      parts.add(uuid.v4());
    }
    
    // Concatenar y limpiar guiones
    final key = parts.join().replaceAll('-', '');
    
    // Asegurar longitud mínima
    if (key.length < SecurityConstants.minKeyLength) {
      return key + _generateRandomString(SecurityConstants.minKeyLength - key.length);
    }
    
    return key;
  }

  String _generateFallbackKey() {
    // Clave de respaldo más simple pero aún segura
    const uuid = Uuid();
    final key = uuid.v4() + uuid.v4() + uuid.v4() + uuid.v4();
    return key.replaceAll('-', '');
  }

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    
    for (int i = 0; i < length; i++) {
      buffer.write(chars[(random + i) % chars.length]);
    }
    
    return buffer.toString();
  }

  Future<void> deleteEncryptionKey() async {
    try {
      if (_storage != null) {
        await _storage!.delete(key: _keyName);
        if (kDebugMode) {
          print('[ENCRYPTION] 🗑️ Clave de cifrado eliminada');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ENCRYPTION] ❌ Error eliminando clave: $e');
      }
    }
  }

  Future<bool> hasEncryptionKey() async {
    try {
      if (_storage != null) {
        final key = await _storage!.read(key: _keyName);
        return key != null && key.length >= SecurityConstants.minKeyLength;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[ENCRYPTION] ❌ Error verificando clave: $e');
      }
      return false;
    }
  }
}