# nicalingo

A new Flutter project.
# NicaLingo

NicaLingo es una plataforma digital educativa diseñada para la revitalización y enseñanza de las lenguas indígenas de Nicaragua. Desarrollada con Flutter, la aplicación busca preservar la riqueza cultural y lingüística del país a través de un aprendizaje interactivo, modular y accesible.

---

## Especificaciones Técnicas

### Arquitectura del Proyecto
El proyecto está estructurado bajo una arquitectura modular por capas, garantizando la escalabilidad, separación de conceptos y facilidad para realizar pruebas.

* Core: Contiene la configuración global, temas visuales, utilidades y servicios compartidos.
* Features: Módulos independientes por funcionalidad (Autenticación, Lecciones).

### Variables de Entorno
La configuración del entorno se maneja a través del paquete flutter_dotenv. Las claves de API y URLs base no se suben al repositorio.

Ejemplo de configuración de archivo .env:
```env
API_URL=[https://api.nicalingo.com/v1](https://api.nicalingo.com/v1)
SUPABASE_URL=YOUR_SUPABASE_URL
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY