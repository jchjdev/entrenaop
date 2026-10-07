"""Exporta capturas del refresh de Inicio/Mi plan y su procedencia comprobable.

Ejecutar desde raíz después de flutter test tools/visual_refresh_plan_capture.dart.
No consulta cuentas ni modifica las capturas históricas del atlas inicial.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "build/visual-atlas-20261007/raw"
OUT = ROOT / "docs/visual-audit/refresh-plan-2026-10-07"
VARIANTS = {
    "Mi plan en curso móvil": "mi-plan-movil",
    "Mi plan en curso escritorio": "mi-plan-escritorio",
    "Mi plan revisión pendiente": "mi-plan-revision",
    "Mi plan pausado": "mi-plan-pausado",
    "Mi plan primer acceso": "mi-plan-primer-acceso",
    "Mi plan error conservado": "mi-plan-error",
    "Inicio sesión actual": "inicio-sesion",
    "Inicio revisión pendiente": "inicio-revision",
}
SOURCES = [
    "lib/features/auth/presentation/pages/home_page.dart",
    "lib/features/training_plan/presentation/pages/training_hub_page.dart",
    "lib/features/dashboard/presentation/widgets/preparation_next_step_card.dart",
    "lib/features/dashboard/presentation/widgets/preparation_status_label.dart",
    "lib/features/dashboard/presentation/widgets/home_section_heading.dart",
    "lib/core/navigation/app_shell.dart",
    "lib/core/router/app_router.dart",
    "tools/visual_refresh_plan_capture.dart",
]


def export():
    candidates = {}
    for path in RAW.glob("tools_visual_refresh_plan_capture_dart_*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        title = data["description"]
        sequence = data["sequence"]
        if title not in VARIANTS or sequence not in ([1, 2, 3] if title.startswith("Mi plan") else [1]):
            continue
        key = (title, sequence)
        previous = candidates.get(key)
        if previous is None or path.stat().st_mtime > previous[0].stat().st_mtime:
            candidates[key] = (path, data)
    expected = {(title, seq) for title in VARIANTS for seq in ([1, 2, 3] if title.startswith("Mi plan") else [1])}
    if candidates.keys() != expected:
        raise RuntimeError("Faltan capturas del refresh; ejecutar primero el renderizado Flutter.")
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for (title, sequence), (path, data) in sorted(candidates.items()):
        name = f"{VARIANTS[title]}-{sequence}.webp"
        image = Image.open(path.with_suffix(".png"))
        if image.size != (data["width"], data["height"]):
            raise RuntimeError("Dimensiones de captura incoherentes")
        image.save(OUT / name, format="WEBP", lossless=True, method=6)
        records.append({**data, "image": name,
            "font_note": "Arial sustituye fuentes de tests; la etiqueta seleccionada del rail normaliza solo su familia a Roboto.",
            "sha256": hashlib.sha256((OUT / name).read_bytes()).hexdigest()})
    manifest = {"date": "2026-10-07", "provenance": "Widgets reales con datos simulados; no es recorrido autenticado ni maqueta generada.",
        "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES},
        "captures": records}
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(records)} capturas exportadas con manifiesto de fuentes.")


if __name__ == "__main__":
    export()
