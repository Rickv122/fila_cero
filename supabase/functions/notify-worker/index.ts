import {env, json, rpc} from '../_shared/fc_http.ts';

type Job = {id:string; bloqueo_id:string; identificador:string; tipo:string; estacion_id:string; titulo:string; cuerpo:string; historial_id:string; perfil_id:string};
let cached: {token:string; expires:number} | undefined;
const encode = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const part = (value:unknown) => encode(new TextEncoder().encode(JSON.stringify(value)));
function credentials() {
  const value = JSON.parse(atob(env('FCM_SERVICE_ACCOUNT_B64')));
  if (value.project_id !== 'filacero-b94e6') throw new Error('Invalid Firebase project');
  return value;
}
async function accessToken() {
  if (cached && cached.expires > Date.now()+60000) return cached.token;
  const account = credentials();
  const now = Math.floor(Date.now()/1000);
  const head = part({alg:'RS256',typ:'JWT'});
  const claims = part({iss:account.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600});
  const pem = String(account.private_key).replace(/-----[^-]+-----/g,'').replace(/\s/g,'');
  const key = await crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(pem),c=>c.charCodeAt(0)),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,new TextEncoder().encode(head+'.'+claims));
  const response = await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:head+'.'+claims+'.'+encode(new Uint8Array(signature))}),signal:AbortSignal.timeout(15000)});
  const value = await response.json();
  if (!response.ok || !value.access_token) throw new Error('Firebase authorization failed');
  cached = {token:value.access_token,expires:Date.now()+Number(value.expires_in)*1000};
  return cached.token;
}
function authorized(req:Request) {
  const expected = 'Bearer '+env('PUSH_WORKER_SECRET');
  const actual = req.headers.get('Authorization') || '';
  if (expected.length<30 || actual.length!==expected.length) return false;
  let difference=0;
  for(let i=0;i<expected.length;i++) difference |= expected.charCodeAt(i)^actual.charCodeAt(i);
  return difference===0;
}
Deno.serve(async req => {
  if (req.method!=='POST' || !authorized(req)) return json({error:'Acceso denegado'},401);
  const summary={sent:0,retry:0,cancelled:0};
  try {
    const jobs:Job[] = await rpc('fc3_push_claim',{p_limit:20});
    for(const job of jobs) {
      let success=false,invalid=false,message='No se pudo enviar el aviso';
      try {
        const token=await accessToken();
        const response=await fetch('https://fcm.googleapis.com/v1/projects/filacero-b94e6/messages:send',{
          method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},
          body:JSON.stringify({message:{[job.tipo==='fid'?'fid':'token']:job.identificador,
            notification:{title:job.titulo,body:job.cuerpo},
            data:{estacion_id:job.estacion_id,event_id:job.id,recipient_id:job.perfil_id},
            android:{priority:'high',ttl:'120s',collapse_key:job.id,notification:{tag:job.id}},
          }}),signal:AbortSignal.timeout(15000),
        });
        const value=await response.json();
        success=response.ok;
        invalid=(value.error?.details || []).some((e:Record<string,unknown>)=>e.errorCode==='UNREGISTERED');
        message=success?String(value.name):String(value.error?.status || 'FCM_ERROR');
        if(response.status===401)cached=undefined;
      } catch (_) {message='Conexión de mensajería no disponible';}
      await rpc('fc3_push_complete',{p_id:job.id,p_bloqueo:job.bloqueo_id,p_success:success,p_invalid_device:invalid,p_message:message});
      if(success)summary.sent++;else if(invalid)summary.cancelled++;else summary.retry++;
    }
    console.log(JSON.stringify({kind:'push_batch',...summary}));
    return json(summary);
  } catch (_) {
    console.error(JSON.stringify({kind:'push_batch_failed'}));
    return json({error:'No se pudo procesar la cola de avisos'},503);
  }
});
