"""Comprueba o aplica solo el asunto y el HTML de recuperación en desarrollo."""
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not token:
        raise RuntimeError("Falta SUPABASE_ACCESS_TOKEN; nunca pegarlo en el código.")
    config = tomllib.loads((ROOT / "supabase/config.toml").read_text(encoding="utf-8"))
    recovery = config["auth"]["email"]["template"]["recovery"]
    html = (ROOT / recovery["content_path"]).resolve()
    if not html.is_relative_to(ROOT):
        raise RuntimeError("La plantilla debe pertenecer a esta configuración.")
    content = html.read_text(encoding="utf-8")
    if '{{ .ConfirmationURL }}' not in content:
        raise RuntimeError("La plantilla debe conservar el enlace de Supabase.")
    expected = {
        "mailer_subjects_recovery": recovery["subject"],
        "mailer_templates_recovery_content": content,
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
        # Dos propiedades explícitas: no cambia SMTP, permisos ni confirmación.
        request("PATCH", expected)
        after = request()
    unexpected = sorted(
        k for k in set(before) | set(after)
        if k not in expected and before.get(k) != after.get(k)
    )
    matches_after = all(after.get(k) == v for k, v in expected.items())
    # Solo información del trabajo: no imprimir Auth completo ni credenciales.
    print(json.dumps({
        "project_ref": PROJECT_REF,
        "applied": args.apply and not matches_before,
        "subject_matches": after.get("mailer_subjects_recovery") == recovery["subject"],
        "content_matches": after.get("mailer_templates_recovery_content") == content,
        "html_sha256": hashlib.sha256(content.encode("utf-8")).hexdigest(),
        "custom_smtp_configured": bool(after.get("smtp_host")),
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
