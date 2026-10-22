"""Publicación estática de ADMIN Dev; solo biblioteca estándar, sin secretos en disco."""
import argparse
import ftplib
import hashlib
import io
import json
import os
from pathlib import Path
import re
import ssl
import subprocess
import sys
import time
import urllib.request
import urllib.parse

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from static_web_release import package_web as shared_package_web

HOST = "admin.entrenaop.es"
PROJECT = "sxbxfjqgoddzhtcyhalw"
ROOT_FILES = (".htaccess", "robots.txt", "build-info.json", "index.html")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(manifest):
    if (manifest.get("host"), manifest.get("supabaseProject"), manifest.get("environment")) != (HOST, PROJECT, "development"):
        raise ValueError("El destino o el paquete no corresponden a ADMIN Dev.")


def package_web(source, output, revision, release_id, deployment):
    # El transporte y las guardas administrativas conservan su contrato.
    return shared_package_web(source, output, revision, release_id, deployment,
                              host=HOST, project=PROJECT)

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


def publish(ftp, package, verifier=verify_public, *, progress=lambda phase: None):
    package = Path(package)
    expected = json.loads((package / "build-info.json").read_text(encoding="utf-8"))
    identity(expected)
    progress("read_previous")
    ftp.cwd("/")
    # Una cuenta que empiece en la web principal no pasa este control. La cuenta
    # debe estar confinada por Hostinger a public_html/admin, no solo por el script.
    previous = {name: retrieve(ftp, name) for name in ROOT_FILES}
    identity(json.loads(previous["build-info.json"].decode("utf-8-sig")))
    token = expected["releaseId"]
    progress("upload_assets")
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
        progress("activate")
        # La entrada se activa al final; los recursos de la versión anterior se conservan.
        for name in ROOT_FILES:
            replace_file(ftp, name, (package / name).read_bytes(), token)
        progress("verify_https")
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
        progress("restore_previous")
        for name in ROOT_FILES:
            replace_file(ftp, name, previous[name], token + "-restore")
        raise RuntimeError("Publicación fallida; entrada y configuración anteriores restauradas.") from None


def transient_transfer(error):
    if isinstance(error, ssl.SSLError):
        return isinstance(error, ssl.SSLEOFError)
    return isinstance(error, (OSError, EOFError, ftplib.error_temp))


def transfer_diagnostic(phase, error):
    # Solo fase y categorías cerradas: los mensajes del servidor pueden incluir
    # rutas, usuarios o credenciales. errno y la respuesta FTP son numéricos.
    parts = [phase, type(error).__name__]
    if isinstance(error, OSError) and isinstance(error.errno, int):
        parts.append("errno=" + str(error.errno))
    if isinstance(error, ftplib.Error) and re.match(r"^[0-9]{3}", str(error)):
        parts.append("ftp=" + str(error)[:3])
    return " · ".join(parts)


def deploy(package):
    expected = json.loads((Path(package) / "build-info.json").read_text(encoding="utf-8"))
    identity(expected)
    user, password = os.environ["HOSTINGER_ADMIN_FTPS_USER"], os.environ["HOSTINGER_ADMIN_FTPS_PASSWORD"]
    if not user.strip() or not password:
        raise ValueError("Faltan los secretos de la cuenta de publicación.")
    context = ssl.create_default_context()
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    for attempt in range(3):
        # Cada conexión nueva contrasta main; nunca recuperar un despliegue
        # obsoleto por el mero hecho de reintentar una transferencia.
        require_current_main(expected["revision"])
        phase = "connect"
        ftp = ftplib.FTP_TLS(context=context, timeout=45)
        def progress(value):
            nonlocal phase
            phase = value
        try:
            ftp.connect("srv1589.hstgr.io", 21)
            phase = "authenticate"
            ftp.auth()
            ftp.login(user, password)
            ftp.prot_p()
            return publish(ftp, package, progress=progress)
        except Exception as error:
            print("Transferencia ADMIN Dev:", transfer_diagnostic(phase, error), file=sys.stderr)
            # Antes de activar solo se han escrito recursos aislados. Se
            # pueden sobrescribir completos desde otra conexión. Una caída
            # durante activación/restauración exige revisión, no otro intento.
            safe = phase in ("connect", "authenticate", "read_previous", "upload_assets")
            if not safe or not transient_transfer(error) or attempt == 2:
                raise
        finally:
            ftp.close()
        time.sleep(5 * (attempt + 1))


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
