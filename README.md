# NicaLingo

NicaLingo es una plataforma digital educativa diseñada para la revitalización y enseñanza de las lenguas indígenas de Nicaragua. Desarrollada con Flutter, la aplicación busca preservar la riqueza cultural y lingüística del país a través de un aprendizaje interactivo, modular y accesible.

# Configuración y Arquitectura del Proyecto (NicaLingo)

Guía completa para instalar las dependencias, configurar el entorno de desarrollo local, entender la arquitectura del software y establecer los servicios del proyecto.

## Arquitectura del Proyecto

El proyecto está estructurado utilizando Clean Architecture (Arquitectura Limpia), combinada con una organización de código basada en carpetas por módulos o características (feature-based directory structure):

* Clean Architecture: Divide el código en capas independientes (como data, domain y presentation) para separar estrictamente la lógica de negocio de los detalles técnicos y de la interfaz de usuario.
* Estructura Modular por Features: Organiza los componentes agrupándolos por características específicas de la aplicación (por ejemplo, autenticación, mapa de niveles y recursos de la biblioteca), facilitando la escalabilidad y el mantenimiento.

## Lista de Dependencias

El proyecto utiliza las siguientes dependencias configuradas en el archivo pubspec.yaml:

### Dependencias de producción

* flutter: SDK principal del framework.
* supabase_flutter: Cliente oficial para conectar e interactuar con la base de datos y servicios de Supabase.
* flutter_dotenv: Paquete para la gestión segura de variables de entorno.

### Dependencias de desarrollo

* flutter_test: Paquete para pruebas unitarias.
* flutter_lints (v6.0.0): Reglas de estilo de código.
* flutter_launcher_icons (v0.13.1): Automatización del ícono de la aplicación.
* flutter_native_splash (v2.4.1): Generador de la pantalla de carga nativa para Android.

## Configuración de Variables de Entorno y Políticas de Privacidad

Crea un archivo .env en la raíz del proyecto para almacenar las credenciales de forma segura. Con las nuevas actualizaciones de políticas de privacidad y seguridad, ya no se emplean claves anónimas, utilizándose estrictamente la Publishable Key:

SUPABASE_URL=tu_url_de_supabase
SUPABASE_PUBLISHABLE_KEY=tu_publish_key_de_supabase

Asegúrate de registrar este archivo dentro de los assets en tu pubspec.yaml:

flutter:
uses-material-design: true
assets:
- .env
- assets/images/
- assets/icons/

## Comandos para Obtener las Dependencias

Ejecutá los siguientes comandos en orden desde la terminal en la raíz del proyecto:

### 1. Añadir Dependencias

flutter pub add supabase_flutter flutter_dotenv

### 2. Descargar paquetes

Descarga e indexa todas las dependencias en el editor:

flutter pub get

### 3. Generar el Splash Screen Nativo

Crea los assets nativos de la pantalla de carga con el color oficial:

dart run flutter_native_splash:create

### 4. Limpieza de caché (En caso de errores)

Si el editor muestra errores de indexación o paquetes no encontrados, ejecutá estos comandos:

flutter clean
flutter pub get

## Configuración Adicional del Proyecto

### 1. Inicialización de Supabase en el Código

Asegúrate de inicializar Supabase de forma asíncrona en tu método main() utilizando la Publishable Key:

await dotenv.load(fileName: ".env");
await Supabase.initialize(
url: dotenv.env['SUPABASE_URL']!,
anonKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
);

### 2. Deep Linking (Autenticación OAuth y Correo)

Configura los esquemas de redirección para manejar los inicios de sesión con Google y la verificación por correo:

* Android (android/app/src/main/AndroidManifest.xml): Agregar los intent filters correspondientes para interceptar las redirecciones de autenticación de Supabase.
* iOS (ios/Runner/Info.plist): Configurar los URL schemes para el manejo correcto de las sesiones.

### 3. Base de Datos y Esquema SQL en Supabase

Ejecuta los scripts SQL en tu panel de Supabase para configurar:

* Tablas relacionales para perfiles, idiomas, niveles y seguimiento de progreso de aprendizaje.
* Políticas de seguridad a nivel de fila (Row Level Security - RLS).
* Triggers automáticos para la creación de perfiles de usuario tras el registro.

## Ejecutar el Proyecto

Para iniciar la aplicación en el dispositivo conectado o emulador:

flutter run