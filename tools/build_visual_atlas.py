"""Selecciona capturas reales y genera evidencia y atlas desde una plantilla.

No dibuja ni reconstruye la interfaz de producto: todas las imágenes son renders
Flutter. El catálogo explica funcionalidades; la cobertura se coteja con clases.
"""
from pathlib import Path
import base64
import json
import re
import argparse
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'visual-audit' / '2026-10-07'
CATALOG = ROOT / 'tools' / 'visual_atlas_catalog.json'


def load_raw():
    records = []
    for project in (ROOT, ROOT / 'admin_app'):
        for path in (project / 'build/visual-atlas-20261007/raw').glob('*.json'):
            data = json.loads(path.read_text(encoding='utf-8'))
            if data.get('commit') != 'cf7025f':
                continue
            data['_path'] = path
            records.append(data)
    return records


def rank(data, name):
    modal = name.endswith('Dialog') or name == 'ProgramCoverEditor'
    blockers = [n for n in data['widgets'] if n.endswith('Dialog') or n == 'ProgramCoverEditor']
    score = min(len(data['texts']), 50) * 0.5
    score += 35 if data['stage'] == 'estable' else 0
    score += 30 if 320 <= data['width'] <= 430 and not name.startswith('Admin') else 0
    score -= 80 if blockers and not modal else 0
    score -= 10 * data['sequence']
    if any(w in data['description'].lower() for w in ('error', 'falla', 'texto grande', '2x', 'rechaz')):
        score -= 35
    if len(data['texts']) < 3:
        score -= 100
    if name == 'TrainingContextPage' and data['width'] == 320:
        score -= 50  # El fixture de 320 px comprueba texto 2×.
    if name == 'ProgramCoverEditor' and 'fotografía real' in data['description']:
        score += 180 if data['stage'] == 'final' else (60 if data['sequence'] > 2 else -50)
    if name == 'PreparationTrainingPage' and 'un programa activo no devuelve' in data['description']:
        score += 80
    return score


def main(destination):
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    raw = load_raw()
    images = OUT / 'images'
    images.mkdir(parents=True, exist_ok=True)
    declarations = {}
    for parent in (ROOT / 'lib', ROOT / 'admin_app/lib'):
        for path in parent.rglob('*.dart'):
            code = path.read_text(encoding='utf-8-sig')
            for name in re.findall(r'class ([A-Z]\w*(?:Page|Lab|Dialog)) extends (?:StatefulWidget|StatelessWidget)', code):
                declarations[name] = path.relative_to(ROOT).as_posix()
            for component in ('ProgramCoverEditor', 'ProgramPhaseSection', 'RunningWeekPreviewSection'):
                if f'class {component} ' in code:
                    declarations[component] = path.relative_to(ROOT).as_posix()
    public_views = len(declarations)
    for screen in catalog['screens']:
        if not screen['class'].startswith('_'):
            continue
        for parent in (ROOT / 'lib', ROOT / 'admin_app/lib'):
            for path in parent.rglob('*.dart'):
                if re.search(r'class ' + re.escape(screen['class']) + r'\b', path.read_text(encoding='utf-8-sig')):
                    declarations[screen['class']] = path.relative_to(ROOT).as_posix()
    missing_catalog = set(declarations) - {s['class'] for s in catalog['screens']}
    if missing_catalog:
        raise ValueError(f'Clases no inventariadas: {sorted(missing_catalog)}')
    contact = []
    for screen in catalog['screens']:
        name = screen['class']
        screen['mode'] = screen.get('mode') or ('admin' if name.startswith('Admin') or name == 'ProgramCoverEditor' else 'app')
        screen['source'] = declarations.get(name)
        screen.setdefault('status', 'Implementada')
        candidates = sorted((d for d in raw if name in d['widgets']), key=lambda d: rank(d, name), reverse=True)
        if not candidates:
            raise ValueError(f'Sin render de {name}')
        selected = [candidates[0]]
        for candidate in candidates[1:]:
            a, b = set(candidate['texts']), set(selected[-1]['texts'])
            if len(a & b) / max(1, len(a | b)) < 0.65 and len(a) > 2:
                selected.append(candidate)
            if len(selected) == 3:
                break
        screen['captures'] = []
        for i, capture in enumerate(selected):
            png = capture['_path'].with_suffix('.png')
            image = Image.open(png).convert('RGB')
            # Compresión de píxeles ya renderizados, sin alterar elementos UI.
            image.thumbnail((950, 1400))
            target = images / f'{name}-{i + 1}.webp'
            image.save(target, 'WEBP', quality=80, method=6)
            entry = {k: v for k, v in capture.items() if k != '_path'}
            entry['file'] = target.relative_to(OUT).as_posix()
            entry['raw'] = png.relative_to(ROOT).as_posix()
            entry['label'] = capture['description'] + f" · vista {capture['sequence'] + 1}"
            screen['captures'].append(entry)
        contact.append((screen, images / f'{name}-1.webp'))
    catalog['coverage'] = {'publicViews': public_views - 2, 'programSections': 2, 'namedPrivateDialogs': len(declarations) - public_views, 'inventoriedViews': len(catalog['screens']), 'rawFrames': len(raw)}
    (OUT / 'manifest.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding='utf-8')
    make_report(catalog)
    make_contact(contact)
    template = (ROOT / 'tools/visual_atlas_template.html').read_text(encoding='utf-8')
    destination.mkdir(parents=True, exist_ok=True)
    for mode in ('app', 'admin'):
        screens = [s for s in catalog['screens'] if s['mode'] == mode]
        payload = {'screens': [], 'flows': [f for f in catalog['flows'] if f['mode'] == mode]}
        for screen in screens:
            view = {k: screen[k] for k in ('class', 'title', 'group', 'route', 'does', 'gap', 'status')}
            view['captures'] = []
            for capture in screen['captures']:
                image = Image.open(OUT / capture['file'])
                image.thumbnail((760 if mode == 'admin' else 420, 1100))
                from io import BytesIO
                buffer = BytesIO()
                image.save(buffer, 'WEBP', quality=65, method=6)
                view['captures'].append({'label': capture['label'], 'width': capture['width'], 'height': capture['height'], 'src': 'data:image/webp;base64,' + base64.b64encode(buffer.getvalue()).decode()})
            payload['screens'].append(view)
        # Mantener cada fragmento por debajo de 1 MB. Las tres vistas completas
        # permanecen en el manifiesto versionado aunque se limite el inline.
        while len(json.dumps(payload)) > 930000 and any(len(s['captures']) > 1 for s in payload['screens']):
            largest = max((s for s in payload['screens'] if len(s['captures']) > 1), key=lambda s: sum(len(c['src']) for c in s['captures']))
            largest['captures'].pop()
        data = json.dumps(payload, ensure_ascii=False).replace('</', '<\\/')
        fragment = template.replace('@@ROOT@@', 'atlas-' + mode).replace('@@DATA@@', data).replace('@@TITLE@@', 'App del deportista' if mode == 'app' else 'Administración')
        target = destination / f'entrenaop-{mode}.html'
        target.write_text(fragment, encoding='utf-8')
        if target.stat().st_size >= 1000000:
            raise ValueError(f'Fragmento demasiado grande: {target}')
        print(f'{mode}: {len(screens)} vistas; {sum(len(s["captures"]) for s in payload["screens"])} capturas inline; {target.stat().st_size} bytes')
    print(json.dumps(catalog['coverage']))


def make_contact(items):
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 15)
    for mode in ('app', 'admin'):
        subset = [(s, p) for s, p in items if s['mode'] == mode]
        sheet = Image.new('RGB', (1000, ((len(subset) + 4) // 5) * 290), '#eeeeee')
        draw = ImageDraw.Draw(sheet)
        for i, (screen, path) in enumerate(subset):
            im = Image.open(path).convert('RGB')
            im.thumbnail((190, 250))
            x, y = (i % 5) * 200, (i // 5) * 290
            sheet.paste(im, (x + (200 - im.width) // 2, y + 30))
            draw.text((x + 4, y + 4), screen['title'][:25], fill='#111111', font=font)
        sheet.save(OUT / f'contact-{mode}.jpg', quality=90)


def make_report(catalog):
    report = ROOT / 'docs/SCREEN_MAP_2026_10_07.md'
    marker = '<!-- INVENTARIO GENERADO: tools/build_visual_atlas.py -->'
    if not report.exists():
        return
    prefix = report.read_text(encoding='utf-8').split(marker)[0].rstrip()
    rows = [prefix, '', marker, '', '## Inventario de pantallas y diálogos', '',
            'Cada imagen procede del widget real. Las vistas adicionales se conservan como enlaces; '
            'el atlas permite seleccionar estados sin desplegar este documento entero.', '']
    for mode, title in [('app', 'Aplicación del deportista'), ('admin', 'Administración')]:
        rows += ['### ' + title, '']
        for screen in [s for s in catalog['screens'] if s['mode'] == mode]:
            rows += ['#### ' + screen['title'], '', f'**{screen["status"]}** · {screen["group"]} · `{screen["class"]}`', '',
                     'Entrada: `' + screen['route'] + '`.', '', '**Actual:** ' + screen['does'], '',
                     '**Pendiente / propuesta:** ' + screen['gap'], '']
            if screen.get('source'):
                rows += [f'Código: [{screen["source"]}](../{screen["source"]}).', '']
            capture = screen['captures'][0]
            rows += [f'![{screen["title"]}](visual-audit/2026-10-07/{capture["file"]})', '',
                     f'Fixture: {capture["description"]}; vista {capture["sequence"] + 1}; {capture["width"]} × {capture["height"]}.', '']
            for state in screen['captures'][1:]:
                rows += [f'- [Estado: {state["label"]}](visual-audit/2026-10-07/{state["file"]})']
            rows.append('')
    report.write_text('\n'.join(rows).rstrip() + '\n', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    main(parser.parse_args().destination)
