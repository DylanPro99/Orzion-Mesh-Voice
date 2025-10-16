import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/contact_model.dart';

class ContactsService {
  static final ContactsService _instance = ContactsService._internal();
  factory ContactsService() => _instance;
  ContactsService._internal();

  late Box<ContactModel> _contactsBox;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        print('[CONTACTS] 🚀 Inicializando servicio de contactos');
      }

      // Hive ya está inicializado por Hive.initFlutter() en main.dart
      // Solo abrir la caja de contactos
      _contactsBox = await Hive.openBox<ContactModel>('contacts');

      _isInitialized = true;
      
      if (kDebugMode) {
        print('[CONTACTS] ✅ Servicio de contactos inicializado correctamente');
        print('[CONTACTS] 📊 Contactos almacenados: ${_contactsBox.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error inicializando contactos: $e');
      }
      _isInitialized = false;
      // NO rethrow para evitar crash - permitir que la app continúe
    }
  }

  Future<void> addContact(String nodeId, String alias) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final contact = ContactModel(
        nodeId: nodeId,
        alias: alias,
        addedAt: DateTime.now(),
      );

      await _contactsBox.put(nodeId, contact);

      if (kDebugMode) {
        print('[CONTACTS] 👤 Contacto añadido: $alias ($nodeId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error añadiendo contacto: $e');
      }
      rethrow;
    }
  }

  Future<void> removeContact(String nodeId) async {
    try {
      if (!_isInitialized) return;

      await _contactsBox.delete(nodeId);

      if (kDebugMode) {
        print('[CONTACTS] 🗑️ Contacto eliminado: $nodeId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error eliminando contacto: $e');
      }
    }
  }

  List<ContactModel> getAllContacts() {
    try {
      if (!_isInitialized) return [];

      return _contactsBox.values.toList()
        ..sort((a, b) => a.alias.compareTo(b.alias));
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error obteniendo contactos: $e');
      }
      return [];
    }
  }

  ContactModel? getContact(String nodeId) {
    try {
      if (!_isInitialized) return null;

      return _contactsBox.get(nodeId);
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error obteniendo contacto: $e');
      }
      return null;
    }
  }

  String getDisplayName(String nodeId) {
    try {
      if (!_isInitialized) return 'Nodo ${nodeId.substring(0, 8)}...';

      final contact = _contactsBox.get(nodeId);
      return contact?.alias ?? 'Nodo ${nodeId.substring(0, 8)}...';
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error obteniendo nombre: $e');
      }
      return 'Nodo ${nodeId.substring(0, 8)}...';
    }
  }

  bool hasContact(String nodeId) {
    try {
      if (!_isInitialized) return false;

      return _contactsBox.containsKey(nodeId);
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error verificando contacto: $e');
      }
      return false;
    }
  }

  Future<void> updateContactAlias(String nodeId, String newAlias) async {
    try {
      if (!_isInitialized) return;

      final contact = _contactsBox.get(nodeId);
      if (contact != null) {
        final updatedContact = contact.copyWith(alias: newAlias);
        await _contactsBox.put(nodeId, updatedContact);

        if (kDebugMode) {
          print('[CONTACTS] 📝 Alias actualizado: $nodeId -> $newAlias');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error actualizando alias: $e');
      }
    }
  }

  Future<void> dispose() async {
    try {
      await _contactsBox.close();
      _isInitialized = false;
      
      if (kDebugMode) {
        print('[CONTACTS] 🧹 Servicio de contactos cerrado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CONTACTS] ❌ Error cerrando contactos: $e');
      }
    }
  }
}