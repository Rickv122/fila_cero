# FilaCero · Sprint 3

Aplicación Flutter para consultar estaciones de La Paz y El Alto, comparar opciones según combustible y recorrido, obtener rutas y recibir avisos de disponibilidad. El administrador gestiona el catálogo y sus ubicaciones; únicamente el responsable asignado publica disponibilidad.

Esta entrega se enfoca en **Android**. El Sprint 2 se conserva en la rama `sprint-2`. El trabajo de iOS queda pendiente por decisión del equipo.

## Historias de usuario

| HU | Función | Responsable |
| --- | --- | --- |
| HU-11 | Preferencias de combustible y distancia | Cristopher Roy Flores Gomez |
| HU-12 | Recomendaciones por disponibilidad y tiempo por carretera | Naira Araziel Quisbert Perales |
| HU-13 | Ruta por calles hacia la estación elegida | Lucas Ivan Castro Alvarado |
| HU-14 | Avisos de disponibilidad en favoritas | Ricardo Wilfredo Limachi Medina |
| HU-15 | Buscar y confirmar ubicaciones en el mapa | Andrick Fernando Valenzuela Alvarez |

Las cinco historias y sus 34 criterios están en [historias_sprint3.json](docs/historias_sprint3.json). Los **47 SP son estimaciones propuestas**, pendientes de la votación del equipo.

## Ejecutar Android

Requiere Flutter **3.47.9**, Dart **3.13.7**, Android SDK y JDK compatibles. Android mínimo **8.0 / API 26**. El emulador de referencia es `Pixel_Android_15`, Android 15 / API 35, con servicios de Google para mensajería.

```powershell
cd D:\FilaCero_Proyecto
D:\AndroidDev\bin\flutter.cmd pub get
D:\AndroidDev\bin\flutter.cmd devices
D:\AndroidDev\bin\flutter.cmd run -d emulator-5554
```

En otro equipo usar `flutter` desde la instalación local. En VS Code abrir la carpeta del proyecto, seleccionar el dispositivo y ejecutar `lib/main.dart` con F5.

La aplicación requiere Internet. Para comparar recorridos se puede autorizar la ubicación del dispositivo o seleccionar un punto en el mapa. Las coordenadas de estaciones se confirman desde su formulario administrativo.

## Cuentas académicas de evaluación

| Rol | Correo | Contraseña |
| --- | --- | --- |
| Administrador | marcela.salvatierra@filacero.test | `AdminAula26` |
| Responsable | mateo.quispe@filacero.test | `Encargado26` |
| Conductor | valentina.rojas@filacero.test | `Conductor26` |

Son identidades públicas de evaluación, sin buzones acreditados. Mateo tiene asignada **San Jorge**. Las cuentas personales de los integrantes y las credenciales de administración de infraestructura permanecen privadas.

El registro público crea conductores, sin confirmación por correo. El administrador registra personal desde **Usuarios → Registrar personal** y asigna empresa y estaciones. Se conservan la autenticación, bajas lógicas, perfiles, gestión de cuentas, historial y favoritas del Sprint 2.

## Recorrido de exposición

1. **Conductor → Mis preferencias:** elegir Gasolina Especial y una distancia de 5, 10 o 20 km; guardar y volver a abrir para comprobar persistencia.
2. **Responsable Mateo → Mis estaciones → San Jorge:** publicar disponibilidad reciente. Los estados vencen a las dos horas; no se renuevan automáticamente.
3. **Conductor → Recomendaciones:** elegir origen en La Paz y buscar. Comparar estado, fecha, kilómetros y tiempo; abrir **Cómo llegar** y volver a las recomendaciones.
4. Guardar San Jorge en favoritas y activar **Mis avisos** con permiso del teléfono. Desde Mateo publicar primero Limitada o Agotado y después Disponible. El aviso permite abrir el detalle actualizado. Repetir Disponible no crea otro evento mientras el estado anterior siga vigente.
5. **Administrador → Estaciones → San Jorge → Editar estación → Revisar ubicación en el mapa:** buscar una dirección, revisar el punto y la dirección, confirmar y guardar. Se conserva la identidad de la estación y sus relaciones.

Los nombres y direcciones del catálogo proceden de referencias públicas. La disponibilidad y las personas de evaluación son escenarios académicos; no acreditan abastecimiento real. Las ubicaciones incorporadas se documentan en [ubicaciones_sprint3.json](docs/ubicaciones_sprint3.json).

## Integraciones y arquitectura

Se integran **Geocoding, Routing, Route Matrix y Firebase Cloud Messaging**. Las pantallas llaman a Supabase por HTTPS; las funciones de servidor verifican la sesión y consultan las APIs. Las claves privadas permanecen como secretos. PostgreSQL mantiene preferencias, ubicaciones, suscripciones, dispositivos y la cola de avisos con control de permisos.

[Contratos HTTP, JSON, diagrama de comunicación, seguridad, errores y configuración](docs/API_SPRINT_3.md).

| Carpeta | Contenido |
| --- | --- |
| `lib/screens` | Pantallas y navegación con `Navigator.push` / `pop`. |
| `lib/core` | Sesión, perfil y ciclo de notificaciones. |
| `lib/data` | Repositorios de consultas, comandos y APIs. |
| `lib/models` | Modelos y conversión de respuestas. |
| `supabase/functions` | Administración de personal, servicios geográficos y envío de avisos. |
| `supabase/migrations` | Cambios versionados de BD y permisos. |
| `test`, `integration_test`, `supabase/tests` | Pruebas de Flutter, dispositivo, contratos y reglas de BD. |

## Verificar y empaquetar

```bash
flutter analyze
flutter test
node --experimental-transform-types --test supabase/tests/geo_models_test.ts supabase/tests/http_errors_test.ts
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/sprint3_flow_test.dart -d emulator-5554
flutter build apk --release
```

El APK normal queda en `build/app/outputs/flutter-apk/app-release.apk`. La firma actual permite distribución académica directa. Las claves de proveedor y las credenciales privadas no forman parte del APK. Los archivos de Firebase del cliente contienen identificadores públicos.

La prueba de dispositivo usa las cuentas académicas anteriores y realiza publicaciones de evaluación en San Jorge. Las comprobaciones de `supabase/tests/sprint3_invariants.sql` se ejecutan con **ROLLBACK**. Evidencias y límites de verificación: [ESTADO_SPRINT_3.md](docs/ESTADO_SPRINT_3.md).
