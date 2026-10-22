import hashlib
import io
import json
import os
import re
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dev_operations as ops
import dev_restore_drill as drill


class DevOperationsTests(unittest.TestCase):
    def test_all_application_schemas_declared_in_migrations_are_backed_up(self):
        migrations = Path(__file__).resolve().parents[3] / "supabase/migrations"
        declared = set()
        for path in migrations.glob("*.sql"):
            declared.update(re.findall(r'create\s+schema\s+(?:if\s+not\s+exists\s+)?"?([a-z_]+)',
                                       path.read_text(encoding="utf-8"), re.I))
        self.assertTrue(declared)
        self.assertEqual(declared - set(drill.BACKUP_SCHEMAS), set())

    def test_unknown_private_schema_stops_before_export(self):
        with patch.object(ops, "sql", return_value=[{"nspname": "new_private"}]):
            with self.assertRaisesRegex(ops.OperationsError, "backup_schema_scope_incomplete"):
                ops.assert_backup_scope()
        with patch.object(ops, "sql", return_value=[{"nspname": s} for s in drill.BACKUP_SCHEMAS if s.endswith('_private')]):
            ops.assert_backup_scope()

    def test_production_wrong_repo_and_branch_are_refused(self):
        settings = {"DEV_PROJECT_REF": ops.PROJECT, "GITHUB_REPOSITORY": ops.REPO,
                    "GITHUB_REF": "refs/heads/main", "SUPABASE_ACCESS_TOKEN": "fixture"}
        for key, value in [("DEV_PROJECT_REF", "izzsttrrgrowktfjssqv"),
                           ("GITHUB_REPOSITORY", "another/repo"), ("GITHUB_REF", "refs/pull/1/merge")]:
            with self.subTest(key=key), patch.dict(os.environ, settings | {key: value}):
                with self.assertRaises(ops.OperationsError):
                    ops.configured()

    def test_sql_values_cannot_escape_their_literal(self):
        self.assertEqual(ops.literal("a'; select secret;--"), "'a''; select secret;--'")

    def test_logs_keep_only_closed_metadata_and_stable_identity(self):
        row = {"timestamp": "2026-10-20T12:00:00Z", "id": "fixture", "source": "edge_logs", "status": 503,
               "event_message": "password=secret", "token": "secret", "path": "/users/private@example.com"}
        clean = ops.normalize_event(row)
        self.assertEqual(set(clean), {"event_id", "occurred_at", "source", "code", "component"})
        self.assertEqual(clean, ops.normalize_event(row))
        self.assertNotIn("secret", json.dumps(clean))
        self.assertEqual(clean["code"], "503")

    def test_unknown_log_source_and_code_fail_closed(self):
        for row in [{"source": "unknown"}, {"source": "edge_logs", "timestamp": "bad"},
                    {"source": "postgres_logs", "timestamp": "2026-10-20T12:00Z", "sqlstate": "token=secret"}]:
            with self.assertRaises(ops.OperationsError):
                ops.normalize_event(row)

    def test_copy_counts_escaped_newlines_and_empty_tables(self):
        text = 'COPY "public"."fixture" (id,name) FROM stdin;\n1\ta\\nb\n\\.\nCOPY auth.empty (id) FROM stdin;\n\\.\n'
        self.assertEqual(drill.copied_rows(text), {'"public"."fixture"': 1, 'auth.empty': 0})
        with self.assertRaises(ValueError):
            drill.copied_rows('COPY public.fixture (id) FROM stdin;\n1\n')

    def test_encrypted_package_roundtrip_and_no_plaintext_uploaded(self):
        gpg = shutil.which("gpg") or "C:/Program Files/Git/usr/bin/gpg.exe"
        if not Path(gpg).is_file():
            self.fail("GPG es obligatorio para validar copias")
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {"DEV_BACKUP_PASSPHRASE": "fixture-long-backup-passphrase-2026"}):
            root = Path(temp)
            source = root / "source"
            source.mkdir()
            (source / "data.sql").write_text("fixture private secret", encoding="utf-8")
            output = root / "archive.gpg"
            result = ops.pack_and_encrypt(source, output, gpg=gpg)
            self.assertNotIn(b"fixture private secret", output.read_bytes())
            self.assertEqual(result["archive_sha256"], hashlib.sha256(output.read_bytes()).hexdigest())
            self.assertEqual(list(root.glob("*.tar.gz")), [])

    def test_empty_or_short_passphrase_cannot_publish(self):
        with patch.dict(os.environ, {"DEV_BACKUP_PASSPHRASE": "short"}):
            with self.assertRaises(ops.OperationsError):
                ops.pack_and_encrypt("unused", "unused.gpg")

    def test_invalid_passphrase_stops_before_accessing_or_exporting_dev(self):
        with patch.dict(os.environ, {"DEV_BACKUP_PASSPHRASE": "short"}), \
                patch.object(ops, "sql") as sql, patch.object(ops, "command") as command:
            with self.assertRaises(ops.OperationsError):
                ops.backup("unused")
        sql.assert_not_called()
        command.assert_not_called()

    def test_archive_budget_refuses_excess_without_deleting_anything(self):
        with patch.object(ops, "api", return_value={"artifacts": [{"expired": False, "size_in_bytes": ops.MAX_ARTIFACT_STORAGE}]}):
            with self.assertRaises(ops.OperationsError):
                ops.assert_artifact_budget(1)

    def test_failing_commands_do_not_expose_remote_output(self):
        with self.assertRaises(ops.OperationsError) as caught:
            ops.command([sys.executable, "-c", "import sys;print('private password');sys.exit(1)"])
        self.assertEqual(str(caught.exception), "command_failed")

    def test_api_errors_expose_only_provider_and_http_status(self):
        error = ops.urllib.error.HTTPError("https://private.example/secret", 403,
            "private password", {}, io.BytesIO(b"private body"))
        with patch.dict(os.environ, {"SUPABASE_ACCESS_TOKEN": "fixture"}), \
                patch.object(ops.urllib.request, "urlopen", side_effect=error):
            with self.assertRaises(ops.OperationsError) as caught:
                ops.api("/database/query", {"query": "fixture"})
        self.assertEqual(str(caught.exception), "supabase_api_http_403_database")

    def test_query_diagnostic_never_exposes_response_body(self):
        error = ops.urllib.error.HTTPError("https://private.example", 400,
            "private password", {}, io.BytesIO(b'{"message":"ERROR: 23503 private@example.com private payload"}'))
        with patch.dict(os.environ, {"SUPABASE_ACCESS_TOKEN": "fixture"}), \
                patch.object(ops.urllib.request, "urlopen", side_effect=error):
            with self.assertRaises(ops.OperationsError) as caught:
                ops.api("/database/query", {"query": "fixture"})
        self.assertEqual(str(caught.exception), "supabase_api_http_400_database_23503")

    def test_log_window_uses_utc_z_accepted_by_management_api(self):
        with patch.object(ops, "api", return_value={"result": []}) as api, \
                patch.object(ops, "sql"), patch.object(ops, "run_id", return_value="123-1"), \
                patch("builtins.print"):
            ops.collect_logs()
        query = ops.urllib.parse.parse_qs(ops.urllib.parse.urlsplit(api.call_args.args[0]).query)
        start, end = query["iso_timestamp_start"][0], query["iso_timestamp_end"][0]
        self.assertTrue(start.endswith("Z") and end.endswith("Z"))
        self.assertEqual(ops.dt.datetime.fromisoformat(end) - ops.dt.datetime.fromisoformat(start),
                         ops.dt.timedelta(hours=24))

    def test_missing_managed_roles_keep_privileges_without_login_or_replacing_local_admin(self):
        def role(name):
            return dict(rolname=name, rolsuper=False, rolinherit=True, rolcreaterole=False,
                        rolcreatedb=False, rolcanlogin=True, rolreplication=False, rolbypassrls=True)
        sql = drill.missing_roles_sql([role('supabase_admin'), role('realtime"; select secret;--')], {'supabase_admin'})
        self.assertNotIn('supabase_admin', sql)
        self.assertIn('"realtime""; select secret;--" with NOLOGIN', sql)
        self.assertIn('BYPASSRLS', sql)
        self.assertIn('NOSUPERUSER', sql)
        with self.assertRaises(ValueError):
            drill.missing_roles_sql([role('invalid') | {'rolsuper': 'private'}], set())

    def test_restore_refuses_a_different_environment(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp)
            (source / "manifest.json").write_text(json.dumps({"project": "prod", "environment": "production"}))
            with self.assertRaises(ValueError):
                drill.verify_files(source)


if __name__ == "__main__":
    unittest.main()
