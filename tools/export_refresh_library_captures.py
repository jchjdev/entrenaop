"""Exporta widgets reales de Biblioteca y huellas de las fuentes capturadas."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'build/visual-atlas-20261007/raw'
OUT = ROOT / 'docs/visual-audit/refresh-library-2026-10-08'
VARIANTS = {
    'Biblioteca ejercicios false 390.0': ('catalogo-movil', [1, 2]),
    'Biblioteca ejercicios true 390.0': ('personales-movil', [1, 2]),
    'Biblioteca ejercicios false 1100.0': ('catalogo-escritorio', [1, 2]),
    'Editor personal 390.0 1.0': ('editor-movil', [1, 2, 3]),
    'Editor personal 320.0 2.0': ('editor-texto-ampliado', [1, 2, 3]),
}
SOURCES = [
    'lib/core/router/app_router.dart',
    'lib/features/exercises/presentation/pages/exercise_library_page.dart',
    'lib/features/exercises/presentation/pages/personal_exercise_creator_page.dart',
    'lib/features/exercises/presentation/pages/personal_exercise_editor_page.dart',
    'lib/features/exercises/presentation/widgets/exercise_reference_video.dart',
    'lib/features/exercises/data/datasources/exercise_remote_datasource_impl.dart',
    'lib/features/preparation_goal/presentation/widgets/preparation_cover_provider.dart',
    'tools/visual_refresh_library_capture.dart',
    'tools/cover_navigation_probe.dart',
]

def export():
    candidates = {}
    for path in RAW.glob('tools_visual_refresh_library_capture_dart_*.json'):
        data = json.loads(path.read_text(encoding='utf-8'))
        title, seq = data['description'], data['sequence']
        if title not in VARIANTS or seq not in VARIANTS[title][1]:
            continue
        key = (title, seq)
        if key not in candidates or path.stat().st_mtime > candidates[key][0].stat().st_mtime:
            candidates[key] = (path, data)
    expected = {(title, seq) for title, (_, seqs) in VARIANTS.items() for seq in seqs}
    if candidates.keys() != expected:
        raise RuntimeError('Faltan capturas: ejecutar flutter test tools/visual_refresh_library_capture.dart')
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for (title, seq), (path, data) in sorted(candidates.items()):
        name = f'{VARIANTS[title][0]}-{seq}.webp'
        pixels = Image.open(path.with_suffix('.png'))
        assert pixels.size == (data['width'], data['height'])
        pixels.save(OUT / name, format='WEBP', lossless=True, method=6)
        records.append({**{k: v for k, v in data.items() if k != 'commit'},
            'base_commit': data['commit'], 'image': name,
            'sha256': hashlib.sha256((OUT / name).read_bytes()).hexdigest()})
    manifest = {
        'date': '2026-10-08',
        'provenance': 'Widgets actuales con datos ficticios; no acredita una cuenta autenticada ni un dispositivo real.',
        'git_context': 'base_commit es el punto anterior al bloque. Las huellas identifican el código capturado antes del commit.',
        'source_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES},
        'captures': records,
        'browser_probe': {
            'source': 'tools/cover_navigation_probe.dart',
            'browser': 'Chromium · navegador integrado de Codex',
            'fixture': 'PNG de color generado localmente; sin autenticación ni red de imágenes',
            'completed_returns': 5,
            'observed': 'Ambos proveedores muestran el PNG inicialmente; tras cinco retornos el anterior pierde la imagen y el corregido la conserva.',
            'images': [{
                'image': name,
                'sha256': hashlib.sha256((OUT / name).read_bytes()).hexdigest(),
                'size': Image.open(OUT / name).size,
            } for name in ['portadas-antes.jpg', 'portadas-despues.jpg']],
        },
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(records)} capturas exportadas.')

if __name__ == '__main__':
    export()
