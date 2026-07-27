#!/usr/bin/env python3
"""Contract tests for self-contained fresh-agent evidence publication."""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile


HEAD = "a" * 40


def sha256(payload):
    return hashlib.sha256(payload).hexdigest()


def write_file(path, payload, mode=0o600):
    with open(path, "xb") as stream:
        stream.write(payload)
    os.chmod(path, mode)


def make_directory(path, mode=0o700):
    os.mkdir(path, mode)
    os.chmod(path, mode)


def build_candidate(root):
    candidate = os.path.join(root, "candidate")
    make_directory(candidate)
    for name in ("bin", "control", "libexec"):
        make_directory(os.path.join(candidate, name))
    native_payload = b"fixture native command\n"
    write_file(os.path.join(candidate, "bin", "office-native"), native_payload, 0o500)
    os.symlink("office-native", os.path.join(candidate, "bin", "office"))
    manifest = {
        "build": {},
        "candidate_head": HEAD,
        "files": [
            {
                "kind": "file",
                "mode": "0500",
                "path": "bin/office-native",
                "sha256": sha256(native_payload),
            }
        ],
        "schema": "office.fresh-agent.candidate/5",
        "symlinks": [{"path": "bin/office", "target": "office-native"}],
    }
    manifest_payload = (
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    ).encode("ascii")
    write_file(os.path.join(candidate, "CANDIDATE.json"), manifest_payload, 0o400)
    for name in ("bin", "control", "libexec", "candidate"):
        path = candidate if name == "candidate" else os.path.join(candidate, name)
        os.chmod(path, 0o500)
    return candidate, manifest_payload, sha256(manifest_payload)


def build_probe(root, payload=b"probe artifact\n"):
    probe = os.path.join(root, "probe")
    make_directory(probe)
    make_directory(os.path.join(probe, "native"))
    write_file(os.path.join(probe, "native", "artifact.bin"), payload)
    write_file(os.path.join(probe, "probe-result.md"), b"# BASELINE PASS\n")
    return probe


def build_runtime(root, with_bwrap):
    codex = os.path.join(root, "codex")
    codex_payload = b"#!/bin/sh\necho codex-cli 0.145.0\n"
    write_file(codex, codex_payload, 0o500)
    if not with_bwrap:
        return codex, sha256(codex_payload), None, None
    bwrap = os.path.join(root, "bwrap")
    bwrap_payload = b"fixture bubblewrap\n"
    write_file(bwrap, bwrap_payload, 0o500)
    return codex, sha256(codex_payload), bwrap, sha256(bwrap_payload)


def invoke(policy, arguments):
    return subprocess.run(
        [sys.executable, "-I", policy] + arguments,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env={"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"},
    )


def expect_success(policy, arguments, label):
    result = invoke(policy, arguments)
    if result.returncode != 0:
        raise AssertionError("%s failed: %r" % (label, result.stderr))
    return result


def expect_failure(policy, arguments, label, pattern):
    result = invoke(policy, arguments)
    if result.returncode == 0:
        raise AssertionError("%s unexpectedly succeeded" % label)
    if pattern.encode() not in result.stderr:
        raise AssertionError("%s omitted %r: %r" % (label, pattern, result.stderr))


def publish_arguments(
    evidence,
    candidate,
    candidate_sha,
    probe,
    codex,
    codex_sha,
    bwrap=None,
    bwrap_sha=None,
):
    arguments = [
        "publish",
        "--evidence-root",
        evidence,
        "--candidate-root",
        candidate,
        "--probe-root",
        probe,
        "--candidate-head",
        HEAD,
        "--candidate-sha256",
        candidate_sha,
        "--codex-bin",
        codex,
        "--codex-version",
        "codex-cli 0.145.0",
        "--codex-sha256",
        codex_sha,
        "--bwrap-selection",
        "private" if bwrap is not None else "none",
        "--timeout-seconds",
        "10",
    ]
    if bwrap is not None:
        arguments.extend(
            ["--bwrap-bin", bwrap, "--bwrap-sha256", bwrap_sha]
        )
    return arguments


def write_top_level_evidence(evidence, mode, manifest_payload):
    names = {
        "CANDIDATE.json",
        "CONFIG.toml",
        "RUN-PREFLIGHT.json",
        "RUN.json",
        "permission-canary.log",
    }
    if mode == "baseline":
        names.update(
            {
                "COMMANDS.json",
                "WORKFLOWS.json",
                "codex-exit-status.txt",
                "codex-stderr.log",
                "codex-transcript.jsonl",
                "final-message.json",
                "probe-result.md",
                "probe-transcript.md",
            }
        )
    for name in sorted(names):
        if name == "CANDIDATE.json":
            payload = manifest_payload
        elif name in ("RUN-PREFLIGHT.json", "RUN.json"):
            payload = (
                json.dumps(
                    {
                        "candidate_head": HEAD,
                        "candidate_manifest_sha256": sha256(manifest_payload),
                    },
                    sort_keys=True,
                )
                + "\n"
            ).encode("ascii")
        else:
            payload = (name + "\n").encode("ascii")
        write_file(os.path.join(evidence, name), payload)


def make_writable(root):
    for current, directories, files in os.walk(root, topdown=True, followlinks=False):
        try:
            os.chmod(current, 0o700)
        except OSError:
            pass
        for name in directories + files:
            path = os.path.join(current, name)
            if not os.path.islink(path):
                try:
                    os.chmod(path, 0o700)
                except OSError:
                    pass


def baseline_roundtrip(policy, root):
    candidate, manifest_payload, candidate_sha = build_candidate(root)
    probe = build_probe(root)
    codex, codex_sha, bwrap, bwrap_sha = build_runtime(root, with_bwrap=True)
    evidence = os.path.join(root, "evidence")
    make_directory(evidence)
    expect_success(
        policy,
        publish_arguments(
            evidence,
            candidate,
            candidate_sha,
            probe,
            codex,
            codex_sha,
            bwrap,
            bwrap_sha,
        ),
        "baseline evidence publication",
    )
    if not os.path.islink(os.path.join(evidence, "closure", "candidate", "bin", "office")):
        raise AssertionError("candidate alias was not preserved as a symlink")
    write_top_level_evidence(evidence, "baseline", manifest_payload)
    pending = os.path.join(root, "EVIDENCE.pending.json")
    expect_success(
        policy,
        [
            "manifest",
            "--evidence-root",
            evidence,
            "--mode",
            "baseline",
            "--candidate-head",
            HEAD,
            "--candidate-sha256",
            candidate_sha,
            "--output",
            pending,
            "--timeout-seconds",
            "10",
        ],
        "baseline evidence manifest",
    )
    manifest = json.load(open(pending, encoding="utf-8"))
    if manifest["schema"] != "office.fresh-agent.evidence/2":
        raise AssertionError("unexpected baseline evidence schema")
    paths = {artifact["path"] for artifact in manifest["artifacts"]}
    required = {
        "closure/candidate/control",
        "closure/probe/native/artifact.bin",
        "closure/runtime/RUNTIME.json",
        "closure/runtime/bwrap",
        "closure/runtime/codex",
    }
    if not required.issubset(paths):
        raise AssertionError("self-contained closure is incomplete")
    evidence_manifest = os.path.join(evidence, "EVIDENCE.json")
    os.rename(pending, evidence_manifest)
    expect_success(
        policy,
        [
            "verify",
            "--evidence-root",
            evidence,
            "--manifest",
            evidence_manifest,
            "--timeout-seconds",
            "10",
        ],
        "baseline evidence verification",
    )
    with open(os.path.join(evidence, "closure", "probe", "native", "artifact.bin"), "ab") as stream:
        stream.write(b"mutation")
    expect_failure(
        policy,
        [
            "verify",
            "--evidence-root",
            evidence,
            "--manifest",
            evidence_manifest,
            "--timeout-seconds",
            "10",
        ],
        "mutated evidence",
        "does not match EVIDENCE.json",
    )


def canary_roundtrip(policy, root):
    candidate, manifest_payload, candidate_sha = build_candidate(root)
    probe = os.path.join(root, "probe")
    make_directory(probe)
    codex, codex_sha, _, _ = build_runtime(root, with_bwrap=False)
    evidence = os.path.join(root, "evidence")
    make_directory(evidence)
    expect_success(
        policy,
        publish_arguments(
            evidence, candidate, candidate_sha, probe, codex, codex_sha
        ),
        "canary evidence publication",
    )
    write_top_level_evidence(evidence, "canary", manifest_payload)
    pending = os.path.join(root, "EVIDENCE.pending.json")
    expect_success(
        policy,
        [
            "manifest",
            "--evidence-root",
            evidence,
            "--mode",
            "canary",
            "--candidate-head",
            HEAD,
            "--candidate-sha256",
            candidate_sha,
            "--output",
            pending,
            "--timeout-seconds",
            "10",
        ],
        "canary evidence manifest",
    )
    document = json.load(open(pending, encoding="utf-8"))
    if document["schema"] != "office.fresh-agent.canary-evidence/2":
        raise AssertionError("unexpected canary evidence schema")


def rejection_cases(policy, root):
    candidate, _, candidate_sha = build_candidate(root)
    probe = build_probe(root)
    codex, codex_sha, _, _ = build_runtime(root, with_bwrap=False)
    os.symlink("native/artifact.bin", os.path.join(probe, "escape"))
    evidence = os.path.join(root, "symlink-evidence")
    make_directory(evidence)
    expect_failure(
        policy,
        publish_arguments(
            evidence, candidate, candidate_sha, probe, codex, codex_sha
        ),
        "probe symlink",
        "unapproved symlink",
    )
    os.unlink(os.path.join(probe, "escape"))
    os.link(
        os.path.join(probe, "native", "artifact.bin"),
        os.path.join(probe, "native", "hardlink.bin"),
    )
    evidence = os.path.join(root, "hardlink-evidence")
    make_directory(evidence)
    expect_failure(
        policy,
        publish_arguments(
            evidence, candidate, candidate_sha, probe, codex, codex_sha
        ),
        "probe hard link",
        "exactly one hard link",
    )


def run_in_private_root(callback, policy, prefix):
    root = tempfile.mkdtemp(prefix=prefix)
    os.chmod(root, 0o700)
    try:
        callback(policy, root)
    finally:
        make_writable(root)
        shutil.rmtree(root)


def main(argv):
    if len(argv) != 2:
        print("usage: evidence_policy_test.py EVIDENCE_POLICY", file=sys.stderr)
        return 2
    policy = os.path.abspath(argv[1])
    run_in_private_root(baseline_roundtrip, policy, "evidence-policy-baseline.")
    run_in_private_root(canary_roundtrip, policy, "evidence-policy-canary.")
    run_in_private_root(rejection_cases, policy, "evidence-policy-reject.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
