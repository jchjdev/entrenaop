"""Exporta el recorrido de Cuenta desde capturas de widgets actuales."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'build/visual-atlas-20261007/raw'
OUT = ROOT / 'docs/visual-audit/refresh-account-2026-10-08'
SOURCES = [
    'lib/core/router/app_router.dart',
    'lib/features/auth/presentation/pages/account_email_page.dart',
    'lib/features/auth/presentation/pages/reset_password_page.dart',
    'lib/features/auth/presentation/pages/login_page.dart',
    'lib/features/auth/presentation/pages/sign_up_page.dart',
    'lib/features/auth/presentation/bloc/auth_cubit.dart',
    'tools/visual_refresh_account_capture.dart',
]
NAMES = {1: 'solicitar', 2: 'correo-enviado', 3: 'confirmar-cuenta',
         4: 'nueva-contrasena', 5: 'error-con-borrador',
         6: 'contrasena-actualizada', 7: 'enlace-invalido'}

def export():
    candidates = {}
    for path in RAW.glob('tools_visual_refresh_account_capture_dart_*.json'):
        data = json.loads(path.read_text(encoding='utf-8'))
        seq = data['sequence']
        if seq not in NAMES:
            continue
        key = (data['description'], seq)
        if key not in candidates or path.stat().st_mtime > candidates[key][0].stat().st_mtime:
            candidates[key] = (path, data)
    expected = {(f'Cuenta {w} {s}', seq) for w, s in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)] for seq in NAMES}
    if candidates.keys() != expected:
        raise RuntimeError(f'Capturas incompletas: {expected - candidates.keys()}')
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for (title, seq), (path, data) in sorted(candidates.items()):
        variant = 'texto-ampliado' if '320.0' in title else 'escritorio' if '1100.0' in title else 'movil'
        name = f'{variant}-{NAMES[seq]}.webp'
        pixels = Image.open(path.with_suffix('.png'))
        pixels.save(OUT / name, format='WEBP', lossless=True, method=6)
        records.append({**data, 'image': name, 'sha256': hashlib.sha256((OUT / name).read_bytes()).hexdigest()})
    (OUT / 'manifest.json').write_text(json.dumps({
        'date': '2026-10-08',
        'provenance': 'Widgets actuales, datos y contraseñas ficticios; sin correos reales ni Supabase remoto.',
        'sources': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES},
        'captures': records,
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Exportadas {len(records)} capturas de Cuenta.')

if __name__ == '__main__':
    export()
