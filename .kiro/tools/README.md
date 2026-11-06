# mcp-darwin-context — local MCP server

Serves macOS Darwin SDK headers, TCC service-key data, and the
`KERN_PROCARGS2` buffer layout as MCP resources/tools over stdio.

## Environment setup (uv venv)

This tool uses a uv-managed virtual environment checked into the workspace at
`.kiro/tools/.venv` (git-ignored). To recreate it elsewhere:

```sh
# from the workspace root
uv venv .kiro/tools/.venv --python 3.12
VIRTUAL_ENV=.kiro/tools/.venv uv pip install -r .kiro/tools/requirements.txt
```

Or with plain pip, without uv:

```sh
python3 -m venv .kiro/tools/.venv
.kiro/tools/.venv/bin/python -m pip install -r .kiro/tools/requirements.txt
```

The interpreter used by `.kiro/settings/mcp.json` is
`.kiro/tools/.venv/bin/python` (relative to the workspace root).

## Run tests

```sh
.kiro/tools/.venv/bin/python -m pytest .kiro/tools/tests/ -q
```

## Run the server directly

```sh
.kiro/tools/.venv/bin/python .kiro/tools/mcp_darwin_server.py
```
