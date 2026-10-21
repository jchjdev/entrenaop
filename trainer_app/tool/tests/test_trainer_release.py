import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("trainer_release",ROOT/"trainer_app/tool/trainer_release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
sys.path.insert(0,str(ROOT/"tools"))
from static_web_release import package_web

SHA = "a" * 40
RELEASE = SHA + "-123-1"

class TrainerReleaseTests(unittest.TestCase):
    def test_local_file_read_is_allowed_without_allowing_blob_scripts(self):
        import re
        for portal in ('trainer_app', 'admin_app'):
            with self.subTest(portal=portal):
                config = (ROOT / portal / 'deployment/hostinger-dev.htaccess').read_text()
                csp = re.search(r'Content-Security-Policy "([^"]+)"', config).group(1)
                directives = {p.strip().split()[0]: p.strip().split()[1:]
                              for p in csp.split(';') if p.strip()}
                self.assertIn('blob:', directives['connect-src'])
                self.assertNotIn('blob:', directives['script-src'])
                self.assertNotIn("'unsafe-eval'", directives['script-src'])
                self.assertEqual(directives['frame-ancestors'], ["'none'"])

    def test_scope_checks_every_local_dependency_without_unconsumed_packages(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            config = root / 'trainer_app/.dart_tool/package_config.json'
            config.parent.mkdir(parents=True)
            config.write_text(json.dumps({'packages': [
                {'name': 'trainer', 'rootUri': '../'},
                {'name': 'shared', 'rootUri': '../../packages/shared/'},
                {'name': 'external', 'rootUri': 'https://example.invalid/package/'},
            ]}))
            with patch.object(release, 'ROOT', root):
                scope = release.source_scope()
            self.assertIn('packages/shared', scope)
            self.assertIn('trainer_app', scope)
            self.assertNotIn('packages', scope)
            self.assertNotIn('packages/device_activity_core', scope)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.source,self.output,self.deployment = root/"web",root/"package",root/"deployment"
        (self.source/"canvaskit").mkdir(parents=True)
        self.deployment.mkdir()
        (self.source/"index.html").write_text('<base href="/"><script src="flutter_bootstrap.js"></script>',encoding="utf-8")
        (self.source/"flutter_bootstrap.js").write_text("_flutter.loader.load();",encoding="utf-8")
        (self.source/"main.dart.js").write_bytes(b"fixture")
        (self.source/"canvaskit/canvaskit.wasm").write_bytes(b"fixture wasm")
        (self.deployment/"hostinger-dev.htaccess").write_text("fixture",encoding="utf-8")
        (self.deployment/"robots.txt").write_text("fixture",encoding="utf-8")

    def package(self,host=release.HOST,project=release.PROJECT):
        return package_web(self.source,self.output,SHA,RELEASE,self.deployment,host=host,project=project)

    def test_professional_package_uses_own_host_and_versioned_assets(self):
        manifest = self.package()
        release.identity(manifest)
        self.assertEqual(manifest["host"],"trainer.entrenaop.es")
        self.assertIn("/releases/"+RELEASE+"/flutter_bootstrap.js",(self.output/"index.html").read_text())
        archive = self.output.with_suffix(".zip")
        self.assertEqual(len(release.create_archive(self.output,archive)),64)
        import zipfile
        with zipfile.ZipFile(archive) as data:
            self.assertIn(".htaccess",data.namelist())
            self.assertIn("build-info.json",data.namelist())
            self.assertNotIn("pubspec.yaml",data.namelist())

    def test_target_or_production_project_is_rejected(self):
        for host,project in [("entrenaop.es",release.PROJECT),(release.HOST,"production")]:
            with self.subTest(host=host,project=project),self.assertRaises(ValueError):
                self.package(host,project)
        self.assertFalse(self.output.exists())

    def test_admin_manifest_cannot_be_used_as_professional_package(self):
        self.package(host="admin.entrenaop.es")
        with self.assertRaises(ValueError):
            release.create_archive(self.output,self.output.with_suffix(".zip"))

    def test_hash_mismatch_never_accredits_publication(self):
        manifest = self.package()
        with patch.object(release,"fetch",side_effect=[(json.dumps(manifest).encode(),{}),(b"corrupt",{})]):
            with self.assertRaisesRegex(ValueError,"SHA-256"):
                release.verify(manifest)

    def test_destination_does_not_redirect_to_admin(self):
        config=(ROOT/"trainer_app/deployment/hostinger-dev.htaccess").read_text()
        self.assertIn("https://trainer.entrenaop.es",config)
        self.assertNotIn("admin.entrenaop",config)
        self.assertIn("sxbxfjqgoddzhtcyhalw",config)

if __name__ == "__main__":
    unittest.main()
