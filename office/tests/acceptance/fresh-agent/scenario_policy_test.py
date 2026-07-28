#!/usr/bin/env python3
"""Focused semantic tests for host-derived fresh-agent scenario evidence."""

import importlib.util
import hashlib
import os
import sys
import tempfile
import zipfile


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


def write_fixture(path, entries):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, payload in entries.items():
            archive.writestr(name, payload)
    os.chmod(path, 0o600)


def xlsx_fixture(policy, final):
    template = policy.TEMPLATE_MARKERS["xlsx"] if final else "{{agent_name}}"
    return {
        "xl/sharedStrings.xml": (
            '<sst xmlns="%s"><si><t>%s</t></si><si><t>%s</t></si></sst>'
            % (policy.XLSX_NS, policy.XLSX_CONTENT_MARKER, template)
        ),
        "xl/worksheets/sheet1.xml": (
            '<worksheet xmlns="%s"><sheetData><row r="1">'
            '<c r="A1" t="s"><v>0</v></c><c r="A2"><v>42</v></c>'
            '<c r="A3"><f>SUM(A2:A2)</f><v>42</v></c>'
            '<c r="A4" t="s"><v>1</v></c>'
            '</row></sheetData></worksheet>' % policy.XLSX_NS
        ),
        "xl/charts/chart1.xml": (
            '<c:chartSpace xmlns:c="%s"><c:chart><c:plotArea>'
            '<c:barChart><c:ser/></c:barChart>'
            '</c:plotArea></c:chart></c:chartSpace>' % policy.CHART_NS
        ),
    }


def docx_fixture(policy, final):
    template = policy.TEMPLATE_MARKERS["docx"] if final else "{{agent_name}}"
    document = (
        '<w:document xmlns:w="%s" xmlns:r="%s"><w:body>'
        '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>%s</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>%s</w:t></w:r></w:p>'
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>%s</w:t></w:r></w:p>'
        '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>%s</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
        '<w:p><w:hyperlink r:id="rId1"><w:r><w:t>F1B link</w:t></w:r></w:hyperlink></w:p>'
        '</w:body></w:document>'
        % (
            policy.WORD_NS,
            policy.OFFICE_REL_NS,
            policy.DOCX_HEADING_MARKER,
            template,
            policy.DOCX_LIST_MARKER,
            policy.DOCX_TABLE_MARKER,
        )
    )
    entries = {
        "word/document.xml": document,
        "word/_rels/document.xml.rels": (
            '<Relationships xmlns="%s"><Relationship Id="rId1" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" '
            'Target="%s" TargetMode="External"/></Relationships>'
            % (policy.REL_NS, policy.DOCX_LINK_TARGET)
        ),
    }
    if final:
        entries["word/comments.xml"] = (
            '<w:comments xmlns:w="%s"><w:comment w:id="0"><w:p><w:r><w:t>%s</w:t></w:r></w:p></w:comment>'
            '<w:comment w:id="1"><w:p><w:r><w:t>%s</w:t></w:r></w:p></w:comment></w:comments>'
            % (policy.WORD_NS, policy.COMMENT_MARKER, policy.REPLY_MARKER)
        )
        entries["word/commentsExtended.xml"] = (
            '<w15:commentsEx xmlns:w15="%s"><w15:commentEx w15:paraId="00000001" w15:done="1"/>'
            '<w15:commentEx w15:paraId="00000002" w15:paraIdParent="00000001" w15:done="0"/>'
            '</w15:commentsEx>' % policy.WORD_2012_NS
        )
    return entries


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
    assert len(
        policy.validate_docx_refusal_script(
            {
                "schema": "docx.batch/2",
                "ops": [{"op": "f1b_invalid_operation", "params": {}}],
            }
        )
    ) == 64

    dump = {
        "schema": "office.dump/1",
        "format": "xlsx",
        "source": {"file": "source.xlsx"},
        "replay": {"batch_schema": "xlsx.batch/2", "create": {}},
        "ops": [
            {
                "op": "set",
                "params": {"value": policy.XLSX_CONTENT_MARKER},
            },
            {
                "op": "set",
                "params": {"value": policy.TEMPLATE_MARKERS["xlsx"]},
            },
            {"op": "formula", "params": {"formula": "SUM(A1:A2)"}},
            {"op": "chart", "params": {"values": "A1:A2"}},
        ],
        "assets": {},
        "residual": [{"code": "ignored-by-fixpoint"}],
        "warnings": [],
        "stats": {"ops": 1},
    }
    assert set(policy.dump_projection(dump, "xlsx")) == set(dump) - {"source"}

    preview = {
        "schema": "office.output/1",
        "success": True,
        "data": {
            "schema": "office.preview/1",
            "format": "xlsx",
            "charts_rendered": 1,
            "charts_placeholder": 0,
            "images_embedded": 0,
            "truncation": {
                "max_rows": 200,
                "max_cols": 50,
                "truncated_sheets": 0,
                "images_omitted": 0,
            },
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
        "warnings": ["target detail"],
        "data": ["$runtime/xlsx/final.xlsx"],
    }
    core, diagnostics = policy.split_runtime_diagnostics(normalized, "native")
    assert "warnings" not in core
    assert diagnostics == [
        {
            "field": "warnings",
            "location": "$.warnings",
            "value": "target detail",
        }
    ]
    counters, diagnostics = policy.split_runtime_diagnostics(
        {"stats": {"warnings": 2}},
        "native",
    )
    assert counters == {"stats": {"warnings": 2}}
    assert diagnostics == []
    common = {
        "field": "warnings",
        "location": "$.warnings",
        "operation": "batch",
        "value": {"code": "office.shared", "message": "shared"},
    }
    limitation = {
        "field": "warnings",
        "location": "$.warnings",
        "operation": "batch",
        "value": policy.WASM_COMMIT_WARNING,
    }
    classification = policy.classify_runtime_diagnostics(
        [common],
        [common, limitation],
        "xlsx",
    )
    assert classification["target_limitations"] == [limitation]
    unknown = {**limitation, "value": {"code": "office.unknown"}}
    expect_rejected(
        policy,
        lambda: policy.classify_runtime_diagnostics(
            [common],
            [common, limitation, unknown],
            "xlsx",
        ),
    )

    preview_payload = (
        '<p>%s</p><p>%s</p><figure class="chart">chart</figure>'
        % (policy.XLSX_CONTENT_MARKER, policy.TEMPLATE_MARKERS["xlsx"])
    )
    assert policy.preview_content_projection(preview_payload, "xlsx")[
        "representative_content"
    ]
    expect_rejected(
        policy,
        lambda: policy.preview_content_projection("<title>canned</title>", "xlsx"),
    )

    raw_xlsx = {
        "schema": "office.output/1",
        "success": True,
        "data": {
            "schema": "office.raw.inventory/1",
            "parts": [
                {"name": "xl/workbook.xml"},
                {"name": "xl/worksheets/sheet1.xml"},
                {"name": "xl/charts/chart1.xml"},
            ],
        },
    }
    assert policy.validate_raw_semantics(raw_xlsx, "xlsx")["chart_part"]
    raw_docx = {
        "schema": "office.output/1",
        "success": True,
        "data": {
            "schema": "office.raw.part/1",
            "content": " ".join(
                (
                    policy.DOCX_HEADING_MARKER,
                    policy.DOCX_LIST_MARKER,
                    policy.DOCX_TABLE_MARKER,
                    policy.TEMPLATE_MARKERS["docx"],
                )
            ),
        },
    }
    assert policy.validate_raw_semantics(raw_docx, "docx")[
        "main_document_content"
    ]
    raw_docx["data"]["content"] = "<document/>"
    expect_rejected(
        policy,
        lambda: policy.validate_raw_semantics(raw_docx, "docx"),
    )

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
    bad_dump = dict(dump, residual="lost")
    expect_rejected(policy, lambda: policy.dump_projection(bad_dump, "xlsx"))
    bad_preview = {
        **preview,
        "data": {**preview["data"], "charts_rendered": -1},
    }
    expect_rejected(policy, lambda: policy.preview_projection(bad_preview, "xlsx"))
    expect_rejected(
        policy,
        lambda: policy.safe_relative_path("../private.json", "test path"),
    )
    with tempfile.TemporaryDirectory(prefix="scenario-policy-test.") as root:
        os.chmod(root, 0o700)
        os.mkdir(os.path.join(root, "safe"), 0o700)
        for format_name, builder, inspector in (
            ("xlsx", xlsx_fixture, policy.inspect_xlsx_semantics),
            ("docx", docx_fixture, policy.inspect_docx_semantics),
        ):
            for final in (False, True):
                stage = "final" if final else "authored"
                path = os.path.join(root, "safe", "%s-%s.zip" % (format_name, stage))
                write_fixture(path, builder(policy, final))
                relative = "safe/%s-%s.zip" % (format_name, stage)
                info = os.stat(path)
                with open(path, "rb") as stream:
                    digest = hashlib.sha256(stream.read()).hexdigest()
                record = {"bytes": info.st_size, "path": relative, "sha256": digest}
                semantics = inspector(root, record, relative, final)
                assert semantics["template_state"] == (
                    "merged" if final else "placeholder"
                )
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
