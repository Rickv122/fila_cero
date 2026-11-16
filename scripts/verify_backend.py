"""Pruebas reales de Auth, CRUD, consultas, transacciones y restricciones.
Lee accesos privados; solo escribe nombres y resultados de pruebas.
Los registros creados se conservan mediante baja lógica.
"""
import argparse
import concurrent.futures
import datetime
import json
from pathlib import Path
import urllib.error
import urllib.request
import uuid

parser=argparse.ArgumentParser()
parser.add_argument('--credentials',required=True)
parser.add_argument('--output',required=True)
args=parser.parse_args()
private=json.loads(Path(args.credentials).read_text(encoding='utf-8'))
base=private['url']
public_key='sb_publishable_L9O4WSZeVF2O-_F9-XvAag_yDxyI8Rb'
results=[]
tokens={}

def req(path,method='GET',body=None,role=None):
    headers={'apikey':public_key,'Content-Type':'application/json'}
    if role:headers['Authorization']='Bearer '+tokens[role]['access_token']
    request=urllib.request.Request(base+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method)
    try:
        with urllib.request.urlopen(request,timeout=30) as response:
            raw=response.read();return response.status,json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw=error.read()
        try:value=json.loads(raw)
        except json.JSONDecodeError:value={'message':'Respuesta HTTP no JSON'}
        return error.code,value

def rpc(name,body,role=None):return req('/rest/v1/rpc/'+name,'POST',body,role)
def check(name,condition):
    results.append({'case':name,'passed':bool(condition)})
    if not condition:raise AssertionError(name)
def login(purpose):
    account=next(a for a in private['users'] if a['purpose']==purpose)
    status,response=req('/auth/v1/token?grant_type=password','POST',{'email':account['email'],'password':account['password']})
    check('Autenticación real '+purpose,status==200 and bool(response.get('access_token')))
    tokens[purpose]=response
    return account

query={'p_nombre':'','p_ciudad':None,'p_combustible':None,'p_inactivas':False,'p_asignadas':False,'p_pagina':0}
created=[]
admin=None
try:
    status,public=rpc('consultar_gasolineras',query)
    check('Consulta pública sin cuenta',status==200 and len(public['elementos'])>=4)
    for purpose in ['administrador','encargado','inactivo','sin_perfil']:
        if purpose=='encargado':
            for account in [a for a in private['users'] if a['purpose']=='encargado']:
                status,data=req('/auth/v1/token?grant_type=password','POST',{'email':account['email'],'password':account['password']})
                key='sopocachi' if 'sopocachi' in account['email'] else 'elalto'
                check('Autenticación real encargado '+key,status==200);tokens[key]=data
        else:
            value=login(purpose)
            if purpose=='administrador':admin=value
    status,_=req('/auth/v1/token?grant_type=password','POST',{'email':admin['email'],'password':'Incorrecta-123!'})
    check('Contraseña incorrecta rechazada',status in (400,401))
    status,_=req('/rest/v1/perfiles')
    check('Perfiles privados para visitante',status in (401,403))
    status,own=req('/rest/v1/perfiles',role='sopocachi')
    check('Encargado solo lee su propio perfil',status==200 and len(own)==1 and own[0]['rol']=='encargado')
    status,_=req('/rest/v1/perfiles?id=eq.'+own[0]['id'],'PATCH',{'rol':'administrador'},'sopocachi')
    check('No puede elevar su rol editando perfil',status in (401,403))
    status,_=req('/auth/v1/user','PUT',{'data':{'rol':'administrador'}},'sopocachi')
    check('Preparación de intento con metadatos de usuario',status==200)
    fuels=req('/rest/v1/combustibles?select=id,nombre')[1]
    fuel_ids=[f['id'] for f in fuels[:2]]
    sopocachi=next(s for s in public['elementos'] if s['nombre']=='Surtidor Sopocachi')
    change={'p_surtidor':sopocachi['id'],'p_cambios':[{'combustible_id':f['combustible_id'],'estado':'hay'} for f in sopocachi['combustibles']]}
    for role in [None,'administrador','elalto','inactivo','sin_perfil']:
        status,_=rpc('actualizar_disponibilidad',change,role)
        check('Publicación denegada '+str(role),status in (401,403))
    status,_=rpc('actualizar_disponibilidad',change,'sopocachi')
    check('Encargado asignado publica disponibilidad',status==204 or status==200)
    status,refreshed=rpc('consultar_gasolineras',{**query,'p_nombre':'Sopocachi'})
    check('Otra sesión recupera actualización y autor',status==200 and all(f['estado']=='hay' and f['informado_por']=='Encargado Sopocachi' for f in refreshed['elementos'][0]['combustibles']))
    stem='Validación Sprint2 '+uuid.uuid4().hex[:6]
    draft={'p_id':None,'p_nombre':stem,'p_direccion':'Av. Validación 100','p_ciudad':'La Paz','p_latitud':-16.51,'p_longitud':-68.13,'p_combustibles':fuel_ids}
    for role in [None,'sopocachi','inactivo','sin_perfil']:
        status,_=rpc('guardar_surtidor',draft,role)
        check('Catálogo protegido '+str(role),status in (401,403))
    for bad in [{'p_nombre':' '},{'p_direccion':''},{'p_latitud':91},{'p_longitud':181},{'p_ciudad':'Otra'},{'p_combustibles':[]},{'p_combustibles':[str(uuid.uuid4())]}]:
        status,_=rpc('guardar_surtidor',{**draft,**bad},'administrador')
        check('Validación de formulario en servidor '+next(iter(bad)),status==400)
    status,new_id=rpc('guardar_surtidor',draft,'administrador');check('CREATE remoto',status==200 and isinstance(new_id,str));created.append(new_id)
    status,same=rpc('guardar_surtidor',{**draft,'p_id':new_id,'p_direccion':'Av. Corregida 200'},'administrador')
    check('UPDATE conserva identificador',status==200 and same==new_id)
    status,filtered=rpc('consultar_gasolineras',{**query,'p_nombre':stem.lower(),'p_ciudad':'La Paz','p_combustible':fuel_ids[0]})
    check('Filtros combinados y búsqueda sin distinguir mayúsculas',status==200 and len(filtered['elementos'])==1 and filtered['elementos'][0]['direccion']=='Av. Corregida 200')
    status,empty=rpc('consultar_gasolineras',{**query,'p_nombre':'inexistente-'+uuid.uuid4().hex})
    check('Consulta sin coincidencias',status==200 and empty['elementos']==[])
    manager=next(a for a in private['users'] if 'sopocachi' in a['email'])
    status,_=rpc('asignar_encargado',{'p_surtidor':new_id,'p_perfil':manager['id'],'p_activo':True},'administrador')
    check('Asignación controlada de encargado',status in (200,204))
    valid={'p_surtidor':new_id,'p_cambios':[{'combustible_id':fuel_ids[0],'estado':'poco'}]}
    status,_=rpc('actualizar_disponibilidad',valid,'sopocachi');check('Disponibilidad con historial',status in (200,204))
    _,history=req('/rest/v1/historial_disponibilidad?surtidor_id=eq.'+new_id,role='administrador')
    check('Autor y hora registrados por servidor',len(history)==1 and history[0]['autor_id']==manager['id'] and bool(history[0]['creado_en']))
    status,_=rpc('actualizar_disponibilidad',{'p_surtidor':new_id,'p_cambios':[{'combustible_id':fuel_ids[0],'estado':'hay'},{'combustible_id':fuel_ids[1],'estado':'INVALIDO'}]},'sopocachi')
    _,history_after=req('/rest/v1/historial_disponibilidad?surtidor_id=eq.'+new_id,role='administrador')
    _,unchanged=rpc('consultar_gasolineras',{**query,'p_nombre':stem})
    check('Transacción revierte estado e historial ante fallo',status==400 and len(history_after)==1 and next(f for f in unchanged['elementos'][0]['combustibles'] if f['combustible_id']==fuel_ids[0])['estado']=='poco')
    for table,method,body in [('surtidores','PATCH',{'nombre':'Intrusión'}),('surtidores','DELETE',None),('historial_disponibilidad','PATCH',{'estado_nuevo':'hay'})]:
        selector=('?id=eq.' if table=='surtidores' else '?surtidor_id=eq.')+new_id
        status,response= req('/rest/v1/'+table+selector,method,body,'sopocachi')
        if status not in (401,403):
            print(json.dumps({'unexpected_http':status,'database_error':response}))
        check('Escritura directa denegada '+table+' '+method,status in (401,403))
    status,_=rpc('cambiar_estado_surtidor',{'p_id':new_id,'p_activo':False},'administrador')
    check('Baja lógica',status in (200,204))
    _,hidden=rpc('consultar_gasolineras',{**query,'p_nombre':stem})
    check('Inactiva oculta en consulta pública',hidden['elementos']==[])
    status,_=rpc('actualizar_disponibilidad',valid,'sopocachi')
    check('Encargado no publica en gasolinera inactiva',status==403)
    _,private_rows=req('/rest/v1/surtidores?id=eq.'+new_id,role='administrador')
    _,saved_history=req('/rest/v1/historial_disponibilidad?surtidor_id=eq.'+new_id,role='administrador')
    check('Baja conserva fila, identidad e historial',len(private_rows)==1 and private_rows[0]['activo']==False and len(saved_history)==1)
    status,_=rpc('cambiar_estado_surtidor',{'p_id':new_id,'p_activo':True},'administrador')
    _,reactivated=rpc('consultar_gasolineras',{**query,'p_nombre':stem})
    check('Reactivación no renueva disponibilidad antigua',status in (200,204) and reactivated['elementos'][0]['id']==new_id and all(f['estado']=='sin_informacion' for f in reactivated['elementos'][0]['combustibles']))
    prefix='Paginación '+uuid.uuid4().hex[:6]
    def add(i):
        status,value=rpc('guardar_surtidor',{**draft,'p_nombre':f'{prefix} {i:02d}'},'administrador')
        if status!=200:raise AssertionError('Preparación de paginación')
        return value
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:created.extend(executor.map(add,range(21)))
    _,first=rpc('consultar_gasolineras',{**query,'p_nombre':prefix})
    _,second=rpc('consultar_gasolineras',{**query,'p_nombre':prefix,'p_pagina':1})
    check('Paginación estable de veinte resultados',len(first['elementos'])==20 and first['hay_mas'] and len(second['elementos'])==1 and not second['hay_mas'] and not ({s['id'] for s in first['elementos']}&{s['id'] for s in second['elementos']}))
finally:
    for station_id in created:
        code,_=rpc('cambiar_estado_surtidor',{'p_id':station_id,'p_activo':False},'administrador')
        if code not in (200,204):results.append({'case':'Conservar registro de prueba mediante baja lógica','passed':False})
    report={'executed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'project':private['project'],
      'results':results,'passed':sum(r['passed'] for r in results),'total':len(results),'physical_deletes':0}
    out=Path(args.output);out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'passed':report['passed'],'total':report['total']}))
