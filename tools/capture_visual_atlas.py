"""Prepara copias instrumentadas de tests de widgets, sin editar código/test originales.

Las imágenes renderizan widgets reales con el tema de la aplicación y fixtures
existentes. El resultado es evidencia visual local, no un recorrido autenticado.
"""
from pathlib import Path
import argparse
import re

ROOT = Path(__file__).resolve().parents[1]


def matching(text, start):
    depth = 0
    quote = None
    escaped = False
    for i in range(start, len(text)):
        c = text[i]
        if quote:
            if escaped:
                escaped = False
            elif c == '\\':
                escaped = True
            elif c == quote:
                quote = None
            continue
        if c in "\"'":
            quote = c
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if not depth:
                return i
    raise ValueError('Constructor sin cierre')


def production_theme(text):
    # MaterialApp de los fixtures utiliza siempre el tema actual, no Ahem/tema azul.
    positions = list(re.finditer(r'\b(?:MaterialApp(?:\.router)?|AdminTestApp)\(', text))
    for m in reversed(positions):
        start = m.end()
        end = matching(text, start - 1)
        args = text[start:end]
        theme = re.search(r'\btheme\s*:\s*', args)
        if theme:
            p = theme.end()
            depth = 0
            for j in range(p, len(args)):
                if args[j] in '([{': depth += 1
                if args[j] in ')]}': depth -= 1
                if args[j] == ',' and depth == 0:
                    break
            else:
                j = len(args)
            args = args[:p] + 'EntrenaTheme.dark' + args[j:]
        else:
            args = '\n theme: EntrenaTheme.dark, ' + args
        if m.group(0).startswith('MaterialApp') and 'debugShowCheckedModeBanner:' not in args:
            args = 'debugShowCheckedModeBanner: false, ' + args
        text = text[:start] + args + text[end:]
    return text


def prepare(mode):
    project = ROOT if mode == 'app' else ROOT / 'admin_app'
    out = project / 'build' / 'visual-atlas-20261007'
    copies = out / 'tests'
    copies.mkdir(parents=True, exist_ok=True)
    helper = (ROOT / 'tools' / 'visual_atlas_capture.dart').as_uri()
    files = []
    for source in sorted((project / 'test').rglob('*_test.dart')):
        text = source.read_text(encoding='utf-8-sig')
        if 'testWidgets(' not in text:
            continue
        text = re.sub(r"(import|export)\s+(['\"])([^'\"]+)\2", lambda m:
            m.group(0) if ':' in m.group(3) else
            f"{m.group(1)} '{(source.parent / m.group(3)).resolve().as_uri()}'", text)
        if 'entrena_theme.dart' not in text and 'package:entrena_ui/entrena_ui.dart' not in text:
            text = "import 'package:entrena_ui/entrena_ui.dart';\n" + text
        text = f"import '{helper}';\n" + text
        # Solo estos contenedores dejan de ser const al recibir el tema actual.
        text = re.sub(r'\bconst\s+(?=(?:MaterialApp|AdminTestApp)\b)', '', text)
        text = production_theme(text)
        # El tema real construye etiquetas distintas al tema mínimo del fixture.
        # Estas adaptaciones afectan solo a localizadores en las copias.
        if source.name == 'running_context_form_page_test.dart':
            text = text.replace("find.ancestor(of: find.text('60 min'), matching: find.byType(ChoiceChip)),",
                                "find.ancestor(of: find.text('60 min'), matching: find.byType(ChoiceChip)).first,")
        if source.name == 'admin_programs_page_test.dart':
            text = text.replace("await tester.ensureVisible(find.text('Prueba cronometrada de 2.000 m'));",
                                "await tester.scrollUntilVisible(find.text('Prueba cronometrada de 2.000 m'), 100, scrollable: find.byType(Scrollable).first);")
        text = text.replace('testWidgets(', 'atlasTestWidgets(')
        text = re.sub(r'\b(tester|t)\.pumpWidget\(', r'atlasPumpWidget(\1, ', text)
        text = re.sub(r'\b(tester|t)\.pumpAndSettle\(', r'atlasSettle(\1, ', text)
        rel = source.relative_to(ROOT).as_posix()
        text = re.sub(r'((?:void|Future<void>) main\(\)\s*(?:async\s*)?\{)',
                      lambda m: m.group(1) + f"\n atlasSource = '{rel}';\n", text, count=1)
        target = copies / source.relative_to(project / 'test')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding='utf-8')
        files.append(str(target.relative_to(project)))
    (out / 'files.txt').write_text('\n'.join(files), encoding='utf-8')
    print(f'{mode}: {len(files)} archivos preparados en {copies}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['app', 'admin'])
    prepare(parser.parse_args().mode)
