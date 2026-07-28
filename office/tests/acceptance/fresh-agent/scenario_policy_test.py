#!/usr/bin/env python3
"""Focused semantic tests for host-derived fresh-agent scenario evidence."""

import importlib.util
import os
import sys
import tempfile


def load_policy(path):
    spec = importlib.util.spec_from_file_location("fresh_agent_scenario_policy", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def expect_rejected(policy, action):
    try:
        action()
    except (OSError, policy.ScenarioError):
        return
    raise AssertionError("shallow scenario evidence was accepted")


def xlsx_batch(policy):
    return {
        "schema": "xlsx.batch/2",
        "ops": [
            {
                "op": "set",
                "params": {
                    "sheet": "Sheet1",
                    "cell": "A1",
                    "value": policy.XLSX_CONTENT_MARKER,
                },
            },
            {
                "op": "set",
                "params": {"sheet": "Sheet1", "cell": "B2", "value": 21},
            },
            {
                "op": "formula",
                "params": {
                    "sheet": "Sheet1",
                    "cell": "B4",
                    "formula": "SUM(B2:B3)",
                },
            },
            {
                "op": "chart",
                "params": {
                    "sheet": "Sheet1",
                    "anchor": "D2",
                    "categories": "A2:A3",
                    "values": "B2:B3",
                },
            },
            {
                "op": "set",
                "params": {
                    "sheet": "Sheet1",
                    "cell": "A5",
                    "value": "{{agent_name}}",
                },
            },
        ],
    }


def docx_batch(policy):
    return {
        "schema": "docx.batch/2",
        "ops": [
            {
                "op": "paragraph",
                "params": {
                    "text": policy.DOCX_HEADING_MARKER,
                    "style": "Heading1",
                },
            },
            {"op": "paragraph", "params": {"text": "{{agent_name}}"}},
            {
                "op": "paragraph",
                "params": {
                    "text": policy.DOCX_LIST_MARKER,
                    "list": {"ordered": False},
                },
            },
            {
                "op": "table",
                "params": {"rows": [[{"text": policy.DOCX_TABLE_MARKER}]]},
            },
            {
                "op": "paragraph",
                "params": {
                    "runs": [
                        {
                            "link": {
                                "href": policy.DOCX_LINK_TARGET,
                                "text": "reference",
                            }
                        }
                    ]
                },
            },
        ],
    }


def annotation_script(policy):
    return {
        "schema": "docx.annotation-batch/1",
        "ops": [
            {
                "op": "comment_add",
                "anchor": {"at": "/docx/body/p[1]"},
                "author": "Ada",
                "body": [policy.COMMENT_MARKER],
                "label": "root",
            },
            {
                "op": "comment_reply",
                "parent": {"label": "root"},
                "author": "Bob",
                "body": [policy.REPLY_MARKER],
                "label": "reply",
            },
            {"op": "comment_resolve", "target": {"label": "root"}},
        ],
    }


def main(argv):
    if len(argv) != 2:
        raise SystemExit("usage: scenario_policy_test.py SCENARIO_POLICY")
    policy = load_policy(argv[1])

    assert len(policy.validate_xlsx_batch(xlsx_batch(policy))) == 64
    assert len(policy.validate_docx_batch(docx_batch(policy))) == 64
    for format_name in policy.FORMATS:
        value = {
            "schema": "office.template.data/1",
            "values": {
                policy.TEMPLATE_KEY: policy.TEMPLATE_MARKERS[format_name]
            },
        }
        assert len(policy.validate_template_data(value, format_name)) == 64
    assert len(policy.validate_annotation_script(annotation_script(policy))) == 64

    dump = {
        "schema": "office.dump/1",
        "format": "xlsx",
        "source": {"file": "source.xlsx"},
        "replay": {"batch_schema": "xlsx.batch/2", "create": {}},
        "ops": [{"op": "set", "params": {}}],
        "assets": {},
        "residual": [{"code": "ignored-by-fixpoint"}],
    }
    assert set(policy.dump_projection(dump, "xlsx")) == {
        "assets",
        "ops",
        "replay",
    }

    preview = {
        "schema": "office.output/1",
        "success": True,
        "data": {
            "schema": "office.preview/1",
            "format": "xlsx",
            "charts_rendered": 1,
            "charts_placeholder": 0,
            "images_embedded": 0,
            "truncation": {"truncated_sheets": 0},
        },
    }
    assert policy.preview_projection(preview, "xlsx")["charts_rendered"] == 1

    failure = (
        '{"schema":"office.output/1","success":false,'
        '"error":{"code":"office.transaction.output_exists"}}'
    )
    assert policy.parse_failure_result(
        failure,
        "office.transaction.output_exists",
    ) == "office.transaction.output_exists"

    normalized = policy.normalize_runtime_paths(
        {
            "file": "native/xlsx/final.xlsx",
            "warnings": ["target detail"],
            "data": ["native/xlsx/final.xlsx"],
        },
        "native",
    )
    assert normalized == {
        "file": "$runtime/xlsx/final.xlsx",
        "data": ["$runtime/xlsx/final.xlsx"],
    }

    shallow_xlsx = xlsx_batch(policy)
    shallow_xlsx["ops"] = shallow_xlsx["ops"][:-1]
    expect_rejected(policy, lambda: policy.validate_xlsx_batch(shallow_xlsx))
    shallow_docx = docx_batch(policy)
    shallow_docx["ops"] = shallow_docx["ops"][:-1]
    expect_rejected(policy, lambda: policy.validate_docx_batch(shallow_docx))
    shallow_annotation = annotation_script(policy)
    shallow_annotation["ops"] = shallow_annotation["ops"][:1]
    expect_rejected(
        policy,
        lambda: policy.validate_annotation_script(shallow_annotation),
    )
    expect_rejected(policy, lambda: policy.parse_failure_result("false\n"))
    expect_rejected(
        policy,
        lambda: policy.safe_relative_path("../private.json", "test path"),
    )
    with tempfile.TemporaryDirectory(prefix="scenario-policy-test.") as root:
        os.chmod(root, 0o700)
        os.mkdir(os.path.join(root, "safe"), 0o700)
        payload_path = os.path.join(root, "safe", "value.json")
        with open(payload_path, "wb") as stream:
            stream.write(b'{"value":1}\n')
        os.chmod(payload_path, 0o600)
        record, payload = policy.inspect_bound_file(
            root,
            "safe/value.json",
            "test value",
            policy.MAX_JSON_BYTES,
        )
        assert record["bytes"] == len(payload)
        result_record = dict(record, schema="office.test/1")
        assert policy.read_record(
            root,
            result_record,
            "workflow result",
            parse_json=True,
        ) == {"value": 1}
        expect_rejected(
            policy,
            lambda: policy.read_record(
                root,
                dict(result_record, unexpected=True),
                "over-specified result",
                parse_json=True,
            ),
        )
        os.symlink("value.json", os.path.join(root, "safe", "alias.json"))
        expect_rejected(
            policy,
            lambda: policy.inspect_bound_file(
                root,
                "safe/alias.json",
                "symlink value",
                policy.MAX_JSON_BYTES,
            ),
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
