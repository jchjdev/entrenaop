"""Empaquetado estático compartido de los paneles EntrenaOP Dev. Sin credenciales."""
import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil

def digest(data):
    return hashlib.sha256(data).hexdigest()


def package_web(source, output, revision, release_id, deployment, *, host, project):
    if host not in ("admin.entrenaop.es", "trainer.entrenaop.es") or project != "sxbxfjqgoddzhtcyhalw":
        raise ValueError("Solo se empaquetan los paneles autorizados de EntrenaOP Dev.")
    if not re.fullmatch(r"[a-f0-9]{40}", revision):
        raise ValueError("Se exige una revisión Git completa.")
    if not re.fullmatch(re.escape(revision) + r"-[0-9]+-[0-9]+", release_id):
        raise ValueError("Identificador de publicación inválido.")
    source, output, deployment = Path(source), Path(output), Path(deployment)
    required = ("index.html", "flutter_bootstrap.js", "main.dart.js", "canvaskit/canvaskit.wasm")
    if not all((source / name).is_file() for name in required):
        raise ValueError("El build de Flutter está incompleto.")
    for path in source.rglob("*"):
        if path.is_symlink() or path.name.startswith(".env") or path.suffix in (".dart", ".map", ".pem", ".key"):
            raise ValueError("El build contiene fuentes, secretos, mapas o enlaces.")
    bootstrap = (source / "flutter_bootstrap.js").read_text(encoding="utf-8")
    index = (source / "index.html").read_text(encoding="utf-8")
    if bootstrap.count("_flutter.loader.load();") != 1 or index.count('src="flutter_bootstrap.js"') != 1:
        raise ValueError("Ha cambiado el contrato de arranque de Flutter; revisar antes de publicar.")
    # El SDK incluye la API de service worker aunque no se use. El contrato
    # anterior exige precisamente la llamada sin configuración que lo registre.
    output.mkdir(parents=True, exist_ok=False)
    prefix = f"/releases/{release_id}/"
    release = output / "releases" / release_id
    shutil.copytree(source, release)
    config = {"entrypointBaseUrl": prefix, "assetBase": prefix, "canvasKitBaseUrl": prefix + "canvaskit/"}
    (release / "flutter_bootstrap.js").write_text(
        bootstrap.replace("_flutter.loader.load();", "_flutter.loader.load(" + json.dumps({"config": config}) + ");"), encoding="utf-8"
    )
    index = index.replace('src="flutter_bootstrap.js"', f'src="{prefix}flutter_bootstrap.js"')
    for name in ("favicon.png", "manifest.json", "icons/Icon-192.png"):
        index = index.replace(f'href="{name}"', f'href="{prefix}{name}"')
    (output / "index.html").write_text(index, encoding="utf-8")
    shutil.copyfile(deployment / "hostinger-dev.htaccess", output / ".htaccess")
    shutil.copyfile(deployment / "robots.txt", output / "robots.txt")
    manifest = {"host": host, "supabaseProject": project, "environment": "development", "revision": revision,
                "releaseId": release_id, "assetBase": prefix, "sourceTreeDirty": False,
                "builtAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "mainJsSha256": digest((release / "main.dart.js").read_bytes())}
    (output / "build-info.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest
