import {ApiError} from './geo_models.ts';
export const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'GET, POST, OPTIONS'};
export const env = (name: string) => Deno.env.get(name) || '';
export function json(value: unknown, status=200) {return new Response(JSON.stringify(value),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});}
export function failure(error: unknown) {
  if (error instanceof ApiError) return json({error:error.message,code:error.code},error.status);
  if (error instanceof Error && (error.name === 'TimeoutError' || error.name === 'AbortError')) return json({error:'La consulta tardó demasiado. Vuelve a intentar.',code:'timeout'},504);
  console.error(JSON.stringify({kind:'internal_error',type:error instanceof Error ? error.name : 'unknown'}));
  return json({error:'No se pudo completar la operación. Vuelve a intentar.',code:'internal_error'},500);
}
export async function rpc(name: string, body: unknown, token?: string) {
  const key=token ? env('SUPABASE_ANON_KEY') : env('SUPABASE_SERVICE_ROLE_KEY');
  const res=await fetch(env('SUPABASE_URL')+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,Authorization:token || 'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
  if (res.status===204) return null;
  const data=await res.json();
  if (!res.ok) throw new ApiError(res.status===401?401:res.status===403||data.code==='42501'?403:400,String(data.message || 'No se pudo consultar la información.'),'database_error');
  return data;
}
export async function activeUser(req: Request) {
  const token=req.headers.get('Authorization') || '';
  if (!token.startsWith('Bearer ')) throw new ApiError(401,'Inicia sesión para continuar.','unauthorized');
  const res=await fetch(env('SUPABASE_URL')+'/auth/v1/user',{headers:{apikey:env('SUPABASE_ANON_KEY'),Authorization:token},signal:AbortSignal.timeout(12000)});
  if (!res.ok) throw new ApiError(401,'Tu sesión terminó. Vuelve a iniciar sesión.','unauthorized');
  const profile=await rpc('fc_query',{p_resource:'profile',p_params:{}},token);
  if (!profile || !profile.activo) throw new ApiError(403,'Tu cuenta no tiene acceso a esta operación.','forbidden');
  return {token,profile};
}
export async function reserve(units: number) {
  const result=await rpc('fc3_geo_budget',{p_units:units});
  if (result.wait_ms > 0) await new Promise(resolve=>setTimeout(resolve,result.wait_ms));
}
export async function provider(url: URL, method='GET', body?: unknown, units=1) {
  const key=env('GEOAPIFY_API_KEY');
  if (!key) throw new ApiError(503,'El servicio geográfico aún no está disponible.','not_configured');
  await reserve(units);
  url.searchParams.set('apiKey',key);
  const started=Date.now();
  const response=await fetch(url,{method,headers:{'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(18000)});
  console.log(JSON.stringify({provider:'geoapify',path:url.pathname,method,status:response.status,duration_ms:Date.now()-started}));
  if (!response.ok) throw new ApiError(response.status===429?429:502,response.status===429?'El servicio está ocupado. Espera un momento y reintenta.':'No se pudo obtener la información geográfica. Reintenta.',response.status===429?'rate_limit':'provider_error');
  return response;
}
