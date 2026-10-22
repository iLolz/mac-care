#!/usr/bin/env python3
"""Fails when a string in the exported localizations has no translation.

Run after `xcodebuild -exportLocalizations`, which extracts every string the app uses
from the Swift sources and merges it with the string catalogs:

    python3 scripts/check-localizations.py build/localizations
"""
import glob
import os
import sys
import xml.etree.ElementTree as ET

NS = {"x": "urn:oasis:names:tc:xliff:document:1.2"}

root = sys.argv[1] if len(sys.argv) > 1 else "build/localizations"
xliffs = sorted(glob.glob(os.path.join(root, "*.xcloc", "Localized Contents", "*.xliff")))
if not xliffs:
    sys.exit(f"No .xliff found under {root}")

missing = []
for path in xliffs:
    for file in ET.parse(path).getroot().findall("x:file", NS):
        original = file.get("original", "")
        language = file.get("target-language")
        # Only the app's own catalogs; Info.plist keys like the bundle name are not ours to translate.
        if not original.endswith("Localizable.xcstrings") and not original.endswith("InfoPlist.xcstrings"):
            continue
        for unit in file.iter(f"{{{NS['x']}}}trans-unit"):
            if unit.get("translate") == "no":
                continue
            target = unit.find("x:target", NS)
            state = target.get("state") if target is not None else None
            if target is None or not (target.text or "").strip() or state in ("new", "needs-translation"):
                source = unit.find("x:source", NS)
                missing.append((language, original, source.text if source is not None else unit.get("id")))

for language, original, source in missing:
    print(f"::error file={original}::[{language}] missing translation: {source}")
print(f"Checked {len(xliffs)} languages, {len(missing)} missing translations.")
sys.exit(1 if missing else 0)
