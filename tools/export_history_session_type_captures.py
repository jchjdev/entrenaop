"""Exporta el filtro actual y conserva la procedencia de las imágenes."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'build/visual-atlas-20261007/raw'
OUT = ROOT / 'docs/visual-audit/history-session-type-2026-10-08'
SOURCE = 'tools/visual_history_session_type_capture.dart'
VARIANTS = {
    'Tipo histórico 390.0 1.0': 'movil',
    'Tipo histórico 320.0 2.0': 'texto-ampliado',
    'Tipo histórico 1100.0 1.0': 'escritorio',
}
STATES = {1: 'inicio', 2: 'filtros', 3: 'fuerza', 4: 'sin-clasificar', 5: 'error-conservado'}
SOURCES = [
    'lib/features/workouts/domain/entities/workout_session_type.dart',
    'lib/features/workouts/domain/entities/workout_execution.dart',
    'lib/features/workouts/domain/entities/workout_history_query.dart',
    'lib/features/workouts/presentation/bloc/workout_history_cubit.dart',
    'lib/features/workouts/presentation/widgets/workout_history_filters.dart',
    'lib/features/workouts/presentation/pages/workout_history_page.dart',
    'lib/core/theme/entrena_theme.dart',
    'test/helpers/evolution_fixtures.dart',
    'tools/visual_atlas_capture.dart', SOURCE,
    'tools/export_history_session_type_captures.py',
]


def export():
    captures = {}
    for path in RAW.glob('tools_visual_history_session_type_capture_dart_*.json'):
        data = json.loads(path.read_text(encoding='utf-8'))
        title, seq = data['description'], data['sequence']
        if title not in VARIANTS or seq not in STATES:
            continue
        key = (title, seq)
        if key not in captures or path.stat().st_mtime > captures[key][0].stat().st_mtime:
            captures[key] = (path, data)
    expected = {(title, seq) for title in VARIANTS for seq in STATES}
    if captures.keys() != expected:
        raise RuntimeError(f'Capturas incompletas: {expected - captures.keys()}')
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for (title, seq), (path, data) in sorted(captures.items()):
        name = f'{VARIANTS[title]}-{STATES[seq]}.webp'
        pixels = Image.open(path.with_suffix('.png'))
        if pixels.size != (data['width'], data['height']):
            raise RuntimeError(f'Dimensiones incoherentes: {name}')
        pixels.save(OUT / name, format='WEBP', lossless=True, method=6)
        records.append({**data, 'image': name,
            'sha256': hashlib.sha256((OUT / name).read_bytes()).hexdigest()})
    fonts = [Path('C:/Windows/Fonts/arial.ttf'),
        Path('E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')]
    manifest = {
        'date': '2026-10-08',
        'git_context': 'La base de captures.commit precede al guardado de UI-016. Las huellas corresponden al código local capturado.',
        'provenance': 'Widgets actuales, tema real y datos ficticios. Sin autenticación, Supabase ni dispositivo físico; las preparaciones de ejemplo no tienen portada.',
        'sources': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES},
        'fonts': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in fonts},
        'captures': records,
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Exportadas {len(records)} imágenes del filtro de entrenamiento.')


if __name__ == '__main__':
    export()
