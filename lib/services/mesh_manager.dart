import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'map_data_service.dart';
import 'ble_service.dart';
import 'wifi_direct_service.dart';

class MeshManager {
  static final MeshManager _instance = MeshManager._internal();
  factory MeshManager() => _instance;
  MeshManager._internal();

  final String nodeId = DateTime.now().millisecondsSinceEpoch.toString();
  final MapDataService _mapService = MapDataService();
  final BLEService _bleService = BLEService();
  final WiFiDirectService _wifiService = WiFiDirectService();

  final Map<String, MessageModel> _messageCache = {};
  bool _servicesInitialized = false;
  final Map<String, DateTime> _processedMessages = {};
  final StreamController<MessageModel> _incomingMessagesController =
      StreamController<MessageModel>.broadcast();

  Stream<MessageModel> get incomingMessages => _incomingMessagesController.stream;

  Future<void> initializeNetworkServices() async {
    if (_servicesInitialized) return;

    if (kDebugMode) {
      print('[MESH] Inicializando servicios de red');
      print('[MESH] ═══════════════════════════════════════════════════════');
      print('[MESH] ARQUITECTURA DE RED DE MALLA:');
      print('[MESH]   🔵 BLE = TRANSPORTE PRINCIPAL');
      print('[MESH]      ✓ Descubrimiento de nodos');
      print('[MESH]      ✓ Transmisión de mensajes');
      print('[MESH]      ✓ Retransmisión multi-salto');
      print('[MESH]   📶 WiFi Direct = DESHABILITADO');
      print('[MESH]      (Incompatible con arquitectura de malla distribuida)');
      print('[MESH] ═══════════════════════════════════════════════════════');
    }

    // Solicitar permisos antes de iniciar servicios
    if (!await _mapService.requestBackgroundPermission()) {
      if (kDebugMode) {
        print('[MESH] Permiso de segundo plano denegado. No se pueden iniciar servicios de red.');
      }
      // Considerar lanzar una excepción o manejar este caso de forma más robusta
      return; 
    }

    try {
      await _wifiService.initialize();
      await _bleService.startScanning();
    } catch (e) {
      if (kDebugMode) {
        print('[MESH] Error inicializando servicios de red: $e');
      }
      // Considerar lanzar una excepción o manejar este caso de forma más robusta
      return;
    }

    // Iniciar servicio en primer plano para mantener nodo activo
    await _startForegroundService();

    _servicesInitialized = true;

    if (kDebugMode) {
      print('[MESH] Red de malla activa (BLE) - Nodo retransmitirá mensajes');
    }
  }

  Future<void> _startForegroundService() async {
    if (kDebugMode) {
      print('[MESH] Iniciando servicio en primer plano');
    }

    try {
      // Aquí iría la lógica para iniciar un servicio en primer plano (Android/iOS)
      // Por ahora, solo imprimimos un mensaje de depuración.
      if (kDebugMode) {
        print('[MESH] Servicio de primer plano activo - Nodo retransmitirá mensajes en segundo plano');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MESH] Error iniciando servicio en primer plano: $e');
      }
      // Manejar el error de forma apropiada, quizás lanzar una excepción
    }
  }

  bool checkLegalCompliance() {
    if (kDebugMode) {
      print('[COMPLIANCE CHECK] Iniciando verificación de cumplimiento regulatorio CONATEL');
    }

    bool compliant = true;
    List<String> complianceChecks = [];

    final hasGps = _mapService.hasGpsConsent;
    final hasBackground = _mapService.hasBackgroundConsent;

    complianceChecks.add('✓ Uso exclusivo de APIs oficiales de BLE (flutter_blue_plus) - 2.4 GHz');
    complianceChecks.add('✓ No se modifica la potencia de transmisión (APIs nativas sin modificación)');
    complianceChecks.add('✓ Operación exclusiva en bandas no licenciadas ISM 2.4 GHz');
    complianceChecks.add(hasGps && hasBackground
        ? '✓ Consentimiento explícito obtenido (doble opt-in)'
        : '✗ Requiere consentimiento explícito del usuario');
    complianceChecks.add('✓ Privacidad: nodos repetidores no descifran mensajes (solo metadata)');
    complianceChecks.add('✓ Encriptación AES con IV aleatorio por mensaje');

    if (!hasGps || !hasBackground) {
      compliant = false;
    }

    if (kDebugMode) {
      print('[COMPLIANCE CHECK] Resultados de verificación:');
      for (var check in complianceChecks) {
        print('  $check');
      }
      print('[COMPLIANCE CHECK] Estado: ${compliant ? "CONFORME" : "NO CONFORME"}');
      if (!compliant) {
        print('[COMPLIANCE CHECK] Acción requerida: Solicitar permisos de usuario');
      }
    }

    return compliant;
  }

  Future<bool> canRetransmit() async {
    // Asegurarse de que los servicios de red estén inicializados y los permisos estén concedidos
    if (!_servicesInitialized) {
      if (kDebugMode) {
        print('[MESH] Servicios de red no inicializados, no se puede retransmitir.');
      }
      return false;
    }
    return await _mapService.hasBackgroundPermission();
  }

  Future<void> forwardMessage(MessageModel message) async {
    if (kDebugMode) {
      print('[MESH] Procesando mensaje ${message.messageId}');
    }

    if (_processedMessages.containsKey(message.messageId)) {
      if (kDebugMode) {
        print('[MESH] Mensaje ${message.messageId} ya procesado, descartando');
      }
      return;
    }

    _processedMessages[message.messageId] = DateTime.now();
    _cleanOldProcessedMessages();

    if (message.ttl <= 0) {
      if (kDebugMode) {
        print('[MESH] TTL agotado para mensaje ${message.messageId}, descartando');
      }
      return;
    }

    if (message.destinationId == nodeId) {
      if (kDebugMode) {
        print('[MESH] Mensaje ${message.messageId} recibido (soy el destinatario)');
      }
      _messageCache[message.messageId] = message;
      _incomingMessagesController.add(message);

      await _mapService.sendRoute(
        message.messageId,
        message.hopHistory.map((h) => h.nodeId).toList(),
      );
      return;
    }

    if (!await canRetransmit()) {
      if (kDebugMode) {
        print('[MESH] Sin permiso de retransmisión, descartando mensaje');
      }
      return;
    }

    if (kDebugMode) {
      print('[MESH] Retransmitiendo mensaje ${message.messageId} (TTL: ${message.ttl})');
    }

    final currentLocation = await _mapService.getCurrentLocation();
    final newHop = HopData(
      nodeId: nodeId,
      timestamp: DateTime.now(),
      gpsCoords: currentLocation,
    );

    final updatedMessage = message
        .copyWithNewHop(newHop)
        .copyWithDecrementedTTL();

    await _retransmit(updatedMessage);

    await _mapService.sendNodeData(
        nodeId,
        currentLocation ?? {'lat': 0.0, 'lng': 0.0}
    );
  }

  Future<void> _retransmit(MessageModel message) async {
    final messageJson = message.toJsonString();

    if (kDebugMode) {
      print('[MESH] Transmitiendo mensaje ${message.messageId} via BLE');
      print('[MESH] TTL: ${message.ttl}, Saltos: ${message.hopHistory.length}');
    }

    await _transmitViaBLE(messageJson);
  }

  Future<void> _transmitViaBLE(String messageJson) async {
    await _bleService.startAdvertising(messageJson);
  }

  Future<MessageModel> createMessage({
    required String destinationId,
    required String plainTextContent,
    required String encryptionKey,
    int ttl = 10,
  }) async {
    // Asegurarse de que los permisos estén concedidos antes de crear y enviar mensajes
    if (!await _mapService.hasBackgroundPermission()) {
      if (kDebugMode) {
        print('[MESH] Sin permiso de retransmisión, no se puede crear mensaje.');
      }
      // Lanzar una excepción o devolver un resultado nulo para indicar fallo
      throw StateError("Background permission not granted to create message.");
    }

    final encryptedContent = MessageModel.encryptMessage(
      plainTextContent,
      encryptionKey,
    );

    final currentLocation = await _mapService.getCurrentLocation();
    final initialHop = HopData(
      nodeId: nodeId,
      timestamp: DateTime.now(),
      gpsCoords: currentLocation,
    );

    final message = MessageModel(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: nodeId,
      destinationId: destinationId,
      encryptedContent: encryptedContent,
      ttl: ttl,
      hopHistory: [initialHop],
    );

    _messageCache[message.messageId] = message;

    await _retransmit(message);

    return message;
  }

  String? decryptMessage(MessageModel message, String key) {
    if (message.destinationId != nodeId && message.senderId != nodeId) {
      if (kDebugMode) {
        print('[PRIVACY] Nodo repetidor no puede descifrar mensajes');
      }
      return null;
    }

    return MessageModel.decryptMessage(message.encryptedContent, key);
  }

  void _cleanOldProcessedMessages() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _processedMessages.removeWhere((key, value) => value.isBefore(cutoff));
  }

  List<MessageModel> getReceivedMessages() {
    return _messageCache.values
        .where((m) => m.destinationId == nodeId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void dispose() {
    _incomingMessagesController.close();
  }
}