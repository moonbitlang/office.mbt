#!/usr/bin/env python3
"""Cross-platform repeatability tests for native build-host discovery."""

import json
import os
import platform
import subprocess
import sys
import tempfile


def query(argv):
    result = subprocess.run(
        argv,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env={"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "C", "LC_ALL": "C"},
    )
    if result.returncode != 0:
        raise AssertionError("host query failed: %r" % result.stderr)
    return result.stdout.decode().strip()


def platform_inputs():
    system = platform.system()
    machine = platform.machine()
    if system == "Darwin" and machine == "arm64":
        return (
            "darwin-arm64",
            query(["/usr/bin/xcrun", "--sdk", "macosx", "--find", "clang"]),
            query(["/usr/bin/xcrun", "--sdk", "macosx", "--find", "ar"]),
            query(["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"]),
        )
    if system == "Linux" and machine == "x86_64":
        return "linux-x86_64", "/usr/bin/cc", "/usr/bin/ar", "-"
    raise AssertionError("unsupported test host: %s/%s" % (system, machine))


def discover(policy, root, suffix, inputs):
    output_json = os.path.join(root, "discovery-%s.json" % suffix)
    output_paths = os.path.join(root, "paths-%s.txt" % suffix)
    environment = {
        "AR": "/must/not/be/read",
        "CC": "/must/not/be/read",
        "COMPILER_PATH": "/must/not/be/read",
        "CPATH": "/must/not/be/read",
        "DEVELOPER_DIR": "/must/not/be/read",
        "GCC_EXEC_PREFIX": "/must/not/be/read",
        "LANG": "C",
        "LC_ALL": "C",
        "LIBRARY_PATH": "/must/not/be/read",
        "PATH": "/must/not/be/read",
        "SDKROOT": "/must/not/be/read",
        "TOOLCHAINS": "/must/not/be/read",
    }
    result = subprocess.run(
        [sys.executable, "-I", policy] + list(inputs) + [output_json, output_paths],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=environment,
    )
    if result.returncode != 0:
        raise AssertionError("build-host discovery failed: %r" % result.stderr)
    with open(output_json, "rb") as stream:
        json_payload = stream.read()
    with open(output_paths, "rb") as stream:
        paths_payload = stream.read()
    return json_payload, paths_payload


def main(argv):
    if len(argv) != 2:
        print("usage: build_host_discovery_test.py DISCOVERY_POLICY", file=sys.stderr)
        return 2
    policy = os.path.abspath(argv[1])
    inputs = platform_inputs()
    with tempfile.TemporaryDirectory(prefix="build-host-discovery-test.") as root:
        first_json, first_paths = discover(policy, root, "first", inputs)
        second_json, second_paths = discover(policy, root, "second", inputs)
        if first_json != second_json or first_paths != second_paths:
            raise AssertionError("build-host discovery is not byte-for-byte repeatable")
        document = json.loads(first_json)
        if document["schema"] != "office.fresh-agent.build-host-discovery/1":
            raise AssertionError("unexpected discovery schema")
        if document["platform"] != inputs[0]:
            raise AssertionError("discovery platform mismatch")
        if document["environment"] != {
            "lang": "C",
            "lc_all": "C",
            "path": "/usr/bin:/bin:/usr/sbin:/sbin",
            "sdkroot": None if inputs[3] == "-" else inputs[3],
        }:
            raise AssertionError("hostile compiler environment entered discovery")
        if sorted(document["tools"]) != ["archiver", "assembler", "compiler", "linker"]:
            raise AssertionError("discovery omitted a native build tool")
        for record in document["tools"].values():
            if not record["selected_path"].startswith("/"):
                raise AssertionError("tool selection is not absolute")
            if not record["resolved_path"].startswith("/"):
                raise AssertionError("tool resolution is not absolute")
            if len(record["sha256"]) != 64:
                raise AssertionError("tool bytes are not bound")
        if not document["compiler_queries"]["runtime_files"]:
            raise AssertionError("compiler runtime queries are absent")
        if not document["loader"]:
            raise AssertionError("dynamic-loader closure is absent")
        if not first_paths.endswith(b"\n"):
            raise AssertionError("inventory path list is not newline terminated")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
