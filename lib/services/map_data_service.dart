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
    if (kDebugMode) {
      print('[PERMISSIONS] Solicitando permiso de GPS (doble opt-in)');
    }

    final locationStatus = await Permission.location.request();
    
    if (locationStatus.isGranted) {
      _hasGpsConsent = true;
      if (kDebugMode) {
        print('[PERMISSIONS] ✓ Permiso de GPS concedido');
      }
      return true;
    } else {
      if (kDebugMode) {
        print('[PERMISSIONS] ✗ Permiso de GPS denegado');
      }
      return false;
    }
  }

  Future<bool> requestBackgroundPermission() async {
    if (kDebugMode) {
      print('[PERMISSIONS] Solicitando permiso de uso en segundo plano (doble opt-in)');
    }

    final locationAlwaysStatus = await Permission.locationAlways.request();
    
    if (locationAlwaysStatus.isGranted) {
      _hasBackgroundConsent = true;
      if (kDebugMode) {
        print('[PERMISSIONS] ✓ Permiso de segundo plano concedido - Nodo puede retransmitir');
      }
      return true;
    } else {
      if (kDebugMode) {
        print('[PERMISSIONS] ✗ Permiso de segundo plano denegado - Nodo NO puede retransmitir');
      }
      return false;
    }
  }

  Future<Map<String, double>?> getCurrentLocation() async {
    if (!_hasGpsConsent) {
      if (kDebugMode) {
        print('[GPS] No se puede obtener ubicación - Sin consentimiento GPS');
      }
      return null;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('[GPS] Servicio de ubicación deshabilitado');
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _lastKnownPosition = position;

      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
      };
    } catch (e) {
      if (kDebugMode) {
        print('[GPS] Error obteniendo ubicación: $e');
      }
      return null;
    }
  }

  Future<void> sendNodeData(String nodeId, Map<String, double> gpsCoords) async {
    if (!_hasGpsConsent) {
      if (kDebugMode) {
        print('[MAP DATA] No se puede enviar datos de nodo - Sin consentimiento GPS');
      }
      return;
    }

    if (kDebugMode) {
      print('[MAP DATA] Enviando datos de nodo $nodeId: $gpsCoords');
    }

  }

  Future<void> sendRoute(String messageId, List<String> hopList) async {
    if (!_hasGpsConsent) {
      if (kDebugMode) {
        print('[MAP DATA] No se puede enviar ruta - Sin consentimiento GPS');
      }
      return;
    }

    if (kDebugMode) {
      print('[MAP DATA] Enviando ruta para mensaje $messageId');
      print('[MAP DATA] Ruta (${hopList.length} saltos): ${hopList.join(' -> ')}');
    }

  }

  Future<bool> hasBackgroundPermission() async {
    return _hasBackgroundConsent;
  }

  void revokeGpsConsent() {
    _hasGpsConsent = false;
    if (kDebugMode) {
      print('[PERMISSIONS] Consentimiento GPS revocado');
    }
  }

  void revokeBackgroundConsent() {
    _hasBackgroundConsent = false;
    if (kDebugMode) {
      print('[PERMISSIONS] Consentimiento de segundo plano revocado');
    }
  }

  Position? get lastKnownPosition => _lastKnownPosition;
}
