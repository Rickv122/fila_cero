# FilaCero · Sprint 2 revisado

Aplicación Flutter para Android e iOS. Permite consultar estaciones de La Paz y El Alto, guardar favoritas y administrar el catálogo, las cuentas y los permisos del personal. Solo el responsable asignado a una estación puede publicar su disponibilidad.

## Ejecutar en Windows

Proyecto local: `D:\FilaCero_Proyecto`.

```powershell
cd D:\FilaCero_Proyecto
D:\AndroidDev\bin\flutter.cmd pub get
D:\AndroidDev\bin\flutter.cmd devices
D:\AndroidDev\bin\flutter.cmd run -d emulator-5554
```

En otro equipo, instalar Flutter 3.47.9 y ejecutar `flutter pub get` y `flutter run`. Usar el identificador que muestre `flutter devices`. En VS Code abrir la carpeta completa del proyecto y ejecutar `lib/main.dart` con F5.

Android requiere SDK/JDK compatibles. iOS requiere macOS y Xcode para compilar o ejecutar el simulador. La carpeta `ios/` comparte el código Dart; el workflow de GitHub realiza su verificación en un equipo macOS. Esta comprobación no instala un simulador iOS en Windows ni distribuye una aplicación firmada para iPhone.

## Alcance de las historias

| Historia | Recorrido |
| --- | --- |
| HU-06 | Administrador → Empresas → Estaciones → Registrar, editar, desactivar o reactivar |
| HU-07 | Bienvenida → Consulta pública, registro de conductor o acceso → Mi cuenta |
| HU-08 | Administrador → Usuarios → Ficha → Invitaciones, estado, rol, vinculaciones y asignaciones |
| HU-09 | Responsable → Mis estaciones → Actualizar disponibilidad → Historial |
| HU-10 | Catálogo → Filtros → Detalle → Favoritas personales |

Las cinco historias revisadas tienen 49 criterios. Los 55 SP de la planificación son una propuesta de estimación; no representan una votación realizada.

No se solicitan latitud ni longitud. No se consumen mapas, geocodificación, ubicación ni notificaciones externas en este sprint. Las comunicaciones remotas corresponden a la base de datos y autenticación de Supabase.

## Usuarios y permisos

- **Visitante:** consulta pública sin crear una identidad en Auth.
- **Conductor:** registro con correo verificado; perfil y favoritas propias.
- **Responsable de estación:** funciones personales, vínculos aceptados y estaciones asignadas explícitamente.
- **Administrador:** empresas, estaciones, cuentas, roles, bajas lógicas, invitaciones y asignaciones. No publica disponibilidad ni consulta favoritas ajenas.

El nombre del rol es una autorización dentro de FilaCero. Una vinculación utilizada en la evaluación académica no acredita una relación laboral con una empresa real.

El registro público crea exclusivamente conductores. Los roles se consultan en la base y nunca se obtienen de metadatos editables por el usuario. Las operaciones protegidas comprueban la cuenta activa y confirmada en cada solicitud; desactivar una cuenta bloquea su siguiente operación incluso si conserva un JWT.

El administrador puede filtrar Activos, Inactivos, Pendientes o Todos, editar datos y gestionar estado y rol desde la ficha. Los cambios requieren confirmación. No puede desactivarse ni quitarse su propio rol. Las operaciones que modifican permisos se serializan en la base para proteger el último administrador y coordinar revocaciones con publicaciones.

## Alta de personal

1. Administrador → Usuarios → Invitar personal.
2. Registrar nombre, correo, función y, para responsables, empresa activa.
3. Un correo nuevo recibe una invitación de acceso. La cuenta conserva permisos de conductor hasta confirmar y aceptar su habilitación.
4. Si el correo ya existe, se reutiliza la identidad. La persona acepta o rechaza desde Mi cuenta → Invitaciones de personal; conserva sus favoritas.
5. Desde la ficha se asignan estaciones de la misma empresa a una vinculación aceptada.
6. Retirar una asignación, finalizar una vinculación y desactivar la cuenta son operaciones diferentes. Reactivar no recrea permisos retirados.

La creación de identidades usa la función de servidor `staff-admin`. Su clave administrativa nunca forma parte de Flutter. Si la habilitación falla después de crear la identidad, queda pendiente sin permisos de personal y se puede reintentar con el mismo correo.

## Correos: configuración pendiente para destinatarios generales

El proyecto mantiene la confirmación obligatoria, contraseña mínima de ocho caracteres y verificación de los cambios de correo. El retorno a la aplicación es `filacero://auth-callback`, declarado en Android, iOS y Supabase.

El proveedor predeterminado de Supabase limita destinatarios a miembros de la organización y actualmente permite dos mensajes por hora. Para que cualquier integrante pueda registrarse, recibir invitaciones o recuperar su contraseña hace falta configurar **SMTP propio** en Authentication → Email → SMTP Settings. No se ha contratado un proveedor ni se ha desactivado la verificación para evitar esa dependencia.

Se comprobó la entrega de registro y recuperación al titular del proyecto. Su correo fue confirmado. El enlace de recuperación recibido ya se había abierto; se comprobó su rechazo al reutilizarlo y el protocolo de restablecimiento con un desafío nuevo de uso único generado de forma administrativa, sin otro envío.

Los HTML de `supabase/templates/` están preparados en español. Su publicación requiere SMTP propio: el plan gratuito con proveedor predeterminado rechazó modificar plantillas. Los mensajes activos siguen siendo los predeterminados. No configurar esas plantillas como si ya estuvieran publicadas.

Referencias: [SMTP en Supabase](https://supabase.com/docs/guides/auth/auth-smtp), [seguridad de contraseñas](https://supabase.com/docs/guides/auth/password-security).

## Datos de partida

Cuatro estaciones y tres operadoras, con dirección, licencia y productos documentados en el [catálogo ANH](https://www.anh.gob.bo/w2026/contenido.php?D=2&R=1&s=40), consultado el 17/11/2026:

| Estación | Operadora | Ciudad | Dirección |
| --- | --- | --- | --- |
| San Jorge | Automóvil Club Boliviano | La Paz | Av. 6 de Agosto Nº 2993 |
| Calacoto | Automóvil Club Boliviano | La Paz | Calle 12 esq. Gral. Inofuentes Nº 7823 |
| Obrajes | BASSAM LIMITADA | La Paz | Av. Hernando Siles Nº 4554 |
| Senkata | E.S. C. Redentor S.R.L. | El Alto | Av. 6 de Marzo Nº 110 |

Los productos habilitados no son existencias actuales. No se cargaron publicaciones de combustible inventadas para estas estaciones. La disponibilidad inicial es **Sin actualizar**. Las pruebas de publicación se ejecutan dentro de una transacción que se revierte.

La migración conservó los 35 registros, relaciones y 16 publicaciones anteriores en `historico_sprint2`, fuera de la API pública. Las identidades previas se conservan para trazabilidad; sus accesos de evaluación quedan inactivos al finalizar las comprobaciones. Los accesos personales y cualquier archivo con contraseñas se entregan fuera del repositorio.

## Modelo de datos

Diez tablas de negocio: `perfiles`, `empresas_operadoras`, `ciudades`, `estaciones`, `combustibles`, `estacion_combustible`, `vinculaciones_personal`, `asignaciones_responsables`, `historial_disponibilidad` y `favoritas`.

Las relaciones usan UUID completos y claves foráneas. Los códigos PER-, EMP- y EST- son referencias legibles. El correo de acceso tiene su fuente en Auth; la contraseña no se almacena en tablas de negocio. No hay un campo de disponibilidad actual que duplique el historial: se calcula a partir del último evento válido.

Todas las tablas públicas tienen RLS y una política que deniega acceso directo. Las operaciones se realizan mediante dos RPC públicas con funciones internas que verifican identidad, estado y autorización. Las bajas son lógicas y los eventos no se editan ni borran desde los clientes.

La categoría informada es Disponible, Disponibilidad limitada o Agotado. Al alcanzar dos horas, o cuando una reactivación invalida una publicación anterior, la consulta devuelve Sin actualizar. El indicador visual es cualitativo; no representa litros, porcentajes ni tiempos de espera.

## Estructura

```text
lib/
  main.dart                     Tema y navegación raíz
  core/app_controller.dart      Sesión, perfil y cambios de identidad
  core/supabase_config.dart     URL y clave publicable
  models/domain.dart            Validaciones y tipos compartidos
  data/                         Acceso a consultas, comandos y Auth administrativo
  screens/
    home_screen.dart            Bienvenida e inicio por rol
    auth_screen.dart            Registro, acceso y recuperación
    account_screen.dart         Perfil, seguridad e invitaciones
    company_screen.dart         Gestión de empresas
    users_screen.dart           Cuentas, vínculos, asignaciones
    catalog_screen.dart         Listas, filtros, paginación y favoritas
    station_form_screen.dart    Alta y edición sin coordenadas
    station_detail_screen.dart  Detalle e indicadores
    availability_screen.dart    Publicación e historial
supabase/
  migrations/                   Historial reproducible de cambios
  functions/staff-admin/         Operaciones privilegiadas de Auth
  templates/                    Plantillas preparadas, pendientes de SMTP
  tests/sprint2_rules.sql        Pruebas transaccionales de reglas
test/                           Pruebas unitarias y de widgets
integration_test/               Recorrido real contra Supabase
android/ · ios/                 Configuración nativa
```

La organización separa presentación, coordinación de estado y acceso a datos. No se presenta como una implementación formal de MVC.

## Validación

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

- 58 comprobaciones de reglas de negocio en la base, con rollback: permisos, baja lógica, vínculos, asignaciones, favoritas, vigencia e historial.
- 13 comprobaciones HTTPS: consulta pública, bloqueo de lecturas directas, Auth y función administrativa.
- 13 pruebas de Flutter y navegación Android. La evidencia de la revisión está separada de los documentos y capturas de la versión anterior.
- GitHub Actions compila y prueba iOS en macOS. Consultar el resultado del último commit de código en [Actions](https://github.com/Rickv122/fila_cero/actions).

El test `supabase/tests/sprint2_rules.sql` reutiliza identidades de evaluación conservadas en el proyecto para probar varias autorizaciones dentro de una transacción. No crea correos, no envía mensajes y revierte sus datos temporales. En una base nueva deben prepararse identidades de evaluación controladas antes de ejecutarlo.

La prueba adicional `integration_test/roles_flow_test.dart` comprueba en Android la consulta del conductor, la aceptación de una invitación de personal, la asignación y su revocación con una sesión vigente. Requiere dos identidades controladas: administrador de prueba y titular. Restituye el rol anterior y cierra la vinculación al finalizar; no publica existencias ficticias. No debe apuntarse a una cuenta que esté usando otra persona durante la prueba.

Las comprobaciones HTTPS se pueden repetir con `python scripts/verify_backend.py --credentials RUTA_PRIVADA.json`; el JSON requiere `email` y `password` de un administrador activo. No crea ni edita registros de negocio.

Para integración, proporcionar `TEST_ADMIN_EMAIL` y `TEST_ADMIN_PASSWORD` mediante un archivo privado externo al repositorio. GitHub los mantiene cifrados en Secrets. Nunca distribuir el binario generado para la integración, porque contiene esas constantes. Después de las pruebas compilar otra vez `lib/main.dart` sin definiciones privadas.

## Preparar otra base

Aplicar las migraciones en orden, desplegar `staff-admin`, exigir confirmación de correo y longitud mínima de ocho caracteres, y autorizar el enlace de retorno. Registrar y verificar una cuenta controlada antes de habilitar al primer administrador mediante un procedimiento administrativo controlado. No promover roles desde Flutter ni ejecutar scripts antiguos de alta masiva.

La comprobación adicional de contraseñas filtradas aparece deshabilitada en el asesor de Supabase. No se anuncia como activa. Su disponibilidad y configuración deben revisarse según el plan del proyecto.

Los informes y capturas previos de `docs/` documentan la primera implementación de Sprint 2. No representan la revisión actual de HU-06 a HU-10; ver `docs/REVISION_SPRINT2.md`.
