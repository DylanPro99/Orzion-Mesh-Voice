import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class MapDataService {
  static final MapDataService _instance = MapDataService._internal();
  factory MapDataService() => _instance;
  MapDataService._internal();

  bool _hasGpsConsent = false;
  bool _hasBackgroundConsent = false;
  Position? _lastKnownPosition;
  Timer? _locationUpdateTimer;

  bool get hasGpsConsent => _hasGpsConsent;
  bool get hasBackgroundConsent => _hasBackgroundConsent;

  Future<bool> requestGpsPermission() async {
    if (kDebugMode) {
      print('[PERMISSIONS] 📍 Solicitando permiso de GPS (doble opt-in)');
    }

    try {
      final locationStatus = await Permission.location.request();
      
      if (locationStatus.isGranted) {
        _hasGpsConsent = true;
        
        if (kDebugMode) {
          print('[PERMISSIONS] ✅ Permiso de GPS concedido');
        }
        
        // Iniciar actualización periódica de ubicación
        _startLocationUpdates();
        
        return true;
      } else {
        if (kDebugMode) {
          print('[PERMISSIONS] ❌ Permiso de GPS denegado');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PERMISSIONS] ⚠️ Error solicitando permiso GPS: $e');
      }
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (kDebugMode) {
      print('[PERMISSIONS] 🔔 Solicitando permiso de notificaciones (Android 13+)');
    }

    try {
      final notificationStatus = await Permission.notification.request();
      
      if (notificationStatus.isGranted) {
        if (kDebugMode) {
          print('[PERMISSIONS] ✅ Permiso de notificaciones concedido');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('[PERMISSIONS] ⚠️ Permiso de notificaciones denegado');
          print('[PERMISSIONS] ℹ️ El servicio en primer plano puede no funcionar correctamente');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PERMISSIONS] ⚠️ Error solicitando permiso de notificaciones: $e');
      }
      return false;
    }
  }

  Future<bool> requestBackgroundPermission() async {
    if (kDebugMode) {
      print('[PERMISSIONS] 🔄 Solicitando permiso de uso en segundo plano (doble opt-in)');
    }

    try {
      // Primero solicitar ubicación básica si no se tiene
      if (!_hasGpsConsent) {
        await requestGpsPermission();
      }

      // NOTA: El permiso de notificaciones ya debe haberse solicitado antes
      // No lo volvemos a solicitar aquí para evitar prompts duplicados

      final locationAlwaysStatus = await Permission.locationAlways.request();
      
      if (locationAlwaysStatus.isGranted) {
        _hasBackgroundConsent = true;
        
        if (kDebugMode) {
          print('[PERMISSIONS] ✅ Permiso de segundo plano concedido');
          print('[PERMISSIONS] ℹ️ Nodo puede retransmitir mensajes en segundo plano');
        }
        
        return true;
      } else if (locationAlwaysStatus.isDenied || locationAlwaysStatus.isPermanentlyDenied) {
        if (kDebugMode) {
          print('[PERMISSIONS] ❌ Permiso de segundo plano denegado');
          print('[PERMISSIONS] ⚠️ Nodo NO podrá retransmitir mensajes en segundo plano');
        }
        return false;
      } else {
        // Si solo tiene permiso cuando se usa la app, aún es útil
        _hasBackgroundConsent = false;
        
        if (kDebugMode) {
          print('[PERMISSIONS] ⚠️ Solo se concedió ubicación "mientras se usa la app"');
        }
        
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PERMISSIONS] ⚠️ Error solicitando permiso de segundo plano: $e');
      }
      return false;
    }
  }

  void _startLocationUpdates() {
    // OPTIMIZACIÓN BATERÍA: Actualizar ubicación cada 2 minutos (120 segundos)
    // Los nodos de malla no necesitan actualizaciones GPS tan frecuentes
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 120), (timer) {
      if (_hasGpsConsent) {
        getCurrentLocation();
      }
    });
  }

  Future<Map<String, double>?> getCurrentLocation() async {
    if (!_hasGpsConsent) {
      if (kDebugMode) {
        print('[GPS] ⚠️ No se puede obtener ubicación - Sin consentimiento GPS');
      }
      return null;
    }

    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('[GPS] ⚠️ Servicio de ubicación deshabilitado en el dispositivo');
        }
        return _getLastKnownLocationAsMap();
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('[GPS] ❌ Permiso de ubicación denegado');
          }
          return _getLastKnownLocationAsMap();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('[GPS] ❌ Permiso de ubicación denegado permanentemente');
        }
        return _getLastKnownLocationAsMap();
      }

      // Obtener ubicación actual
      Position? position;
      
      try {
        // OPTIMIZACIÓN BATERÍA: Usar precisión media en lugar de alta
        // LocationAccuracy.medium es suficiente para tracking de mesh network
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        ).timeout(
          const Duration(seconds: 6),
          onTimeout: () async {
            if (kDebugMode) {
              print('[GPS] ⏱️ Timeout obteniendo ubicación, usando última conocida');
            }
            
            // Intentar obtener última ubicación conocida
            final lastPosition = await Geolocator.getLastKnownPosition();
            if (lastPosition != null) {
              return lastPosition;
            }
            
            if (_lastKnownPosition != null) {
              return _lastKnownPosition!;
            }
            
            // Si no hay ninguna ubicación, lanzar excepción
            throw TimeoutException('No se pudo obtener ubicación');
          },
        );
      } on TimeoutException {
        if (kDebugMode) {
          print('[GPS] ⚠️ Timeout sin ubicación disponible');
        }
        return _getLastKnownLocationAsMap();
      }

      if (position != null) {
        _lastKnownPosition = position;
      }

      if (kDebugMode) {
        print('[GPS] ✅ Ubicación obtenida: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
      }

      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
      };
    } catch (e) {
      if (kDebugMode) {
        print('[GPS] ⚠️ Error obteniendo ubicación: $e');
      }
      return _getLastKnownLocationAsMap();
    }
  }

  Map<String, double>? _getLastKnownLocationAsMap() {
    if (_lastKnownPosition != null) {
      return {
        'lat': _lastKnownPosition!.latitude,
        'lng': _lastKnownPosition!.longitude,
        'accuracy': _lastKnownPosition!.accuracy,
      };
    }
    return null;
  }

  Future<void> sendNodeData(String nodeId, Map<String, double> gpsCoords) async {
    if (!_hasGpsConsent) {
      if (kDebugMode) {
        print('[MAP DATA] ⚠️ No se puede enviar datos de nodo - Sin consentimiento GPS');
      }
      return;
    }

    if (kDebugMode) {
      print('[MAP DATA] 📍 Reportando posición del nodo');
      print('[MAP DATA] ℹ️ Nodo: ${nodeId.substring(0, 8)}...');
      print('[MAP DATA] ℹ️ Coords: ${gpsCoords['lat']?.toStringAsFixed(6)}, ${gpsCoords['lng']?.toStringAsFixed(6)}');
    }

    // Aquí se enviaría al servidor de visualización de mapas
    // Por ahora solo registramos en debug
  }

  Future<void> sendRoute(String messageId, List<String> hopList) async {
    if (!_hasGpsConsent) {
      if (kDebugMode) {
        print('[MAP DATA] ⚠️ No se puede enviar ruta - Sin consentimiento GPS');
      }
      return;
    }

    if (kDebugMode) {
      print('[MAP DATA] 🗺️ Reportando ruta del mensaje');
      print('[MAP DATA] ℹ️ Mensaje: ${messageId.substring(0, 8)}...');
      print('[MAP DATA] ℹ️ Ruta (${hopList.length} ${hopList.length == 1 ? "salto" : "saltos"}):');
      for (int i = 0; i < hopList.length; i++) {
        print('[MAP DATA]    ${i + 1}. ${hopList[i].substring(0, 8)}...');
      }
    }

    // Aquí se enviaría al servidor de visualización de mapas
    // Por ahora solo registramos en debug
  }

  Future<bool> hasBackgroundPermission() async {
    return _hasBackgroundConsent;
  }

  void revokeGpsConsent() {
    _hasGpsConsent = false;
    _locationUpdateTimer?.cancel();
    
    if (kDebugMode) {
      print('[PERMISSIONS] 🚫 Consentimiento GPS revocado');
    }
  }

  void revokeBackgroundConsent() {
    _hasBackgroundConsent = false;
    
    if (kDebugMode) {
      print('[PERMISSIONS] 🚫 Consentimiento de segundo plano revocado');
    }
  }

  Position? get lastKnownPosition => _lastKnownPosition;

  void dispose() {
    _locationUpdateTimer?.cancel();
    
    if (kDebugMode) {
      print('[MAP DATA] 🧹 MapDataService limpiado');
    }
  }
}
