# Revisión del Sprint 2

El alta del responsable reúne datos, contraseña inicial, empresa y estaciones en un único formulario. El servidor crea la identidad mediante Auth y concede permisos comprobados en PostgreSQL. La edición conserva la cuenta. Los estados de usuario son Activo e Inactivo.

Se retiraron las invitaciones de la interfaz y de las operaciones activas de la BD, sus estados pendientes y su aceptación. El registro público continúa creando conductores y no exige confirmar correo. Las cuentas ficticias sirven para evaluación académica y no prueban propiedad de un buzón.

Los códigos y UUID siguen siendo claves internas. La interfaz identifica registros por nombre, empresa y dirección. Las disponibilidades mantienen su autor, fecha e historial y vencen a las dos horas.
