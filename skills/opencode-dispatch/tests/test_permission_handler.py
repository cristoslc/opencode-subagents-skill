"""Unit-test the permission allowlist without going through the model."""
import sys
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path

DISPATCH = "/Users/cristos/Documents/code/opencode-subagents-skill/skills/opencode-dispatch/bin/opencode-dispatch"
loader = SourceFileLoader("ocd", DISPATCH)
spec = spec_from_loader("ocd", loader)
ocd = module_from_spec(spec)
sys.modules["ocd"] = ocd          # <-- needed for @dataclass
loader.exec_module(ocd)

target = Path("/tmp/sandbox/src/calc.py")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("placeholder\n")

cases = [
    ("read",                       {"toolCall": {"kind": "read",   "title": "read",
                                                  "rawInput": {"filepath": "/tmp/sandbox/some/other.py"}}}, "once"),
    ("search",                     {"toolCall": {"kind": "search", "title": "search",
                                                  "rawInput": {"pattern": "TODO"}}}, "once"),
    ("edit on target file",        {"toolCall": {"kind": "edit",   "title": "edit",
                                                  "rawInput": {"filepath": str(target)}}}, "once"),
    ("edit on a different file",   {"toolCall": {"kind": "edit",   "title": "edit",
                                                  "rawInput": {"filepath": "/tmp/sandbox/src/other.py"}}}, "reject"),
    ("edit with file_path key",    {"toolCall": {"kind": "edit",   "title": "edit",
                                                  "rawInput": {"file_path": str(target)}}}, "once"),
    ("execute (bash)",             {"toolCall": {"kind": "execute", "title": "bash",
                                                  "rawInput": {"command": "ls"}}}, "reject"),
    ("delete",                     {"toolCall": {"kind": "delete", "title": "delete",
                                                  "rawInput": {"filepath": str(target)}}}, "reject"),
    ("unknown kind → default reject", {"toolCall": {"kind": "weird", "title": "weird", "rawInput": {}}}, "reject"),
    ("missing rawInput → reject",  {"toolCall": {"kind": "edit",   "title": "edit"}}, "reject"),
]

failures = 0
for desc, params, expected in cases:
    handler = ocd.make_permission_handler("single-file-fix", target)
    result = handler(params)
    actual = result["optionId"]
    ok = actual == expected
    print(f"[{'PASS' if ok else 'FAIL'}] {desc}: expected={expected} got={actual}")
    if not ok:
        failures += 1

target.unlink()
target.parent.rmdir()
target.parent.parent.rmdir()
sys.exit(1 if failures else 0)
