import 'package:flutter/material.dart';
import '../services/mesh_manager.dart';
import '../services/map_data_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final MeshManager _meshManager = MeshManager();
  final MapDataService _mapService = MapDataService();
  
  int _currentPage = 0;
  bool _isInitializing = false;
  bool _hasGpsPermission = false;
  bool _hasBackgroundPermission = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      final gps = await _mapService.requestGpsPermission();
      final background = await _mapService.requestBackgroundPermission();

      setState(() {
        _hasGpsPermission = gps;
        _hasBackgroundPermission = background;
        _isInitializing = false;
      });

      if (gps || background) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gps && background
                  ? '✅ Permisos concedidos correctamente'
                  : '⚠️ Algunos permisos fueron denegados',
            ),
            backgroundColor: gps && background ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isInitializing = false;
      });

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

  Future<void> _completeOnboarding() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      await _meshManager.initializeNetworkServices();
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _isInitializing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error inicializando: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
        
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildPage1(),
              _buildPage2(),
              _buildPage3(),
            ],
          ),
          
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.blue
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                if (_currentPage < 2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          _pageController.jumpToPage(2);
                        },
                        child: const Text('Saltar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Siguiente'),
                      ),
                    ],
                  ),
                
                if (_currentPage == 2)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isInitializing ? null : _completeOnboarding,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isInitializing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Comenzar a usar Orzion Mesh',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 100,
            color: Colors.blue.shade600,
          ),
          const SizedBox(height: 32),
          const Text(
            'Privacidad y Seguridad',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Todos tus mensajes están protegidos con cifrado de extremo a extremo AES-256. Solo tú y tu destinatario pueden leerlos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sin servidores centrales. Tus datos son solo tuyos.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route,
            size: 100,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 32),
          const Text(
            'Red de Malla Distribuida',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Los mensajes viajan automáticamente a través de múltiples nodos. Cada salto puede cubrir 20-50 metros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.bluetooth, 'Bluetooth LE como transporte'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.devices, 'Hasta 10 saltos por mensaje'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.straighten, 'Alcance total: ~200-500m'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 100,
            color: Colors.orange.shade600,
          ),
          const SizedBox(height: 32),
          const Text(
            'Permisos Necesarios',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Para funcionar como nodo de la red de malla, necesitamos algunos permisos:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          _buildPermissionCard(
            icon: Icons.location_on,
            title: 'Ubicación (GPS)',
            description: 'Para rastrear la ruta de los mensajes',
            isGranted: _hasGpsPermission,
          ),
          const SizedBox(height: 16),
          _buildPermissionCard(
            icon: Icons.repeat,
            title: 'Segundo Plano',
            description: 'Para retransmitir mensajes cuando la app está cerrada',
            isGranted: _hasBackgroundPermission,
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isInitializing ? null : _requestPermissions,
              icon: const Icon(Icons.security),
              label: const Text('Conceder Permisos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? Colors.green : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isGranted ? Colors.green : Colors.grey.shade600,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.circle_outlined,
            color: isGranted ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }
}
