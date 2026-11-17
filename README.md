# FilaCero Sprint 2

Aplicación Flutter y Dart para Android e iOS. El conductor consulta gasolineras sin cuenta. El administrador mantiene el catálogo y las asignaciones. Solo el encargado activo y asignado publica disponibilidad de combustible.

Este incremento usa listas, filtros, detalles y formularios. El mapa y sus dependencias se retiraron del código activo. No incorpora GPS, rutas, geocodificación, notificaciones ni reportes de conductores. La conexión a Supabase se limita a base de datos y autenticación, autorizadas para el Sprint 2.

## Ejecutar

Entorno utilizado: Flutter 3.47.9, Dart 3.13.7 y JDK 21. Android mínimo 8.0 API 26. La plataforma iOS tiene objetivo mínimo 15.0.

El Sprint 2 está en la rama `sprint-2`; `main` conserva el primer incremento. Para descargar esta versión:

```sh
git clone --branch sprint-2 https://github.com/Rickv122/fila_cero.git FilaCero_Proyecto
cd FilaCero_Proyecto
```

En el equipo donde se desarrolló, la carpeta es `D:\FilaCero_Proyecto`. Abrir esa carpeta completa en Visual Studio Code y seleccionar un dispositivo Android, o un simulador iOS desde un Mac.

```sh
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d ID_DISPOSITIVO
```

La URL y la clave **pública** del proyecto están en `lib/core/supabase_config.dart`. Se pueden sustituir con `--dart-define=SUPABASE_URL=...` y `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`. La clave pública no concede permisos administrativos: cada operación comprueba identidad, rol y asignación en el servidor.

Proyecto de base de datos: https://supabase.com/dashboard/project/oejouwwxngyafftzfkux

Código del incremento: https://github.com/Rickv122/fila_cero/tree/sprint-2

```sh
flutter build apk --debug
```

## iOS

Se incluye `ios/` y se comparte el mismo código Dart. Se necesita macOS con Xcode y sus herramientas de desarrollo para compilar y ejecutar iOS. En un Mac:

```sh
flutter pub get
flutter build ios --simulator --debug
flutter devices
flutter run -d ID_SIMULADOR_IOS
```

La compilación y el recorrido de las cinco historias pasaron en un simulador iOS mediante GitHub Actions en Mac. Consultar `docs/ESTADO_SPRINT_2.md` para los resultados, evidencias y límites de esa verificación. Ejecución: https://github.com/Rickv122/fila_cero/actions/runs/43978863216

## Las cinco historias

| Historia | Recorrido |
|---|---|
| HU-06 Catálogo | Acceso de personal, Administrador, Mi cuenta, Administrar catálogo. Registrar o editar nombre, dirección, ciudad, coordenadas manuales y combustibles. Desde el detalle se asignan encargados autorizados. |
| HU-07 Autenticación | Acceso de personal con correo y contraseña. La cuenta activa define las funciones disponibles. Cerrar sesión retira las pantallas protegidas. |
| HU-08 Disponibilidad | Encargado, Mi cuenta, Mis gasolineras, Detalle, Actualizar disponibilidad. Estados por combustible: Hay, Poco y No hay. El servidor registra autor, hora e historial. |
| HU-09 Consultas | Consulta pública por nombre, ciudad y combustible, veinte resultados por página y detalle de la información. Actualizar lista recupera cambios de otras sesiones. |
| HU-10 Baja lógica | Administrador, Detalle, Desactivar o Reactivar, Confirmar. Las inactivas desaparecen de la consulta pública, conservan datos e historial y no admiten publicaciones. |

Una actualización dura dos horas. La ausencia o vencimiento se muestra como **Sin información vigente**. Reactivar una gasolinera no renueva estados anteriores. Las cuentas con rol administrador tampoco pueden publicar disponibilidad.

## Base de datos y seguridad

La migración en `supabase/migrations/` crea seis tablas de negocio: `perfiles`, `surtidores`, `combustibles`, `surtidor_combustible`, `asignaciones_encargado` e `historial_disponibilidad`. Las cuentas y contraseñas las administra Auth. No hay tablas de funciones futuras del Sprint 3.

Todas las tablas de negocio tienen `activo`. Se aplican claves, validaciones, índices y RLS. No se conceden escrituras directas ni DELETE a los clientes. Las operaciones de varias tablas son transacciones mediante funciones con parámetros acotados. Los auxiliares privilegiados permanecen en el esquema privado, con comprobación de rol y sin usar metadatos editables del usuario para autorizar.

`supabase/seed.sql` prepara datos académicos para la evaluación, sin afirmar que sean información real de abastecimiento. Las gasolineras y disponibilidades de prueba se guardan en la base remota y se comparten entre instalaciones.

## Cuentas para evaluar

Las cuentas de personal se crean mediante un procedimiento administrativo controlado. No existe autorregistro de encargados ni selección de rol en la app. Las credenciales se entregan al equipo y a la docente por separado en el archivo privado de accesos, fuera del repositorio público y del ZIP de código.

Para crear cuentas equivalentes en otro proyecto, un administrador puede ejecutar `scripts/provision_staff.py` desde un equipo de confianza con la CLI de Supabase autenticada. El programa consulta una clave privilegiada únicamente en memoria y no la escribe en archivos ni en Flutter. Después aplica el archivo de datos iniciales para vincular los perfiles. Revisar los correos del script antes de usarlo fuera de esta evaluación.

## Comprobar

```sh
flutter analyze
flutter test
python scripts/verify_backend.py --credentials RUTA_ACCESOS_PRIVADOS_JSON --output docs/evidencias/supabase-tests.json
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/public_smoke_test.dart -d ID_DISPOSITIVO
```

El archivo privado se usa solo desde el equipo de desarrollo. Las pruebas remotas crean registros de evaluación y los desactivan al terminar; conservan su historial sin borrado físico. Los resultados publicados no contienen contraseñas ni tokens.

El recorrido completo de personal utiliza `integration_test/sprint2_flow_test.dart` y cuatro valores `TEST_ADMIN_EMAIL`, `TEST_ADMIN_PASSWORD`, `TEST_MANAGER_EMAIL` y `TEST_MANAGER_PASSWORD`. Se pasan desde un JSON privado mediante `--dart-define-from-file`, únicamente para las pruebas. No compartir la compilación de integración, que incorpora esos valores. La aplicación normal se compila con `lib/main.dart` y sin ese archivo. En CI las credenciales se leen de Secrets y solo se publican capturas PNG.

## Organización del código

```text
lib/
  main.dart                     inicio y tema
  models/domain.dart            perfiles, gasolineras, combustibles y validaciones
  core/app_controller.dart      sesión y coordinación de interfaz
  core/supabase_config.dart     configuración pública
  data/fila_repository.dart     contrato de datos
  data/supabase_repository.dart  conexión, consultas y operaciones
  screens/                      lista, acceso, detalle, formulario, disponibilidad y asignaciones
supabase/                       migración reproducible y datos de evaluación
test/                           pruebas de modelos, permisos de interfaz y navegación
integration_test/               recorridos contra el servidor real en dispositivo
scripts/                        alta controlada y pruebas remotas
android/                        proyecto nativo Android
ios/                            proyecto nativo iOS
docs/                           planificación, resultados y evidencias
```

El proyecto separa modelos, repositorio, controlador y vistas. No se presenta como una implementación estricta de MVC. Cada capa tiene una responsabilidad y las pantallas no contienen SQL ni claves de administración.

La aceptación de la docente, el consenso real de Planning Poker y las ceremonias del equipo se registran después de realizarlos. Los documentos no los dan por celebrados.
