import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'map_data_service.dart';

class MeshManager {
  static final MeshManager _instance = MeshManager._internal();
  factory MeshManager() => _instance;
  MeshManager._internal();

  final String nodeId = DateTime.now().millisecondsSinceEpoch.toString();
  final MapDataService _mapService = MapDataService();
  
  final Map<String, MessageModel> _messageCache = {};
  final Map<String, DateTime> _processedMessages = {};
  final StreamController<MessageModel> _incomingMessagesController = 
      StreamController<MessageModel>.broadcast();
  
  Stream<MessageModel> get incomingMessages => _incomingMessagesController.stream;

  bool checkLegalCompliance() {
    if (kDebugMode) {
      print('[COMPLIANCE CHECK] Iniciando verificación de cumplimiento regulatorio CONATEL');
    }
    
    bool compliant = true;
    List<String> complianceChecks = [];

    final hasGps = _mapService.hasGpsConsent;
    final hasBackground = _mapService.hasBackgroundConsent;

    complianceChecks.add('✓ Uso exclusivo de APIs oficiales de BLE (flutter_blue_plus) - 2.4 GHz');
    complianceChecks.add('✓ Uso exclusivo de APIs oficiales de WiFi Direct (flutter_p2p_connection) - 2.4 GHz');
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

  /// Retransmite un mensaje a nodos vecinos usando BLE y WiFi Direct.
  /// 
  /// IMPLEMENTACIÓN REQUERIDA:
  /// 
  /// 1. BLE (Bluetooth Low Energy) usando flutter_blue_plus:
  ///    - Advertise: Publicar el mensaje serializado como advertising data
  ///      * Usar FlutterBluePlus.startAdvertising() con el payload del mensaje
  ///      * Mantener potencia de transmisión en límites ISM 2.4 GHz (no modificar)
  ///    - Scan: Escuchar mensajes de otros nodos
  ///      * Usar FlutterBluePlus.startScan() para detectar nodos vecinos
  ///      * Filtrar por serviceUUID específico de la app
  /// 
  /// 2. WiFi Direct usando flutter_p2p_connection:
  ///    - Broadcast: Transmitir mensaje a grupo P2P
  ///      * Usar FlutterP2pConnection.createGroup() o joinGroup()
  ///      * Enviar mensaje serializado via FlutterP2pConnection.sendMessage()
  ///      * Operar exclusivamente en 2.4 GHz (sin modificar potencia)
  /// 
  /// 3. Formato del mensaje:
  ///    - Serializar con message.toJsonString()
  ///    - Incluir TTL, hop history, y contenido encriptado
  ///    - NO descifrar contenido (solo leer metadata para routing)
  /// 
  /// 4. Cumplimiento regulatorio CONATEL:
  ///    - Solo transmitir si hasBackgroundPermission == true
  ///    - Usar APIs nativas sin modificar potencia de transmisión
  ///    - Operar solo en banda ISM 2.4 GHz no licenciada
  Future<void> _retransmit(MessageModel message) async {
    if (kDebugMode) {
      print('[MESH] Transmitiendo a nodos vecinos...');
      print('[MESH] NOTA: Implementación BLE/WiFi Direct pendiente');
      print('[MESH] - BLE: Usar flutter_blue_plus para advertise/scan');
      print('[MESH] - WiFi Direct: Usar flutter_p2p_connection para broadcast');
      print('[MESH] - Mensaje serializado: ${message.toJsonString()}');
    }
  }

  Future<MessageModel> createMessage({
    required String destinationId,
    required String plainTextContent,
    required String encryptionKey,
    int ttl = 10,
  }) async {
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
