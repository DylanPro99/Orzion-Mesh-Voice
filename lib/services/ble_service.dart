import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/message_model.dart';
import 'mesh_manager.dart';

class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  static const String SERVICE_UUID = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb";

  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  bool _isScanning = false;

  Future<void> startAdvertising(String messageJson) async {
    try {
      if (kDebugMode) {
        print('[BLE] Iniciando advertising para mensaje');
      }

      // BLE advertising limitado en Android - usar GATT server como alternativa
      // Esto permite que otros dispositivos se conecten y lean el mensaje

    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Error en advertising: $e');
      }
    }
  }

  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      _isScanning = true;

      if (kDebugMode) {
        print('[BLE] Iniciando escaneo de nodos vecinos');
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(SERVICE_UUID)],
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _handleDiscoveredDevice(result);
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Error en escaneo: $e');
      }
      _isScanning = false;
    }
  }

  Future<void> _handleDiscoveredDevice(ScanResult result) async {
    try {
      final device = result.device;

      if (kDebugMode) {
        print('[BLE] Nodo descubierto: ${device.remoteId}, RSSI: ${result.rssi}');
      }

      // Conectar y leer mensaje
      await device.connect(timeout: const Duration(seconds: 5));

      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == CHARACTERISTIC_UUID) {
              // Leer mensaje
              List<int> value = await characteristic.read();
              String messageJson = utf8.decode(value);

              if (kDebugMode) {
                print('[BLE] Mensaje recibido de ${device.remoteId}');
              }

              // Procesar mensaje
              final message = MessageModel.fromJsonString(messageJson);
              await MeshManager().forwardMessage(message);
            }
          }
        }
      }

      await device.disconnect();

    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Error procesando dispositivo: $e');
      }
    }
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _isScanning = false;
  }

  Future<void> initialize() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        print('⚠️ Bluetooth no soportado en este dispositivo');
        return;
      }

      // No forzar encendido automático, solo verificar estado
      final isOn = await FlutterBluePlus.adapterState.first;
      if (isOn != BluetoothAdapterState.on) {
        print('⚠️ Bluetooth está apagado - solicitar al usuario que lo encienda');
        return;
      }

      // Solo iniciar escaneo - el advertising se hace cuando hay mensajes
      await startScanning();
    } catch (e) {
      print('Error inicializando BLE: $e');
      // No lanzar excepción, solo registrar el error
    }
  }


  void dispose() {
    stopScanning();
    _connectedDevice?.disconnect();
  }
}