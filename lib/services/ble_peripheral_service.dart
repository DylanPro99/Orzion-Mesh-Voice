import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../models/message_model.dart';

class BLEPeripheralService {
  static final BLEPeripheralService _instance = BLEPeripheralService._internal();
  factory BLEPeripheralService() => _instance;
  BLEPeripheralService._internal();

  static const String SERVICE_UUID = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb";
  
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;
  bool _isInitialized = false;
  String? _currentMessageJson;
  Timer? _advertisingTimer;

  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('[BLE Peripheral] ℹ️ Ya inicializado');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('[BLE Peripheral] 🚀 Inicializando modo peripheral');
      }

      // Verificar soporte de peripheral mode
      final isSupported = await _peripheral.isSupported();
      if (!isSupported) {
        if (kDebugMode) {
          print('[BLE Peripheral] ⚠️ Peripheral mode no soportado en este dispositivo');
        }
        return;
      }

      _isInitialized = true;

      if (kDebugMode) {
        print('[BLE Peripheral] ✅ Peripheral mode inicializado');
      }

    } catch (e) {
      if (kDebugMode) {
        print('[BLE Peripheral] ❌ Error inicializando: $e');
      }
      _isInitialized = false;
    }
  }

  Future<void> startAdvertising(MessageModel message) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('[BLE Peripheral] ⚠️ No inicializado, omitiendo advertising');
      }
      return;
    }

    try {
      final messageJson = message.toJsonString();
      _currentMessageJson = messageJson;

      if (kDebugMode) {
        print('[BLE Peripheral] 📡 Iniciando advertising de mensaje');
        print('[BLE Peripheral] ℹ️ Mensaje ID: ${message.messageId.substring(0, 8)}...');
      }

      // Detener advertising previo si existe
      await stopAdvertising();

      // Preparar datos de advertising
      // Nota: BLE advertising tiene límite de ~31 bytes en el payload
      // Para mensajes más grandes, se debe usar el GATT server
      
      final messageBytes = utf8.encode(messageJson);
      final truncatedBytes = messageBytes.length > 20 
          ? messageBytes.sublist(0, 20) 
          : messageBytes;

      // Configurar advertising data
      final advertiseData = AdvertiseData(
        serviceUuid: SERVICE_UUID,
        localName: 'Orzion-${message.senderId.substring(0, 6)}',
        manufacturerId: 0x004C, // ID genérico
        manufacturerData: truncatedBytes,
        includeDeviceName: false,
      );

      // Configurar advertising settings
      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: true,
        timeout: 0, // Sin timeout, advertising continuo
      );

      // Iniciar advertising
      await _peripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      _isAdvertising = true;

      if (kDebugMode) {
        print('[BLE Peripheral] ✅ Advertising activo');
        print('[BLE Peripheral] ℹ️ Service UUID: $SERVICE_UUID');
        print('[BLE Peripheral] ℹ️ Mensaje en advertising: ${truncatedBytes.length} bytes');
        print('[BLE Peripheral] ℹ️ Para mensaje completo, los nodos deben conectarse');
      }

      // Programar detención automática después de 30 segundos
      // Esto evita advertising indefinido del mismo mensaje
      _advertisingTimer?.cancel();
      _advertisingTimer = Timer(const Duration(seconds: 30), () {
        stopAdvertising();
      });

    } catch (e) {
      if (kDebugMode) {
        print('[BLE Peripheral] ❌ Error en advertising: $e');
      }
      _isAdvertising = false;
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;

    try {
      await _peripheral.stop();
      _isAdvertising = false;
      _advertisingTimer?.cancel();

      if (kDebugMode) {
        print('[BLE Peripheral] 🛑 Advertising detenido');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE Peripheral] ⚠️ Error deteniendo advertising: $e');
      }
    }
  }

  /// Obtener el mensaje actual que se está anunciando
  String? getCurrentMessage() {
    return _currentMessageJson;
  }

  /// Verificar si está anunciando
  bool isAdvertising() {
    return _isAdvertising;
  }

  void dispose() {
    _advertisingTimer?.cancel();
    stopAdvertising();
    _currentMessageJson = null;
    _isInitialized = false;

    if (kDebugMode) {
      print('[BLE Peripheral] 🧹 Servicio peripheral limpiado');
    }
  }
}
