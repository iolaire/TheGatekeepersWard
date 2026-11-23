"""Shared harness for the permission capture framework tests.

Provides:
  * run_bash: runs a fixed bash snippet with values passed as arguments
    ("$@"), never spliced into the source.
  * make_repo / repo: a temporary copy of scripts/capture with stub binaries
    first on PATH and a call log.
  * Hypothesis strategies for IDs, prompt text, window rows, rectangles,
    button labels, manifests and file names.
  * skip_without_permission: skips a test that needs a macOS permission.

No test built on this harness needs Accessibility, Screen Recording or
Automation grants: every external binary is a stub.
"""

from __future__ import annotations

import os
import shutil
import sqlite3
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Mapping, Sequence

import pytest
from hypothesis import HealthCheck, settings
from hypothesis import strategies as st

TESTS_DIR = Path(__file__).resolve().parent
CAPTURE_SRC = TESTS_DIR.parent
STUB_NAMES = ("tccutil", "osascript", "screencapture", "pgrep", "open", "sqlite3", "pkill")

# Hypothesis profile, selected by the CAPTURE_PBT_PROFILE environment variable:
#   dev  (default): max_examples=10, pre-commit and local runs (under 1 minute with -n auto)
#   full:           max_examples=100, use before merging, e.g.
#                   CAPTURE_PBT_PROFILE=full pytest scripts/capture/tests
# Test files must not hard-code max_examples in @settings, or the profile
# stops controlling the count.
_CHECKS = [HealthCheck.function_scoped_fixture, HealthCheck.too_slow]
settings.register_profile("dev", max_examples=10, deadline=None, suppress_health_check=_CHECKS)
settings.register_profile("full", max_examples=100, deadline=None, suppress_health_check=_CHECKS)
settings.load_profile(os.environ.get("CAPTURE_PBT_PROFILE", "dev"))
# End-to-end property tests run the whole capture.sh or the real sqlite3 and
# osascript per example (about 10 s each under load), so they get far fewer
# examples in dev. Apply with @settings(max_examples=E2E_EXAMPLES).
E2E_EXAMPLES = 100 if os.environ.get("CAPTURE_PBT_PROFILE", "dev") == "full" else 2


# --------------------------------------------------------------------------
# Markers and skip helper
# --------------------------------------------------------------------------

def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line(
        "markers",
        "needs_macos_permission(name): test needs a real macOS permission "
        "(accessibility, screen-recording, automation) and is skipped without it",
    )


def skip_without_permission(permission: str) -> None:
    """Skip the calling test because it needs a macOS permission.

    The default suite never needs one. Set CAPTURE_TESTS_ALLOW_PERMISSIONS=1
    to run tests that call this helper (it then returns normally).
    """
    if os.environ.get("CAPTURE_TESTS_ALLOW_PERMISSIONS") == "1":
        return
    pytest.skip(f"requires macOS permission: {permission}")


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    if os.environ.get("CAPTURE_TESTS_ALLOW_PERMISSIONS") == "1":
        return
    for item in items:
        marker = item.get_closest_marker("needs_macos_permission")
        if marker is not None:
            name = marker.args[0] if marker.args else "unspecified"
            item.add_marker(pytest.mark.skip(reason=f"requires macOS permission: {name}"))


# --------------------------------------------------------------------------
# Temporary repo and bash runner
# --------------------------------------------------------------------------

@dataclass
class Repo:
    """A temporary copy of scripts/capture laid out as <root>/scripts/capture."""

    root: Path
    call_log: Path
    extra_env: dict[str, str] = field(default_factory=dict)

    @property
    def capture_dir(self) -> Path:
        return self.root / "scripts" / "capture"

    @property
    def lib_dir(self) -> Path:
        return self.capture_dir / "lib"

    @property
    def profiles_dir(self) -> Path:
        return self.capture_dir / "profiles"

    @property
    def stubs_dir(self) -> Path:
        return self.capture_dir / "tests" / "stubs"

    @property
    def captures_dir(self) -> Path:
        return self.root / "captures"

    def calls(self, name: str | None = None) -> list[list[str]]:
        """Logged stub calls as [name, arg1, ...]; optionally filtered by name."""
        if not self.call_log.exists():
            return []
        rows = []
        # Split on "\n" only: args may hold \r, \x0b and other line separators.
        text = self.call_log.read_bytes().decode("utf-8", errors="surrogateescape")
        for line in text.split("\n"):
            if not line:
                continue
            parts = [_unescape(p) for p in line.split("\t")]
            if name is None or parts[0] == name:
                rows.append(parts)
        return rows

    def write_profile(self, profile_id: str, text: str) -> Path:
        self.profiles_dir.mkdir(parents=True, exist_ok=True)
        path = self.profiles_dir / f"{profile_id}.profile"
        path.write_text(text)
        return path


def _unescape(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            out.append({"t": "\t", "n": "\n", "\\": "\\"}.get(s[i + 1], s[i + 1]))
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def make_repo(base: Path) -> Repo:
    """Copy scripts/capture into base/scripts/capture and make stubs executable."""
    root = base / "repo"
    dest = root / "scripts" / "capture"
    shutil.copytree(
        CAPTURE_SRC,
        dest,
        ignore=shutil.ignore_patterns("__pycache__", ".pytest_cache", "*.pyc"),
    )
    (root / "captures").mkdir()
    for stub in (dest / "tests" / "stubs").iterdir():
        stub.chmod(0o755)
    capture_sh = dest / "capture.sh"
    if capture_sh.exists():
        capture_sh.chmod(0o755)
    return Repo(root=root, call_log=base / "calls.log")


def run_bash(
    repo: Repo,
    snippet: str,
    *args: str,
    libs: Sequence[str] = ("common", "defaults"),
    env: Mapping[str, str] | None = None,
    stubs: bool = True,
    stdin: str | None = None,
    timeout: float = 60,
) -> subprocess.CompletedProcess[str]:
    """Run a fixed bash snippet after sourcing the named lib/*.sh files.

    Values go in `args` and are read in the snippet as "$1", "$@" and so on.
    They are never interpolated into the snippet source. With stubs=True the
    stub binaries come first on PATH and log to repo.call_log.
    """
    prelude = ['CAPTURE_DIR="$1"', 'CAPTURE_REPO_ROOT="$2"', "shift 2"]
    prelude.append("export CAPTURE_DIR CAPTURE_REPO_ROOT")
    for lib in libs:
        prelude.append(f'. "$CAPTURE_DIR/lib/{lib}.sh"')
    source = "\n".join(prelude) + "\n" + snippet
    full_env = dict(os.environ)
    full_env.update(repo.extra_env)
    if stubs:
        full_env["PATH"] = f"{repo.stubs_dir}{os.pathsep}{full_env.get('PATH', '')}"
        full_env["STUB_CALL_LOG"] = str(repo.call_log)
    if env:
        full_env.update(env)
    return subprocess.run(
        ["/bin/bash", "-c", source, "bash", str(repo.capture_dir), str(repo.root), *args],
        capture_output=True,
        text=True,
        input=stdin,
        env=full_env,
        timeout=timeout,
    )


def run_capture(
    repo: Repo,
    *args: str,
    env: Mapping[str, str] | None = None,
    stubs: bool = True,
    timeout: float = 60,
) -> subprocess.CompletedProcess[str]:
    """Run capture.sh with the stub PATH. All values are argv elements."""
    full_env = dict(os.environ)
    full_env.update(repo.extra_env)
    if stubs:
        full_env["PATH"] = f"{repo.stubs_dir}{os.pathsep}{full_env.get('PATH', '')}"
        full_env["STUB_CALL_LOG"] = str(repo.call_log)
    if env:
        full_env.update(env)
    return subprocess.run(
        ["/bin/bash", str(repo.capture_dir / "capture.sh"), *args],
        capture_output=True,
        text=True,
        env=full_env,
        cwd=repo.root,
        timeout=timeout,
    )


@pytest.fixture
def repo(tmp_path: Path) -> Repo:
    """A fresh temporary repo copy with stubs and an empty call log."""
    return make_repo(tmp_path)


# --------------------------------------------------------------------------
# Hypothesis strategies
# --------------------------------------------------------------------------

_LOWER_ALNUM = "abcdefghijklmnopqrstuvwxyz0123456789"

# Profile, scenario and service-style IDs: [a-z0-9-]+, starting with a letter.
ids = st.builds(
    lambda head, tail: head + tail,
    st.sampled_from("abcdefghijklmnopqrstuvwxyz"),
    st.text(alphabet=_LOWER_ALNUM + "-", min_size=0, max_size=20),
)
profile_ids = ids
scenario_names = ids

# Reverse-DNS bundle IDs such as dev.zcode.app.
bundle_ids = st.builds(
    lambda parts: ".".join(parts),
    st.lists(
        st.text(alphabet=_LOWER_ALNUM, min_size=1, max_size=10), min_size=2, max_size=4
    ),
)

tcc_services = st.sampled_from(
    [
        "SystemPolicyDesktopFolder",
        "SystemPolicyDocumentsFolder",
        "SystemPolicyDownloadsFolder",
        "SystemPolicyRemovableVolumes",
    ]
)

# Prompt text: printable Unicode including shell and AppleScript metacharacters,
# no control characters, no surrogates. A profile prompt is a single line.
_PROMPT_SPECIALS = " \"'`$\\;&|<>(){}[]*?!#~%\u2019\u00e9\u4e2d\U0001f47b"
prompt_text = st.text(
    alphabet=st.one_of(
        st.characters(
            blacklist_categories=("Cc", "Cs", "Zl", "Zp"),
            blacklist_characters="\x7f",
        ),
        st.sampled_from(list(_PROMPT_SPECIALS)),
    ),
    min_size=1,
    max_size=2000,
).filter(lambda s: s.strip() != "" and s == s.strip())

# Arbitrary argv-style text for quoting tests: anything but NUL.
argv_text = st.text(
    alphabet=st.characters(blacklist_categories=("Cs",), blacklist_characters="\x00"),
    min_size=0,
    max_size=200,
)

# Window rows as printed by windows.js list:
# <windowNumber> <owner> <layer> <alpha> <x> <y> <w> <h>
_OWNERS = st.one_of(
    st.sampled_from(
        ["UserNotificationCenter", "Gatekeeper's Ward", "Window Server", "Finder", "ZCode"]
    ),
    st.text(alphabet=_LOWER_ALNUM + "-_", min_size=1, max_size=15),
)


@st.composite
def window_rows(draw) -> dict:
    return {
        "number": draw(st.integers(1, 100000)),
        "owner": draw(_OWNERS),
        "layer": draw(st.integers(-5, 30)),
        "alpha": draw(st.sampled_from([0.0, 0.5, 0.9, 0.91, 1.0])),
        "x": draw(st.integers(-3000, 5000)),
        "y": draw(st.integers(-3000, 5000)),
        "w": draw(st.integers(0, 3000)),
        "h": draw(st.integers(0, 3000)),
    }


def format_window_row(row: Mapping) -> str:
    """Render a window row as one tab-separated windows.js list line."""
    return "\t".join(
        str(row[k]) for k in ("number", "owner", "layer", "alpha", "x", "y", "w", "h")
    )


def format_window_list(rows: Sequence[Mapping]) -> str:
    return "".join(format_window_row(r) + "\n" for r in rows)


window_lists = st.lists(window_rows(), min_size=0, max_size=12)


# Rectangles: x y w h with positive size, in points.
@st.composite
def rectangles(draw) -> tuple[int, int, int, int]:
    return (
        draw(st.integers(-500, 3000)),
        draw(st.integers(-500, 2000)),
        draw(st.integers(1, 1500)),
        draw(st.integers(1, 1500)),
    )


# Button labels, including curly apostrophes and case variants.
button_labels = st.one_of(
    st.sampled_from(
        [
            "OK",
            "Allow",
            "Don't Allow",
            "Don\u2019t Allow",
            "Deny",
            "ok",
            "ALLOW",
            "Cancel",
            "Allow Once",
        ]
    ),
    st.text(
        alphabet=st.characters(
            blacklist_categories=("Cc", "Cs", "Zl", "Zp"), blacklist_characters="\t"
        ),
        min_size=1,
        max_size=20,
    ),
)

# File names: plain relative names with no slash, NUL or leading dot-dot.
file_names = st.builds(
    lambda stem, ext: stem + ext,
    st.text(alphabet=_LOWER_ALNUM + "-_", min_size=1, max_size=15),
    st.sampled_from([".png", ".mov", ".mp4", ".log", ".json", ".md", ""]),
)

_ISO_S = st.builds(
    lambda y, mo, d, h, mi, s: f"{y:04d}-{mo:02d}-{d:02d}T{h:02d}:{mi:02d}:{s:02d}Z",
    st.integers(2026, 2030),
    st.integers(1, 12),
    st.integers(1, 28),
    st.integers(0, 23),
    st.integers(0, 59),
    st.integers(0, 59),
)
_ISO_MS = _ISO_S.map(lambda s: s[:-1] + ".123Z")

ward_commits = st.one_of(
    st.just("unknown"), st.text(alphabet="0123456789abcdef", min_size=40, max_size=40)
)


@st.composite
def manifests(draw) -> dict:
    """A valid manifest dict as in design.md "Manifest (manifest.json)"."""
    mode = draw(st.sampled_from(["baseline", "ward"]))
    outcome = draw(st.sampled_from(["ok", "no_prompt", "no_hud", "error"]))
    m: dict = {
        "profile_id": draw(profile_ids),
        "bundle_id": draw(bundle_ids),
        "scenario": draw(scenario_names),
        "mode": mode,
        "started_at": draw(_ISO_S),
        "ended_at": draw(_ISO_S),
        "macos_version": "27.2.1",
        "artifacts": draw(st.lists(file_names, min_size=0, max_size=50, unique=True)),
        "outcome": outcome,
        "prompt": {
            "detected_at": draw(_ISO_MS),
            "bounds": {"x": 640, "y": 220, "w": 260, "h": 282},
            "service_match": draw(st.sampled_from([True, False, "unknown"])),
            "resolution": draw(
                st.sampled_from(["dismissed", "still present", "skipped", "failed"])
            ),
        },
        "video": {
            "status": "ok",
            "bytes": draw(st.integers(1, 10**8)),
            "duration_s": draw(st.floats(0.1, 600, allow_nan=False)),
        },
        "reset_failed": draw(st.booleans()),
        "failed_step": None,
        "error": None,
    }
    if mode == "ward":
        m["ward_commit"] = draw(ward_commits)
        m["hud"] = {
            "detected_at": draw(_ISO_MS),
            "bounds": {"x": 910, "y": 220, "w": 400, "h": 410},
        }
    if outcome != "ok":
        m["failed_step"] = draw(
            st.sampled_from(["preflight", "app-launch", "prompt-detection", "screenshots"])
        )
        m["error"] = draw(
            st.text(
                alphabet=st.characters(blacklist_categories=("Cc", "Cs")),
                min_size=1,
                max_size=1000,
            ).filter(lambda s: s.strip() != "")
        )
    return m


# --------------------------------------------------------------------------
# TCC database fixtures (temporary database only, never the user database)
# --------------------------------------------------------------------------
# NOTE: Task 15 could not measure the real `access` columns on this macOS
# (the Capture_Host had no Full Disk Access). This column set is a PLAUSIBLE
# one, copied from the design's snapshot example. The code under test is
# schema-agnostic (it reads PRAGMA table_info(access)), so tests must not
# depend on this exact list beyond `service` and `client`.
ACCESS_COLUMNS = (
    "service",
    "client",
    "client_type",
    "auth_value",
    "auth_reason",
    "auth_version",
    "csreq",
    "policy_id",
    "indirect_object_identifier_type",
    "indirect_object_identifier",
    "indirect_object_code_identity",
    "flags",
    "last_modified",
)
ACCESS_SCHEMA = """
CREATE TABLE access (
    service TEXT NOT NULL,
    client TEXT NOT NULL,
    client_type INTEGER NOT NULL,
    auth_value INTEGER NOT NULL,
    auth_reason INTEGER NOT NULL,
    auth_version INTEGER NOT NULL,
    csreq BLOB,
    policy_id INTEGER,
    indirect_object_identifier_type INTEGER,
    indirect_object_identifier TEXT NOT NULL DEFAULT 'UNUSED',
    indirect_object_code_identity BLOB,
    flags INTEGER,
    last_modified INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (service, client, client_type, indirect_object_identifier)
)
"""
DECLARED_SERVICES = (
    "kTCCServiceSystemPolicyDesktopFolder",
    "kTCCServiceSystemPolicyRemovableVolumes",
)
UNDECLARED_SERVICES = ("kTCCServiceCamera", "kTCCServiceSystemPolicyDocumentsFolder")
REAL_TCC_MARKERS = ("com.apple.TCC", "/TCC.db")

AccessRow = dict  # column name -> None | int | str | bytes


def _row_key(row: Mapping) -> tuple:
    return (
        row["service"],
        row["client"],
        row["client_type"],
        row["indirect_object_identifier"],
    )


def _reject_real_db(path: Path) -> None:
    text = str(path)
    if any(m in text for m in REAL_TCC_MARKERS):
        raise AssertionError(f"test refuses to touch the real TCC database: {text}")


def create_access_db(path: Path, rows: Sequence[Mapping] = ()) -> Path:
    """(Re)create a temp database at path holding rows. Replaces any old file."""
    _reject_real_db(path)
    for suffix in ("", "-journal", "-wal", "-shm"):
        Path(str(path) + suffix).unlink(missing_ok=True)
    conn = sqlite3.connect(str(path))
    try:
        conn.execute(ACCESS_SCHEMA)
        marks = ",".join("?" for _ in ACCESS_COLUMNS)
        for row in rows:
            conn.execute(
                f"INSERT OR REPLACE INTO access ({','.join(ACCESS_COLUMNS)}) "
                f"VALUES ({marks})",
                [row[c] for c in ACCESS_COLUMNS],
            )
        conn.commit()
    finally:
        conn.close()
    return path


def read_access_rows(path: Path) -> list[tuple]:
    """Row reader independent of the code under test (Python sqlite3, read-only).

    Returns every row as a tuple in ACCESS_COLUMNS order, sorted by the
    primary key, with blobs as bytes and NULL as None.
    """
    _reject_real_db(path)
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        cur = conn.execute(
            f"SELECT {','.join(ACCESS_COLUMNS)} FROM access "
            "ORDER BY service, client, client_type, indirect_object_identifier"
        )
        return [tuple(r) for r in cur.fetchall()]
    finally:
        conn.close()


def scope_rows(rows: Sequence[tuple], bundle: str, services: Sequence[str]) -> list[tuple]:
    """Rows from read_access_rows whose client is bundle and service is declared."""
    s_i, c_i = ACCESS_COLUMNS.index("service"), ACCESS_COLUMNS.index("client")
    return [r for r in rows if r[c_i] == bundle and r[s_i] in services]


@dataclass
class TccDb:
    """A temporary access database selected through CAPTURE_TCC_DB_TEST."""

    path: Path

    @property
    def env(self) -> dict[str, str]:
        return {"CAPTURE_TCC_DB_TEST": str(self.path)}

    def reset(self, rows: Sequence[Mapping] = ()) -> "TccDb":
        create_access_db(self.path, rows)
        return self

    def read(self) -> list[tuple]:
        return read_access_rows(self.path)


# Cell strategies --------------------------------------------------------
_db_text = st.text(
    alphabet=st.one_of(
        st.characters(
            blacklist_categories=("Cs",), blacklist_characters="\x00", max_codepoint=0x2FFF
        ),
        st.sampled_from(list("'\"`;\\%_ \t") + ["\u00e9", "\u4e2d", "\U0001f47b"]),
    ),
    min_size=1,
    max_size=24,
)
_ascii_text = st.text(alphabet="abcdefghijklmnopqrstuvwxyz0123456789._-", min_size=1, max_size=16)
# csreq-like blobs: random bytes (any value, including 0x00), possibly empty.
_blob = st.one_of(st.none(), st.just(b""), st.binary(min_size=1, max_size=64))
_small_int = st.integers(0, 4)
_big_int = st.integers(-(2**63), 2**63 - 1)


@st.composite
def access_row(draw, client: str, service: str) -> AccessRow:
    """One access row for the given client and service."""
    return {
        "service": service,
        "client": client,
        "client_type": draw(st.sampled_from([0, 1])),
        "auth_value": draw(_small_int),
        "auth_reason": draw(_small_int),
        "auth_version": draw(st.integers(0, 2)),
        "csreq": draw(_blob),
        "policy_id": draw(st.one_of(st.none(), _small_int)),
        "indirect_object_identifier_type": draw(st.one_of(st.none(), _small_int)),
        "indirect_object_identifier": draw(st.one_of(st.just("UNUSED"), _db_text)),
        "indirect_object_code_identity": draw(_blob),
        "flags": draw(st.one_of(st.none(), _small_int)),
        "last_modified": draw(st.one_of(_big_int, st.integers(0, 2_000_000_000))),
    }


@st.composite
def access_tables(
    draw,
    bundle: str,
    declared: Sequence[str] = DECLARED_SERVICES,
    undeclared: Sequence[str] = UNDECLARED_SERVICES,
    max_rows: int = 4,
) -> list[AccessRow]:
    """A generated database: rows for the bundle in declared services, the
    bundle in undeclared services, other bundle IDs, and the client `All`.
    Rows are unique on the table's primary key (last one wins).
    """
    others = draw(st.lists(bundle_ids.filter(lambda b: b != bundle), min_size=1, max_size=3))
    groups = [
        (bundle, list(declared)),
        (bundle, list(undeclared)),
        ("All", list(declared) + list(undeclared)),
    ] + [(o, list(declared) + list(undeclared)) for o in others]
    rows: dict[tuple, AccessRow] = {}
    for client, services in groups:
        n = draw(st.integers(0, max_rows))
        for _ in range(n):
            row = draw(access_row(client, draw(st.sampled_from(services))))
            rows[_row_key(row)] = row
    return list(rows.values())


@pytest.fixture
def tcc_db(tmp_path: Path, repo: Repo) -> TccDb:
    """An empty temp access database, exported as CAPTURE_TCC_DB_TEST.

    The path is resolved and lives under the system temporary directory.
    Call tcc_db.reset(rows) to refill it between Hypothesis examples. The
    repo's extra_env carries CAPTURE_TCC_DB_TEST so run_bash and run_capture
    pass it on. Nothing here opens the user database.
    """
    path = (tmp_path.resolve() / "tcc-test" / "TCC-test.sqlite")
    path.parent.mkdir()
    db = TccDb(path).reset([])
    repo.extra_env.update(db.env)
    return db
