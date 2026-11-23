import test from 'node:test';
import assert from 'node:assert/strict';
import {addresses, ApiError, point, recommendations, route} from '../functions/_shared/geo_models.ts';

test('La matriz excluye destinos sin ruta, valores inválidos y fuera del límite', () => {
  const stations = ['A','B','C','D'].map((nombre)=>({nombre,estado:'disponible'}));
  const actual = recommendations({sources_to_targets:[[
    {target_index:0,source_index:0,distance:1500,time:200}, null,
    {target_index:2,source_index:0,distance:99999,time:1},
    {target_index:3,source_index:0,distance:null,time:null},
  ]]},stations,5);
  assert.deepEqual(actual.map(s=>s.nombre), ['A']);
});
test('Disponibilidad tiene prioridad; tiempo y distancia resuelven el orden', () => {
  const stations=[{nombre:'Limitada',estado:'limitada'},{nombre:'Lejana',estado:'disponible'},{nombre:'Cercana',estado:'disponible'}];
  const costs=[{target_index:0,distance:500,time:10},{target_index:1,distance:2000,time:100},{target_index:2,distance:1000,time:100}];
  assert.deepEqual(recommendations({sources_to_targets:[costs]},stations,5).map(s=>s.nombre), ['Cercana','Lejana','Limitada']);
});
test('Una respuesta con índices desconocidos o duplicados se rechaza', () => {
  const station=[{id:'uno'}];
  for(const costs of [[{target_index:2,distance:1,time:1}],[{target_index:0,distance:1,time:1},{target_index:0,distance:2,time:2}]]) {
    assert.throws(()=>recommendations({sources_to_targets:[costs]},station,5), ApiError);
  }
});
test('Routing transforma lon/lat a lat/lon sin inventar un recorrido ausente', () => {
  assert.throws(()=>route({features:[]}), (e:unknown)=>e instanceof ApiError && e.status===422);
  const result=route({features:[{properties:{distance:100,time:20},geometry:{type:'MultiLineString',coordinates:[[[-68.1,-16.5],[-68.2,-16.6]]]}}]});
  assert.deepEqual(result.points,[[-16.5,-68.1],[-16.6,-68.2]]);
  assert.equal(result.distance_m,100);
});
test('Se rechazan coordenadas no finitas y direcciones de otro país', () => {
  assert.throws(()=>point({lat:NaN,lon:0}),ApiError);
  assert.throws(()=>point({lat:0,lon:181}),ApiError);
  assert.deepEqual(addresses({results:[{lat:-16.5,lon:-68.1,country_code:'bo',formatted:'La Paz'},{lat:0,lon:0,country_code:'xx'}]}).map(p=>p.address),['La Paz']);
});
