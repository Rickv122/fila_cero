// Administrative Auth operations stay on the server. No privileged key is sent to Flutter.
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Access-Control-Allow-Methods":"POST, OPTIONS"};
Deno.serve(async (req: Request) => {
 const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json"}});
 if(req.method==="OPTIONS")return new Response(null,{headers:cors});
 if(req.method!=="POST")return reply({error:"Método no permitido"},405);
 const base=Deno.env.get("SUPABASE_URL")!;
 const secret=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const authorization=req.headers.get("Authorization")??"";
 if(!authorization.startsWith("Bearer "))return reply({error:"Inicia sesión"},401);
 async function request(path:string,body:unknown,privileged=false,method="POST"){
  const response=await fetch(base+path,{method,headers:{"apikey":secret,"Authorization":privileged?"Bearer "+secret:authorization,"Content-Type":"application/json"},body:method==="GET"?undefined:JSON.stringify(body)});
  const data=await response.json().catch(()=>({}));
  if(!response.ok)throw new Error(data.msg??data.message??data.error_description??data.error??"No se pudo completar la operación");
  return data;
 }
 async function query(resource:string,params:unknown={}){return await request("/rest/v1/rpc/fc_query",{p_resource:resource,p_params:params});}
 async function command(action:string,data:unknown){return await request("/rest/v1/rpc/fc_command",{p_action:action,p_data:data});}
 try{
  // The Auth server verifies the access token; business permissions are checked live, not from editable claims.
  await request("/auth/v1/user",null,false,"GET");
  const profile=await query("profile");
  if(!profile?.activo||!profile?.confirmado||profile.rol!=="administrador")return reply({error:"Acceso administrativo requerido"},403);
  const input=await req.json();
  if(input.action==="invite"){
   const email=String(input.email??"").trim().toLowerCase();
   const nombre=String(input.nombre??"").trim();
   if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||nombre.length<2||nombre.length>100||!["responsable","administrador"].includes(input.rol))return reply({error:"Revisa nombre, correo y función"},400);
   if(input.rol==="responsable"){
    const options=await query("options");
    if(!options.empresas.some((e:{id:string,activo:boolean})=>e.id===input.empresa_id&&e.activo))return reply({error:"Selecciona una empresa activa"},400);
   }
   const existing=await query("lookup_email",{email});
   let user=existing[0];let created=false;
   if(!user){
    const invited=await request("/auth/v1/invite?redirect_to="+encodeURIComponent("filacero://auth-callback"),{email,data:{nombre}},true);
    user=invited.user??invited;created=true;
   }
   try{await command("invite_stage",{id:user.id,rol:input.rol,empresa_id:input.empresa_id});}
   catch{
    return reply({error:"El acceso quedó pendiente sin permisos de personal. Reintenta la invitación con el mismo correo; no se duplicará la identidad."},409);
   }
   return reply({id:user.id,message:created?"Invitación enviada. Falta confirmar el acceso y aceptar la habilitación.":"Identidad reutilizada. La invitación está en Mi cuenta → Invitaciones de personal."});
  }
  const user=await query("user",{id:input.id});
  if(!user)return reply({error:"Cuenta no encontrada"},404);
  if(input.action==="recover"){
   await request("/auth/v1/recover?redirect_to="+encodeURIComponent("filacero://auth-callback"),{email:user.email},true);
   return reply({message:"Instrucciones enviadas al correo de la cuenta. Su titular podrá recuperar el acceso y solicitar el cambio de correo desde Mi cuenta."});
  }
  if(input.action==="resend"){
   if(!user.rol_invitado)return reply({error:"No hay una habilitación de personal pendiente"},400);
   await command("invite_renew",{id:user.id});
   if(!user.confirmado){
    await request("/auth/v1/invite?redirect_to="+encodeURIComponent("filacero://auth-callback"),{email:user.email,data:{nombre:user.nombre}},true);
    return reply({message:"Invitación de acceso reenviada."});
   }
   return reply({message:"Invitación renovada. Está disponible en Mi cuenta → Invitaciones de personal."});
  }
  return reply({error:"Operación desconocida"},400);
 }catch(error){
  const message=error instanceof Error?error.message:"No se pudo completar la operación";
  return reply({error:message.includes("not authorized")?"El proveedor de correo actual solo permite destinatarios del equipo de Supabase. Configura SMTP para invitar a otras personas.":message},400);
 }
});