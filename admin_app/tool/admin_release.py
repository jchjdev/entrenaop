"""Publicación estática de ADMIN Dev; solo biblioteca estándar, sin secretos en disco."""
import argparse
import datetime
import ftplib
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import ssl
import subprocess
import sys
import time
import urllib.request
import urllib.parse

HOST = "admin.entrenaop.es"
PROJECT = "sxbxfjqgoddzhtcyhalw"
ROOT_FILES = (".htaccess", "robots.txt", "build-info.json", "index.html")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(manifest):
    if (manifest.get("host"), manifest.get("supabaseProject"), manifest.get("environment")) != (HOST, PROJECT, "development"):
        raise ValueError("El destino o el paquete no corresponden a ADMIN Dev.")


def package_web(source, output, revision, release_id, deployment):
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
    manifest = {"host": HOST, "supabaseProject": PROJECT, "environment": "development", "revision": revision,
                "releaseId": release_id, "assetBase": prefix, "sourceTreeDirty": False,
                "builtAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "mainJsSha256": digest((release / "main.dart.js").read_bytes())}
    (output / "build-info.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def retrieve(ftp, name):
    data = io.BytesIO()
    ftp.retrbinary("RETR " + name, data.write)
    return data.getvalue()


def replace_file(ftp, name, data, token):
    # RNTO activa un archivo completo; nunca se trunca la entrada visible durante STOR.
    temporary = name + ".ci-" + token
    ftp.storbinary("STOR " + temporary, io.BytesIO(data))
    ftp.rename(temporary, name)


def require_current_main(revision):
    request = urllib.request.Request("https://api.github.com/repos/jchjdev/entrenaop/commits/main", headers={
        "Authorization": "Bearer " + os.environ["GITHUB_TOKEN"], "Accept": "application/vnd.github+json",
        "User-Agent": "entrenaop-admin-deploy"})
    with urllib.request.urlopen(request, timeout=20) as response:
        if json.load(response)["sha"] != revision:
            raise ValueError("main ha avanzado; se conserva la publicación actual hasta validar la nueva revisión.")


def https_get(path):
    request = urllib.request.Request("https://" + HOST + path, headers={"Cache-Control": "no-cache"})
    with urllib.request.urlopen(request, timeout=30) as response:
        if urllib.parse.urlparse(response.url).hostname != HOST:
            raise ValueError("Redirección HTTPS fuera del admin.")
        return response.read(), response.headers


def verify_public(expected):
    body, _ = https_get("/build-info.json?check=" + expected["revision"])
    actual = json.loads(body)
    identity(actual)
    for key in ("revision", "mainJsSha256", "releaseId"):
        if actual.get(key) != expected.get(key):
            raise ValueError("El manifiesto servido no corresponde a la publicación esperada.")
    prefix = actual.get("assetBase", "/")
    if prefix != "/" and not re.fullmatch(r"/releases/[a-f0-9]{40}-[0-9]+-[0-9]+/", prefix):
        raise ValueError("Ruta de recursos inválida.")
    main, _ = https_get(prefix + "main.dart.js")
    if digest(main) != actual["mainJsSha256"].lower():
        raise ValueError("El JavaScript servido no coincide con su SHA-256.")
    page, headers = https_get("/?check=" + expected["revision"])
    if "no-store" not in headers.get("Cache-Control", "") or headers.get("X-Frame-Options", "").upper() != "DENY":
        raise ValueError("Faltan cabeceras del acceso administrativo.")
    if prefix != "/" and (prefix + "flutter_bootstrap.js").encode() not in page:
        raise ValueError("La entrada no activa la versión esperada.")
    # HEAD evita descargar de nuevo el motor de varios MB.
    request = urllib.request.Request("https://" + HOST + prefix + "canvaskit/canvaskit.wasm", method="HEAD")
    with urllib.request.urlopen(request, timeout=20) as response:
        if response.headers.get_content_type() != "application/wasm":
            raise ValueError("Hostinger no está sirviendo el MIME de WebAssembly.")


def publish(ftp, package, verifier=verify_public):
    package = Path(package)
    expected = json.loads((package / "build-info.json").read_text(encoding="utf-8"))
    identity(expected)
    ftp.cwd("/")
    # Una cuenta que empiece en la web principal no pasa este control. La cuenta
    # debe estar confinada por Hostinger a public_html/admin, no solo por el script.
    previous = {name: retrieve(ftp, name) for name in ROOT_FILES}
    identity(json.loads(previous["build-info.json"].decode("utf-8-sig")))
    token = expected["releaseId"]
    made = set()
    for path in sorted((package / "releases").rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(package).as_posix()
        parent = Path(relative).parent.as_posix()
        components = parent.split("/")
        for count in range(1, len(components) + 1):
            directory = "/".join(components[:count])
            if directory not in made:
                try:
                    ftp.mkd(directory)
                except ftplib.error_perm:
                    ftp.cwd(directory)
                    ftp.cwd("/")
                made.add(directory)
        with path.open("rb") as data:
            ftp.storbinary("STOR " + relative, data)
    try:
        # La entrada se activa al final; los recursos de la versión anterior se conservan.
        for name in ROOT_FILES:
            replace_file(ftp, name, (package / name).read_bytes(), token)
        last_error = None
        for attempt in range(4):
            try:
                verifier(expected)
                return expected
            except Exception as error:
                last_error = error
                if attempt < 3:
                    time.sleep(3)
        raise RuntimeError("La comprobación HTTPS no ha pasado.") from last_error
    except Exception:
        for name in ROOT_FILES:
            replace_file(ftp, name, previous[name], token + "-restore")
        raise RuntimeError("Publicación fallida; entrada y configuración anteriores restauradas.") from None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("package", "deploy"))
    parser.add_argument("--package", default="admin_app/build/admin-release")
    parser.add_argument("--revision", default=os.environ.get("GITHUB_SHA"))
    args = parser.parse_args()
    if args.command == "package":
        scope = ["admin_app", "packages", "pubspec.yaml", "pubspec.lock"]
        if subprocess.check_output(["git", "status", "--porcelain", "--", *scope], text=True).strip():
            raise ValueError("No se empaquetan fuentes con cambios pendientes.")
        if subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() != args.revision:
            raise ValueError("La revisión del build no coincide con HEAD.")
        release_id = args.revision + "-" + os.environ["GITHUB_RUN_ID"] + "-" + os.environ["GITHUB_RUN_ATTEMPT"]
        package_web("admin_app/build/web", args.package, args.revision, release_id, "admin_app/deployment")
    else:
        expected = json.loads((Path(args.package) / "build-info.json").read_text(encoding="utf-8"))
        require_current_main(expected["revision"])
        user, password = os.environ["HOSTINGER_ADMIN_FTPS_USER"], os.environ["HOSTINGER_ADMIN_FTPS_PASSWORD"]
        if not user.strip() or not password:
            raise ValueError("Faltan los secretos de la cuenta de publicación.")
        context = ssl.create_default_context()
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        with ftplib.FTP_TLS(context=context, timeout=45) as ftp:
            ftp.connect("srv1589.hstgr.io", 21)
            ftp.auth()
            ftp.login(user, password)
            ftp.prot_p()
            result = publish(ftp, args.package)
        print("ADMIN Dev publicado y verificado:", result["revision"])


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Las excepciones de transporte pueden contener respuestas del servidor:
        # no se imprimen variables de entorno ni credenciales.
        print("Error de publicación:", type(error).__name__, file=sys.stderr)
        if isinstance(error, ftplib.Error) and re.match(r"^[0-9]{3}", str(error)):
            print("Respuesta de transferencia:", str(error)[:3], file=sys.stderr)
        if type(error) in (ValueError, RuntimeError):
            print(str(error), file=sys.stderr)
        sys.exit(1)
