# FilaCero Sprint 1

Aplicaciones Móviles I. Incremento Android basado en el proyecto de Naira con HU-01 a HU-05 integradas. Se conserva la identidad visual original y se agregan acceso por correo, mapa, detalle y administración.

## Abrir y ejecutar

Abre esta carpeta en Android Studio o VS Code con las extensiones Flutter y Dart. Se necesita Flutter 3.47.9 (Dart 3.13.7), JDK 21 y Android SDK. Configura el SDK y sus licencias con flutter doctor. El proyecto usa compile/target API 36, Build Tools 36.0.0 y minSdk 26 (Android 8.0). La primera compilación puede descargar Gradle y dependencias.

```sh
flutter pub get
flutter doctor -v
flutter analyze
flutter test
flutter devices
flutter run -d ID_DEL_DISPOSITIVO
```

Siempre ejecuta flutter pub get al preparar una copia nueva: regenera los complementos nativos. El paquete se concentra en Android; no incluye la plataforma Windows, por lo que no necesita crear enlaces simbólicos para compilar Android. Las rutas locales se generan en android/local.properties y no se versionan.

```sh
flutter build apk --debug
```

El APK generado queda en build/app/outputs/flutter-apk/app-debug.apk. Para APK por arquitectura: flutter build apk --debug --split-per-abi. El emulador probado utiliza Android 15 API 35 x86_64. Si el entorno presenta fallos gráficos del emulador, inicia un arranque en frío; el APK también puede ejecutarse en un teléfono compatible.

## Cuentas para la presentación

Administrador: admin@filacero.test

Conductor: conductor@filacero.test

Contraseña de ambas: FilaCero2026!

También se puede crear una cuenta con nombre, correo y contraseña de 8 caracteres como mínimo. Utiliza datos ficticios y una clave que no uses en otros servicios. Las contraseñas se derivan con PBKDF2 HMAC SHA-256, salt de 16 bytes e iteraciones 120000. Esta implementación de aula no debe utilizarse como autenticación de producción.

## Recorrido de las historias

1. HU-01: crear cuenta, cerrar sesión, entrar con correo, comprobar el error con contraseña incorrecta y revisar nombre en Mi perfil.
2. HU-02: Entrar sin cuenta, consultar y abrir un surtidor; Reportar solicita acceso.
3. HU-03: consultar marcadores verde, amarillo, rojo y gris y usar la leyenda. Acercar el mapa para distinguir marcadores próximos o elegir desde Surtidores.
4. HU-04: abrir el detalle con dirección, combustibles y fecha del último reporte; consultar Obrajes para el estado sin reportes.
5. HU-05: entrar como administrador, Mi perfil > Administración > Agregar surtidor. Completar nombre, dirección, ciudad, latitud, longitud y uno o más combustibles. Guardar, editar y consultar el cambio como visitante en la misma instalación.

## Alcance y pendientes

El almacenamiento es local. No hay Google Sign-In, servidor de autenticación ni sincronización entre teléfonos. El criterio original de HU-05 sobre todos los usuarios se demuestra entre sesiones de la misma instalación; la sincronización remota sigue pendiente. Los datos iniciales son ejemplos académicos, no información de abastecimiento real. El mapa utiliza internet para las teselas de OpenStreetMap; no hay GPS ni ubicación del usuario en este sprint. El botón Reportar conserva la restricción del visitante y la publicación se implementará en HU-08. La sesión se mantiene en memoria y se cierra al reiniciar la aplicación; cuentas y surtidores sí persisten.

La aceptación de Product Owner, la prueba en teléfono físico y la revisión de otro compañero están pendientes. No se declara la Definition of Done formalmente cumplida.

## Estructura

- lib/main.dart: inicio y tema.
- lib/core/app_store.dart: modelos, sesión, permisos y persistencia.
- lib/core/app_strings.dart: textos visibles.
- lib/screens/sprint_screens.dart: pantallas del incremento.
- test/sprint_test.dart: 9 pruebas automatizadas.
- docs/: backlog de 25 HU, tarjetas para Trello y evidencias.

## Repositorio GitHub

Proyecto: https://github.com/Rickv122/fila_cero

```sh
git clone https://github.com/Rickv122/fila_cero.git
cd fila_cero
flutter pub get
flutter run -d ID_DEL_DISPOSITIVO
```

El repositorio es privado. Para que otros integrantes o la docente puedan verlo deben tener acceso al repositorio. El tablero Trello y la aceptación de la Product Owner siguen pendientes. No se atribuyen revisiones de código ni Pull Requests que no se hayan realizado.

docs/Trello_tarjetas.csv contiene las tarjetas preparadas para el tablero, docs/backlog_25_hu.json contiene las 25 historias y docs/capturas conserva las evidencias y los resultados de pruebas. Las carpetas de compilación y las rutas locales se regeneran al abrir el proyecto.
## Repositorio GitHub

Proyecto: https://github.com/Rickv122/fila_cero

```sh
git clone https://github.com/Rickv122/fila_cero.git
cd fila_cero
flutter pub get
flutter run -d ID_DEL_DISPOSITIVO
```

El repositorio es privado. Para que otros integrantes o la docente puedan verlo deben tener acceso al repositorio. El tablero Trello y la aceptación de la Product Owner siguen pendientes. No se atribuyen revisiones de código ni Pull Requests que no se hayan realizado.

docs/Trello_tarjetas.csv contiene las tarjetas preparadas para el tablero, docs/backlog_25_hu.json contiene las 25 historias y docs/capturas conserva las evidencias y los resultados de pruebas. Las carpetas de compilación y las rutas locales se regeneran al abrir el proyecto.
