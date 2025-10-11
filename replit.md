# Orzion Mesh-Voice (OMV) - MVP

## Descripción del Proyecto

Orzion Mesh-Voice es una red de comunicaciones descentralizada de malla (mesh network) que opera en el espectro no licenciado de 2.4 GHz, cumpliendo estrictamente con las regulaciones CONATEL de Venezuela. La aplicación permite mensajería peer-to-peer con retransmisión multi-salto, cifrado de extremo a extremo, y visualización de rutas en un mapa de credibilidad.

## Fecha de Creación
11 de Octubre, 2025

## Stack Tecnológico

### Framework Principal
- **Flutter 3.27.1** - Framework multiplataforma (Web, Android)
- **Dart 3.6.0** - Lenguaje de programación

### Dependencias Clave

#### Seguridad y Encriptación
- `crypto: ^3.0.3` - Funciones criptográficas
- `encrypt: ^5.0.3` - Cifrado AES con IV aleatorio

#### Conectividad de Malla
- `flutter_blue_plus: ^1.32.12` - Bluetooth Low Energy (BLE)
- `flutter_p2p_connection: ^3.0.3` - WiFi Direct P2P

#### Almacenamiento Local
- `hive_flutter: ^1.1.0` - Base de datos NoSQL local
- `path_provider: ^2.1.4` - Acceso al sistema de archivos

#### Ubicación y Permisos
- `geolocator: ^13.0.2` - Servicios GPS
- `permission_handler: ^11.3.1` - Gestión de permisos del sistema

#### Utilidades
- `uuid: ^4.5.1` - Generación de identificadores únicos

## Arquitectura del Proyecto

### Estructura de Directorios

```
lib/
├── models/
│   └── message_model.dart        # Modelo de mensaje con cifrado
├── services/
│   ├── mesh_manager.dart          # Lógica de enrutamiento de malla
│   └── map_data_service.dart      # Servicio de ubicación y mapa
└── main.dart                      # UI principal y punto de entrada
```

### Componentes Principales

#### 1. MessageModel (`lib/models/message_model.dart`)
- **Propósito**: Estructura de datos para mensajes en la red de malla
- **Características**:
  - Cifrado AES con IV aleatorio por mensaje
  - Tracking de saltos (hop history) con ubicación GPS
  - TTL (Time-to-Live) decremental
  - Serialización/deserialización JSON

**Campos principales**:
- `messageId`: Identificador único del mensaje
- `senderId`: ID del nodo emisor
- `destinationId`: ID del nodo destinatario
- `encryptedContent`: Contenido cifrado con AES
- `ttl`: Contador de saltos restantes
- `hopHistory`: Lista de nodos por los que ha pasado el mensaje

#### 2. MeshManager (`lib/services/mesh_manager.dart`)
- **Propósito**: Núcleo del algoritmo de enrutamiento de malla
- **Características**:
  - Verificación de cumplimiento regulatorio CONATEL
  - Lógica de retransmisión multi-salto
  - Gestión de caché de mensajes procesados
  - Privacidad: nodos repetidores no descifran mensajes

**Métodos clave**:
- `checkLegalCompliance()`: Verifica cumplimiento de regulaciones
- `forwardMessage()`: Procesa y retransmite mensajes
- `createMessage()`: Crea y envía nuevos mensajes
- `decryptMessage()`: Descifra solo si es destinatario o emisor

#### 3. MapDataService (`lib/services/map_data_service.dart`)
- **Propósito**: Gestión de permisos y datos de ubicación
- **Características**:
  - Sistema de doble opt-in (GPS + segundo plano)
  - Obtención de coordenadas GPS
  - Envío de datos al servidor de visualización

**Métodos clave**:
- `requestGpsPermission()`: Solicita permiso de ubicación
- `requestBackgroundPermission()`: Solicita permiso de segundo plano
- `getCurrentLocation()`: Obtiene coordenadas GPS actuales
- `sendNodeData()`: Envía datos de nodo al mapa
- `sendRoute()`: Envía ruta de mensaje al mapa

## Cumplimiento Regulatorio CONATEL

### Restricciones Implementadas

#### 1. Potencia de Transmisión
- ✅ Uso exclusivo de APIs oficiales de BLE (flutter_blue_plus)
- ✅ Uso exclusivo de APIs oficiales de WiFi Direct (flutter_p2p_connection)
- ✅ **No se modifica** la potencia de transmisión
- ✅ Operación en límites ISM de 2.4 GHz

#### 2. Control de Frecuencias
- ✅ Operación exclusiva en banda no licenciada de 2.4 GHz
- ✅ Sin intento de modificar frecuencias fuera de lo permitido

#### 3. Consentimiento Explícito (Doble Opt-in)
- ✅ **Permiso GPS**: Obligatorio para enviar datos al mapa
- ✅ **Permiso de Segundo Plano**: Obligatorio para ser nodo de retransmisión
- ✅ La app no funciona sin consentimientos explícitos

#### 4. Privacidad y Anonimato
- ✅ Nodos repetidores **no descifran** mensajes
- ✅ Solo se leen metadatos esenciales (destinationId, TTL)
- ✅ Contenido cifrado permanece opaco para repetidores

#### 5. Seguridad
- ✅ Cifrado AES con IV aleatorio por mensaje
- ✅ No se exponen claves de cifrado
- ✅ Caché de mensajes procesados para evitar loops

## Algoritmo de Enrutamiento de Malla

### Flujo de Mensaje

1. **Creación**:
   - Usuario crea mensaje con texto plano
   - Sistema cifra con AES + IV aleatorio
   - Se asigna TTL inicial (default: 10)
   - Se registra hop inicial con ubicación GPS

2. **Transmisión**:
   - Mensaje se serializa a JSON
   - Se transmite via BLE y/o WiFi Direct
   - Nodos vecinos reciben el mensaje

3. **Recepción y Procesamiento**:
   - Verificar si mensaje ya fue procesado (prevenir loops)
   - Verificar TTL > 0
   - Si soy destinatario → descifrar y mostrar
   - Si no soy destinatario → evaluar retransmisión

4. **Retransmisión**:
   - Verificar permiso de segundo plano
   - Decrementar TTL
   - Agregar hop actual con ubicación
   - Retransmitir a nodos vecinos
   - Reportar ruta al servidor de visualización

### Heurística de Salto
- **Actual**: Retransmisión básica a todos los vecinos
- **Futura**: Heurística de menor distancia percibida basada en:
  - Potencia de señal recibida (RSSI)
  - Distancia geográfica estimada
  - Historial de entrega exitosa

## Estado de Implementación del MVP

### ✅ Completado

1. **Modelos de Datos**
   - ✅ MessageModel con cifrado AES + IV aleatorio
   - ✅ HopData con tracking de ubicación

2. **Servicios Core**
   - ✅ MeshManager con lógica de enrutamiento
   - ✅ MapDataService con gestión de permisos
   - ✅ Sistema de verificación de cumplimiento

3. **Interfaz de Usuario**
   - ✅ Pantalla principal con mensajería
   - ✅ Visualización de ID de nodo
   - ✅ Estado de permisos (GPS, segundo plano)
   - ✅ Lista de mensajes recibidos
   - ✅ Indicador de cumplimiento CONATEL

4. **Configuración**
   - ✅ Dependencias instaladas
   - ✅ Workflow de Flutter Web configurado
   - ✅ App corriendo en puerto 5000

### ⏳ Pendiente de Implementación

1. **Conectividad de Malla (Requiere hardware)**
   - ⏳ BLE advertise/scan con flutter_blue_plus
   - ⏳ WiFi Direct broadcast con flutter_p2p_connection
   - ⏳ Descubrimiento de nodos vecinos
   - ⏳ Transmisión real de mensajes

2. **Servidor de Visualización**
   - ⏳ API REST para recibir datos de nodos
   - ⏳ API REST para recibir rutas de mensajes
   - ⏳ Mapa web con visualización en tiempo real

3. **Optimizaciones**
   - ⏳ Persistencia de mensajes en Hive
   - ⏳ Tabla de vecinos con RSSI
   - ⏳ Heurística de routing avanzada
   - ⏳ Tests automatizados

## Cómo Ejecutar el Proyecto

### En Replit (Web)
1. El workflow "Flutter Web Server" está configurado
2. La app se sirve automáticamente en puerto 5000
3. Acceder via la URL de Replit

### Localmente (Android)
```bash
# Instalar Flutter SDK
flutter doctor

# Instalar dependencias
flutter pub get

# Conectar dispositivo Android
flutter devices

# Ejecutar en Android
flutter run -d <device-id>

# O construir APK
flutter build apk --release
```

## Próximos Pasos

### Fase 1: Integración BLE/WiFi Direct (1-2 semanas)
1. Implementar advertise/scan BLE siguiendo documentación en `_retransmit()`
2. Implementar broadcast WiFi Direct
3. Probar descubrimiento de nodos en dispositivos reales
4. Validar retransmisión multi-salto

### Fase 2: Servidor de Visualización (1 semana)
1. Crear API REST con Node.js/Express
2. Implementar endpoints para nodos y rutas
3. Crear mapa web con visualización en tiempo real
4. Integrar con Google Maps o Mapbox

### Fase 3: Optimización y Escala (2-3 semanas)
1. Implementar persistencia con Hive
2. Optimizar algoritmo de routing
3. Reducir consumo de batería
4. Tests de carga con múltiples nodos

### Fase 4: Lanzamiento Ciudad Guayana (1 mes)
1. Beta testing con usuarios reales
2. Monitoreo de cumplimiento regulatorio
3. Ajustes basados en feedback
4. Marketing viral para expansión de red

## Notas de Desarrollo

### Restricciones de Replit
- Flutter no está soportado nativamente
- Flutter SDK instalado manualmente en ~/flutter/
- Solo se puede probar Flutter Web (no BLE/WiFi Direct)
- Para probar conectividad de malla, se requieren dispositivos Android físicos

### Comandos Útiles
```bash
# Limpiar build
~/flutter/bin/flutter clean

# Actualizar dependencias
~/flutter/bin/flutter pub get

# Verificar diagnóstico
~/flutter/bin/flutter doctor

# Hot reload (cuando está corriendo)
# Presionar 'r' en la consola del workflow
```

## Contacto y Soporte

**Proyecto**: Orzion Mesh-Voice MVP  
**Desarrollador**: OrzattyStudios  
**Objetivo**: Red de malla descentralizada legal y viral en Venezuela  
**Valoración objetivo**: $100M+

---

_Última actualización: 11 de Octubre, 2025_
