import pathlib
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='noitamap-installer-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.game = self.root / "Bob's Steam; $(touch DO_NOT_RUN)"
        self.game.mkdir()
        (self.game / 'noita.exe').touch()

    def invoke(self, *args, script=None, success=True, env=None):
        result = subprocess.run(['sh', str(script or ROOT / 'install.sh'), '--dir', str(self.game), *args],
                                cwd=self.root, capture_output=True, text=True, env=env)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'DO_NOT_RUN').exists())
        return result

    def test_install_replace_and_uninstall_quoted_paths(self):
        self.invoke()
        target = self.game / 'mods/noitamap'
        self.assertEqual((target / 'init.lua').read_bytes(), (ROOT / 'noitamap/init.lua').read_bytes())
        (target / 'obsolete-file').write_text('old')
        self.invoke()
        self.assertFalse((target / 'obsolete-file').exists())
        self.assertEqual(list((self.game / 'mods').glob('.noitamap-install.*')), [])
        self.invoke('--uninstall')
        self.assertFalse(target.exists())
        self.assertTrue((self.game / 'noita.exe').exists())

    def test_dry_run_does_not_create_mods(self):
        self.invoke('--dry-run')
        self.assertFalse((self.game / 'mods').exists())

    def test_source_is_already_the_destination(self):
        mods = self.game / 'mods'
        mods.mkdir()
        shutil.copytree(ROOT / 'noitamap', mods / 'noitamap')
        shutil.copy2(ROOT / 'install.sh', mods / 'install.sh')
        expected = (mods / 'noitamap/init.lua').read_bytes()
        self.invoke(script=mods / 'install.sh')
        self.assertEqual((mods / 'noitamap/init.lua').read_bytes(), expected)

    def test_invalid_game_is_rejected(self):
        (self.game / 'noita.exe').unlink()
        self.invoke(success=False)
        self.assertFalse((self.game / 'mods').exists())

    def test_failed_replacement_restores_the_existing_mod(self):
        self.invoke()
        target = self.game / 'mods/noitamap'
        (target / 'init.lua').write_text('existing installed version')
        commands = self.root / 'commands'
        commands.mkdir()
        command = commands / 'mv'
        command.write_text('#!/bin/sh\ncase "$2" in *.previous) ;; */.noitamap-install.*) exit 1 ;; esac\nexec /bin/mv "$@"\n')
        command.chmod(0o755)
        self.invoke(success=False, env={**os.environ, 'PATH': str(commands) + os.pathsep + os.environ['PATH']})
        self.assertEqual((target / 'init.lua').read_text(), 'existing installed version')
        self.assertEqual(list((self.game / 'mods').glob('.noitamap-install.*')), [])

if __name__ == '__main__':
    unittest.main()
