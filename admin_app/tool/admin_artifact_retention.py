"""Plan de retención de compilados ADMIN Dev. Sin aplicar salvo --apply."""
import argparse
import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

from admin_release import https_get, identity

REPO = "jchjdev/entrenaop"
KEEP = 5


def read_with_retry(provider, action):
    # Solo lecturas: un fallo temporal no obliga a repetir una publicación.
    # Un DELETE incierto nunca se reenvía automáticamente desde este helper.
    for attempt in range(3):
        try:
            return action()
        except urllib.error.HTTPError as error:
            code = error.code
            error.close()
            reason = 'http_' + str(code)
            transient = code in (408, 429, 500, 502, 503, 504)
        except (urllib.error.URLError, TimeoutError):
            reason, transient = 'transport', True
        if not transient or attempt == 2:
            # No incluir URL, cabeceras, cuerpo remoto ni texto de la excepción.
            raise ValueError('retention_read_failed:' + provider + ':' + reason) from None
        time.sleep(1 << attempt)


def plan(rows, revision):
    if not re.fullmatch(r"[a-f0-9]{40}", revision):
        raise ValueError("invalid_revision")
    candidates = []
    for row in rows:
        match = re.fullmatch(r"admin-dev-([a-f0-9]{40})", row.get("name", ""))
        run = row.get("workflow_run") or {}
        if row.get("expired") or not match or run.get("head_branch") != "main" or run.get("head_sha") != match[1]:
            continue
        if type(row.get("id")) is not int or row["id"] <= 0:
            raise ValueError("invalid_artifact_id")
        created = dt.datetime.fromisoformat(row["created_at"].replace("Z", "+00:00"))
        candidates.append((created, row))
    candidates.sort(key=lambda item: (item[0], item[1]["id"]), reverse=True)
    if not any(row["name"] == "admin-dev-" + revision for _, row in candidates):
        raise ValueError("published_artifact_not_found")
    kept, removed = [], []
    for position, (_, row) in enumerate(candidates):
        # La versión que acaba de verificarse en HTTPS nunca se retira, aunque
        # aparezcan más paquetes de otras ejecuciones mientras tanto.
        (kept if position < KEEP or row["name"] == "admin-dev-" + revision else removed).append(row)
    return kept, removed


def api(path, method="GET"):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "entrenaop-admin-retention"}
    if os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    request = urllib.request.Request("https://api.github.com/repos/" + REPO + path, headers=headers, method=method)
    def perform():
        with urllib.request.urlopen(request, timeout=30) as response:
            return None if response.status == 204 else json.load(response)
    if method == 'GET':
        return read_with_retry('github', perform)
    try:
        return perform()
    except urllib.error.HTTPError as error:
        code = error.code
        error.close()
        raise ValueError('retention_write_failed:github:http_' + str(code)) from None
    except (urllib.error.URLError, TimeoutError):
        raise ValueError('retention_write_failed:github:transport') from None


def inventory():
    rows = []
    for page in range(1, 21):
        batch = api(f"/actions/artifacts?per_page=100&page={page}")["artifacts"]
        rows.extend(batch)
        if len(batch) < 100:
            return rows
    raise ValueError("artifact_inventory_limit")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--revision", default=os.environ.get("GITHUB_SHA"))
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.apply and (os.environ.get("GITHUB_REPOSITORY") != REPO or
        os.environ.get("GITHUB_REF") != "refs/heads/main" or not os.environ.get("GITHUB_TOKEN") or
        args.revision != os.environ.get("GITHUB_SHA")):
        raise ValueError("wrong_retention_context")
    published = json.loads(read_with_retry('admin_manifest',
        lambda: https_get("/build-info.json?retention=" + str(args.revision)))[0])
    identity(published)
    if published.get("revision") != args.revision:
        raise ValueError("published_revision_changed")
    kept, removed = plan(inventory(), args.revision)
    print(json.dumps({"apply": args.apply, "kept": [r["name"] for r in kept],
        "remove": [{"id": r["id"], "name": r["name"], "bytes": r["size_in_bytes"]} for r in removed],
        "released_bytes": sum(r["size_in_bytes"] for r in removed)}))
    if args.apply:
        for row in removed:
            # Revisar de nuevo la identidad; nunca se usa una URL o un ID
            # arbitrario recibido de un formulario o de un artefacto de datos.
            current = api("/actions/artifacts/" + str(row["id"]))
            if current["name"] != row["name"] or current.get("workflow_run") != row.get("workflow_run"):
                raise ValueError("artifact_identity_changed")
            api("/actions/artifacts/" + str(row["id"]), method="DELETE")
        print("Retención de compilados ADMIN Dev aplicada.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("Retención ADMIN Dev:", str(error) if type(error) is ValueError else type(error).__name__, file=sys.stderr)
        sys.exit(1)
