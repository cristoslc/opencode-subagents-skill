"""Unit-test the permission allowlist without going through the model."""

import asyncio
import sys
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
from unittest.mock import MagicMock

DISPATCH = str(Path(__file__).resolve().parent.parent / "bin" / "dispatch-opencode")
loader = SourceFileLoader("ocd", DISPATCH)
spec = spec_from_loader("ocd", loader)
ocd = module_from_spec(spec)
sys.modules["ocd"] = ocd  # <-- needed for @dataclass
loader.exec_module(ocd)

target = Path("/tmp/sandbox/src/calc.py")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("placeholder\n")

# A stub AcpClient with no session_id, so HTTP-probe paths return None
# and the handler falls through to its empty-command branch.
stub_client = MagicMock()
stub_client.session_id = None
stub_client.acp_url = ""

single_file_fix_cases = [
    (
        "read",
        {
            "toolCall": {
                "kind": "read",
                "title": "read",
                "rawInput": {"filepath": "/tmp/sandbox/some/other.py"},
            }
        },
        "once",
    ),
    (
        "search",
        {
            "toolCall": {
                "kind": "search",
                "title": "search",
                "rawInput": {"pattern": "TODO"},
            }
        },
        "once",
    ),
    (
        "edit on target file",
        {
            "toolCall": {
                "kind": "edit",
                "title": "edit",
                "rawInput": {"filepath": str(target)},
            }
        },
        "once",
    ),
    (
        "edit on a different file",
        {
            "toolCall": {
                "kind": "edit",
                "title": "edit",
                "rawInput": {"filepath": "/tmp/sandbox/src/other.py"},
            }
        },
        "reject",
    ),
    (
        "edit with file_path key",
        {
            "toolCall": {
                "kind": "edit",
                "title": "edit",
                "rawInput": {"file_path": str(target)},
            }
        },
        "once",
    ),
    (
        "execute (bash)",
        {
            "toolCall": {
                "kind": "execute",
                "title": "bash",
                "rawInput": {"command": "ls"},
            }
        },
        "reject",
    ),
    (
        "delete",
        {
            "toolCall": {
                "kind": "delete",
                "title": "delete",
                "rawInput": {"filepath": str(target)},
            }
        },
        "reject",
    ),
    (
        "unknown kind → default reject",
        {"toolCall": {"kind": "weird", "title": "weird", "rawInput": {}}},
        "reject",
    ),
    (
        "missing rawInput → reject",
        {"toolCall": {"kind": "edit", "title": "edit"}},
        "reject",
    ),
]

# headless-spike has the same edit-on-target rule but adds bash_readonly.
headless_spike_cases = [
    (
        "git status (allowed)",
        {
            "toolCall": {
                "kind": "execute",
                "title": "bash",
                "rawInput": {"command": "git status --short"},
            }
        },
        "once",
    ),
    (
        "git diff (allowed)",
        {
            "toolCall": {
                "kind": "execute",
                "title": "bash",
                "rawInput": {"command": "  git diff src/foo.py"},
            }
        },
        "once",
    ),
    (
        "git log (allowed)",
        {
            "toolCall": {
                "kind": "execute",
                "title": "bash",
                "rawInput": {"command": "git log --oneline -3"},
            }
        },
        "once",
    ),
    (
        "ls (allowed)",
        {
            "toolCall": {
                "kind": "execute",
                "title": "bash",
                "rawInput": {"command": "ls -la src"},
            }
        },
        "once",
    ),
    (
        "cat (allowed)",
        {
            "toolCall": {
                "kind": "execute",
                "title": "bash",
                "rawInput": {"command": "cat src/foo.py"},
            }
        },
        "once",
    ),
    (
        "rm (rejected)",
        {
            "toolCall": {
                "kind": "execute",
                "title": "bash",
                "rawInput": {"command": "rm -rf /tmp/anything"},
            }
        },
        "reject",
    ),
    (
        "git push (rejected)",
        {
            "toolCall": {
                "kind": "execute",
                "title": "bash",
                "rawInput": {"command": "git push origin main"},
            }
        },
        "reject",
    ),
    (
        "empty command (rejected)",
        {"toolCall": {"kind": "execute", "title": "bash", "rawInput": {"command": ""}}},
        "reject",
    ),
    (
        "missing command (rejected)",
        {"toolCall": {"kind": "execute", "title": "bash", "rawInput": {}}},
        "reject",
    ),
    (
        "edit on report path",
        {
            "toolCall": {
                "kind": "edit",
                "title": "edit",
                "rawInput": {"filepath": str(target)},
            }
        },
        "once",
    ),
    (
        "edit on source file",
        {
            "toolCall": {
                "kind": "edit",
                "title": "edit",
                "rawInput": {"filepath": "/tmp/sandbox/src/other.py"},
            }
        },
        "reject",
    ),
    (
        "read (allowed)",
        {
            "toolCall": {
                "kind": "read",
                "title": "read",
                "rawInput": {"filepath": "/tmp/sandbox/src/other.py"},
            }
        },
        "once",
    ),
]

failures = 0
for kind, cases in [
    ("single-file-fix", single_file_fix_cases),
    ("headless-spike", headless_spike_cases),
]:
    print(f"=== kind={kind} ===")
    for desc, params, expected in cases:
        handler = ocd.make_permission_handler(kind, target)
        result = asyncio.run(handler(params, stub_client))
        actual = result["optionId"]
        ok = actual == expected
        print(f"[{'PASS' if ok else 'FAIL'}] {desc}: expected={expected} got={actual}")
        if not ok:
            failures += 1

target.unlink()
target.parent.rmdir()
target.parent.parent.rmdir()
sys.exit(1 if failures else 0)
