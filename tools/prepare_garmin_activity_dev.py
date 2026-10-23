"""Prepara la capacidad del receptor Garmin Dev, sin imprimirla ni desplegar."""
import re
import secrets
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    target = root / '.dart_tool/garmin-dev/activity.env'
    if target.is_symlink():
        raise ValueError('No se reemplaza un enlace de secretos.')
    if target.exists():
        content = target.read_text(encoding='utf-8').strip()
        if not re.fullmatch(r'GARMIN_ACTIVITY_WEBHOOK_SECRET=[A-Za-z0-9_-]{43}', content):
            raise ValueError('Secreto previo inesperado; no se rota automáticamente.')
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('GARMIN_ACTIVITY_WEBHOOK_SECRET=' + secrets.token_urlsafe(32) + '\n', encoding='utf-8')
        target.chmod(0o600)
    print('Capacidad Dev preparada; conservar el archivo privado .dart_tool/garmin-dev/activity.env.')
    print('El secreto solo se aplica a Supabase Dev y a la URL del receptor Activity Files de Garmin.')


if __name__ == '__main__':
    main()
