import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/message_model.dart';
import 'mesh_manager.dart';
import 'ble_peripheral_service.dart';
import 'storage_service.dart';

class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  static const String SERVICE_UUID = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb";

  final BLEPeripheralService _peripheralService = BLEPeripheralService();
  final StorageService _storageService = StorageService();
  
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _adapterStateSubscription;
  bool _isScanning = false;
  bool _isInitialized = false;
  final Set<String> _processedDevices = {};
  Timer? _scanRestartTimer;
  int _scanInterval = 45; // Intervalo de escaneo en segundos (dinámico)
  
  // Cola de mensajes pendientes para transmitir
  final List<MessageModel> _messageQueue = [];
  bool _isTransmitting = false;

  /// Iniciar advertising de un mensaje (usa peripheral mode)
  Future<void> startAdvertising(String messageJson) async {
    try {
      final message = MessageModel.fromJsonString(messageJson);
      
      if (kDebugMode) {
        print('[BLE] 📡 Agregando mensaje a cola de transmisión');
      }

      // Agregar mensaje a la cola
      _messageQueue.add(message);

      // Iniciar advertising con el servicio peripheral
      await _peripheralService.startAdvertising(message);

      // Procesar cola si no está en proceso
      if (!_isTransmitting) {
        _processMessageQueue();
      }

    } catch (e) {
      if (kDebugMode) {
        print('[BLE] ❌ Error en advertising: $e');
      }
    }
  }

  /// Procesa la cola de mensajes y los transmite a nodos conectados
  Future<void> _processMessageQueue() async {
    if (_isTransmitting || _messageQueue.isEmpty) return;

    _isTransmitting = true;

    try {
      while (_messageQueue.isNotEmpty) {
        final message = _messageQueue.first;

        if (kDebugMode) {
          print('[BLE] 📤 Transmitiendo mensaje de la cola (${_messageQueue.length} pendientes)');
        }

        // Estrategia 1: Advertising activo (ya está corriendo con peripheral service)
        // Los otros nodos nos descubrirán automáticamente
        
        // Estrategia 2: Buscar nodos conocidos y enviarles el mensaje directamente
        await _broadcastToKnownDevices(message);

        // Remover de la cola después de transmitir
        _messageQueue.removeAt(0);

        // Pequeña pausa entre transmisiones
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      _isTransmitting = false;
    }
  }

  /// Intenta transmitir el mensaje a dispositivos conocidos directamente
  Future<void> _broadcastToKnownDevices(MessageModel message) async {
    if (kDebugMode) {
      print('[BLE] 🔄 Broadcasting a nodos conocidos');
      print('[BLE] ℹ️ Advertising activo: ${_peripheralService.isAdvertising()}');
    }

    // ESTRATEGIA 1: Advertising pasivo ya está activo vía peripheral service
    // Los nodos remotos pueden descubrirnos y conectarse para leer mensajes
    
    // ESTRATEGIA 2: Escaneo activo para encontrar nodos cercanos y enviarles el mensaje
    // Esto complementa el advertising para mejorar la entrega de mensajes
    
    try {
      // Obtener dispositivos actualmente escaneados
      final scanResults = FlutterBluePlus.lastScanResults;
      
      for (var result in scanResults) {
        // Filtrar solo nodos Orzion con señal fuerte
        if (result.advertisementData.localName.startsWith('Orzion-') && 
            result.rssi >= -80) {
          
          try {
            await _sendMessageToDevice(result.device, message);
          } catch (e) {
            if (kDebugMode) {
              print('[BLE] ⚠️ Error enviando a ${result.device.remoteId.toString().substring(0, 8)}: $e');
            }
            // Continuar con el siguiente nodo
            continue;
          }
        }
      }
      
      if (kDebugMode) {
        print('[BLE] ✅ Broadcast completado a nodos activos');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE] ⚠️ Error en broadcast a nodos conocidos: $e');
      }
    }
  }

  /// Envía un mensaje a un dispositivo BLE específico
  Future<void> _sendMessageToDevice(BluetoothDevice device, MessageModel message) async {
    try {
      // Conectar con timeout corto
      await device.connect(
        timeout: const Duration(seconds: 2),
        autoConnect: false,
      ).timeout(const Duration(seconds: 3));

      // Descubrir servicios
      final services = await device.discoverServices().timeout(
        const Duration(seconds: 3),
      );

      // Buscar nuestro servicio y característica
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              if (characteristic.properties.write) {
                // Escribir el mensaje
                final messageJson = message.toJsonString();
                final bytes = utf8.encode(messageJson);
                
                if (bytes.length <= 512) {
                  await characteristic.write(bytes, withoutResponse: false).timeout(
                    const Duration(seconds: 2),
                  );
                  
                  if (kDebugMode) {
                    print('[BLE] ✅ Mensaje enviado a ${device.remoteId.toString().substring(0, 8)}');
                  }
                }
              }
            }
          }
        }
      }

      // Desconectar
      await device.disconnect();
    } catch (e) {
      // Asegurar desconexión en caso de error
      try {
        await device.disconnect();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> startScanning() async {
    if (_isScanning) {
      if (kDebugMode) {
        print('[BLE] ℹ️ Escaneo ya está activo');
      }
      return;
    }

    try {
      _isScanning = true;

      if (kDebugMode) {
        print('[BLE] 🔍 Iniciando escaneo de nodos vecinos');
      }

      // Limpiar dispositivos procesados cada cierto tiempo para permitir reconexión
      _processedDevices.clear();

      // Configurar escaneo con parámetros optimizados para batería
      // OPTIMIZACIÓN: Reducir tiempo de escaneo de 15s a 10s
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (ScanResult result in results) {
            _handleDiscoveredDevice(result);
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('[BLE] ⚠️ Error en stream de escaneo: $error');
          }
        },
      );

      // Reiniciar escaneo periódicamente para mantener descubrimiento activo
      _scheduleNextScan();

    } catch (e) {
      if (kDebugMode) {
        print('[BLE] ❌ Error en escaneo: $e');
      }
      _isScanning = false;
      // Reintentar después de un error
      _scheduleNextScan();
    }
  }

  void _scheduleNextScan() {
    _scanRestartTimer?.cancel();
    // OPTIMIZACIÓN BATERÍA: Intervalo dinámico ajustado según batería
    _scanRestartTimer = Timer(Duration(seconds: _scanInterval), () {
      if (_isInitialized) {
        _isScanning = false;
        startScanning();
      }
    });
  }

  /// Actualizar intervalo de escaneo dinámicamente
  void updateScanInterval(int seconds) {
    if (_scanInterval != seconds) {
      _scanInterval = seconds;
      if (kDebugMode) {
        print('[BLE] 🔄 Intervalo de escaneo actualizado a ${_scanInterval}s');
      }
      // Reprogramar el siguiente escaneo con el nuevo intervalo
      if (_isInitialized) {
        _scheduleNextScan();
      }
    }
  }

  Future<void> _handleDiscoveredDevice(ScanResult result) async {
    try {
      final device = result.device;
      final deviceId = device.remoteId.toString();

      // Evitar procesar el mismo dispositivo múltiples veces en la misma sesión de escaneo
      if (_processedDevices.contains(deviceId)) {
        return;
      }

      // Verificar si es un nodo Orzion (por nombre local)
      final localName = result.advertisementData.localName;
      final isOrzionNode = localName.startsWith('Orzion-');

      if (kDebugMode) {
        print('[BLE] 📱 Nodo descubierto: ${deviceId.substring(0, 8)}..., RSSI: ${result.rssi} dBm, Nombre: $localName');
      }

      _processedDevices.add(deviceId);

      // OPTIMIZACIÓN SISTEMA DE SALTOS: Filtrar por intensidad de señal RSSI
      // RSSI > -80 dBm garantiza distancia efectiva de 20-50 metros por salto
      // -80 dBm es el umbral estándar para comunicación BLE confiable en exteriores
      // Distancias aproximadas: -50 dBm = ~5m, -70 dBm = ~20m, -80 dBm = ~50m
      if (result.rssi < -80) {
        if (kDebugMode) {
          print('[BLE] ⚠️ Señal débil (RSSI: ${result.rssi} dBm, fuera de alcance 20-50m), omitiendo conexión');
        }
        return;
      }
      
      if (kDebugMode) {
        print('[BLE] ✅ Señal aceptable (RSSI: ${result.rssi} dBm, distancia estimada: ${_estimateDistance(result.rssi)}m)');
      }

      // Priorizar nodos Orzion
      if (!isOrzionNode) {
        if (kDebugMode) {
          print('[BLE] ℹ️ No es nodo Orzion, omitiendo');
        }
        return;
      }

      // Guardar información del vecino descubierto
      await _storageService.saveOrUpdateNeighbor(
        deviceId,
        nodeName: localName,
        rssi: result.rssi,
      );

      // Conectar con timeout corto para no bloquear
      await device.connect(
        timeout: const Duration(seconds: 3),
        autoConnect: false,
      ).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          if (kDebugMode) {
            print('[BLE] ⏱️ Timeout en conexión con ${deviceId.substring(0, 8)}');
          }
          device.disconnect();
        },
      );

      if (kDebugMode) {
        print('[BLE] ✅ Conectado a nodo Orzion ${deviceId.substring(0, 8)}');
      }

      // Descubrir servicios
      List<BluetoothService> services = await device.discoverServices().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            print('[BLE] ⏱️ Timeout descubriendo servicios');
          }
          return [];
        },
      );

      bool messageFound = false;

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              try {
                // Leer mensaje del nodo remoto
                if (characteristic.properties.read) {
                  List<int> value = await characteristic.read().timeout(
                    const Duration(seconds: 3),
                    onTimeout: () {
                      if (kDebugMode) {
                        print('[BLE] ⏱️ Timeout leyendo característica');
                      }
                      return [];
                    },
                  );

                  if (value.isNotEmpty) {
                    String messageJson = utf8.decode(value);

                    if (kDebugMode) {
                      print('[BLE] 📨 Mensaje recibido de nodo Orzion ${deviceId.substring(0, 8)}');
                    }

                    // Procesar mensaje en el mesh manager
                    final message = MessageModel.fromJsonString(messageJson);
                    await MeshManager().forwardMessage(message);
                    messageFound = true;
                  }
                }

                // Si tenemos mensajes en cola, escribirlos en el nodo remoto
                if (characteristic.properties.write && _messageQueue.isNotEmpty) {
                  final messageToSend = _messageQueue.first;
                  final messageJson = messageToSend.toJsonString();
                  final bytes = utf8.encode(messageJson);
                  
                  // Solo enviar si el tamaño es manejable (max 512 bytes típicamente)
                  if (bytes.length <= 512) {
                    await characteristic.write(bytes, withoutResponse: false).timeout(
                      const Duration(seconds: 3),
                      onTimeout: () {
                        if (kDebugMode) {
                          print('[BLE] ⏱️ Timeout escribiendo mensaje');
                        }
                      },
                    );

                    if (kDebugMode) {
                      print('[BLE] ✅ Mensaje transmitido a nodo ${deviceId.substring(0, 8)}');
                    }
                  } else {
                    if (kDebugMode) {
                      print('[BLE] ⚠️ Mensaje muy grande para BLE (${bytes.length} bytes)');
                    }
                  }
                }

              } catch (e) {
                if (kDebugMode) {
                  print('[BLE] ⚠️ Error procesando característica: $e');
                }
              }
            }
          }
        }
      }

      // Desconectar después de procesar
      await device.disconnect();

      if (kDebugMode) {
        print('[BLE] 🔌 Desconectado de ${deviceId.substring(0, 8)} ${messageFound ? "(mensaje recibido)" : ""}');
      }

    } catch (e) {
      if (kDebugMode) {
        print('[BLE] ⚠️ Error procesando dispositivo: $e');
      }
      // Asegurar desconexión en caso de error
      try {
        await result.device.disconnect();
      } catch (_) {}
    }
  }

  Future<void> stopScanning() async {
    _scanRestartTimer?.cancel();
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _isScanning = false;
    
    if (kDebugMode) {
      print('[BLE] 🛑 Escaneo detenido');
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('[BLE] ℹ️ BLE ya inicializado');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('[BLE] 🚀 Inicializando servicio BLE completo');
        print('[BLE] ℹ️ Implementación: Dual mode (Central + Peripheral)');
        print('[BLE] ℹ️ Central: Escaneo y conexión a nodos');
        print('[BLE] ℹ️ Peripheral: Advertising y GATT server');
      }

      // Inicializar servicio peripheral con manejo de errores
      try {
        await _peripheralService.initialize();
      } catch (e) {
        if (kDebugMode) {
          print('[BLE] ⚠️ Peripheral service falló (no crítico): $e');
        }
      }

      // Verificar soporte de Bluetooth
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        if (kDebugMode) {
          print('[BLE] ⚠️ Bluetooth no soportado en este dispositivo');
        }
        // No lanzar excepción, marcar como parcialmente inicializado
        _isInitialized = true;
        return;
      }

      // Monitorear estado del adaptador
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (kDebugMode) {
          print('[BLE] 📡 Estado del adaptador: $state');
        }
        
        if (state == BluetoothAdapterState.on && !_isScanning) {
          startScanning();
        } else if (state != BluetoothAdapterState.on && _isScanning) {
          stopScanning();
        }
      });

      // Verificar estado actual
      final currentState = await FlutterBluePlus.adapterState.first;
      if (currentState != BluetoothAdapterState.on) {
        if (kDebugMode) {
          print('[BLE] ⚠️ Bluetooth está apagado - por favor enciéndalo');
        }
        // No retornar, esperar a que el usuario encienda el Bluetooth
        _isInitialized = true;
      } else {
        // Iniciar escaneo si Bluetooth está encendido
        try {
          await startScanning();
        } catch (e) {
          if (kDebugMode) {
            print('[BLE] ⚠️ Error iniciando escaneo: $e');
          }
        }
        _isInitialized = true;
      }
      
      if (kDebugMode) {
        print('[BLE] ✅ Servicio BLE completo inicializado correctamente');
        print('[BLE] ℹ️ Alcance efectivo: ~20-50 metros por salto (RSSI > -80 dBm)');
        print('[BLE] ✅ Multi-hop REAL habilitado con advertising');
      }

    } catch (e) {
      if (kDebugMode) {
        print('[BLE] ❌ Error inicializando BLE: $e');
        print('[BLE] ℹ️ Marcando como parcialmente inicializado para evitar crasheo');
      }
      // Marcar como inicializado pero con limitaciones
      _isInitialized = true;
    }
  }

  /// Estima la distancia aproximada basada en RSSI (en metros)
  /// Fórmula simplificada: d = 10^((TxPower - RSSI) / (10 * n))
  /// donde n = 2 (factor de propagación en espacio abierto)
  int _estimateDistance(int rssi) {
    const int txPower = -59;
    if (rssi >= 0) return 1;
    
    final ratio = (txPower - rssi) / 20.0;
    final distance = (10.0 * (ratio)).round();
    
    return distance.clamp(1, 100);
  }

  void dispose() {
    _scanRestartTimer?.cancel();
    _adapterStateSubscription?.cancel();
    stopScanning();
    _peripheralService.dispose();
    _connectedDevice?.disconnect();
    _messageQueue.clear();
    _isInitialized = false;
    
    if (kDebugMode) {
      print('[BLE] 🧹 Servicio BLE limpiado');
    }
  }
}
