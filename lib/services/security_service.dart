import '../config/security_constants.dart';

/// Entrada de blacklist con razón y timestamp
class BlacklistEntry {
  final String nodeId;
  final String reason;
  final DateTime timestamp;

  BlacklistEntry({
    required this.nodeId,
    required this.reason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Servicio de seguridad singleton para Orzion Mesh
/// 
/// Responsabilidades:
/// - Rate limiting por nodo
/// - Detección de mensajes duplicados
/// - Gestión de blacklist
/// - Logging de eventos de seguridad
/// - Detección de actividad sospechosa
/// 
/// TODO: Añadir test para rate limiting
/// TODO: Añadir test para detección de duplicados
/// TODO: Añadir test para blacklist
/// TODO: Añadir test para limpieza automática
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Rate Limiting: nodeId -> List de timestamps de mensajes recientes
  final Map<String, List<DateTime>> _messageTimes = {};

  // Detección de Duplicados: Map de messageIds con timestamp de cuando se vio
  // Cambio de Set a Map para poder limpiar mensajes expirados y evitar memory leaks
  final Map<String, DateTime> _seenMessageIds = {};

  // Blacklist: nodeId -> entrada de blacklist
  final Map<String, BlacklistEntry> _blacklist = {};

  // Contador de actividades sospechosas: nodeId -> contador
  final Map<String, int> _suspiciousActivityCount = {};

  // Log de eventos de seguridad (últimos 100)
  final List<SecurityEvent> _securityEvents = [];
  static const int _maxSecurityEvents = 100;

  /// Verifica si un nodo ha excedido el límite de rate
  /// 
  /// Reglas:
  /// - Máximo [SecurityConstants.maxMessagesPerMinute] mensajes por minuto
  /// - Limpia automáticamente entradas antiguas
  /// - Limita lista de timestamps a 100 máximo para evitar DoS/memory leaks
  /// 
  /// Retorna true si el nodo puede enviar, false si excede el límite
  /// 
  /// TODO: Añadir test para nodo que no excede límite
  /// TODO: Añadir test para nodo que excede límite
  /// TODO: Añadir test para limpieza de entradas antiguas
  bool checkRateLimit(String nodeId) {
    final now = DateTime.now();
    final windowStart = now.subtract(SecurityConstants.rateLimitWindow);

    // Obtener o crear lista de timestamps para este nodo
    if (!_messageTimes.containsKey(nodeId)) {
      _messageTimes[nodeId] = [];
    }

    final times = _messageTimes[nodeId]!;

    // Limpiar timestamps antiguos (fuera de la ventana)
    times.removeWhere((time) => time.isBefore(windowStart));

    // Verificar si se excede el límite
    if (times.length >= SecurityConstants.maxMessagesPerMinute) {
      logSecurityEvent(SecurityEvent(
        type: SecurityEventType.rateLimitExceeded,
        nodeId: nodeId,
        description: 'Nodo excedió el límite de ${SecurityConstants.maxMessagesPerMinute} mensajes por minuto',
        metadata: {'messageCount': times.length},
      ));
      
      reportSuspiciousActivity(nodeId, SecurityEventType.rateLimitExceeded);
      return false;
    }

    // Añadir timestamp actual
    times.add(now);
    
    // SEGURIDAD: Limitar tamaño de lista a 100 elementos máximo para evitar DoS
    // Si un nodo envía muchos mensajes, solo mantener los 100 más recientes
    if (times.length > 100) {
      // Ordenar por timestamp y mantener solo los 100 más recientes
      times.sort();
      while (times.length > 100) {
        times.removeAt(0);
      }
    }
    
    return true;
  }

  /// Verifica si un messageId es duplicado
  /// 
  /// Reglas:
  /// - Mantiene Map de messageIds con timestamps vistos en [SecurityConstants.duplicateDetectionWindow]
  /// - Limpia automáticamente mensajes expirados ANTES de verificar
  /// - Limita tamaño a [SecurityConstants.maxDuplicateCache]
  /// 
  /// Retorna true si es duplicado, false si es nuevo
  /// 
  /// TODO: Añadir test para mensaje nuevo
  /// TODO: Añadir test para mensaje duplicado
  /// TODO: Añadir test para límite de caché
  bool isDuplicate(String messageId) {
    final now = DateTime.now();
    final windowStart = now.subtract(SecurityConstants.duplicateDetectionWindow);
    
    // PRIMERO: Limpiar mensajes expirados para evitar memory leaks
    // Usar removeWhere en lugar de iterar y remover (evita ConcurrentModificationError)
    _seenMessageIds.removeWhere((id, timestamp) => timestamp.isBefore(windowStart));
    
    // SEGUNDO: Verificar si es duplicado
    if (_seenMessageIds.containsKey(messageId)) {
      return true;
    }

    // TERCERO: Añadir a map de vistos con timestamp actual
    _seenMessageIds[messageId] = now;

    // CUARTO: Limitar tamaño del map por seguridad (evitar DoS)
    if (_seenMessageIds.length > SecurityConstants.maxDuplicateCache) {
      // Remover los más antiguos hasta llegar al límite
      final entries = _seenMessageIds.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final toRemove = _seenMessageIds.length - SecurityConstants.maxDuplicateCache;
      for (int i = 0; i < toRemove; i++) {
        _seenMessageIds.remove(entries[i].key);
      }
    }

    return false;
  }

  /// Verifica si un nodo está en la blacklist
  /// 
  /// Reglas:
  /// - Verifica si el nodo está en la blacklist
  /// - Limpia automáticamente entradas expiradas (después de [SecurityConstants.blacklistDuration])
  /// 
  /// Retorna true si está en blacklist, false si no
  /// 
  /// TODO: Añadir test para nodo no bloqueado
  /// TODO: Añadir test para nodo bloqueado
  /// TODO: Añadir test para limpieza de blacklist expirada
  bool isBlacklisted(String nodeId) {
    if (!_blacklist.containsKey(nodeId)) {
      return false;
    }

    final entry = _blacklist[nodeId]!;
    final now = DateTime.now();
    final expirationTime = entry.timestamp.add(SecurityConstants.blacklistDuration);

    // Si ha expirado, remover de blacklist
    if (now.isAfter(expirationTime)) {
      _blacklist.remove(nodeId);
      logSecurityEvent(SecurityEvent(
        type: SecurityEventType.blacklistedNode,
        nodeId: nodeId,
        description: 'Nodo removido de blacklist (expirado)',
      ));
      return false;
    }

    return true;
  }

  /// Añade un nodo a la blacklist
  /// 
  /// Reglas:
  /// - Limita a [SecurityConstants.maxBlacklistSize] entradas
  /// - Si se excede, remueve la entrada más antigua
  /// 
  /// TODO: Añadir test para añadir nodo a blacklist
  /// TODO: Añadir test para límite de blacklist
  void addToBlacklist(String nodeId, String reason) {
    // Limitar tamaño de blacklist
    if (_blacklist.length >= SecurityConstants.maxBlacklistSize) {
      // Remover la entrada más antigua
      String? oldestNodeId;
      DateTime? oldestTime;

      _blacklist.forEach((key, value) {
        if (oldestTime == null || value.timestamp.isBefore(oldestTime!)) {
          oldestTime = value.timestamp;
          oldestNodeId = key;
        }
      });

      if (oldestNodeId != null) {
        _blacklist.remove(oldestNodeId);
      }
    }

    // Añadir a blacklist
    _blacklist[nodeId] = BlacklistEntry(
      nodeId: nodeId,
      reason: reason,
    );

    logSecurityEvent(SecurityEvent(
      type: SecurityEventType.blacklistedNode,
      nodeId: nodeId,
      description: 'Nodo añadido a blacklist: $reason',
    ));
  }

  /// Reporta actividad sospechosa de un nodo
  /// 
  /// Incrementa el contador de actividades sospechosas.
  /// Si alcanza [SecurityConstants.suspiciousActivityThreshold], añade a blacklist automáticamente.
  /// 
  /// TODO: Añadir test para reporte de actividad sospechosa
  /// TODO: Añadir test para blacklist automático por threshold
  void reportSuspiciousActivity(String nodeId, SecurityEventType type) {
    // Incrementar contador
    _suspiciousActivityCount[nodeId] = 
        (_suspiciousActivityCount[nodeId] ?? 0) + 1;

    final count = _suspiciousActivityCount[nodeId]!;

    logSecurityEvent(SecurityEvent(
      type: SecurityEventType.suspiciousActivity,
      nodeId: nodeId,
      description: 'Actividad sospechosa detectada: ${type.toString()}',
      metadata: {'count': count},
    ));

    // Si alcanza el threshold, añadir a blacklist
    if (count >= SecurityConstants.suspiciousActivityThreshold) {
      addToBlacklist(
        nodeId,
        'Threshold de actividad sospechosa alcanzado ($count eventos)'
      );
      
      // Reset contador después de blacklist
      _suspiciousActivityCount[nodeId] = 0;
    }
  }

  /// Registra un evento de seguridad
  /// 
  /// Mantiene los últimos [_maxSecurityEvents] eventos.
  /// Si se excede, remueve los más antiguos.
  /// 
  /// TODO: Añadir test para logging de eventos
  /// TODO: Añadir test para límite de eventos
  void logSecurityEvent(SecurityEvent event) {
    _securityEvents.add(event);

    // Limitar tamaño de la lista
    if (_securityEvents.length > _maxSecurityEvents) {
      _securityEvents.removeAt(0);
    }

    // Log en consola para debugging
    print('[SECURITY EVENT] ${event.type}: ${event.description} (Node: ${event.nodeId})');
  }

  /// Obtiene la lista de eventos de seguridad
  /// 
  /// Útil para estadísticas y auditoría
  /// Retorna una copia de la lista para evitar modificaciones externas
  /// 
  /// TODO: Añadir test para obtener eventos
  List<SecurityEvent> getSecurityEvents() {
    return List.unmodifiable(_securityEvents);
  }

  /// Obtiene eventos filtrados por tipo
  /// 
  /// TODO: Añadir test para filtrado por tipo
  List<SecurityEvent> getEventsByType(SecurityEventType type) {
    return _securityEvents
        .where((event) => event.type == type)
        .toList();
  }

  /// Obtiene eventos filtrados por nodo
  /// 
  /// TODO: Añadir test para filtrado por nodo
  List<SecurityEvent> getEventsByNode(String nodeId) {
    return _securityEvents
        .where((event) => event.nodeId == nodeId)
        .toList();
  }

  /// Obtiene estadísticas de seguridad
  /// 
  /// Retorna un mapa con estadísticas útiles
  /// 
  /// TODO: Añadir test para estadísticas
  Map<String, dynamic> getSecurityStats() {
    final stats = <String, dynamic>{};

    // Conteo por tipo de evento
    final eventCounts = <SecurityEventType, int>{};
    for (final event in _securityEvents) {
      eventCounts[event.type] = (eventCounts[event.type] ?? 0) + 1;
    }

    stats['totalEvents'] = _securityEvents.length;
    stats['eventsByType'] = eventCounts.map(
      (key, value) => MapEntry(key.toString(), value)
    );
    stats['blacklistedNodes'] = _blacklist.length;
    stats['seenMessages'] = _seenMessageIds.length;
    stats['activeRateLimits'] = _messageTimes.length;
    stats['suspiciousNodes'] = _suspiciousActivityCount.length;

    return stats;
  }

  /// Limpia datos antiguos y libera memoria
  /// 
  /// Debe llamarse periódicamente para mantener el rendimiento
  /// 
  /// TODO: Añadir test para limpieza
  void cleanup() {
    final now = DateTime.now();
    
    // Limpiar rate limiting de nodos inactivos
    final rateLimitWindowStart = now.subtract(SecurityConstants.rateLimitWindow);
    _messageTimes.removeWhere((nodeId, times) {
      times.removeWhere((time) => time.isBefore(rateLimitWindowStart));
      return times.isEmpty;
    });

    // Limpiar duplicados expirados (mensajes más viejos que duplicateDetectionWindow)
    final duplicateWindowStart = now.subtract(SecurityConstants.duplicateDetectionWindow);
    _seenMessageIds.removeWhere((messageId, timestamp) => timestamp.isBefore(duplicateWindowStart));

    // Limpiar blacklist expirada
    _blacklist.removeWhere((nodeId, entry) {
      final expirationTime = entry.timestamp.add(SecurityConstants.blacklistDuration);
      return now.isAfter(expirationTime);
    });

    // Resetear contadores de actividad sospechosa para nodos limpios
    // (Opcional: podrías mantenerlos por más tiempo si prefieres)
    _suspiciousActivityCount.removeWhere((nodeId, count) {
      // Remover si está en blacklist (ya fue penalizado)
      return _blacklist.containsKey(nodeId);
    });

    logSecurityEvent(SecurityEvent(
      type: SecurityEventType.suspiciousActivity,
      nodeId: 'SYSTEM',
      description: 'Limpieza de seguridad ejecutada',
      metadata: {
        'rateLimitsCleared': _messageTimes.length,
        'duplicatesSize': _seenMessageIds.length,
        'blacklistSize': _blacklist.length,
      },
    ));
  }

  /// Reset completo del servicio (útil para testing)
  /// 
  /// TODO: Añadir test para reset
  void reset() {
    _messageTimes.clear();
    _seenMessageIds.clear();
    _blacklist.clear();
    _suspiciousActivityCount.clear();
    _securityEvents.clear();
  }
}
