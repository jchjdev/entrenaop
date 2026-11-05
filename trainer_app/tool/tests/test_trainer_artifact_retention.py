import sys
import json
import os
from pathlib import Path
import unittest
import urllib.error
import importlib.util
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import trainer_artifact_retention as retention


def artifact(number, **changes):
    sha = format(number, '040x')
    return dict(id=number, name='trainer-dev-' + sha, expired=False, size_in_bytes=100,
                created_at=f'2026-10-{number:02d}T12:00:00Z',
                workflow_run=dict(head_sha=sha, head_branch='main')) | changes


def valid_manifest(revision, **changes):
    return dict(host='trainer.entrenaop.es',supabaseProject='sxbxfjqgoddzhtcyhalw',
                environment='development',revision=revision,sourceTreeDirty=False,
                assetBase='/releases/'+revision+'-123-1/') | changes


class RetentionTests(unittest.TestCase):
    def test_workflow_retention_requires_verified_deploy_and_isolated_permissions(self):
        workflow=(Path(__file__).resolve().parents[3]/'.github/workflows/trainer-dev.yml').read_text(encoding='utf-8')
        job=workflow.split('  retain-packages:',1)[1]
        self.assertNotIn("TRAINER_DEV_RETENTION_ENABLED",job)
        self.assertIn("github.ref == 'refs/heads/main'",job)
        self.assertIn('needs: deploy',job)
        self.assertIn('actions: write',job)
        self.assertIn('GITHUB_TOKEN: ${{ github.token }}',job)
        self.assertNotIn('HOSTINGER_',job)
        self.assertNotIn('SUPABASE',job)
        self.assertNotIn('actions: write',workflow.split('  retain-packages:',1)[0])

    def test_admin_and_trainer_compiled_packages_are_isolated_both_ways(self):
        admin_tools = Path(__file__).resolve().parents[3] / 'admin_app/tool'
        sys.path.insert(0, str(admin_tools))
        try:
            spec = importlib.util.spec_from_file_location('_admin_retention_isolation', admin_tools/'admin_artifact_retention.py')
            admin = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(admin)
        finally:
            sys.path.remove(str(admin_tools))
        trainers = [artifact(i) for i in range(1, 11)]
        admins = [artifact(i+20, name='admin-dev-'+format(i+20,'040x')) for i in range(1, 11)]
        rows = trainers+admins
        kept, removed = retention.plan(rows, format(10,'040x'))
        self.assertEqual({r['id'] for r in removed},{1,2,3,4,5})
        self.assertTrue(all(r['name'].startswith('trainer-dev-') for r in kept+removed))
        admin_kept, admin_removed = admin.plan(rows, format(30,'040x'))
        self.assertTrue(all(r['name'].startswith('admin-dev-') for r in admin_kept+admin_removed))
        self.assertFalse({r['id'] for r in admin_kept+admin_removed}&{r['id'] for r in trainers})

    def test_rejects_other_domains_projects_dirty_sources_or_assets_before_inventory(self):
        revision=format(10,'040x')
        for changes in [dict(host='admin.entrenaop.es'),dict(host='entrenaop.es'),
                        dict(supabaseProject='other'),dict(sourceTreeDirty=True),
                        dict(environment='production'),
                        dict(assetBase='/releases/'+format(9,'040x')+'-123-1/')]:
            with self.subTest(changes=changes), patch.object(sys,'argv',['retention','--revision',revision]), \
                    patch.object(retention,'fetch',return_value=(json.dumps(valid_manifest(revision,**changes)).encode(),{})), \
                    patch.object(retention,'inventory') as inventory, patch.object(retention,'api') as api:
                with self.assertRaises(ValueError): retention.main()
                inventory.assert_not_called()
                api.assert_not_called()

    def test_publication_change_between_candidates_stops_before_another_delete(self):
        revision=format(10,'040x')
        manifests=[valid_manifest(revision),valid_manifest(revision),valid_manifest(format(9,'040x'))]
        rows=[artifact(i) for i in range(1,11)]
        calls=[]
        def api(path,method='GET'):
            calls.append((path,method))
            return artifact(int(path.rsplit('/',1)[1])) if method=='GET' else None
        settings=dict(GITHUB_REPOSITORY=retention.REPO,GITHUB_REF='refs/heads/main',GITHUB_TOKEN='fixture',GITHUB_SHA=revision)
        with patch.dict(os.environ,settings,clear=True),patch.object(sys,'argv',['retention','--apply']), \
                patch.object(retention,'fetch',side_effect=[(json.dumps(x).encode(),{}) for x in manifests]), \
                patch.object(retention,'inventory',return_value=rows),patch.object(retention,'api',side_effect=api),patch('builtins.print'):
            with self.assertRaisesRegex(ValueError,'^published_revision_changed$'): retention.main()
        self.assertEqual(calls,[('/actions/artifacts/5','GET'),('/actions/artifacts/5','DELETE'),('/actions/artifacts/4','GET')])

    def test_inventory_is_bounded_and_reads_can_work_without_credentials(self):
        with patch.dict(os.environ,{},clear=True),patch.object(retention,'api',return_value={'artifacts':[artifact(1)]*100}) as api:
            with self.assertRaisesRegex(ValueError,'^artifact_inventory_limit$'): retention.inventory()
            self.assertEqual(api.call_count,20)
        with patch.dict(os.environ,{},clear=True),patch.object(sys,'argv',['retention','--revision',format(10,'040x')]), \
                patch.object(retention,'fetch',return_value=(json.dumps(valid_manifest(format(10,'040x'))).encode(),{})), \
                patch.object(retention,'inventory',return_value=[artifact(i) for i in range(1,11)]), \
                patch.object(retention,'api') as api,patch('builtins.print'):
            retention.main()
            api.assert_not_called()

    def test_transient_reads_retry_with_a_bound_and_preserve_the_result(self):
        for error in [urllib.error.HTTPError('https://private.invalid/secret',503,'secret',{},None),
                      urllib.error.HTTPError('https://private.invalid/secret',429,'secret',{},None),
                      urllib.error.URLError('credential=secret'), TimeoutError('secret')]:
            with self.subTest(error=type(error).__name__), patch.object(retention.time,'sleep') as pause:
                from unittest.mock import Mock
                action=Mock(side_effect=[error,{'artifacts':[]}])
                self.assertEqual(retention.read_with_retry('github',action),{'artifacts':[]})
                self.assertEqual(action.call_count,2)
                pause.assert_called_once_with(1)

    def test_permanent_read_failure_is_immediate_and_diagnostic_contains_no_remote_text(self):
        from unittest.mock import Mock
        for status in (401,403,404):
            with self.subTest(status=status), patch.object(retention.time,'sleep') as pause:
                action=Mock(side_effect=urllib.error.HTTPError('https://private.invalid/secret',status,'token=secret',{},None))
                with self.assertRaisesRegex(ValueError,'^retention_read_failed:github:http_'+str(status)+'$'):
                    retention.read_with_retry('github',action)
                self.assertEqual(action.call_count,1)
                pause.assert_not_called()

    def test_repeated_transport_failure_stops_after_three_reads(self):
        from unittest.mock import Mock, call
        with patch.object(retention.time,'sleep') as pause:
            action=Mock(side_effect=urllib.error.URLError('secret'))
            with self.assertRaisesRegex(ValueError,'^retention_read_failed:trainer_manifest:transport$'):
                retention.read_with_retry('trainer_manifest',action)
            self.assertEqual(action.call_count,3)
            self.assertEqual(pause.call_args_list,[call(1),call(2)])

    def test_uncertain_delete_is_never_retried(self):
        with patch.object(retention.urllib.request,'urlopen',side_effect=urllib.error.HTTPError(
                'https://private.invalid/secret',503,'secret',{},None)) as request, \
                patch.object(retention.time,'sleep') as pause:
            with self.assertRaisesRegex(ValueError,'^retention_write_failed:github:http_503$'):
                retention.api('/actions/artifacts/1',method='DELETE')
            self.assertEqual(request.call_count,1)
            pause.assert_not_called()

    def test_retains_latest_five_and_the_online_revision_even_when_older(self):
        rows = [artifact(i) for i in range(1, 11)]
        kept, removed = retention.plan(rows, format(1, '040x'))
        self.assertEqual({r['id'] for r in kept}, {1, 6, 7, 8, 9, 10})
        self.assertEqual({r['id'] for r in removed}, {2, 3, 4, 5})

    def test_never_selects_backups_unknown_names_other_branches_or_expired_artifacts(self):
        excluded = [artifact(11, name='entrenaop-dev-123-1'), artifact(12, name='trainer-dev-private-data'),
                    artifact(13, expired=True), artifact(14, workflow_run={'head_sha': format(14, '040x'), 'head_branch': 'other'}),
                    artifact(15, workflow_run={'head_sha': format(99, '040x'), 'head_branch': 'main'})]
        kept, removed = retention.plan([artifact(i) for i in range(1, 11)] + excluded, format(10, '040x'))
        self.assertEqual({r['id'] for r in removed}, {1, 2, 3, 4, 5})
        self.assertEqual(len(kept), 5)

    def test_refuses_cleanup_if_the_published_package_is_missing(self):
        with self.assertRaises(ValueError):
            retention.plan([artifact(1)], format(2, '040x'))

    def test_mutation_refuses_another_repository_branch_or_revision_before_any_request(self):
        settings = dict(GITHUB_REPOSITORY=retention.REPO, GITHUB_REF='refs/heads/main',
                        GITHUB_TOKEN='fixture', GITHUB_SHA=format(10, '040x'))
        for key, value in [('GITHUB_REPOSITORY', 'other/repo'), ('GITHUB_REF', 'refs/heads/other')]:
            with self.subTest(key=key), patch.dict(os.environ, settings | {key: value}), \
                    patch.object(sys, 'argv', ['retention', '--apply']), patch.object(retention, 'fetch') as request:
                with self.assertRaises(ValueError):
                    retention.main()
                request.assert_not_called()

    def test_default_plan_never_mutates_and_production_manifest_is_rejected(self):
        manifest = valid_manifest(format(10, '040x'))
        for environment in ['development', 'production']:
            with self.subTest(environment=environment), \
                    patch.object(sys, 'argv', ['retention', '--revision', format(10, '040x')]), \
                    patch.object(retention, 'fetch', return_value=(json.dumps(manifest | {'environment': environment}).encode(), {})), \
                    patch.object(retention, 'inventory', return_value=[artifact(i) for i in range(1, 11)]) as inventory, \
                    patch.object(retention, 'api') as api, patch('builtins.print'):
                if environment == 'production':
                    with self.assertRaises(ValueError):
                        retention.main()
                    inventory.assert_not_called()
                else:
                    retention.main()
                api.assert_not_called()

    def test_apply_rechecks_each_selected_identity_before_deleting_only_old_packages(self):
        revision = format(10, '040x')
        manifest = valid_manifest(revision)
        rows = [artifact(i) for i in range(1, 11)]
        settings = dict(GITHUB_REPOSITORY=retention.REPO, GITHUB_REF='refs/heads/main',
                        GITHUB_TOKEN='fixture', GITHUB_SHA=revision)
        for changed in [False, True]:
            calls = []

            def api(path, method='GET'):
                calls.append((path, method))
                if method == 'GET':
                    return artifact(int(path.rsplit('/', 1)[1]), **({'name': 'entrenaop-dev-copy'} if changed else {}))

            with self.subTest(changed=changed), patch.dict(os.environ, settings), \
                    patch.object(sys, 'argv', ['retention', '--apply']), \
                    patch.object(retention, 'fetch', return_value=(json.dumps(manifest).encode(), {})), \
                    patch.object(retention, 'inventory', return_value=rows), \
                    patch.object(retention, 'api', side_effect=api), patch('builtins.print'):
                if changed:
                    with self.assertRaisesRegex(ValueError, 'artifact_identity_changed'):
                        retention.main()
                    self.assertFalse(any(method == 'DELETE' for _, method in calls))
                else:
                    retention.main()
                    self.assertEqual(calls, [(f'/actions/artifacts/{i}', method)
                                             for i in range(5, 0, -1) for method in ['GET', 'DELETE']])


if __name__ == '__main__':
    unittest.main()
