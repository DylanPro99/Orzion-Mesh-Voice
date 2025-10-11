
# Orzion Mesh - Red de Malla Descentralizada

## Descripción

Orzion Mesh es una red de comunicaciones P2P que funciona mediante:

- **BLE (Bluetooth Low Energy)**: Para comunicación de corto alcance (<20m)
- **WiFi Direct**: Para mayor alcance y velocidad (hasta 100m)
- **Sistema de saltos múltiples**: Los mensajes se retransmiten automáticamente entre nodos

## Cómo Funciona

### Mensajes a Menos de 20 Metros
1. Usuario A envía mensaje a Usuario B
2. El mensaje se transmite directamente via BLE
3. Usuario B recibe y descifra el mensaje

### Mensajes a Más de 20 Metros (Multi-hop)
1. Usuario A envía mensaje a Usuario C (a 100m de distancia)
2. Usuario B (intermedio) recibe el mensaje via BLE/WiFi
3. Usuario B NO descifra el contenido (privacidad)
4. Usuario B retransmite el mensaje hacia nodos vecinos
5. Usuario C finalmente recibe y descifra el mensaje
6. La ruta completa se visualiza en el mapa

### Funcionamiento como "Mini Antena"
✅ **App abierta**: Nodo 100% activo  
✅ **App minimizada**: Nodo activo via servicio en primer plano (notificación visible)  
✅ **App cerrada**: Nodo activo via servicio en primer plano (se reinicia automáticamente)  
⚠️ **Batería baja**: Android puede detener el servicio (configurable en ajustes)

## Compilar APK de Producción

```bash
# Instalar Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Compilar APK
flutter pub get
flutter build apk --release

# El APK estará en: build/app/outputs/flutter-apk/app-release.apk
```

## Requisitos para Pruebas Reales

⚠️ **Importante**: La funcionalidad de red de malla requiere:

1. **Mínimo 2 dispositivos Android físicos** (no funciona en emuladores)
2. **Bluetooth y WiFi activados** en todos los dispositivos
3. **Permisos otorgados** (GPS + Segundo plano)
4. **Ubicación activada** para BLE en Android 12+

## Instalación en Dispositivos

1. Activar "Opciones de desarrollador" en Android
2. Habilitar "Instalación desde fuentes desconocidas"
3. Transferir el APK a cada dispositivo
4. Instalar y otorgar todos los permisos
5. Abrir la app en todos los dispositivos simultáneamente

## Prueba de Campo

### Escenario 1: Comunicación Directa
- Colocar 2 dispositivos a 10 metros de distancia
- En Dispositivo A: Copiar Node ID
- En Dispositivo B: Añadir contacto con Node ID de A
- Enviar mensaje desde B hacia A
- Verificar recepción inmediata

### Escenario 2: Multi-Hop
- Colocar 3 dispositivos: A --- B (30m) --- C (30m)
- Asegurar que A y C NO estén en rango directo
- Enviar mensaje de A hacia C
- Observar cómo B retransmite automáticamente
- Verificar que B NO puede leer el contenido
- C recibe el mensaje después de 1 salto

## Cumplimiento Regulatorio CONATEL

✅ Operación en banda ISM 2.4 GHz no licenciada  
✅ Sin modificación de potencia de transmisión  
✅ Uso de APIs oficiales (flutter_blue_plus, flutter_p2p_connection)  
✅ Consentimiento explícito del usuario (doble opt-in)  
✅ Privacidad: nodos intermedios no descifran mensajes  

## Troubleshooting

**BLE no descubre nodos:**
- Verificar Bluetooth activado
- Verificar permisos de ubicación otorgados
- En Android 12+, necesita permiso BLUETOOTH_SCAN

**WiFi Direct no conecta:**
- Verificar WiFi activado
- Algunos dispositivos requieren WiFi Direct habilitado manualmente
- Verificar permisos de ubicación

**Mensajes no se retransmiten:**
- Verificar permiso de "Segundo plano" otorgado
- La app debe estar en primer plano o con permisos de ejecución en segundo plano
