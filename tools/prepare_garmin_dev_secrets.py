"""Prepara secretos Dev localmente; no despliega ni los imprime o envía.

Primera instalación: python tools/prepare_garmin_dev_secrets.py --first-setup
Actualizaciones: python tools/prepare_garmin_dev_secrets.py
Conserva la clave de cifrado existente: cambiarla dejaría ilegibles los tokens.
"""
import base64
import argparse
import getpass
from pathlib import Path
import secrets


def prepare(client_id, client_secret, existing_key=None):
    for value in (client_id, client_secret):
        if not value or any(character.isspace() or ord(character) < 32 or character in "\"'#\\" for character in value):
            raise ValueError('Credencial vacía o con caracteres no admitidos.')
    encryption_key = existing_key or base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip('=')
    raw = base64.urlsafe_b64decode(encryption_key + '=')
    if len(raw) != 32 or base64.urlsafe_b64encode(raw).decode().rstrip('=') != encryption_key:
        raise ValueError('La clave de cifrado existente no es válida; no se reemplaza automáticamente.')
    return {'GARMIN_ENVIRONMENT': 'DEVELOPMENT', 'GARMIN_CLIENT_ID': client_id,
            'GARMIN_CLIENT_SECRET': client_secret, 'GARMIN_TOKEN_ENCRYPTION_KEY': encryption_key}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--first-setup', action='store_true', help='Crear clave solo en primera instalación, antes de guardar tokens.')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    target = root / '.dart_tool/garmin-dev/secrets.env'
    if target.is_symlink():
        raise ValueError('No se sobrescribe un enlace de secretos.')
    target = target.resolve()
    if not target.is_relative_to(root / '.dart_tool'):
        raise ValueError('La ruta de secretos debe permanecer en .dart_tool del proyecto.')
    existing_key = None
    if target.exists():
        existing = dict(line.split('=', 1) for line in target.read_text(encoding='utf-8').splitlines() if '=' in line)
        existing_key = existing.get('GARMIN_TOKEN_ENCRYPTION_KEY')
        if not existing_key:
            raise ValueError('El archivo previo no contiene clave de cifrado; revisar antes de continuar.')
    elif not args.first_setup:
        raise ValueError('Falta la clave local previa. Recuperarla antes de actualizar; --first-setup solo sirve para el alta inicial sin tokens existentes.')
    print('Preparación local de Garmin para EntrenaOP Dev. No se publicará ni enviará nada.')
    client_id = input('Client ID de EntrenaOP Dev: ').strip()
    client_secret = getpass.getpass('Client Secret (oculto): ').strip()
    values = prepare(client_id, client_secret, existing_key)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(''.join(f'{key}={value}\n' for key, value in values.items()), encoding='utf-8')
    target.chmod(0o600)
    print(f'Secretos preparados en {target}. No compartir este archivo ni capturas de sus valores.')
    print('Con autorización para configurar Dev, aplicar con:')
    print('supabase secrets set --env-file .dart_tool/garmin-dev/secrets.env --project-ref sxbxfjqgoddzhtcyhalw')


if __name__ == '__main__':
    main()
