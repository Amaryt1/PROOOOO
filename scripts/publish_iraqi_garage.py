#!/usr/bin/env python3
"""Publish the exact, independently checked Iraqi Garage mod in mods.json.

This script refuses substitutes and never changes an IPA or game data.
Run from repository root:
  python3 scripts/publish_iraqi_garage.py \
    --archive /path/Iraqi_Garage_3_Cars_Realistic_Driving_Audio_Fixed_FiveStarPort.zip \
    --catalog mods.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import zipfile

TAG = "iraqi-garage-3cars-v1"
NAME = "Iraqi_Garage_3_Cars_Realistic_Driving_Audio_Fixed_FiveStarPort.zip"
ID = "iraqi-garage-3"
SIZE = 73604201
SHA256 = "792d9a4e714ed16cb753982eec74e25c0e3a5882f7033b3109af54f8686f286e"
REQUIRED = {
    "update/x64/dlcpacks/405glxfnt/dlc.rpf": 127785746,
    "update/x64/dlcpacks/sj131/dlc.rpf": 76676895,
    "update/x64/dlcpacks/srtday20/dlc.rpf": 17103615,
}

def verify_archive(path: pathlib.Path) -> None:
    if path.name != NAME:
        raise ValueError(f"File must retain its exact original name: {NAME}")
    if path.stat().st_size != SIZE:
        raise ValueError(f"Archive size mismatch: {path.stat().st_size} != {SIZE}")
    hasher = hashlib.sha256()
    with path.open("rb") as src:
        for block in iter(lambda: src.read(1024 * 1024), b""):
            hasher.update(block)
    digest = hasher.hexdigest()
    if digest != SHA256:
        raise ValueError(f"SHA-256 mismatch; refusing unknown ZIP: {digest}")

    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP integrity test failed")
        names = [x.filename for x in archive.infolist()]
        if len(set(names)) != len(names):
            raise ValueError("ZIP contains duplicate entry names")
        if len(names) > 1000:
            raise ValueError("Unexpected number of files")
        if any(n.startswith("/") or "\\" in n or ".." in pathlib.PurePosixPath(n).parts for n in names):
            raise ValueError("Archive contains unsafe paths")
        if sum(x.file_size for x in archive.infolist()) > 300_000_000:
            raise ValueError("Archive exceeds expanded size budget")
        for required, expected_size in REQUIRED.items():
            found = archive.getinfo(required)
            if found.file_size != expected_size:
                raise ValueError(f"Expected DLC content changed: {required}")
    print(f"PASS: exact three-car ZIP, {SIZE} bytes, SHA256={SHA256}")

def update_catalog(path: pathlib.Path) -> bool:
    catalog = json.loads(path.read_text(encoding="utf-8"))
    if catalog.get("schema") != 1 or not isinstance(catalog.get("mods"), list):
        raise ValueError("Invalid catalog")
    if "السيارات" not in catalog.get("categories", []):
        raise ValueError("Vehicle category not found")

    entry = {
        "id": ID,
        "name": "Iraqi Garage — سايبة + بيجو 405 + تشارجر",
        "description": "حزمة السيارات الثلاث التي نجح استيرادها داخل GTA V.",
        "category": "السيارات",
        "image": "https://raw.githubusercontent.com/Amaryt1/PROOOOO/main/images/mods/iraqi-garage.svg",
        "minKit": 5,
        "maxKit": 5,
        "compatibility": "حزمة ZIP تستورد بالمستورد الأصلي للعبة.",
        "archiveURL": f"https://github.com/Amaryt1/PROOOOO/releases/download/{TAG}/{NAME}",
        "archiveSize": SIZE,
        "archiveSha256": SHA256,
        "expectedMods": ["405glxfnt", "sj131", "srtday20"],
        "version": "1.0",
        "featured": True,
        "installMode": "native",
        "archiveFormat": "zip"
    }

    previous = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    catalog["mods"] = [entry] + [m for m in catalog["mods"] if m.get("id") != ID]
    result = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    if result != previous:
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(result, encoding="utf-8")
        os.replace(tmp, path)
        print(f"UPDATED: {path} with {ID} as first item")
        return True
    print("UNCHANGED: already published")
    return False

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--archive", type=pathlib.Path, required=True)
    p.add_argument("--catalog", type=pathlib.Path, default=pathlib.Path("mods.json"))
    args = p.parse_args()
    verify_archive(args.archive)
    update_catalog(args.catalog)
