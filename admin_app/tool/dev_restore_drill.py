"""Ensayo de restauración en un contenedor nuevo, sin puertos ni red exterior."""
import hashlib
import json
from pathlib import Path
import re
import secrets
import subprocess
import time
import tempfile

# Misma versión mayor y distribución de extensiones que Dev. Nunca es una URL
# de base de datos configurable: el ensayo no puede sobrescribir Dev ni Prod.
IMAGE = "supabase/postgres:17.6.1.166@sha256:b3bfedb107413abb3b8cb0d0874b0414a1dceb3d55bc0c778de6ad22d1f7dc86"


def copied_rows(text):
    counts, table, count = {}, None, 0
    for line in text.splitlines():
        if table is None:
            match = re.fullmatch(r'COPY ("?[a-zA-Z_][a-zA-Z_0-9]*"?\."?[a-zA-Z_][a-zA-Z_0-9]*"?) .* FROM stdin;', line)
            if match:
                table, count = match[1], 0
        elif line == r"\.":
            counts[table] = count
            table = None
        else:
            count += 1
    if table is not None or not counts:
        raise ValueError("invalid_copy_dump")
    return counts


def verify_files(source):
    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("project") != "sxbxfjqgoddzhtcyhalw" or manifest.get("environment") != "development":
        raise ValueError("wrong_restore_source")
    for relative, expected in manifest["files"].items():
        path = source / relative
        if not path.resolve().is_relative_to(source.resolve()) or path.is_symlink():
            raise ValueError("unsafe_restore_file")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("backup_hash_mismatch")
    index = json.loads((source / "storage/index.json").read_text(encoding="utf-8"))
    for item in index:
        if not re.fullmatch(r"[a-f0-9]{64}", item["file"]):
            raise ValueError("unsafe_storage_path")
        content = (source / "storage" / item["file"]).read_bytes()
        if len(content) != item["bytes"] or hashlib.sha256(content).hexdigest() != item["sha256"]:
            raise ValueError("storage_hash_mismatch")
    return index


def verify_restore(source):
    source = Path(source)
    index = verify_files(source)
    counts = copied_rows((source / "data.sql").read_text(encoding="utf-8"))
    name = "entrenaop-restore-" + secrets.token_hex(8)

    def run(args, data=None):
        result = subprocess.run(args, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=600)
        if result.returncode:
            # La salida de psql puede incluir datos del COPY. No se imprime.
            state = re.search(rb'ERROR:\s+([A-Z0-9]{5})(?:\s|:)', result.stderr)
            raise RuntimeError("isolated_restore_failed" + (":" + state[1].decode() if state else ""))
        return result.stdout

    def query(sql):
        # supabase_admin es el superusuario de este contenedor nuevo. El rol
        # postgres replica el rol restringido de Supabase y no puede preparar
        # los esquemas administrados del ensayo.
        return run(["docker", "exec", "-i", name, "psql", "-X", "-U", "supabase_admin", "-d", "postgres",
                    "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=sqlstate", "-At"], sql.encode()).decode().strip()

    created = False
    try:
        run(["docker", "run", "--detach", "--network", "none", "--name", name,
             "--env", "POSTGRES_PASSWORD=" + secrets.token_hex(24), IMAGE])
        created = True
        for attempt in range(60):
            ready = subprocess.run(["docker", "exec", name, "pg_isready", "-U", "postgres"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if ready.returncode == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError("isolated_database_not_ready")
        roles = (source / "roles.sql").read_text(encoding="utf-8")
        roles = re.sub(r'^CREATE ROLE ("?[A-Za-z_][A-Za-z_0-9]*"?);$',
            lambda m: "do $$begin if not exists(select 1 from pg_roles where rolname=" +
            "'" + m[1].strip('"') + "') then create role " + m[1] + "; end if; end$$;", roles, flags=re.M)
        query(roles)
        # Solo se limpian esquemas del contenedor recién creado por este proceso.
        query("drop schema if exists public,auth,storage,admin_ops_private,trainer_private,supabase_migrations cascade;")
        query((source / "extensions.sql").read_text(encoding="utf-8"))
        query((source / "schema.sql").read_text(encoding="utf-8"))
        query("set session_replication_role=replica;\n" + (source / "data.sql").read_text(encoding="utf-8"))
        for table, expected in counts.items():
            actual = int(query("select count(*) from " + table))
            if actual != expected:
                raise RuntimeError("restored_row_count_mismatch")
        stored = json.loads(query("select coalesce(json_agg(json_build_object('bucket_id',bucket_id,'name',name)), '[]') from storage.objects"))
        if {(r["bucket_id"], r["name"]) for r in stored} != {(r["bucket_id"], r["name"]) for r in index}:
            raise RuntimeError("restored_storage_inventory_mismatch")
        # Recorre todas las FK restauradas; desactivar triggers al cargar no
        # basta para acreditar la integridad de las relaciones.
        query("""do $drill$ declare c record; n bigint; begin
          for c in select con.conrelid::regclass child,con.confrelid::regclass parent,
            string_agg(format('c.%I is not null',a.attname),' and ' order by k.ord) present,
            string_agg(format('p.%I=c.%I',b.attname,a.attname),' and ' order by k.ord) comparison
            from pg_constraint con join pg_namespace ns on ns.oid=con.connamespace
            cross join lateral unnest(con.conkey,con.confkey) with ordinality k(ca,pa,ord)
            join pg_attribute a on a.attrelid=con.conrelid and a.attnum=k.ca
            join pg_attribute b on b.attrelid=con.confrelid and b.attnum=k.pa
            where con.contype='f' and ns.nspname in ('public','auth','storage','admin_ops_private','trainer_private')
            group by con.oid,con.conrelid,con.confrelid loop
              execute format('select count(*) from %s c where %s and not exists(select 1 from %s p where %s)',
                c.child,c.present,c.parent,c.comparison) into n;
              if n<>0 then raise exception 'restore_fk_mismatch'; end if;
          end loop;
        end $drill$;""")
        return {"tables": len(counts), "storage_objects": len(index)}
    finally:
        if created:
            subprocess.run(["docker", "rm", "--force", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)


def self_test():
    with tempfile.TemporaryDirectory() as temp:
        source = Path(temp)
        (source / "roles.sql").write_text("select 1;", encoding="utf-8")
        (source / "extensions.sql").write_text("select 1;", encoding="utf-8")
        (source / "schema.sql").write_text("""create schema auth; create schema storage; create schema public;
          create table auth.users(id uuid primary key);
          create table public.recipe(id uuid primary key, owner_id uuid references auth.users(id), name text);
          create table storage.objects(bucket_id text,name text,primary key(bucket_id,name));""", encoding="utf-8")
        (source / "data.sql").write_text('''COPY auth.users (id) FROM stdin;
10000000-0000-4000-8000-000000000001
\\.
COPY public.recipe (id, owner_id, name) FROM stdin;
20000000-0000-4000-8000-000000000001\t10000000-0000-4000-8000-000000000001\tFixture
\\.
COPY storage.objects (bucket_id, name) FROM stdin;
images\tfixture.jpg
\\.
''', encoding="utf-8")
        storage = source / "storage"
        storage.mkdir()
        file = "a" * 64
        (storage / file).write_bytes(b"fixture image")
        item = {"bucket_id": "images", "name": "fixture.jpg", "file": file,
                "sha256": hashlib.sha256(b"fixture image").hexdigest(), "bytes": len(b"fixture image")}
        (storage / "index.json").write_text(json.dumps([item]), encoding="utf-8")
        files = {p.relative_to(source).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in source.rglob("*") if p.is_file()}
        (source / "manifest.json").write_text(json.dumps({"project": "sxbxfjqgoddzhtcyhalw",
            "environment": "development", "files": files}), encoding="utf-8")
        result = verify_restore(source)
        assert result == {"tables": 3, "storage_objects": 1}, result
        print("Ensayo aislado con datos ficticios: correcto.")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Ensayo local; no admite destinos remotos")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--self-test", action="store_true")
    mode.add_argument("--directory", type=Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        verify_restore(args.directory)
        print("Datos y archivos restaurados y comprobados en aislamiento.")
