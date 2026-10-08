"""Exporta las capturas reales de UI-021 sin modificar evidencia histórica."""

import hashlib
import json
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / "build/performance_v2_review"
destination = root / "docs/visual-audit/plan-coherence-2026-10-08"
destination.mkdir(parents=True, exist_ok=True)

captures = []
for name in (
    "referencia-separada-320.0",
    "referencia-con-teclado",
    "mi-plan-eleccion-sin-programa",
    "mi-plan-contexto-guardado",
):
    with Image.open(source / f"{name}.png") as capture:
        output = destination / f"{name}.webp"
        capture.save(output, format="WEBP", lossless=True)
        captures.append({
            "file": output.name,
            "dimensions": list(capture.size),
            "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        })

paths = (
    "lib/features/preparation_goal/presentation/widgets/performance_reference_dialog.dart",
    "lib/features/preparation_goal/presentation/widgets/preparation_select_field.dart",
    "lib/features/preparation_goal/presentation/pages/running_context_form_page.dart",
    "lib/features/preparation_goal/presentation/pages/preparation_training_page.dart",
    "lib/features/training_plan/presentation/pages/training_hub_page.dart",
    "test/features/preparation_goal/presentation/preparation_layout_regression_test.dart",
    "test/features/training_plan/presentation/training_hub_page_test.dart",
)
manifest = {
    "date": "2026-10-08",
    "decision": "UI-021",
    "method": "Widgets actuales con fixtures y Arial, pixelRatio 2; sin cuenta ni servidor. Teclado simulado mediante viewInsets. Los fixtures de Mi plan no aportan portada.",
    "captures": captures,
    "source_sha256": {
        path: hashlib.sha256((root / path).read_bytes()).hexdigest()
        for path in paths
    },
}
(destination / "manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(f"{len(captures)} capturas exportadas con manifiesto.")
