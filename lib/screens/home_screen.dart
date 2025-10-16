import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mesh_manager.dart';
import '../services/contacts_service.dart';
import '../services/encryption_service.dart';
import '../models/message_model.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MeshManager _meshManager = MeshManager();
  final ContactsService _contactsService = ContactsService();
  final EncryptionService _encryptionService = EncryptionService();
  final TextEditingController _messageController = TextEditingController();
  
  bool _isMeshInitialized = false;
  bool _isMeshInitializing = true;
  String? _meshError;
  String? _encryptionKey;
  String? _selectedContactId;
  
  @override
  void initState() {
    super.initState();
    _initializeMesh();
    _setupMessageListener();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeMesh() async {
    setState(() {
      _isMeshInitializing = true;
      _meshError = null;
    });

    try {
      debugPrint('🚀 Inicializando Protocolo Mesh...');
      
      try {
        _encryptionKey = await _encryptionService.getOrCreateEncryptionKey();
        debugPrint('✅ Clave de cifrado generada');
      } catch (e) {
        debugPrint('⚠️ Error generando clave de cifrado: $e');
      }
      
      try {
        await _contactsService.init();
        debugPrint('✅ Servicio de contactos iniciado');
      } catch (e) {
        debugPrint('⚠️ Error inicializando contactos: $e');
      }
      
      final hasFullFunctionality = await _meshManager.initializeNetworkServices();
      
      if (mounted) {
        setState(() {
          _isMeshInitialized = true;
          _isMeshInitializing = false;
        });

        if (!hasFullFunctionality) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Funcionalidad limitada: La app solo funciona en primer plano'),
              backgroundColor: AppColors.gold,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Protocolo Mesh activado correctamente'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        debugPrint('✅ Protocolo Mesh inicializado correctamente');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR DE CONEXIÓN MESH: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isMeshInitialized = false;
          _isMeshInitializing = false;
          _meshError = 'ERROR DE CONEXIÓN MESH: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ERROR DE CONEXIÓN MESH\n${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _setupMessageListener() {
    _meshManager.incomingMessages.listen((message) {
      if (mounted) {
        setState(() {});
        _showMessageNotification(message);
      }
    });
  }

  void _showMessageNotification(MessageModel message) {
    if (!mounted) return;
    
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

  Future<void> _sendMessage() async {
    final destinationId = _selectedContactId;
    final messageText = _messageController.text.trim();
    
    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Escribe un mensaje')),
      );
      return;
    }

    if (destinationId == null || destinationId.isEmpty) {
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
            backgroundColor: AppColors.gold,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error enviando mensaje: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showAddContactDialog() async {
    final destinationController = TextEditingController();
    final aliasController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Node ID del contacto',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fingerprint),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: aliasController,
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
              if (destinationController.text.trim().isNotEmpty &&
                  aliasController.text.trim().isNotEmpty) {
                await _contactsService.addContact(
                  destinationController.text.trim(),
                  aliasController.text.trim(),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Text(
              'Orzion Mesh',
              style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            if (_isMeshInitializing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              )
            else if (_isMeshInitialized)
              const Icon(Icons.check_circle, color: AppColors.success, size: 20)
            else
              const Icon(Icons.error, color: AppColors.error, size: 20),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.gold),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Configuración',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isMeshInitializing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Conectando al Protocolo Mesh...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (_meshError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.error,
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _meshError!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.greyDark),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.router, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nodo: ${_meshManager.nodeId.substring(0, 16)}...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: AppColors.gold),
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
                      child: DropdownButtonFormField<String?>(
                        value: _selectedContactId,
                        decoration: const InputDecoration(
                          labelText: 'Destinatario',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
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
                  enabled: _isMeshInitialized && !_isMeshInitializing,
                  decoration: InputDecoration(
                    labelText: 'Mensaje',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.message),
                    hintText: _isMeshInitialized 
                        ? 'Escribe tu mensaje cifrado...' 
                        : 'Esperando conexión Mesh...',
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isMeshInitialized && !_isMeshInitializing) ? _sendMessage : null,
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
          
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mensajes Recibidos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (messages.isNotEmpty)
                  Chip(
                    label: Text(
                      '${messages.length}',
                      style: const TextStyle(color: AppColors.background),
                    ),
                    backgroundColor: AppColors.gold,
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
                        Icon(Icons.inbox, size: 64, color: AppColors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay mensajes recibidos',
                          style: TextStyle(color: AppColors.textSecondary),
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
                        color: AppColors.surface,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.gold.withOpacity(0.2),
                            child: const Icon(Icons.message, color: AppColors.gold),
                          ),
                          title: Text(
                            'De: $senderName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                decrypted ?? '[Mensaje cifrado]',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.route, size: 14, color: AppColors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${message.hopHistory.length} saltos',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
