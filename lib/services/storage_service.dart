import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/stored_message.dart';
import '../models/neighbor_node.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Box<StoredMessage> _messagesBox;
  late Box<NeighborNode> _neighborsBox;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        print('[STORAGE] 🚀 Inicializando servicio de almacenamiento');
      }

      // Obtener directorio de documentos
      final directory = await getApplicationDocumentsDirectory();
      
      // Inicializar Hive con el directorio personalizado
      Hive.init(directory.path);

      // Abrir cajas de datos
      _messagesBox = await Hive.openBox<StoredMessage>('messages');
      _neighborsBox = await Hive.openBox<NeighborNode>('neighbors');

      _isInitialized = true;
      
      if (kDebugMode) {
        print('[STORAGE] ✅ Servicio de almacenamiento inicializado correctamente');
        print('[STORAGE] 📊 Mensajes almacenados: ${_messagesBox.length}');
        print('[STORAGE] 📊 Vecinos almacenados: ${_neighborsBox.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error inicializando almacenamiento: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> saveMessage(
    dynamic message, {
    required bool isOutgoing,
    String? decryptedContent,
    MessageStatus status = MessageStatus.sent,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final storedMessage = StoredMessage(
        messageId: message.messageId,
        senderId: message.senderId,
        destinationId: message.destinationId,
        encryptedContent: message.encryptedContent,
        timestamp: message.createdAt ?? DateTime.now(),
        hopCount: message.hopHistory?.length ?? 0,
        status: status,
        isOutgoing: isOutgoing,
        decryptedContent: decryptedContent,
      );

      await _messagesBox.put(message.messageId, storedMessage);

      if (kDebugMode) {
        print('[STORAGE] 💾 Mensaje guardado: ${message.messageId.substring(0, 8)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error guardando mensaje: $e');
      }
    }
  }

  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    try {
      if (!_isInitialized) return;

      final message = _messagesBox.get(messageId);
      if (message != null) {
        final updatedMessage = message.copyWith(status: status);
        await _messagesBox.put(messageId, updatedMessage);

        if (kDebugMode) {
          print('[STORAGE] 📝 Estado actualizado: $messageId -> $status');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error actualizando estado: $e');
      }
    }
  }

  List<StoredMessage> getMessages({String? contactId}) {
    try {
      if (!_isInitialized) return [];

      final messages = _messagesBox.values.toList();
      
      if (contactId != null) {
        return messages.where((msg) => 
          msg.senderId == contactId || msg.destinationId == contactId
        ).toList();
      }
      
      return messages;
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error obteniendo mensajes: $e');
      }
      return [];
    }
  }

  Future<void> saveOrUpdateNeighbor(
    String nodeId, {
    String? nodeName,
    int? rssi,
    double? latitude,
    double? longitude,
    int? batteryLevel,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final existing = _neighborsBox.get(nodeId);
      final now = DateTime.now();

      final neighbor = existing?.copyWith(
        nodeName: nodeName ?? existing.nodeName,
        lastRssi: rssi ?? existing.lastRssi,
        lastSeen: now,
        latitude: latitude ?? existing.latitude,
        longitude: longitude ?? existing.longitude,
        batteryLevel: batteryLevel ?? existing.batteryLevel,
      ) ?? NeighborNode(
        nodeId: nodeId,
        nodeName: nodeName,
        lastRssi: rssi ?? -100,
        lastSeen: now,
        latitude: latitude,
        longitude: longitude,
        batteryLevel: batteryLevel ?? 100,
      );

      await _neighborsBox.put(nodeId, neighbor);

      if (kDebugMode) {
        print('[STORAGE] 👥 Vecino actualizado: ${nodeId.substring(0, 8)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error guardando vecino: $e');
      }
    }
  }

  Future<void> incrementSuccessfulRelay(String nodeId) async {
    try {
      if (!_isInitialized) return;

      final neighbor = _neighborsBox.get(nodeId);
      if (neighbor != null) {
        final updated = neighbor.copyWith(
          successfulRelays: neighbor.successfulRelays + 1,
        );
        await _neighborsBox.put(nodeId, updated);

        if (kDebugMode) {
          print('[STORAGE] ✅ Relay exitoso incrementado para ${nodeId.substring(0, 8)}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error incrementando relay exitoso: $e');
      }
    }
  }

  List<NeighborNode> getBestRoutingNeighbors({
    String? destinationId,
    int limit = 5,
  }) {
    try {
      if (!_isInitialized) return [];

      final neighbors = _neighborsBox.values
          .where((n) => n.isActive && n.isReliable)
          .toList();

      // Ordenar por confiabilidad y señal
      neighbors.sort((a, b) {
        final scoreA = a.reliabilityScore * (a.signalStrength / 4.0);
        final scoreB = b.reliabilityScore * (b.signalStrength / 4.0);
        return scoreB.compareTo(scoreA);
      });

      return neighbors.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error obteniendo mejores vecinos: $e');
      }
      return [];
    }
  }

  Map<String, dynamic> getStats() {
    try {
      if (!_isInitialized) return {};

      final messages = _messagesBox.values.toList();
      final neighbors = _neighborsBox.values.toList();

      return {
        'totalMessages': messages.length,
        'sentMessages': messages.where((m) => m.isOutgoing).length,
        'receivedMessages': messages.where((m) => !m.isOutgoing).length,
        'activeNeighbors': neighbors.where((n) => n.isActive).length,
        'reliableNeighbors': neighbors.where((n) => n.isReliable).length,
        'totalRelays': neighbors.fold(0, (sum, n) => sum + n.successfulRelays),
      };
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error obteniendo estadísticas: $e');
      }
      return {};
    }
  }

  Future<void> clearOldData() async {
    try {
      if (!_isInitialized) return;

      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      
      // Limpiar mensajes antiguos
      final oldMessages = _messagesBox.values
          .where((msg) => msg.timestamp.isBefore(cutoff))
          .map((msg) => msg.messageId)
          .toList();

      for (final messageId in oldMessages) {
        await _messagesBox.delete(messageId);
      }

      // Limpiar vecinos inactivos
      final inactiveNeighbors = _neighborsBox.values
          .where((n) => !n.isActive && n.timeSinceLastSeen.inDays > 7)
          .map((n) => n.nodeId)
          .toList();

      for (final nodeId in inactiveNeighbors) {
        await _neighborsBox.delete(nodeId);
      }

      if (kDebugMode) {
        print('[STORAGE] 🧹 Limpieza completada: ${oldMessages.length} mensajes, ${inactiveNeighbors.length} vecinos');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error en limpieza: $e');
      }
    }
  }

  Future<void> dispose() async {
    try {
      await _messagesBox.close();
      await _neighborsBox.close();
      _isInitialized = false;
      
      if (kDebugMode) {
        print('[STORAGE] 🧹 Servicio de almacenamiento cerrado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[STORAGE] ❌ Error cerrando almacenamiento: $e');
      }
    }
  }
}