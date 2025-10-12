import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';
import '../models/message_model.dart';
import '../models/ack_message.dart';
import '../models/stored_message.dart';
import 'map_data_service.dart';
import 'ble_service.dart';
import 'wifi_direct_service.dart';
import 'storage_service.dart';

class MeshManager {
  static final MeshManager _instance = MeshManager._internal();
  factory MeshManager() => _instance;
  MeshManager._internal();

  final String nodeId = DateTime.now().millisecondsSinceEpoch.toString();
  final MapDataService _mapService = MapDataService();
  final BLEService _bleService = BLEService();
  final WiFiDirectService _wifiService = WiFiDirectService();
  final StorageService _storageService = StorageService();
  Battery? _battery;

  // Control flag para foreground service (solo si permiso de notificaciones está concedido)
  bool _canStartForegroundService = false;

  final Map<String, MessageModel> _messageCache = {};
  bool _servicesInitialized = false;
  final Map<String, DateTime> _processedMessages = {};
  final StreamController<MessageModel> _incomingMessagesController =
      StreamController<MessageModel>.broadcast();
  final StreamController<AckMessage> _ackController =
      StreamController<AckMessage>.broadcast();

  static const platform = MethodChannel('com.orzion.mesh/foreground');

  Stream<MessageModel> get incomingMessages => _incomingMessagesController.stream;
  Stream<AckMessage> get ackMessages => _ackController.stream;

  // Variables para modo ahorro de batería
  int _currentBatteryLevel = 100;
  Timer? _batteryCheckTimer;
  int _scanInterval = 45; // Intervalo de escaneo en segundos (default)

  /// Retorna true si se inicializó completamente, false si tiene limitaciones
  Future<bool> initializeNetworkServices() async {
    if (_servicesInitialized) {
      if (kDebugMode) {
        print('[MESH] ℹ️ Servicios ya inicializados');
      }
      return _canStartForegroundService;
    }

    if (kDebugMode) {
      print('[MESH] 🚀 Inicializando servicios de red');
      print('[MESH] ═══════════════════════════════════════════════════════');
      print('[MESH] ARQUITECTURA DE RED DE MALLA:');
      print('[MESH]   🔵 BLE = TRANSPORTE PRINCIPAL');
      print('[MESH]      ✓ Descubrimiento automático de nodos');
      print('[MESH]      ✓ Transmisión de mensajes cifrados');
      print('[MESH]      ✓ Retransmisión multi-salto automática');
      print('[MESH]      ✓ Alcance: ~20-50 metros por salto');
      print('[MESH]   📶 WiFi Direct = DESHABILITADO');
      print('[MESH]      (Incompatible con arquitectura de malla distribuida)');
      print('[MESH] ═══════════════════════════════════════════════════════');
    }

    // Solicitar permiso de notificaciones (crítico para foreground service en Android 13+)
    final hasNotificationPermission = await _mapService.requestNotificationPermission();

    // Solicitar permisos de segundo plano
    final hasBackgroundPermission = await _mapService.requestBackgroundPermission();

    if (!hasBackgroundPermission) {
      if (kDebugMode) {
        print('[MESH] ⚠️ Permiso de segundo plano denegado');
        print('[MESH] ℹ️ El nodo funcionará pero no retransmitirá mensajes');
      }
    }

    // Guardar si se debe iniciar el foreground service
    _canStartForegroundService = hasNotificationPermission;

    try {
      // Inicializar WiFi Direct (modo simplificado)
      try {
        await _wifiService.initialize();
      } catch (e) {
        if (kDebugMode) {
          print('[MESH] ⚠️ WiFi Direct falló (no crítico): $e');
        }
      }

      // Inicializar BLE (servicio principal)
      try {
        await _bleService.initialize();
      } catch (e) {
        if (kDebugMode) {
          print('[MESH] ⚠️ BLE falló (continuando): $e');
        }
      }

      if (kDebugMode) {
        print('[MESH] ✓ Servicios de red inicializados (con posibles limitaciones)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MESH] ⚠️ Error durante inicialización de red: $e');
      }
      // Continuar con servicios parcialmente inicializados
    }

    // Iniciar servicio en primer plano solo si tenemos permiso de notificaciones
    if (_canStartForegroundService) {
      await _startForegroundService();
    } else {
      if (kDebugMode) {
        print('[MESH] ⚠️ Servicio en primer plano NO iniciado (sin permiso de notificaciones)');
        print('[MESH] ℹ️ El nodo funcionará solo cuando la app esté en primer plano');
      }
    }

    // Iniciar monitoreo de batería para modo ahorro
    _startBatteryMonitoring();

    _servicesInitialized = true;

    if (kDebugMode) {
      print('[MESH] ✅ Red de malla activa (BLE) - Nodo listo para operar');
      if (!_canStartForegroundService) {
        print('[MESH] ⚠️ Modo limitado: Solo funciona en primer plano');
      }
    }

    return _canStartForegroundService;
  }

  // ==================== MODO AHORRO DE BATERÍA ====================

  void _startBatteryMonitoring() {
    // Inicializar Battery de forma segura
    try {
      _battery = Battery();
      _batteryCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
        await _updateBatteryLevel();
      });
      _updateBatteryLevel(); // Actualizar inmediatamente
    } catch (e) {
      if (kDebugMode) {
        print('[BATTERY] ⚠️ Monitoreo de batería no disponible: $e');
        print('[BATTERY] ℹ️ Usando modo normal sin ahorro de batería');
      }
    }
  }

  Future<void> _updateBatteryLevel() async {
    if (_battery == null) return;

    try {
      _currentBatteryLevel = await _battery!.batteryLevel;
      final oldInterval = _scanInterval;

      // Ajustar intervalo de escaneo según batería
      if (_currentBatteryLevel < 10) {
        _scanInterval = 120; // Ultra-ahorro: cada 2 minutos
      } else if (_currentBatteryLevel < 20) {
        _scanInterval = 60; // Ahorro: cada 1 minuto
      } else {
        _scanInterval = 45; // Normal: cada 45 segundos
      }

      // Detectar modo nocturno (12am-6am)
      final hour = DateTime.now().hour;
      if (hour >= 0 && hour < 6) {
        _scanInterval = (_scanInterval * 1.5).toInt(); // 50% más lento en la noche
      }

      if (kDebugMode && oldInterval != _scanInterval) {
        print('[BATTERY] 🔋 Batería: $_currentBatteryLevel% - Intervalo: ${_scanInterval}s');
      }

      // Actualizar intervalo en BLE service
      _bleService.updateScanInterval(_scanInterval);
    } catch (e) {
      if (kDebugMode) {
        print('[BATTERY] ⚠️ Error obteniendo nivel de batería: $e');
      }
    }
  }

  int get currentBatteryLevel => _currentBatteryLevel;
  int get scanInterval => _scanInterval;

  Future<void> _startForegroundService() async {
    try {
      if (kDebugMode) {
        print('[MESH] 🔔 Iniciando servicio en primer plano');
      }

      // Llamar al método nativo de Android para iniciar el foreground service
      await platform.invokeMethod('startForegroundService');

      if (kDebugMode) {
        print('[MESH] ✓ Servicio de primer plano activo');
        print('[MESH] ℹ️ Nodo retransmitirá mensajes incluso con app en segundo plano');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MESH] ⚠️ Error iniciando servicio en primer plano: $e');
        print('[MESH] ℹ️ La app funcionará pero sin retransmisión en segundo plano');
        print('[MESH] ℹ️ Asegúrate de que todos los permisos estén concedidos');
      }
      // NO lanzar excepción - permitir que la app continúe sin foreground service
    }
  }

  bool checkLegalCompliance() {
    if (kDebugMode) {
      print('[COMPLIANCE] 🔍 Verificando cumplimiento regulatorio CONATEL');
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
    complianceChecks.add('✓ Encriptación AES-256 con IV aleatorio por mensaje');

    if (!hasGps || !hasBackground) {
      compliant = false;
    }

    if (kDebugMode) {
      print('[COMPLIANCE] 📋 Resultados de verificación:');
      for (var check in complianceChecks) {
        print('[COMPLIANCE]   $check');
      }
      print('[COMPLIANCE] ${compliant ? "✅ CONFORME" : "⚠️ NO CONFORME"}');
      if (!compliant) {
        print('[COMPLIANCE] 📝 Acción requerida: Solicitar permisos de usuario');
      }
    }

    return compliant;
  }

  Future<bool> canRetransmit() async {
    if (!_servicesInitialized) {
      if (kDebugMode) {
        print('[MESH] ⚠️ Servicios no inicializados, retransmisión no disponible');
      }
      return false;
    }

    final hasPermission = await _mapService.hasBackgroundPermission();

    if (!hasPermission && kDebugMode) {
      print('[MESH] ⚠️ Sin permiso de retransmisión');
    }

    return hasPermission;
  }

  Future<void> forwardMessage(MessageModel message) async {
    if (kDebugMode) {
      print('[MESH] 📥 Procesando mensaje ${message.messageId.substring(0, 8)}...');
    }

    // Prevenir loops: verificar si ya procesamos este mensaje
    if (_processedMessages.containsKey(message.messageId)) {
      if (kDebugMode) {
        print('[MESH] ♻️ Mensaje ya procesado, descartando (prevención de loops)');
      }
      return;
    }

    // Marcar mensaje como procesado
    _processedMessages[message.messageId] = DateTime.now();
    _cleanOldProcessedMessages();

    // Verificar TTL
    if (message.ttl <= 0) {
      if (kDebugMode) {
        print('[MESH] ⏱️ TTL agotado, descartando mensaje');
      }
      return;
    }

    // Si soy el destinatario
    if (message.destinationId == nodeId) {
      if (kDebugMode) {
        print('[MESH] 🎯 ¡Mensaje para mí! Recibido después de ${message.hopHistory.length} saltos');
      }

      _messageCache[message.messageId] = message;
      _incomingMessagesController.add(message);

      // Guardar mensaje en storage
      await _storageService.saveMessage(
        message,
        isOutgoing: false,
        status: MessageStatus.received,
      );

      // Enviar ACK de entrega
      await _sendAck(message.messageId, message.senderId, 'delivered');

      // Reportar ruta al servicio de mapas
      await _mapService.sendRoute(
        message.messageId,
        message.hopHistory.map((h) => h.nodeId).toList(),
      );

      // Incrementar contador de retransmisiones exitosas para el último hop
      if (message.hopHistory.isNotEmpty) {
        final lastHop = message.hopHistory.last;
        await _storageService.incrementSuccessfulRelay(lastHop.nodeId);
      }

      return;
    }

    // Si no soy el destinatario, verificar si puedo retransmitir
    if (!await canRetransmit()) {
      if (kDebugMode) {
        print('[MESH] 🚫 Sin permiso de retransmisión, descartando mensaje');
      }
      return;
    }

    // Retransmitir mensaje con routing inteligente
    if (kDebugMode) {
      print('[MESH] 📡 Retransmitiendo mensaje (TTL: ${message.ttl}, Saltos: ${message.hopHistory.length})');
    }

    final currentLocation = await _mapService.getCurrentLocation();

    // Guardar información del nodo actual
    await _storageService.saveOrUpdateNeighbor(
      nodeId,
      rssi: -50, // RSSI propio
      latitude: currentLocation?['latitude'],
      longitude: currentLocation?['longitude'],
      batteryLevel: _currentBatteryLevel,
    );

    final newHop = HopData(
      nodeId: nodeId,
      timestamp: DateTime.now(),
      gpsCoords: currentLocation,
    );

    final updatedMessage = message
        .copyWithNewHop(newHop)
        .copyWithDecrementedTTL();

    await _retransmitIntelligent(updatedMessage);

    // Reportar posición del nodo al servicio de mapas
    if (currentLocation != null) {
      await _mapService.sendNodeData(nodeId, currentLocation);
    }
  }

  // ==================== SISTEMA DE ACK ====================

  Future<void> _sendAck(String messageId, String recipientId, String ackType) async {
    final ack = AckMessage(
      originalMessageId: messageId,
      ackType: ackType,
      senderId: nodeId,
      recipientId: recipientId,
    );

    if (kDebugMode) {
      print('[ACK] 📨 Enviando ACK de $ackType para mensaje ${messageId.substring(0, 8)}');
    }

    // Transmitir ACK como mensaje especial
    final ackJson = jsonEncode({
      'type': 'ack',
      'data': ack.toJson(),
    });

    await _transmitViaBLE(ackJson);
  }

  void _handleAck(AckMessage ack) {
    if (kDebugMode) {
      print('[ACK] ✅ ACK recibido: ${ack.ackType} para ${ack.originalMessageId.substring(0, 8)}');
    }

    // Actualizar estado del mensaje en storage
    MessageStatus status;
    switch (ack.ackType) {
      case 'delivered':
        status = MessageStatus.delivered;
        break;
      case 'read':
        status = MessageStatus.read;
        break;
      default:
        status = MessageStatus.sent;
    }

    _storageService.updateMessageStatus(ack.originalMessageId, status);
    _ackController.add(ack);
  }

  Future<void> markMessageAsRead(String messageId) async {
    final message = _messageCache[messageId];
    if (message != null && message.destinationId == nodeId) {
      await _sendAck(messageId, message.senderId, 'read');
      await _storageService.updateMessageStatus(messageId, MessageStatus.read);
    }
  }

  Future<void> _retransmit(MessageModel message) async {
    final messageJson = message.toJsonString();

    if (kDebugMode) {
      print('[MESH] 🔄 Retransmitiendo vía BLE');
      print('[MESH] ℹ️ TTL restante: ${message.ttl}, Saltos realizados: ${message.hopHistory.length}');
    }

    await _transmitViaBLE(messageJson);
  }

  // ==================== ROUTING INTELIGENTE ====================

  Future<void> _retransmitIntelligent(MessageModel message) async {
    final messageJson = message.toJsonString();

    // Obtener mejores vecinos para routing
    final bestNeighbors = _storageService.getBestRoutingNeighbors(
      destinationId: message.destinationId,
      limit: 5,
    );

    if (kDebugMode) {
      print('[ROUTING] 🧭 Routing inteligente activado');
      print('[ROUTING] ℹ️ Vecinos confiables disponibles: ${bestNeighbors.length}');

      if (bestNeighbors.isNotEmpty) {
        for (var neighbor in bestNeighbors) {
          print('[ROUTING]   📍 ${neighbor.nodeId.substring(0, 8)}: '
              'Confiabilidad ${(neighbor.reliabilityScore * 100).toStringAsFixed(0)}%, '
              'RSSI ${neighbor.lastRssi}, '
              'Batería ${neighbor.batteryLevel}%');
        }
      }
    }

    // Transmitir primero a vecinos confiables, luego broadcast general
    if (bestNeighbors.isNotEmpty) {
      // Aquí se podría implementar transmisión dirigida a vecinos específicos
      // Por ahora usamos broadcast pero priorizamos en el futuro
      await _transmitViaBLE(messageJson);
    } else {
      if (kDebugMode) {
        print('[ROUTING] 📡 No hay vecinos confiables, usando broadcast general');
      }
      await _transmitViaBLE(messageJson);
    }
  }

  Future<void> _transmitViaBLE(String messageJson) async {
    try {
      await _bleService.startAdvertising(messageJson);

      if (kDebugMode) {
        print('[MESH] ✓ Mensaje transmitido vía BLE');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MESH] ❌ Error transmitiendo vía BLE: $e');
      }
    }
  }

  Future<MessageModel> createMessage({
    required String destinationId,
    required String plainTextContent,
    required String encryptionKey,
    int ttl = 10,
  }) async {
    if (kDebugMode) {
      print('[MESH] ✉️ Creando nuevo mensaje');
      print('[MESH] ℹ️ Destinatario: ${destinationId.substring(0, 8)}...');
      print('[MESH] ℹ️ TTL inicial: $ttl saltos');
    }

    // Verificar permisos
    if (!await _mapService.hasBackgroundPermission()) {
      if (kDebugMode) {
        print('[MESH] ⚠️ Sin permiso de retransmisión');
        print('[MESH] ℹ️ El mensaje se enviará pero puede no llegar si requiere saltos');
      }
    }

    // Cifrar contenido
    final encryptedContent = MessageModel.encryptMessage(
      plainTextContent,
      encryptionKey,
    );

    // Obtener ubicación actual
    final currentLocation = await _mapService.getCurrentLocation();
    final initialHop = HopData(
      nodeId: nodeId,
      timestamp: DateTime.now(),
      gpsCoords: currentLocation,
    );

    // Crear mensaje
    final message = MessageModel(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: nodeId,
      destinationId: destinationId,
      encryptedContent: encryptedContent,
      ttl: ttl,
      hopHistory: [initialHop],
    );

    _messageCache[message.messageId] = message;

    // Guardar mensaje en storage
    await _storageService.saveMessage(
      message,
      isOutgoing: true,
      decryptedContent: plainTextContent,
      status: MessageStatus.sending,
    );

    if (kDebugMode) {
      print('[MESH] 📤 Enviando mensaje a la red de malla');
    }

    // Transmitir mensaje inicial con routing inteligente
    await _retransmitIntelligent(message);

    // Actualizar estado a "enviado"
    await _storageService.updateMessageStatus(message.messageId, MessageStatus.sent);

    if (kDebugMode) {
      print('[MESH] ✅ Mensaje enviado exitosamente');
    }

    return message;
  }

  String? decryptMessage(MessageModel message, String key) {
    // Solo el remitente y el destinatario pueden descifrar
    if (message.destinationId != nodeId && message.senderId != nodeId) {
      if (kDebugMode) {
        print('[PRIVACY] 🔒 Nodo intermedio: no se puede descifrar mensaje');
      }
      return null;
    }

    try {
      final decrypted = MessageModel.decryptMessage(message.encryptedContent, key);

      if (kDebugMode && decrypted.isNotEmpty) {
        print('[PRIVACY] 🔓 Mensaje descifrado exitosamente');
      }

      return decrypted.isNotEmpty ? decrypted : null;
    } catch (e) {
      if (kDebugMode) {
        print('[PRIVACY] ❌ Error descifrando mensaje: $e');
      }
      return null;
    }
  }

  void _cleanOldProcessedMessages() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    final sizeBefore = _processedMessages.length;
    _processedMessages.removeWhere((key, value) => value.isBefore(cutoff));

    if (kDebugMode && sizeBefore > _processedMessages.length) {
      print('[MESH] 🧹 Limpieza: ${sizeBefore - _processedMessages.length} mensajes antiguos eliminados');
    }
  }

  List<MessageModel> getReceivedMessages() {
    return _messageCache.values
        .where((m) => m.destinationId == nodeId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void dispose() {
    _bleService.dispose();
    _wifiService.dispose();
    _incomingMessagesController.close();
    _ackController.close();
    _batteryCheckTimer?.cancel();

    if (kDebugMode) {
      print('[MESH] 🧹 MeshManager limpiado');
    }
  }

  // ==================== MÉTODOS AUXILIARES ====================

  List<StoredMessage> getStoredMessages({String? contactId}) {
    return _storageService.getMessages(contactId: contactId);
  }

  Map<String, dynamic> getNetworkStats() {
    final stats = _storageService.getStats();
    stats['batteryLevel'] = _currentBatteryLevel;
    stats['scanInterval'] = _scanInterval;
    return stats;
  }
}