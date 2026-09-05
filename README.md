# NicaLingo

NicaLingo es una plataforma digital educativa diseñada para la revitalización y enseñanza de las lenguas indígenas de Nicaragua. Desarrollada con Flutter, la aplicación busca preservar la riqueza cultural y lingüística del país a través de un aprendizaje interactivo, modular y accesible.

---

## Requisitos Previos y Entorno

Asegurate de contar con las siguientes versiones instaladas en tu entorno de desarrollo antes de clonar el proyecto:

* Flutter SDK: >=3.16.0
* Dart SDK: >=3.2.0


## Configuración y Arquitectura del Proyecto

### Arquitectura del Proyecto

El proyecto está estructurado utilizando Clean Architecture (Arquitectura Limpia), combinada con una organización de código basada en carpetas por módulos o características (feature-based directory structure):

* Clean Architecture: Divide el código en capas independientes (data, domain y presentation) para separar estrictamente la lógica de negocio de los detalles técnicos y de la interfaz de usuario.
* Estructura Modular por Features: Organiza los componentes agrupándolos por características específicas de la aplicación, facilitando la escalabilidad y el mantenimiento.

#### Estructura de Directorios (lib/)

lib/
├── core/                  # Utilidades globales, temas, constantes, clientes API
│   ├── constants/
│   ├── network/
│   └── theme/
└── features/              # Módulos organizados por característica
├── auth/
│   ├── data/          # Repositorios concretos, datasources (Supabase)
│   ├── domain/        # Entidades, casos de uso, interfaces de repositorio
│   └── presentation/  # Widgets, pantallas (LoginScreen, etc.), state management
├── home_map/          # Mapa de niveles y navegación
└── library/           # Biblioteca y recursos culturales

---

## Lista de Dependencias (pubspec.yaml)

### Dependencias de producción

* flutter: SDK principal del framework.
* supabase_flutter: Cliente oficial para conectar e interactuar con la base de datos y servicios de Supabase.
* flutter_dotenv: Paquete para la gestión segura de variables de entorno.

### Dependencias de desarrollo

* flutter_test: Paquete para pruebas unitarias.
* flutter_lints (v6.0.0): Reglas de estilo de código.
* flutter_launcher_icons (v0.13.1): Automatización del ícono de la aplicación.
* flutter_native_splash (v2.4.1): Generador de la pantalla de carga nativa para Android.

---

## Configuración de Variables de Entorno y Seguridad

1. En la raíz del proyecto, crea un archivo llamado .env:

SUPABASE_URL=tu_url_de_supabase
SUPABASE_PUBLISHABLE_KEY=tu_publish_key_de_supabase

2. Advertencia de Seguridad: Asegúrate de que el archivo .env real NUNCA se suba al repositorio. Agrégalo inmediatamente a tu archivo .gitignore. Comparte únicamente una plantilla de ejemplo (.env.example) con los nombres de las variables vacías.

Registra los assets y el archivo de entorno en tu pubspec.yaml:

flutter:
uses-material-design: true
assets:
- .env
- assets/images/
- assets/icons/

---

## Comandos para Obtener las Dependencias

Ejecutá los siguientes comandos en orden desde la terminal en la raíz del proyecto:

### 1. Añadir Dependencias

flutter pub add supabase_flutter flutter_dotenv

### 2. Descargar paquetes

flutter pub get

### 3. Generar Assets Nativos (Splash Screen e Íconos)

dart run flutter_native_splash:create
dart run flutter_launcher_icons

### 4. Limpieza de caché (En caso de errores de indexación)

flutter clean
flutter pub get

---

## Configuración Adicional del Proyecto

### 1. Inicialización de Supabase en el Código

Asegúrate de inicializar Supabase de forma asíncrona en tu método main utilizando la Publishable Key:

await dotenv.load(fileName: ".env");
await Supabase.initialize(
url: dotenv.env['SUPABASE_URL']!,
publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
);

### 2. Deep Linking (Autenticación OAuth y Correo)

Configura los esquemas de redirección para manejar los inicios de sesión con Google y la verificación por correo:

* Android (android/app/src/main/AndroidManifest.xml): Agregar el intent-filter correspondiente dentro de la actividad principal.
* iOS (ios/Runner/Info.plist): Configurar los URL schemes correspondientes para el manejo correcto de las sesiones.
(Asegúrate de registrar este mismo Redirect URL en el panel de Supabase y en la Google Cloud Console).

### 3. Base de Datos y Esquema SQL en Supabase

Ejecuta los scripts SQL en tu panel de Supabase para configurar:

* Tablas relacionales para perfiles, idiomas, niveles y seguimiento de progreso de aprendizaje.
* Políticas de seguridad a nivel de fila (Row Level Security - RLS).
* Triggers automáticos para la creación de perfiles de usuario tras el registro.

---

## Flujo de Trabajo y Git

Para mantener una colaboración limpia entre compañeros de equipo:

* Ramas principales: main (producción) y develop (desarrollo).
* Ramas de trabajo: feature/nombre-de-la-caracteristica para nuevas pantallas o módulos.
* Convención de commits: Utiliza prefijos claros (ej. feat:, fix:, docs:, refactor:).

---

## Ejecutar el Proyecto

Para iniciar la aplicación en el dispositivo conectado o emulador:

flutter run