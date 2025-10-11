
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

  final _flutterP2pConnection = FlutterP2pConnection();
  StreamSubscription? _stateSubscription;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _transferSubscription;
  
  bool _isDiscovering = false;
  WifiP2pDevice? _connectedDevice;

  Future<void> initialize() async {
    try {
      await _flutterP2pConnection.initialize();
      
      _stateSubscription = _flutterP2pConnection.streamWifiP2pState().listen((state) {
        if (kDebugMode) {
          print('[WiFi] Estado P2P: ${state.isWifiP2pEnabled ? "Activo" : "Inactivo"}');
        }
      });

      _devicesSubscription = _flutterP2pConnection.streamPeers().listen((devicesList) {
        if (kDebugMode) {
          print('[WiFi] ${devicesList.length} nodos P2P descubiertos');
        }
        _handleDiscoveredDevices(devicesList);
      });

      _transferSubscription = _flutterP2pConnection.streamSocket().listen((socket) {
        if (socket != null) {
          _handleIncomingData(socket);
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('[WiFi] Error inicializando P2P: $e');
      }
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    try {
      _isDiscovering = true;
      
      if (kDebugMode) {
        print('[WiFi] Iniciando descubrimiento de nodos P2P');
      }

      await _flutterP2pConnection.discover();
      
    } catch (e) {
      if (kDebugMode) {
        print('[WiFi] Error en descubrimiento: $e');
      }
      _isDiscovering = false;
    }
  }

  Future<void> _handleDiscoveredDevices(List<WifiP2pDevice> devices) async {
    for (var device in devices) {
      if (kDebugMode) {
        print('[WiFi] Conectando a nodo: ${device.deviceName}');
      }

      try {
        final result = await _flutterP2pConnection.connect(device.deviceAddress);
        
        if (result) {
          _connectedDevice = device;
          if (kDebugMode) {
            print('[WiFi] Conectado exitosamente a ${device.deviceName}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('[WiFi] Error conectando: $e');
        }
      }
    }
  }

  void _handleIncomingData(Socket socket) {
    socket.listen((data) {
      try {
        final messageJson = utf8.decode(data);
        
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
    });
  }

  Future<void> broadcast(String messageJson) async {
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
    await _flutterP2pConnection.stopDiscovery();
    _isDiscovering = false;
  }

  void dispose() {
    stopDiscovery();
    _stateSubscription?.cancel();
    _devicesSubscription?.cancel();
    _transferSubscription?.cancel();
    _flutterP2pConnection.removeGroup();
  }
}
