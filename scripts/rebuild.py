#!/usr/bin/env python3
"""Build the diagnostic IPA using the exact Build 7 input, then sign the whole bundle."""
import argparse
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import struct
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE_HASH = '4b6d55f0bf5217012b9e41ded98b55fc2d7ee1bdca72963ff1e994cff08c8c91'

def link_launcher(executable):
    # Build 7 is a pinned arm64 executable. Append a standard LC_LOAD_DYLIB in its existing header padding.
    path = b'@executable_path/Frameworks/AMARYTKit.dylib\0'
    with executable.open('r+b') as stream:
        header = stream.read(16384)
        magic, cpu, _, filetype, count, used = struct.unpack_from('<6I', header)
        if (magic, cpu, filetype) != (0xfeedfacf, 0x100000c, 2):
            raise ValueError('Unexpected executable')
        end = 32 + used
        offset = 32
        sections = []
        for _ in range(count):
            command, size = struct.unpack_from('<2I', header, offset)
            if size < 8 or offset + size > end:
                raise ValueError('Invalid load command')
            if command == 0x19:
                section_count = struct.unpack_from('<I', header, offset+64)[0]
                for j in range(section_count):
                    fileoff = struct.unpack_from('<I', header, offset+120+80*j)[0]
                    if fileoff:
                        sections.append(fileoff)
            offset += size
        size = (24 + len(path) + 7) & ~7
        if offset != end or end+size > min(sections) or end+size > len(header) or any(header[end:end+size]):
            raise ValueError('Cannot add dependency without moving code')
        stream.seek(end)
        stream.write((struct.pack('<6I', 12, size, 24, 0, 0x10000, 0x10000)+path).ljust(size,b'\0'))
        stream.seek(16)
        stream.write(struct.pack('<2I', count+1, used+size))

def build(src, output):
    if output.exists():
        raise ValueError('Choose a new output path')
    with src.open('rb') as f:
        digest = hashlib.sha256()
        for block in iter(lambda:f.read(1024*1024), b''):
            digest.update(block)
    if digest.hexdigest() != BASE_HASH:
        raise ValueError('Expected the exact Build 7 IPA')
    with tempfile.TemporaryDirectory(dir=output.resolve().parent) as work:
        folder = Path(work)
        with zipfile.ZipFile(src) as archive:
            archive.extractall(folder)
            for entry in archive.infolist():
                mode = (entry.external_attr >> 16) & 0o777
                if mode:
                    (folder / entry.filename).chmod(mode)
        app = folder/'Payload/GTAV.app'
        plist = app/'Info.plist'
        values = plistlib.loads(plist.read_bytes())
        values.update(CFBundleDisplayName='GTA V', CFBundleName='GTA V', CFBundleVersion='8')
        plist.write_bytes(plistlib.dumps(values))
        ar = app/'GTAVArabic/launcher_ar.json'
        tr = json.loads(ar.read_bytes())
        tr['launcher'].update(GAMES='الألعاب', DATA='الحفظ', SETTINGS='الإعدادات', MODS='المودات')
        ar.write_text(json.dumps(tr, ensure_ascii=False, indent=2))
        subprocess.run([ROOT/'scripts/compile.sh', app/'Frameworks/AMARYTKit.dylib'], check=True)
        for name in ('mods.json','source/policy.js','source/panel.html'):
            shutil.copyfile(ROOT/name, app/'AMARYTKit'/Path(name).name)
        cfg = json.loads((ROOT/'config.json').read_bytes())
        cfg['welcome'].update(enabled=True, id='welcome-build8-local', frequency='launch',title='أهلًا بك في AMAR YT')
        cfg['update']['enabled'] = False
        (app/'AMARYTKit/config.json').write_text(json.dumps(cfg,ensure_ascii=False,indent=2))
        signer = os.environ.get('ZSIGN', 'zsign')
        link_launcher(app/'GTA5')
        candidate = folder/'diagnostic.ipa'
        subprocess.run([signer,'-a','-f','-R','-z','6','-o',candidate,app],cwd=folder,check=True)
        with zipfile.ZipFile(candidate) as archive:
            if archive.testzip() or 'Payload/GTAV.app/GTA5' not in archive.namelist():
                raise ValueError('Invalid signed IPA')
        os.replace(candidate,output)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('build7',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    build(args.build7,args.output)
