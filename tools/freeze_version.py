"""Freeze the current development build as a self-contained playable version.

  "<blender>/5.2/python/bin/python.exe" tools/freeze_version.py v01

Copies scripts/ scenes/ shaders/ assets/ into versions/<id>/, rewrites res:// paths, prefixes every
global class_name and autoload with the version id (Player -> V01Player, Events -> V01Events) so later
development can never change or collide with the frozen copy, and registers the version's autoloads.
Shared project-level contract that frozen versions rely on (never remove/rename): input actions,
physics layer numbers, shader globals cut_* / night_factor, window/stretch settings.
"""
import os
import re
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DIRS = ["scripts", "scenes", "shaders", "assets", "resources"]
TEXT_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc"}
SKIP_EXT = {".import", ".uid"}
# autoload name -> scripts/systems/<file>.gd (only those that exist in the build are registered)
AUTOLOADS = {"Events": "events", "GameTime": "game_time", "NoiseSystem": "noise", "Sfx": "sfx",
             "ItemDB": "item_db", "Settings": "game_settings"}


def split_code_strings(line):
    """Yield (is_code, text) segments; GDScript '#' comments count as non-code."""
    out, buf, i, quote = [], "", 0, None
    while i < len(line):
        ch = line[i]
        if quote:
            buf += ch
            if ch == "\\" and i + 1 < len(line):
                buf += line[i + 1]
                i += 2
                continue
            if ch == quote:
                out.append((False, buf))
                buf, quote = "", None
        elif ch in "\"'":
            if buf:
                out.append((True, buf))
            buf, quote = ch, ch
        elif ch == "#":
            if buf:
                out.append((True, buf))
            out.append((False, line[i:]))
            return out
        else:
            buf += ch
        i += 1
    if buf:
        out.append((quote is None, buf))
    return out


def rename_identifiers(src, mapping):
    pat = re.compile(r"(?<![\$%\w\.])\b(" + "|".join(map(re.escape, mapping)) + r")\b")
    # Also allow "Foo." member access after a dot? No: only bare identifiers (Foo, Foo.Kind) are renamed.
    lines = []
    for line in src.split("\n"):
        parts = []
        for is_code, text in split_code_strings(line):
            parts.append(pat.sub(lambda m: mapping[m.group(1)], text) if is_code else text)
        lines.append("".join(parts))
    return "\n".join(lines)


def main(vid):
    prefix = vid.upper()  # V01
    dest = os.path.join(ROOT, "versions", vid)
    if os.path.exists(dest):
        sys.exit("versions/%s already exists - frozen versions are never overwritten" % vid)
    files = []
    for d in DIRS:
        for base, _dirs, names in os.walk(os.path.join(ROOT, d)):
            for n in names:
                if os.path.splitext(n)[1] in SKIP_EXT:
                    continue
                src = os.path.join(base, n)
                rel = os.path.relpath(src, ROOT)
                dst = os.path.join(dest, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
                files.append(dst)
    classes = {}
    for f in files:
        if f.endswith(".gd"):
            m = re.search(r"^class_name\s+(\w+)", open(f, encoding="utf-8").read(), re.M)
            if m:
                classes[m.group(1)] = prefix + m.group(1)
    mapping = dict(classes)
    autoloads = {a: n for a, n in AUTOLOADS.items()
                 if os.path.exists(os.path.join(dest, "scripts", "systems", n + ".gd"))}
    for a in autoloads:
        mapping[a] = prefix + a
    res_prefix = "res://versions/%s/" % vid
    for f in files:
        if os.path.splitext(f)[1] not in TEXT_EXT:
            continue
        s = open(f, encoding="utf-8").read()
        for d in DIRS:
            s = s.replace("res://%s/" % d, res_prefix + d + "/")
        s = re.sub(r' uid="uid://[^"]*"', "", s)
        s = re.sub(r'script_class="(\w+)"', lambda m: 'script_class="%s"' % mapping.get(m.group(1), m.group(1)), s)
        if f.endswith(".gd"):
            s = rename_identifiers(s, mapping)
            s = re.sub(r"^class_name\s+(\w+)", lambda m: "class_name " + mapping.get(m.group(1), m.group(1)), s, flags=re.M)
        with open(f, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(s)
    # Register the version's own autoloads.
    pg = os.path.join(ROOT, "project.godot")
    txt = open(pg, encoding="utf-8").read()
    lines = "".join('%s%s="*%sscripts/systems/%s.gd"\n' % (prefix, a, res_prefix, n)
                    for a, n in autoloads.items())
    txt = txt.replace("[autoload]\n\n", "[autoload]\n\n" + lines, 1)
    open(pg, "w", encoding="utf-8", newline="\n").write(txt)
    print("frozen %d files into versions/%s; renamed %d classes + %d autoloads" % (len(files), vid, len(classes), len(autoloads)))


if __name__ == "__main__":
    main(sys.argv[1])
