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


def expect_event_rejected(policy, event):
    try:
        policy.normalize_event(event, set())
    except policy.PolicyError:
        return
    raise AssertionError("unsafe command event was accepted: %r" % event["command"])


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

    argv, redirect = policy.parse_simple_command("printf '%s\\n' '{literal,braces}'")
    assert argv == ["printf", "%s\\n", "{literal,braces}"]
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
        "/bin/bash -c 'cat {safe,/etc/passwd}'",
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
        {
            "access": "input",
            "argument_index": 1,
            "bytes": 101,
            "path": "sample.xlsx",
            "role": "package",
            "sha256": "2" * 64,
        },
    ]
    inputs = [
        {
            "access": "input",
            "argument_index": 1,
            "path": "sample.xlsx",
            "role": "package",
            "snapshot": {
                "bytes": 101,
                "path": "input-evidence/event-" + "a" * 32 + "/000.xlsx",
                "sha256": "3" * 64,
            },
        }
    ]
    attestation = {
        "files": files,
        "inputs": inputs,
        "result": result,
        "schema": "office.fresh-agent.command-attestation/3",
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

    selector_normalized = policy.normalize_event(
        completed_event(
            "office-native get sample.xlsx "
            "'/xlsx/sheet[name=\"Data\"]/range[A1:B5]' --json "
            "--attest-result result.json",
            output,
        ),
        set(),
    )
    assert selector_normalized["product_argv"][3] == (
        '/xlsx/sheet[name="Data"]/range[A1:B5]'
    )

    raw_attestation = json.loads(json.dumps(attestation))
    raw_attestation["files"][0].update(
        argument_index=2,
        path="sample.docx",
    )
    raw_attestation["inputs"][0].update(
        argument_index=2,
        path="sample.docx",
    )
    raw_output = policy.ATTESTATION_PREFIX + json.dumps(
        raw_attestation, sort_keys=True, separators=(",", ":")
    ) + "\n"
    raw_normalized = policy.normalize_event(
        completed_event(
            "office-native raw read sample.docx /document --json "
            "--attest-result result.json",
            raw_output,
        ),
        set(),
    )
    assert raw_normalized["product_argv"][4] == "/document"

    expect_event_rejected(
        policy,
        {
            "aggregated_output": "typed refusal\n",
            "command": "office-native get sample.xlsx /tmp/private --json",
            "exit_code": 2,
            "id": "absolute-get",
            "status": "failed",
        },
    )

    wrong_role = json.loads(json.dumps(attestation))
    wrong_role["files"][0]["role"] = "package-output"
    wrong_role_output = policy.ATTESTATION_PREFIX + json.dumps(
        wrong_role, sort_keys=True, separators=(",", ":")
    ) + "\n"
    expect_event_rejected(
        policy,
        completed_event(
            "office-native identify sample.xlsx --json "
            "--attest-result result.json",
            wrong_role_output,
        ),
    )

    traversal_event = {
        "aggregated_output": "typed refusal\n",
        "command": (
            "office-native batch source.xlsx "
            "../../../../private/tmp/ops.json --json"
        ),
        "exit_code": 2,
        "id": "traversal",
        "status": "failed",
    }
    expect_event_rejected(policy, traversal_event)


if __name__ == "__main__":
    main()
