"""Publicación estática de ADMIN Dev; solo biblioteca estándar, sin secretos en disco."""
import argparse
import ftplib
import hashlib
import io
import json
import os
from pathlib import Path
import re
import socket
import ssl
import subprocess
import sys
import time
import urllib.request
import urllib.parse

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from static_web_release import package_web as shared_package_web
import static_web_deploy as shared_deploy
from static_web_deploy import (FTP_HOST, ROOT_FILES, IPv4FTP_TLS, ftps_context,
                               retrieve, replace_file, transient_transfer, transfer_diagnostic)

HOST = "admin.entrenaop.es"
PROJECT = "sxbxfjqgoddzhtcyhalw"


def connection_check():
    return shared_deploy.connection_check(label="ADMIN Dev", ftp_factory=IPv4FTP_TLS)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(manifest):
    if (manifest.get("host"), manifest.get("supabaseProject"), manifest.get("environment")) != (HOST, PROJECT, "development"):
        raise ValueError("El destino o el paquete no corresponden a ADMIN Dev.")


def package_web(source, output, revision, release_id, deployment):
    # El transporte y las guardas administrativas conservan su contrato.
    return shared_package_web(source, output, revision, release_id, deployment,
                              host=HOST, project=PROJECT)

def require_current_main(revision):
    return shared_deploy.require_current_main(revision)


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


def publish(ftp, package, verifier=verify_public, *, progress=lambda phase: None):
    return shared_deploy.publish(ftp, package, identity=identity,
                                 verifier=verifier, progress=progress)


def deploy(package):
    return shared_deploy.deploy(
        package, identity=identity, publisher=publish,
        require_current_main=require_current_main,
        credential_names=("HOSTINGER_ADMIN_FTPS_USER", "HOSTINGER_ADMIN_FTPS_PASSWORD"),
        label="ADMIN Dev", ftp_factory=IPv4FTP_TLS)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("package", "deploy", "connection-check"))
    parser.add_argument("--package", default="admin_app/build/admin-release")
    parser.add_argument("--revision", default=os.environ.get("GITHUB_SHA"))
    args = parser.parse_args()
    if args.command == "connection-check":
        connection_check()
    elif args.command == "package":
        scope = ["admin_app", "packages", "pubspec.yaml", "pubspec.lock",
                 "tools/static_web_release.py", "tools/static_web_deploy.py",
                 ".github/workflows/admin-dev.yml"]
        if subprocess.check_output(["git", "status", "--porcelain", "--", *scope], text=True).strip():
            raise ValueError("No se empaquetan fuentes con cambios pendientes.")
        if subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() != args.revision:
            raise ValueError("La revisión del build no coincide con HEAD.")
        release_id = args.revision + "-" + os.environ["GITHUB_RUN_ID"] + "-" + os.environ["GITHUB_RUN_ATTEMPT"]
        package_web("admin_app/build/web", args.package, args.revision, release_id, "admin_app/deployment")
    else:
        result = deploy(args.package)
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
