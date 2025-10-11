
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import '../models/message_model.dart';
import 'mesh_manager.dart';

class WiFiDirectService {
  static final WiFiDirectService _instance = WiFiDirectService._internal();
  factory WiFiDirectService() => _instance;
  WiFiDirectService._internal();

  final _flutterP2pConnection = FlutterP2pConnection.instance;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _dataSubscription;
  
  bool _isDiscovering = false;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _flutterP2pConnection.initialize();
      
      _stateSubscription = _flutterP2pConnection.streamWifiP2pState().listen((state) {
        if (kDebugMode) {
          print('[WiFi] Estado P2P actualizado');
        }
      });

      _devicesSubscription = _flutterP2pConnection.streamPeers().listen((devicesList) {
        if (kDebugMode) {
          print('[WiFi] ${devicesList.length} dispositivos P2P descubiertos');
        }
        _connectToDevices(devicesList);
      });

      _dataSubscription = _flutterP2pConnection.streamSocket().listen((data) {
        if (data != null) {
          _handleIncomingData(data);
        }
      });

      _isInitialized = true;
      
      if (kDebugMode) {
        print('[WiFi] Servicio WiFi Direct inicializado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WiFi] Error inicializando P2P: $e');
      }
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering || !_isInitialized) return;

    try {
      _isDiscovering = true;
      
      if (kDebugMode) {
        print('[WiFi] Iniciando descubrimiento P2P');
      }

      await _flutterP2pConnection.discover();
      
    } catch (e) {
      if (kDebugMode) {
        print('[WiFi] Error en descubrimiento: $e');
      }
      _isDiscovering = false;
    }
  }

  Future<void> _connectToDevices(List<dynamic> devices) async {
    for (var device in devices) {
      try {
        final deviceAddress = device.deviceAddress ?? device.toString();
        
        if (kDebugMode) {
          print('[WiFi] Intentando conectar a dispositivo');
        }

        final result = await _flutterP2pConnection.connect(deviceAddress);
        
        if (result && kDebugMode) {
          print('[WiFi] Conexión P2P establecida');
        }
      } catch (e) {
        if (kDebugMode) {
          print('[WiFi] Error conectando: $e');
        }
      }
    }
  }

  void _handleIncomingData(dynamic socketData) {
    try {
      String messageJson;
      
      if (socketData is String) {
        messageJson = socketData;
      } else if (socketData is List<int>) {
        messageJson = utf8.decode(socketData);
      } else {
        if (kDebugMode) {
          print('[WiFi] Tipo de datos no soportado: ${socketData.runtimeType}');
        }
        return;
      }
      
      if (kDebugMode) {
        print('[WiFi] Mensaje recibido via P2P');
      }

      final message = MessageModel.fromJsonString(messageJson);
      MeshManager().forwardMessage(message);
      
    } catch (e) {
      if (kDebugMode) {
        print('[WiFi] Error procesando mensaje: $e');
      }
    }
  }

  Future<void> broadcast(String messageJson) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('[WiFi] Servicio no inicializado, omitiendo broadcast');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('[WiFi] Transmitiendo mensaje via WiFi Direct');
      }

      await _flutterP2pConnection.sendStringToSocket(messageJson);
      
      if (kDebugMode) {
        print('[WiFi] Mensaje transmitido exitosamente');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('[WiFi] Error transmitiendo: $e');
      }
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isInitialized) return;
    
    try {
      await _flutterP2pConnection.stopDiscovery();
      _isDiscovering = false;
    } catch (e) {
      if (kDebugMode) {
        print('[WiFi] Error deteniendo descubrimiento: $e');
      }
    }
  }

  void dispose() {
    stopDiscovery();
    _stateSubscription?.cancel();
    _devicesSubscription?.cancel();
    _dataSubscription?.cancel();
    _flutterP2pConnection.removeGroup();
    _isInitialized = false;
  }
}
