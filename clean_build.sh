#!/bin/bash
# Script para limpiar caché y build antes de compilar en CodeMagic

echo "🧹 Limpiando caché y archivos de build..."

# Eliminar directorios de build y caché
rm -rf build/
rm -rf .dart_tool/
rm -rf .flutter-plugins
rm -rf .flutter-plugins-dependencies
rm -rf .packages
rm -rf pubspec.lock

echo "✅ Caché eliminada"

# Obtener dependencias limpias
echo "📦 Descargando dependencias..."
flutter pub get

echo "✅ Dependencias actualizadas"

# Limpiar build de Flutter
flutter clean

echo "✅ Build limpio completado"
echo ""
echo "🚀 Ahora puedes compilar con: flutter build apk --release"
