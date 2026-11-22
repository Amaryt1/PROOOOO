#!/usr/bin/env python3
"""Normalize an existing GTA V Add-on DLC ZIP for LOCAL iOS import testing.

No new dlc.rpf can be fabricated from loose YFT/YTD files. Distribution of
third-party content requires original author permission. Does not edit IPA.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import stat
import sys
import zipfile

DLC = re.compile(r"(?:^|/)(?:update/x64/)?dlcpacks/([a-z0-9_-]+)/dlc\.rpf$", re.I)
BARE = re.compile(r"(?:^|/)([a-z0-9_-]+)/dlc\.rpf$", re.I)
MAX_FILE = 400_000_000
MAX_TOTAL = 1_610_612_736
MAX_ARCHIVE = 536_870_912

def convert(src, dst, single_id=None):
    if src.resolve() == dst.resolve():
        raise ValueError("Use separate source and output paths")
    if src.stat().st_size > MAX_ARCHIVE:
        raise ValueError("ZIP exceeds Build 9 download size limit")
    assets = {}
    with zipfile.ZipFile(src, "r") as z:
        infos = z.infolist()
        if len(infos) > 4000:
            raise ValueError("Excessive ZIP entry count")
        seen = set()
        total = 0
        for item in infos:
            name = item.filename.replace("\\", "/")
            parts = pathlib.PurePosixPath(name).parts
            if (item.filename != name or not name or name.startswith("/") or
                ".." in parts or name.casefold() in seen or
                stat.S_ISLNK(item.external_attr >> 16) or item.flag_bits & 1):
                raise ValueError("Unsafe/duplicate/encrypted ZIP member: " + name)
            seen.add(name.casefold())
            total += item.file_size
            if total > MAX_TOTAL or item.file_size > MAX_FILE:
                raise ValueError("Archive exceeds decompression limits")
            if item.is_dir():
                continue
            match = DLC.search(name)
            if not match and single_id:
                if not re.fullmatch(r"[a-zA-Z0-9_-]{1,50}", single_id):
                    raise ValueError("Unsafe --id")
                if name.lower() == "dlc.rpf":
                    mod_id = single_id.lower()
                    with z.open(item) as f:
                        if f.read(4) != b"7FPR":
                            raise ValueError("Not an RPF7 DLC: " + name)
                    assets[mod_id] = item
                    continue
            if not match:
                match = BARE.search(name)
            if match:
                mod_id = match.group(1).lower()
                if mod_id in assets:
                    raise ValueError("Duplicate DLC folder: " + mod_id)
                with z.open(item) as f:
                    if f.read(4) != b"7FPR":
                        raise ValueError("Not an RPF7 DLC: " + name)
                assets[mod_id] = item
        if not assets:
            raise ValueError("No genuine Add-on dlc.rpf found. Cannot convert loose YFT/YTD to DLC.")
        if len(assets) > 20:
            raise ValueError("Too many DLC packs")
        if bad := z.testzip():
            raise ValueError("Corrupt ZIP entry: " + bad)
        dst.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as output:
            for mod_id, item in sorted(assets.items()):
                filename = f"update/x64/dlcpacks/{mod_id}/dlc.rpf"
                with z.open(item) as original, output.open(filename, "w", force_zip64=True) as target:
                    shutil.copyfileobj(original, target, 1024 * 1024)
    with zipfile.ZipFile(dst) as check:
        if bad := check.testzip():
            dst.unlink(missing_ok=True)
            raise ValueError("Result ZIP corrupt: " + bad)
    with dst.open("rb") as f:
        digest = hashlib.file_digest(f, "sha256").hexdigest()
    return {"output": str(dst), "bytes": dst.stat().st_size, "sha256": digest,
            "expectedMods": sorted(assets),
            "verified": "CRC and RPF7 magic only; GAME PLAY / AUTO-IMPORT NOT TESTED",
            "excluded_other_files": len(infos)-len(assets)}

if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source_zip", type=pathlib.Path)
    p.add_argument("output_zip", type=pathlib.Path)
    p.add_argument("--id", help="Only when ZIP contains a root dlc.rpf without a car name")
    a = p.parse_args()
    try:
        print(json.dumps(convert(a.source_zip, a.output_zip, a.id), ensure_ascii=False, indent=2))
    except (ValueError, OSError, zipfile.BadZipFile) as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
