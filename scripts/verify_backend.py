"""Read-only HTTPS checks. Pass a private JSON file with email and password.
Does not send mail or change business records. Never commit the credential file.
"""
import argparse
import json
import urllib.error
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--credentials', required=True)
parser.add_argument('--url', default='https://oejouwwxngyafftzfkux.supabase.co')
parser.add_argument('--publishable-key', default='sb_publishable_L9O4WSZeVF2O-_F9-XvAag_yDxyI8Rb')
args = parser.parse_args()
with open(args.credentials, encoding='utf-8') as source:
    credentials = json.load(source)
base = args.url.rstrip('/')
key = args.publishable_key

def request(path, body=None, token=None):
    headers = {'apikey': key, 'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=40) as response:
            data = response.read()
            return response.status, json.loads(data) if data else None
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())

status, session = request('/auth/v1/token?grant_type=password', {'email': credentials['email'], 'password': credentials['password']})
if status != 200:
    raise SystemExit('No se pudo iniciar la sesión de comprobación.')
token = session['access_token']
owner_id = session['user']['id']
checks = []

def check(ok, label):
    if not ok:
        raise SystemExit('Fallo: ' + label)
    checks.append(label)

status, data = request('/rest/v1/rpc/fc_query', {'p_resource': 'catalog', 'p_params': {}})
check(status == 200 and isinstance(data.get('rows'), list), 'Consulta pública por HTTPS')
for table in ['perfiles', 'empresas_operadoras', 'estaciones', 'vinculaciones_personal', 'asignaciones_responsables', 'historial_disponibilidad', 'favoritas', 'combustibles']:
    status, data = request('/rest/v1/' + table + '?select=*', token=token)
    check(status in (401, 403), 'Acceso directo denegado: ' + table)
status, data = request('/rest/v1/rpc/fc_query', {'p_resource': 'users', 'p_params': {}})
check(status >= 400, 'Visitante no consulta cuentas')
status, data = request('/rest/v1/rpc/fc_command', {'p_action': 'profile_save', 'p_data': {'nombre': 'Solicitud sin sesión'}})
check(status >= 400, 'Visitante no modifica perfiles')
status, data = request('/rest/v1/rpc/fc_query', {'p_resource': 'profile', 'p_params': {}}, token=token)
check(status == 200 and data['rol'] == 'administrador' and data['confirmado'], 'Perfil administrativo confirmado')
status, data = request('/functions/v1/staff-admin', {'action': 'unknown', 'id': owner_id}, token=token)
check(status == 400 and data.get('error') == 'Operación desconocida', 'Función de servidor valida identidad y autorización')
print(json.dumps({'passed': len(checks), 'checks': checks}, ensure_ascii=False, indent=2))
