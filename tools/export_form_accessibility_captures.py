"""Exporta formularios actuales con texto normal y ampliado."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'admin_app/build/visual-atlas-20261007/raw'
OUT = ROOT / 'docs/visual-audit/form-accessibility-2026-10-08'
SOURCE = 'admin_app/tools/visual_form_accessibility_capture.dart'
VARIANTS = {'390.0 1.0': 'movil', '320.0 2.0': 'texto-ampliado', '1100.0 1.0': 'escritorio'}
STATES = {'programa': {2: 'tipo', 3: 'error'}, 'ejercicio': {2: 'selectores', 3: 'foto'}}
SOURCES = [
    'admin_app/lib/features/programs/presentation/admin_programs_page.dart',
    'admin_app/lib/features/exercises/presentation/admin_exercises_page.dart',
    'packages/workout_editor_ui/lib/exercise_form.dart',
    'packages/entrena_ui/lib/src/retained_save_dialog.dart',
    'admin_app/test/helpers/admin_test_app.dart',
    'tools/visual_atlas_capture.dart', SOURCE,
    'tools/export_form_accessibility_captures.py',
]


def export():
    captures = {}
    for path in RAW.glob('admin_app_tools_visual_form_accessibility_capture_dart_*.json'):
        data = json.loads(path.read_text(encoding='utf-8'))
        parts = data['description'].split(' ', 2)
        if len(parts) != 3 or parts[1] not in STATES or parts[2] not in VARIANTS:
            continue
        form, variant, seq = parts[1], parts[2], data['sequence']
        if seq not in STATES[form]:
            continue
        key = (form, variant, seq)
        if key not in captures or path.stat().st_mtime > captures[key][0].stat().st_mtime:
            captures[key] = (path, data)
    expected = {(f, v, s) for f in STATES for v in VARIANTS for s in STATES[f]}
    if captures.keys() != expected:
        raise RuntimeError(f'Capturas incompletas: {expected - captures.keys()}')
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for (form, variant, seq), (path, data) in sorted(captures.items()):
        name = f'{VARIANTS[variant]}-{form}-{STATES[form][seq]}.webp'
        pixels = Image.open(path.with_suffix('.png'))
        assert pixels.size == (data['width'], data['height']), name
        pixels.save(OUT / name, format='WEBP', lossless=True, method=6)
        records.append({**data, 'image': name,
            'sha256': hashlib.sha256((OUT / name).read_bytes()).hexdigest()})
    fonts = [Path('C:/Windows/Fonts/arial.ttf'), Path('E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')]
    manifest = {
        'date': '2026-10-08',
        'provenance': 'Widgets actuales, router y tema compartidos, datos ficticios. Sin autenticación, Supabase, imágenes subidas o dispositivo físico. captures.commit identifica la base anterior al guardado de UI-017; sources identifica el código local capturado.',
        'sources': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES},
        'fonts': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in fonts},
        'captures': records,
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Exportadas {len(records)} capturas de formularios.')


if __name__ == '__main__':
    export()
