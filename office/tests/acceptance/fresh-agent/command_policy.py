#!/usr/bin/env python3
"""Validate and normalize fresh-agent command events without executing shell text."""

import hashlib
import importlib.util
import json
import os
import re
import shlex
import stat
import sys
import tempfile


MAX_COMMANDS = 512
MAX_COMMAND_BYTES = 16 * 1024
MAX_EVENT_OUTPUT_BYTES = 8 * 1024 * 1024
MAX_INPUT_BYTES = 64 * 1024 * 1024

APPROVED_UTILITIES = frozenset(
    {
        "cat",
        "cksum",
        "cmp",
        "comm",
        "cp",
        "cut",
        "diff",
        "echo",
        "false",
        "file",
        "find",
        "grep",
        "head",
        "jq",
        "ls",
        "mkdir",
        "mv",
        "paste",
        "printf",
        "pwd",
        "readlink",
        "rm",
        "sha256sum",
        "shasum",
        "stat",
        "tail",
        "test",
        "touch",
        "tr",
        "true",
        "uniq",
        "unzip",
        "wc",
        "zipinfo",
    }
)
OFFICE_COMMANDS = frozenset(
    {"office-native", "office-wasm", "office-permission-canary"}
)
ACCEPTANCE_GET_SELECTORS = frozenset(
    {
        '/xlsx/sheet[name="Data"]/range[A1:B5]',
        "/docx/body/p[1]",
    }
)
ACCEPTANCE_RAW_SELECTORS = frozenset({"/document"})
SHELLS = frozenset({"/bin/sh", "/bin/bash", "/bin/zsh"})
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")
SNAPSHOT_PATH = re.compile(
    r"input-evidence/event-[0-9a-f]{32}/"
    r"[0-9]{3}(?:[.]input|[.](?:xlsx|docx|html|json|xml))"
)
ATTESTATION_SCHEMA = "office.fresh-agent.command-attestation/3"
ATTESTATION_PREFIX = "OFFICE_F1B_ATTESTATION\t"


class PolicyError(Exception):
    pass


def fail(message):
    raise PolicyError(message)


def load_argument_policy():
    directory = os.path.dirname(os.path.abspath(__file__))
    for name in ("argument-policy.py", "argument_policy.py"):
        path = os.path.join(directory, name)
        if not os.path.isfile(path):
            continue
        spec = importlib.util.spec_from_file_location(
            "fresh_agent_argument_policy", path
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    fail("Office argument policy is unavailable")


ARGUMENT_POLICY = load_argument_policy()


def utf8_bytes(value, label):
    if not isinstance(value, str):
        fail("%s must be a string" % label)
    try:
        return value.encode("utf-8")
    except UnicodeEncodeError as exc:
        fail("%s is not valid UTF-8 text: %s" % (label, exc))


def safe_relative_path(value, label):
    try:
        return ARGUMENT_POLICY.safe_relative_path(value, label)
    except ARGUMENT_POLICY.ArgumentPolicyError as exc:
        fail(str(exc))


def unwrap_command(raw):
    if not isinstance(raw, str):
        fail("command is not a string")
    if len(utf8_bytes(raw, "command")) > MAX_COMMAND_BYTES:
        fail("command exceeds the %d-byte policy limit" % MAX_COMMAND_BYTES)
    try:
        outer = shlex.split(raw, posix=True)
    except ValueError as exc:
        fail("command wrapper is not valid shell quoting: %s" % exc)
    if outer and outer[0] in SHELLS:
        if len(outer) != 3 or outer[1] != "-c":
            fail("shell wrappers must use exactly SHELL -c BODY")
        return outer[2]
    return raw


def reject_shell_expansion(body):
    state = "plain"
    word_start = True
    index = 0
    while index < len(body):
        char = body[index]
        if char in "\r\n\t\x00":
            fail("commands may not contain control characters")
        if state == "single":
            if char == "'":
                state = "plain"
            index += 1
            continue
        if state == "double":
            if char == '"':
                state = "plain"
            elif char in "$`":
                fail("shell expansion is not allowed")
            elif char == "\\":
                index += 1
                if index >= len(body):
                    fail("command ends in an incomplete escape")
            index += 1
            continue

        if char == "'":
            state = "single"
            word_start = False
        elif char == '"':
            state = "double"
            word_start = False
        elif char == "\\":
            index += 1
            if index >= len(body):
                fail("command ends in an incomplete escape")
            word_start = False
        elif char.isspace():
            word_start = True
        elif char in "$`":
            fail("shell expansion is not allowed")
        elif char == "#":
            fail("shell comments are not allowed")
        elif char in ";|&()":
            fail("compound shell syntax is not allowed")
        elif char == "<":
            fail("input redirection is not allowed")
        elif char == ">":
            before = body[index - 1] if index else ""
            after = body[index + 1] if index + 1 < len(body) else ""
            if not before.isspace() or not after.isspace():
                fail("stdout redirection must be one space-delimited '>' token")
            word_start = True
        elif char in "*?[":
            fail("unquoted shell globbing is not allowed")
        elif char in "{}":
            fail("unquoted shell brace expansion is not allowed")
        elif char == "~" and word_start:
            fail("tilde expansion is not allowed")
        else:
            word_start = False
        index += 1
    if state != "plain":
        fail("command contains an unterminated quote")


def parse_simple_command(raw):
    body = unwrap_command(raw)
    reject_shell_expansion(body)
    lexer = shlex.shlex(body, posix=True, punctuation_chars="();<>|&")
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        tokens = list(lexer)
    except ValueError as exc:
        fail("command body is not valid shell quoting: %s" % exc)
    if not tokens:
        fail("command body is empty")
    if any(token in (";", "|", "||", "&", "&&", "(", ")", "<", ">>") for token in tokens):
        fail("compound shell syntax is not allowed")
    redirects = [index for index, token in enumerate(tokens) if token == ">"]
    redirect_path = None
    if redirects:
        if len(redirects) != 1 or redirects[0] != len(tokens) - 2:
            fail("one final stdout redirection is the only permitted redirection")
        redirect_path = safe_relative_path(tokens[-1], "stdout redirection")
        tokens = tokens[:-2]
    if not tokens:
        fail("command has no executable")
    return tokens, redirect_path


def approved_executable(argv):
    executable = argv[0]
    if executable in OFFICE_COMMANDS:
        return executable
    if "/" in executable:
        name = os.path.basename(executable)
        if executable not in ("/bin/" + name, "/usr/bin/" + name):
            fail("executable path is outside the approved system locations: %s" % executable)
    else:
        name = executable
    if name not in APPROVED_UTILITIES:
        fail("executable is outside the acceptance allowlist: %s" % executable)
    return name


def validate_utility(name, argv):
    if any(argument.startswith("/") for argument in argv[1:]):
        fail("absolute command arguments are not allowed")
    if name == "find" and any(
        argument in ("-exec", "-execdir", "-ok", "-okdir", "-delete")
        for argument in argv[1:]
    ):
        fail("find execution and deletion actions are not allowed")
    if name in ("head", "tail") and any(
        argument == "-c" or argument.startswith("--bytes")
        for argument in argv[1:]
    ):
        fail("byte-count head/tail operations are outside the resource policy")


def parse_attestation(output, result_path, product_arguments, path_references):
    if len(utf8_bytes(output, "command output")) > 64 * 1024:
        fail("an attested command emitted more than 64 KiB")
    if not output.startswith(ATTESTATION_PREFIX) or not output.endswith("\n"):
        fail("attested Office command did not emit one host-recognizable attestation")
    payload = output[len(ATTESTATION_PREFIX) : -1]
    if "\n" in payload or "\r" in payload:
        fail("attested Office command emitted multiple output lines")
    try:
        value = json.loads(payload)
    except (TypeError, ValueError) as exc:
        fail("attestation is not valid JSON: %s" % exc)
    if not isinstance(value, dict) or set(value) != {
        "files",
        "inputs",
        "result",
        "schema",
    }:
        fail("attestation has an unexpected top-level shape")
    if value["schema"] != ATTESTATION_SCHEMA:
        fail("attestation has an unexpected schema")
    validate_digest_record(value["result"], "attestation result")
    if value["result"]["path"] != result_path:
        fail("attestation result path does not match --attest-result")
    expected_files = sorted(
        (
            reference
            for reference in path_references
            if reference["path"].lower().endswith((".xlsx", ".docx", ".html"))
        ),
        key=lambda reference: reference["path"],
    )
    files = value["files"]
    if (
        not isinstance(files, list)
        or not files
        or len(files) != len(expected_files)
    ):
        fail("attestation must bind at least one Office or preview file")
    paths = []
    for index, (record, expected) in enumerate(zip(files, expected_files)):
        if not isinstance(record, dict) or set(record) != {
            "access",
            "argument_index",
            "bytes",
            "path",
            "role",
            "sha256",
        }:
            fail("attestation file %d has an unexpected shape" % index)
        validate_digest_record(
            {key: record[key] for key in ("bytes", "path", "sha256")},
            "attestation file %d" % index,
        )
        for field in ("access", "argument_index", "path", "role"):
            if record[field] != expected[field]:
                fail(
                    "attestation file %d contradicts its Office argument %s"
                    % (index, field)
                )
        if not record["path"].lower().endswith((".xlsx", ".docx", ".html")):
            fail("attestation file has an unsupported suffix: %s" % record["path"])
        paths.append(record["path"])
    if paths != sorted(set(paths)):
        fail("attestation file paths must be sorted and unique")

    expected_inputs = [
        reference
        for reference in path_references
        if reference["access"] in ("input", "input-output")
    ]
    inputs = value["inputs"]
    if not isinstance(inputs, list) or len(inputs) != len(expected_inputs):
        fail("attestation input set does not match the Office command contract")
    snapshot_paths = []
    for index, (record, expected) in enumerate(zip(inputs, expected_inputs)):
        if not isinstance(record, dict) or set(record) != {
            "access",
            "argument_index",
            "path",
            "role",
            "snapshot",
        }:
            fail("attestation input %d has an unexpected shape" % index)
        for field in ("access", "argument_index", "path", "role"):
            if record[field] != expected[field]:
                fail(
                    "attestation input %d contradicts its Office argument %s"
                    % (index, field)
                )
        validate_digest_record(
            record["snapshot"], "attestation input %d snapshot" % index
        )
        snapshot_path = record["snapshot"]["path"]
        if not SNAPSHOT_PATH.fullmatch(snapshot_path):
            fail("attestation input snapshot path is outside the managed namespace")
        snapshot_paths.append(snapshot_path)
    if len(snapshot_paths) != len(set(snapshot_paths)):
        fail("attestation input snapshot paths must be unique")
    canonical = json.dumps(value, sort_keys=True, separators=(",", ":"))
    if payload != canonical:
        fail("attestation JSON is not canonical")
    return value


def validate_digest_record(value, label):
    if not isinstance(value, dict) or set(value) != {"bytes", "path", "sha256"}:
        fail("%s has an unexpected shape" % label)
    safe_relative_path(value["path"], label + " path")
    if not isinstance(value["bytes"], int) or isinstance(value["bytes"], bool):
        fail("%s byte count is not an integer" % label)
    if value["bytes"] <= 0 or value["bytes"] > 128 * 1024 * 1024:
        fail("%s byte count is outside the accepted domain" % label)
    if not isinstance(value["sha256"], str) or not HEX_SHA256.fullmatch(value["sha256"]):
        fail("%s digest is not SHA-256" % label)


def normalize_event(event, seen_results):
    if not isinstance(event, dict):
        fail("command ledger entry is not an object")
    required = {"aggregated_output", "command", "exit_code", "id", "status"}
    if set(event) != required:
        fail("command ledger entry has unexpected fields")
    event_id = event["id"]
    if not isinstance(event_id, str) or not event_id:
        fail("command event id is empty")
    status = event["status"]
    exit_code = event["exit_code"]
    if status not in ("completed", "failed"):
        fail("command event has an unsupported status")
    if not isinstance(exit_code, int) or isinstance(exit_code, bool) or not 0 <= exit_code <= 255:
        fail("command event exit code is outside 0..255")
    if (status == "completed") != (exit_code == 0):
        fail("command status contradicts its exit code")
    output = event["aggregated_output"]
    output_raw = utf8_bytes(output, "command output")
    if len(output_raw) > MAX_EVENT_OUTPUT_BYTES:
        fail("command output exceeds the %d-byte policy limit" % MAX_EVENT_OUTPUT_BYTES)
    argv, redirect_path = parse_simple_command(event["command"])
    name = approved_executable(argv)
    product_argv = None
    attestation = None
    if name in ("office-native", "office-wasm"):
        positions = [index for index, value in enumerate(argv) if value == "--attest-result"]
        path_references = None
        if positions:
            if positions != [len(argv) - 2] or len(argv) < 5:
                fail("--attest-result must be the final Office wrapper option")
            if argv[-3] != "--json":
                fail("attested Office commands must end product arguments with --json")
            if redirect_path is not None:
                fail("attested Office commands may not use shell redirection")
            result_path = safe_relative_path(argv[-1], "--attest-result")
            if result_path == "input-evidence" or result_path.startswith(
                "input-evidence/"
            ):
                fail("--attest-result uses the host-managed input-evidence namespace")
            if not result_path.endswith(".json"):
                fail("--attest-result must name a .json file")
            product_arguments = argv[1:-2]
            try:
                path_references = ARGUMENT_POLICY.classify_office_paths(
                    product_arguments
                )
            except ARGUMENT_POLICY.ArgumentPolicyError as exc:
                fail(str(exc))
            if exit_code == 0:
                if result_path in seen_results:
                    fail("attested result paths must be unique: %s" % result_path)
                seen_results.add(result_path)
                product_argv = argv[:-2]
                attestation = parse_attestation(
                    output, result_path, product_arguments, path_references
                )
            elif ATTESTATION_PREFIX in output:
                fail("failed Office command may not claim a completion attestation")
        elif "--attest-result" in argv:
            fail("invalid --attest-result placement")
        else:
            try:
                path_references = ARGUMENT_POLICY.classify_office_paths(argv[1:])
            except ARGUMENT_POLICY.ArgumentPolicyError as exc:
                fail(str(exc))
        for index, argument in enumerate(argv[1:], start=1):
            if not argument.startswith("/"):
                continue
            if (
                len(argv) > 3
                and argv[1] == "get"
                and index == 3
                and argument in ACCEPTANCE_GET_SELECTORS
            ):
                continue
            if (
                len(argv) > 4
                and argv[1:3] == ["raw", "read"]
                and index == 4
                and argument in ACCEPTANCE_RAW_SELECTORS
            ):
                continue
            fail("absolute Office arguments are not allowed")
    elif name == "office-permission-canary":
        if argv != ["office-permission-canary"] or redirect_path is not None:
            fail("the permission canary must be a direct standalone command")
    else:
        validate_utility(name, argv)
    return {
        "argv": argv,
        "attestation": attestation,
        "command": event["command"],
        "exit_code": exit_code,
        "id": event_id,
        "output_bytes": len(output_raw),
        "output_sha256": hashlib.sha256(output_raw).hexdigest(),
        "product_argv": product_argv,
        "stdout_path": redirect_path,
        "status": status,
    }


def atomic_write_json(path, value):
    parent = os.path.dirname(os.path.abspath(path))
    descriptor, temporary = tempfile.mkstemp(prefix=".command-policy.", dir=parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, sort_keys=True, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        if os.path.lexists(path):
            fail("normalized command ledger already exists")
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
    if len(sys.argv) != 3:
        print("usage: command_policy.py RAW_COMMANDS_JSON OUTPUT_JSON", file=sys.stderr)
        return 64
    source, output = sys.argv[1:]
    source_stat = os.lstat(source)
    if not stat.S_ISREG(source_stat.st_mode) or source_stat.st_size > MAX_INPUT_BYTES:
        fail("raw command ledger is not a bounded regular file")
    with open(source, "r", encoding="utf-8") as stream:
        events = json.load(stream)
    if not isinstance(events, list) or not 0 < len(events) <= MAX_COMMANDS:
        fail("command count is outside 1..%d" % MAX_COMMANDS)
    seen_ids = set()
    seen_results = set()
    normalized = []
    for event in events:
        event_id = event.get("id") if isinstance(event, dict) else None
        if event_id in seen_ids:
            fail("command event ids must be unique")
        seen_ids.add(event_id)
        normalized.append(normalize_event(event, seen_results))
    atomic_write_json(output, normalized)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, PolicyError, UnicodeError, ValueError) as exc:
        print("command policy rejected transcript: %s" % exc, file=sys.stderr)
        sys.exit(1)
