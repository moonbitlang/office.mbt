#!/usr/bin/env python3
"""Focused semantic tests for host-derived fresh-agent scenario evidence."""

import importlib.util
import hashlib
import copy
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
        "ops": policy.representative_xlsx_batch_ops(),
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


def annotation_result():
    return {
        "schema": "office.output/1",
        "success": True,
        "data": {
            "schema": "office.docx.annotation-batch/1",
            "ops_applied": 3,
            "results": [
                {
                    "op": "comment_add",
                    "comment_id": "0",
                    "done": None,
                    "anchor": "/docx/body/p[1]",
                },
                {
                    "op": "comment_reply",
                    "comment_id": "1",
                    "done": None,
                    "target": "0",
                },
                {
                    "op": "comment_resolve",
                    "comment_id": "0",
                    "done": True,
                    "target": "0",
                },
            ],
            "labels": [
                {"label": "root", "comment_id": "0"},
                {"label": "reply", "comment_id": "1"},
            ],
        },
    }


def write_fixture(path, entries):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, payload in entries.items():
            archive.writestr(name, payload)
    os.chmod(path, 0o600)


def xlsx_fixture(policy, final):
    template = policy.TEMPLATE_MARKERS["xlsx"] if final else "{{agent_name}}"
    return {
        "xl/workbook.xml": (
            '<workbook xmlns="%s" xmlns:r="%s"><sheets>'
            '<sheet name="Data" sheetId="1" r:id="rId1"/>'
            '</sheets></workbook>' % (policy.XLSX_NS, policy.OFFICE_REL_NS)
        ),
        "xl/_rels/workbook.xml.rels": (
            '<Relationships xmlns="%s"><Relationship Id="rId1" '
            'Type="%s/worksheet" Target="worksheets/sheet1.xml"/>'
            '</Relationships>' % (policy.REL_NS, policy.OFFICE_REL_NS)
        ),
        "xl/sharedStrings.xml": (
            '<sst xmlns="%s"><si><t>%s</t></si><si><t>%s</t></si></sst>'
            % (policy.XLSX_NS, policy.XLSX_CONTENT_MARKER, template)
        ),
        "xl/worksheets/sheet1.xml": (
            '<worksheet xmlns="%s" xmlns:r="%s"><sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c></row>'
            '<row r="2"><c r="B2"><v>30</v></c></row>'
            '<row r="3"><c r="B3"><v>70</v></c></row>'
            '<row r="4"><c r="B4"><f>SUM(B2:B3)</f></c></row>'
            '<row r="5"><c r="A5" t="s"><v>1</v></c></row>'
            '</sheetData><drawing r:id="rId1"/></worksheet>'
            % (policy.XLSX_NS, policy.OFFICE_REL_NS)
        ),
        "xl/worksheets/_rels/sheet1.xml.rels": (
            '<Relationships xmlns="%s"><Relationship Id="rId1" '
            'Type="%s/drawing" Target="../drawings/drawing1.xml"/>'
            '</Relationships>' % (policy.REL_NS, policy.OFFICE_REL_NS)
        ),
        "xl/drawings/drawing1.xml": (
            '<xdr:wsDr xmlns:xdr="%s" xmlns:c="%s" xmlns:r="%s">'
            '<xdr:twoCellAnchor><xdr:from><xdr:col>3</xdr:col>'
            '<xdr:row>1</xdr:row></xdr:from><xdr:graphicFrame>'
            '<c:chart r:id="rId1"/></xdr:graphicFrame></xdr:twoCellAnchor>'
            '</xdr:wsDr>'
            % (
                policy.SPREADSHEET_DRAWING_NS,
                policy.CHART_NS,
                policy.OFFICE_REL_NS,
            )
        ),
        "xl/drawings/_rels/drawing1.xml.rels": (
            '<Relationships xmlns="%s"><Relationship Id="rId1" '
            'Type="%s/chart" Target="../charts/chart1.xml"/>'
            '</Relationships>' % (policy.REL_NS, policy.OFFICE_REL_NS)
        ),
        "xl/charts/chart1.xml": (
            '<c:chartSpace xmlns:c="%s" xmlns:a="%s"><c:chart>'
            '<c:title><c:tx><c:rich><a:p><a:r><a:t>Representative</a:t>'
            '</a:r></a:p></c:rich></c:tx></c:title><c:plotArea>'
            '<c:barChart><c:barDir val="col"/><c:ser><c:tx><c:v>F1B</c:v>'
            '</c:tx><c:cat><c:strRef><c:f>\'Data\'!A2:A3</c:f></c:strRef>'
            '</c:cat><c:val><c:numRef><c:f>\'Data\'!B2:B3</c:f></c:numRef>'
            '</c:val></c:ser></c:barChart></c:plotArea></c:chart></c:chartSpace>'
            % (policy.CHART_NS, policy.DRAWING_NS)
        ),
    }


def docx_fixture(policy, final, resolve_reply=False, anchor_paragraph=1):
    template = policy.TEMPLATE_MARKERS["docx"] if final else "{{agent_name}}"
    anchor_start = '<w:commentRangeStart w:id="0"/>'
    anchor_end = (
        '<w:commentRangeEnd w:id="0"/>'
        '<w:r><w:commentReference w:id="0"/></w:r>'
    )

    def anchored(paragraph, content):
        if final and paragraph == anchor_paragraph:
            return anchor_start + content + anchor_end
        return content

    document = (
        '<w:document xmlns:w="%s" xmlns:r="%s"><w:body>'
        '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr>%s</w:p>'
        '<w:p>%s</w:p>'
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>%s</w:t></w:r></w:p>'
        '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>%s</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
        '<w:p><w:hyperlink r:id="rId1"><w:r><w:t>F1B link</w:t></w:r></w:hyperlink></w:p>'
        '</w:body></w:document>'
        % (
            policy.WORD_NS,
            policy.OFFICE_REL_NS,
            anchored(
                1,
                '<w:r><w:t>%s</w:t></w:r>' % policy.DOCX_HEADING_MARKER,
            ),
            anchored(2, '<w:r><w:t>%s</w:t></w:r>' % template),
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
            '<w:comments xmlns:w="%s" xmlns:w14="%s"><w:comment w:id="0">'
            '<w:p w14:paraId="00000001"><w:r><w:t>%s</w:t></w:r></w:p></w:comment>'
            '<w:comment w:id="1"><w:p w14:paraId="00000002"><w:r><w:t>%s</w:t>'
            '</w:r></w:p></w:comment></w:comments>'
            % (
                policy.WORD_NS,
                policy.WORD_2010_NS,
                policy.COMMENT_MARKER,
                policy.REPLY_MARKER,
            )
        )
        entries["word/commentsExtended.xml"] = (
            '<w15:commentsEx xmlns:w15="%s"><w15:commentEx w15:paraId="00000001" w15:done="%s"/>'
            '<w15:commentEx w15:paraId="00000002" w15:paraIdParent="00000001" w15:done="%s"/>'
            '</w15:commentsEx>'
            % (
                policy.WORD_2012_NS,
                "0" if resolve_reply else "1",
                "1" if resolve_reply else "0",
            )
        )
    return entries


def xlsx_get_result(policy):
    path = '/xlsx/sheet[name="Data"]/range[A1:B5]'
    cells = []
    expected = policy.expected_xlsx_projection(xlsx_batch(policy), final=True)
    for reference in ("A1", "B2", "B3", "B4", "A5"):
        row, column = policy.xlsx_reference_coordinates(reference, "test get")
        semantic = expected["cells"][reference]
        cell = {
            "path": '/xlsx/sheet[name="Data"]/cell[%s]' % reference,
            "reference": reference,
            "row": row,
            "column": column,
        }
        if semantic["kind"] == "formula":
            cell["formula"] = semantic["formula"]
        else:
            cell["value"] = str(semantic["value"])
            cell["raw"] = {
                "type": semantic["kind"],
                "value": semantic["value"],
            }
        cells.append(cell)
    return {
        "schema": "office.output/1",
        "success": True,
        "data": {
            "schema": "office.xlsx.element/1",
            "format": "xlsx",
            "path": path,
            "kind": "range",
            "stability": "snapshot-relative",
            "parent": '/xlsx/sheet[name="Data"]',
            "reference": "A1:B5",
            "cells": cells,
            "styles": {},
            "scanned_cells": 10,
            "returned": 5,
        },
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
    annotation_contract = policy.validate_annotation_script(annotation_script(policy))
    assert len(annotation_contract["sha256"]) == 64
    annotation_ids = policy.validate_annotation_result(
        annotation_result(),
        annotation_contract,
        "test annotation result",
    )
    assert annotation_ids == {
        "root_comment_id": "0",
        "reply_comment_id": "1",
        "root_anchor": "/docx/body/p[1]",
    }
    assert len(
        policy.validate_docx_refusal_script(
            {
                "schema": "docx.batch/2",
                "ops": [{"op": "f1b_invalid_operation", "params": {}}],
            }
        )
    ) == 64
    assert len(
        policy.validate_xlsx_refusal_script(
            {
                "schema": "xlsx.batch/2",
                "ops": [
                    {
                        "op": "set",
                        "params": {
                            "sheet": "Data",
                            "cell": "A9",
                            "value": "refusal",
                        },
                    }
                ],
            }
        )
    ) == 64

    expected_dump_ops = policy.expected_xlsx_dump_ops(xlsx_batch(policy), final=True)
    dump = {
        "schema": "office.dump/1",
        "format": "xlsx",
        "source": {"file": "source.xlsx"},
        "replay": {"batch_schema": "xlsx.batch/2", "create": {}},
        "ops": expected_dump_ops,
        "assets": {},
        "residual": [{"code": "ignored-by-fixpoint"}],
        "warnings": [],
        "stats": {"ops": len(expected_dump_ops)},
    }
    assert set(
        policy.dump_projection(dump, "xlsx", expected_ops=expected_dump_ops)
    ) == set(dump) - {"source"}

    get_result = xlsx_get_result(policy)
    get_projection = policy.validate_xlsx_get_semantics(
        get_result,
        policy.expected_xlsx_projection(xlsx_batch(policy), final=True),
    )
    assert [cell["reference"] for cell in get_projection["cells"]] == [
        "A1",
        "B2",
        "B3",
        "B4",
        "A5",
    ]

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
                "truncated_sheets": ["Wide"],
                "images_omitted": 0,
            },
        },
    }
    assert policy.preview_projection(preview, "xlsx")["charts_rendered"] == 1

    failure = (
        '{"schema":"office.output/1","success":false,'
        '"error":{"code":"office.transaction.output_exists",'
        '"message":"output exists","details":{"output":"native/x.xlsx"}}}'
    )
    assert policy.parse_failure_result(
        failure,
        "office.transaction.output_exists",
    ) == "office.transaction.output_exists"
    failure_core, failure_diagnostics = policy.split_runtime_diagnostics(
        policy.normalize_failure_envelope(
            {
                "schema": "office.output/1",
                "success": False,
                "error": {
                    "code": "office.transaction.output_exists",
                    "message": "output exists",
                    "details": {"output": "native/x.xlsx"},
                },
                "warnings": [{"code": "office.test", "message": "warning"}],
            },
            "office.transaction.output_exists",
            "test refusal",
        ),
        "native",
    )
    assert failure_core["error"]["details"]["output"] == "$runtime/x.xlsx"
    assert failure_diagnostics == [
        {
            "field": "warnings",
            "location": "$.warnings",
            "value": {"code": "office.test", "message": "warning"},
        }
    ]

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
    wrong_xlsx = xlsx_batch(policy)
    wrong_xlsx["ops"][1]["params"]["cell"] = "B1"
    expect_rejected(policy, lambda: policy.validate_xlsx_batch(wrong_xlsx))
    shallow_docx = docx_batch(policy)
    shallow_docx["ops"] = shallow_docx["ops"][:-1]
    expect_rejected(policy, lambda: policy.validate_docx_batch(shallow_docx))
    shallow_annotation = annotation_script(policy)
    shallow_annotation["ops"] = shallow_annotation["ops"][:1]
    expect_rejected(
        policy,
        lambda: policy.validate_annotation_script(shallow_annotation),
    )
    wrong_target_annotation = annotation_script(policy)
    wrong_target_annotation["ops"][2]["target"]["label"] = "reply"
    expect_rejected(
        policy,
        lambda: policy.validate_annotation_script(wrong_target_annotation),
    )
    wrong_target_result = annotation_result()
    wrong_target_result["data"]["results"][2]["comment_id"] = "1"
    wrong_target_result["data"]["results"][2]["target"] = "1"
    expect_rejected(
        policy,
        lambda: policy.validate_annotation_result(
            wrong_target_result,
            annotation_contract,
            "wrong-target annotation result",
        ),
    )
    wrong_anchor_result = annotation_result()
    wrong_anchor_result["data"]["results"][0]["anchor"] = "/docx/body/p[2]"
    expect_rejected(
        policy,
        lambda: policy.validate_annotation_result(
            wrong_anchor_result,
            annotation_contract,
            "wrong-anchor annotation result",
        ),
    )
    expect_rejected(policy, lambda: policy.parse_failure_result("false\n"))
    expect_rejected(
        policy,
        lambda: policy.normalize_failure_envelope(
            {
                "schema": "office.output/1",
                "success": False,
                "error": {"code": "office.transaction.output_exists"},
            },
            "office.transaction.output_exists",
            "incomplete refusal",
        ),
    )
    bad_dump = dict(dump, residual="lost")
    expect_rejected(
        policy,
        lambda: policy.dump_projection(
            bad_dump,
            "xlsx",
            expected_ops=expected_dump_ops,
        ),
    )
    wrong_dump = copy.deepcopy(dump)
    wrong_dump["ops"][1]["params"]["value"] = 31
    expect_rejected(
        policy,
        lambda: policy.dump_projection(
            wrong_dump,
            "xlsx",
            expected_ops=expected_dump_ops,
        ),
    )
    wrong_get = copy.deepcopy(get_result)
    wrong_get["data"]["cells"][1]["raw"]["value"] = 31
    wrong_get["data"]["cells"][1]["value"] = "31"
    expect_rejected(
        policy,
        lambda: policy.validate_xlsx_get_semantics(
            wrong_get,
            policy.expected_xlsx_projection(xlsx_batch(policy), final=True),
        ),
    )
    bad_preview = {
        **preview,
        "data": {**preview["data"], "charts_rendered": -1},
    }
    expect_rejected(policy, lambda: policy.preview_projection(bad_preview, "xlsx"))
    bad_truncation = {
        **preview,
        "data": {
            **preview["data"],
            "truncation": {
                **preview["data"]["truncation"],
                "truncated_sheets": 0,
            },
        },
    }
    expect_rejected(
        policy,
        lambda: policy.preview_projection(bad_truncation, "xlsx"),
    )
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
                if format_name == "docx" and final:
                    semantics = inspector(
                        root,
                        record,
                        relative,
                        final,
                        expected_annotation_ids=annotation_ids,
                    )
                else:
                    semantics = inspector(root, record, relative, final)
                assert semantics["template_state"] == (
                    "merged" if final else "placeholder"
                )
                if format_name == "xlsx":
                    assert semantics["projection"] == policy.expected_xlsx_projection(
                        xlsx_batch(policy),
                        final=final,
                    )
        wrong_thread_path = os.path.join(root, "safe", "docx-wrong-thread.zip")
        write_fixture(
            wrong_thread_path,
            docx_fixture(policy, True, resolve_reply=True),
        )
        wrong_thread_info = os.stat(wrong_thread_path)
        with open(wrong_thread_path, "rb") as stream:
            wrong_thread_digest = hashlib.sha256(stream.read()).hexdigest()
        expect_rejected(
            policy,
            lambda: policy.inspect_docx_semantics(
                root,
                {
                    "bytes": wrong_thread_info.st_size,
                    "path": "safe/docx-wrong-thread.zip",
                    "sha256": wrong_thread_digest,
                },
                "wrong-target DOCX thread",
                True,
                expected_annotation_ids=annotation_ids,
            ),
        )
        wrong_anchor_path = os.path.join(root, "safe", "docx-wrong-anchor.zip")
        write_fixture(
            wrong_anchor_path,
            docx_fixture(policy, True, anchor_paragraph=2),
        )
        wrong_anchor_info = os.stat(wrong_anchor_path)
        with open(wrong_anchor_path, "rb") as stream:
            wrong_anchor_digest = hashlib.sha256(stream.read()).hexdigest()
        expect_rejected(
            policy,
            lambda: policy.inspect_docx_semantics(
                root,
                {
                    "bytes": wrong_anchor_info.st_size,
                    "path": "safe/docx-wrong-anchor.zip",
                    "sha256": wrong_anchor_digest,
                },
                "wrong-anchor DOCX thread",
                True,
                expected_annotation_ids=annotation_ids,
            ),
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
