"""Shared test fixtures for the mcp-darwin-context test suite (Task 11)."""
from __future__ import annotations

import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
TESTS_DIR = Path(__file__).resolve().parent
for _p in (TOOLS_DIR, TESTS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

import pytest  # noqa: E402

from header_reader import HeaderReader  # noqa: E402
from sdk_locator import SDKPath  # noqa: E402

BUNDLED_DATA_PATH = TOOLS_DIR / "resources" / "tcc_services.json"
WORKSPACE_ROOT = Path(__file__).resolve().parents[3]
TCC_EVENT_SWIFT_PATH = WORKSPACE_ROOT / "GatekeepersWard" / "Permissions" / "TCCEvent.swift"


@pytest.fixture()
def tmp_sdk_dir(tmp_path: Path) -> Path:
    """A minimal fake SDK tree with stub .h files exercising HeaderReader and
    HeaderSearchEngine without requiring Xcode."""
    include = tmp_path / "usr" / "include"
    (include / "sys").mkdir(parents=True)
    (include / "mach").mkdir(parents=True)
    (include / "sys" / "sysctl.h").write_text(
        "#define CTL_KERN 1\n"
        "#define KERN_PROC 14\n"
        "#define KERN_PROCARGS 38\n"
        "#define KERN_PROCARGS2 49\n"
        "struct kinfo_proc {\n"
        "    struct extern_proc kp_proc;\n"
        "};\n",
        encoding="utf-8",
    )
    (include / "sys" / "proc_info.h").write_text(
        "#define MAXPATHLEN 1024\n"
        "struct proc_vnodepathinfo {\n"
        "    char pvi_path[MAXPATHLEN];\n"
        "};\n"
        "struct proc_bsdinfo {\n"
        "    unsigned int pbi_flags;\n"
        "    unsigned int pbi_pid;\n"
        "};\n",
        encoding="utf-8",
    )
    (include / "sys" / "proc.h").write_text(
        "struct extern_proc {\n"
        "    union {\n"
        "        struct {\n"
        "            struct proc *p_forw;\n"
        "            struct proc *p_back;\n"
        "        } p_st1;\n"
        "        int p_flag_placeholder;\n"
        "    } p_un;\n"
        "    int p_flag;\n"
        "    char p_stat;\n"
        "};\n",
        encoding="utf-8",
    )
    (include / "mach" / "mach_types.h").write_text(
        "typedef int kern_return_t;\n"
        "#define KERN_SUCCESS 0\n"
        "typedef int mach_msg_type_number_t;\n",
        encoding="utf-8",
    )
    return tmp_path


@pytest.fixture()
def fake_sdk(tmp_sdk_dir: Path) -> SDKPath:
    return SDKPath(root=tmp_sdk_dir, used_fallback=False)


@pytest.fixture()
def mock_header_reader(fake_sdk: SDKPath) -> HeaderReader:
    """A HeaderReader backed by tmp_sdk_dir."""
    return HeaderReader(fake_sdk)


# Raw C struct definition strings for the five required structs. Each entry is
# self-contained: by-value dependency structs are declared before the target
# struct so parse_struct_text can resolve them. Used by the property-based
# tests (Properties 1, 7, 8).
_VINFO_STAT_FIELDS = (
    "uint32_t vst_dev; uint16_t vst_mode; uint16_t vst_nlink; uint64_t vst_ino; "
    "uid_t vst_uid; gid_t vst_gid; int64_t vst_atime; int64_t vst_atimensec; "
    "int64_t vst_mtime; int64_t vst_mtimensec; int64_t vst_ctime; int64_t vst_ctimensec; "
    "int64_t vst_birthtime; int64_t vst_birthtimensec; int64_t vst_size; "
    "int64_t vst_blocks; int32_t vst_blksize; uint32_t vst_flags; uint32_t vst_gen; "
    "uint32_t vst_rdev; int64_t vst_qspare[2];"
)

_VNODE_INFO_FIELDS = (
    f"struct {{ {_VINFO_STAT_FIELDS} }} vi_stat; int vi_type; int vi_pad; "
    "struct { int32_t val[2]; } vi_fsid;"
)

_VNODE_INFO_PATH_BODY = (
    f"struct {{ {_VNODE_INFO_FIELDS} }} vip_vi; char vip_path[1024];"
)

_EXTERN_PROC_DEF = (
    "struct timeval { int64_t tv_sec; int32_t tv_usec; }; "
    "struct itimerval { struct timeval it_interval; struct timeval it_value; }; "
    "struct extern_proc { "
    "union { struct { struct proc *__p_forw; struct proc *__p_back; } p_st1; "
    "struct timeval __p_starttime; } p_un; "
    "struct vmspace *p_vmspace; struct sigacts *p_sigacts; "
    "int p_flag; char p_stat; pid_t p_pid; pid_t p_oppid; int p_dupfd; "
    "char *user_stack; void *exit_thread; int p_debugger; boolean_t sigwait; "
    "unsigned int p_estcpu; int p_cpticks; fixpt_t p_pctcpu; void *p_wchan; "
    "char *p_wmesg; unsigned int p_swtime; unsigned int p_slptime; "
    "struct itimerval p_realtimer; struct timeval p_rtime; "
    "u_quad_t p_uticks; u_quad_t p_sticks; u_quad_t p_iticks; "
    "int p_traceflag; struct vnode *p_tracep; int p_siglist; "
    "struct vnode *p_textvp; int p_holdcnt; sigset_t p_sigmask; "
    "sigset_t p_sigignore; sigset_t p_sigcatch; unsigned char p_priority; "
    "unsigned char p_usrpri; char p_nice; char p_comm[17]; "
    "struct pgrp *p_pgrp; struct user *p_addr; unsigned short p_xstat; "
    "unsigned short p_acflag; struct rusage *p_ru; };"
)

_KINFO_PROC_DEF = (
    _EXTERN_PROC_DEF + " struct kinfo_proc { struct extern_proc kp_proc; "
    "struct eproc { struct proc *e_paddr; struct session *e_sess; "
    "struct { char pc_lock[72]; struct ucred *pc_ucred; uid_t p_ruid; "
    "uid_t p_svuid; gid_t p_rgid; gid_t p_svgid; int p_refcnt; } e_pcred; "
    "struct { int32_t cr_ref; uid_t cr_uid; int16_t cr_ngroups; "
    "gid_t cr_groups[16]; } e_ucred; "
    "struct { int32_t dummy; char *dummy2; int32_t dummy3[5]; char *dummy4[3]; } e_vm; "
    "pid_t e_ppid; pid_t e_pgid; int16_t e_jobc; dev_t e_tdev; pid_t e_tpgid; "
    "struct session *e_tsess; char e_wmesg[8]; segsz_t e_xsize; int16_t e_xrssize; "
    "int16_t e_xccount; int16_t e_xswrss; int32_t e_flag; char e_login[12]; "
    "int32_t e_spare[4]; } kp_eproc; };"
)

KNOWN_STRUCT_DEFINITIONS: list[str] = [
    # proc_vnodepathinfo
    f"struct proc_vnodepathinfo {{ struct {{ {_VNODE_INFO_PATH_BODY} }} pvi_cdir; "
    f"struct {{ {_VNODE_INFO_PATH_BODY} }} pvi_rdir; }};",
    # vnode_info_path
    f"struct vnode_info_path {{ {_VNODE_INFO_PATH_BODY} }};",
    # kinfo_proc
    _KINFO_PROC_DEF,
    # extern_proc
    _EXTERN_PROC_DEF,
    # proc_bsdinfo
    "struct proc_bsdinfo { uint32_t pbi_flags; uint32_t pbi_status; "
    "uint32_t pbi_xstatus; uint32_t pbi_pid; uint32_t pbi_ppid; uid_t pbi_uid; "
    "gid_t pbi_gid; uid_t pbi_ruid; gid_t pbi_rgid; uid_t pbi_svuid; "
    "gid_t pbi_svgid; uint32_t rfu_1; char pbi_comm[16]; char pbi_name[32]; "
    "uint32_t pbi_nfiles; uint32_t pbi_pgid; uint32_t pbi_pjobc; uint32_t e_tdev; "
    "uint32_t e_tpgid; int32_t pbi_nice; uint64_t pbi_start_tvsec; "
    "uint64_t pbi_start_tvusec; };",
]

UNION_CONTAINING_STRUCT_DEFINITIONS: list[str] = [
    _KINFO_PROC_DEF,
    _EXTERN_PROC_DEF,
]


@pytest.fixture()
def known_struct_definitions() -> list[str]:
    return list(KNOWN_STRUCT_DEFINITIONS)


@pytest.fixture()
def union_containing_struct_definitions() -> list[str]:
    return list(UNION_CONTAINING_STRUCT_DEFINITIONS)
