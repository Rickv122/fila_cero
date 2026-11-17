# Revisión de Sprint 2

La revisión implementa las cinco historias corregidas: empresas y estaciones (HU-06), autenticación de tres roles (HU-07), cuentas y asignaciones (HU-08), disponibilidad trazable (HU-09) y consulta con favoritas (HU-10).

Los documentos y capturas de la primera versión se conservan como antecedentes. Las numeraciones y resultados de aquella versión no deben mezclarse con los 49 criterios de la planificación corregida.

El esquema público tiene diez tablas de negocio. Los datos previos sin fuente quedaron conservados en un esquema histórico privado; el catálogo de inicio de esta revisión procede de la ANH y no afirma existencias actuales de combustible.

Las pruebas SQL revierten sus modificaciones. La entrega de mensajes generales sigue dependiendo de configurar SMTP propio. El registro y la recuperación se comprobaron con el correo controlado del titular del proyecto.

Ver el README para ejecución, límites de correo, seguridad, configuración nativa y pruebas. Los accesos privados se entregan fuera de Git.

Por decisión del equipo se retiró la auditoría de cuentas. El modelo activo conserva diez tablas y las cinco historias suman 49 criterios. Los UUID internos y sus códigos legibles se mantienen.
