# nicalingo

A new Flutter project.
# NicaLingo

NicaLingo es una plataforma digital educativa diseñada para la revitalización y enseñanza de las lenguas indígenas de Nicaragua. Desarrollada con Flutter, la aplicación busca preservar la riqueza cultural y lingüística del país a través de un aprendizaje interactivo, modular y accesible.


# Configuración Inicial del Proyecto (NicaLingo)

Guía para instalar las dependencias y configurar el entorno de desarrollo local.

## Lista de Dependencias

El proyecto utiliza las siguientes dependencias configuradas en el archivo pubspec.yaml:

### Dependencias de producción
- flutter: SDK principal del framework.

### Dependencias de desarrollo
- flutter_test: Paquete para pruebas unitarias.
- flutter_lints (v6.0.0): Reglas de estilo de código.
- flutter_launcher_icons (v0.13.1): Automatización del ícono de la aplicación.
- flutter_native_splash (v2.4.1): Generador de la pantalla de carga nativa para Android.

## Comandos para Obtener las Dependencias

Ejecutá los siguientes comandos en orden desde la terminal en la raíz del proyecto:

### 1. Descargar paquetes
Descarga e indexa todas las dependencias en el editor:

flutter pub get

### 2. Generar el Splash Screen Nativo
Crea los assets nativos de la pantalla de carga con el color oficial:

dart run flutter_native_splash:create

### 3. Limpieza de caché (En caso de errores)
Si el editor muestra errores de indexación o paquetes no encontrados, ejecutá estos comandos:

flutter clean
flutter pub get

## Ejecutar el Proyecto

Para iniciar la aplicación en el dispositivo conectado o emulador:

flutter run