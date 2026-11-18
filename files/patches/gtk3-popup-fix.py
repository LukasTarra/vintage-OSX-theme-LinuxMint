#!/usr/bin/env python3
"""Fix the OS X Leopard GTK3 theme's drop-down/popup menus (best effort).

Symptom: combobox menus sometimes open as a tiny sliver in the middle and
need scrolling. Changes: normalise the scroll arrows, drop the 10px
invisible margin around popup windows, use a thin even popup outline.
Idempotent: running it twice changes nothing. Usage: gtk3-popup-fix.py FILE
"""
import sys

path = sys.argv[1]
s = open(path, encoding="utf-8").read()

edits = [
    ("  menu > arrow, .menu > arrow {\n    padding: 4px;",
     "  menu > arrow, .menu > arrow {\n    padding: 2px;"),
    ("      margin-top: -6px;\n", "      margin-top: 0;\n"),
    ("      margin-bottom: -6px;\n", "      margin-bottom: 0;\n"),
    ("  .popup decoration {\n    box-shadow: none; }",
     "  .popup decoration {\n    margin: 0;\n    box-shadow: none; }"),
    ("  .csd.popup decoration {\n    border-radius: 4px;\n    box-shadow: 0 6px 5px 1px alpha(#000000, 0.2), 0 0 0 1px alpha(#000000, 0.1); }",
     "  .csd.popup decoration {\n    margin: 0;\n    border-radius: 4px;\n    box-shadow: 0 0 0 1px alpha(#000000, 0.25); }"),
]
applied = skipped = 0
for old, new in edits:
    if old in s:
        s = s.replace(old, new, 1)
        applied += 1
    elif new in s:
        skipped += 1          # already patched
    else:
        print("WARNING: pattern not found (theme version differs?):",
              old.strip().splitlines()[0], file=sys.stderr)
open(path, "w", encoding="utf-8").write(s)
print(f"gtk3 popup fix: {applied} applied, {skipped} already present")
