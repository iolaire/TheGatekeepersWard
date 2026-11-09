#!/usr/bin/env python3
"""PreToolUse guard for .kiro/steering/macos-security-boundaries.md.

Reads the Kiro hook JSON on stdin. If a write to a Swift/plist/entitlements
file introduces something the steering forbids, prints a permissionDecision of
"ask" so the user confirms. Anything else passes silently (exit 0).
Never blocks outright: the human decides.
"""
import json
import re
import sys

WATCHED = re.compile(r"(\.swift|\.entitlements|\.plist)$")

RULES = [
    (r"com\.apple\.private\.", "restricted private entitlement"),
    (r"com\.apple\.security\.(?!app-sandbox)", "new com.apple.security.* entitlement (needs a /// justification)"),
    (r"allow-jit|disable-library-validation", "Hardened Runtime weakening"),
    (r"\btask_for_pid\b|\bvm_read\b|\bPT_ATTACH\b|\bptrace\s*\(", "debugger-class API (task_for_pid / vm_read / ptrace)"),
    (r"\bcsrutil\b|\bkext\b|\bDriverKit\b|\bSystemExtensions\b", "SIP bypass or kernel/driver extension"),
    (r"TCC\.db|TCCAccessRequest|TCC\.framework", "direct TCC database or private TCC API"),
    (r"\bAXUIElement\w*", "synthetic input / accessibility clicks (ignored by TCC dialogs)"),
    (r"\bSIGSTOP\b|\bSIGKILL\b|\bSIGTERM\b|\bkill\s*\(", "signalling an inspected process (we are read-only)"),
    (r"/private/var/db/", "reading protected /private/var/db paths"),
]


def strings(node):
    if isinstance(node, dict):
        for v in node.values():
            yield from strings(v)
    elif isinstance(node, list):
        for v in node:
            yield from strings(v)
    elif isinstance(node, str):
        yield node


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0
    tool_input = payload.get("tool_input", payload) if isinstance(payload, dict) else {}
    path = ""
    for key in ("path", "file_path", "filePath", "targetFile"):
        if isinstance(tool_input, dict) and isinstance(tool_input.get(key), str):
            path = tool_input[key]
            break
    if not WATCHED.search(path):
        return 0

    # Only inspect the text being written, not the path field itself.
    body = "\n".join(
        s for k, v in (tool_input.items() if isinstance(tool_input, dict) else [])
        if k not in ("path", "file_path", "filePath", "targetFile", "oldStr") for s in strings(v)
    )
    # Ignore comment-only mentions so docs explaining a ban do not trigger it.
    code = "\n".join(l for l in body.splitlines() if not l.strip().startswith("//"))

    reasons = [why for pat, why in RULES if re.search(pat, code)]
    if "styleMask" in code and "nonactivatingPanel" not in code and "NSPanel" in body + path:
        reasons.append("NSPanel styleMask without .nonactivatingPanel (would steal focus from Apple's dialog)")
    if not reasons:
        return 0

    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason":
            "Security boundary check for " + path + ": " + "; ".join(reasons)
            + ". See .kiro/steering/macos-security-boundaries.md.",
    }}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
