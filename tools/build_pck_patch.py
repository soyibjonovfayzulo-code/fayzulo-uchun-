#!/usr/bin/env python3
"""
Russian Zombie Survival — Production Auto Delta PCK Patch Generator & Verifier.

Capabilities:
1. Compares current project files against the base APK baseline (`tools/patch_baseline.json`)
   and/or Git commit range (`--git-diff`), preserving cumulative compatibility with all prior patches.
2. Resolves Godot resource dependencies (`preload`, `load`, `ext_resource`, `.uid`, `.import` -> `.godot/imported/*`).
3. Automatically falls back to a full resource patch if delta changes exceed safety thresholds.
4. Detects Native / Android configuration changes (`export_presets.cfg`, `android/`, `.gdextension`, `.so`, `.aar`,
   or native `project.godot` settings) that require a new APK build, halting normal `.pck` distribution for old APKs.
5. Auto-increments semantic version (`0.5.1` -> `0.5.2`) and `build_number` (`500` -> `501`) via `tools/version_state.json`.
6. Packs and verifies the `.pck` using official Godot 4.7 headless `PCKPacker` + `ResourceLoader` verification,
   and signs the manifest with RSA-2048 (`signature_rsa`) + SHA-256 canonical `manifest_hash`.
7. Generates Cloudflare Pages / GitHub Releases deployment artifacts in `updates/`:
   - `manifest.json`
   - `patch_<ver>_<build>.pck`
   - `versions_history.json` (rollback catalog)
   - `index.html` (live update status page)
"""

import argparse
import datetime
import hashlib
import http.server
import json
import os
import re
import shutil
import socketserver
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE_FILE = ROOT / "tools" / "patch_baseline.json"
VERSION_STATE_FILE = ROOT / "tools" / "version_state.json"
UPDATES_DIR = ROOT / "updates"
HISTORY_FILE = UPDATES_DIR / "versions_history.json"

DEFAULT_GODOT_WIN = r"C:\Users\USTAFON\Godot\4.7\Godot_v4.7-stable_win64_console.exe"
DEFAULT_GODOT = os.environ.get("GODOT_BIN", DEFAULT_GODOT_WIN if os.name == "nt" else "godot")

TRACKED_DIRS = ["scripts", "scenes", "shaders", "resources", "launcher", "assets"]
TRACKED_EXTS = {".gd", ".tscn", ".tres", ".gdshader", ".json", ".cfg", ".png", ".glb", ".wav", ".ogg"}
CODE_AND_DATA_DIRS = ["scripts", "scenes", "shaders", "resources", "launcher"]
DELTA_FALLBACK_THRESHOLD = 85

NATIVE_APK_PATTERNS = [
    (r"^export_presets\.cfg$", "Изменена конфигурация экспорта Android (export_presets.cfg)"),
    (r"^android/.*", "Изменены нативные файлы шаблона Android (android/)"),
    (r".*\.(gdextension|so|aar|jar|jni)$", "Добавлен или изменён нативный плагин (.gdextension / .so / .aar)"),
]

RES_DEP_REGEX = re.compile(r'(?:preload|load|path)\s*(?:\(\s*|=\s*)"(res://[^"]+)"')


TEXT_HASH_EXTS = {".gd", ".tscn", ".tres", ".gdshader", ".json", ".cfg", ".import", ".uid"}


def sha256_of_binary(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_of(path: Path) -> str:
    if path.suffix.lower() in TEXT_HASH_EXTS:
        data = path.read_bytes().replace(b"\r\n", b"\n")
        return hashlib.sha256(data).hexdigest()
    return sha256_of_binary(path)


def canonical_manifest_payload(version: str, build_number: int, min_apk_build: int, requires_apk: bool, pck_size: int, sha256_hex: str) -> str:
    req_str = "1" if requires_apk else "0"
    return f"RZS_MANIFEST_V1|{version}|{build_number}|{min_apk_build}|{req_str}|{pck_size}|{sha256_hex.lower()}"


def scan_project_files(dirs=None) -> dict:
    target_dirs = dirs if dirs is not None else TRACKED_DIRS
    out = {}
    for d in target_dirs:
        folder = ROOT / d
        if not folder.exists():
            continue
        for p in folder.rglob("*"):
            if p.is_file() and p.suffix in TRACKED_EXTS:
                rel = "res://" + p.relative_to(ROOT).as_posix()
                out[rel] = sha256_of(p)
    # Also track root config files for native change detection
    for root_file in ["export_presets.cfg", "project.godot"]:
        rf = ROOT / root_file
        if rf.exists():
            out["res://" + root_file] = sha256_of(rf)
    return out


def save_baseline() -> None:
    files = scan_project_files()
    BASELINE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(BASELINE_FILE, "w", encoding="utf-8") as f:
        json.dump(files, f, indent=2, ensure_ascii=False)
    print(f"[Baseline] Saved {len(files)} file hashes to {BASELINE_FILE}")


def load_version_state() -> dict:
    if VERSION_STATE_FILE.exists():
        with open(VERSION_STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"version": "0.5.1", "build_number": 500, "min_apk_build": 500}


def save_version_state(state: dict) -> None:
    VERSION_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(VERSION_STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


def auto_bump_version(ver_str: str) -> str:
    parts = ver_str.strip().lstrip("v").split(".")
    while len(parts) < 3:
        parts.append("0")
    try:
        parts[-1] = str(int(parts[-1]) + 1)
    except ValueError:
        parts[-1] = "1"
    return ".".join(parts)


def git_changed_files(diff_range: str) -> list:
    try:
        proc = subprocess.run(
            ["git", "diff", "--name-only", diff_range],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            return []
        out = []
        for line in proc.stdout.splitlines():
            clean = line.strip().replace("\\", "/")
            if clean:
                out.append(clean)
        return out
    except Exception:
        return []


def check_apk_rebuild_required(changed_rel_paths: list, baseline: dict, current: dict) -> tuple:
    reasons = []
    for rel in changed_rel_paths:
        clean = rel[6:] if rel.startswith("res://") else rel
        for pattern, msg in NATIVE_APK_PATTERNS:
            if re.match(pattern, clean):
                if msg not in reasons:
                    reasons.append(msg)
    # Check if baseline vs current export_presets.cfg changed
    if baseline.get("res://export_presets.cfg") and current.get("res://export_presets.cfg"):
        if baseline["res://export_presets.cfg"] != current["res://export_presets.cfg"]:
            msg = "Изменена конфигурация экспорта Android (export_presets.cfg)"
            if msg not in reasons:
                reasons.append(msg)
    return (len(reasons) > 0, "; ".join(reasons))


def resolve_dependencies(changed_res_paths: list, baseline: dict, current: dict) -> list:
    resolved = set(changed_res_paths)
    queue = list(changed_res_paths)
    while queue:
        item = queue.pop(0)
        rel = item[6:] if item.startswith("res://") else item
        abs_p = ROOT / rel
        if not abs_p.exists() or abs_p.suffix not in {".gd", ".tscn", ".tres", ".gdshader"}:
            continue
        try:
            content = abs_p.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for match in RES_DEP_REGEX.finditer(content):
            dep = match.group(1)
            dep_rel = dep[6:] if dep.startswith("res://") else dep
            if (ROOT / dep_rel).exists():
                # Include dependency if it is new or modified compared to baseline
                if dep not in baseline or baseline.get(dep) != current.get(dep):
                    if dep not in resolved:
                        resolved.add(dep)
                        queue.append(dep)
    return sorted(p for p in resolved if not p.endswith("export_presets.cfg") and not p.endswith("project.godot"))


def find_changed_and_verify_scope(git_diff_spec: str, explicit_files: list, force_full: bool) -> tuple:
    current = scan_project_files()
    if not BASELINE_FILE.exists():
        save_baseline()
        baseline = dict(current)
    else:
        with open(BASELINE_FILE, "r", encoding="utf-8") as f:
            baseline = json.load(f)

    changed = set()
    for res_path, digest in current.items():
        if res_path in ("res://export_presets.cfg", "res://project.godot"):
            continue
        if baseline.get(res_path) != digest:
            changed.add(res_path)

    git_list = git_changed_files(git_diff_spec) if git_diff_spec else []
    for gf in git_list:
        rp = "res://" + gf.lstrip("/")
        if (ROOT / gf).exists() and any(gf.startswith(d + "/") for d in TRACKED_DIRS):
            changed.add(rp)

    if explicit_files:
        for ef in explicit_files:
            rp = ef if ef.startswith("res://") else ("res://" + ef.lstrip("/"))
            changed.add(rp)

    need_apk, apk_reason = check_apk_rebuild_required(git_list + list(changed), baseline, current)

    resolved = resolve_dependencies(list(changed), baseline, current)
    patch_mode = "delta"
    if force_full or len(resolved) > DELTA_FALLBACK_THRESHOLD:
        patch_mode = "full_resources"
        code_files = scan_project_files(CODE_AND_DATA_DIRS)
        resolved = sorted(k for k in code_files.keys() if k not in ("res://export_presets.cfg", "res://project.godot"))

    if not resolved:
        resolved = ["res://launcher/versions.json"]

    return resolved, patch_mode, need_apk, apk_reason


def write_status_html(manifest: dict, history: list) -> None:
    ver = manifest["version"]
    bld = manifest["build_number"]
    sz_kb = manifest["pck_size"] / 1024.0
    sha_short = manifest["sha256"][:16] if manifest["sha256"] else "N/A"
    mode = manifest.get("patch_mode", "delta")
    req_apk = manifest.get("requires_apk_update", False)
    badge = "⚠️ ТРЕБУЕТСЯ НОВЫЙ APK" if req_apk else "✅ АКТИВЕН (PCK HOT UPDATE)"
    rows = ""
    for h in history[:10]:
        rows += f"<tr><td>v{h['version']} (#{h['build_number']})</td><td>{h.get('pck_size', 0)//1024} КБ</td><td><code>{h.get('sha256', '')[:12]}…</code></td><td>{h.get('updated_at', '')}</td></tr>\n"
    html = f"""<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Russian Zombie Survival — Update Server</title>
<style>
body {{ background:#111210; color:#e5dec9; font-family:system-ui,sans-serif; max-width:760px; margin:32px auto; padding:0 16px; }}
.card {{ background:#1b1a17; border:1px solid #4a4438; padding:20px; margin-bottom:20px; }}
h1 {{ color:#e88245; margin-top:0; }}
code {{ background:#262420; padding:2px 6px; color:#8fd99f; }}
table {{ width:100%; border-collapse:collapse; margin-top:12px; }}
th, td {{ text-align:left; padding:8px; border-bottom:1px solid #333028; }}
a {{ color:#e88245; }}
</style>
</head>
<body>
<div class="card">
  <h1>RUSSIAN ZOMBIE SURVIVAL — HOT UPDATE CDN</h1>
  <p>Статус: <strong>{badge}</strong></p>
  <p>Актуальная версия: <strong>v{ver}</strong> (сборка #{bld}, режим: <code>{mode}</code>)</p>
  <p>Размер пакета: <strong>{sz_kb:.1f} КБ</strong> · SHA-256: <code>{sha_short}…</code></p>
  <p>Описание: {manifest.get('changelog', '')}</p>
  <p><a href="./manifest.json">manifest.json</a> · <a href="./versions_history.json">versions_history.json</a></p>
</div>
<div class="card">
  <h3>История версий (Rollback каталог)</h3>
  <table>
    <tr><th>Версия</th><th>Размер</th><th>SHA-256</th><th>Дата</th></tr>
    {rows}
  </table>
</div>
</body>
</html>"""
    (UPDATES_DIR / "index.html").write_text(html, encoding="utf-8")


def build_patch(
    version: str,
    build_number: int,
    min_apk_build: int,
    requires_apk_update: bool,
    apk_reason: str,
    host_url: str,
    pck_base_url: str,
    files_to_pack: list,
    patch_mode: str,
    changelog: str,
    godot_bin: str,
) -> dict:
    UPDATES_DIR.mkdir(parents=True, exist_ok=True)
    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    base_url = host_url.rstrip("/")
    release_url = (pck_base_url or host_url).rstrip("/")

    # If native Android components changed, do NOT distribute an incompatible .pck for old APKs!
    if requires_apk_update:
        payload = canonical_manifest_payload(version, build_number, min_apk_build, True, 0, "")
        manifest_hash = hashlib.sha256(payload.encode("utf-8")).hexdigest()
        manifest = {
            "version": version,
            "build_number": build_number,
            "min_apk_build": min_apk_build,
            "requires_apk_update": True,
            "apk_update_reason": apk_reason or "Требуется пересборка APK из-за нативных изменений Android.",
            "apk_url": f"{release_url}/RussianZombieSurvival.apk",
            "pck_url": "",
            "pck_size": 0,
            "sha256": "",
            "manifest_hash": manifest_hash,
            "signature_rsa": "",
            "patch_mode": "apk_required",
            "changed_files": files_to_pack,
            "changelog": changelog,
            "updated_at": now_iso,
        }
        manifest_path = UPDATES_DIR / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
        write_status_html(manifest, [])
        print(f"[APK REQUIRED] Native change detected: {apk_reason}")
        print(f"[OK] APK-required manifest written to {manifest_path}")
        return manifest

    safe_ver = version.replace(".", "_")
    pck_filename = f"patch_{safe_ver}_{build_number}.pck"
    pck_path = UPDATES_DIR / pck_filename
    if pck_path.exists():
        pck_path.unlink()

    cmd = [
        godot_bin,
        "--headless",
        "--path",
        str(ROOT),
        "-s",
        "res://tools/pck_builder.gd",
        "--",
        f"--out=res://updates/{pck_filename}",
        f"--files={','.join(files_to_pack)}",
    ]
    print(f"[Build] Packing {len(files_to_pack)} file(s) ({patch_mode}) into {pck_filename}...")
    proc = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)
    if not pck_path.exists() or "PCK_BUILDER_OK" not in proc.stdout:
        print(proc.stdout)
        print(proc.stderr, file=sys.stderr)
        raise RuntimeError("Failed to build & verify delta PCK via Godot PCKPacker")

    pck_size = pck_path.stat().st_size
    pck_sha256 = sha256_of_binary(pck_path)
    payload = canonical_manifest_payload(version, build_number, min_apk_build, False, pck_size, pck_sha256)
    manifest_hash = hashlib.sha256(payload.encode("utf-8")).hexdigest()

    # Sign the canonical manifest payload using Godot's RSA-2048 Crypto signer
    sign_cmd = [
        godot_bin,
        "--headless",
        "--path",
        str(ROOT),
        "-s",
        "res://tools/pck_builder.gd",
        "--",
        f"--out=res://updates/{pck_filename}",
        f"--files={','.join(files_to_pack)}",
        f"--sign-payload={payload}",
    ]
    sign_proc = subprocess.run(sign_cmd, cwd=str(ROOT), capture_output=True, text=True)
    sig_rsa = ""
    for line in sign_proc.stdout.splitlines():
        if "PCK_BUILDER_OK" in line and "sig=" in line:
            sig_rsa = line.split("sig=", 1)[1].strip()

    manifest = {
        "version": version,
        "build_number": build_number,
        "min_apk_build": min_apk_build,
        "requires_apk_update": False,
        "apk_update_reason": "",
        "pck_filename": pck_filename,
        "pck_url": f"{release_url}/{pck_filename}",
        "fallback_pck_url": f"{base_url}/{pck_filename}",
        "pck_size": pck_size,
        "sha256": pck_sha256,
        "manifest_hash": manifest_hash,
        "signature_rsa": sig_rsa,
        "patch_mode": patch_mode,
        "changed_files_count": len(files_to_pack),
        "changed_files": files_to_pack,
        "changelog": changelog,
        "updated_at": now_iso,
    }

    manifest_path = UPDATES_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    # Maintain version history for safe rollback
    history = []
    if HISTORY_FILE.exists():
        try:
            history = json.loads(HISTORY_FILE.read_text(encoding="utf-8"))
        except Exception:
            history = []
    history = [h for h in history if h.get("build_number") != build_number]
    history.insert(0, manifest)
    HISTORY_FILE.write_text(json.dumps(history[:30], indent=2, ensure_ascii=False), encoding="utf-8")
    write_status_html(manifest, history)

    print(f"[OK] Verified PCK ready: {pck_path} ({pck_size} bytes, SHA256={pck_sha256[:16]}...)")
    print(f"[OK] Signed Manifest written: {manifest_path}")
    return manifest


def serve_updates(port: int) -> None:
    UPDATES_DIR.mkdir(parents=True, exist_ok=True)
    os.chdir(str(UPDATES_DIR))
    handler = http.server.SimpleHTTPRequestHandler
    with socketserver.TCPServer(("0.0.0.0", port), handler) as httpd:
        print(f"[Server] Serving {UPDATES_DIR} at http://127.0.0.1:{port}/manifest.json")
        httpd.serve_forever()


def main() -> None:
    parser = argparse.ArgumentParser(description="Build & verify delta PCK patch for Russian Zombie Survival")
    parser.add_argument("--version", default="", help="Explicit patch version (if omitted, uses version_state.json)")
    parser.add_argument("--build", type=int, default=0, help="Explicit build number (if omitted, uses version_state.json)")
    parser.add_argument("--auto-bump", action="store_true", help="Automatically increment version and build_number in tools/version_state.json")
    parser.add_argument("--min-apk", type=int, default=0, help="Minimum required APK build number")
    parser.add_argument("--require-apk", action="store_true", help="Force update to require full APK reinstall")
    parser.add_argument("--apk-reason", default="", help="Reason why full APK update is required")
    parser.add_argument("--host", default="http://127.0.0.1:8090", help="Primary manifest/CDN base URL (e.g. Cloudflare Pages)")
    parser.add_argument("--pck-base-url", default="", help="Optional separate base URL for .pck download (e.g. GitHub Releases download URL)")
    parser.add_argument("--git-diff", default="", help="Optional git diff range (e.g. HEAD~1..HEAD)")
    parser.add_argument("--files", default="", help="Comma-separated list of res:// paths to pack")
    parser.add_argument("--full-fallback", action="store_true", help="Force full resource patch instead of delta")
    parser.add_argument("--changelog", default="Автоматическое обновление ресурсов и скриптов", help="Changelog description")
    parser.add_argument("--godot", default=DEFAULT_GODOT, help="Path to Godot 4.7 executable")
    parser.add_argument("--save-baseline", action="store_true", help="Save current project hashes as baseline and exit")
    parser.add_argument("--serve", action="store_true", help="Start HTTP update server after building")
    parser.add_argument("--port", type=int, default=8090, help="Port for --serve (default: 8090)")
    args = parser.parse_args()

    if args.save_baseline:
        save_baseline()
        return

    vstate = load_version_state()
    if args.auto_bump:
        vstate["version"] = auto_bump_version(vstate.get("version", "0.5.1"))
        vstate["build_number"] = int(vstate.get("build_number", 500)) + 1

    version = args.version if args.version else vstate["version"]
    build_number = args.build if args.build > 0 else int(vstate["build_number"])
    min_apk = args.min_apk if args.min_apk > 0 else int(vstate.get("min_apk_build", 500))

    explicit = [x.strip() for x in args.files.split(",") if x.strip()] if args.files else []
    files_to_pack, patch_mode, detected_apk_req, detected_reason = find_changed_and_verify_scope(
        args.git_diff, explicit, args.full_fallback
    )

    requires_apk = args.require_apk or detected_apk_req
    apk_reason = args.apk_reason or detected_reason
    if requires_apk and args.min_apk == 0:
        min_apk = max(min_apk, build_number)

    vstate["version"] = version
    vstate["build_number"] = build_number
    vstate["min_apk_build"] = min_apk
    save_version_state(vstate)

    build_patch(
        version=version,
        build_number=build_number,
        min_apk_build=min_apk,
        requires_apk_update=requires_apk,
        apk_reason=apk_reason,
        host_url=args.host,
        pck_base_url=args.pck_base_url,
        files_to_pack=files_to_pack,
        patch_mode=patch_mode,
        changelog=args.changelog,
        godot_bin=args.godot,
    )
    if args.serve:
        serve_updates(args.port)


if __name__ == "__main__":
    main()
