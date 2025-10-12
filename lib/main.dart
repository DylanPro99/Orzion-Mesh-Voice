import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/mesh_manager.dart';
import 'services/map_data_service.dart';
import 'services/contacts_service.dart';
import 'services/encryption_service.dart';
import 'models/message_model.dart';
import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Hive.initFlutter();
  } catch (e) {
    debugPrint('❌ Error inicializando Hive: $e');
  }
  
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
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final MeshManager _meshManager = MeshManager();
  final MapDataService _mapService = MapDataService();
  final ContactsService _contactsService = ContactsService();
  final EncryptionService _encryptionService = EncryptionService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  String? _encryptionKey;
  
  bool _complianceChecked = false;
  bool _hasGpsPermission = false;
  bool _hasBackgroundPermission = false;
  String? _selectedContactId;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
    _checkCompliance();
    _meshManager.incomingMessages.listen((message) {
      if (mounted) {
        setState(() {});
        _showMessageNotification(message);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _destinationController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  void _showMessageNotification(MessageModel message) {
    if (!mounted) return;
    
    final decrypted = _encryptionKey != null
        ? _meshManager.decryptMessage(message, _encryptionKey!)
        : null;
    final senderName = _contactsService.getDisplayName(message.senderId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📨 Mensaje de $senderName (${message.hopHistory.length} saltos)'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () {
            setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _initServices() async {
    if (_isInitializing) return;
    
    setState(() {
      _isInitializing = true;
    });

    try {
      // Obtener o generar clave de cifrado segura
      _encryptionKey = await _encryptionService.getOrCreateEncryptionKey();
      
      await _contactsService.init();
      await _meshManager.initializeNetworkServices();
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error inicializando servicios: $e');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error al inicializar: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _checkCompliance() {
    final isCompliant = _meshManager.checkLegalCompliance();
    if (mounted) {
      setState(() {
        _complianceChecked = isCompliant;
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final gps = await _mapService.requestGpsPermission();
      final background = await _mapService.requestBackgroundPermission();
      
      if (mounted) {
        setState(() {
          _hasGpsPermission = gps;
          _hasBackgroundPermission = background;
        });

        _checkCompliance();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gps && background
                  ? '✅ Permisos concedidos - Nodo activo'
                  : '⚠️ Permisos faltantes - Funcionalidad limitada',
            ),
            backgroundColor: gps && background ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error solicitando permisos: $e');
    }
  }

  Future<void> _sendMessage() async {
    final destinationId = _selectedContactId ?? _destinationController.text.trim();
    final messageText = _messageController.text.trim();
    
    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Escribe un mensaje')),
      );
      return;
    }

    if (destinationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Selecciona un destinatario')),
      );
      return;
    }

    if (_encryptionKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Clave de cifrado no disponible')),
      );
      return;
    }

    try {
      await _meshManager.createMessage(
        destinationId: destinationId,
        plainTextContent: messageText,
        encryptionKey: _encryptionKey!,
      );

      _messageController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mensaje enviado a la red de malla'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error enviando mensaje: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                prefixIcon: Icon(Icons.fingerprint),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Nombre / Alias',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
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
              if (_destinationController.text.trim().isNotEmpty &&
                  _aliasController.text.trim().isNotEmpty) {
                await _contactsService.addContact(
                  _destinationController.text.trim(),
                  _aliasController.text.trim(),
                );
                setState(() {});
                if (context.mounted) Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Contacto añadido')),
                );
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
        title: const Text('Orzion Mesh-Voice'),
        actions: [
          IconButton(
            icon: Icon(
              _complianceChecked ? Icons.verified : Icons.warning,
              color: _complianceChecked ? Colors.green : Colors.orange,
            ),
            onPressed: _checkCompliance,
            tooltip: 'Verificar cumplimiento CONATEL',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Configuración',
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de información del nodo
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.router, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nodo: ${_meshManager.nodeId.substring(0, 16)}...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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
                            content: Text('✅ Node ID copiado'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      tooltip: 'Copiar Node ID completo',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusChip(
                        'GPS',
                        _hasGpsPermission,
                        Icons.location_on,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusChip(
                        'Retransmisión',
                        _hasBackgroundPermission,
                        Icons.repeat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isInitializing ? null : _requestPermissions,
                    icon: const Icon(Icons.security),
                    label: const Text('Solicitar Permisos (Doble Opt-in)'),
                  ),
                ),
              ],
            ),
          ),
          
          // Panel de envío de mensajes
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
                          prefixIcon: Icon(Icons.person_outline),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.message),
                    hintText: 'Escribe tu mensaje cifrado...',
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isInitializing ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar Mensaje Cifrado'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Lista de mensajes recibidos
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mensajes Recibidos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (messages.isNotEmpty)
                  Chip(
                    label: Text('${messages.length}'),
                    backgroundColor: Colors.blue.shade100,
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay mensajes recibidos',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final decrypted = _encryptionKey != null 
                          ? _meshManager.decryptMessage(message, _encryptionKey!)
                          : null;
                      final senderName = _contactsService.getDisplayName(message.senderId);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.message, color: Colors.blue),
                          ),
                          title: Text(
                            'De: $senderName',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                decrypted ?? '🔒 [Mensaje cifrado]',
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.route,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${message.hopHistory.length} ${message.hopHistory.length == 1 ? "salto" : "saltos"} • TTL: ${message.ttl}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
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

  Widget _buildStatusChip(String label, bool isActive, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.green.shade900 : Colors.red.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: isActive ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }
}
