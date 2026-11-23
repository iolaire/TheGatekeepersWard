"""Property 22: Preflight reports every failure.

For any subset of the three preflight conditions (permissions present, target
app installed, display awake and unlocked) set to fail by stubs, the preflight
step runs all three checks, prints a message naming exactly the failed ones,
exits non-zero when the subset is non-empty, and runs no later step. For the
empty subset it passes. The permissions condition covers five permissions
including full-disk-access (probed read-only through a temporary database);
with --no-restore it covers four and never opens a database.

**Validates: Requirements 12.7, 12.8**
"""
from __future__ import annotations

from pathlib import Path

from hypothesis import given, strategies as st

from conftest import bundle_ids, create_access_db, run_bash

PERMCHECK_PERMS = ["accessibility", "screen-recording", "automation-system-events", "automation-finder"]
FDA = "full-disk-access"
PERMS = PERMCHECK_PERMS + [FDA]

PERMCHECK = """#!/bin/sh
printf 'perm\\t%s\\t%s\\n' "$1" "$2" >>"$STUB_CALL_LOG"
if [ "$1" = status ] && [ -f "$PERM_DIR/$2" ]; then echo granted; else echo missing; fi
"""

# Distinguishes the two preflight.js probes by their verb argument.
OSASCRIPT = """#!/usr/bin/env bash
. "$(dirname "$0")/_stub_common.sh"
stub_log_call osascript "$@"
case " $* " in
  *" installed "*) [ "$PRE_INSTALLED" = 1 ] && echo true || echo false ;;
  *" display "*) [ "$PRE_DISPLAY" = 1 ] && echo true || echo false ;;
esac
exit 0
"""

SNIPPET = 'S_MODE=baseline; S_BUNDLE="$1"; CAPTURE_DRY_RUN=0; OPT_NO_RESTORE="$2"; step_preflight; echo "rc=$?"'
LIBS = ("common", "defaults", "tccdb", "setup", "ward", "runner_steps")

failure_sets = st.fixed_dictionaries(
    {
        "perms": st.booleans(),
        "app": st.booleans(),
        "display": st.booleans(),
    }
)


@given(
    fail=failure_sets,
    missing_perms=st.sets(st.sampled_from(PERMS), min_size=1),
    bundle=bundle_ids,
    no_restore=st.booleans(),
)
def test_preflight_runs_all_checks_and_names_every_failure(
    repo, tmp_path, fail, missing_perms, bundle, no_restore
):
    root = repo.root
    repo.call_log.unlink(missing_ok=True)
    pdir = root / "perm"
    pdir.mkdir(exist_ok=True)
    for p in PERMS:
        (pdir / p).unlink(missing_ok=True)
    missing = missing_perms if fail["perms"] else set()
    # Permissions the preflight actually checks: FDA is left out with --no-restore.
    checked = [p for p in PERMS if not (no_restore and p == FDA)]
    # With --no-restore a missing-FDA-only subset is not a failure.
    perms_fail = fail["perms"] and any(p in checked for p in missing)
    for p in PERMCHECK_PERMS:
        if p not in missing:
            (pdir / p).write_text("granted\n")
    # Full Disk Access is probed through a temporary database: granted when it
    # is readable, missing when the path does not exist. Never the real one.
    dbdir = tmp_path.resolve() / "fda"
    dbdir.mkdir(exist_ok=True)
    db = dbdir / "TCC-test.sqlite"
    db.unlink(missing_ok=True)
    if FDA not in missing:
        create_access_db(db)
    permcheck = root / "permcheck.sh"
    permcheck.write_text(PERMCHECK)
    permcheck.chmod(0o755)
    osa = repo.stubs_dir / "osascript"
    osa.write_text(OSASCRIPT)
    osa.chmod(0o755)

    result = run_bash(
        repo,
        SNIPPET,
        bundle,
        "1" if no_restore else "0",
        libs=LIBS,
        env={
            "CAPTURE_TCC_DB_TEST": str(db),
            "CAPTURE_PERMCHECK": str(permcheck),
            "PERM_DIR": str(pdir),
            "PRE_INSTALLED": "0" if fail["app"] else "1",
            "PRE_DISPLAY": "0" if fail["display"] else "1",
        },
    )

    # All three checks always run; Full Disk Access is a read-only sqlite3 probe.
    assert len(repo.calls("perm")) == len(PERMCHECK_PERMS)
    probe_calls = [c for c in repo.calls("sqlite3") if "-readonly" in c]
    # A missing database path fails the probe before sqlite3 runs.
    expect_probe = 0 if (no_restore or FDA in missing) else 1
    assert len(probe_calls) == expect_probe, probe_calls
    assert all("-readonly" in c for c in repo.calls("sqlite3"))
    probes = [c for c in repo.calls("osascript") if "preflight.js" in " ".join(c)]
    verbs = sorted(c[-2] if c[-2] in ("installed", "display") else c[-1] for c in probes)
    assert verbs == ["display", "installed"], probes

    fail = {**fail, "perms": perms_fail}
    any_fail = any(fail.values())
    err = result.stderr
    # Message names exactly the failed conditions.
    assert ("permissions missing" in err) == fail["perms"], err
    assert ("target app not installed" in err) == fail["app"], err
    assert ("display is asleep" in err) == fail["display"], err
    if fail["perms"]:
        for p in PERMS:
            assert (p in err) == (p in missing and p in checked), err
        assert ("Full Disk Access: open System Settings" in err) == (FDA in missing and FDA in checked), err

    if any_fail:
        assert "rc=1" in result.stdout, result.stdout
        assert "preflight failed" in err
        # No later work: the mode setup (ward_ensure -> pgrep) never ran.
        assert repo.calls("pgrep") == []
    else:
        assert "rc=0" in result.stdout, (result.stdout, err)
        assert err == ""


def test_preflight_names_an_absent_user_database_and_points_to_no_restore(repo, tmp_path):
    """Probe exit 3 is not a missing permission: no pane hint, --no-restore advice."""
    root = repo.root
    pdir = root / "perm"
    pdir.mkdir(exist_ok=True)
    for p in PERMCHECK_PERMS:
        (pdir / p).write_text("granted\n")
    permcheck = root / "permcheck.sh"
    permcheck.write_text(PERMCHECK)
    permcheck.chmod(0o755)
    osa = repo.stubs_dir / "osascript"
    osa.write_text(OSASCRIPT)
    osa.chmod(0o755)
    nodb = tmp_path.resolve() / "no-such-dir" / "TCC-test.sqlite"
    result = run_bash(
        repo,
        SNIPPET,
        "dev.zcode.app",
        "0",
        libs=LIBS,
        env={
            "CAPTURE_TCC_DB_TEST": str(nodb),
            "CAPTURE_PERMCHECK": str(permcheck),
            "PERM_DIR": str(pdir),
            "PRE_INSTALLED": "1",
            "PRE_DISPLAY": "1",
        },
    )
    err = result.stderr
    assert "rc=1" in result.stdout, (result.stdout, err)
    assert "no user TCC database on this macOS" in err and "use --no-restore" in err, err
    assert "permissions missing" not in err
    assert "Full Disk Access" not in err
