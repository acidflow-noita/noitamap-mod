"""Exercise the compiled Windows installer only in disposable game directories.

The release workflow supplies NOITAMAP_TEST_INSTALLER and NOITAMAP_TEST_ISCC.
Linux checks skip this suite; a private Wine prefix can also run the same cases.
"""
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
INSTALLER = os.environ.get('NOITAMAP_TEST_INSTALLER')
ISCC = os.environ.get('NOITAMAP_TEST_ISCC')
WINE = os.environ.get('NOITAMAP_TEST_WINE')


def windows_path(path):
    path = str(pathlib.Path(path).resolve())
    return 'Z:' + path.replace('/', '\\') if WINE else path


def run_windows(program, *args):
    command = ([WINE, windows_path(program)] if WINE else [str(program)]) + list(args)
    return subprocess.run(command, capture_output=True, text=True, timeout=90)


def files_below(root):
    return {p.relative_to(root).as_posix(): p.read_bytes()
            for p in root.rglob('*') if p.is_file()}


@unittest.skipUnless(INSTALLER and ISCC and (os.name == 'nt' or WINE),
                     'Requires a compiled installer and Windows or isolated Wine')
class WindowsInstallerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Never overwrite a user's installed uninstaller or its registration.
        if WINE:
            prefix = os.environ.get('WINEPREFIX')
            if not prefix:
                raise RuntimeError('Use an explicit, disposable WINEPREFIX')
            cls.uninstall_roots = [p / 'AppData/Local/Programs'
                                   for p in pathlib.Path(prefix).glob('drive_c/users/*')]
        else:
            import winreg
            key = r'Software\Microsoft\Windows\CurrentVersion\Uninstall\{7E1FBF3E-9C21-4E7B-A2D0-5B6A44C0FBAF}_is1'
            for hive in [winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE]:
                for view in [winreg.KEY_WOW64_32KEY, winreg.KEY_WOW64_64KEY]:
                    try:
                        with winreg.OpenKey(hive, key, 0, winreg.KEY_READ | view):
                            raise RuntimeError('Run installer tests on a clean runner, not an existing installation')
                    except FileNotFoundError:
                        pass
            cls.uninstall_roots = [pathlib.Path(os.environ['LOCALAPPDATA']) / 'Programs']
        if any((p / 'Noitamap Mod').exists() for p in cls.uninstall_roots):
            raise RuntimeError('Refusing to replace an existing Noitamap uninstaller')
        cls.temporary = tempfile.TemporaryDirectory(prefix='noitamap-windows-tests-')
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.work = pathlib.Path(cls.temporary.name)
        cls.addClassCleanup(cls.uninstall)
        # Compile a failure-injected COPY, never test switches in the release.
        source = cls.work / 'failing-source'
        shutil.copytree(ROOT / 'installer', source / 'installer', ignore=shutil.ignore_patterns('out'))
        shutil.copytree(ROOT / 'noitamap', source / 'noitamap')
        shutil.copy2(ROOT / 'LICENSE', source / 'LICENSE')
        script = source / 'installer/noitamap-mod.iss'
        script.write_text(script.read_text(encoding='utf8').replace(
            'Flags: recursesubdirs ignoreversion',
            'Flags: recursesubdirs ignoreversion; AfterInstall: FailTestInstall'), encoding='utf8')
        with script.open('a', encoding='utf8') as output:
            output.write('''
[Code]
procedure FailTestInstall;
begin
  // Turn the next file's destination into a directory: a real copy error,
  // unlike script callback exceptions which Inno can log and continue past.
  if not FileExists(ExpandConstant('{app}\\mod.xml')) then
  begin
    ForceDirectories(ExpandConstant('{app}\\mod.xml'));
    Log('Injected copy failure for rollback regression test');
  end;
end;
''')
            if WINE:
                # The local runtime executes a 64-bit Setup stub. Windows CI
                # exercises the unmodified release architecture instead.
                output.write('\n[Setup]\nSetupArchitecture=x64\n')
        compiled = run_windows(ISCC, windows_path(script), '/DAppVer=0.0.0-rollback-test')
        if compiled.returncode:
            raise RuntimeError(compiled.stdout + compiled.stderr)
        cls.failing_installer = source / 'installer/out/noitamap-mod-installer-0.0.0-rollback-test.exe'
        if not cls.failing_installer.is_file():
            raise RuntimeError('Failure-test installer was not produced')

    @classmethod
    def uninstall(cls):
        for root in cls.uninstall_roots:
            for executable in (root / 'Noitamap Mod').glob('unins*.exe'):
                result = run_windows(executable, '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
                if result.returncode:
                    raise RuntimeError('Test uninstaller failed: ' + result.stdout + result.stderr)

    def setUp(self):
        self.game = self.work / self._testMethodName / "Bob's Noita game"
        self.game.mkdir(parents=True)
        (self.game / 'noita.exe').write_bytes(b'fake game; never execute')
        self.target = self.game / 'mods/noitamap'
        other = self.game / 'mods/another-mod'
        other.mkdir(parents=True)
        (other / 'keep.lua').write_bytes(b'leave other mods alone')
        self.outside = self.game / 'save00'
        self.outside.mkdir()
        (self.outside / 'keep').write_bytes(b'leave saves alone')

    def invoke(self, *, target=None, installer=None, success=True):
        log = self.game / 'setup.log'
        result = run_windows(installer or INSTALLER, '/SP-', '/VERYSILENT',
                             '/SUPPRESSMSGBOXES', '/NORESTART', '/NOCLOSEAPPLICATIONS',
                             '/DIR=' + windows_path(target or self.target),
                             '/LOG=' + windows_path(log))
        details = result.stdout + result.stderr
        self.assertTrue(log.is_file(), 'Setup did not reach initialization: ' + details)
        if log.exists():
            details += log.read_text(encoding='utf8', errors='replace')
        if success:
            self.assertEqual(result.returncode, 0, details)
        else:
            self.assertNotEqual(result.returncode, 0, details)
        self.assertEqual((self.game / 'noita.exe').read_bytes(), b'fake game; never execute')
        self.assertEqual((self.game / 'mods/another-mod/keep.lua').read_bytes(), b'leave other mods alone')
        self.assertEqual((self.outside / 'keep').read_bytes(), b'leave saves alone')
        return details

    def old_mod(self):
        shutil.copytree(ROOT / 'noitamap', self.target)
        (self.target / 'init.lua').write_bytes(b'old version')
        (self.target / 'retired/deep').mkdir(parents=True)
        (self.target / 'retired/deep/obsolete.lua').write_bytes(b'old-only file')

    def assert_clean_install(self):
        expected = files_below(ROOT / 'noitamap')
        expected['LICENSE'] = (ROOT / 'LICENSE').read_bytes()
        expected['noitamap.ico'] = (ROOT / 'installer/noitamap.ico').read_bytes()
        self.assertEqual(files_below(self.target), expected)
        self.assertFalse(self.target.with_name('noitamap.previous').exists())

    def test_fresh_install_and_repeated_upgrade(self):
        self.invoke()
        self.assert_clean_install()
        (self.target / 'obsolete.txt').write_text('old')
        self.invoke()
        self.assert_clean_install()
        self.invoke()
        self.assert_clean_install()

    def test_upgrade_replaces_a_manually_installed_mod(self):
        self.old_mod()
        self.invoke()
        self.assert_clean_install()

    def test_copy_failure_restores_the_complete_previous_folder(self):
        self.old_mod()
        before = files_below(self.target)
        details = self.invoke(installer=self.failing_installer, success=False)
        self.assertIn('Injected copy failure', details)
        self.assertEqual(files_below(self.target), before)
        self.assertFalse(self.target.with_name('noitamap.previous').exists())

    def test_an_existing_backup_is_never_overwritten(self):
        self.old_mod()
        before = files_below(self.target)
        backup = self.target.with_name('noitamap.previous')
        backup.mkdir()
        (backup / 'recover-me').write_bytes(b'previous interrupted update')
        self.invoke(success=False)
        self.assertEqual(files_below(self.target), before)
        self.assertEqual(files_below(backup), {'recover-me': b'previous interrupted update'})

    def test_arbitrary_destination_is_rejected(self):
        before = files_below(self.outside)
        self.invoke(target=self.outside, success=False)
        self.assertEqual(files_below(self.outside), before)

    def test_mod_path_without_a_game_is_rejected(self):
        wrong = self.work / self._testMethodName / 'not-a-game/mods/noitamap'
        wrong.mkdir(parents=True)
        (wrong / 'keep').write_bytes(b'unrelated directory')
        self.invoke(target=wrong, success=False)
        self.assertEqual(files_below(wrong), {'keep': b'unrelated directory'})

    @unittest.skipUnless(os.name == 'nt', 'NTFS junction check runs on the Windows release runner')
    def test_old_junction_does_not_delete_its_target(self):
        self.old_mod()
        junction = self.target / 'outside'
        subprocess.run(['cmd', '/c', 'mklink', '/J', str(junction), str(self.outside)],
                       check=True, capture_output=True)
        self.invoke()
        self.assert_clean_install()


if __name__ == '__main__':
    unittest.main()
