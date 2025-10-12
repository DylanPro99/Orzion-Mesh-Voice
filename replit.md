# Orzion Mesh

## Overview

Orzion Mesh is a decentralized mesh network application built with Flutter. The project is designed to provide a cross-platform solution for mesh networking, with support for web deployment as evidenced by the web-specific configuration files. The application now includes advanced features like message persistence, intelligent routing, delivery confirmations, and smart battery saving.

**Última actualización: Octubre 12, 2025**

### Nuevas Funcionalidades Implementadas ✅

1. **💾 Persistencia de Mensajes con Hive** - Los mensajes nunca se pierden
2. **👥 Tabla de Vecinos Conocidos** - Historial completo de nodos descubiertos
3. **✅ Sistema de Confirmación ACK** - Doble check estilo WhatsApp
4. **🧭 Routing Inteligente** - Selección de vecinos basada en confiabilidad
5. **🔋 Modo Ahorro de Batería** - Intervalos dinámicos según batería
6. **🔧 Dependencias Corregidas** - flutter_ble_peripheral ^1.2.6

**Estado**: Listo para compilar en CodeMagic 🚀

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture

**Framework Choice: Flutter for Web**
- **Decision**: Use Flutter as the primary framework for building a cross-platform mesh networking application
- **Rationale**: Flutter enables code sharing across web, mobile, and desktop platforms with a single codebase
- **Benefits**: Reduced development time, consistent UI/UX across platforms, strong performance on web through compiled JavaScript

**Progressive Web App (PWA) Configuration**
- **Decision**: Configure the application as a Progressive Web App
- **Implementation**: Includes manifest.json with offline capabilities and installability features
- **Benefits**: Users can install the app on their devices, works offline, provides native-like experience on web browsers
- **Configuration Details**:
  - Standalone display mode for app-like experience
  - Portrait-primary orientation for mobile-optimized layout
  - Multiple icon sizes (192px, 512px) including maskable variants for adaptive icons

### Application Structure

**Web Bootstrap Strategy**
- **Decision**: Use Flutter's async bootstrap mechanism (`flutter_bootstrap.js`)
- **Rationale**: Enables progressive loading and better initial page load performance
- **Benefits**: Improved user experience with faster perceived load times

**Base Path Flexibility**
- **Decision**: Implement dynamic base href configuration
- **Implementation**: Uses `$FLUTTER_BASE_HREF` placeholder for build-time replacement
- **Rationale**: Allows deployment in subdirectories without code changes
- **Benefits**: Greater deployment flexibility for different hosting environments

### Design Patterns

**Meta Configuration**
- **Mobile-First Approach**: Configured for mobile web with appropriate meta tags
- **iOS Optimization**: Includes specific meta tags for iOS web app capabilities
- **Cross-Browser Compatibility**: IE Edge compatibility mode specified

**Branding and Theme**
- **Color Scheme**: Uses #0175C2 as primary brand color for both background and theme
- **Consistent Identity**: Unified naming ("Orzion Mesh") across all web configurations
- **Localization Ready**: Descriptions in Spanish ("Red de malla descentralizada") indicate internationalization support

## External Dependencies

### Core Framework
- **Flutter Web**: Primary application framework for building and rendering the UI

### Web Standards
- **Progressive Web App APIs**: For offline support and installability
- **Web App Manifest**: JSON-based configuration for PWA features

### Asset Management
- **Icon Assets**: Multiple resolution icons stored in `web/icons/` directory
  - Standard icons: 192px and 512px
  - Maskable icons: For Android adaptive icons
- **Favicon**: Custom branding icon for browser tabs

### Browser Compatibility
- **Modern Web Browsers**: Targets modern browsers with Flutter Web support
- **Internet Explorer Edge Mode**: Fallback compatibility configuration

**Note**: The repository appears to be in initial setup phase. No backend services, databases, or external API integrations are currently configured. Future development will likely require additional architectural decisions for the mesh networking functionality, peer-to-peer communication protocols, and data synchronization mechanisms.