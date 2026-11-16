"""Alta controlada de cuentas de evaluación. Nunca ejecutar desde la app Flutter.

Requiere CLI Supabase autenticada con acceso de administración al proyecto.
La clave privilegiada existe solo en memoria. El archivo de accesos debe quedar
fuera del repositorio y no se debe publicar junto al código fuente.
"""
import argparse
import json
from pathlib import Path
import secrets
import subprocess
import urllib.request

parser=argparse.ArgumentParser()
parser.add_argument('--cli',default='supabase')
parser.add_argument('--project',required=True)
parser.add_argument('--output',required=True)
args=parser.parse_args()
result=subprocess.run([args.cli,'projects','api-keys',f'--remote={args.project}','--reveal','--output-format','json'],capture_output=True,text=True,encoding='utf-8',check=True)
bag=json.loads(result.stdout)
keys=bag if isinstance(bag,list) else bag.get('keys',bag.get('api_keys',[]))
key=next((k['api_key'] for k in keys if k.get('name')=='service_role'),None)
if key is None:
    key=next((k.get('api_key') or k.get('key') for k in keys if k.get('type')=='secret' and not k.get('disabled')),None)
if not key:
    raise SystemExit('La CLI no devolvió una clave de administración utilizable.')
base=f'https://{args.project}.supabase.co'
headers={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def request(path,body=None):
    req=urllib.request.Request(base+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method='GET' if body is None else 'POST')
    with urllib.request.urlopen(req,timeout=30) as response:
        return json.load(response)

existing=request('/auth/v1/admin/users?page=1&per_page=100').get('users',[])
output=Path(args.output)
previous=json.loads(output.read_text(encoding='utf-8'))['users'] if output.exists() else []
accounts=[
    ('admin@filacero.test','Administrador','administrador'),
    ('encargado.sopocachi@filacero.test','Encargado Sopocachi','encargado'),
    ('encargado.elalto@filacero.test','Encargado El Alto','encargado'),
    ('inactivo@filacero.test','Personal inactivo','inactivo'),
    ('sin.permisos@filacero.test','Cuenta sin autorización','sin_perfil'),
]
users=[]
for email,name,purpose in accounts:
    current=next((u for u in existing if u['email']==email),None)
    old=next((u for u in previous if u['email']==email),None)
    if current:
        if not old:
            raise SystemExit(f'La cuenta {email} ya existe. No se reemplazó su contraseña.')
        users.append(old)
        continue
    password='Fc2!'+secrets.token_urlsafe(18)
    user=request('/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True,'user_metadata':{'nombre':name}})
    users.append({'id':user.get('id',user.get('user',{}).get('id')),'email':email,'password':password,'name':name,'purpose':purpose})
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps({'project':args.project,'url':base,'users':users},indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'accounts':[{'email':u['email'],'id':u['id']} for u in users]}))
