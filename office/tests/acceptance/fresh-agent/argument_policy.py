#!/usr/bin/env python3
"""Classify filesystem paths in installed Office command arguments."""

import re


SAFE_RELATIVE = re.compile(r"^[a-z0-9][a-z0-9._/-]*$")
PATH_ACCESSES = frozenset({"input", "input-output", "output"})


class ArgumentPolicyError(Exception):
    pass


def fail(message):
    raise ArgumentPolicyError(message)


def safe_relative_path(value, label):
    if not isinstance(value, str):
        fail("%s is not a portable lowercase relative path: %r" % (label, value))
    if any(part in ("", ".", "..") for part in value.split("/")):
        fail("%s traverses a non-canonical path: %r" % (label, value))
    if not SAFE_RELATIVE.fullmatch(value):
        fail("%s is not a portable lowercase relative path: %r" % (label, value))
    if value.endswith("/") or "//" in value:
        fail("%s is not canonical: %r" % (label, value))
    return value


def add_reference(references, arguments, index, role, access):
    if index < 0 or index >= len(arguments):
        return
    value = arguments[index]
    if not isinstance(value, str) or value.startswith("-"):
        return
    if access not in PATH_ACCESSES:
        fail("internal path access is invalid: %s" % access)
    path = safe_relative_path(value, "%s path" % role)
    if path == "input-evidence" or path.startswith("input-evidence/"):
        fail("%s path uses the host-managed input-evidence namespace" % role)
    references.append(
        {
            "access": access,
            "argument_index": index,
            "path": path,
            "role": role,
        }
    )


def option_positions(arguments, option):
    positions = []
    prefix = option + "="
    for index, value in enumerate(arguments):
        if value == option:
            if index + 1 < len(arguments) and not arguments[index + 1].startswith("-"):
                positions.append(index + 1)
        elif value.startswith(prefix):
            fail("%s path must be a separate shell token" % option)
    return positions


def add_option_references(references, arguments, option, role, access):
    positions = option_positions(arguments, option)
    if len(positions) > 1:
        fail("%s path option is repeated" % option)
    for index in positions:
        add_reference(references, arguments, index, role, access)
    return positions


def batch_positionals(arguments):
    positionals = []
    format_name = None
    index = 1
    while index < len(arguments):
        value = arguments[index]
        if value in ("--format", "--out"):
            if index + 1 < len(arguments):
                if value == "--format":
                    format_name = arguments[index + 1]
                index += 2
                continue
            index += 1
            continue
        if value.startswith("--format="):
            format_name = value.split("=", 1)[1]
            index += 1
            continue
        if value.startswith("--out="):
            fail("--out path must be a separate shell token")
        if not value.startswith("-"):
            positionals.append(index)
        index += 1
    return positionals, format_name


def classify_batch(arguments, references):
    out_positions = add_option_references(
        references, arguments, "--out", "package-output", "output"
    )
    positionals, format_name = batch_positionals(arguments)
    if positionals:
        target_access = "output" if format_name == "docx" else (
            "input" if out_positions else "input-output"
        )
        target_role = "package-output" if target_access == "output" else "package"
        add_reference(
            references, arguments, positionals[0], target_role, target_access
        )
    if len(positionals) > 1:
        add_reference(references, arguments, positionals[1], "script", "input")


def classify_raw(arguments, references):
    if len(arguments) < 2:
        return
    operation = arguments[1]
    if operation == "list":
        add_reference(references, arguments, 2, "package", "input")
    elif operation == "read":
        add_reference(references, arguments, 2, "package", "input")
        add_option_references(
            references, arguments, "--output", "payload-output", "output"
        )
    elif operation in ("replace", "edit"):
        out_positions = add_option_references(
            references, arguments, "--out", "package-output", "output"
        )
        add_reference(
            references,
            arguments,
            2,
            "package",
            "input" if out_positions else "input-output",
        )
        add_option_references(
            references, arguments, "--xml-file", "xml", "input"
        )


def classify_office_paths(arguments):
    if not isinstance(arguments, list) or any(
        not isinstance(value, str) for value in arguments
    ):
        fail("Office arguments must be a string array")
    if not arguments:
        return []

    references = []
    operation = arguments[0]
    if operation in (
        "identify",
        "outline",
        "get",
        "text",
        "query",
        "validate",
        "issues",
        "dump",
    ):
        add_reference(references, arguments, 1, "package", "input")
    elif operation == "replay":
        add_reference(references, arguments, 1, "dump", "input")
        add_option_references(
            references, arguments, "--output", "package-output", "output"
        )
    elif operation == "preview":
        add_reference(references, arguments, 1, "package", "input")
        add_option_references(
            references, arguments, "--output", "preview-output", "output"
        )
    elif operation == "create":
        add_reference(references, arguments, 2, "package-output", "output")
    elif operation == "template":
        add_reference(references, arguments, 1, "package", "input")
        add_reference(references, arguments, 2, "template-data", "input")
        add_option_references(
            references, arguments, "--out", "package-output", "output"
        )
    elif operation == "annotate":
        add_reference(references, arguments, 1, "package", "input")
        add_reference(references, arguments, 2, "annotation-script", "input")
        add_option_references(
            references, arguments, "--out", "package-output", "output"
        )
    elif operation == "edit":
        add_reference(references, arguments, 1, "package", "input")
        add_reference(references, arguments, 2, "edit-script", "input")
        add_option_references(
            references, arguments, "--out", "package-output", "output"
        )
    elif operation == "batch":
        classify_batch(arguments, references)
    elif operation == "raw":
        classify_raw(arguments, references)

    references.sort(key=lambda value: value["argument_index"])
    positions = [value["argument_index"] for value in references]
    if len(positions) != len(set(positions)):
        fail("one Office argument was classified as multiple filesystem paths")
    return references


if __name__ == "__main__":
    raise SystemExit("argument_policy.py is an import-only policy")
