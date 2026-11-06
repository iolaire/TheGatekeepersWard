#!/usr/bin/env python3
"""Build-time generator for StructParser.KNOWN_STRUCTS.

Parses `clang -Xclang -fdump-record-layouts` output (arm64) for the five
required Darwin structs and extracts the raw struct definition text from the
SDK headers, then emits JSON suitable for embedding in struct_parser.py.

Usage:
    cc -arch arm64 -Xclang -fdump-record-layouts -c probe.c -o probe.o > dump.txt
    python3 gen_known_structs.py dump.txt [out.json]

probe.c:
    #include <sys/proc_info.h>
    #include <sys/sysctl.h>
    struct proc_vnodepathinfo a;
    struct vnode_info_path b;
    struct kinfo_proc c;
    struct extern_proc d;
    struct proc_bsdinfo e;

Field-table conventions (must match StructParser._flatten_ast):
- Named/anonymous nested structs in a non-union context are flattened with
  dot-notation names; offsets are absolute from the outermost struct.
- Direct members of a union all share the union's base offset and are marked
  in_union=True. Struct/union-typed union members are kept WHOLE (not
  flattened) so that "all in_union fields share one offset" holds.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SDK = Path("/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")

TARGETS = {
    "proc_vnodepathinfo": "sys/proc_info.h",
    "vnode_info_path": "sys/proc_info.h",
    "kinfo_proc": "sys/sysctl.h",
    "extern_proc": "sys/proc.h",
    "proc_bsdinfo": "sys/proc_info.h",
}

SIZES = {
    "char": 1, "unsigned char": 1, "signed char": 1,
    "short": 2, "unsigned short": 2,
    "int": 4, "unsigned int": 4,
    "long": 8, "unsigned long": 8,
    "int8_t": 1, "uint8_t": 1, "int16_t": 2, "uint16_t": 2,
    "int32_t": 4, "uint32_t": 4, "int64_t": 8, "uint64_t": 8,
    "uid_t": 4, "gid_t": 4, "pid_t": 4, "dev_t": 4, "off_t": 8,
    "caddr_t": 8, "segsz_t": 4, "fixpt_t": 4, "sigset_t": 4,
    "u_char": 1, "u_short": 2, "u_int": 4, "u_long": 8,
    "u_quad_t": 8, "quad_t": 8, "boolean_t": 4,
    "__darwin_time_t": 8, "__darwin_suseconds_t": 4,
    "time_t": 8, "suseconds_t": 4, "size_t": 8, "ssize_t": 8,
    "intptr_t": 8, "uintptr_t": 8, "natural_t": 4, "kern_return_t": 4,
}

LINE_RE = re.compile(r"^\s*(\d+)\s*\|\s?(.*)$")


def parse_dump(text: str) -> dict[str, dict]:
    records: dict[str, dict] = {}
    for block in text.split("*** Dumping AST Record Layout"):
        lines: list[tuple[int, str, int]] = []
        sizeof = align = None
        for line in block.splitlines():
            m = re.search(r"\[sizeof=(\d+), align=(\d+)\]", line)
            if m:
                sizeof, align = int(m.group(1)), int(m.group(2))
                continue
            m = LINE_RE.match(line)
            if not m:
                continue
            rest = m.group(2)
            indent = len(rest) - len(rest.lstrip(" "))
            lines.append((indent, rest.strip(), int(m.group(1))))
        if not lines:
            continue
        name = _member_name(lines[0][1])
        records[name] = {
            "members": _parse_block(lines, 1, 2),
            "sizeof": sizeof,
            "align": align,
        }
    return records


def _member_name(decl: str) -> str:
    if decl.startswith(("struct", "union")):
        m = re.match(r"^(?:struct|union)\s+\S+\s+([A-Za-z_]\w*)$", decl)
        if m:
            return m.group(1)
        m = re.match(r"^(?:struct|union)\s+(\S+)$", decl)
        if m:
            return m.group(1).split("::")[0]
    return ""


def _parse_block(lines: list[tuple[int, str, int]], start: int, indent: int) -> list[dict]:
    out: list[dict] = []
    i = start
    while i < len(lines):
        line_indent, decl, offset = lines[i]
        if line_indent < indent:
            break
        if line_indent > indent:
            raise ValueError(f"unexpected deeper line: {decl}")
        kind, type_str, name = _classify(decl)
        node: dict = {"kind": kind, "type": type_str, "name": name, "offset": offset}
        if kind in ("struct", "union"):
            node["members"] = _parse_block(lines, i + 1, indent + 2)
            i = _skip_block(lines, i + 1, indent)
        else:
            i += 1
        out.append(node)
    return out


def _skip_block(lines: list[tuple[int, str, int]], start: int, indent: int) -> int:
    i = start
    while i < len(lines) and lines[i][0] > indent:
        i += 1
    return i


def _classify(decl: str) -> tuple[str, str, str]:
    kw = decl.split()[0]
    if kw in ("struct", "union"):
        rest = decl[len(kw):].strip()
        m = re.search(r"([A-Za-z_]\w*)$", rest)
        name = m.group(1) if m else ""
        head = rest[: len(rest) - (len(name) + 1 if name else 0)].strip()
        if head and "*" not in head:
            if "::" in head:
                return kw, "<anonymous>", name
            return kw, head.split(" ")[0], name
        if not head and not name:
            # root-style declaration without a member name
            return kw, rest.split("::")[0], ""
    # plain field (scalar, pointer, array): trailing token is the name
    m = re.search(r"([A-Za-z_]\w*)$", decl)
    name = m.group(1) if m else ""
    type_str = decl[: len(decl) - len(name)].strip() if name else decl
    return "field", type_str, name


def _align_up(v: int, a: int) -> int:
    return (v + a - 1) // a * a


def _scalar_size(type_str: str) -> int:
    if type_str.endswith("*"):
        return 8
    size = SIZES.get(type_str)
    if size is None:
        raise KeyError(f"unknown scalar size for {type_str!r}")
    return size


def _field_size_align(type_str: str) -> tuple[int, int]:
    m = re.match(r"^(.*?)\[(\d+)\]$", type_str)
    if m:  # array
        elem = m.group(1).strip()
        if elem.endswith("*"):
            return int(m.group(2)) * 8, 8
        size = _scalar_size(elem)
        return size * int(m.group(2)), min(size, 8)
    size = _scalar_size(type_str)
    return size, min(size, 8)


def size_align(node: dict) -> tuple[int, int]:
    """Compute (size, align) of a struct/union node from its member list."""
    base = node["members"][0]["offset"] if node["members"] else 0
    size, align = 0, 1
    for mem in node["members"]:
        if mem["kind"] in ("struct", "union"):
            m_size, m_align = size_align(mem)
        else:
            m_size, m_align = _field_size_align(mem["type"])
        align = max(align, m_align)
        end = mem["offset"] - base + m_size
        size = max(size, end)
    return _align_up(size, align), align


def render_type(node: dict) -> str:
    """Render the c_type string for a kept-whole struct/union member."""
    kw = node["kind"]
    type_name = node["type"]
    if type_name and type_name != "<anonymous>":
        return f"{kw} {type_name}"
    inner = " ".join(_render_member(m) for m in node["members"])
    return f"{kw} {{ {inner} }}"


def _render_member(mem: dict) -> str:
    if mem["kind"] in ("struct", "union"):
        return f"{render_type(mem)} {mem['name']};"
    m = re.match(r"^(.*?)\[(\d+)\]$", mem["type"])
    if m:
        return f"{m.group(1).strip()} {mem['name']}[{m.group(2)}];"
    return f"{mem['type']} {mem['name']};"


def flatten(node: dict, prefix: str, base_offset: int, in_union: bool, out: list) -> None:
    # NOTE: dump offsets are absolute from the root record start, so nested
    # struct members are flattened without adding base_offset again.
    for mem in node["members"]:
        name = f"{prefix}.{mem['name']}" if prefix and mem["name"] else (mem["name"] or prefix)
        if mem["kind"] == "union":
            u_offset = mem["offset"]
            for u_mem in mem["members"]:
                u_name = f"{name}.{u_mem['name']}" if u_mem["name"] else name
                if u_mem["kind"] in ("struct", "union"):
                    m_size, _ = size_align(u_mem)
                    out.append({
                        "name": u_name, "c_type": render_type(u_mem),
                        "byte_offset": u_mem["offset"], "byte_size": m_size, "in_union": True,
                    })
                else:
                    m_size, _ = _field_size_align(u_mem["type"])
                    out.append({
                        "name": u_name, "c_type": u_mem["type"],
                        "byte_offset": u_mem["offset"], "byte_size": m_size, "in_union": True,
                    })
        elif mem["kind"] == "struct":
            flatten(mem, name, base_offset, in_union, out)
        else:
            m_size, _ = _field_size_align(mem["type"])
            out.append({
                "name": name, "c_type": mem["type"],
                "byte_offset": mem["offset"], "byte_size": m_size,
                "in_union": in_union,
            })


def extract_definition(header_rel: str, struct_name: str) -> str:
    text = (SDK / "usr" / "include" / header_rel).read_text(encoding="utf-8")
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i = text.index("*/", i) + 2
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            i = text.index("\n", i)
        elif c == "#":  # skip preprocessor line
            j = text.find("\n", i)
            i = j + 1 if j != -1 else n
        elif c == "s" and text.startswith(f"struct {struct_name}", i):
            m = re.match(r"struct\s+" + re.escape(struct_name) + r"\s*\{", text[i:])
            if m:
                start = i
                depth = 0
                j = i + m.end() - 1
                while j < n:
                    c = text[j]
                    if c == "/" and text[j + 1: j + 2] == "*":
                        j = text.index("*/", j) + 1
                    elif c == "{":
                        depth += 1
                    elif c == "}":
                        depth -= 1
                        if depth == 0:
                            end = text.index(";", j)
                            return " ".join(text[start: end + 1].split())
                    j += 1
                raise SystemExit(f"unbalanced braces for {struct_name}")
            i += 1
        else:
            i += 1
    raise SystemExit(f"struct {struct_name} not found in {header_rel}")


def main() -> None:
    dump_path = Path(sys.argv[1])
    records = parse_dump(dump_path.read_text())
    result: dict[str, dict] = {}
    for name, header in TARGETS.items():
        rec = records[name]
        fields: list[dict] = []
        flatten(rec, "", 0, False, fields)
        result[name] = {
            "header": header,
            "definition": extract_definition(header, name),
            "arm64_byte_size": rec["sizeof"],
            "fields": fields,
        }
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("known_structs.json")
    out.write_text(json.dumps(result, indent=2))
    print(f"wrote {out}: " + ", ".join(
        f"{k}={v['arm64_byte_size']}B/{len(v['fields'])}f" for k, v in result.items()))


if __name__ == "__main__":
    main()
