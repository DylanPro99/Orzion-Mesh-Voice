
import 'package:hive_flutter/hive_flutter.dart';
import '../models/contact_model.dart';

class ContactsService {
  static const String _boxName = 'contacts';
  Box<Map>? _contactsBox;

  Future<void> init() async {
    _contactsBox = await Hive.openBox<Map>(_boxName);
  }

  Future<void> addContact(String nodeId, String alias) async {
    final contact = ContactModel(nodeId: nodeId, alias: alias);
    await _contactsBox?.put(nodeId, contact.toJson());
  }

  Future<void> removeContact(String nodeId) async {
    await _contactsBox?.delete(nodeId);
  }

  List<ContactModel> getAllContacts() {
    if (_contactsBox == null) return [];
    return _contactsBox!.values
        .map((data) => ContactModel.fromJson(Map<String, dynamic>.from(data)))
        .toList()
      ..sort((a, b) => a.alias.compareTo(b.alias));
  }

  ContactModel? getContact(String nodeId) {
    final data = _contactsBox?.get(nodeId);
    if (data == null) return null;
    return ContactModel.fromJson(Map<String, dynamic>.from(data));
  }

  String getDisplayName(String nodeId) {
    final contact = getContact(nodeId);
    return contact?.alias ?? nodeId.substring(0, 8);
  }
}
