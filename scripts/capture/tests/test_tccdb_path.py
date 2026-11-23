"""Property 35: Database path guard.
**Validates: Requirements 17.1, 17.2**
Drives lib/tccdb.sh tcc_path_ok through bash. Every path lives under a temp
directory. tcc_path_ok only resolves symlinks, so no database is opened, and
the system-level path is passed as a string only.
"""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

from conftest import Repo, run_bash

LIBS = ("common", "defaults", "validate", "profile", "reset", "tccdb")
TCC_REL = "Library/Application Support/com.apple.TCC/TCC.db"
SYSTEM_DB = "/Library/Application Support/com.apple.TCC/TCC.db"

KINDS = (
    "user_db",
    "user_db_link",
    "other_home_db",
    "tmp_plain",
    "tmp_nested",
    "tmp_dotdot_inside",
    "tmp_dotdot_escape",
    "tmp_root",
    "tmp_link_out_file",
    "tmp_link_out_dir",
    "outside",
    "prefix_sibling",
    "system",
)

names = st.text(alphabet="abcdefghijklmnopqrstuvwxyz0123456789._-", min_size=1, max_size=12).filter(
    lambda s: s not in (".", "..")
)


def _guard(repo: Repo, candidate: str, home: str, tmpdir: str, test_env: str):
    return run_bash(
        repo,
        'tcc_path_ok "$@"',
        candidate,
        home,
        tmpdir,
        test_env,
        libs=LIBS,
        env={"CAPTURE_TCC_DB_TEST": ""},
    )


def _build(base: Path, kind: str, name: str, home_link: bool, tmp_link: bool, exists: bool):
    """Create the layout and return (candidate, home_arg, tmp_arg)."""
    real_home = base / "real_home"
    (real_home / TCC_REL).parent.mkdir(parents=True)
    real_tmp = base / "real_tmp"
    (real_tmp / "sub").mkdir(parents=True)
    outside = base / "outside"
    outside.mkdir()
    other = base / "other"
    (other / TCC_REL).parent.mkdir(parents=True)
    evil = base / "real_tmp_evil"
    evil.mkdir()

    home_arg = real_home
    if home_link:
        home_arg = base / "home"
        home_arg.symlink_to(real_home)
    tmp_arg = real_tmp
    if tmp_link:
        tmp_arg = base / "tmp"
        tmp_arg.symlink_to(real_tmp)

    if exists:
        (real_home / TCC_REL).write_bytes(b"")
    (outside / name).write_bytes(b"")

    if kind == "user_db":
        cand = home_arg / TCC_REL
    elif kind == "user_db_link":
        (real_home / TCC_REL).write_bytes(b"")
        (real_tmp / "lnk").symlink_to(real_home / TCC_REL)
        cand = tmp_arg / "lnk"
    elif kind == "other_home_db":
        cand = other / TCC_REL
    elif kind == "tmp_plain":
        cand = tmp_arg / name
    elif kind == "tmp_nested":
        cand = tmp_arg / "sub" / name
    elif kind == "tmp_dotdot_inside":
        cand = Path(f"{tmp_arg}/sub/../{name}")
    elif kind == "tmp_dotdot_escape":
        cand = Path(f"{tmp_arg}/sub/../../outside/{name}")
    elif kind == "tmp_root":
        cand = tmp_arg
    elif kind == "tmp_link_out_file":
        (real_tmp / "lnk").symlink_to(outside / name)
        cand = tmp_arg / "lnk"
    elif kind == "tmp_link_out_dir":
        (real_tmp / "dlnk").symlink_to(outside)
        cand = Path(f"{tmp_arg}/dlnk/{name}")
    elif kind == "outside":
        cand = outside / name
    elif kind == "prefix_sibling":
        cand = evil / name
    else:
        cand = Path(SYSTEM_DB)
    return str(cand), str(home_arg), str(tmp_arg)


def _expected(candidate: str, home: str, tmpdir: str, test_env: str) -> bool:
    """Oracle written with os.path.realpath, independent of the bash code."""
    rc = os.path.realpath(candidate)
    user_db = os.path.realpath(os.path.join(os.path.realpath(home), TCC_REL))
    if rc == user_db:
        return True
    rt = os.path.realpath(tmpdir)
    return bool(test_env) and rt != "/" and rc.startswith(rt + "/") and len(rc) > len(rt) + 1


# Feature: permission-capture-framework, Property 35: Database path guard
@settings(suppress_health_check=[HealthCheck.function_scoped_fixture], deadline=None)
@given(
    kind=st.sampled_from(KINDS),
    name=names,
    home_link=st.booleans(),
    tmp_link=st.booleans(),
    exists=st.booleans(),
    env_set=st.booleans(),
)
def test_path_ok_iff_user_db_or_inside_temp_with_variable(
    repo: Repo, tmp_path: Path, kind, name, home_link, tmp_link, exists, env_set
) -> None:
    base = Path(tempfile.mkdtemp(dir=tmp_path)).resolve()
    cand, home, tmpdir = _build(base, kind, name, home_link, tmp_link, exists)
    test_env = cand if env_set else ""
    res = _guard(repo, cand, home, tmpdir, test_env)
    want = _expected(cand, home, tmpdir, test_env)
    assert (res.returncode == 0) == want, (kind, cand, home, tmpdir, test_env, res.stderr)
    if want:
        assert res.stderr == ""
    else:
        assert res.returncode == 1
        assert "refusing database path" in res.stderr
    # Spec examples that must hold regardless of the oracle.
    if kind in ("system", "outside", "prefix_sibling", "tmp_link_out_file", "tmp_link_out_dir",
                "tmp_dotdot_escape", "other_home_db", "tmp_root"):
        assert res.returncode == 1, (kind, cand)
    if kind in ("user_db", "user_db_link"):
        assert res.returncode == 0, (kind, cand)
    assert repo.calls("sqlite3") == []


def test_system_db_refused_with_and_without_variable(repo: Repo, tmp_path: Path) -> None:
    home = tmp_path.resolve() / "home"
    (home / TCC_REL).parent.mkdir(parents=True)
    tmpdir = tmp_path.resolve() / "t"
    tmpdir.mkdir()
    for env in ("", SYSTEM_DB):
        res = _guard(repo, SYSTEM_DB, str(home), str(tmpdir), env)
        assert res.returncode == 1
        assert SYSTEM_DB in res.stderr
