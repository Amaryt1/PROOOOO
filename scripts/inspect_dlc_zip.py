#!/usr/bin/env python3
"""Read-only inspector for GTA V DLC vehicle ZIPs.

Checks the proven Iraqi Garage layout without claiming game-level compatibility.
Usage:
  python3 scripts/inspect_dlc_zip.py '/path/to/new-mod.zip'
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import stat
import sys
import zipfile

DLC_PATTERN = re.compile(r"^update/x64/dlcpacks/([A-Za-z0-9_-]+)/dlc\.rpf$", re.I)
MAX_ZIP_BYTES = 536_870_912  # Same 512 MiB ceiling as current Build 9 catalog.
MAX_EXPANDED_BYTES = 1_610_612_736
MAX_FILES = 4_000

def inspect(path: pathlib.Path) -> dict:
    if not path.is_file() or path.suffix.lower() != ".zip":
        raise ValueError("Expected an existing .zip file")
    packed_size = path.stat().st_size
    if not (20 <= packed_size <= MAX_ZIP_BYTES):
        raise ValueError("ZIP size outside supported download limits")
    sha = hashlib.sha256()
    with path.open("rb") as fp:
        for block in iter(lambda: fp.read(1024 * 1024), b""):
            sha.update(block)

    cars = {}
    warnings = []
    extras = []
    total = 0
    seen = set()
    with zipfile.ZipFile(path) as z:
        entries = z.infolist()
        if not entries or len(entries) > MAX_FILES:
            raise ValueError("Invalid number of ZIP members")
        for item in entries:
            name = item.filename
            pure = pathlib.PurePosixPath(name)
            if (not name or name.startswith("/") or "\\" in name or
                "." in pure.parts or ".." in pure.parts or
                name.casefold() in seen):
                raise ValueError(f"Unsafe or duplicated ZIP entry: {name!r}")
            seen.add(name.casefold())
            if stat.S_ISLNK(item.external_attr >> 16):
                raise ValueError(f"Symlink ZIP entry is not allowed: {name}")
            if item.flag_bits & 1:
                raise ValueError(f"Encrypted ZIP entry is not supported: {name}")
            if item.file_size > MAX_EXPANDED_BYTES:
                raise ValueError(f"Oversized member: {name}")
            total += item.file_size
            if total > MAX_EXPANDED_BYTES:
                raise ValueError("Expanded archive is too large")
            match = DLC_PATTERN.fullmatch(name)
            if match is None:
                if not item.is_dir():
                    extras.append(name)
                continue
            vehicle = match.group(1)
            with z.open(item) as fp:
                header = fp.read(4)
            if header != b"7FPR":
                raise ValueError(f"{name}: invalid RPF7 header: {header!r}")
            cars[vehicle] = {"path": name, "bytes": item.file_size, "rpf7": True}
        if not cars:
            raise ValueError(
                "No DLC found under update/x64/dlcpacks/<vehicle>/dlc.rpf. "
                "Loose stream/*.yft and *.ytd files alone do not match the known-good ZIP."
            )
        bad = z.testzip()
        if bad:
            raise ValueError(f"CRC error in {bad}")

    if extras:
        warnings.append(
            f"Archive contains {len(extras)} files outside DLC packs "
            "(e.g., timecycle/visualsettings); review before publishing."
        )
    warnings.append(
        "PASS indicates a structurally similar ZIP, not guaranteed import, spawn or gameplay "
        "compatibility; a manual import test on the target iOS game is still required."
    )
    return {
        "filename": path.name,
        "archive_size_bytes": packed_size,
        "sha256": sha.hexdigest(),
        "vehicle_folders_expectedMods": list(cars),
        "dlc_packs": cars,
        "other_files": extras,
        "expanded_size_bytes": total,
        "warnings": warnings,
    }

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("archive", type=pathlib.Path, help="Local GTA V add-on ZIP")
    p.add_argument("--json", action="store_true", help="Machine-readable report")
    args = p.parse_args()
    try:
        report = inspect(args.archive)
    except (ValueError, OSError, zipfile.BadZipFile) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
