#!/usr/bin/env python3
"""Reconstruct a user-authorized Hilux beta ZIP from verified Git blobs and publish metadata.

No archive bytes are embedded in the repository: binary chunk blobs are created via
GitHub API and reconstructed by a one-time GitHub Actions job. Do not alter IPA.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import urllib.request
import zipfile

REPO = "Amaryt1/PROOOOO"
TAG = "amaryt-hilux21-tele-v1"
ZIP_NAME = "AMARYT-HILUX-2021-TELE-BETA.zip"
ZIP_SIZE = 19513969
ZIP_SHA256 = "4892ba9988dd59c7c9fa4f34ebd88e093992168e9930eae8e0b16fedfe2fca88"
DLC_PATH = "update/x64/dlcpacks/hilux21/dlc.rpf"
GIT_BLOBS = """
6107fbb161107fcd321b647d37835ce976e32a1c
afdd1a2b85dc197342e956c81bdb670a1cadfd9b
e7bc8c837e1f4850f968a746ef1422163d13ced1
b671d599a454af487fbc381630093a8d1920dcab
e84864dcd62e63ac773dfd39e9f5581c4e1ea91d
e9dc7fa6e42ba3d745142b1e27ee8c7593d8af0c
12167a68831f4e341e16da6049d7eff1ffe61220
3a260dc134704b50c6234ae16c555439fd594544
27e70475d3684ebd7204aee4bb30f80476eda24c
14733c3e05fec33773a16ec619f8d878fec20b3f
8f2b3d06568ca182fba5effabb7531e6624db74b
7604a28b1416b5ab6f93b94258b2e32c6b0889fe
91a82f4198911c40e55bf26ee67be347913b8c8d
5369bab4759e964978dd2f6f9ce9ca912850f46a
b4827ee2ef4e81b695a81349485b55bae7a917d3
f207feed7078dc1e78bb9a580a9a8061c3ae088a
e820e1f901d67dd39d00c70b703c4a8ccaf160a2
f46b81a2b27ae82d75965e7f8d04c5a43d0e80d2
f585e1487f20a48bba770b51e7bb67fb5083ce93
99189679e85d7394240c3dad2c2908dc48afadb1
9a81fc06c302fa4ec9980b4ac060a8c761ab4d27
5788f55fb2024220da4fadee78ff9e343d8b1b7f
f4d1105b930a4e2d322d8d0905e35d4bdd8fb3ca
6666742e6259c7fb1d88539f0d0b4033c8e0b5a1
f63dbd2bf464c2559105e0b2dfb1548fb2d4e221
dcb51b745ab7a0e48182ca6cd63796390e0f5df1
cc9287394ccefb9b7326a0ae52c6b314ab39e0d9
""".split()


def validate_zip(path: Path) -> None:
    if path.stat().st_size != ZIP_SIZE:
        raise ValueError(f"Wrong byte length: {path.stat().st_size}")
    h=hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024*1024), b""):
            h.update(block)
    if h.hexdigest() != ZIP_SHA256:
        raise ValueError("Reconstructed ZIP SHA256 differs from local original")
    with zipfile.ZipFile(path) as z:
        if z.namelist() != [DLC_PATH]:
            raise ValueError("Unexpected ZIP structure")
        if z.getinfo(DLC_PATH).file_size != 305320960:
            raise ValueError("Unexpected size of RPF")
        with z.open(DLC_PATH) as f:
            if f.read(4) != b"7FPR":
                raise ValueError("Missing RPF7 magic")
        if z.testzip() is not None:
            raise ValueError("ZIP CRC failed")
    print("Verified exact modified 2021 Hilux ZIP",path,ZIP_SHA256)


def assemble(path: Path) -> None:
    token = os.environ["GH_TOKEN"]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as out:
        for idx, sha in enumerate(GIT_BLOBS):
            url=f"https://api.github.com/repos/{REPO}/git/blobs/{sha}"
            request=urllib.request.Request(url,headers={
                "Authorization":f"Bearer {token}",
                "Accept":"application/vnd.github+json",
                "X-GitHub-Api-Version":"2022-11-28",
                "User-Agent":"AMARYT-Hilux-Release-Bot"})
            with urllib.request.urlopen(request,timeout=40) as response:
                payload=json.load(response)
            if payload.get("sha")!=sha or payload.get("encoding")!="base64":
                raise ValueError(f"Unexpected blob metadata {idx}")
            part=base64.b64decode(payload["content"])
            git_sha=hashlib.sha1(b"blob "+str(len(part)).encode()+b"\x00"+part).hexdigest()
            if git_sha!=sha:
                raise ValueError(f"Blob mismatch {idx}")
            out.write(part)
            print(f"Verified part {idx+1} of {len(GIT_BLOBS)} ({len(part)} bytes)")
    validate_zip(path)


def update_catalog(path: Path) -> None:
    catalog=json.loads(path.read_text(encoding="utf-8"))
    if catalog.get("schema")!=1 or "السيارات" not in catalog.get("categories",[]):
        raise ValueError("Invalid mod catalog")
    ids=[m["id"] for m in catalog["mods"]]
    if "iraqi-garage-3" not in ids:
        raise ValueError("Refusing to modify catalog without known-good Iraqi Garage entry")
    entry={
        "id":"hilux21-tele",
        "name":"تويوتا هايلوكس 2021 — TELE • @AMARYT",
        "description":"نسخة اختبار: هايلوكس GLX 2021 مع كتابة TELE • @AMARYT على خامة الزجاج. قد يظهر النص على أكثر من نافذة. لم يكتمل اختبار ظهور الكتابة داخل اللعبة.",
        "category":"السيارات",
        "image":"https://img.gta5-mods.com/q75/images/toyota-hilux-glx-2021-add-on-fivem/5200b0-374211494_829221631913744_2043670646105742635_n.jpg",
        "minKit":5,
        "maxKit":5,
        "compatibility":"RPF7 DLC حقيقي؛ اجتاز فحص الأرشيف، لكن لم يختبر التوليد وموضع النص على iOS.",
        "archiveURL":f"https://github.com/{REPO}/releases/download/{TAG}/{ZIP_NAME}",
        "archiveSize":ZIP_SIZE,
        "archiveSha256":ZIP_SHA256,
        "expectedMods":["hilux21"],
        "version":"1.0-beta",
        "featured":True,
        "installMode":"native",
        "archiveFormat":"zip",
        "sourcePage":"https://www.gta5-mods.com/vehicles/toyota-hilux-glx-2021-add-on-fivem",
        "originalAuthor":"omardr",
    }
    catalog["mods"]=[entry]+[m for m in catalog["mods"] if m["id"]!="hilux21-tele"]
    path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("Updated catalog with verified GitHub Release beta ZIP")


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--assemble",type=Path)
    group.add_argument("--publish-catalog",type=Path)
    args=parser.parse_args()
    if args.assemble:assemble(args.assemble)
    else:update_catalog(args.publish_catalog)
