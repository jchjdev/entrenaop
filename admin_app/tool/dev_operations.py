"""Copias y errores exclusivamente de Dev. Sin dependencias Python externas.

Los secretos solo se leen del entorno del job; ningún cuerpo de error remoto
ni salida de pg_dump se imprime en los logs públicos de GitHub.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
import urllib.error

PROJECT = "sxbxfjqgoddzhtcyhalw"
REPO = "jchjdev/entrenaop"
URL = f"https://{PROJECT}.supabase.co"
MAX_ARCHIVE = 16 * 1024 * 1024
MAX_SOURCE = 256 * 1024 * 1024
MAX_ARTIFACT_STORAGE = 400 * 1024 * 1024
SOURCES = {"edge_logs": "api", "postgres_logs": "database", "auth_logs": "auth",
           "storage_logs": "storage", "function_edge_logs": "functions"}
LOG_SQL = """select timestamp, id, source,
  log_attributes['parsed.sql_state_code'] as sqlstate,
  greatest(toInt32OrZero(log_attributes['response.status_code']),
    toInt32OrZero(log_attributes['status_code'])) as status
from logs where
  (source='postgres_logs' and log_attributes['parsed.error_severity'] in ('ERROR','FATAL','PANIC')
   and log_attributes['parsed.sql_state_code'] not in ('22023','42501','P0002'))
  or (source in ('edge_logs','auth_logs','storage_logs','function_edge_logs')
    and greatest(toInt32OrZero(log_attributes['response.status_code']),
      toInt32OrZero(log_attributes['status_code'])) between 500 and 599)
order by timestamp desc limit 1000"""


class OperationsError(Exception):
    pass


def now():
    return dt.datetime.now(dt.timezone.utc)


def stamp(value=None):
    return (value or now()).isoformat()


def configured():
    if os.environ.get("DEV_PROJECT_REF") != PROJECT:
        raise OperationsError("wrong_project")
    if os.environ.get("GITHUB_REPOSITORY") != REPO or os.environ.get("GITHUB_REF") != "refs/heads/main":
        raise OperationsError("wrong_repository_or_branch")
    if not os.environ.get("SUPABASE_ACCESS_TOKEN"):
        raise OperationsError("missing_dev_token")


def api(path, data=None, *, github=False):
    base = f"https://api.github.com/repos/{REPO}" if github else f"https://api.supabase.com/v1/projects/{PROJECT}"
    key = os.environ["GITHUB_TOKEN" if github else "SUPABASE_ACCESS_TOKEN"]
    request = urllib.request.Request(base + path,
        data=None if data is None else json.dumps(data).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json",
                 "Accept": "application/json", "User-Agent": "EntrenaOP-Dev-Operations"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # El estado HTTP permite distinguir credencial, permiso y consulta sin
        # publicar URL, cabeceras ni el cuerpo privado devuelto por el servicio.
        provider = "github" if github else "supabase"
        operation = "logs" if path.startswith("/analytics/") else "database" if path == "/database/query" else "other"
        # Solo se extraen códigos SQL/ClickHouse y categorías cerradas. El
        # cuerpo remoto puede incluir consultas o datos y nunca se publica.
        detail = ""
        if error.code == 400:
            body = error.read(32768).decode("utf-8", errors="replace")
            state = re.search(r'ERROR:\s+([A-Z0-9]{5})\b|Code:\s*(\d{1,5})\b', body)
            if state:
                detail = "_" + next(v for v in state.groups() if v)
            else:
                detail = "".join("_" + word for word in ("timestamp", "transaction", "syntax", "interval") if word in body.lower())
        raise OperationsError(provider + "_api_http_" + str(error.code) + "_" + operation + detail) from error
    except Exception as error:
        raise OperationsError("github_api_failed" if github else "supabase_api_failed") from error


def sql(text, *, read_only=False):
    result = api("/database/query", {"query": text, "read_only": read_only})
    if not isinstance(result, list):
        raise OperationsError("invalid_database_response")
    return result


def literal(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def run_id():
    value = os.environ.get("GITHUB_RUN_ID", "") + "-" + os.environ.get("GITHUB_RUN_ATTEMPT", "")
    if not re.fullmatch(r"[0-9]+-[0-9]+", value):
        raise OperationsError("invalid_run")
    return value


def command(args, *, data=None, env=None, timeout=600):
    result = subprocess.run(args, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            env=env, timeout=timeout)
    if result.returncode:
        raise OperationsError("command_failed")
    return result.stdout


def normalize_event(row):
    source = row.get("source")
    if source not in SOURCES:
        raise OperationsError("invalid_log_source")
    when = str(row.get("timestamp", ""))
    try:
        parsed = dt.datetime.fromisoformat(when.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
    except ValueError as error:
        raise OperationsError("invalid_log_date") from error
    code = str(row.get("sqlstate") if source == "postgres_logs" else row.get("status"))
    if not re.fullmatch(r"[A-Za-z0-9_]{1,50}", code):
        raise OperationsError("invalid_log_code")
    # Se conserva identidad para deduplicar, nunca mensajes, consultas ni rutas.
    identity = hashlib.sha256((source + ":" + str(row.get("id")) + ":" + when).encode()).hexdigest()
    return {"event_id": identity, "occurred_at": stamp(parsed), "source": source,
            "code": code, "component": SOURCES[source]}


def collect_logs():
    end = now().replace(second=0, microsecond=0)
    # Solapamiento de 24 h: tolera retrasos del proveedor y reintentos sin duplicar.
    start = end - dt.timedelta(hours=24)
    query = urllib.parse.urlencode({"sql": LOG_SQL, "iso_timestamp_start": stamp(start).replace("+00:00", "Z"),
                                   "iso_timestamp_end": stamp(end).replace("+00:00", "Z")})
    try:
        data = api("/analytics/endpoints/logs?" + query)
        if not isinstance(data, dict) or data.get("error") or not isinstance(data.get("result"), list):
            raise OperationsError("invalid_logs_response")
        events = [normalize_event(row) for row in data["result"]]
        if len(events) > 1000:
            raise OperationsError("invalid_logs_count")
        encoded = literal(json.dumps(events))
        sql("""begin;
          insert into admin_ops_private.service_events(event_id,occurred_at,source,code,component)
          select event_id,occurred_at,source,code,component from jsonb_to_recordset(""" + encoded + """::jsonb)
          as e(event_id text,occurred_at timestamptz,source text,code text,component text)
          on conflict(event_id) do nothing;
          insert into admin_ops_private.log_collections values(""" + ",".join(map(literal, [run_id(), stamp(), stamp(start), stamp(end), "success", len(events) == 1000, len(events)])) + """ )
          on conflict(run_id) do update set checked_at=excluded.checked_at,status=excluded.status,
            truncated=excluded.truncated,event_count=excluded.event_count;
          delete from admin_ops_private.service_events where occurred_at<now()-interval '14 days';
          delete from admin_ops_private.log_collections where checked_at<now()-interval '14 days';
          commit;""")
        print("Consulta de errores Dev completada:", len(events), "eventos sin datos personales.")
    except Exception:
        sql("insert into admin_ops_private.log_collections values(" +
            ",".join(map(literal, [run_id(), stamp(), stamp(start), stamp(end), "failed", False, 0])) +
            ") on conflict(run_id) do update set checked_at=excluded.checked_at,status='failed';")
        raise


def tree_digest(directory):
    return {str(p.relative_to(directory)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(directory.rglob("*")) if p.is_file()}


def pack_and_encrypt(source, output, *, gpg="gpg"):
    password = os.environ.get("DEV_BACKUP_PASSPHRASE", "")
    if len(password) < 24 or any(c in password for c in "\n\r\0"):
        raise OperationsError("invalid_encryption_passphrase")
    output = Path(output)
    if output.exists():
        raise OperationsError("archive_exists")
    with tempfile.TemporaryDirectory() as temp:
        archive = Path(temp) / "backup.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            for path in sorted(Path(source).rglob("*")):
                if path.is_symlink():
                    raise OperationsError("unsafe_backup_source")
                if path.is_file():
                    tar.add(path, arcname=path.relative_to(source).as_posix(), recursive=False)
        home = Path(temp) / "gpg"
        home.mkdir(mode=0o700)
        def gpg_path(path):
            value = Path(path).resolve().as_posix()
            if os.name == 'nt' and '/Git/usr/bin/' in gpg.replace('\\', '/'):
                return '/' + value[0].lower() + value[2:]
            return value
        prefix = [gpg, "--homedir", gpg_path(home), "--batch", "--no-tty", "--no-symkey-cache", "--pinentry-mode", "loopback", "--passphrase-fd", "0"]
        command(prefix + ["--symmetric", "--cipher-algo", "AES256", "--output", gpg_path(output), gpg_path(archive)], data=(password + "\n").encode())
        # El paquete publicado debe descifrarse exactamente, no solo existir.
        restored = command(prefix + ["--decrypt", gpg_path(output)], data=(password + "\n").encode())
        if hashlib.sha256(restored).digest() != hashlib.sha256(archive.read_bytes()).digest():
            raise OperationsError("encryption_roundtrip_failed")
    if output.stat().st_size > MAX_ARCHIVE:
        raise OperationsError("archive_size_limit")
    return {"archive_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
            "archive_bytes": output.stat().st_size}


def storage_backup(directory):
    keys = api("/api-keys?reveal=true")
    key = next((k["api_key"] for k in keys if k.get("name") == "service_role"), None)
    if not key:
        raise OperationsError("missing_storage_read_key")
    # La lista se toma de la misma base de datos: incluye buckets privados y no
    # convierte los nombres de archivos en rutas locales ejecutables.
    objects = sql("select bucket_id,name,metadata from storage.objects order by bucket_id,name", read_only=True)
    if len(objects) > 5000:
        raise OperationsError("storage_count_limit")
    result, total = [], 0
    directory.mkdir()
    for obj in objects:
        identity = hashlib.sha256((obj["bucket_id"] + "/" + obj["name"]).encode()).hexdigest()
        path = urllib.parse.quote(obj["bucket_id"], safe="") + "/" + urllib.parse.quote(obj["name"], safe="/")
        request = urllib.request.Request(URL + "/storage/v1/object/" + path,
            headers={"apikey": key, "Authorization": "Bearer " + key})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read(MAX_SOURCE + 1)
        total += len(data)
        if total > MAX_SOURCE:
            raise OperationsError("storage_size_limit")
        (directory / identity).write_bytes(data)
        result.append({"bucket_id": obj["bucket_id"], "name": obj["name"], "file": identity,
                       "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
    (directory / "index.json").write_text(json.dumps(result), encoding="utf-8")
    return len(result)


def assert_artifact_budget(extra):
    total, page = 0, 1
    while True:
        data = api(f"/actions/artifacts?per_page=100&page={page}", github=True)
        rows = data["artifacts"]
        total += sum(r["size_in_bytes"] for r in rows if not r["expired"])
        if len(rows) < 100:
            break
        page += 1
        if page > 50:
            raise OperationsError("artifact_inventory_limit")
    if total + extra + 1024*1024 > MAX_ARTIFACT_STORAGE:
        raise OperationsError("artifact_budget_limit")


def backup(output):
    run = run_id()
    sql("insert into admin_ops_private.backup_runs(run_id,started_at,status) values(" + literal(run) +
        ",now(),'running') on conflict(run_id) do nothing")
    try:
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source"
            source.mkdir()
            schemas = "public,auth,storage,admin_ops_private,trainer_private,supabase_migrations"
            for name, flags in [("roles.sql", ["--role-only"]),
                ("schema.sql", ["--schema", schemas]),
                ("data.sql", ["--schema", schemas, "--data-only", "--use-copy"])]:
                command(["supabase", "db", "dump", "--project-ref", PROJECT, "--file", str(source / name), *flags])
            extensions = sql("select format('create schema if not exists %I; create extension if not exists %I with schema %I;',"
                "n.nspname,e.extname,n.nspname) as statement from pg_extension e join pg_namespace n on n.oid=e.extnamespace "
                "where e.extname<>'plpgsql' order by e.extname", read_only=True)
            (source / "extensions.sql").write_text("\n".join(e["statement"] for e in extensions), encoding="utf-8")
            count = storage_backup(source / "storage")
            revision = os.environ.get("GITHUB_SHA", "")
            if not re.fullmatch(r"[a-f0-9]{40}", revision):
                raise OperationsError("invalid_source_revision")
            shutil.copytree("supabase/migrations", source / "migrations")
            if sum(p.stat().st_size for p in source.rglob('*') if p.is_file()) > MAX_SOURCE:
                raise OperationsError("source_size_limit")
            manifest = {"format": 1, "project": PROJECT, "environment": "development", "created_at": stamp(),
                "revision": revision, "database": "17", "storage_objects": count,
                "excludes": ["Bunny videos", "Edge secrets", "Auth encryption root key", "provider settings"],
                "files": tree_digest(source)}
            (source / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            # El ensayo acepta únicamente el contenedor temporal creado por el
            # script; jamás una URL o contraseña de un proyecto remoto.
            from dev_restore_drill import verify_restore, RestoreError
            try:
                verify_restore(source)
            except RestoreError as error:
                raise OperationsError(str(error)) from error
            verified = stamp()
            output = Path(output)
            output.mkdir(parents=True, exist_ok=True)
            archive = output / ("entrenaop-dev-" + run + ".tar.gz.gpg")
            evidence = pack_and_encrypt(source, archive)
            assert_artifact_budget(evidence["archive_bytes"])
            evidence.update({"run_id": run, "storage_objects": count, "restore_verified_at": verified,
                             "artifact_name": "entrenaop-dev-" + run})
            # Solo metadatos no sensibles: el único archivo subible es *.gpg.
            (output / "receipt.json").write_text(json.dumps(evidence), encoding="utf-8")
            print("Copia Dev cifrada y ensayo aislado correctos.")
    except Exception:
        sql("update admin_ops_private.backup_runs set status='failed',finished_at=now(),failure_code='backup_failed' where run_id=" + literal(run))
        raise


def publish_receipt(path, artifact_id):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    artifact = api(f"/actions/artifacts/{int(artifact_id)}", github=True)
    if artifact["name"] != data["artifact_name"] or artifact["expired"]:
        raise OperationsError("invalid_artifact")
    expires = dt.datetime.fromisoformat(artifact["expires_at"].replace("Z", "+00:00"))
    sql("update admin_ops_private.backup_runs set status='verified',finished_at=now(),artifact_id=" + literal(int(artifact_id)) +
        ",artifact_name=" + literal(data["artifact_name"]) + ",archive_sha256=" + literal(data["archive_sha256"]) +
        ",archive_bytes=" + literal(data["archive_bytes"]) + ",storage_objects=" + literal(data["storage_objects"]) +
        ",restore_verified_at=" + literal(data["restore_verified_at"]) + ",expires_at=" + literal(stamp(expires)) +
        " where run_id=" + literal(run_id()))
    print("Evidencia de copia publicada registrada en Dev.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("logs", "backup", "receipt", "failed"))
    parser.add_argument("--output", default=os.environ.get("RUNNER_TEMP", ".dart_tool") + "/dev-backup")
    parser.add_argument("--artifact-id", type=int)
    args = parser.parse_args()
    configured()
    if args.command == "logs":
        collect_logs()
    elif args.command == "backup":
        backup(args.output)
    elif args.command == "receipt":
        publish_receipt(Path(args.output) / "receipt.json", args.artifact_id)
    else:
        sql("update admin_ops_private.backup_runs set status='failed',finished_at=now(),failure_code='job_failed' where run_id=" +
            literal(run_id()) + " and status='running'")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("Operaciones Dev:", str(error) if isinstance(error, OperationsError) else type(error).__name__, file=sys.stderr)
        sys.exit(1)
