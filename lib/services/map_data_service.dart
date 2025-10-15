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

  bool get hasGpsConsent => _hasGpsConsent;
  bool get hasBackgroundConsent => _hasBackgroundConsent;

  Future<bool> requestGpsPermission() async {
    try {
      if (kDebugMode) {
        print('[MAP] 🔐 Solicitando permiso de ubicación...');
      }

      final permission = await Permission.location.request();
      
      if (permission == PermissionStatus.granted) {
        _hasGpsConsent = true;
        if (kDebugMode) {
          print('[MAP] ✅ Permiso de ubicación concedido');
        }
        return true;
      } else {
        _hasGpsConsent = false;
        if (kDebugMode) {
          print('[MAP] ❌ Permiso de ubicación denegado');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MAP] ❌ Error solicitando permiso de ubicación: $e');
      }
      return false;
    }
  }

  Future<bool> requestBackgroundPermission() async {
    try {
      if (kDebugMode) {
        print('[MAP] 🔐 Solicitando permiso de ubicación en segundo plano...');
      }

      final permission = await Permission.locationAlways.request();
      
      if (permission == PermissionStatus.granted) {
        _hasBackgroundConsent = true;
        if (kDebugMode) {
          print('[MAP] ✅ Permiso de ubicación en segundo plano concedido');
        }
        return true;
      } else {
        _hasBackgroundConsent = false;
        if (kDebugMode) {
          print('[MAP] ❌ Permiso de ubicación en segundo plano denegado');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MAP] ❌ Error solicitando permiso de segundo plano: $e');
      }
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      if (kDebugMode) {
        print('[MAP] 🔐 Solicitando permiso de notificaciones...');
      }

      final permission = await Permission.notification.request();
      
      if (permission == PermissionStatus.granted) {
        if (kDebugMode) {
          print('[MAP] ✅ Permiso de notificaciones concedido');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('[MAP] ❌ Permiso de notificaciones denegado');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MAP] ❌ Error solicitando permiso de notificaciones: $e');
      }
      return false;
    }
  }

  Future<bool> hasBackgroundPermission() async {
    try {
      final permission = await Permission.locationAlways.status;
      return permission == PermissionStatus.granted;
    } catch (e) {
      if (kDebugMode) {
        print('[MAP] ❌ Error verificando permiso de segundo plano: $e');
      }
      return false;
    }
  }

  Future<Map<String, double>?> getCurrentLocation() async {
    try {
      if (!_hasGpsConsent) {
        if (kDebugMode) {
          print('[MAP] ⚠️ Sin permiso de ubicación, usando ubicación por defecto');
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      _lastKnownPosition = position;

      if (kDebugMode) {
        print('[MAP] 📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}');
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      if (kDebugMode) {
        print('[MAP] ❌ Error obteniendo ubicación: $e');
      }
      return null;
    }
  }

  Future<void> sendRoute(String messageId, List<String> hopNodeIds) async {
    try {
      if (kDebugMode) {
        print('[MAP] 🗺️ Enviando ruta del mensaje $messageId');
        print('[MAP] 📍 Saltos: ${hopNodeIds.length}');
      }
      
      // En una implementación real, aquí se enviaría la información de ruta
      // a un servicio de mapeo o almacenamiento
      
    } catch (e) {
      if (kDebugMode) {
        print('[MAP] ❌ Error enviando ruta: $e');
      }
    }
  }

  Future<void> sendNodeData(String nodeId, Map<String, double> location) async {
    try {
      if (kDebugMode) {
        print('[MAP] 📍 Enviando datos del nodo $nodeId');
        print('[MAP] 📍 Ubicación: ${location['latitude']}, ${location['longitude']}');
      }
      
      // En una implementación real, aquí se enviaría la información del nodo
      // a un servicio de mapeo o almacenamiento
      
    } catch (e) {
      if (kDebugMode) {
        print('[MAP] ❌ Error enviando datos del nodo: $e');
      }
    }
  }
}