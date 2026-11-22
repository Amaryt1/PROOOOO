#!/usr/bin/env python3
"""Rebuild a personal V5 package from the supported V4. Sign all nested code afterwards."""
import argparse
from copy import copy
import hashlib
import json
import os
import plistlib
import shutil
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = 'Payload/GTAV.app/'
ARABIC = APP + 'GTAVArabic.dylib'
TRANSLATION = APP + 'GTAVArabic/launcher_ar.json'
TARGETS = [APP+'GTA5', ARABIC, APP+'Frameworks/libgtacompat.dylib']
DEPENDENCY = b'@executable_path/Frameworks/AMARYTKit.dylib\0'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def stream_hash(stream):
    h = hashlib.sha256()
    while block := stream.read(2**20):
        h.update(block)
    return h.hexdigest()

def link_kit(original):
    data = bytearray(original)
    magic, count = struct.unpack_from('>2I', data)
    if (magic, count) != (0xcafebabe, 2):
        raise ValueError('Unexpected V4 localization library')
    size = (24 + len(DEPENDENCY) + 7) & ~7
    command = struct.pack('<6I', 0x80000018, size, 24, 0, 0, 0) + DEPENDENCY
    for i in range(count):
        cpu, _, base, length, _ = struct.unpack_from('>5I', data, 8+20*i)
        if cpu != 0x100000c or base+length > len(data):
            raise ValueError('Unexpected slice')
        n, used = struct.unpack_from('<2I', data, base+16)
        end = base+32+used
        at = base+32
        sections = []
        for _ in range(n):
            cmd, sz = struct.unpack_from('<2I', data, at)
            if sz < 8 or at+sz > end:
                raise ValueError('Malformed Mach-O commands')
            if cmd == 25:
                nsects = struct.unpack_from('<I', data, at+64)[0]
                sections.extend(struct.unpack_from('<I', data, at+120+j*80)[0] for j in range(nsects))
            at += sz
        first = base+min(x for x in sections if x)
        if at != end or end+size > first or any(data[end:end+size]):
            raise ValueError('Missing verified header space')
        data[end:end+size] = command.ljust(size,b'\0')
        struct.pack_into('<2I', data, base+16,n+1,used+size)
    return data

def rebuild(src, out, tmp):
    kit = tmp/'AMARYTKit.dylib'
    subprocess.run([ROOT/'scripts/compile.sh', kit],check=True)
    trust=json.loads((ROOT/'scripts/v4-hashes.json').read_text())
    with zipfile.ZipFile(src) as old:
        names=old.namelist()
        if len(names)!=len(set(names)):
            raise ValueError('Duplicate archive entries')
        for name in TARGETS:
            with old.open(name) as f:
                if stream_hash(f)!=trust[name]:
                    raise ValueError('Unsupported V4 binary: '+name)
        original=old.read(ARABIC)
        lang=json.loads(old.read(TRANSLATION))
        lang['launcher'].update({'GAMES':'الألعاب','MODS':'المودات','SAVES':'الحفظ','SETTINGS':'الإعدادات'})
        pl=plistlib.loads(old.read(APP+'Info.plist'))
        pl.update(CFBundleDisplayName='AMAR YT V5',CFBundleShortVersionString='5.0',CFBundleVersion='5')
        changes={ARABIC:link_kit(original),TRANSLATION:json.dumps(lang,ensure_ascii=False,indent=2).encode(),APP+'Info.plist':plistlib.dumps(pl)}
        staged=tmp/'package.ipa'
        with zipfile.ZipFile(staged,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=3) as new:
            for item in old.infolist():
                if item.filename in changes:
                    new.writestr(copy(item),changes[item.filename])
                else:
                    with old.open(item) as r,new.open(copy(item),'w') as w:
                        shutil.copyfileobj(r,w,2**20)
            new.write(kit,APP+'Frameworks/AMARYTKit.dylib')
            for path in ['config.json','mods.json','source/panel.html','source/policy.js']:
                new.write(ROOT/path, APP+'AMARYTKit/'+Path(path).name)
        with zipfile.ZipFile(staged) as new:
            if new.testzip(): raise ValueError('CRC verification failed')
            changed=[]
            for n in names:
                with old.open(n) as a,new.open(n) as b:
                    if stream_hash(a)!=stream_hash(b): changed.append(n)
            if set(changed)!=set(changes): raise ValueError('Unexpected changed entries')
            for n,v in changes.items():
                if digest(new.read(n))!=digest(v): raise ValueError('Output mismatch')
            report={'original_entries':len(names),'unchanged_entries':len(names)-len(changed),'changed':changed,
                    'added':sorted(set(new.namelist())-set(names)),'v4_sha256':trust,
                    'v5_binary_sha256':{}}
            for n in TARGETS+[APP+'Frameworks/AMARYTKit.dylib']:
                with new.open(n) as f: report['v5_binary_sha256'][n]=stream_hash(f)
    with staged.open('rb') as f:report['ipa_sha256']=stream_hash(f)
    os.replace(staged,out)
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('v4',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
    if args.output.exists():parser.error('Choose a new output path')
    with tempfile.TemporaryDirectory(dir=args.output.resolve().parent) as t:
        rebuild(args.v4,args.output,Path(t))
