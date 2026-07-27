#!/usr/bin/env python3
"""Bound and validate a Codex JSONL lifecycle before whole-document parsing."""

import json
import os
import stat
import sys
import tempfile


MAX_TRANSCRIPT_BYTES = 32 * 1024 * 1024
MAX_LINE_BYTES = 1024 * 1024
MAX_EVENTS = 4096


class TranscriptError(Exception):
    pass


def fail(message):
    raise TranscriptError(message)


def is_command_event(event, lifecycle):
    item = event.get("item")
    return (
        event.get("type") == lifecycle
        and isinstance(item, dict)
        and item.get("type") == "command_execution"
    )


def exact_canary_command(value):
    return value in {
        "office-permission-canary",
        "/bin/sh -c office-permission-canary",
        "/bin/sh -c 'office-permission-canary'",
        "/bin/bash -c office-permission-canary",
        "/bin/bash -c 'office-permission-canary'",
        "/bin/zsh -c office-permission-canary",
        "/bin/zsh -c 'office-permission-canary'",
    }


def read_bounded_jsonl(path):
    before = os.lstat(path)
    if not stat.S_ISREG(before.st_mode) or stat.S_ISLNK(before.st_mode):
        fail("Codex transcript is not a physical regular file")
    if before.st_size <= 0 or before.st_size > MAX_TRANSCRIPT_BYTES:
        fail("Codex transcript size is outside 1..%d bytes" % MAX_TRANSCRIPT_BYTES)
    events = []
    total = 0
    with open(path, "rb", buffering=0) as stream:
        while True:
            line = stream.readline(MAX_LINE_BYTES + 1)
            if not line:
                break
            total += len(line)
            if len(line) > MAX_LINE_BYTES:
                fail("Codex transcript contains a line larger than %d bytes" % MAX_LINE_BYTES)
            if not line.endswith(b"\n"):
                fail("Codex transcript must end every JSON event with a newline")
            if line == b"\n":
                fail("Codex transcript contains a blank line")
            try:
                value = json.loads(line.decode("utf-8"))
            except (UnicodeError, ValueError) as exc:
                fail("Codex transcript contains malformed JSONL: %s" % exc)
            if not isinstance(value, dict) or not isinstance(value.get("type"), str):
                fail("Codex transcript event is not a typed object")
            events.append(value)
            if len(events) > MAX_EVENTS:
                fail("Codex transcript contains more than %d events" % MAX_EVENTS)
    after = os.lstat(path)
    identity_before = (
        before.st_dev,
        before.st_ino,
        before.st_mode,
        before.st_uid,
        before.st_nlink,
        before.st_size,
        before.st_mtime_ns,
    )
    identity_after = (
        after.st_dev,
        after.st_ino,
        after.st_mode,
        after.st_uid,
        after.st_nlink,
        after.st_size,
        after.st_mtime_ns,
    )
    if identity_before != identity_after or total != before.st_size:
        fail("Codex transcript changed while it was streamed")
    return events


def validate_lifecycle(events, outer_status):
    if outer_status != 0:
        fail("a completed transcript cannot contradict a nonzero outer Codex status")
    thread_started = [index for index, event in enumerate(events) if event["type"] == "thread.started"]
    turn_started = [index for index, event in enumerate(events) if event["type"] == "turn.started"]
    turn_completed = [index for index, event in enumerate(events) if event["type"] == "turn.completed"]
    turn_failed = [index for index, event in enumerate(events) if event["type"] == "turn.failed"]
    if thread_started != [0]:
        fail("transcript must begin with exactly one thread.started event")
    if len(turn_started) != 1 or len(turn_completed) != 1 or turn_failed:
        fail("transcript must contain one successful terminal turn")
    if not turn_started[0] < turn_completed[0] == len(events) - 1:
        fail("successful terminal turn has an impossible position")

    starts = {}
    completions = {}
    command_event_indices = []
    for index, event in enumerate(events):
        if is_command_event(event, "item.started"):
            item = event["item"]
            event_id = item.get("id")
            command = item.get("command")
            if not isinstance(event_id, str) or not event_id:
                fail("started command has an empty id")
            if not isinstance(command, str) or not command:
                fail("started command has an empty command")
            if event_id in starts:
                fail("command start ids are not unique")
            starts[event_id] = (index, command, item)
            command_event_indices.append(index)
        elif is_command_event(event, "item.completed"):
            item = event["item"]
            event_id = item.get("id")
            command = item.get("command")
            if not isinstance(event_id, str) or not event_id:
                fail("completed command has an empty id")
            if not isinstance(command, str) or not command:
                fail("completed command has an empty command")
            if event_id in completions:
                fail("command completion ids are not unique")
            exit_code = item.get("exit_code")
            status = item.get("status")
            output = item.get("aggregated_output")
            if (
                not isinstance(exit_code, int)
                or isinstance(exit_code, bool)
                or not 0 <= exit_code <= 255
            ):
                fail("command exit code is not an integer in 0..255")
            if not isinstance(output, str):
                fail("completed command output is not a string")
            if not (
                (status == "completed" and exit_code == 0)
                or (status == "failed" and exit_code >= 1)
            ):
                fail("command status contradicts its exit code")
            completions[event_id] = (index, command, item)
            command_event_indices.append(index)

    if not starts or set(starts) != set(completions):
        fail("command starts and completions do not pair exactly")
    for event_id, (start_index, command, _item) in starts.items():
        completion_index, completion_command, _completion = completions[event_id]
        if command != completion_command:
            fail("paired command text changed between start and completion")
        if not (
            turn_started[0] < start_index < completion_index < turn_completed[0]
        ):
            fail("command completion does not follow its start inside the turn")

    first_index = min(command_event_indices)
    first_event = events[first_index]
    if not is_command_event(first_event, "item.started"):
        fail("the first command event is not a start")
    first_item = first_event["item"]
    if not exact_canary_command(first_item["command"]):
        fail("the first command is not the exact permission canary")
    completion = completions[first_item["id"]][2]
    if not (
        exact_canary_command(completion["command"])
        and completion["exit_code"] == 0
        and completion["aggregated_output"]
        == "FRESH-AGENT PERMISSION CANARY PASS\n"
    ):
        fail("the permission canary completion is not an exact PASS")


def atomic_write_json(path, value):
    parent = os.path.dirname(os.path.abspath(path))
    descriptor, temporary = tempfile.mkstemp(prefix=".transcript-policy.", dir=parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, sort_keys=True, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        if os.path.lexists(path):
            fail("bounded transcript output already exists")
        os.link(temporary, path, follow_symlinks=False)
        os.unlink(temporary)
        temporary = None
    finally:
        if temporary is not None:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass


def main():
    if len(sys.argv) != 4:
        print(
            "usage: transcript_policy.py TRANSCRIPT_JSONL OUTER_STATUS OUTPUT_JSON",
            file=sys.stderr,
        )
        return 64
    source, outer_status_text, output = sys.argv[1:]
    try:
        outer_status = int(outer_status_text, 10)
    except ValueError:
        fail("outer Codex status is not an integer")
    events = read_bounded_jsonl(source)
    validate_lifecycle(events, outer_status)
    atomic_write_json(output, events)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, TranscriptError, UnicodeError, ValueError) as exc:
        print("transcript policy rejected Codex output: %s" % exc, file=sys.stderr)
        sys.exit(1)
