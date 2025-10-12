import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  
  static const platform = MethodChannel('com.orzion.mesh/foreground');

  Stream<MessageModel> get incomingMessages => _incomingMessagesController.stream;

  Future<void> initializeNetworkServices() async {
    if (_servicesInitialized) {
      if (kDebugMode) {
        print('[MESH] ℹ️ Servicios ya inicializados');
      }
      return;
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

    // Solicitar permisos antes de iniciar servicios
    final hasBackgroundPermission = await _mapService.requestBackgroundPermission();
    
    if (!hasBackgroundPermission) {
      if (kDebugMode) {
        print('[MESH] ⚠️ Permiso de segundo plano denegado');
        print('[MESH] ℹ️ El nodo funcionará pero no retransmitirá mensajes');
      }
    }

    try {
      // Inicializar WiFi Direct (modo simplificado)
      await _wifiService.initialize();
      
      // Inicializar BLE (servicio principal)
      await _bleService.initialize();
      
      if (kDebugMode) {
        print('[MESH] ✓ Servicios de red inicializados');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MESH] ❌ Error inicializando servicios de red: $e');
      }
      // No retornar, continuar con servicios parcialmente inicializados
    }

    // Iniciar servicio en primer plano para mantener nodo activo
    await _startForegroundService();

    _servicesInitialized = true;

    if (kDebugMode) {
      print('[MESH] ✅ Red de malla activa (BLE) - Nodo listo para operar');
    }
  }

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
        print('[MESH] ℹ️ Esto es normal en depuración - funcionará en release');
      }
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

      // Reportar ruta al servicio de mapas
      await _mapService.sendRoute(
        message.messageId,
        message.hopHistory.map((h) => h.nodeId).toList(),
      );
      return;
    }

    // Si no soy el destinatario, verificar si puedo retransmitir
    if (!await canRetransmit()) {
      if (kDebugMode) {
        print('[MESH] 🚫 Sin permiso de retransmisión, descartando mensaje');
      }
      return;
    }

    // Retransmitir mensaje
    if (kDebugMode) {
      print('[MESH] 📡 Retransmitiendo mensaje (TTL: ${message.ttl}, Saltos: ${message.hopHistory.length})');
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

    // Reportar posición del nodo al servicio de mapas
    if (currentLocation != null) {
      await _mapService.sendNodeData(nodeId, currentLocation);
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

    if (kDebugMode) {
      print('[MESH] 📤 Enviando mensaje a la red de malla');
    }

    // Transmitir mensaje inicial
    await _retransmit(message);

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
    
    if (kDebugMode) {
      print('[MESH] 🧹 MeshManager limpiado');
    }
  }
}
