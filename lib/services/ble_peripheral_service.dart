import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../models/message_model.dart';

class BLEPeripheralService {
  static final BLEPeripheralService _instance = BLEPeripheralService._internal();
  factory BLEPeripheralService() => _instance;
  BLEPeripheralService._internal();

  bool _isInitialized = false;
  bool _isAdvertising = false;
  StreamSubscription? _peripheralStateSubscription;
  
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
        print('[BLE_PERIPHERAL] 🚀 Inicializando servicio peripheral BLE');
      }

      // Verificar si el dispositivo soporta BLE peripheral
      final isSupported = await FlutterBlePeripheral.isSupported;
      if (!isSupported) {
        if (kDebugMode) {
          print('[BLE_PERIPHERAL] ⚠️ BLE Peripheral no soportado en este dispositivo');
        }
        _isInitialized = true;
        return;
      }

      // Monitorear estado del peripheral
      _peripheralStateSubscription = FlutterBlePeripheral.peripheralState.listen((state) {
        if (kDebugMode) {
          print('[BLE_PERIPHERAL] 📡 Estado peripheral: $state');
        }
        
        _isAdvertising = state == PeripheralState.advertising;
      });

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
      
      if (kDebugMode) {
        print('[BLE_PERIPHERAL] 📡 Iniciando advertising con mensaje');
      }

      // Configurar datos de advertising
      final advertisementData = AdvertisementData(
        localName: 'Orzion-${message.senderId.substring(0, 8)}',
        serviceUuids: [serviceUuid],
        manufacturerData: _encodeMessageData(message),
      );

      // Iniciar advertising
      await FlutterBlePeripheral.start(
        advertiseMode: AdvertiseMode.lowLatency,
        connectable: true,
        timeout: 0, // Sin timeout
        advertisementData: advertisementData,
      );

      if (kDebugMode) {
        print('[BLE_PERIPHERAL] ✅ Advertising iniciado exitosamente');
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
      if (_isAdvertising) {
        await FlutterBlePeripheral.stop();
        
        if (kDebugMode) {
          print('[BLE_PERIPHERAL] 🛑 Advertising detenido');
        }
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
    _peripheralStateSubscription?.cancel();
    stopAdvertising();
    _isInitialized = false;
    
    if (kDebugMode) {
      print('[BLE_PERIPHERAL] 🧹 Servicio peripheral limpiado');
    }
  }
}
