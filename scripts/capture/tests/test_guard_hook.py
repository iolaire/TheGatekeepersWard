"""The security guard hook allows TCC.db only in scripts/capture/lib/tccdb.sh.

Validates: Requirements 13.1, 13.11, 17.1
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HOOK = ROOT / "scripts" / "hooks" / "guard-security-boundaries.py"
BODY = 'sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" "select 1"\n'


def run_hook(path, text=BODY, key="path"):
    payload = {"tool_name": "fs_write", "tool_input": {key: str(path), "text": text}}
    out = subprocess.run([sys.executable, str(HOOK)], input=json.dumps(payload),
                         capture_output=True, text=True, cwd=ROOT, check=True).stdout
    return json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out.strip() else None


def test_exact_path_relative_is_allowed():
    assert run_hook("scripts/capture/lib/tccdb.sh") is None


def test_exact_path_absolute_and_dotted_is_allowed():
    assert run_hook(ROOT / "scripts/capture/lib/tccdb.sh") is None
    assert run_hook("scripts/capture/lib/../lib/./tccdb.sh") is None
    assert run_hook(ROOT / "scripts/capture/lib/tccdb.sh", key="file_path") is None


def test_other_scripts_are_blocked():
    for p in ("scripts/capture/lib/reset.sh", "scripts/capture/capture.sh",
              "scripts/other/lib/tccdb.sh", "scripts/capture/lib/tccdb.sh.bak",
              "scripts/capture/lib/tccdb.py", "scripts/capture/lib/xtccdb.sh",
              "scripts/capture/lib/sub/tccdb.sh", "lib/tccdb.sh", "tccdb.sh",
              "/tmp/elsewhere/scripts/capture/lib/tccdb.sh"):
        assert run_hook(p) == "ask", p


def test_swift_file_still_blocked():
    assert run_hook("GatekeepersWard/Core/X.swift", 'let p = "TCC.db"\n') == "ask"


def test_exception_does_not_cover_private_tcc_api():
    assert run_hook("scripts/capture/lib/tccdb.sh", "TCCAccessRequest\n") is None  # not watched as .sh
    assert run_hook("scripts/capture/lib/tccdb.sh", "no database here\n") is None


def test_unrelated_script_without_tcc_reference_passes():
    assert run_hook("scripts/capture/lib/reset.sh", "echo hi\n") is None
