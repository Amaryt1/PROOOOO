#!/usr/bin/env python3
"""Build the diagnostic IPA using the exact FINAL(4) input, then sign the whole bundle."""
import argparse
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE_HASH = '4adc5fc848ca09c5d9327a6fa2895c53482da6b6ad318c9914e090e6dba36ab6'

def build(src, output):
    if output.exists():
        raise ValueError('Choose a new output path')
    with src.open('rb') as f:
        digest = hashlib.sha256()
        for block in iter(lambda:f.read(1024*1024), b''):
            digest.update(block)
    if digest.hexdigest() != BASE_HASH:
        raise ValueError('Expected the FINAL(4) reference IPA')
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
        values.update(CFBundleDisplayName='GTA V', CFBundleName='GTA V', CFBundleVersion='7')
        plist.write_bytes(plistlib.dumps(values))
        ar = app/'GTAVArabic/launcher_ar.json'
        tr = json.loads(ar.read_bytes())
        tr['launcher'].update(GAMES='الألعاب', DATA='الحفظ', SETTINGS='الإعدادات', MODS='المودات')
        ar.write_text(json.dumps(tr, ensure_ascii=False, indent=2))
        subprocess.run([ROOT/'scripts/compile.sh', app/'Frameworks/AMARYTKit.dylib'], check=True)
        for name in ('mods.json','source/policy.js','source/panel.html'):
            shutil.copyfile(ROOT/name, app/'AMARYTKit'/Path(name).name)
        cfg = json.loads((ROOT/'config.json').read_bytes())
        cfg['welcome'].update(enabled=True, id='welcome-ui-verification-01', frequency='launch',title='أهلًا بك في AMAR YT')
        cfg['update']['enabled'] = False
        (app/'AMARYTKit/config.json').write_text(json.dumps(cfg,ensure_ascii=False,indent=2))
        signer = os.environ.get('ZSIGN', 'zsign')
        candidate = folder/'diagnostic.ipa'
        subprocess.run([signer,'-a','-f','-R','-z','6','-o',candidate,app],cwd=folder,check=True)
        with zipfile.ZipFile(candidate) as archive:
            if archive.testzip() or 'Payload/GTAV.app/GTA5' not in archive.namelist():
                raise ValueError('Invalid signed IPA')
        os.replace(candidate,output)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('final4',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    build(args.final4,args.output)
