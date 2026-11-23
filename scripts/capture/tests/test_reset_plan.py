"""Property 6: Reset plan is scoped to one bundle and the profile's services.

**Validates: Requirements 3.1, 3.3, 3.4, 3.8, 10.7**

For any App_Profile and any --service argument, reset_plan prints one
`tccutil reset <service> <bundle_id>` per distinct profile service in
declaration order when no service is given, exactly one command for a listed
service, and an error naming the service and the valid services with zero
commands for an unlisted one. Every command carries the profile's own bundle.
"""

from __future__ import annotations

from pathlib import Path

from hypothesis import given, strategies as st

from conftest import Repo, bundle_ids, ids, run_bash, scenario_names, tcc_services

LIBS = ("common", "defaults", "validate", "profile", "reset")

# Services may repeat across scenarios; the plan lists each distinct one once.
service_names = st.one_of(tcc_services, ids)


@st.composite
def cases(draw) -> dict:
    names = draw(st.lists(scenario_names, min_size=1, max_size=10, unique=True))
    services = [draw(service_names) for _ in names]
    distinct = list(dict.fromkeys(services))
    kind = draw(st.sampled_from(["none", "listed", "unlisted"]))
    if kind == "listed":
        service = draw(st.sampled_from(distinct))
    elif kind == "unlisted":
        service = draw(service_names.filter(lambda s: s not in distinct))
    else:
        service = None
    return {
        "bundle": draw(bundle_ids),
        "names": names,
        "services": services,
        "distinct": distinct,
        "kind": kind,
        "service": service,
    }


def render(case: dict) -> str:
    lines = [f"bundle_id = {case['bundle']}"]
    for name, svc in zip(case["names"], case["services"]):
        lines.append(f"scenario.{name}.prompt = hello")
        lines.append(f"scenario.{name}.service = {svc}")
    return "\n".join(lines) + "\n"


def test_reset_plan_scope(tmp_path: Path, repo: Repo) -> None:
    path = tmp_path / "p.profile"

    @given(case=cases())
    def check(case: dict) -> None:
        path.write_text(render(case), encoding="utf-8")
        args = [str(path)]
        if case["service"] is not None:
            args += ["--service", case["service"]]
        res = run_bash(repo, 'reset_plan "$@"', *args, libs=LIBS)
        lines = [ln for ln in res.stdout.split("\n") if ln]
        bundle = case["bundle"]

        if case["kind"] == "none":
            assert res.returncode == 0, res.stderr
            assert lines == [f"tccutil reset {s} {bundle}" for s in case["distinct"]]
        elif case["kind"] == "listed":
            assert res.returncode == 0, res.stderr
            assert lines == [f"tccutil reset {case['service']} {bundle}"]
        else:
            assert res.returncode == 2
            assert lines == []
            assert case["service"] in res.stderr
            for s in case["distinct"]:
                assert s in res.stderr
            assert ", ".join(case["distinct"]) in res.stderr

        # Scope: every command is a tccutil reset of a profile service for the
        # profile's own bundle; never "All", never another bundle.
        for ln in lines:
            parts = ln.split(" ")
            assert parts[:2] == ["tccutil", "reset"] and len(parts) == 4
            assert parts[2] in case["distinct"]
            assert parts[3] == bundle

    check()
