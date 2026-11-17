# FilaCero Sprint 2

Aplicación Flutter para Android e iOS. Permite consultar estaciones de La Paz y El Alto, guardar favoritas y gestionar empresas, estaciones, cuentas y permisos. El responsable asignado publica disponibilidad por combustible.

## Ejecutar en Windows

```powershell
cd D:\FilaCero_Proyecto
D:\AndroidDev\bin\flutter.cmd pub get
D:\AndroidDev\bin\flutter.cmd devices
D:\AndroidDev\bin\flutter.cmd run -d emulator-5554
```

En VS Code, abrir la carpeta completa y ejecutar `lib/main.dart` con F5. En otro equipo usar Flutter 3.47.9 y Dart 3.13.7. Android requiere SDK y JDK compatibles. El dispositivo de referencia es Pixel 5 con Android 15 API 35, 1080 × 2340 píxeles y densidad 440. La compilación usa minSdk 26, Android 8.0.

iOS comparte el código Dart y requiere macOS con Xcode para compilar o usar el simulador. El workflow verifica compilación y recorridos en un simulador macOS. Windows ejecuta el emulador Android.

## Acceso y roles

| Actor | Funciones |
| --- | --- |
| Visitante | Consulta pública, filtros y detalle sin cuenta. |
| Conductor | Registro con correo y contraseña, perfil y favoritas propias. |
| Responsable de estación | Consulta sus estaciones asignadas y publica disponibilidad. |
| Administrador | Gestiona catálogo, cuentas, roles y estaciones autorizadas. |

El registro de conductor inicia sesión sin confirmar el correo. La configuración `auth.email.enable_confirmations=false` debe aplicarse también en el proyecto Supabase. Las direcciones de prueba no representan buzones verificados.

El administrador abre **Usuarios → Registrar personal** y completa nombre, correo, teléfono opcional, contraseña inicial, rol, empresa y estaciones. La cuenta queda disponible para iniciar sesión. No hay invitaciones ni aceptación de vínculos. **Editar acceso y estaciones** modifica el mismo registro. **Restablecer contraseña** permite recuperar cuentas de prueba sin correo; cada persona también puede cambiar su contraseña desde Mi cuenta comprobando la actual.

Las cuentas pueden desactivarse y reactivarse. La baja es lógica y no borra el historial. Una persona no puede asignarse permisos ni desactivar su propia cuenta administrativa. Se comprueban los permisos en cada operación, también con una sesión abierta.

## Historias

| HU | Función | Responsable |
| --- | --- | --- |
| HU-06 | Gestionar empresas y estaciones | Cristopher Roy Flores Gomez |
| HU-07 | Registrarse y acceder según el rol | Naira Araziel Quisbert Perales |
| HU-08 | Registrar personal y gestionar sus estaciones | Lucas Ivan Castro Alvarado |
| HU-09 | Publicar disponibilidad con historial | Ricardo Wilfredo Limachi Medina |
| HU-10 | Consultar estaciones y gestionar favoritas | Andrick Fernando Valenzuela Alvarez |

Las cinco historias tienen 33 criterios en [historias_sprint2.json](docs/historias_sprint2.json). Los 55 SP son una estimación propuesta, pendiente de votación del equipo.

## Arquitectura y base de datos

`lib/screens` contiene pantallas y formularios. `core/app_controller.dart` coordina sesión y perfil. `data/supabase_repository.dart` concentra consultas y comandos. PostgreSQL conserva diez tablas de negocio con RLS. Las entradas públicas `fc_query` y `fc_command` usan invocación con permisos del solicitante y llaman funciones privadas que verifican identidad y autorizaciones actuales. El acceso directo a las tablas está restringido.

Las empresas agrupan estaciones. Una persona responsable tiene una empresa vigente y una o varias estaciones de esa empresa; puede quedar sin asignar. La relación de empresa y las asignaciones se mantienen en tablas separadas para conservar historial y evitar duplicaciones. Las claves UUID y los códigos de referencia son internos y no aparecen en las pantallas.

Las operaciones administrativas de Auth se ejecutan en `supabase/functions/staff-admin/index.ts`. La función verifica el token con Auth y el rol actual en BD antes de crear cuentas o restablecer contraseñas. La clave privilegiada permanece en el servidor. El cliente usa únicamente la URL y clave publicable.

## Datos para la exposición

El catálogo incluye diez estaciones y nueve empresas con nombres y direcciones documentados en el [directorio de la ANH](https://www.anh.gob.bo/w2026/contenido.php?D=2&R=1&s=40). El detalle está en `docs/catalogo_exposicion.json`. Las personas y existencias utilizadas en la exposición son datos académicos ficticios, sin relación laboral ni abastecimiento real acreditados.

Miraflores queda sin publicaciones para mostrar **Sin actualizar**. Mario Salazar queda sin estaciones para mostrar **Sin estaciones asignadas**. Las demás estaciones tienen combinaciones Disponible, Disponibilidad limitada y Agotado. La información vence a las dos horas; para una nueva exposición deben publicarse estados recientes desde las cuentas autorizadas. No se renuevan fechas automáticamente.

Las credenciales se entregan al grupo en un archivo privado local. No se incluyen contraseñas administrativas ni claves secretas en el repositorio, documentos públicos ni APK.

## Verificación

```bash
flutter analyze
flutter test
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/sprint2_flow_test.dart -d DEVICE --dart-define-from-file=PRIVATE_FILE
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/direct_staff_flow_test.dart -d DEVICE --dart-define-from-file=PRIVATE_FILE
```

El archivo privado contiene `TEST_ADMIN_EMAIL`, `TEST_ADMIN_PASSWORD`, `TEST_MANAGER_EMAIL`, `TEST_MANAGER_PASSWORD`, `TEST_DRIVER_EMAIL`, `TEST_DRIVER_PASSWORD` y `TEST_UNASSIGNED_EMAIL`. No debe añadirse a Git ni usarse para compilar el APK normal.

Las 22 comprobaciones de `supabase/tests/sprint2_rules.sql` se ejecutan dentro de una transacción con ROLLBACK. Verifican alta directa, asignaciones, aislamiento, revocación, bajas lógicas e idempotencia. Los recorridos de dispositivo generan capturas por historia. El estado de la verificación está en `docs/ESTADO_SPRINT_2.md`.

Las capturas Android actuales están en [docs/capturas_sprint2](docs/capturas_sprint2) y los resultados vigentes, en [docs/evidencias](docs/evidencias). Las interfaces y comprobaciones de versiones anteriores se conservan únicamente en `docs/historico/`, con su contexto.

## Preparación de Supabase

Aplicar las migraciones en orden, configurar Auth sin confirmación de correo y desplegar `staff-admin`. Conservar la primera cuenta administrativa autorizada. El registro público siempre crea conductores, incluso si el cliente envía otro rol. `supabase/seed.sql` carga el catálogo; las identidades se crean mediante Auth, nunca insertando contraseñas en tablas del negocio.

## Generar APK

```bash
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`. La firma actual permite distribución académica directa y no representa una publicación en Play Store. La app requiere Internet para acceder a la BD. No integra mapas, coordenadas, GPS ni notificaciones en este sprint.
