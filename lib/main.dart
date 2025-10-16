import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/storage_service.dart';
import 'models/stored_message.dart';
import 'models/neighbor_node.dart';
import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  String? globalInitError;
  
  // Capturar errores de Flutter Framework
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };
  
  try {
    debugPrint('🚀 Iniciando Orzion Mesh...');
    await Hive.initFlutter();
    
    // Registrar adaptadores de Hive
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(StoredMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MessageStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(NeighborNodeAdapter());
    }
    
    // Inicializar storage
    await StorageService().initialize();
    
    debugPrint('✅ Hive inicializado correctamente');
  } catch (e, stackTrace) {
    debugPrint('❌ Error crítico inicializando app: $e');
    debugPrint('Stack trace: $stackTrace');
    globalInitError = '$e\n\nStack:\n${stackTrace.toString()}';
  }
  
  runApp(OrzionMeshVoiceApp(globalInitError: globalInitError));
}

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orzion Mesh - Error',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: AppColors.error,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Error Crítico de Inicialización',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    error,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontFamily: 'monospace',
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
}

class OrzionMeshVoiceApp extends StatelessWidget {
  final String? globalInitError;
  
  const OrzionMeshVoiceApp({super.key, this.globalInitError});

  @override
  Widget build(BuildContext context) {
    // Si hay error global, mostrar pantalla de error
    if (globalInitError != null) {
      return ErrorApp(error: globalInitError!);
    }
    
    return MaterialApp(
      title: 'Orzion Mesh-Voice',
      theme: AppTheme.darkTheme,
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/loading': (context) => const LoadingScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
