"""Paquete, publicación y comprobación HTTPS de Trainer Dev.

Usa una cuenta confinada propia; nunca reutiliza credenciales ADMIN.
"""
import argparse
import ftplib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from static_web_release import package_web
import static_web_deploy as shared_deploy
from static_web_deploy import IPv4FTP_TLS, transfer_diagnostic

HOST = "trainer.entrenaop.es"
PROJECT = "sxbxfjqgoddzhtcyhalw"

def source_scope():
    # Comprobar todos los paquetes locales que realmente compila Trainer. Otro
    # chat puede trabajar en un paquete aún no consumido sin entrar en el ZIP.
    config_path = ROOT / "trainer_app/.dart_tool/package_config.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    paths = {"trainer_app", "pubspec.yaml", "pubspec.lock", "tools/static_web_release.py",
             "tools/static_web_deploy.py", ".github/workflows/trainer-dev.yml"}
    for package in config["packages"]:
        uri = urllib.parse.urljoin(config_path.as_uri(), package["rootUri"])
        parsed = urllib.parse.urlparse(uri)
        if parsed.scheme != "file":
            continue
        path = Path(urllib.request.url2pathname(parsed.path)).resolve()
        if path.is_relative_to(ROOT):
            paths.add(path.relative_to(ROOT).as_posix())
    return sorted(paths)

def identity(manifest):
    if (manifest.get("host"),manifest.get("supabaseProject"),manifest.get("environment")) != (HOST,PROJECT,"development"):
        raise ValueError("El paquete no corresponde al panel profesional Dev.")
    prefix = manifest.get("assetBase","")
    if not re.fullmatch(r"/releases/[a-f0-9]{40}-[0-9]+-[0-9]+/",prefix):
        raise ValueError("Ruta de publicación inválida.")
    if manifest.get("sourceTreeDirty") is not False:
        raise ValueError("El paquete no acredita fuentes guardadas.")

def create_archive(package, archive):
    package, archive = Path(package), Path(archive)
    identity(json.loads((package / "build-info.json").read_text(encoding="utf-8")))
    # El ZIP solo contiene el paquete público; no la carpeta de trabajo.
    with zipfile.ZipFile(archive,"x",compression=zipfile.ZIP_DEFLATED) as output:
        for path in sorted(package.rglob("*")):
            if path.is_symlink():
                raise ValueError("No se admiten enlaces en la publicación.")
            if path.is_file():
                output.write(path,path.relative_to(package).as_posix())
    return hashlib.sha256(archive.read_bytes()).hexdigest()

def fetch(path):
    request = urllib.request.Request("https://" + HOST + path, headers={"Cache-Control":"no-cache"})
    with urllib.request.urlopen(request,timeout=30) as response:
        if urllib.parse.urlparse(response.url).hostname != HOST:
            raise ValueError("Redirección fuera del panel profesional.")
        return response.read(),response.headers

def verify(manifest):
    identity(manifest)
    body,_ = fetch("/build-info.json?check=" + manifest["revision"])
    actual = json.loads(body)
    identity(actual)
    for key in ("revision","releaseId","mainJsSha256","assetBase"):
        if actual.get(key) != manifest.get(key):
            raise ValueError("La versión servida no coincide con el paquete.")
    main,_ = fetch(actual["assetBase"] + "main.dart.js")
    if hashlib.sha256(main).hexdigest() != actual["mainJsSha256"]:
        raise ValueError("El JavaScript servido no coincide con su SHA-256.")
    page,headers = fetch("/?check=" + manifest["revision"])
    if (actual["assetBase"] + "flutter_bootstrap.js").encode() not in page:
        raise ValueError("La entrada no activa la versión esperada.")
    if "no-store" not in headers.get("Cache-Control","") or headers.get("X-Frame-Options","").upper() != "DENY":
        raise ValueError("Faltan cabeceras de publicación.")
    request = urllib.request.Request("https://" + HOST + actual["assetBase"] + "canvaskit/canvaskit.wasm",method="HEAD")
    with urllib.request.urlopen(request,timeout=20) as response:
        if response.headers.get_content_type() != "application/wasm":
            raise ValueError("MIME WebAssembly incorrecto.")

def connection_check():
    return shared_deploy.connection_check(label="Trainer Dev", ftp_factory=IPv4FTP_TLS)


def require_current_main(revision):
    return shared_deploy.require_current_main(revision)


def publish(ftp, package, verifier=verify, *, progress=lambda phase: None):
    return shared_deploy.publish(ftp, package, identity=identity,
                                 verifier=verifier, progress=progress)


def deploy(package):
    return shared_deploy.deploy(
        package, identity=identity, publisher=publish,
        require_current_main=require_current_main,
        credential_names=("HOSTINGER_TRAINER_FTPS_USER", "HOSTINGER_TRAINER_FTPS_PASSWORD"),
        label="Trainer Dev", ftp_factory=IPv4FTP_TLS)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command",choices=("package","verify","deploy","connection-check"))
    parser.add_argument("--output",default=ROOT/"trainer_app/build/trainer-release",type=Path)
    parser.add_argument("--revision",default=os.environ.get("GITHUB_SHA"))
    parser.add_argument("--release-id")
    args = parser.parse_args()
    if args.command == "connection-check":
        connection_check()
    elif args.command == "deploy":
        result = deploy(args.output)
        print("Trainer Dev publicado y verificado:",result["revision"])
    elif args.command == "package":
        scope = source_scope()
        if subprocess.check_output(["git","status","--porcelain","--",*scope],cwd=ROOT,text=True).strip():
            raise ValueError("Guarda y valida las fuentes antes de empaquetarlas.")
        if subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip() != args.revision:
            raise ValueError("La revisión no coincide con HEAD.")
        package_web(ROOT/"trainer_app/build/web",args.output,args.revision,args.release_id,
                    ROOT/"trainer_app/deployment",host=HOST,project=PROJECT)
        archive = args.output.with_suffix(".zip")
        print("Paquete:",archive)
        print("SHA-256:",create_archive(args.output,archive))
    else:
        verify(json.loads((args.output/"build-info.json").read_text(encoding="utf-8")))
        print("Panel profesional Dev publicado y verificado por HTTPS.")

if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # No volcar respuestas FTPS, nombres de cuenta ni secretos en Actions.
        print("Error de publicación Trainer Dev:",type(error).__name__,file=sys.stderr)
        if isinstance(error,ftplib.Error) and re.match(r"^[0-9]{3}",str(error)):
            print("Respuesta de transferencia:",str(error)[:3],file=sys.stderr)
        if type(error) in (ValueError,RuntimeError):
            print(str(error),file=sys.stderr)
        sys.exit(1)
