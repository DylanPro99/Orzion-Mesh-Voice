import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/mesh_manager.dart';
import 'services/map_data_service.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final String _encryptionKey = 'default-key-2025';
  
  bool _complianceChecked = false;
  bool _hasGpsPermission = false;
  bool _hasBackgroundPermission = false;

  @override
  void initState() {
    super.initState();
    _checkCompliance();
    _meshManager.incomingMessages.listen((message) {
      setState(() {});
    });
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
    if (_messageController.text.isEmpty || _destinationController.text.isEmpty) {
      return;
    }

    await _meshManager.createMessage(
      destinationId: _destinationController.text,
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
                Text(
                  'Nodo ID: ${_meshManager.nodeId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: 'ID del Destinatario',
                    border: OutlineInputBorder(),
                  ),
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
                          title: Text('De: ${message.senderId}'),
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
    super.dispose();
  }
}
