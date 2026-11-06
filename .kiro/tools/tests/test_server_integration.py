"""Wire-level integration test: start mcp_darwin_server.py, speak JSON-RPC 2.0
over stdio (Task 13). Skipped entirely when no macOS SDK is available."""
from __future__ import annotations

import json
import selectors
import subprocess
import sys
from pathlib import Path

import pytest

from conftest import TOOLS_DIR
from sdk_locator import SDKLocator, SDKUnavailableError

SERVER_SCRIPT = TOOLS_DIR / "mcp_darwin_server.py"
REQUEST_TIMEOUT_S = 30.0
NEXT_ID = iter(range(1, 1000))


def _sdk_available() -> bool:
    try:
        SDKLocator().locate()
        return True
    except SDKUnavailableError:
        return False


pytestmark = [
    pytest.mark.skipif(not _sdk_available(),
                       reason="macOS SDK unavailable (SDKUnavailableError) - CI guard"),
]


@pytest.fixture(scope="module")
def server():
    proc = subprocess.Popen(
        [sys.executable, str(SERVER_SCRIPT)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    sel = selectors.DefaultSelector()
    sel.register(proc.stdout, selectors.EVENT_READ)
    try:
        yield _Session(proc, sel)
    finally:
        proc.stdin.close()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
        sel.close()
        assert proc.returncode == 0, f"server exited with {proc.returncode}"


class _Session:
    def __init__(self, proc: subprocess.Popen, sel: selectors.DefaultSelector):
        self.proc = proc
        self.sel = sel

    def send(self, payload: dict) -> None:
        self.proc.stdin.write(json.dumps(payload) + "\n")
        self.proc.stdin.flush()

    def recv(self, timeout_s: float = REQUEST_TIMEOUT_S) -> dict | None:
        if not self.sel.select(timeout_s):
            raise AssertionError(f"server did not respond within {timeout_s}s")
        line = self.proc.stdout.readline()
        if not line:
            raise AssertionError("server closed stdout unexpectedly")
        return json.loads(line)

    def request(self, method: str, params: dict, notify: bool = False) -> dict | None:
        payload: dict = {"jsonrpc": "2.0", "method": method, "params": params}
        if not notify:
            payload["id"] = next(NEXT_ID)
        self.send(payload)
        return None if notify else self.recv()

    def tool_json(self, name: str, arguments: dict) -> dict:
        resp = self.request("tools/call", {"name": name, "arguments": arguments})
        assert "result" in resp, f"{name} call failed: {resp}"
        assert resp["result"].get("isError") is not True, f"{name} returned error: {resp}"
        text = resp["result"]["content"][0]["text"]
        return json.loads(text)

    def resource_text(self, uri: str) -> str:
        resp = self.request("resources/read", {"uri": uri})
        assert "result" in resp, f"read {uri} failed: {resp}"
        return resp["result"]["contents"][0]["text"]


@pytest.fixture(scope="module")
def session(server: _Session) -> _Session:
    resp = server.request("initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "integration-test", "version": "0"},
    })
    assert "result" in resp
    assert resp["result"]["serverInfo"]["name"] == "mcp-darwin-context"
    server.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
    return server


class TestResources:
    def test_darwin_headers_sysctl(self, session):
        data = json.loads(session.resource_text("darwin://headers/sysctl"))
        assert "sysctl" in data["content"]
        assert data["source_path"].endswith("sys/sysctl.h")
        assert isinstance(data["used_fallback"], bool)

    def test_darwin_headers_proc_info(self, session):
        data = json.loads(session.resource_text("darwin://headers/proc_info"))
        assert "proc_vnodepathinfo" in data["content"]
        assert data["source_path"].endswith("sys/proc_info.h")
        assert isinstance(data["used_fallback"], bool)

    def test_tcc_schema(self, session):
        data = json.loads(session.resource_text("tcc://schema"))
        assert data["source"] in ("live", "bundled")
        assert "CREATE TABLE access" in data["ddl"]

    def test_tcc_constants_services(self, session):
        data = json.loads(session.resource_text("tcc://constants/services"))
        assert isinstance(data, list)
        assert len(data) >= 13
        required = {
            "kTCCServiceSystemPolicyDocumentsFolder", "kTCCServiceCamera",
            "kTCCServiceAppleEvents", "kTCCServiceAccessibility",
        }
        keys = {entry["key"] for entry in data}
        assert required <= keys
        for entry in data:
            assert {"key", "display_name", "scope", "description",
                    "ui_prompt_label"} <= set(entry)
            assert entry["scope"] in ("user", "system", "both")

    def test_procargs2_layout_sections(self, session):
        text = session.resource_text("darwin://procargs2/layout")
        for section in ("## Byte Layout", "## Swift Code Example",
                        "## Parser Cautions"):
            assert section in text, f"missing section {section}"
        assert "CTL_KERN" in text and "KERN_PROCARGS2" in text
        assert "argc" in text


class TestTools:
    def test_lookup_tcc_service_found(self, session):
        data = session.tool_json("lookup_tcc_service", {"name": "kTCCServiceCamera"})
        assert data["found"] is True
        assert data["results"][0]["key"] == "kTCCServiceCamera"
        assert {"key", "display_name", "scope", "description",
                "ui_prompt_label"} <= set(data["results"][0])

    def test_lookup_tcc_service_empty_name(self, session):
        data = session.tool_json("lookup_tcc_service", {"name": ""})
        assert data["found"] is False
        assert data["error"]

    def test_get_darwin_struct_known(self, session):
        data = session.tool_json("get_darwin_struct",
                                 {"struct_name": "proc_vnodepathinfo"})
        assert data["found"] is True
        assert data["arm64_byte_size"] == 2352
        assert data["source_header"].endswith("sys/proc_info.h")
        assert data["fields"], "expected field table"
        for field in data["fields"]:
            assert {"name", "c_type", "byte_offset", "byte_size"} <= set(field)

    def test_get_darwin_struct_empty_name(self, session):
        data = session.tool_json("get_darwin_struct", {"struct_name": "  "})
        assert data["found"] is False
        assert data["error"]

    def test_search_darwin_headers(self, session):
        data = session.tool_json("search_darwin_headers",
                                 {"keyword": "KERN_PROCARGS2", "max_results": 5})
        assert data["total_matches"] >= 1
        assert data["timed_out"] is False
        assert len(data["results"]) <= 5
        match = data["results"][0]
        assert {"file", "line_number", "line_content", "context"} <= set(match)
        assert "KERN_PROCARGS2" in match["line_content"]

    def test_search_darwin_headers_validation_error(self, session):
        resp = session.request("tools/call", {
            "name": "search_darwin_headers",
            "arguments": {"keyword": "ab"},
        })
        assert "result" in resp
        assert resp["result"].get("isError") is True
        assert "at least 3 characters" in resp["result"]["content"][0]["text"]
