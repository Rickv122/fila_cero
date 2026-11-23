# Preparación del catálogo para las pruebas del Sprint 3

Actualizado: 23 de noviembre de 2026. Hay **20 estaciones activas**, con ubicación y responsables asignados. Se conservaron los 12 identificadores anteriores y sus relaciones; se añadieron ocho estaciones. Las 150 publicaciones previas conservan sus identificadores y fechas. La preparación generó 95 publicaciones nuevas mediante las cuentas responsables, sin alterar fechas antiguas.

## Cobertura

En Miraflores y su entorno se incorporaron Servifull Miraflores, Angelita Miraflores, Motoreco y Kantuta. También se añadieron Soinco, La Costanera, San Pedro y Cristo Autogas. La estación Miraflores anterior tiene ahora ubicación y disponibilidad reciente.

Dieciocho ubicaciones se obtuvieron de puntos cartográficos de OpenStreetMap. Las dos estaciones incompletas del grupo se renombraron Villa Adela y Villa Bolívar, con ubicaciones simuladas autorizadas. Sus registros se conservaron. Las denominaciones comerciales nuevas no sustituyen una comprobación de razón social o licencia. El [catálogo](catalogo_sprint3.json) identifica las fuentes y la naturaleza de cada ubicación. Atribución: [© OpenStreetMap contributors](https://www.openstreetmap.org/copyright).

La oferta configurada, las personas responsables y los estados de combustible son datos académicos para recorrer los criterios. No representan abastecimiento actual de los establecimientos.

## Estados preparados

| Combustible | Disponible | Limitada | Agotado |
| --- | ---: | ---: | ---: |
| Diésel Oil | 6 | 13 | 1 |
| Gasolina Especial | 16 | 3 | 0 |
| Gasolina Especial (+) | 15 | 3 | 0 |
| Gasolina Premium | 13 | 2 | 1 |
| Super Etanol 92 | 14 | 2 | 0 |

Todos los 89 estados configurados estaban vigentes al terminar la preparación. Villa Adela tiene Diésel agotado, para comprobar que una estación sin combustible utilizable no se recomienda. Soinco tiene Gasolina Premium agotada. Angelita Miraflores y Obrajes permiten comparar disponibilidad limitada con estaciones disponibles.

## Recorrido inmediato

1. Mantener la cuenta conductora y abrir **Mis preferencias**. Super Etanol 92 y 20 km ya cuentan con varias opciones; también se puede elegir Gasolina Especial.
2. Abrir **Recomendaciones**, seleccionar un origen en Miraflores y buscar de nuevo. Si la pantalla estaba abierta, recalcular para consultar los datos actuales.
3. Abrir **Cómo llegar** desde un resultado para comprobar la ruta, los kilómetros y el tiempo por calles.
4. Para avisos, guardar una estación en favoritas y activarlos. Desde su responsable publicar primero Limitada o Agotado y después Disponible. No se envía un nuevo aviso por repetir Disponible mientras el estado anterior siga vigente.

**Antes de exponer:** publicar de nuevo desde las cuentas responsables si pasaron dos horas. La información vence según la regla de la app; este catálogo no renueva fechas automáticamente. Elegir un origen de La Paz y autorizar ubicación o marcarlo manualmente. La distancia máxima se aplica al recorrido por calles.

## Verificación

- BD: 20 estaciones activas, 20 ubicadas, 20 con responsables habilitados y 89 estados vigentes.
- APIs reales: 16 opciones para Super Etanol 92 a 20 km desde cada uno de tres orígenes: Plaza Triangular, entorno de Pasoskanki y el punto simulado del emulador en Sopocachi. Las preferencias de Valentina se conservaron.
- Routing: las 20 estaciones devolvieron una ruta con distancia, tiempo y puntos de recorrido desde Miraflores, incluidas las dos ubicaciones simuladas.
- No se modificó el esquema, las reglas de autenticación ni el APK. Los cambios de datos se obtienen al volver a consultar en la aplicación instalada.

Los resultados medidos y las fechas están en [verificacion_catalogo_sprint3.json](verificacion_catalogo_sprint3.json). Esta verificación comprueba consultas y rutas reales; no marca como recorridos manualmente todos los criterios de las cinco HU.
