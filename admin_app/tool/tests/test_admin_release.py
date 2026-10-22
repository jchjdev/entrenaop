import ftplib
import errno
import json
import os
from pathlib import Path
import sys
import ssl
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import admin_release as release

SHA = "a" * 40
RELEASE = SHA + "-123-1"


class Remote:
    def __init__(self):
        self.files = {
            ".htaccess": b"previous headers",
            "robots.txt": b"previous robots",
            "index.html": b"previous application",
            "build-info.json": json.dumps({"host": release.HOST, "supabaseProject": release.PROJECT,
                                            "environment": "development"}).encode(),
            "default.php": b"Hostinger file to preserve",
        }
        self.writes = []
        self.fail_assets = False

    def cwd(self, name):
        pass

    def mkd(self, name):
        pass

    def retrbinary(self, command, callback):
        callback(self.files[command.removeprefix("RETR ")])

    def storbinary(self, command, data):
        name = command.removeprefix("STOR ")
        if self.fail_assets and name.endswith("main.dart.js"):
            raise ftplib.error_temp("Synthetic transfer failure")
        self.files[name] = data.read()
        self.writes.append(name)

    def rename(self, source, destination):
        self.files[destination] = self.files.pop(source)
        self.writes.append(destination)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.source, self.output, self.deployment = root / "web", root / "release", root / "deployment"
        (self.source / "canvaskit").mkdir(parents=True)
        (self.source / "assets").mkdir()
        self.deployment.mkdir()
        (self.source / "index.html").write_text('<base href="/"><script src="flutter_bootstrap.js" async></script>', encoding="utf-8")
        (self.source / "flutter_bootstrap.js").write_text("/* fixture */ _flutter.loader.load();", encoding="utf-8")
        (self.source / "main.dart.js").write_bytes(b"synthetic application")
        (self.source / "canvaskit/canvaskit.wasm").write_bytes(b"synthetic wasm")
        (self.source / "assets/example.txt").write_bytes(b"synthetic asset")
        (self.deployment / "hostinger-dev.htaccess").write_bytes(b"new headers")
        (self.deployment / "robots.txt").write_bytes(b"User-agent: *\nDisallow: /\n")

    def package(self):
        return release.package_web(self.source, self.output, SHA, RELEASE, self.deployment)

    def test_versioned_assets_keep_root_routes_and_source_untouched(self):
        manifest = self.package()
        self.assertEqual(manifest["mainJsSha256"], release.digest(b"synthetic application"))
        index = (self.output / "index.html").read_text()
        self.assertIn('<base href="/">', index)
        self.assertIn(f'/releases/{RELEASE}/flutter_bootstrap.js', index)
        bootstrap = (self.output / "releases" / RELEASE / "flutter_bootstrap.js").read_text()
        self.assertIn('"assetBase": "/releases/', bootstrap)
        self.assertIn('"canvasKitBaseUrl": "/releases/', bootstrap)
        self.assertEqual((self.source / "flutter_bootstrap.js").read_text(), "/* fixture */ _flutter.loader.load();")

    def test_rejects_sources_and_secrets_before_packaging(self):
        for filename in (".env", "secret.key", "source.dart", "source.map"):
            with self.subTest(filename=filename):
                path = self.source / filename
                path.write_text("fixture")
                with self.assertRaises(ValueError):
                    self.package()
                self.assertFalse(self.output.exists())
                path.unlink()

    def test_rejects_traversal_and_incomplete_build(self):
        with self.assertRaises(ValueError):
            release.package_web(self.source, self.output, SHA, "../../public_html", self.deployment)
        (self.source / "main.dart.js").unlink()
        with self.assertRaises(ValueError):
            self.package()

    def test_unknown_flutter_bootstrap_fails_closed(self):
        (self.source / "flutter_bootstrap.js").write_text("changed bootstrap")
        with self.assertRaises(ValueError):
            self.package()
        self.assertFalse(self.output.exists())

    def test_uploads_all_assets_before_switch_and_preserves_hostinger_files(self):
        self.package()
        ftp = Remote()
        verified = []
        release.publish(ftp, self.output, lambda manifest: verified.append(manifest))
        self.assertEqual(ftp.writes[-1], "index.html")
        self.assertTrue(all(ftp.writes.index(name) < ftp.writes.index("index.html") for name in ftp.writes if name.startswith("releases/")))
        self.assertEqual(ftp.files["default.php"], b"Hostinger file to preserve")
        self.assertEqual(len(verified), 1)

    def test_failed_asset_transfer_does_not_activate_partial_release(self):
        self.package()
        ftp = Remote()
        old = dict(ftp.files)
        ftp.fail_assets = True
        with self.assertRaises(ftplib.error_temp):
            release.publish(ftp, self.output)
        for name in release.ROOT_FILES:
            self.assertEqual(ftp.files[name], old[name])

    def test_failed_https_check_restores_previous_entry_and_configuration(self):
        self.package()
        ftp = Remote()
        old = dict(ftp.files)
        def fail(_):
            raise ValueError("Synthetic verification failure")
        with patch.object(release.time, "sleep"), self.assertRaisesRegex(RuntimeError, "restauradas"):
            release.publish(ftp, self.output, fail)
        for name in release.ROOT_FILES:
            self.assertEqual(ftp.files[name], old[name])
        self.assertEqual(ftp.files["default.php"], old["default.php"])

    def test_wrong_remote_environment_is_rejected_before_any_write(self):
        self.package()
        ftp = Remote()
        ftp.files["build-info.json"] = b'{"environment":"production"}'
        with self.assertRaises(ValueError):
            release.publish(ftp, self.output)
        self.assertEqual(ftp.writes, [])

    def test_https_rejects_a_javascript_hash_mismatch(self):
        manifest = self.package()
        responses = [(json.dumps(manifest).encode(), {}), (b"wrong application", {})]
        with patch.object(release, "https_get", side_effect=responses), self.assertRaisesRegex(ValueError, "SHA-256"):
            release.verify_public(manifest)

    def test_transient_asset_failure_reconnects_before_activating(self):
        self.package()
        first, second = Remote(), Remote()
        first.fail_assets = True
        second.files = first.files
        sessions = []
        for remote in (first, second):
            session = Mock(wraps=remote)
            sessions.append(session)
        publish = release.publish
        def isolated_publish(ftp, package, *, progress):
            return publish(ftp, package, lambda expected: None, progress=progress)
        with patch.dict(os.environ, {"HOSTINGER_ADMIN_FTPS_USER": "fixture", "HOSTINGER_ADMIN_FTPS_PASSWORD": "fixture"}), \
                patch.object(release.ftplib, "FTP_TLS", side_effect=sessions) as factory, \
                patch.object(release, "require_current_main") as current, \
                patch.object(release, "publish", side_effect=isolated_publish), \
                patch.object(release.time, "sleep"), patch("builtins.print"):
            # Las operaciones de sesión no forman parte del almacenamiento ficticio.
            for session in sessions:
                for method in ("connect", "auth", "login", "prot_p", "close"):
                    setattr(session, method, Mock())
            result = release.deploy(self.output)
        self.assertEqual(result["revision"], SHA)
        self.assertEqual(factory.call_count, 2)
        self.assertEqual(current.call_count, 2)
        self.assertNotIn("index.html", first.writes)
        self.assertEqual(second.writes[-1], "index.html")
        for session in sessions:
            session.close.assert_called_once()

    def test_activation_failure_credentials_and_certificate_are_never_retried(self):
        self.package()
        for phase, error in (("activate", OSError(errno.ECONNRESET, "private")),
                             ("restore_previous", OSError("private")),
                             ("authenticate", ftplib.error_perm("530 private")),
                             ("connect", ssl.SSLCertVerificationError("private"))):
            with self.subTest(phase=phase):
                session = Mock()
                def fail(ftp, package, *, progress):
                    progress(phase)
                    raise error
                with patch.dict(os.environ, {"HOSTINGER_ADMIN_FTPS_USER": "fixture", "HOSTINGER_ADMIN_FTPS_PASSWORD": "fixture"}), \
                        patch.object(release.ftplib, "FTP_TLS", return_value=session) as factory, \
                        patch.object(release, "require_current_main"), \
                        patch.object(release, "publish", side_effect=fail), patch("builtins.print"):
                    with self.assertRaises(type(error)):
                        release.deploy(self.output)
                factory.assert_called_once()
                session.close.assert_called_once()

    def test_retry_stops_if_main_advances_and_attempts_are_bounded(self):
        self.package()
        for advance in (False, True):
            with self.subTest(advance=advance), \
                    patch.dict(os.environ, {"HOSTINGER_ADMIN_FTPS_USER": "fixture", "HOSTINGER_ADMIN_FTPS_PASSWORD": "fixture"}), \
                    patch.object(release.ftplib, "FTP_TLS") as factory, \
                    patch.object(release, "require_current_main", side_effect=[None, ValueError("main advanced")] if advance else None), \
                    patch.object(release.time, "sleep"), patch("builtins.print"):
                factory.return_value.connect.side_effect = TimeoutError("private")
                with self.assertRaises(ValueError if advance else TimeoutError):
                    release.deploy(self.output)
                self.assertEqual(factory.call_count, 1 if advance else 3)

    def test_transfer_diagnostics_never_expose_remote_messages(self):
        for error in (OSError(errno.ECONNRESET, "password=private"), ftplib.error_perm("530 private user")):
            diagnostic = release.transfer_diagnostic("connect", error)
            self.assertNotIn("private", diagnostic)
            self.assertIn("connect", diagnostic)


if __name__ == "__main__":
    unittest.main()
