"""Exporta las secciones del admin desde widgets reales y datos ficticios."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'admin_app/build/visual-atlas-20261007/raw'
OUT = ROOT / 'docs/visual-audit/refresh-admin-2026-10-08'
SOURCE = 'admin_app/tools/visual_refresh_admin_capture.dart'
NAMES = {1: 'contenido', 2: 'evaluacion', 3: 'prueba', 4: 'entrenamiento'}
SOURCES = [
    'admin_app/lib/features/programs/presentation/admin_program_detail_page.dart',
    'admin_app/lib/features/programs/presentation/admin_performance_strategy_section.dart',
    'admin_app/test/helpers/admin_test_app.dart',
    'tools/visual_atlas_capture.dart', SOURCE,
]


def export():
    candidates = {}
    for path in RAW.glob('admin_app_tools_visual_refresh_admin_capture_dart_*.json'):
        data = json.loads(path.read_text(encoding='utf-8'))
        if data['source'] != SOURCE or data['sequence'] not in NAMES:
            continue
        key = (data['description'], data['sequence'])
        if key not in candidates or path.stat().st_mtime > candidates[key][0].stat().st_mtime:
            candidates[key] = (path, data)
    expected = {
        (f'Admin {width} {scale} {published}', seq)
        for width, scale in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]
        for published in ['false', 'true'] for seq in NAMES
    }
    if candidates.keys() != expected:
        raise RuntimeError(f'Capturas incompletas: {expected - candidates.keys()}')
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for (title, seq), (path, data) in sorted(candidates.items()):
        variant = 'texto-ampliado' if '320.0' in title else 'escritorio' if '1100.0' in title else 'movil'
        state = 'publicado' if title.endswith('true') else 'borrador'
        name = f'{variant}-{state}-{NAMES[seq]}.webp'
        pixels = Image.open(path.with_suffix('.png'))
        pixels.save(OUT / name, format='WEBP', lossless=True, method=6)
        records.append({**data, 'image': name,
                        'sha256': hashlib.sha256((OUT / name).read_bytes()).hexdigest()})
    fonts = [Path('C:/Windows/Fonts/arial.ttf'),
             Path('E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')]
    manifest = {
        'date': '2026-10-08',
        'provenance': 'Widgets actuales del admin, tema compartido y datos ficticios; sin autenticación ni Supabase remoto.',
        'sources': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES},
        'fonts': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in fonts},
        'captures': records,
    }
    (OUT / 'manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Exportadas {len(records)} capturas del admin.')


if __name__ == '__main__':
    export()
