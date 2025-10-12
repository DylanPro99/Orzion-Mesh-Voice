import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/mesh_manager.dart';
import '../services/map_data_service.dart';
import '../theme/app_theme.dart';
import 'loading_screen.dart';

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
  String? _initError;
  String? _permissionError;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isInitializing = true;
      _permissionError = null;
    });

    try {
      debugPrint('🔐 Solicitando permisos...');
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
            backgroundColor: gps && background ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error solicitando permisos: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _isInitializing = false;
        _permissionError = e.toString();
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (!mounted) return;
    
    setState(() {
      _initError = null;
    });
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoadingScreen(
          message: 'Inicializando Orzion Mesh...',
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      debugPrint('🚀 Iniciando servicios de red...');
      final hasFullFunctionality = await _meshManager.initializeNetworkServices();
      
      if (mounted) {
        if (!hasFullFunctionality) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ Funcionalidad limitada: La app solo funciona en primer plano.\n\nActiva permisos en Configuración para funcionalidad completa.'),
              backgroundColor: AppColors.gold,
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Orzion Mesh activado completamente'),
              backgroundColor: AppColors.gold,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error crítico durante inicialización: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
        
        Navigator.pop(context); // Volver a onboarding
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}\n\nVerifica permisos en Configuración.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'OK',
              textColor: AppColors.gold,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                            ? AppColors.gold
                            : AppColors.greyDark,
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
            color: AppColors.gold,
          ),
          const SizedBox(height: 32),
          const Text(
            'Privacidad y Seguridad',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Todos tus mensajes están protegidos con cifrado de extremo a extremo AES-256. Solo tú y tu destinatario pueden leerlos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user, color: AppColors.gold),
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
            color: AppColors.gold,
          ),
          const SizedBox(height: 32),
          const Text(
            'Red de Malla Distribuida',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Los mensajes viajan automáticamente a través de múltiples nodos. Cada salto puede cubrir 20-50 metros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
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
            color: AppColors.gold,
          ),
          const SizedBox(height: 32),
          const Text(
            'Permisos Necesarios',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Para funcionar como nodo de la red de malla, necesitamos algunos permisos:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          // Mostrar error de permisos si existe
          if (_permissionError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Error al Solicitar Permisos',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _permissionError!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          
          // Mostrar error de inicialización si existe
          if (_initError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Error de Inicialización',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _initError!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          
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
        Icon(icon, size: 20, color: AppColors.gold),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
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
        color: isGranted ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? AppColors.gold : AppColors.greyDark,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isGranted ? AppColors.gold : AppColors.grey,
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.circle_outlined,
            color: isGranted ? AppColors.gold : AppColors.grey,
          ),
        ],
      ),
    );
  }
}
