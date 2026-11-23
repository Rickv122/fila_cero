import {ApiError,addresses,point,recommendations,record,route} from '../_shared/geo_models.ts';
import {activeUser,cors,failure,json,provider,rpc} from '../_shared/fc_http.ts';

const tileCache=new Map<string,{bytes:ArrayBuffer,expires:number}>();
Deno.serve(async req=>{
 try {
  if (req.method==='OPTIONS') return new Response('ok',{headers:cors});
  const path=new URL(req.url).pathname;
  if (req.method==='GET') {
   const match=path.match(/\/tile\/(\d+)\/(\d+)\/(\d+)\.png$/);
   if (!match) throw new ApiError(404,'Recurso no encontrado.');
   const [z,x,y]=match.slice(1).map(Number);
   if (z>19 || x>=2**z || y>=2**z) throw new ApiError(400,'Mapa no válido.');
   const key=`${z}/${x}/${y}`;let cached=tileCache.get(key);
   if (!cached || cached.expires<Date.now()) {
    const response=await provider(new URL('https://maps.geoapify.com/v1/tile/osm-carto/'+key+'.png'),'GET',undefined,.25);
    cached={bytes:await response.arrayBuffer(),expires:Date.now()+86400000};
    if(tileCache.size>350)tileCache.delete(tileCache.keys().next().value!);
    tileCache.set(key,cached);
   }
   return new Response(cached.bytes,{headers:{...cors,'Content-Type':'image/png','Cache-Control':'public,max-age=86400'}});
  }
  if(req.method!=='POST')throw new ApiError(405,'Método no permitido.');
  const user=await activeUser(req);
  const body=record(await req.json());const action=body.action;
  if(action==='search'){
   const text=String(body.text || '').trim();
   if(text.length<3 || text.length>250)throw new ApiError(400,'Escribe una dirección de al menos tres caracteres.');
   const url=new URL('https://api.geoapify.com/v1/geocode/search');
   url.search=new URLSearchParams({text,filter:'countrycode:bo',lang:'es',limit:'5',format:'json'}).toString();
   return json({results:addresses(await (await provider(url)).json())});
  }
  if(action==='reverse'){
   const p=point(body.point);const url=new URL('https://api.geoapify.com/v1/geocode/reverse');
   url.search=new URLSearchParams({lat:String(p.lat),lon:String(p.lon),lang:'es',limit:'1',format:'json'}).toString();
   return json({results:addresses(await (await provider(url)).json())});
  }
  if(action==='recommend'){
   const origin=point(body.origin);
   const current=await rpc('fc3_query',{p_resource:'recommendation_candidates',p_params:{}},user.token);
   const stations=current.stations as Record<string,unknown>[];
   if(!stations.length)return json({stations:[],preferences:current.preferences,unreachable:0,calculated_at:new Date().toISOString()});
   // Candidate selection limits credit use; every retained result still uses road distances.
   const approximate=(s:Record<string,unknown>)=>Math.hypot(Number(s.latitud)-origin.lat,(Number(s.longitud)-origin.lon)*Math.cos(origin.lat*Math.PI/180));
   const candidates=stations.sort((a,b)=>approximate(a)-approximate(b)).slice(0,20);
   const payload={mode:'drive',sources:[{location:[origin.lon,origin.lat]}],targets:candidates.map(s=>({location:[s.longitud,s.latitud]}))};
   const response=await (await provider(new URL('https://api.geoapify.com/v1/routematrix'),'POST',payload,candidates.length)).json();
   const rows=recommendations(response,candidates,Number(current.preferences.distancia_maxima_km));
   // Revalidate after the provider request so expiry or account changes cannot become fresh results.
   const fresh=await rpc('fc3_query',{p_resource:'recommendation_candidates',p_params:{}},user.token);
   if(fresh.preferences.combustible_id!==current.preferences.combustible_id || fresh.preferences.distancia_maxima_km!==current.preferences.distancia_maxima_km)throw new ApiError(409,'Tus preferencias cambiaron. Actualiza las recomendaciones.');
   const valid=new Map((fresh.stations as Record<string,unknown>[]).map(s=>[s.id,s]));
   return json({stations:rows.filter(s=>valid.has(s.id) && valid.get(s.id)!.latitud===s.latitud && valid.get(s.id)!.longitud===s.longitud).map(s=>({...s,...valid.get(s.id),distance_m:s.distance_m,time_s:s.time_s})).sort((a,b)=>(a.estado==='disponible'?0:1)-(b.estado==='disponible'?0:1)||Number(a.time_s)-Number(b.time_s)||Number(a.distance_m)-Number(b.distance_m)),preferences:fresh.preferences,calculated_at:new Date().toISOString()});
  }
  if(action==='route'){
   const origin=point(body.origin);const id=String(body.id || '');
   let station=await rpc('fc3_query',{p_resource:'location',p_params:{id}},user.token);
   if(!station || station.latitud===null || station.longitud===null || !station.station.disponible)throw new ApiError(422,'Esta estación todavía no tiene una ubicación disponible.','missing_location');
   const url=new URL('https://api.geoapify.com/v1/routing');
   url.search=new URLSearchParams({waypoints:`${origin.lat},${origin.lon}|${station.latitud},${station.longitud}`,mode:'drive',lang:'es',format:'geojson'}).toString();
   const result=route(await (await provider(url)).json());
   const fresh=await rpc('fc3_query',{p_resource:'location',p_params:{id}},user.token);
   if(!fresh || !fresh.station.disponible || fresh.latitud!==station.latitud || fresh.longitud!==station.longitud)throw new ApiError(409,'La ubicación de la estación cambió. Vuelve a calcular.');
   station=fresh;
   return json({...result,station,origin,calculated_at:new Date().toISOString()});
  }
  throw new ApiError(400,'Operación geográfica desconocida.');
 }catch(error){return failure(error);}
});
