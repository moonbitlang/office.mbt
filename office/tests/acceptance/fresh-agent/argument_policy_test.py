#!/usr/bin/env python3
"""Focused tests for installed Office filesystem-argument classification."""

import importlib.util
import sys


def load_policy(path):
    spec = importlib.util.spec_from_file_location("fresh_agent_argument_policy", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def expect_rejected(policy, arguments):
    try:
        policy.classify_office_paths(arguments)
    except policy.ArgumentPolicyError:
        return
    raise AssertionError("unsafe Office arguments were accepted: %r" % arguments)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: argument_policy_test.py ARGUMENT_POLICY")
    policy = load_policy(sys.argv[1])

    assert policy.classify_office_paths(
        ["template", "template.xlsx", "data.json", "--out", "merged.xlsx", "--json"]
    ) == [
        {
            "access": "input",
            "argument_index": 1,
            "path": "template.xlsx",
            "role": "package",
        },
        {
            "access": "input",
            "argument_index": 2,
            "path": "data.json",
            "role": "template-data",
        },
        {
            "access": "output",
            "argument_index": 4,
            "path": "merged.xlsx",
            "role": "package-output",
        },
    ]
    assert policy.classify_office_paths(
        ["batch", "--format", "docx", "fresh.docx", "authoring", "--json"]
    ) == [
        {
            "access": "output",
            "argument_index": 3,
            "path": "fresh.docx",
            "role": "package",
        },
        {
            "access": "input",
            "argument_index": 4,
            "path": "authoring",
            "role": "script",
        },
    ]
    assert policy.classify_office_paths(
        ["batch", "source.xlsx", "ops.json", "--out", "result.xlsx", "--json"]
    )[0]["access"] == "input"
    assert policy.classify_office_paths(
        ["batch", "source.xlsx", "ops.json", "--json"]
    )[0]["access"] == "input-output"
    assert policy.classify_office_paths(
        [
            "raw",
            "replace",
            "source.docx",
            "part:/word/document.xml",
            "--xml-file",
            "replacement",
            "--out",
            "result.docx",
            "--json",
        ]
    ) == [
        {
            "access": "input",
            "argument_index": 2,
            "path": "source.docx",
            "role": "package",
        },
        {
            "access": "input",
            "argument_index": 5,
            "path": "replacement",
            "role": "xml",
        },
        {
            "access": "output",
            "argument_index": 7,
            "path": "result.docx",
            "role": "package-output",
        },
    ]

    unsafe = [
        ["batch", "source.xlsx", "../../../../private/tmp/ops.json", "--json"],
        ["preview", "source.xlsx", "--output", "../preview.html", "--json"],
        ["template", "source.docx", "data.json", "--out=../result.docx", "--json"],
        [
            "raw",
            "replace",
            "source.docx",
            "part:/word/document.xml",
            "--xml-file",
            "../../replacement",
            "--json",
        ],
        ["identify", "input-evidence/event-a/000.xlsx", "--json"],
    ]
    for arguments in unsafe:
        expect_rejected(policy, arguments)

    print("ARGUMENT POLICY TEST PASS")


if __name__ == "__main__":
    main()
