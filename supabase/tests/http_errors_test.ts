import test from 'node:test';
import assert from 'node:assert/strict';
import {failure,provider,rpc} from '../functions/_shared/fc_http.ts';
import {ApiError} from '../functions/_shared/geo_models.ts';

test('Los fallos HTTP y tiempos agotados se convierten en mensajes sin claves', async () => {
  const timeout=failure(new DOMException('sensitive upstream URL','TimeoutError'));
  assert.equal(timeout.status,504);
  assert.equal((await timeout.json()).code,'timeout');
  const forbidden=failure(new ApiError(403,'Acceso administrativo requerido','forbidden'));
  assert.equal(forbidden.status,403);
});

test('Un proveedor ocupado conserva HTTP 429 y permite reintentar', async () => {
  const original=globalThis.fetch;
  const scope=globalThis as unknown as {Deno:unknown};
  scope.Deno={env:{get:(name:string)=>({GEOAPIFY_API_KEY:'unit-only-key',SUPABASE_URL:'https://unit.invalid',SUPABASE_SERVICE_ROLE_KEY:'unit-only-server'}[name])}};
  let calls=0;
  globalThis.fetch=async(input:RequestInfo|URL)=>{
    calls++;
    return String(input).includes('/rpc/fc3_geo_budget')
      ? new Response('{"wait_ms":0}',{status:200,headers:{'Content-Type':'application/json'}})
      : new Response('{}',{status:429});
  };
  try {
    await assert.rejects(()=>provider(new URL('https://provider.invalid/search')), (e:unknown)=>e instanceof ApiError && e.status===429 && e.code==='rate_limit');
    assert.equal(calls,2);
  } finally {globalThis.fetch=original;}
});

test('La confirmación de entrega acepta HTTP 204 sin intentar leer JSON', async () => {
  const original=globalThis.fetch;
  const scope=globalThis as unknown as {Deno:unknown};
  scope.Deno={env:{get:()=> 'unit-only'}};
  globalThis.fetch=async()=>new Response(null,{status:204});
  try {assert.equal(await rpc('fc3_push_complete',{}),null);}
  finally {globalThis.fetch=original;}
});
