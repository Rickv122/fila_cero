# Estado del Sprint 2 de FilaCero

Verificación técnica del 16 de noviembre de 2026. Código del incremento en la rama `sprint-2`.

## Resultados comprobados

| Comprobación | Resultado |
|---|---|
| Análisis de Flutter | Sin incidencias |
| Dominio e interfaz | 15 pruebas aprobadas |
| Base de datos, Auth y permisos reales | 46 de 46 comprobaciones aprobadas |
| Vencimiento de disponibilidad | Comprobación SQL aprobada en transacción revertida |
| Android | Las cinco historias aprobadas en emulador Android 15 API 35; 13 capturas |
| iOS | Compilación y las cinco historias aprobadas en simulador iOS sobre Mac; 13 capturas |

Ejecución iOS: https://github.com/Rickv122/fila_cero/actions/runs/43978863216

El recorrido completo comprueba consulta pública, acceso del administrador, alta de una gasolinera, asignación de encargado, desactivación y reactivación, acceso del encargado, publicación e historial y consulta pública del estado publicado. Las pruebas HTTP también comprueban edición, paginación, transacciones atómicas y rechazos de escrituras no autorizadas.

Las capturas Android están en `docs/capturas_sprint2/` y las de iOS en `docs/capturas_ios/`. Los resultados del servidor están en `docs/evidencias/supabase-tests.json` y la referencia de CI en `docs/evidencias/ios-ci.json`. Se verificaron emulador y simulador; no se registra una prueba en dispositivos físicos.

## Alcance del incremento

HU-06 catálogo; HU-07 autenticación del personal; HU-08 publicación por encargado asignado; HU-09 consulta pública y filtros; HU-10 baja lógica y reactivación. Se utiliza base de datos y Auth de Supabase. El código activo usa listas y no incorpora mapas, geolocalización ni notificaciones.

Los datos son académicos para evaluar el software y no acreditan abastecimiento real. La disponibilidad vence a las dos horas. La reactivación no renueva información anterior. Los registros creados por las pruebas se desactivan al terminar y conservan su historial.

## Pendientes del equipo

La aceptación de la docente, las votaciones reales de Planning Poker, la Review, los formularios de feedback y la retrospectiva quedan pendientes de realizar y registrar. Las estimaciones de 32 SP son una propuesta para el equipo. Las funciones del Sprint 3 son propuestas sin implementar.

El PR está preparado para revisión; no se afirma que haya sido aprobado ni integrado en `main`. Las credenciales se entregan por separado y no forman parte del repositorio público ni del ZIP de código.
