export class ApiError extends Error {
  constructor(public status: number, message: string, public code = 'api_error') { super(message); }
}
export type RecordValue = Record<string, unknown>;
export function record(value: unknown): RecordValue {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new ApiError(502, 'La respuesta del servicio no es válida.', 'invalid_response');
  return value as RecordValue;
}
export function point(value: unknown): {lat: number; lon: number} {
  const p = record(value);
  if (typeof p.lat !== 'number' || typeof p.lon !== 'number' || !Number.isFinite(p.lat) || !Number.isFinite(p.lon) || p.lat < -90 || p.lat > 90 || p.lon < -180 || p.lon > 180) {
    throw new ApiError(400, 'Selecciona una ubicación válida.', 'invalid_point');
  }
  return {lat:p.lat,lon:p.lon};
}
export function addresses(value: unknown) {
  const raw = record(value);
  if (!Array.isArray(raw.results)) throw new ApiError(502, 'No se pudo interpretar la dirección.', 'invalid_response');
  return raw.results.map(record).filter(p => typeof p.lat === 'number' && typeof p.lon === 'number' && p.country_code === 'bo')
    .map(p => ({...point(p), address:String(p.formatted || p.address_line1 || ''), city:String(p.city || p.town || ''), country_code:'bo'}));
}
export function recommendations(value: unknown, stations: RecordValue[], maximumKm: number) {
  const raw = record(value);
  if (!Array.isArray(raw.sources_to_targets) || !Array.isArray(raw.sources_to_targets[0])) throw new ApiError(502, 'No se pudieron interpretar las distancias.', 'invalid_response');
  const seen = new Set<number>();
  const result: RecordValue[] = [];
  for (const entry of raw.sources_to_targets[0]) {
    if (entry === null) continue;
    const cost = record(entry);
    const index = Number(cost.target_index);
    if (!Number.isInteger(index) || index < 0 || index >= stations.length || seen.has(index)) throw new ApiError(502, 'La comparación de estaciones no es válida.', 'invalid_response');
    seen.add(index);
    if (typeof cost.distance !== 'number' || typeof cost.time !== 'number' || !Number.isFinite(cost.distance) || !Number.isFinite(cost.time) || cost.distance < 0 || cost.time < 0) continue;
    if (cost.distance > maximumKm * 1000) continue;
    result.push({...stations[index],distance_m:cost.distance,time_s:cost.time});
  }
  return result.sort((a,b) => (a.estado === 'disponible' ? 0 : 1) - (b.estado === 'disponible' ? 0 : 1)
    || Number(a.time_s)-Number(b.time_s) || Number(a.distance_m)-Number(b.distance_m) || String(a.nombre).localeCompare(String(b.nombre),'es'));
}
export function route(value: unknown) {
  const raw = record(value);
  if (!Array.isArray(raw.features) || raw.features.length === 0) throw new ApiError(422, 'No se encontró un recorrido por carretera para estos puntos.', 'no_route');
  const feature = record(raw.features[0]); const props = record(feature.properties); const geometry = record(feature.geometry);
  const lines = geometry.type === 'MultiLineString' ? geometry.coordinates : geometry.type === 'LineString' ? [geometry.coordinates] : null;
  if (!Array.isArray(lines)) throw new ApiError(502, 'El recorrido recibido no es válido.', 'invalid_response');
  const points: number[][] = [];
  for (const line of lines) {
    if (!Array.isArray(line)) throw new ApiError(502, 'El recorrido recibido no es válido.', 'invalid_response');
    for (const coordinate of line) {
      if (!Array.isArray(coordinate) || coordinate.length < 2) throw new ApiError(502, 'El recorrido recibido no es válido.', 'invalid_response');
      const p=point({lat:coordinate[1],lon:coordinate[0]});points.push([p.lat,p.lon]);
    }
  }
  if (points.length < 2 || typeof props.distance !== 'number' || typeof props.time !== 'number' || !Number.isFinite(props.distance) || !Number.isFinite(props.time) || props.distance < 0 || props.time < 0) throw new ApiError(502, 'El recorrido recibido no es válido.', 'invalid_response');
  return {points,distance_m:props.distance,time_s:props.time};
}
