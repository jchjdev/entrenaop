"""Exporta capturas reales del bloque Evolución y huellas de sus fuentes."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'build/visual-atlas-20261007/raw'
OUT = ROOT / 'docs/visual-audit/refresh-evolution-2026-10-07'
VARIANTS = {
    'Evolución 390.0': ('evolucion-movil', [1, 2, 3, 4, 5]),
    'Evolución 1280.0': ('evolucion-escritorio', [1, 2, 3, 4, 5]),
    'Marcas troop': ('marcas-tropa', [1, 2]),
    'Marcas fas': ('marcas-fas', [1, 2]),
    'Marcas generic': ('marcas-programa', [1, 2]),
    'Marcas empty': ('marcas-vacio', [1]),
    'Marcas error': ('marcas-error', [2]),
    'FAS personal false': ('fas-personal', [1, 2]),
    'FAS personal true': ('fas-personal-error', [1, 2]),
}
SOURCES = [
    'lib/core/router/app_router.dart',
    'lib/core/navigation/app_shell.dart',
    'lib/features/workouts/presentation/pages/workout_history_page.dart',
    'lib/features/workouts/presentation/widgets/workout_history_filters.dart',
    'lib/features/workouts/presentation/bloc/workout_history_cubit.dart',
    'lib/features/workouts/data/datasources/workout_remote_datasource_impl.dart',
    'lib/features/physical_assessment/presentation/pages/preparation_marks_page.dart',
    'lib/features/physical_assessment/presentation/pages/physical_assessment_history_page.dart',
    'lib/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart',
    'test/helpers/evolution_fixtures.dart',
    'tools/visual_refresh_evolution_capture.dart',
]

def export():
    candidates = {}
    for path in RAW.glob('tools_visual_refresh_evolution_capture_dart_*.json'):
        data = json.loads(path.read_text(encoding='utf-8'))
        title, sequence = data['description'], data['sequence']
        if title not in VARIANTS or sequence not in VARIANTS[title][1]:
            continue
        key = (title, sequence)
        if key not in candidates or path.stat().st_mtime > candidates[key][0].stat().st_mtime:
            candidates[key] = (path, data)
    expected = {(title, seq) for title, (_, seqs) in VARIANTS.items() for seq in seqs}
    if candidates.keys() != expected:
        raise RuntimeError('Faltan capturas: ejecutar flutter test tools/visual_refresh_evolution_capture.dart')
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for (title, sequence), (path, data) in sorted(candidates.items()):
        name = f'{VARIANTS[title][0]}-{sequence}.webp'
        image = Image.open(path.with_suffix('.png'))
        if image.size != (data['width'], data['height']):
            raise RuntimeError('Dimensiones incoherentes')
        image.save(OUT / name, format='WEBP', lossless=True, method=6)
        records.append({**{key: value for key, value in data.items() if key != 'commit'},
            'base_commit': data['commit'], 'image': name,
            'sha256': hashlib.sha256((OUT / name).read_bytes()).hexdigest()})
    manifest = {'date': '2026-10-07',
        'git_context': 'base_commit es el punto anterior a UI-011. Las huellas identifican el código local del bloque capturado antes de su commit.',
        'provenance': 'Widgets actuales con datos ficticios; fuentes legibles del runner. No acredita sesión autenticada ni dispositivo real.',
        'source_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES},
        'captures': records}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(records)} capturas exportadas con manifiesto de fuentes.')

if __name__ == '__main__':
    export()
