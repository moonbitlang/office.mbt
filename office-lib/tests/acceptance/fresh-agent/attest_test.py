#!/usr/bin/env python3
"""Adversarial tests for atomic input and completion Office attestations."""

import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


PREFIX = "OFFICE_F1B_ATTESTATION\t"
SCHEMA = "office.fresh-agent.command-attestation/3"


def write_executable(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as stream:
        stream.write("#!/bin/sh\nset -eu\n")
        stream.write("\n".join(lines))
        stream.write("\n")
    os.chmod(path, stat.S_IRUSR | stat.S_IXUSR)


def write_private(path, data):
    with open(path, "wb") as stream:
        stream.write(data)
    os.chmod(path, 0o600)


def run_helper(attester, cwd, target, result, arguments=None):
    if arguments is None:
        arguments = ["identify", "sample.xlsx", "--json"]
    return subprocess.run(
        [sys.executable, "-I", attester, target, result] + arguments,
        cwd=cwd,
        env={"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"},
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=True,
        timeout=10,
    )


def parse_attestation(completed):
    assert completed.returncode == 0, completed.stderr
    assert completed.stdout.startswith(PREFIX)
    assert completed.stdout.endswith("\n")
    value = json.loads(completed.stdout[len(PREFIX) :])
    assert value["schema"] == SCHEMA
    return value


def snapshot_bytes(root, record):
    snapshot = record["snapshot"]
    path = root / snapshot["path"]
    data = path.read_bytes()
    assert path.stat().st_mode & 0o777 == 0o400
    assert snapshot["bytes"] == len(data)
    assert snapshot["sha256"] == hashlib.sha256(data).hexdigest()
    return data


def event_directories(root):
    evidence = root / "input-evidence"
    if not evidence.exists():
        return []
    return sorted(path.name for path in evidence.iterdir())


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: attest_test.py ATTESTER")
    attester = os.path.abspath(sys.argv[1])
    with tempfile.TemporaryDirectory(prefix="office-attest-test.") as temporary:
        root = Path(temporary)
        source_bytes = b"office-source-bytes\n"
        source = root / "sample.xlsx"
        write_private(source, source_bytes)

        read_target = root / "office-read"
        write_executable(read_target, ['printf \'{"schema":"fixture/1"}\\n\''])
        completed = run_helper(attester, root, read_target, "result.json")
        value = parse_attestation(completed)
        assert value["result"]["path"] == "result.json"
        assert value["files"][0] == {
            "access": "input",
            "argument_index": 1,
            "bytes": len(source_bytes),
            "path": "sample.xlsx",
            "role": "package",
            "sha256": hashlib.sha256(source_bytes).hexdigest(),
        }
        assert value["inputs"][0] == {
            "access": "input",
            "argument_index": 1,
            "path": "sample.xlsx",
            "role": "package",
            "snapshot": value["inputs"][0]["snapshot"],
        }
        assert snapshot_bytes(root, value["inputs"][0]) == source_bytes
        result_bytes = (root / "result.json").read_bytes()
        assert value["result"]["bytes"] == len(result_bytes)
        assert value["result"]["sha256"] == hashlib.sha256(result_bytes).hexdigest()

        repeated = run_helper(attester, root, read_target, "result.json")
        assert repeated.returncode == 70
        assert (root / "result.json").read_bytes() == result_bytes

        managed_result = run_helper(
            attester, root, read_target, "input-evidence/result.json"
        )
        assert managed_result.returncode == 70
        assert not (root / "input-evidence" / "result.json").exists()

        physical = root / "physical"
        physical.mkdir(mode=0o700)
        (root / "alias").symlink_to("physical", target_is_directory=True)
        aliased = run_helper(attester, root, read_target, "alias/result.json")
        assert aliased.returncode == 70
        assert not (physical / "result.json").exists()

        failing = root / "office-failing"
        write_executable(failing, ['printf \'{"failed":true}\\n\'', "exit 7"])
        events_before_failure = event_directories(root)
        failed = run_helper(attester, root, failing, "failed.json")
        assert failed.returncode == 7
        assert not (root / "failed.json").exists()
        assert event_directories(root) == events_before_failure

        marker = root / "unexpected-execution"
        traversal_target = root / "office-traversal"
        write_executable(
            traversal_target,
            [
                "printf executed > unexpected-execution",
                'printf \'{"schema":"fixture/1"}\\n\'',
            ],
        )
        traversal = run_helper(
            attester,
            root,
            traversal_target,
            "traversal.json",
            ["batch", "sample.xlsx", "../../../../private/tmp/ops.json", "--json"],
        )
        assert traversal.returncode == 70
        assert not marker.exists()
        assert "traverses a non-canonical path" in traversal.stderr

        linked = root / "linked.xlsx"
        linked.symlink_to(source.name)
        symlinked = run_helper(
            attester,
            root,
            read_target,
            "symlinked.json",
            ["identify", "linked.xlsx", "--json"],
        )
        assert symlinked.returncode == 70
        assert not (root / "symlinked.json").exists()

        physical_input = root / "physical-input"
        physical_input.mkdir(mode=0o700)
        write_private(physical_input / "data.json", b"{}\n")
        (root / "input-alias").symlink_to(
            physical_input.name, target_is_directory=True
        )
        parent_symlinked = run_helper(
            attester,
            root,
            traversal_target,
            "parent-symlinked.json",
            [
                "template",
                "sample.xlsx",
                "input-alias/data.json",
                "--out",
                "unused.xlsx",
                "--json",
            ],
        )
        assert parent_symlinked.returncode == 70
        assert not marker.exists()

        os.mkfifo(root / "fifo.json", 0o600)
        fifo_input = run_helper(
            attester,
            root,
            traversal_target,
            "fifo-input.json",
            ["batch", "sample.xlsx", "fifo.json", "--json"],
        )
        assert fifo_input.returncode == 70
        assert not marker.exists()

        data_bytes = b'{"schema":"office.template.data/1","values":{"name":"Ada"}}\n'
        write_private(root / "data.json", data_bytes)
        write_private(root / "outside.xlsx", b"outside\n")
        (root / "output-link.xlsx").symlink_to("outside.xlsx")
        output_symlinked = run_helper(
            attester,
            root,
            traversal_target,
            "output-symlinked.json",
            [
                "template",
                "sample.xlsx",
                "data.json",
                "--out",
                "output-link.xlsx",
                "--json",
            ],
        )
        assert output_symlinked.returncode == 70
        assert not marker.exists()

        template_target = root / "office-template"
        write_executable(
            template_target,
            [
                "printf 'merged-bytes\\n' > merged.xlsx",
                'printf \'{"schema":"fixture/1"}\\n\'',
            ],
        )
        templated = run_helper(
            attester,
            root,
            template_target,
            "template-result.json",
            [
                "template",
                "sample.xlsx",
                "data.json",
                "--out",
                "merged.xlsx",
                "--json",
            ],
        )
        template_value = parse_attestation(templated)
        assert [
            (record["argument_index"], record["role"])
            for record in template_value["inputs"]
        ] == [(1, "package"), (2, "template-data")]
        assert snapshot_bytes(root, template_value["inputs"][0]) == source_bytes
        assert snapshot_bytes(root, template_value["inputs"][1]) == data_bytes

        ops_bytes = b'{"schema":"xlsx.batch/2","ops":[]}\n'
        write_private(root / "ops.json", ops_bytes)
        batch_target = root / "office-batch"
        write_executable(
            batch_target,
            [
                "printf 'updated-package\\n' > sample.xlsx",
                'printf \'{"schema":"fixture/1"}\\n\'',
            ],
        )
        batched = run_helper(
            attester,
            root,
            batch_target,
            "batch-result.json",
            ["batch", "sample.xlsx", "ops.json", "--json"],
        )
        batch_value = parse_attestation(batched)
        assert batch_value["inputs"][0]["access"] == "input-output"
        assert snapshot_bytes(root, batch_value["inputs"][0]) == source_bytes
        assert (root / "sample.xlsx").read_bytes() == b"updated-package\n"

        write_private(source, source_bytes)
        mutation_target = root / "office-mutation"
        write_executable(
            mutation_target,
            [
                "printf 'mutated-source-bytes\\n' > sample.xlsx",
                'printf \'{"schema":"fixture/1"}\\n\'',
            ],
        )
        events_before_mutation = event_directories(root)
        mutated = run_helper(
            attester, root, mutation_target, "mutated-result.json"
        )
        assert mutated.returncode == 70
        assert "changed while Office was running" in mutated.stderr
        assert not (root / "mutated-result.json").exists()
        assert event_directories(root) == events_before_mutation

    print("ATTESTATION TEST PASS")


if __name__ == "__main__":
    main()
