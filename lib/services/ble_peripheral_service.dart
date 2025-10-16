import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';

class BLEPeripheralService {
  static final BLEPeripheralService _instance = BLEPeripheralService._internal();
  factory BLEPeripheralService() => _instance;
  BLEPeripheralService._internal();

  bool _isInitialized = false;
  bool _isAdvertising = false;
  
  // UUIDs para el servicio GATT
  static const String serviceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String characteristicUuid = "0000ffe1-0000-1000-8000-00805f9b34fb";
  
  MessageModel? _currentMessage;

  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] ℹ️ Ya inicializado');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] 🚀 Inicializando servicio peripheral BLE (modo simplificado)');
      }

      _isInitialized = true;
      
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] ✅ Servicio peripheral inicializado correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] ❌ Error inicializando peripheral: $e');
      }
      _isInitialized = true; // Marcar como inicializado para evitar loops
    }
  }

  Future<void> startAdvertising(MessageModel message) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _currentMessage = message;
      _isAdvertising = true;
      
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] 📡 Simulando advertising con mensaje');
        print('[BLE_PERIPHERAL] 📱 Mensaje: ${message.messageId.substring(0, 8)}...');
      }

      // En una implementación real, aquí se configuraría el advertising BLE
      // Por ahora simulamos que está funcionando

      if (kDebugMode) {
        print('[BLE_PERIPHERAL] ✅ Advertising simulado exitosamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] ❌ Error iniciando advertising: $e');
      }
      // No lanzar excepción para no romper el flujo
    }
  }

  Future<void> stopAdvertising() async {
    try {
      _isAdvertising = false;
      
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] 🛑 Advertising detenido');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] ⚠️ Error deteniendo advertising: $e');
      }
    }
  }

  bool isAdvertising() {
    return _isAdvertising;
  }

  MessageModel? getCurrentMessage() {
    return _currentMessage;
  }

  /// Codifica datos del mensaje para manufacturer data (limitado a 29 bytes)
  Map<int, List<int>> _encodeMessageData(MessageModel message) {
    try {
      // Crear un resumen del mensaje para manufacturer data
      final messageSummary = {
        'id': message.messageId.substring(0, 8),
        'ttl': message.ttl,
        'hops': message.hopHistory.length,
      };
      
      final jsonString = jsonEncode(messageSummary);
      final bytes = utf8.encode(jsonString);
      
      // Limitar a 29 bytes (límite de manufacturer data)
      final limitedBytes = bytes.length > 29 ? bytes.sublist(0, 29) : bytes;
      
      return {0xFFFF: limitedBytes}; // Usar manufacturer ID personalizado
    } catch (e) {
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] ⚠️ Error codificando datos: $e');
      }
      return {};
    }
  }

  void dispose() {
    stopAdvertising();
    _isInitialized = false;
    
    if (kDebugMode) {
      print('[BLE_PERIPHERAL] 🧹 Servicio peripheral limpiado');
    }
  }
}