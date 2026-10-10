"""Comprueba o aplica solo el asunto y HTML de un correo de acceso en Dev."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request
import tomllib

ROOT = Path(__file__).resolve().parent
PROJECT_REF = "sxbxfjqgoddzhtcyhalw"
URL = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/config/auth"
RECOVERY_MARKERS = {
    "mailer_subjects_custom_contents": "MAILER_SUBJECTS_RECOVERY",
    "mailer_templates_custom_contents": "MAILER_TEMPLATES_RECOVERY_CONTENT",
}
CONFIRMATION_MARKERS = {
    "mailer_subjects_custom_contents": "MAILER_SUBJECTS_CONFIRMATION",
    "mailer_templates_custom_contents": "MAILER_TEMPLATES_CONFIRMATION_CONTENT",
}


def unexpected_properties(before, after, expected, markers=RECOVERY_MARKERS):
    unexpected = []
    for key in sorted(set(before) | set(after)):
        if key in expected or before.get(key) == after.get(key):
            continue
        marker = markers.get(key)
        previous, current = before.get(key), after.get(key)
        # La API marca el correo elegido como personalizado automáticamente.
        # Solo se admite ese indicador; los de otros correos deben conservarse.
        if marker and isinstance(previous, dict) and isinstance(current, dict):
            if current.get(marker) is True and {
                k: v for k, v in previous.items() if k != marker
            } == {k: v for k, v in current.items() if k != marker}:
                continue
        unexpected.append(key)
    return unexpected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--template", choices=("recovery", "confirmation"), default="recovery")
    args = parser.parse_args()
    token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not token:
        raise RuntimeError("Falta SUPABASE_ACCESS_TOKEN; nunca pegarlo en el código.")
    config = tomllib.loads((ROOT / "supabase/config.toml").read_text(encoding="utf-8"))
    template = config["auth"]["email"]["template"][args.template]
    markers = RECOVERY_MARKERS if args.template == "recovery" else CONFIRMATION_MARKERS
    html = (ROOT / template["content_path"]).resolve()
    if not html.is_relative_to(ROOT):
        raise RuntimeError("La plantilla debe pertenecer a esta configuración.")
    content = html.read_text(encoding="utf-8")
    if '{{ .ConfirmationURL }}' not in content:
        raise RuntimeError("La plantilla debe conservar el enlace de Supabase.")
    expected = {
        f"mailer_subjects_{args.template}": template["subject"],
        f"mailer_templates_{args.template}_content": content,
    }

    def request(method="GET", data=None):
        req = urllib.request.Request(
            URL,
            method=method,
            data=None if data is None else json.dumps(data).encode("utf-8"),
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)

    before = request()
    matches_before = all(before.get(k) == v for k, v in expected.items())
    after = before
    if args.apply and not matches_before:
        # Solo asunto y HTML: conserva SMTP, permisos y la confirmación obligatoria.
        request("PATCH", expected)
        after = request()
    unexpected = unexpected_properties(before, after, expected, markers)
    matches_after = all(after.get(k) == v for k, v in expected.items())
    # Solo información del trabajo: no imprimir Auth completo ni credenciales.
    print(json.dumps({
        "project_ref": PROJECT_REF,
        "template": args.template,
        "applied": args.apply and not matches_before,
        "subject_matches": after.get(f"mailer_subjects_{args.template}") == template["subject"],
        "content_matches": after.get(f"mailer_templates_{args.template}_content") == content,
        "html_sha256": hashlib.sha256(content.encode("utf-8")).hexdigest(),
        "custom_smtp_configured": bool(after.get("smtp_host")),
        f"{args.template}_custom_markers": {
            key: after.get(key, {}).get(marker) is True
            if isinstance(after.get(key), dict) else False
            for key, marker in markers.items()
        },
        "unexpected_changed_properties": unexpected,
    }, ensure_ascii=False))
    if unexpected or (args.apply and not matches_after):
        raise RuntimeError("La configuración requiere revisión; no se declara validada.")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        try:
            detail = json.loads(error.read()).get("message", "")
        except (ValueError, AttributeError):
            detail = ""
        detail = re.sub(r"sbp_[a-zA-Z0-9_]+|eyJ[a-zA-Z0-9_.-]+", "[credencial omitida]", str(detail))
        raise SystemExit(f"Supabase rechazó la operación: HTTP {error.code}. {detail[:700]}") from None
    except (urllib.error.URLError, TimeoutError):
        raise SystemExit("No se ha podido conectar con Supabase.") from None
    except RuntimeError as error:
        raise SystemExit(str(error)) from None
