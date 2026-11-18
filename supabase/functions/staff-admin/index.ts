// Auth administration is server-only.
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Access-Control-Allow-Methods":"POST, OPTIONS"};
Deno.serve(async(req:Request)=>{
 const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json"}});
 if(req.method==="OPTIONS")return new Response(null,{headers:cors});
 if(req.method!=="POST")return reply({error:"Método no permitido"},405);
 const base=Deno.env.get("SUPABASE_URL")!,secret=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const authorization=req.headers.get("Authorization")??"";
 if(!authorization.startsWith("Bearer "))return reply({error:"Inicia sesión"},401);
 async function request(path:string,body:unknown,privileged=false,method="POST"){
  const response=await fetch(base+path,{method,headers:{apikey:secret,Authorization:privileged?"Bearer "+secret:authorization,"Content-Type":"application/json"},body:["GET","DELETE"].includes(method)?undefined:JSON.stringify(body)});
  const data=await response.json().catch(()=>({}));
  if(!response.ok)throw new Error(data.msg??data.message??data.error_description??data.error??"No se pudo completar la operación");
  return data;
 }
 const query=(resource:string,params:unknown={})=>request("/rest/v1/rpc/fc_query",{p_resource:resource,p_params:params});
 const command=(action:string,data:unknown)=>request("/rest/v1/rpc/fc_command",{p_action:action,p_data:data});
 try{
  await request("/auth/v1/user",null,false,"GET");
  const profile=await query("profile");
  if(!profile?.activo||profile.rol!=="administrador")return reply({error:"Acceso administrativo requerido"},403);
  const input=await req.json();
  if(input.action==="password"){
   const user=await query("user",{id:input.id});
   if(!user||user.id===profile.id)return reply({error:"Utiliza Mi cuenta para cambiar tu contraseña"},400);
   if(typeof input.password!=="string"||input.password.length<8)return reply({error:"Usa al menos 8 caracteres"},400);
   await request("/auth/v1/admin/users/"+user.id,{password:input.password,email_confirm:true},true,"PUT");
   return reply({message:"Contraseña actualizada"});
  }
  if(input.action!=="save")return reply({error:"Operación desconocida"},400);
  const email=String(input.email??"").trim().toLowerCase(),nombre=String(input.nombre??"").trim();
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||nombre.length<2||nombre.length>100||!["responsable","administrador","conductor"].includes(input.rol))return reply({error:"Revisa nombre, correo y rol"},400);
  if(input.id===profile.id)return reply({error:"Utiliza Mi cuenta para editar tu perfil"},400);
  const selected=Array.isArray(input.station_ids)?input.station_ids:[];
  if(input.rol==="responsable"){
   const options=await query("options");
   if(!options.empresas.some((e:{id:string,activo:boolean})=>e.id===input.empresa_id&&e.activo))return reply({error:"Selecciona una empresa activa"},400);
   for(const id of selected){const station=await query("station",{id});if(!station?.activo||station.empresa_id!==input.empresa_id)return reply({error:"Revisa las estaciones de la empresa"},400);}
  }
  let user:{id:string};let created=false;
  if(input.id){user=await query("user",{id:input.id});if(!user)return reply({error:"Cuenta no encontrada"},404);}
  else{
   if(typeof input.password!=="string"||input.password.length<8)return reply({error:"Usa al menos 8 caracteres"},400);
   if(typeof input.operation!=="string"||!/^[a-f0-9-]{36}$/i.test(input.operation))return reply({error:"Vuelve a abrir el formulario"},400);
   const existing=await query("lookup_email",{email});
   if(existing.length){
    user=existing[0];
    const authUser=await request("/auth/v1/admin/users/"+user.id,null,true,"GET");
    if(authUser.user_metadata?.alta_operacion!==input.operation)return reply({error:"El correo ya tiene una cuenta. Selecciónala en Usuarios para editarla."},409);
   }else{
    const result=await request("/auth/v1/admin/users",{email,password:input.password,email_confirm:true,user_metadata:{nombre,alta_operacion:input.operation}},true);
    user=result.user??result;created=true;
   }
  }
  try{await command("staff_save",{id:user.id,nombre,contacto:String(input.contacto??""),rol:input.rol,empresa_id:input.empresa_id,station_ids:selected});}
  catch(error){if(created){try{await command("user_state",{id:user.id,activo:false});}catch{ /* Preserve the original error and the existing identity. */ }}throw error;}
  return reply({id:user.id,message:created?"Cuenta registrada. Ya puede iniciar sesión.":"Datos y asignaciones actualizados."});
 }catch(error){return reply({error:error instanceof Error?error.message:"No se pudo completar la operación"},400);}
});
