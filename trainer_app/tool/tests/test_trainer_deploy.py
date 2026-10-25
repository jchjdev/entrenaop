"""Regresiones del aislamiento y la activación automática del portal profesional."""
import contextlib
import errno
import ftplib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[3]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

trainer = load("trainer_deploy_adapter", "trainer_app/tool/trainer_release.py")
admin = load("admin_deploy_adapter", "admin_app/tool/admin_release.py")
from static_web_release import package_web

SHA = "a" * 40
RELEASE = SHA + "-123-1"


class Remote:
    def __init__(self, manifest):
        self.files = {"index.html": b"previous entry", ".htaccess": b"previous headers",
                      "robots.txt": b"previous robots", "build-info.json": json.dumps(manifest).encode(),
                      "default.php": b"preserve host file"}
        self.writes = []
        self.credentials = None
        self.closed = 0

    def connect(self, host, port):
        pass

    def auth(self):
        pass

    def login(self, user, password):
        self.credentials = (user, password)

    def prot_p(self):
        pass

    def close(self):
        self.closed += 1

    def cwd(self, name):
        pass

    def mkd(self, name):
        pass

    def retrbinary(self, command, callback):
        callback(self.files[command.removeprefix("RETR ")])

    def storbinary(self, command, data):
        name = command.removeprefix("STOR ")
        self.files[name] = data.read()
        self.writes.append(name)

    def rename(self, source, destination):
        self.files[destination] = self.files.pop(source)
        self.writes.append(destination)


class TrainerDeployTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.source, self.deployment = root / "web", root / "deployment"
        (self.source / "canvaskit").mkdir(parents=True)
        self.deployment.mkdir()
        (self.source / "index.html").write_text('<script src="flutter_bootstrap.js"></script>', encoding="utf-8")
        (self.source / "flutter_bootstrap.js").write_text("_flutter.loader.load();", encoding="utf-8")
        (self.source / "main.dart.js").write_bytes(b"fixture")
        (self.source / "canvaskit/canvaskit.wasm").write_bytes(b"fixture wasm")
        (self.deployment / "hostinger-dev.htaccess").write_bytes(b"fixture headers")
        (self.deployment / "robots.txt").write_bytes(b"fixture robots")
        self.environment = {"HOSTINGER_TRAINER_FTPS_USER": "trainer-private-user",
                            "HOSTINGER_TRAINER_FTPS_PASSWORD": "trainer-private-password",
                            "HOSTINGER_ADMIN_FTPS_USER": "admin-private-user",
                            "HOSTINGER_ADMIN_FTPS_PASSWORD": "admin-private-password"}

    def package(self, host=trainer.HOST):
        output = Path(self.tmp.name) / host
        manifest = package_web(self.source, output, SHA, RELEASE, self.deployment,
                               host=host, project=trainer.PROJECT)
        return output, manifest

    def test_each_adapter_rejects_the_other_local_package_before_any_network(self):
        for adapter, other in ((trainer, admin), (admin, trainer)):
            package, _ = self.package(other.HOST)
            with self.subTest(adapter=adapter.HOST), patch.dict(os.environ, self.environment), \
                    patch.object(adapter, "require_current_main") as current, \
                    patch.object(adapter, "IPv4FTP_TLS") as connection, self.assertRaises(ValueError):
                adapter.deploy(package)
            current.assert_not_called()
            connection.assert_not_called()

    def test_each_adapter_rejects_the_other_remote_root_before_writing(self):
        for adapter, other in ((trainer, admin), (admin, trainer)):
            package, _ = self.package(adapter.HOST)
            manifest = {"host": other.HOST, "supabaseProject": trainer.PROJECT,
                        "environment": "development", "sourceTreeDirty": False,
                        "assetBase": "/releases/" + RELEASE + "/"}
            remote = Remote(manifest)
            with self.subTest(adapter=adapter.HOST), self.assertRaises(ValueError):
                adapter.publish(remote, package, verifier=lambda expected: None)
            self.assertEqual(remote.writes, [])

    def test_production_or_dirty_package_is_rejected_before_network(self):
        package, manifest = self.package()
        for change in ({"environment": "production"}, {"supabaseProject": "production"},
                       {"sourceTreeDirty": True}, {"assetBase": "/releases/../../admin/"}):
            (package / "build-info.json").write_text(json.dumps({**manifest, **change}), encoding="utf-8")
            with self.subTest(change=change), patch.dict(os.environ, self.environment), \
                    patch.object(trainer, "require_current_main") as current, \
                    patch.object(trainer, "IPv4FTP_TLS") as connection, self.assertRaises(ValueError):
                trainer.deploy(package)
            current.assert_not_called()
            connection.assert_not_called()

    def test_missing_trainer_secret_never_falls_back_to_admin_credentials(self):
        package, _ = self.package()
        with patch.dict(os.environ, {key: value for key, value in self.environment.items() if "ADMIN" in key}, clear=True), \
                patch.object(trainer, "IPv4FTP_TLS") as connection, self.assertRaisesRegex(ValueError, "secretos"):
            trainer.deploy(package)
        connection.assert_not_called()

    def test_main_advancing_stops_before_connection_or_login(self):
        package, _ = self.package()
        with patch.dict(os.environ, self.environment), \
                patch.object(trainer, "require_current_main", side_effect=ValueError("main advanced")) as current, \
                patch.object(trainer, "IPv4FTP_TLS") as connection, self.assertRaisesRegex(ValueError, "main advanced"):
            trainer.deploy(package)
        current.assert_called_once_with(SHA)
        connection.assert_not_called()

    def test_success_uses_only_own_credentials_and_activates_entry_last(self):
        package, manifest = self.package()
        remote = Remote(manifest)
        publish = trainer.publish
        def checked_publish(ftp, package, *, progress):
            return publish(ftp, package, verifier=lambda expected: None, progress=progress)
        with patch.dict(os.environ, self.environment), \
                patch.object(trainer, "require_current_main") as current, \
                patch.object(trainer, "IPv4FTP_TLS", return_value=remote), \
                patch.object(trainer, "publish", side_effect=checked_publish):
            result = trainer.deploy(package)
        self.assertEqual(result["revision"], SHA)
        self.assertEqual(remote.credentials, ("trainer-private-user", "trainer-private-password"))
        current.assert_called_once_with(SHA)
        self.assertEqual(remote.writes[-1], "index.html")
        self.assertEqual(remote.closed, 1)
        self.assertEqual(remote.files["default.php"], b"preserve host file")

    def test_failed_https_restores_previous_entry_without_deleting_history(self):
        package, manifest = self.package()
        remote = Remote(manifest)
        previous = dict(remote.files)
        def fail(expected):
            raise ValueError("verification failed")
        with patch.object(trainer.shared_deploy.time, "sleep"), self.assertRaisesRegex(RuntimeError, "restauradas"):
            trainer.publish(remote, package, verifier=fail)
        for name in trainer.shared_deploy.ROOT_FILES:
            self.assertEqual(remote.files[name], previous[name])
        self.assertIn("releases/" + RELEASE + "/main.dart.js", remote.files)
        self.assertEqual(remote.files["default.php"], previous["default.php"])

    def test_transfer_logs_never_include_remote_text_or_credentials(self):
        package, _ = self.package()
        remote = Mock()
        remote.connect.side_effect = OSError(errno.ECONNRESET, "trainer-private-password admin-private-user")
        output = io.StringIO()
        with patch.dict(os.environ, self.environment), \
                patch.object(trainer, "require_current_main"), \
                patch.object(trainer, "IPv4FTP_TLS", return_value=remote), \
                patch.object(trainer.shared_deploy.time, "sleep"), contextlib.redirect_stderr(output), \
                self.assertRaises(OSError):
            trainer.deploy(package)
        self.assertIn("Transferencia Trainer Dev: connect_ipv4", output.getvalue())
        self.assertNotIn("private", output.getvalue())
        self.assertEqual(remote.close.call_count, 3)
        remote.login.assert_not_called()

    def test_admin_packaging_refuses_dirty_shared_deploy_sources(self):
        with patch.object(sys, "argv", ["admin_release.py", "package", "--revision", SHA]), \
                patch.object(admin.subprocess, "check_output", return_value=" M tools/static_web_deploy.py") as git, \
                patch.object(admin, "package_web") as package, self.assertRaisesRegex(ValueError, "cambios pendientes"):
            admin.main()
        self.assertIn("tools/static_web_deploy.py", git.call_args.args[0])
        self.assertIn("tools/static_web_release.py", git.call_args.args[0])
        package.assert_not_called()

    def test_workflow_never_receives_admin_or_supabase_credentials(self):
        workflow = (ROOT / ".github/workflows/trainer-dev.yml").read_text(encoding="utf-8")
        self.assertNotIn("HOSTINGER_ADMIN_", workflow)
        self.assertNotIn("SERVICE_ROLE", workflow)
        self.assertIn("environment:\n      name: trainer-dev", workflow)
        self.assertIn("github.ref == 'refs/heads/main' && vars.TRAINER_DEV_DEPLOY_ENABLED == 'true'", workflow)
        self.assertIn("HOSTINGER_TRAINER_FTPS_USER: ${{ secrets.HOSTINGER_TRAINER_FTPS_USER }}", workflow)
        self.assertIn("HOSTINGER_TRAINER_FTPS_PASSWORD: ${{ secrets.HOSTINGER_TRAINER_FTPS_PASSWORD }}", workflow)
        self.assertIn("SUPABASE_URL=https://sxbxfjqgoddzhtcyhalw.supabase.co", workflow)


if __name__ == "__main__":
    unittest.main()
