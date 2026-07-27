#!/usr/bin/env python3
"""Focused tests for atomic completion-time Office command attestations."""

import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile


PREFIX = "OFFICE_F1B_ATTESTATION\t"


def write_executable(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as stream:
        stream.write("#!/bin/sh\nset -eu\n")
        stream.write("\n".join(lines))
        stream.write("\n")
    os.chmod(path, stat.S_IRUSR | stat.S_IXUSR)


def run_helper(attester, cwd, target, result):
    return subprocess.run(
        [
            sys.executable,
            "-I",
            attester,
            target,
            result,
            "identify",
            "sample.xlsx",
            "--json",
        ],
        cwd=cwd,
        env={"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"},
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=True,
    )


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: attest_test.py ATTESTER")
    attester = os.path.abspath(sys.argv[1])
    with tempfile.TemporaryDirectory(prefix="office-attest-test.") as root:
        target = os.path.join(root, "office-fixture")
        write_executable(
            target,
            [
                "printf 'office-bytes\\n' > sample.xlsx",
                "printf '{\"schema\":\"fixture/1\"}\\n'",
            ],
        )
        completed = run_helper(attester, root, target, "result.json")
        assert completed.returncode == 0, completed.stderr
        assert completed.stdout.startswith(PREFIX)
        assert completed.stdout.endswith("\n")
        value = json.loads(completed.stdout[len(PREFIX) :])
        assert value["schema"] == "office.fresh-agent.command-attestation/1"
        assert value["result"]["path"] == "result.json"
        assert value["files"][0]["path"] == "sample.xlsx"
        with open(os.path.join(root, "result.json"), "rb") as stream:
            result_bytes = stream.read()
        assert value["result"]["bytes"] == len(result_bytes)
        assert value["result"]["sha256"] == hashlib.sha256(result_bytes).hexdigest()

        repeated = run_helper(attester, root, target, "result.json")
        assert repeated.returncode == 70
        with open(os.path.join(root, "result.json"), "rb") as stream:
            assert stream.read() == result_bytes

        physical = os.path.join(root, "physical")
        os.mkdir(physical, 0o700)
        os.symlink("physical", os.path.join(root, "alias"))
        aliased = run_helper(attester, root, target, "alias/result.json")
        assert aliased.returncode == 70
        assert not os.path.lexists(os.path.join(physical, "result.json"))

        failing = os.path.join(root, "office-failing")
        write_executable(failing, ["printf '{\"failed\":true}\\n'", "exit 7"])
        failed = run_helper(attester, root, failing, "failed.json")
        assert failed.returncode == 7
        assert not os.path.lexists(os.path.join(root, "failed.json"))


if __name__ == "__main__":
    main()
