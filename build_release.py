#!/usr/bin/env python3
"""Build a clean mod ZIP and standalone Linux installer, without publication."""
import argparse
import base64
import gzip
import hashlib
import io
import pathlib
import tarfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent


def build(output):
    output = output.resolve()
    installer = output.with_name('install.sh')
    if installer == (ROOT / 'install.sh').resolve() or output.is_relative_to(ROOT / 'noitamap'):
        raise ValueError('Use a separate output directory; refusing to overwrite installer or mod source')
    files = {p.relative_to(ROOT).as_posix(): p for p in (ROOT / 'noitamap').rglob('*') if p.is_file()}
    files['noitamap/LICENSE'] = ROOT / 'LICENSE'
    if any(p.is_symlink() for p in files.values()):
        raise ValueError('Release payload must contain regular files, not symlinks')
    for required in ['noitamap/mod.xml', 'noitamap/init.lua', 'noitamap/mod_id']:
        if required not in files:
            raise ValueError(f'Missing required mod file: {required}')
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        directory = zipfile.ZipInfo('noitamap/', (1980, 1, 1, 0, 0, 0))
        directory.create_system = 3
        directory.external_attr = (0o40755 << 16) | 0x10
        archive.writestr(directory, b'')
        for name, path in sorted(files.items()):
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)

    # The separate .sh carries its matching payload: no adjacent ZIP, network
    # download, or accidentally selected older unpacked copy is needed.
    tar_bytes = io.BytesIO()
    with tarfile.open(fileobj=tar_bytes, mode='w', format=tarfile.USTAR_FORMAT) as archive:
        for name, path in sorted(files.items()):
            data = path.read_bytes()
            entry = tarfile.TarInfo(name)
            entry.size = len(data)
            entry.mode = 0o644
            archive.addfile(entry, io.BytesIO(data))
    compressed = io.BytesIO()
    with gzip.GzipFile(fileobj=compressed, filename='', mode='wb', mtime=0) as stream:
        stream.write(tar_bytes.getvalue())
    payload = compressed.getvalue()
    source = (ROOT / 'install.sh').read_bytes()
    token = b'__NOITAMAP_PAYLOAD_SHA256__'
    if source.count(token) != 1:
        raise ValueError('Installer payload placeholder is missing or repeated')
    source = source.replace(token, hashlib.sha256(payload).hexdigest().encode('ascii'))
    installer.write_bytes(source.rstrip() + b'\n__NOITAMAP_PAYLOAD__\n' + base64.encodebytes(payload))
    installer.chmod(0o755)
    checksums = ''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in [output, installer])
    output.with_name('SHA256SUMS.txt').write_text(checksums, encoding='utf8')
    print(f'Built {output} (root: noitamap/) and {installer} (standalone)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path, default=ROOT / 'dist/noitamap.zip')
    try:
        build(parser.parse_args().output)
    except ValueError as error:
        parser.error(str(error))
