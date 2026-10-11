import hashlib
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ReleaseTests(unittest.TestCase):
    def build(self, work):
        package = work / 'noitamap.zip'
        subprocess.run([sys.executable, str(ROOT / 'build_release.py'), '--output', str(package)],
                       check=True, capture_output=True)
        return package

    def payload(self):
        files = {p.relative_to(ROOT).as_posix(): p.read_bytes()
                 for p in (ROOT / 'noitamap').rglob('*') if p.is_file()}
        files['noitamap/LICENSE'] = (ROOT / 'LICENSE').read_bytes()
        return files

    def test_reproducible_package_installs_the_exact_tested_source(self):
        with tempfile.TemporaryDirectory(prefix='noitamap-release-test-') as temporary:
            work = pathlib.Path(temporary)
            package = self.build(work)
            first = package.read_bytes()
            installer = (work / 'install.sh').read_bytes()
            self.build(work)
            self.assertEqual(package.read_bytes(), first)
            self.assertEqual((work / 'install.sh').read_bytes(), installer)
            self.assertEqual((work / 'SHA256SUMS.txt').read_text(), ''.join(
                hashlib.sha256(data).hexdigest() + '  ' + name + '\n'
                for name, data in [('noitamap.zip', first), ('install.sh', installer)]))
            expected = self.payload()
            with zipfile.ZipFile(package) as archive:
                self.assertEqual(set(archive.namelist()), set(expected) | {'noitamap/'})
                self.assertEqual({name.split('/')[0] for name in archive.namelist()}, {'noitamap'})
                self.assertIsNone(archive.testzip())
                for name, data in expected.items():
                    self.assertEqual(archive.read(name), data)
                archive.extractall(work / 'mods')
            self.assertTrue((work / 'mods/noitamap/mod.xml').is_file())
            self.assertFalse((work / 'mods/noitamap/noitamap').exists())
            self.assertEqual({p.name for p in (work / 'mods').iterdir()}, {'noitamap'})

    def test_standalone_script_needs_no_zip_and_ignores_stale_adjacent_files(self):
        with tempfile.TemporaryDirectory(prefix='noitamap-standalone-test-') as temporary:
            work = pathlib.Path(temporary)
            self.build(work / 'built')
            download = work / 'Only the installer'; download.mkdir()
            script = download / 'install.sh'
            shutil.copy2(work / 'built/install.sh', script)
            subprocess.run(['sh', '-n', str(script)], check=True, capture_output=True)
            stale = download / 'noitamap'; stale.mkdir()
            (stale / 'mod.xml').write_text('stale version beside the installer')
            game = work / 'Fake Noita'; game.mkdir(); (game / 'noita.exe').touch()
            result = subprocess.run(['sh', str(script), '--dir', str(game)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for name, data in self.payload().items():
                self.assertEqual((game / 'mods' / name).read_bytes(), data)
            self.assertFalse((game / 'mods/noitamap/noitamap').exists())
            result = subprocess.run(['sh', str(script), '--dir', str(game), '--uninstall'],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse((game / 'mods/noitamap').exists())
            self.assertTrue((game / 'noita.exe').exists())

    def test_standalone_dry_run_leaves_game_untouched(self):
        with tempfile.TemporaryDirectory(prefix='noitamap-dry-run-test-') as temporary:
            work = pathlib.Path(temporary)
            self.build(work / 'built')
            game = work / 'Fake Noita'; game.mkdir(); (game / 'noita.exe').touch()
            result = subprocess.run(['sh', str(work / 'built/install.sh'), '--dir', str(game), '--dry-run'],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse((game / 'mods').exists())

    def test_damaged_payload_never_replaces_an_installed_mod(self):
        with tempfile.TemporaryDirectory(prefix='noitamap-corrupt-test-') as temporary:
            work = pathlib.Path(temporary)
            self.build(work / 'built')
            script = work / 'built/install.sh'
            prefix, payload = script.read_bytes().split(b'\n__NOITAMAP_PAYLOAD__\n')
            payload = (b'A' if payload[:1] != b'A' else b'B') + payload[1:]
            script.write_bytes(prefix + b'\n__NOITAMAP_PAYLOAD__\n' + payload)
            game = work / 'Fake Noita'; game.mkdir(); (game / 'noita.exe').touch()
            old = game / 'mods/noitamap'; old.mkdir(parents=True)
            (old / 'mod.xml').write_text('existing mod')
            result = subprocess.run(['sh', str(script), '--dir', str(game)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('checksum', result.stderr)
            self.assertEqual((old / 'mod.xml').read_text(), 'existing mod')

    def test_builder_refuses_to_overwrite_installer_source(self):
        before = (ROOT / 'install.sh').read_bytes()
        result = subprocess.run([sys.executable, str(ROOT / 'build_release.py'), '--output', str(ROOT / 'noitamap.zip')],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('source', result.stderr)
        self.assertEqual((ROOT / 'install.sh').read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
