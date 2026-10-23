import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('dv.sh').resolve()


class TeamInitTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dv-team-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home with spaces'
        self.home.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'calls.jsonl'
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:/usr/bin:/bin', CALLS=str(self.log))
        mock = self.bin / 'mock'
        mock.write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps([name, sys.argv[1:], os.getcwd()]) + '\\n')
if name == 'claude' and sys.argv[1:] == ['plugin', 'list', '--json']:
    print(json.dumps([{'id':'sample@test','scope':'project','projectPath':os.environ['HOME']}]))
if name == 'git':
    args = sys.argv[3:]
    if args == ['rev-parse', '--show-toplevel']:
        print(os.environ['REPO_ROOT'])
    elif args == ['remote', 'get-url', 'origin']:
        print(os.environ.get('REPO_URL', 'https://github.com/ksc2320/dv-team.git'))
    elif args == ['symbolic-ref', '--short', '-q', 'HEAD']:
        print('main')
    elif args == ['status', '--porcelain']:
        print(os.environ.get('REPO_STATUS', ''), end='')
    elif 'pull' in args and os.environ.get('UPDATE_SCRIPT'):
        with open(os.environ['UPDATE_SCRIPT'], 'a') as stream:
            stream.write('\\n_dvt_work() { echo NEW_CODE_EXECUTED; }\\n')
raise SystemExit(7 if name == os.environ.get('FAIL_TOOL') else 0)
''')
        mock.chmod(0o755)
        for tool in ('sudo', 'apt-get', 'snap', 'claude', 'codex', 'gemini', 'npm'):
            (self.bin / tool).symlink_to(mock)
        self.mock_repo()

    def run_dv(self, *args):
        return subprocess.run(['/bin/bash', str(SCRIPT), *args], env=self.env, text=True, capture_output=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_dry_run_executes_no_update(self):
        result = self.run_dv('init', '--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('변경 없음', result.stdout)
        self.assertTrue(all(name == 'git' and 'pull' not in args for name, args, cwd in self.calls()))

    def test_install_is_repeatable_and_preserves_existing_dv(self):
        for _ in range(2):
            result = self.run_dv('install')
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / '.bash_functions').read_text().count('source'), 1)
        self.assertEqual((self.home / '.bashrc').read_text().count('source'), 1)
        result = subprocess.run(['/bin/bash', '-c', 'alias dv="echo original"; source "$HOME/.bash_functions"; alias dv; alias dvteam'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("alias dv='echo original'", result.stdout)
        self.assertIn("alias dvteam='_dvt_main'", result.stdout)
        self.assertEqual(self.calls(), [])

    def test_system_ai_and_project_plugin(self):
        result = self.run_dv('init')
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.calls()
        self.assertIn(['sudo', ['apt-get', 'update'], str(Path.cwd())], commands)
        self.assertTrue(any(name == 'codex' and args == ['update'] for name, args, cwd in commands))
        self.assertIn(['claude', ['plugin', 'update', 'sample@test', '-s', 'project'], str(self.home)], commands)

    def test_existing_function_is_preserved(self):
        result = subprocess.run(['/bin/bash', '-c', 'dv() { echo original; }; source "$1"; dv; alias dvteam', '_', str(SCRIPT)], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.startswith('original\n'))
        self.assertEqual(self.calls(), [])

    def test_failed_update_returns_failure_and_continues(self):
        self.env['FAIL_TOOL'] = 'claude'
        result = self.run_dv('ai')
        self.assertEqual(result.returncode, 1)
        self.assertIn('일부 업데이트 실패', result.stderr)
        self.assertTrue(any(name == 'codex' for name, args, cwd in self.calls()))

    def test_failed_apt_update_does_not_upgrade(self):
        self.env['FAIL_TOOL'] = 'sudo'
        self.assertEqual(self.run_dv('init').returncode, 1)
        self.assertFalse(any('upgrade' in args for name, args, cwd in self.calls()))

    def test_bad_option_does_not_run(self):
        self.assertEqual(self.run_dv('init', '--unknown').returncode, 2)
        self.assertEqual(self.calls(), [])

    def mock_repo(self):
        if not (self.bin / 'git').exists():
            (self.bin / 'git').symlink_to(self.bin / 'mock')
        self.env['REPO_ROOT'] = str(SCRIPT.parent)

    def test_self_update_and_reload(self):
        self.mock_repo()
        result = self.run_dv('update')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('적용 완료', result.stdout)
        self.assertTrue(any(args[-4:] == ['pull', '--ff-only', 'origin', 'main'] for name, args, cwd in self.calls()))

    def test_self_update_dry_run_does_not_pull(self):
        self.mock_repo()
        self.assertEqual(self.run_dv('update', '--dry-run').returncode, 0)
        self.assertFalse(any('pull' in args for name, args, cwd in self.calls()))

    def test_self_update_preserves_local_changes(self):
        self.mock_repo()
        self.env['REPO_STATUS'] = ' M dv.sh\n'
        self.assertEqual(self.run_dv('update').returncode, 1)
        self.assertFalse(any('pull' in args for name, args, cwd in self.calls()))

    def test_self_update_rejects_other_remote(self):
        self.mock_repo()
        self.env['REPO_URL'] = 'https://github.com/example/other.git'
        self.assertEqual(self.run_dv('update').returncode, 1)
        self.assertFalse(any('pull' in args for name, args, cwd in self.calls()))

    def test_self_update_failure_is_reported(self):
        self.mock_repo()
        mock = self.bin / 'mock'
        mock.write_text(mock.read_text().replace("raise SystemExit(7 if", "if name == 'git' and 'pull' in sys.argv: raise SystemExit(7)\nraise SystemExit(7 if"))
        result = self.run_dv('update')
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('적용 완료', result.stdout)

    def test_init_updates_before_system_tools(self):
        result = self.run_dv('init')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        pull = next(i for i, (name, args, cwd) in enumerate(calls) if name == 'git' and 'pull' in args)
        system = next(i for i, (name, args, cwd) in enumerate(calls) if name == 'sudo')
        self.assertLess(pull, system)
        self.assertEqual(sum(name == 'git' and 'pull' in args for name, args, cwd in calls), 1)

    def test_init_stops_when_self_update_fails(self):
        self.env['FAIL_TOOL'] = 'git'
        self.assertEqual(self.run_dv('init').returncode, 1)
        self.assertTrue(all(name == 'git' for name, args, cwd in self.calls()))

    def test_init_stops_for_local_changes(self):
        self.env['REPO_STATUS'] = ' M dv.sh\n'
        self.assertEqual(self.run_dv('init').returncode, 1)
        self.assertTrue(all(name == 'git' and 'pull' not in args for name, args, cwd in self.calls()))

    def test_updated_code_runs_in_same_invocation(self):
        script = self.root / 'dv.sh'
        script.write_text(SCRIPT.read_text())
        self.env['REPO_ROOT'] = str(script.parent)
        self.env['UPDATE_SCRIPT'] = str(script)
        result = subprocess.run(['/bin/bash', str(script), 'init'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('NEW_CODE_EXECUTED', result.stdout)
        self.assertTrue(all(name == 'git' for name, args, cwd in self.calls()))


if __name__ == '__main__':
    unittest.main()
