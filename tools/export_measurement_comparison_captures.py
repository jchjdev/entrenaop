"""Exporta imágenes del comparador actual con procedencia y huellas verificables."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'build/visual-atlas-20261007/raw'
OUT = ROOT / 'docs/visual-audit/measurement-comparison-2026-10-08'
SOURCE = 'tools/visual_measurement_comparison_capture.dart'
VARIANTS = {
    'Comparación Tropa 390.0 1.0': ('movil-tropa', 4),
    'Comparación Tropa 320.0 2.0': ('texto-ampliado-tropa', 4),
    'Comparación Tropa 1100.0 1.0': ('escritorio-tropa', 4),
    'Comparación FAS': ('movil-fas', 3),
    'Comparación versiones distintas': ('versiones-distintas', 2),
    'Comparación programa sin contrato': ('programa-snapshot', 2),
}
SOURCES = [
    'lib/features/physical_assessment/domain/entities/measurement_history.dart',
    'lib/features/physical_assessment/domain/services/assessment_progress_calculator.dart',
    'lib/features/physical_assessment/presentation/utils/preparation_measurement_history.dart',
    'lib/features/physical_assessment/presentation/utils/assessment_formatters.dart',
    'lib/features/physical_assessment/presentation/widgets/measurement_comparison_card.dart',
    'lib/features/physical_assessment/presentation/pages/preparation_marks_page.dart',
    'lib/features/physical_assessment/presentation/pages/physical_assessment_history_page.dart',
    'lib/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart',
    'test/helpers/evolution_fixtures.dart',
    'test/helpers/measurement_comparison_fixtures.dart',
    'test/features/physical_assessment/presentation/measurement_comparison_card_test.dart',
    'tools/visual_atlas_capture.dart', SOURCE,
    'tools/export_measurement_comparison_captures.py',
]


def export():
    candidates = {}
    for path in RAW.glob('tools_visual_measurement_comparison_capture_dart_*.json'):
        data = json.loads(path.read_text(encoding='utf-8'))
        title, sequence = data['description'], data['sequence']
        if title not in VARIANTS or sequence not in range(1, VARIANTS[title][1] + 1):
            continue
        key = (title, sequence)
        if key not in candidates or path.stat().st_mtime > candidates[key][0].stat().st_mtime:
            candidates[key] = (path, data)
    expected = {(title, seq) for title, (_, count) in VARIANTS.items() for seq in range(1, count + 1)}
    if candidates.keys() != expected:
        raise RuntimeError(f'Capturas incompletas: {expected - candidates.keys()}')
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for (title, sequence), (path, data) in sorted(candidates.items()):
        name = f'{VARIANTS[title][0]}-{sequence}.webp'
        pixels = Image.open(path.with_suffix('.png'))
        if pixels.size != (data['width'], data['height']):
            raise RuntimeError(f'Dimensiones incoherentes: {name}')
        pixels.save(OUT / name, format='WEBP', lossless=True, method=6)
        records.append({**data, 'image': name, 'sha256': hashlib.sha256((OUT / name).read_bytes()).hexdigest()})
    fonts = [Path('C:/Windows/Fonts/arial.ttf'), Path('E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')]
    manifest = {
        'date': '2026-10-08',
        'git_context': 'captures.commit identifica la base anterior a UI-015. Las huellas de sources corresponden al código local capturado antes de guardar este bloque.',
        'provenance': 'Widgets actuales, tema compartido y datos ficticios. Las preparaciones del fixture no tienen portada. Sin autenticación ni Supabase remoto; no acredita dispositivo ni fotografías remotas.',
        'sources': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES},
        'fonts': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in fonts},
        'captures': records,
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Exportadas {len(records)} capturas del comparador.')


if __name__ == '__main__':
    export()
