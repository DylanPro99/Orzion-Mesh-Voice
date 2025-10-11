import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/mesh_manager.dart';
import 'services/map_data_service.dart';
import 'services/contacts_service.dart';
import 'models/message_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const OrzionMeshVoiceApp());
}

class OrzionMeshVoiceApp extends StatelessWidget {
  const OrzionMeshVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orzion Mesh-Voice',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MeshManager _meshManager = MeshManager();
  final MapDataService _mapService = MapDataService();
  final ContactsService _contactsService = ContactsService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final String _encryptionKey = 'default-key-2025';
  
  bool _complianceChecked = false;
  bool _hasGpsPermission = false;
  bool _hasBackgroundPermission = false;
  String? _selectedContactId;

  @override
  void initState() {
    super.initState();
    _initServices();
    _checkCompliance();
    _meshManager.incomingMessages.listen((message) {
      setState(() {});
    });
  }

  Future<void> _initServices() async {
    await _contactsService.init();
    await _meshManager.initializeNetworkServices();
    setState(() {});
  }

  void _checkCompliance() {
    final isCompliant = _meshManager.checkLegalCompliance();
    setState(() {
      _complianceChecked = isCompliant;
    });
  }

  Future<void> _requestPermissions() async {
    final gps = await _mapService.requestGpsPermission();
    final background = await _mapService.requestBackgroundPermission();
    
    setState(() {
      _hasGpsPermission = gps;
      _hasBackgroundPermission = background;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS: ${gps ? "✓" : "✗"} | Segundo plano: ${background ? "✓" : "✗"}',
          ),
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final destinationId = _selectedContactId ?? _destinationController.text;
    
    if (_messageController.text.isEmpty || destinationId.isEmpty) {
      return;
    }

    await _meshManager.createMessage(
      destinationId: destinationId,
      plainTextContent: _messageController.text,
      encryptionKey: _encryptionKey,
    );

    _messageController.clear();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje enviado a la red de malla')),
      );
    }
  }

  Future<void> _showAddContactDialog() async {
    _destinationController.clear();
    _aliasController.clear();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Node ID del contacto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Nombre / Alias',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_destinationController.text.isNotEmpty &&
                  _aliasController.text.isNotEmpty) {
                await _contactsService.addContact(
                  _destinationController.text,
                  _aliasController.text,
                );
                setState(() {});
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _meshManager.getReceivedMessages();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Orzion Mesh-Voice MVP'),
        actions: [
          IconButton(
            icon: Icon(
              _complianceChecked ? Icons.verified : Icons.warning,
              color: _complianceChecked ? Colors.green : Colors.red,
            ),
            onPressed: _checkCompliance,
            tooltip: 'Verificar cumplimiento CONATEL',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nodo ID: ${_meshManager.nodeId.substring(0, 16)}...',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _meshManager.nodeId),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Node ID copiado al portapapeles'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      tooltip: 'Copiar Node ID completo',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'GPS: ${_hasGpsPermission ? "✓ Activo" : "✗ Inactivo"}',
                        style: TextStyle(
                          color: _hasGpsPermission ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Retransmisión: ${_hasBackgroundPermission ? "✓ Activo" : "✗ Inactivo"}',
                        style: TextStyle(
                          color: _hasBackgroundPermission ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _requestPermissions,
                  child: const Text('Solicitar Permisos (Doble Opt-in)'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedContactId,
                        decoration: const InputDecoration(
                          labelText: 'Destinatario',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Seleccionar contacto...'),
                          ),
                          ..._contactsService.getAllContacts().map(
                                (contact) => DropdownMenuItem(
                                  value: contact.nodeId,
                                  child: Text(contact.alias),
                                ),
                              ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedContactId = value;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: _showAddContactDialog,
                      tooltip: 'Añadir contacto',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sendMessage,
                    child: const Text('Enviar Mensaje'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Mensajes Recibidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('No hay mensajes recibidos'),
                  )
                : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final decrypted = _meshManager.decryptMessage(
                        message,
                        _encryptionKey,
                      );
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.message),
                          title: Text(
                            'De: ${_contactsService.getDisplayName(message.senderId)}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(decrypted ?? '[Encriptado]'),
                              Text(
                                '${message.hopHistory.length} saltos | TTL: ${message.ttl}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _destinationController.dispose();
    _aliasController.dispose();
    super.dispose();
  }
}
