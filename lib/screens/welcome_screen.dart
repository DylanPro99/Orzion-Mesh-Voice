import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _navigationError;

  @override
  void initState() {
    super.initState();
    debugPrint('✅ WelcomeScreen inicializada correctamente');
  }

  void _navigateTo(String route, String routeName) {
    setState(() {
      _navigationError = null;
    });
    
    debugPrint('🔄 Intentando navegar a $routeName ($route)...');
    
    try {
      Navigator.pushReplacementNamed(context, route);
      debugPrint('✅ Navegación exitosa a $routeName');
    } catch (e, stackTrace) {
      debugPrint('❌ Error navegando a $routeName: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _navigationError = 'Error al navegar a $routeName:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.surface,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withOpacity(0.3),
                        AppColors.background.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.hub,
                    size: 120,
                    color: AppColors.gold,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.gold, AppColors.goldLight],
                  ).createShader(bounds),
                  child: const Text(
                    'Orzion Mesh',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'Red de comunicación distribuida',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.gold.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        Icons.lock,
                        'Cifrado de extremo a extremo',
                        'Mensajes protegidos con AES-256',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        Icons.route,
                        'Multi-salto automático',
                        'Alcance de hasta 500 metros',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        Icons.bluetooth,
                        'Red de malla BLE',
                        'Sin internet ni servidores centrales',
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Mostrar error de navegación si existe
                if (_navigationError != null)
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
                              'Error de Navegación',
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
                          _navigationError!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                ElevatedButton(
                  onPressed: () => _navigateTo('/onboarding', 'Onboarding'),
                  child: const Text(
                    'Comenzar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => _navigateTo('/home', 'Home'),
                  child: const Text(
                    'Ya tengo una cuenta',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withOpacity(0.3),
                AppColors.gold.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.gold,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
