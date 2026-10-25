"""Transporte y activación estática compartidos de los portales Dev.

Cada adaptador aporta su identidad, comprobación HTTPS y credenciales propias.
El motor no decide derechos ni utiliza una cuenta compartida entre portales.
"""
import ftplib
import io
import json
import os
from pathlib import Path
import re
import socket
import ssl
import sys
import time
import urllib.request

FTP_HOST = "srv1589.hstgr.io"
ROOT_FILES = (".htaccess", "robots.txt", "build-info.json", "index.html")


class IPv4FTP_TLS(ftplib.FTP_TLS):
    """FTPS con transporte IPv4 y el nombre original para verificar TLS/SNI."""

    def connect(self, host="", port=0, timeout=-999, source_address=None):
        hostname, service = host or self.host, port or self.port
        addresses = dict.fromkeys(record[4][0] for record in socket.getaddrinfo(
            hostname, service, family=socket.AF_INET, type=socket.SOCK_STREAM)
            if record[0] == socket.AF_INET)
        last_error = None
        for address in addresses:
            try:
                # Solo cambia el transporte: AUTH TLS debe seguir validando el
                # certificado del servidor por su nombre, nunca por la IP.
                return super().connect(address, service, timeout, source_address)
            except OSError as error:
                last_error = error
                self.close()
            finally:
                self.host = hostname
        if last_error is not None:
            raise last_error
        raise OSError("No hay direcciones IPv4 para el servidor de publicación.")


def ftps_context():
    context = ssl.create_default_context()
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    return context


def connection_check(*, label, ftp_factory=IPv4FTP_TLS):
    # No lee secretos, no inicia sesión y no escribe archivos. Contrasta desde
    # el runner la misma resolución IPv4 y el certificado usados al publicar.
    for attempt in range(3):
        ftp = ftp_factory(context=ftps_context(), timeout=15)
        phase = "connect_ipv4"
        try:
            ftp.connect(FTP_HOST, 21)
            phase = "tls"
            ftp.auth()
            print("Transporte " + label + ": IPv4 y certificado TLS verificados.")
            return
        except Exception as error:
            print("Transporte " + label + ":", transfer_diagnostic(phase, error), file=sys.stderr)
            if not transient_transfer(error) or attempt == 2:
                raise
        finally:
            ftp.close()
        time.sleep(5 * (attempt + 1))


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
        "User-Agent": "entrenaop-web-deploy"})
    with urllib.request.urlopen(request, timeout=20) as response:
        if json.load(response)["sha"] != revision:
            raise ValueError("main ha avanzado; se conserva la publicación actual hasta validar la nueva revisión.")


def publish(ftp, package, *, identity, verifier, progress=lambda phase: None):
    package = Path(package)
    expected = json.loads((package / "build-info.json").read_text(encoding="utf-8"))
    identity(expected)
    progress("read_previous")
    ftp.cwd("/")
    # Una cuenta que empiece en la web principal no pasa este control. La cuenta
    # debe estar confinada por Hostinger a la carpeta del portal correspondiente, no solo por el script.
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


def deploy(package, *, identity, publisher, require_current_main, credential_names, label,
           ftp_factory=IPv4FTP_TLS):
    expected = json.loads((Path(package) / "build-info.json").read_text(encoding="utf-8"))
    identity(expected)
    user, password = os.environ.get(credential_names[0], ""), os.environ.get(credential_names[1], "")
    if not user.strip() or not password:
        raise ValueError("Faltan los secretos de la cuenta de publicación.")
    context = ftps_context()
    for attempt in range(3):
        # Cada conexión nueva contrasta main; nunca recuperar un despliegue
        # obsoleto por el mero hecho de reintentar una transferencia.
        require_current_main(expected["revision"])
        phase = "connect_ipv4"
        ftp = ftp_factory(context=context, timeout=45)
        def progress(value):
            nonlocal phase
            phase = value
        try:
            ftp.connect(FTP_HOST, 21)
            phase = "authenticate"
            ftp.auth()
            ftp.login(user, password)
            ftp.prot_p()
            return publisher(ftp, package, progress=progress)
        except Exception as error:
            print("Transferencia " + label + ":", transfer_diagnostic(phase, error), file=sys.stderr)
            # Antes de activar solo se han escrito recursos aislados. Se
            # pueden sobrescribir completos desde otra conexión. Una caída
            # durante activación/restauración exige revisión, no otro intento.
            safe = phase in ("connect_ipv4", "authenticate", "read_previous", "upload_assets")
            if not safe or not transient_transfer(error) or attempt == 2:
                raise
        finally:
            ftp.close()
        time.sleep(5 * (attempt + 1))
