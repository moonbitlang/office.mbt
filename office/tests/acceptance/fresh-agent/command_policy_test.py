#!/usr/bin/env python3
"""Focused adversarial tests for the fresh-agent shell command policy."""

import importlib.util
import json
import sys


def load_policy(path):
    spec = importlib.util.spec_from_file_location("fresh_agent_command_policy", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def expect_rejected(policy, command):
    try:
        argv, _redirect = policy.parse_simple_command(command)
        name = policy.approved_executable(argv)
        if name not in policy.OFFICE_COMMANDS:
            policy.validate_utility(name, argv)
    except policy.PolicyError:
        return
    raise AssertionError("unsafe command was accepted: %r" % command)


def completed_event(command, output=""):
    return {
        "aggregated_output": output,
        "command": command,
        "exit_code": 0,
        "id": "event-1",
        "status": "completed",
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: command_policy_test.py COMMAND_POLICY")
    policy = load_policy(sys.argv[1])

    argv, redirect = policy.parse_simple_command(
        "/bin/zsh -c 'printf '\"'\"'%s\\n'\"'\"' payload > result.json'"
    )
    assert argv == ["printf", "%s\\n", "payload"]
    assert redirect == "result.json"

    argv, redirect = policy.parse_simple_command(
        "jq -e '.items | length > 0 and all(.[]; .value == $expected)' result.json"
    )
    assert argv[0] == "jq"
    assert redirect is None

    unsafe_commands = [
        "/bin/bash -c 'printf ok; \"setsid\" -f /bin/sleep 600'",
        '"setsid" -f sleeper',
        'se"t"sid -f sleeper',
        r"s\etsid -f sleeper",
        "set''sid -f sleeper",
        '"no""hup" sleeper',
        "printf '%s' \"$(pwd)\"",
        "printf '%s' `pwd`",
        "cmp <(sed -n '1p' a) b",
        "cat < input.json",
        "cat input.json | jq .",
        "test -f a && rm a",
        "sleep 1 &",
        "printf ok # hide a second command",
        "printf 'ok' >result.json",
        "printf 'ok' 2> result.log",
        "head -c 100000000 /dev/zero",
        "find . -exec rm {} ;",
        "awk 'BEGIN { system(\"setsid /bin/sleep 600\") }'",
        "sed -n 'e setsid /bin/sleep 600' sample.txt",
        "rg --pre 'setsid /bin/sleep 600' needle .",
        "sort --compress-program='setsid /bin/sleep 600' sample.txt",
        "zip -T -TT 'setsid /bin/sleep 600' sample.zip",
    ]
    for command in unsafe_commands:
        expect_rejected(policy, command)

    result = {"bytes": 17, "path": "result.json", "sha256": "1" * 64}
    files = [
        {"bytes": 101, "path": "sample.xlsx", "sha256": "2" * 64},
    ]
    attestation = {
        "files": files,
        "result": result,
        "schema": "office.fresh-agent.command-attestation/1",
    }
    output = policy.ATTESTATION_PREFIX + json.dumps(
        attestation, sort_keys=True, separators=(",", ":")
    ) + "\n"
    normalized = policy.normalize_event(
        completed_event(
            "office-native identify sample.xlsx --json "
            "--attest-result result.json",
            output,
        ),
        set(),
    )
    assert normalized["product_argv"] == [
        "office-native",
        "identify",
        "sample.xlsx",
        "--json",
    ]
    assert normalized["attestation"] == attestation
    assert normalized["stdout_path"] is None


if __name__ == "__main__":
    main()
