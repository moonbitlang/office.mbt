#!/usr/bin/env python3
"""Focused lifecycle and bound tests for Codex JSONL transcript policy."""

import importlib.util
import json
import os
import tempfile


def load_policy(path):
    spec = importlib.util.spec_from_file_location("fresh_agent_transcript_policy", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def valid_events():
    command = "/bin/sh -c 'office-permission-canary'"
    return [
        {"type": "thread.started", "thread_id": "fixture"},
        {"type": "turn.started"},
        {
            "type": "item.started",
            "item": {
                "id": "canary",
                "type": "command_execution",
                "command": command,
            },
        },
        {
            "type": "item.completed",
            "item": {
                "id": "canary",
                "type": "command_execution",
                "command": command,
                "aggregated_output": "FRESH-AGENT PERMISSION CANARY PASS\n",
                "exit_code": 0,
                "status": "completed",
            },
        },
        {"type": "turn.completed"},
    ]


def expect_lifecycle_rejected(policy, mutate):
    events = valid_events()
    mutate(events)
    try:
        policy.validate_lifecycle(events, 0)
    except policy.TranscriptError:
        return
    raise AssertionError("invalid lifecycle was accepted")


def main():
    import sys

    if len(sys.argv) != 2:
        raise SystemExit("usage: transcript_policy_test.py TRANSCRIPT_POLICY")
    policy = load_policy(sys.argv[1])
    policy.validate_lifecycle(valid_events(), 0)

    expect_lifecycle_rejected(
        policy,
        lambda events: events.__setitem__(
            slice(2, 4), [events[3], events[2]]
        ),
    )
    expect_lifecycle_rejected(
        policy, lambda events: events[3]["item"].__setitem__("exit_code", 0.5)
    )
    expect_lifecycle_rejected(
        policy, lambda events: events[3]["item"].__setitem__("exit_code", True)
    )
    expect_lifecycle_rejected(
        policy, lambda events: events[3]["item"].__setitem__("exit_code", 256)
    )
    expect_lifecycle_rejected(
        policy, lambda events: events[3]["item"].__setitem__("status", "failed")
    )
    expect_lifecycle_rejected(
        policy, lambda events: events[2]["item"].__setitem__("command", "true")
    )
    expect_lifecycle_rejected(policy, lambda events: events.pop())
    try:
        policy.validate_lifecycle(valid_events(), 9)
    except policy.TranscriptError:
        pass
    else:
        raise AssertionError("outer status contradiction was accepted")

    with tempfile.TemporaryDirectory(prefix="transcript-policy-test.") as root:
        transcript = os.path.join(root, "events.jsonl")
        with open(transcript, "wb") as stream:
            for event in valid_events():
                stream.write(json.dumps(event).encode("utf-8") + b"\n")
        assert policy.read_bounded_jsonl(transcript) == valid_events()

        with open(transcript, "ab") as stream:
            stream.write(b"{}")
        try:
            policy.read_bounded_jsonl(transcript)
        except policy.TranscriptError:
            pass
        else:
            raise AssertionError("unterminated JSONL event was accepted")

        with open(transcript, "wb") as stream:
            stream.write(b"{}\n\n")
        try:
            policy.read_bounded_jsonl(transcript)
        except policy.TranscriptError:
            pass
        else:
            raise AssertionError("blank JSONL line was accepted")

        with open(transcript, "wb") as stream:
            stream.write(b'{"type":"fixture","payload":"')
            stream.write(b"x" * policy.MAX_LINE_BYTES)
            stream.write(b'"}\n')
        try:
            policy.read_bounded_jsonl(transcript)
        except policy.TranscriptError:
            pass
        else:
            raise AssertionError("oversized JSONL line was accepted")


if __name__ == "__main__":
    main()
