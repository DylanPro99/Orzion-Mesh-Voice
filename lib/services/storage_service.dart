import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/stored_message.dart';
import '../models/neighbor_node.dart';
import '../models/message_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Box<StoredMessage>? _messagesBox;
  Box<NeighborNode>? _neighborsBox;
  bool _isInitialized = false;
  bool _isInitializing = false; // 🔒 Lock para prevenir doble inicialización
  Exception? _initializationError; // 🔒 Guardar error de inicialización

  Future<void> initialize() async {
    // 🔒 Prevenir race condition: Si ya está inicializado, retornar
    if (_isInitialized) {
      if (kDebugMode) {
        print('[STORAGE] ℹ️ Storage ya inicializado, omitiendo');
      }
      return;
    }
    
    // 🔒 Si hubo error previo, re-lanzarlo
    if (_initializationError != null) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Re-lanzando error de inicialización previa');
      }
      throw _initializationError!;
    }
    
    // 🔒 Si otro thread está inicializando, esperar y verificar resultado
    if (_isInitializing) {
      if (kDebugMode) {
        print('[STORAGE] ⏳ Storage inicializándose, esperando...');
      }
      // Esperar hasta que termine la inicialización en curso (máximo 10 segundos)
      final startTime = DateTime.now();
      while (_isInitializing && 
             !_isInitialized && 
             DateTime.now().difference(startTime).inSeconds < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Verificar resultado después de la espera
      if (_isInitialized) {
        if (kDebugMode) {
          print('[STORAGE] ✅ Storage inicializado por otro thread');
        }
        return;
      } else if (_initializationError != null) {
        if (kDebugMode) {
          print('[STORAGE] ❌ Inicialización falló en otro thread');
        }
        throw _initializationError!;
      } else {
        throw Exception('Timeout esperando inicialización de Storage');
      }
    }

    _isInitializing = true;

    try {
      if (kDebugMode) {
        print('[STORAGE] 🚀 Iniciando Storage...');
      }
      
      // Abrir las boxes
      _messagesBox = await Hive.openBox<StoredMessage>('messages');
      _neighborsBox = await Hive.openBox<NeighborNode>('neighbors');

      _isInitialized = true;

      if (kDebugMode) {
        print('[STORAGE] ✅ Storage inicializado correctamente');
        print('[STORAGE] 📨 Mensajes almacenados: ${_messagesBox!.length}');
        print('[STORAGE] 👥 Vecinos conocidos: ${_neighborsBox!.length}');
      }
    } catch (e, stackTrace) {
      // 🔒 Guardar error para re-lanzarlo en llamadas futuras
      _initializationError = Exception('Error inicializando Storage: $e');
      
      if (kDebugMode) {
        print('[STORAGE] ❌ Error crítico inicializando storage: $e');
        print('[STORAGE] Stack trace: $stackTrace');
      }
      rethrow; // Re-lanzar error para que main.dart lo capture
    } finally {
      _isInitializing = false;
    }
  }

  // ==================== MENSAJES ====================

  Future<void> saveMessage(MessageModel message, {
    required bool isOutgoing,
    String? decryptedContent,
    MessageStatus? status,
  }) async {
    if (!_isInitialized || _messagesBox == null) {
      await initialize();
    }

    final storedMessage = StoredMessage(
      messageId: message.messageId,
      senderId: message.senderId,
      destinationId: message.destinationId,
      encryptedContent: message.encryptedContent,
      timestamp: message.createdAt,
      hopCount: message.hopHistory.length,
      status: status ?? (isOutgoing ? MessageStatus.sent : MessageStatus.received),
      isOutgoing: isOutgoing,
      decryptedContent: decryptedContent,
    );

    await _messagesBox?.put(message.messageId, storedMessage);

    if (kDebugMode) {
      print('[STORAGE] 💾 Mensaje guardado: ${message.messageId.substring(0, 8)}');
    }
  }

  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    if (!_isInitialized || _messagesBox == null) return;

    final message = _messagesBox?.get(messageId);
    if (message != null) {
      final updated = message.copyWith(status: status);
      await _messagesBox?.put(messageId, updated);

      if (kDebugMode) {
        print('[STORAGE] 📝 Estado actualizado: $messageId -> $status');
      }
    }
  }

  List<StoredMessage> getMessages({String? contactId, int limit = 100}) {
    if (!_isInitialized || _messagesBox == null) return [];

    var messages = _messagesBox!.values.toList();

    // Filtrar por contacto si se especifica
    if (contactId != null) {
      messages = messages.where((m) => 
        m.senderId == contactId || m.destinationId == contactId
      ).toList();
    }

    // Ordenar por timestamp descendente (más reciente primero)
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Limitar cantidad
    if (messages.length > limit) {
      messages = messages.sublist(0, limit);
    }

    return messages;
  }

  StoredMessage? getMessage(String messageId) {
    if (!_isInitialized || _messagesBox == null) return null;
    return _messagesBox?.get(messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    if (!_isInitialized || _messagesBox == null) return;
    await _messagesBox?.delete(messageId);
  }

  Future<void> clearOldMessages({int daysToKeep = 30}) async {
    if (!_isInitialized || _messagesBox == null) return;

    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final oldMessages = _messagesBox!.values
        .where((m) => m.timestamp.isBefore(cutoffDate))
        .toList();

    for (var message in oldMessages) {
      await _messagesBox?.delete(message.messageId);
    }

    if (kDebugMode) {
      print('[STORAGE] 🧹 ${oldMessages.length} mensajes antiguos eliminados');
    }
  }

  // ==================== VECINOS ====================

  Future<void> saveOrUpdateNeighbor(
    String nodeId, {
    String? nodeName,
    required int rssi,
    double? latitude,
    double? longitude,
    int? batteryLevel,
  }) async {
    if (!_isInitialized || _neighborsBox == null) {
      await initialize();
    }

    var neighbor = _neighborsBox?.get(nodeId);

    if (neighbor == null) {
      // Crear nuevo vecino
      neighbor = NeighborNode(
        nodeId: nodeId,
        nodeName: nodeName,
        lastRssi: rssi,
        lastSeen: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        batteryLevel: batteryLevel ?? 100,
      );
    } else {
      // Actualizar vecino existente
      neighbor = neighbor.copyWith(
        nodeName: nodeName,
        lastRssi: rssi,
        lastSeen: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        batteryLevel: batteryLevel,
      );
    }

    await _neighborsBox?.put(nodeId, neighbor);

    if (kDebugMode) {
      print('[STORAGE] 👤 Vecino actualizado: ${nodeId.substring(0, 8)} (RSSI: $rssi)');
    }
  }

  Future<void> incrementSuccessfulRelay(String nodeId) async {
    if (!_isInitialized || _neighborsBox == null) return;

    final neighbor = _neighborsBox?.get(nodeId);
    if (neighbor != null) {
      final updated = neighbor.copyWith(
        successfulRelays: neighbor.successfulRelays + 1,
      );
      await _neighborsBox?.put(nodeId, updated);
    }
  }

  Future<void> incrementFailedRelay(String nodeId) async {
    if (!_isInitialized || _neighborsBox == null) return;

    final neighbor = _neighborsBox?.get(nodeId);
    if (neighbor != null) {
      final updated = neighbor.copyWith(
        failedRelays: neighbor.failedRelays + 1,
      );
      await _neighborsBox?.put(nodeId, updated);
    }
  }

  List<NeighborNode> getActiveNeighbors({int limit = 10}) {
    if (!_isInitialized || _neighborsBox == null) return [];

    var neighbors = _neighborsBox!.values
        .where((n) => n.isActive)
        .toList();

    // Ordenar por confiabilidad y señal
    neighbors.sort((a, b) {
      // Primero por confiabilidad
      final reliabilityCompare = b.reliabilityScore.compareTo(a.reliabilityScore);
      if (reliabilityCompare != 0) return reliabilityCompare;
      
      // Luego por RSSI
      return b.lastRssi.compareTo(a.lastRssi);
    });

    if (neighbors.length > limit) {
      neighbors = neighbors.sublist(0, limit);
    }

    return neighbors;
  }

  List<NeighborNode> getAllNeighbors() {
    if (!_isInitialized || _neighborsBox == null) return [];

    var neighbors = _neighborsBox!.values.toList();
    
    // Ordenar por última vez visto
    neighbors.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    
    return neighbors;
  }

  NeighborNode? getNeighbor(String nodeId) {
    if (!_isInitialized || _neighborsBox == null) return null;
    return _neighborsBox?.get(nodeId);
  }

  List<NeighborNode> getBestRoutingNeighbors({
    required String destinationId,
    int limit = 5,
  }) {
    if (!_isInitialized || _neighborsBox == null) return [];

    var neighbors = _neighborsBox!.values
        .where((n) => n.isActive && n.reliabilityScore > 0.5)
        .toList();

    // Ordenar por múltiples factores
    neighbors.sort((a, b) {
      // Factor 1: Confiabilidad (peso 40%)
      final reliabilityScore = (b.reliabilityScore - a.reliabilityScore) * 0.4;
      
      // Factor 2: Señal RSSI (peso 30%)
      final rssiScore = ((b.lastRssi - a.lastRssi) / 100) * 0.3;
      
      // Factor 3: Batería (peso 20%)
      final batteryScore = ((b.batteryLevel - a.batteryLevel) / 100) * 0.2;
      
      // Factor 4: Actividad reciente (peso 10%)
      final activityScore = (a.timeSinceLastSeen.inSeconds - b.timeSinceLastSeen.inSeconds) / 300 * 0.1;
      
      final totalScore = reliabilityScore + rssiScore + batteryScore + activityScore;
      return totalScore > 0 ? 1 : (totalScore < 0 ? -1 : 0);
    });

    if (neighbors.length > limit) {
      neighbors = neighbors.sublist(0, limit);
    }

    return neighbors;
  }

  Future<void> cleanupInactiveNeighbors({int hoursToKeep = 24}) async {
    if (!_isInitialized || _neighborsBox == null) return;

    final cutoffTime = DateTime.now().subtract(Duration(hours: hoursToKeep));
    final inactiveNeighbors = _neighborsBox!.values
        .where((n) => n.lastSeen.isBefore(cutoffTime))
        .toList();

    for (var neighbor in inactiveNeighbors) {
      await _neighborsBox?.delete(neighbor.nodeId);
    }

    if (kDebugMode) {
      print('[STORAGE] 🧹 ${inactiveNeighbors.length} vecinos inactivos eliminados');
    }
  }

  // ==================== ESTADÍSTICAS ====================

  Map<String, dynamic> getStats() {
    if (!_isInitialized) return {};

    final totalMessages = _messagesBox?.length ?? 0;
    final sentMessages = _messagesBox?.values.where((m) => m.isOutgoing).length ?? 0;
    final receivedMessages = totalMessages - sentMessages;
    final totalNeighbors = _neighborsBox?.length ?? 0;
    final activeNeighbors = _neighborsBox?.values.where((n) => n.isActive).length ?? 0;

    return {
      'totalMessages': totalMessages,
      'sentMessages': sentMessages,
      'receivedMessages': receivedMessages,
      'totalNeighbors': totalNeighbors,
      'activeNeighbors': activeNeighbors,
    };
  }
}
