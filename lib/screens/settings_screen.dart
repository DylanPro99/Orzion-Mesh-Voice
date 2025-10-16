import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mesh_manager.dart';
import '../services/map_data_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final MeshManager _meshManager = MeshManager();
  final MapDataService _mapService = MapDataService();
  
  bool _hasGpsPermission = false;
  bool _hasBackgroundPermission = false;
  bool _complianceChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final gps = _mapService.hasGpsConsent;
    final background = await _mapService.hasBackgroundPermission();
    final compliance = _meshManager.checkLegalCompliance();

    setState(() {
      _hasGpsPermission = gps;
      _hasBackgroundPermission = background;
      _complianceChecked = compliance;
    });
  }

  Future<void> _requestPermissions() async {
    try {
      final gps = await _mapService.requestGpsPermission();
      final background = await _mapService.requestBackgroundPermission();

      setState(() {
        _hasGpsPermission = gps;
        _hasBackgroundPermission = background;
      });

      _checkPermissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gps && background
                  ? '✅ Permisos actualizados correctamente'
                  : '⚠️ Algunos permisos fueron denegados',
            ),
            backgroundColor: gps && background ? AppColors.gold : AppColors.surfaceLight,
          ),
        );
      }
    } catch (e) {
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

  void _revokeGpsPermission() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Revocar Permiso GPS', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          '¿Estás seguro de que deseas revocar el permiso de GPS? Esto limitará la funcionalidad de tracking de rutas.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _mapService.revokeGpsConsent();
              Navigator.pop(context);
              _checkPermissions();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('GPS deshabilitado'),
                  backgroundColor: AppColors.gold,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
  }

  void _revokeBackgroundPermission() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Revocar Permiso de Segundo Plano', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          '¿Estás seguro? Sin este permiso, tu nodo NO podrá retransmitir mensajes cuando la app esté cerrada.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _mapService.revokeBackgroundConsent();
              Navigator.pop(context);
              _checkPermissions();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Retransmisión deshabilitada'),
                  backgroundColor: AppColors.gold,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(color: AppColors.gold),
        ),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _complianceChecked ? AppColors.surface : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _complianceChecked ? AppColors.gold : AppColors.grey,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _complianceChecked ? Icons.verified : Icons.warning,
                  color: _complianceChecked ? AppColors.gold : AppColors.grey,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _complianceChecked
                            ? 'Cumplimiento CONATEL'
                            : 'Cumplimiento Parcial',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _complianceChecked
                            ? 'Nodo conforme con regulaciones'
                            : 'Concede todos los permisos para cumplimiento total',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionTitle('Información del Nodo'),
          _buildInfoTile(
            icon: Icons.fingerprint,
            title: 'Node ID',
            subtitle: _meshManager.nodeId.substring(0, 24) + '...',
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _meshManager.nodeId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Node ID copiado')),
                );
              },
            ),
          ),
          
          const Divider(),
          
          _buildSectionTitle('Permisos y Privacidad'),
          _buildPermissionTile(
            icon: Icons.location_on,
            title: 'GPS',
            subtitle: _hasGpsPermission
                ? 'Habilitado - Tracking de rutas activo'
                : 'Deshabilitado - Sin tracking de rutas',
            isActive: _hasGpsPermission,
            onRevoke: _hasGpsPermission ? _revokeGpsPermission : null,
          ),
          _buildPermissionTile(
            icon: Icons.repeat,
            title: 'Retransmisión en Segundo Plano',
            subtitle: _hasBackgroundPermission
                ? 'Habilitado - Nodo retransmite mensajes'
                : 'Deshabilitado - Solo mensajería directa',
            isActive: _hasBackgroundPermission,
            onRevoke: _hasBackgroundPermission ? _revokeBackgroundPermission : null,
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar Permisos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const Divider(),
          
          _buildSectionTitle('Red de Malla'),
          _buildInfoTile(
            icon: Icons.bluetooth,
            title: 'Transporte',
            subtitle: 'Bluetooth Low Energy (BLE)',
            trailing: const Icon(Icons.check_circle, color: AppColors.gold),
          ),
          _buildInfoTile(
            icon: Icons.route,
            title: 'Alcance por Salto',
            subtitle: '20-50 metros',
            trailing: null,
          ),
          _buildInfoTile(
            icon: Icons.stairs,
            title: 'Máximo de Saltos',
            subtitle: '10 saltos (~200-500m total)',
            trailing: null,
          ),
          
          const Divider(),
          
          _buildSectionTitle('Seguridad'),
          _buildInfoTile(
            icon: Icons.lock,
            title: 'Cifrado',
            subtitle: 'AES-256 con IV aleatorio',
            trailing: const Icon(Icons.verified_user, color: AppColors.success),
          ),
          _buildInfoTile(
            icon: Icons.privacy_tip,
            title: 'Privacidad',
            subtitle: 'Nodos intermedios no leen mensajes',
            trailing: const Icon(Icons.verified_user, color: AppColors.success),
          ),
          
          const Divider(),
          
          _buildSectionTitle('Acerca de'),
          _buildInfoTile(
            icon: Icons.info,
            title: 'Versión',
            subtitle: '1.0.0 - Red de Malla Distribuida',
            trailing: null,
          ),
          _buildInfoTile(
            icon: Icons.gavel,
            title: 'Regulación',
            subtitle: 'Banda ISM 2.4 GHz no licenciada',
            trailing: null,
          ),
          
          const SizedBox(height: 32),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              'Orzion Mesh\nComunicación descentralizada y privada',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.gold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      trailing: trailing,
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    VoidCallback? onRevoke,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppColors.gold : AppColors.grey,
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            color: isActive ? AppColors.gold : AppColors.grey,
          ),
          if (onRevoke != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.block, color: AppColors.error),
              onPressed: onRevoke,
              tooltip: 'Revocar permiso',
            ),
          ],
        ],
      ),
    );
  }
}
