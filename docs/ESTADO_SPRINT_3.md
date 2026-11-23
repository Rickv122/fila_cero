# Verificación del Sprint 3

Fecha: 23 de noviembre de 2026. Entorno: Android 15 API 35, Flutter 3.47.9, proyecto Supabase FilaCero.

## Regresión de revocación al desactivar una cuenta

Durante la revisión por criterios se detectó que una cuenta desactivada podía recibir un rechazo al revocar su dispositivo antes de cerrar sesión. La migración `sprint3_revocacion_cuenta_inactiva` permite revocar únicamente el dispositivo propio con identidad autenticada, aunque la cuenta esté inactiva. Las demás operaciones siguen requiriendo cuenta activa.

Las cinco comprobaciones de `supabase/tests/sprint3_revocation.sql` pasaron con ROLLBACK: revocación propia, protección de dispositivos ajenos, bloqueo de preferencias, bloqueo de registro de dispositivos y rechazo de una solicitud sin identidad. También volvió a pasar `sprint3_invariants.sql`. El cambio se aplica en el servidor y conserva la compatibilidad con el APK 3.0.0; el recorrido manual con el usuario continúa por criterios.

| Comprobación | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias. |
| `flutter test` | 15 pruebas aprobadas, incluidas regresiones del Sprint 2. |
| Modelos y manejo HTTP del servidor | 8 pruebas aprobadas; cubren matrices incompletas, orden, datos inválidos, ausencia de ruta, HTTP 429, tiempo agotado y respuestas 204. |
| Reglas de BD | Preferencias, permisos, opt-in, transición de estado, deduplicación y cancelación verificadas con ROLLBACK. |
| APIs geográficas reales | Geocoding, reverse geocoding, Route Matrix y Routing respondieron con datos reales. |
| Accesos y datos inválidos | Seis casos HTTP reales rechazados con los códigos esperados. |
| Recorrido Android HU-11 a HU-15 | Aprobado con cuentas de conductor, responsable y administrador. |
| Notificación real | Publicación del responsable → cola → Firebase → aviso en primer plano → detalle actualizado. |
| Ubicación administrativa | Búsqueda, selección, guardado y conservación de la identidad de la estación aprobados. |

Las [capturas por historia](capturas_sprint3/) y [etapas verificadas](evidencia_sprint3.json) corresponden al emulador real. Los fallos del proveedor y tiempos agotados de los contratos se verificaron con transporte simulado; las búsquedas, rutas, matriz y envío FCM se probaron contra los servicios reales.

## Comprobación manual pendiente

La entrega implementa la recepción y navegación de notificaciones del sistema. La recepción y apertura en segundo plano debe comprobarse también en el teléfono de exposición: activar avisos, minimizar la app, publicar primero Limitada o Agotado y después Disponible desde el responsable, y tocar la notificación. La ejecución automatizada documentada verificó primer plano.

El trabajo y verificación de iOS quedan pendientes por decisión del equipo. La información de combustible vence a las dos horas; las pruebas generan publicaciones académicas recientes y no renuevan fechas automáticamente.

Las tablas nuevas tienen RLS con denegación predeterminada y permisos directos revocados a los clientes; las operaciones pasan por funciones que revisan identidad y rol. La revisión de Supabase informó estas tablas sin políticas como información, coherente con ese acceso por RPC. La protección de contraseñas filtradas continúa como aviso previo de configuración de Auth: [documentación de Supabase](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Ampliación del catálogo de exposición

Se completaron los 12 registros anteriores y se añadieron ocho estaciones: 20 activas, ubicadas y con responsables. Los 89 estados académicos vigentes incluyen opciones para los cinco combustibles. Se verificaron recomendaciones desde tres orígenes y rutas reales a las 20 estaciones, conservando preferencias y el historial anterior. Preparación y fuentes: [PRUEBAS_CATALOGO_SPRINT_3.md](PRUEBAS_CATALOGO_SPRINT_3.md).
