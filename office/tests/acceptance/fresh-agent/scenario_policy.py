#!/usr/bin/env python3
"""Build or verify host-derived fresh-agent scenario evidence."""

import hashlib
import json
import math
import os
import re
import stat
import sys
import tempfile
import zipfile
from xml.etree import ElementTree


MAX_JSON_BYTES = 8 * 1024 * 1024
MAX_BOUND_BYTES = 128 * 1024 * 1024
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")
SAFE_PATH = re.compile(r"^[a-z0-9._/-]+$")
RUNTIMES = ("native", "wasm")
FORMATS = ("xlsx", "docx")
FINAL_CONSUMERS = (
    "identify",
    "outline",
    "get",
    "text",
    "query",
    "validate",
    "issues",
    "preview",
    "dump",
    "raw",
)
COMPARE_OPERATIONS = (
    "outline",
    "get",
    "text",
    "query",
    "validate",
    "issues",
    "raw",
)
XLSX_CONTENT_MARKER = "F1B-XLSX-REPRESENTATIVE-V1"
DOCX_HEADING_MARKER = "F1B-DOCX-HEADING-V1"
DOCX_LIST_MARKER = "F1B-DOCX-LIST-V1"
DOCX_TABLE_MARKER = "F1B-DOCX-TABLE-V1"
DOCX_LINK_TARGET = "https://example.invalid/f1b"
TEMPLATE_KEY = "agent_name"
TEMPLATE_MARKERS = {
    "xlsx": "F1B-XLSX-TEMPLATE-V1",
    "docx": "F1B-DOCX-TEMPLATE-V1",
}
COMMENT_MARKER = "F1B-DOCX-COMMENT-V1"
REPLY_MARKER = "F1B-DOCX-REPLY-V1"
XLSX_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
CHART_NS = "http://schemas.openxmlformats.org/drawingml/2006/chart"
WORD_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
OFFICE_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
WORD_2012_NS = "http://schemas.microsoft.com/office/word/2012/wordml"
MAX_PACKAGE_ENTRIES = 4096
MAX_SEMANTIC_XML_BYTES = 16 * 1024 * 1024
MAX_SEMANTIC_TOTAL_BYTES = 64 * 1024 * 1024


class ScenarioError(Exception):
    pass


def fail(message):
    raise ScenarioError(message)


def canonical_bytes(value):
    return json.dumps(
        value,
        ensure_ascii=True,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def value_sha256(value):
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def safe_relative_path(value, label):
    if not isinstance(value, str) or not value or not SAFE_PATH.fullmatch(value):
        fail("%s is not a portable lowercase relative path" % label)
    if (
        value.startswith(("/", "./", "../"))
        or value.endswith("/")
        or "//" in value
        or any(part in ("", ".", "..") for part in value.split("/"))
    ):
        fail("%s is not a canonical relative path" % label)
    return value


def inspect_bound_file(root, relative, label, max_bytes=MAX_BOUND_BYTES):
    relative = safe_relative_path(relative, label)
    components = relative.split("/")
    directory_flags = os.O_RDONLY
    if hasattr(os, "O_DIRECTORY"):
        directory_flags |= os.O_DIRECTORY
    if hasattr(os, "O_NOFOLLOW"):
        directory_flags |= os.O_NOFOLLOW
    descriptor = os.open(root, directory_flags)
    try:
        for component in components[:-1]:
            child = os.open(component, directory_flags, dir_fd=descriptor)
            info = os.fstat(child)
            if not stat.S_ISDIR(info.st_mode):
                os.close(child)
                fail("%s traverses a non-directory" % label)
            if info.st_uid != os.geteuid() or info.st_mode & 0o077:
                os.close(child)
                fail("%s traverses a non-private directory" % label)
            os.close(descriptor)
            descriptor = child
        file_flags = os.O_RDONLY
        if hasattr(os, "O_NOFOLLOW"):
            file_flags |= os.O_NOFOLLOW
        if hasattr(os, "O_NONBLOCK"):
            file_flags |= os.O_NONBLOCK
        file_descriptor = os.open(components[-1], file_flags, dir_fd=descriptor)
        try:
            before = os.fstat(file_descriptor)
            if not stat.S_ISREG(before.st_mode):
                fail("%s is not a physical regular file" % label)
            if (
                before.st_uid != os.geteuid()
                or before.st_nlink != 1
                or before.st_mode & 0o077
            ):
                fail("%s is not an owned, single-link private file" % label)
            if not 0 < before.st_size <= max_bytes:
                fail("%s size is outside 1..%d" % (label, max_bytes))
            digest = hashlib.sha256()
            payload = bytearray()
            total = 0
            while True:
                chunk = os.read(file_descriptor, 1024 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > max_bytes:
                    fail("%s grew beyond %d bytes" % (label, max_bytes))
                digest.update(chunk)
                if max_bytes <= MAX_JSON_BYTES:
                    payload.extend(chunk)
            after = os.fstat(file_descriptor)
            identity = lambda info: (
                info.st_dev,
                info.st_ino,
                info.st_mode,
                info.st_uid,
                info.st_nlink,
                info.st_size,
                info.st_mtime_ns,
                info.st_ctime_ns,
            )
            if total != before.st_size or identity(before) != identity(after):
                fail("%s changed while it was read" % label)
            return {
                "bytes": total,
                "path": relative,
                "sha256": digest.hexdigest(),
            }, bytes(payload)
        finally:
            os.close(file_descriptor)
    finally:
        os.close(descriptor)


def validate_digest_record(record, label):
    core_keys = {"bytes", "path", "sha256"}
    bound_keys = core_keys | {"access", "argument_index", "role"}
    if not isinstance(record, dict) or set(record) not in (
        core_keys,
        core_keys | {"schema"},
        bound_keys,
    ):
        fail("%s has an unexpected digest-record shape" % label)
    if "schema" in record and (
        not isinstance(record["schema"], str) or not record["schema"]
    ):
        fail("%s has an invalid result schema" % label)
    safe_relative_path(record["path"], label + " path")
    if (
        not isinstance(record["bytes"], int)
        or isinstance(record["bytes"], bool)
        or not 0 < record["bytes"] <= MAX_BOUND_BYTES
    ):
        fail("%s has an invalid byte count" % label)
    if not isinstance(record["sha256"], str) or not HEX_SHA256.fullmatch(
        record["sha256"]
    ):
        fail("%s has an invalid SHA-256 digest" % label)
    if set(record) == bound_keys:
        if record["access"] not in ("input", "input-output", "output"):
            fail("%s has an invalid path access" % label)
        if (
            not isinstance(record["argument_index"], int)
            or isinstance(record["argument_index"], bool)
            or record["argument_index"] < 0
        ):
            fail("%s has an invalid argument index" % label)
        if not isinstance(record["role"], str) or not record["role"]:
            fail("%s has an invalid path role" % label)
    return {key: record[key] for key in core_keys}


def validate_artifact_role(event, operation, label):
    artifact = event.get("artifact")
    validate_digest_record(artifact, label + " artifact")
    if "role" not in artifact:
        fail("%s artifact omits its command path role" % label)
    if operation == "batch":
        accepted = (
            artifact["role"] == "package-output"
            and artifact["access"] == "output"
        ) or (
            artifact["role"] == "package"
            and artifact["access"] == "input-output"
        )
    elif operation in ("create", "template", "replay", "annotate"):
        accepted = (
            artifact["role"] == "package-output"
            and artifact["access"] == "output"
        )
    else:
        accepted = artifact["role"] == "package" and artifact["access"] == "input"
    if not accepted:
        fail("%s follows the wrong command path role" % label)
    produced = event.get("produced")
    if operation == "preview":
        validate_digest_record(produced, label + " preview output")
        if "role" not in produced:
            fail("%s preview output omits its command path role" % label)
        if produced["role"] != "preview-output" or produced["access"] != "output":
            fail("%s follows the wrong preview output role" % label)
    elif produced is not None:
        fail("%s unexpectedly records a produced side artifact" % label)


def read_record(root, record, label, parse_json=False):
    expected = validate_digest_record(record, label)
    observed, payload = inspect_bound_file(
        root,
        record["path"],
        label,
        MAX_JSON_BYTES if parse_json else MAX_BOUND_BYTES,
    )
    if observed != expected:
        fail("%s changed after its recorded event" % label)
    if not parse_json:
        return None
    try:
        return json.loads(payload.decode("utf-8"))
    except (UnicodeError, ValueError) as error:
        raise ScenarioError("%s is not one strict UTF-8 JSON value" % label) from error


def load_json_file(path, label, max_bytes=MAX_JSON_BYTES):
    info = os.lstat(path)
    if not stat.S_ISREG(info.st_mode) or info.st_size > max_bytes:
        fail("%s is not a bounded regular file" % label)
    with open(path, "r", encoding="utf-8") as stream:
        value = json.load(stream)
        if stream.read(1):
            fail("%s has trailing content" % label)
    return value


def input_record(event, role):
    matches = [record for record in event["inputs"] if record["role"] == role]
    if len(matches) != 1:
        fail("workflow event needs exactly one %s input" % role)
    return matches[0]


def json_contains(value, expected):
    if value == expected:
        return True
    if isinstance(value, list):
        return any(json_contains(item, expected) for item in value)
    if isinstance(value, dict):
        return any(json_contains(item, expected) for item in value.values())
    return False


def require_object(value, label):
    if not isinstance(value, dict):
        fail("%s must be an object" % label)
    return value


def open_semantic_package(root, record, label):
    read_record(root, record, label)
    path = os.path.join(root, record["path"])
    try:
        archive = zipfile.ZipFile(path, "r")
    except (OSError, zipfile.BadZipFile) as error:
        raise ScenarioError("%s is not a readable Office package" % label) from error
    entries = archive.infolist()
    if not entries or len(entries) > MAX_PACKAGE_ENTRIES:
        archive.close()
        fail("%s has an invalid package entry count" % label)
    total = sum(entry.file_size for entry in entries)
    if total > MAX_SEMANTIC_TOTAL_BYTES:
        archive.close()
        fail("%s is too large for semantic verification" % label)
    return archive


def package_xml(archive, name, label, required=True):
    try:
        info = archive.getinfo(name)
    except KeyError:
        if required:
            fail("%s omits %s" % (label, name))
        return None
    if info.file_size <= 0 or info.file_size > MAX_SEMANTIC_XML_BYTES:
        fail("%s has an invalid %s size" % (label, name))
    try:
        return ElementTree.fromstring(archive.read(info))
    except (OSError, ElementTree.ParseError, RuntimeError) as error:
        raise ScenarioError("%s has malformed %s" % (label, name)) from error


def element_text(element, namespace):
    return "".join(
        node.text or "" for node in element.iter("{%s}t" % namespace)
    )


def inspect_xlsx_semantics(root, record, label, final):
    with open_semantic_package(root, record, label) as archive:
        shared = []
        shared_root = package_xml(
            archive,
            "xl/sharedStrings.xml",
            label,
            required=False,
        )
        if shared_root is not None:
            shared = [
                element_text(item, XLSX_NS)
                for item in shared_root.findall("{%s}si" % XLSX_NS)
            ]
        strings = []
        numeric = formula = False
        worksheets = sorted(
            info.filename
            for info in archive.infolist()
            if re.fullmatch(r"xl/worksheets/sheet[0-9]+\.xml", info.filename)
        )
        if not worksheets:
            fail("%s has no worksheets" % label)
        for name in worksheets:
            root_element = package_xml(archive, name, label)
            for cell in root_element.iter("{%s}c" % XLSX_NS):
                formula_node = cell.find("{%s}f" % XLSX_NS)
                if formula_node is not None and (formula_node.text or "").strip():
                    formula = True
                kind = cell.get("t")
                value = cell.find("{%s}v" % XLSX_NS)
                if kind == "s" and value is not None and value.text is not None:
                    try:
                        index = int(value.text)
                        strings.append(shared[index])
                    except (ValueError, IndexError) as error:
                        raise ScenarioError("%s has an invalid shared string" % label) from error
                elif kind == "inlineStr":
                    inline = cell.find("{%s}is" % XLSX_NS)
                    if inline is not None:
                        strings.append(element_text(inline, XLSX_NS))
                elif kind in ("str", "e"):
                    if kind == "str" and value is not None:
                        strings.append(value.text or "")
                elif value is not None and value.text is not None:
                    try:
                        numeric = numeric or math.isfinite(float(value.text))
                    except ValueError:
                        pass
        chart = False
        chart_series = 0
        for info in archive.infolist():
            if not re.fullmatch(r"xl/charts/chart[0-9]+\.xml", info.filename):
                continue
            chart_root = package_xml(archive, info.filename, label)
            for kind in ("barChart", "lineChart", "pieChart"):
                for chart_node in chart_root.iter("{%s}%s" % (CHART_NS, kind)):
                    series = list(chart_node.findall("{%s}ser" % CHART_NS))
                    if series:
                        chart = True
                        chart_series += len(series)
        joined = "\n".join(strings)
        expected = TEMPLATE_MARKERS["xlsx"] if final else "{{%s}}" % TEMPLATE_KEY
        forbidden = "{{%s}}" % TEMPLATE_KEY if final else TEMPLATE_MARKERS["xlsx"]
        if (
            XLSX_CONTENT_MARKER not in strings
            or expected not in strings
            or forbidden in joined
            or not numeric
            or not formula
            or not chart
        ):
            fail("%s lacks representative XLSX content, formula, chart, or template state" % label)
        return {
            "chart_series": chart_series,
            "formula": formula,
            "numeric": numeric,
            "representative_marker": True,
            "template_state": "merged" if final else "placeholder",
            "worksheets": len(worksheets),
        }


def inspect_docx_semantics(root, record, label, final):
    with open_semantic_package(root, record, label) as archive:
        document = package_xml(archive, "word/document.xml", label)
        paragraphs = list(document.iter("{%s}p" % WORD_NS))
        paragraph_texts = [element_text(paragraph, WORD_NS) for paragraph in paragraphs]
        heading = any(
            text == DOCX_HEADING_MARKER
            and paragraph.find(
                "{%s}pPr/{%s}pStyle" % (WORD_NS, WORD_NS)
            ) is not None
            and paragraph.find(
                "{%s}pPr/{%s}pStyle" % (WORD_NS, WORD_NS)
            ).get("{%s}val" % WORD_NS) == "Heading1"
            for paragraph, text in zip(paragraphs, paragraph_texts)
        )
        listed = any(
            DOCX_LIST_MARKER in text
            and paragraph.find("{%s}pPr/{%s}numPr" % (WORD_NS, WORD_NS)) is not None
            for paragraph, text in zip(paragraphs, paragraph_texts)
        )
        table = any(
            DOCX_TABLE_MARKER in element_text(node, WORD_NS)
            for node in document.iter("{%s}tbl" % WORD_NS)
        )
        relationships = package_xml(
            archive,
            "word/_rels/document.xml.rels",
            label,
        )
        hyperlink_ids = {
            node.get("{%s}id" % OFFICE_REL_NS)
            for node in document.iter("{%s}hyperlink" % WORD_NS)
        }
        hyperlink = any(
            relationship.get("Id") in hyperlink_ids
            and relationship.get("Target") == DOCX_LINK_TARGET
            and relationship.get("TargetMode") == "External"
            for relationship in relationships.iter("{%s}Relationship" % REL_NS)
        )
        document_text = "\n".join(paragraph_texts)
        expected = TEMPLATE_MARKERS["docx"] if final else "{{%s}}" % TEMPLATE_KEY
        forbidden = "{{%s}}" % TEMPLATE_KEY if final else TEMPLATE_MARKERS["docx"]
        if not all((heading, listed, table, hyperlink)) or expected not in document_text or forbidden in document_text:
            fail("%s lacks representative DOCX structure or template state" % label)
        result = {
            "external_hyperlink": True,
            "heading": True,
            "list": True,
            "table": True,
            "template_state": "merged" if final else "placeholder",
        }
        if final:
            comments = package_xml(archive, "word/comments.xml", label)
            comments_text = element_text(comments, WORD_NS)
            extended = package_xml(archive, "word/commentsExtended.xml", label)
            records = list(extended.iter("{%s}commentEx" % WORD_2012_NS))
            resolved = any(
                record.get("{%s}done" % WORD_2012_NS) in ("1", "true")
                for record in records
            )
            reply = any(
                record.get("{%s}paraIdParent" % WORD_2012_NS) is not None
                for record in records
            )
            if (
                COMMENT_MARKER not in comments_text
                or REPLY_MARKER not in comments_text
                or len(list(comments.iter("{%s}comment" % WORD_NS))) < 2
                or not resolved
                or not reply
            ):
                fail("%s lacks the authored comment, reply, or resolved thread state" % label)
            result["annotations"] = "add-reply-resolve"
        return result


def validate_xlsx_batch(value):
    value = require_object(value, "representative XLSX batch")
    if value.get("schema") != "xlsx.batch/2" or not isinstance(value.get("ops"), list):
        fail("representative XLSX batch must use xlsx.batch/2")
    text = number = formula = chart = placeholder = False
    for entry in value["ops"]:
        if not isinstance(entry, dict) or set(entry) != {"op", "params"}:
            continue
        operation = entry["op"]
        params = entry["params"]
        if not isinstance(params, dict):
            continue
        if operation == "set" and params.get("value") == XLSX_CONTENT_MARKER:
            text = True
        if (
            operation == "set"
            and isinstance(params.get("value"), (int, float))
            and not isinstance(params.get("value"), bool)
        ):
            number = True
        if operation == "formula" and isinstance(params.get("formula"), str):
            formula = bool(params["formula"])
        if operation == "chart" and all(
            isinstance(params.get(key), str) and params[key]
            for key in ("sheet", "anchor", "categories", "values")
        ):
            chart = True
        if operation == "set" and params.get("value") == "{{%s}}" % TEMPLATE_KEY:
            placeholder = True
    if not all((text, number, formula, chart, placeholder)):
        fail("representative XLSX batch omits text, number, formula, chart, or template input")
    return value_sha256(value)


def validate_docx_batch(value):
    value = require_object(value, "representative DOCX batch")
    if value.get("schema") != "docx.batch/2" or not isinstance(value.get("ops"), list):
        fail("representative DOCX batch must use docx.batch/2")
    heading = placeholder = listed = table = hyperlink = False
    for entry in value["ops"]:
        if not isinstance(entry, dict) or set(entry) != {"op", "params"}:
            continue
        operation = entry["op"]
        params = entry["params"]
        if not isinstance(params, dict):
            continue
        if (
            operation == "paragraph"
            and params.get("text") == DOCX_HEADING_MARKER
            and params.get("style") == "Heading1"
        ):
            heading = True
        if operation == "paragraph" and json_contains(params, "{{%s}}" % TEMPLATE_KEY):
            placeholder = True
        if (
            operation == "paragraph"
            and params.get("text") == DOCX_LIST_MARKER
            and isinstance(params.get("list"), dict)
        ):
            listed = True
        if operation == "table" and json_contains(params, DOCX_TABLE_MARKER):
            table = True
        if operation == "paragraph" and json_contains(params, DOCX_LINK_TARGET):
            hyperlink = True
    if not all((heading, placeholder, listed, table, hyperlink)):
        fail("representative DOCX batch omits a heading, placeholder, list, table, or hyperlink")
    return value_sha256(value)


def validate_docx_refusal_script(value):
    value = require_object(value, "DOCX refusal script")
    if set(value) != {"schema", "ops"} or value.get("schema") != "docx.batch/2":
        fail("DOCX refusal script must use the exact docx.batch/2 shape")
    operations = value.get("ops")
    if (
        not isinstance(operations, list)
        or operations
        != [{"op": "f1b_invalid_operation", "params": {}}]
    ):
        fail("DOCX refusal script must contain the prescribed unknown operation")
    return value_sha256(value)


def validate_template_data(value, format_name):
    value = require_object(value, "%s template data" % format_name)
    if value.get("schema") != "office.template.data/1":
        fail("%s template data has the wrong schema" % format_name)
    values = value.get("values")
    marker = TEMPLATE_MARKERS[format_name]
    if not isinstance(values, dict) or values.get(TEMPLATE_KEY) != marker:
        fail("%s template data omits the readback marker" % format_name)
    return value_sha256(value)


def validate_annotation_script(value):
    value = require_object(value, "DOCX annotation script")
    if value.get("schema") != "docx.annotation-batch/1":
        fail("DOCX annotation script has the wrong schema")
    operations = value.get("ops")
    if not isinstance(operations, list) or len(operations) < 3:
        fail("DOCX annotation script needs add, reply, and resolve operations")
    names = [entry.get("op") if isinstance(entry, dict) else None for entry in operations]
    required = ("comment_add", "comment_reply", "comment_resolve")
    positions = []
    for name in required:
        try:
            positions.append(names.index(name))
        except ValueError as error:
            raise ScenarioError("DOCX annotation script omits %s" % name) from error
    if positions != sorted(positions):
        fail("DOCX annotation add, reply, and resolve operations are out of order")
    if not json_contains(operations[positions[0]], COMMENT_MARKER):
        fail("DOCX annotation add omits its marker body")
    if not json_contains(operations[positions[1]], REPLY_MARKER):
        fail("DOCX annotation reply omits its marker body")
    return value_sha256(value)


def dump_projection(value, format_name):
    value = require_object(value, "%s dump" % format_name)
    if value.get("schema") != "office.dump/1" or value.get("format") != format_name:
        fail("%s dump has the wrong schema or format" % format_name)
    if not isinstance(value.get("replay"), dict) or not isinstance(value.get("ops"), list):
        fail("%s dump omits its replay projection" % format_name)
    if not isinstance(value.get("assets"), dict):
        fail("%s dump assets must be an object" % format_name)
    for field in ("residual", "warnings"):
        if not isinstance(value.get(field), list):
            fail("%s dump omits %s loss evidence" % (format_name, field))
    if not isinstance(value.get("stats"), dict):
        fail("%s dump omits stats" % format_name)
    return {key: item for key, item in value.items() if key != "source"}


def parse_failure_result(output, expected_code=None):
    if not isinstance(output, str) or not output.strip():
        fail("failed Office event has no typed diagnostic")
    try:
        value = json.loads(output.strip())
    except ValueError as error:
        raise ScenarioError("failed Office event is not one JSON diagnostic") from error
    if (
        not isinstance(value, dict)
        or value.get("schema") != "office.output/1"
        or value.get("success") is not False
        or not isinstance(value.get("error"), dict)
        or not isinstance(value["error"].get("code"), str)
        or not value["error"]["code"].startswith("office.")
    ):
        fail("failed Office event lacks an office.output/1 typed error")
    if expected_code is not None and value["error"]["code"] != expected_code:
        fail("failed Office event has unexpected code %s" % value["error"]["code"])
    return value["error"]["code"]


def preview_projection(value, format_name):
    value = require_object(value, "%s preview result" % format_name)
    data = value.get("data")
    if (
        value.get("schema") != "office.output/1"
        or value.get("success") is not True
        or not isinstance(data, dict)
        or data.get("schema") != "office.preview/1"
        or data.get("format") != format_name
    ):
        fail("%s preview result has the wrong envelope" % format_name)
    projection = {"format": format_name}
    for field in ("charts_rendered", "charts_placeholder", "images_embedded"):
        if (
            not isinstance(data.get(field), int)
            or isinstance(data.get(field), bool)
            or data[field] < 0
        ):
            fail("%s preview result omits %s" % (format_name, field))
        projection[field] = data[field]
    truncation = data.get("truncation")
    required = ("max_rows", "max_cols", "truncated_sheets", "images_omitted")
    if not isinstance(truncation, dict) or any(
        not isinstance(truncation.get(field), int)
        or isinstance(truncation.get(field), bool)
        or truncation[field] < 0
        for field in required
    ):
        fail("%s preview result omits truncation evidence" % format_name)
    projection["truncation"] = truncation
    return projection


def normalize_runtime_paths(value, runtime):
    if isinstance(value, str):
        return value.replace(runtime + "/", "$runtime/")
    if isinstance(value, list):
        return [normalize_runtime_paths(item, runtime) for item in value]
    if isinstance(value, dict):
        return {
            key: normalize_runtime_paths(item, runtime)
            for key, item in value.items()
            if key not in ("diagnostics", "messages", "warnings")
        }
    return value


def raw_output_maps(commands, raw_commands):
    if not isinstance(commands, list) or not isinstance(raw_commands, list):
        fail("command ledgers must be arrays")
    if len(commands) != len(raw_commands):
        fail("normalized and raw command ledgers have different lengths")
    raw_by_id = {}
    indexes = {}
    for index, (command, raw) in enumerate(zip(commands, raw_commands)):
        if not isinstance(command, dict) or not isinstance(raw, dict):
            fail("command ledger entry is not an object")
        if command.get("id") != raw.get("id"):
            fail("normalized command order diverges from the raw transcript")
        output = raw.get("aggregated_output")
        if not isinstance(output, str):
            fail("raw command output is not text")
        encoded = output.encode("utf-8")
        if command.get("output_bytes") != len(encoded) or command.get(
            "output_sha256"
        ) != hashlib.sha256(encoded).hexdigest():
            fail("raw command output contradicts the normalized ledger")
        raw_by_id[command["id"]] = output
        indexes[command["id"]] = index
    return raw_by_id, indexes


def workflow_map(workflows):
    if (
        not isinstance(workflows, dict)
        or workflows.get("schema") != "office.fresh-agent.workflows/5"
        or not isinstance(workflows.get("workflows"), list)
    ):
        fail("workflow ledger has the wrong schema")
    result = {}
    for workflow in workflows["workflows"]:
        key = (
            workflow.get("runtime"),
            workflow.get("format"),
            workflow.get("operation"),
        )
        if key in result or not isinstance(workflow.get("events"), list):
            fail("workflow ledger contains duplicate or invalid entries")
        if len(workflow["events"]) != 1:
            fail("each workflow ledger entry needs exactly one canonical event")
        result[key] = workflow["events"][0]
    return result


def baseline_event(workflows, runtime, format_name, operation):
    try:
        event = workflows[(runtime, format_name, operation)]
    except KeyError as error:
        raise ScenarioError(
            "missing canonical workflow %s/%s/%s"
            % (runtime, format_name, operation)
        ) from error
    expected_path = "matrix-%s-%s-%s.json" % (runtime, format_name, operation)
    if event.get("result", {}).get("path") != expected_path:
        fail("canonical workflow result path must be %s" % expected_path)
    validate_artifact_role(
        event,
        operation,
        "%s/%s/%s" % (runtime, format_name, operation),
    )
    return event


def find_supplemental(commands, result_path, expected_argv):
    matches = []
    for command in commands:
        attestation = command.get("attestation")
        if not isinstance(attestation, dict):
            continue
        if attestation.get("result", {}).get("path") == result_path:
            matches.append(command)
    if len(matches) != 1:
        fail("expected exactly one supplemental event for %s" % result_path)
    event = matches[0]
    if event.get("product_argv") != expected_argv or event.get("status") != "completed":
        fail("supplemental event %s has the wrong command" % result_path)
    return event


def require_lineage(prior, later, label):
    validate_digest_record(prior, label + " prior")
    validate_digest_record(later["snapshot"], label + " input")
    if prior["sha256"] != later["snapshot"]["sha256"] or prior["bytes"] != later[
        "snapshot"
    ]["bytes"]:
        fail("scenario lineage breaks at %s" % label)
    return {
        "bytes": prior["bytes"],
        "from": prior["path"],
        "sha256": prior["sha256"],
        "to": later["path"],
    }


def result_json(root, event, label):
    return read_record(root, event["result"], label, parse_json=True)


def supplemental_result(root, command, label):
    return read_record(
        root,
        command["attestation"]["result"],
        label,
        parse_json=True,
    )


def supplemental_file(command, suffix, label):
    matches = [
        record
        for record in command["attestation"]["files"]
        if record["path"].endswith(suffix)
    ]
    if len(matches) != 1:
        fail("%s needs exactly one %s file" % (label, suffix))
    return matches[0]


def exact_commands(commands, argv):
    return [command for command in commands if command.get("argv") == argv]


def command_basename_argv(command):
    argv = command.get("argv")
    if not isinstance(argv, list) or not argv:
        return argv
    return [os.path.basename(argv[0])] + argv[1:]


def one_command(commands, argv, status, label):
    matches = [
        command
        for command in commands
        if command_basename_argv(command) == argv and command.get("status") == status
    ]
    if len(matches) != 1:
        fail("scenario needs exactly one %s command" % label)
    return matches[0]


def host_docx_refusal_map(root, value):
    value = require_object(value, "host DOCX refusal evidence")
    if (
        set(value) != {"schema", "required_count", "refusals"}
        or value.get("schema") != "office.fresh-agent.docx-refusals/1"
        or value.get("required_count") != 2
        or not isinstance(value.get("refusals"), list)
        or len(value["refusals"]) != 2
    ):
        fail("host DOCX refusal evidence has the wrong shape")
    result = {}
    expected_keys = {
        "command",
        "diagnostic",
        "error_code",
        "exit_status",
        "output",
        "output_absent_after",
        "output_absent_before",
        "postcondition",
        "runtime",
        "script",
        "sequence",
        "staging_after",
        "staging_before",
    }
    for sequence, runtime in enumerate(RUNTIMES, start=1):
        entry = value["refusals"][sequence - 1]
        directory = "host-refusal/%s" % runtime
        script_path = directory + "/refusal.json"
        output_path = directory + "/host-refusal-output.docx"
        diagnostic_path = directory + "/diagnostic.json"
        expected_command = [
            "office-%s" % runtime,
            "batch",
            "--format",
            "docx",
            output_path,
            script_path,
            "--json",
        ]
        if (
            not isinstance(entry, dict)
            or set(entry) != expected_keys
            or entry.get("runtime") != runtime
            or entry.get("sequence") != sequence
            or entry.get("command") != expected_command
            or entry.get("error_code") != "office.docx.batch_parse"
            or not isinstance(entry.get("exit_status"), int)
            or isinstance(entry.get("exit_status"), bool)
            or not 0 < entry["exit_status"] <= 255
            or entry.get("output") != output_path
            or entry.get("output_absent_before") is not True
            or entry.get("output_absent_after") is not True
            or entry.get("staging_before") != []
            or entry.get("staging_after") != []
            or entry.get("postcondition") != "immediate-after-process-exit"
        ):
            fail("host DOCX refusal evidence is invalid for %s" % runtime)
        if (
            not isinstance(entry.get("script"), dict)
            or entry["script"].get("path") != script_path
        ):
            fail("host DOCX refusal script path is invalid for %s" % runtime)
        script = read_record(
            root,
            entry["script"],
            "%s host DOCX refusal script" % runtime,
            parse_json=True,
        )
        validate_docx_refusal_script(script)
        if (
            not isinstance(entry.get("diagnostic"), dict)
            or entry["diagnostic"].get("path") != diagnostic_path
        ):
            fail("host DOCX refusal diagnostic path is invalid for %s" % runtime)
        diagnostic = read_record(
            root,
            entry["diagnostic"],
            "%s host DOCX refusal diagnostic" % runtime,
            parse_json=True,
        )
        diagnostic_error = (
            diagnostic.get("error") if isinstance(diagnostic, dict) else None
        )
        if (
            not isinstance(diagnostic, dict)
            or diagnostic.get("schema") != "office.output/1"
            or diagnostic.get("success") is not False
            or not isinstance(diagnostic_error, dict)
            or diagnostic_error.get("code") != "office.docx.batch_parse"
        ):
            fail("host DOCX refusal diagnostic is invalid for %s" % runtime)
        if os.path.lexists(os.path.join(root, output_path)):
            fail("host DOCX refusal output now exists for %s" % runtime)
        leftovers = [
            name
            for name in os.listdir(os.path.join(root, directory))
            if ".office-tmp-" in name or ".office-output-tmp-" in name
        ]
        if leftovers:
            fail("host DOCX refusal staging now exists for %s" % runtime)
        result[runtime] = {
            "diagnostic": entry["diagnostic"],
            "diagnostic_semantic_sha256": value_sha256(diagnostic),
            "error_code": entry["error_code"],
            "execution": "host-controlled-immediate",
            "exit_status": entry["exit_status"],
            "output": output_path,
            "script": entry["script"],
            "script_semantic_sha256": value_sha256(script),
        }
    return result


def validate_refusal(
    root,
    commands,
    raw_outputs,
    indexes,
    runtime,
    format_name,
    final,
    host_docx_refusals,
):
    directory = "%s/%s" % (runtime, format_name)
    executable = "office-%s" % runtime
    if format_name == "xlsx":
        target = directory + "/refusal-target.xlsx"
        before = directory + "/refusal-before.xlsx"
        script = directory + "/refusal.json"
        copy_target = one_command(
            commands,
            ["cp", final["path"], target],
            "completed",
            "%s XLSX refusal target copy" % runtime,
        )
        copy_before = one_command(
            commands,
            ["cp", target, before],
            "completed",
            "%s XLSX refusal before-image copy" % runtime,
        )
        refusal = one_command(
            commands,
            [
                executable,
                "batch",
                final["path"],
                script,
                "--out",
                target,
                "--json",
            ],
            "failed",
            "%s XLSX typed publication refusal" % runtime,
        )
        comparison = one_command(
            commands,
            ["cmp", before, target],
            "completed",
            "%s XLSX refusal comparison" % runtime,
        )
        if not (
            indexes[copy_target["id"]]
            < indexes[copy_before["id"]]
            < indexes[refusal["id"]]
            < indexes[comparison["id"]]
        ):
            fail("%s XLSX refusal evidence is out of order" % runtime)
        code = parse_failure_result(
            raw_outputs[refusal["id"]],
            "office.transaction.output_exists",
        )
        before_record, _ = inspect_bound_file(root, before, "XLSX refusal before-image")
        target_record, _ = inspect_bound_file(root, target, "XLSX refusal target")
        if (
            before_record["sha256"] != target_record["sha256"]
            or before_record["bytes"] != target_record["bytes"]
        ):
            fail("%s XLSX refusal changed its existing target" % runtime)
        return {
            "comparison_event": comparison["id"],
            "error_code": code,
            "failure_event": refusal["id"],
            "preserved": target_record,
        }

    return host_docx_refusals[runtime]


def validate_scenario(
    root,
    commands,
    workflows,
    raw_outputs,
    indexes,
    host_docx_refusals,
    runtime,
    format_name,
):
    canonical = {
        operation: baseline_event(workflows, runtime, format_name, operation)
        for operation in (
            ("create",) if format_name == "xlsx" else ()
        )
        + (
            "batch",
            "identify",
            "outline",
            "get",
            "text",
            "query",
            "validate",
            "issues",
            "preview",
            "template",
            "dump",
            "replay",
            "raw",
        )
        + (("annotate",) if format_name == "docx" else ())
    }
    lineage = []
    batch_script = read_record(
        root,
        input_record(canonical["batch"], "script")["snapshot"],
        "%s/%s batch input" % (runtime, format_name),
        parse_json=True,
    )
    if format_name == "xlsx":
        batch_digest = validate_xlsx_batch(batch_script)
        lineage.append(
            require_lineage(
                canonical["create"]["artifact"],
                input_record(canonical["batch"], "package"),
                "%s XLSX create-to-batch" % runtime,
            )
        )
    else:
        batch_digest = validate_docx_batch(batch_script)
    if format_name == "xlsx":
        batch_semantics = inspect_xlsx_semantics(
            root,
            canonical["batch"]["artifact"],
            "%s XLSX authored package" % runtime,
            final=False,
        )
    else:
        batch_semantics = inspect_docx_semantics(
            root,
            canonical["batch"]["artifact"],
            "%s DOCX authored package" % runtime,
            final=False,
        )
    lineage.append(
        require_lineage(
            canonical["batch"]["artifact"],
            input_record(canonical["template"], "package"),
            "%s/%s batch-to-template" % (runtime, format_name),
        )
    )
    template_data = read_record(
        root,
        input_record(canonical["template"], "template-data")["snapshot"],
        "%s/%s template input" % (runtime, format_name),
        parse_json=True,
    )
    template_digest = validate_template_data(template_data, format_name)
    final_event = canonical["template"]
    annotation_digest = None
    if format_name == "docx":
        lineage.append(
            require_lineage(
                canonical["template"]["artifact"],
                input_record(canonical["annotate"], "package"),
                "%s DOCX template-to-annotation" % runtime,
            )
        )
        annotation = read_record(
            root,
            input_record(canonical["annotate"], "annotation-script")["snapshot"],
            "%s DOCX annotation input" % runtime,
            parse_json=True,
        )
        annotation_digest = validate_annotation_script(annotation)
        annotation_result = result_json(
            root,
            canonical["annotate"],
            "%s DOCX annotation result" % runtime,
        )
        data = annotation_result.get("data", {})
        if (
            data.get("ops_applied", 0) < 3
            or not json_contains(data.get("results"), "comment_add")
            or not json_contains(data.get("results"), "comment_reply")
            or not json_contains(data.get("results"), "comment_resolve")
            or not json_contains(data.get("results"), True)
        ):
            fail("%s DOCX annotation result does not prove add/reply/resolve" % runtime)
        final_event = canonical["annotate"]
    final = final_event["artifact"]
    if format_name == "xlsx":
        final_semantics = inspect_xlsx_semantics(
            root,
            final,
            "%s XLSX final package" % runtime,
            final=True,
        )
    else:
        final_semantics = inspect_docx_semantics(
            root,
            final,
            "%s DOCX final package" % runtime,
            final=True,
        )
    for operation in FINAL_CONSUMERS:
        lineage.append(
            require_lineage(
                final,
                input_record(canonical[operation], "package"),
                "%s/%s final-to-%s" % (runtime, format_name, operation),
            )
        )
    text_result = result_json(
        root,
        canonical["text"],
        "%s/%s template readback" % (runtime, format_name),
    )
    if not json_contains(text_result, TEMPLATE_MARKERS[format_name]):
        fail("%s/%s text result omits the template marker" % (runtime, format_name))
    if format_name == "docx":
        outline = result_json(root, canonical["outline"], "%s DOCX outline" % runtime)
        comments = outline.get("data", {}).get("counts", {}).get("comments")
        if not isinstance(comments, int) or comments < 2:
            fail("%s DOCX outline does not read back two annotations" % runtime)

    preview_2_path = "scenario-%s-%s-preview-2.json" % (runtime, format_name)
    preview_2_file = "%s/%s/preview-2.html" % (runtime, format_name)
    preview_2 = find_supplemental(
        commands,
        preview_2_path,
        [
            "office-%s" % runtime,
            "preview",
            final["path"],
            "--output",
            preview_2_file,
            "--json",
        ],
    )
    preview_2_input = input_record(preview_2["attestation"], "package")
    lineage.append(
        require_lineage(
            final,
            preview_2_input,
            "%s/%s final-to-second-preview" % (runtime, format_name),
        )
    )
    preview_2_result = supplemental_result(
        root,
        preview_2,
        "%s/%s second preview result" % (runtime, format_name),
    )
    preview_2_projection = preview_projection(preview_2_result, format_name)
    if preview_2_result.get("data", {}).get("output") != preview_2_file:
        fail("%s/%s second preview result is invalid" % (runtime, format_name))
    first_preview = canonical["preview"]["produced"]
    expected_first_preview = "%s/%s/preview-1.html" % (runtime, format_name)
    if first_preview.get("path") != expected_first_preview:
        fail("canonical preview output must be %s" % expected_first_preview)
    preview_1_result = result_json(
        root,
        canonical["preview"],
        "%s/%s first preview result" % (runtime, format_name),
    )
    preview_1_projection = preview_projection(preview_1_result, format_name)
    if (
        preview_1_result.get("data", {}).get("output") != expected_first_preview
        or preview_1_projection != preview_2_projection
    ):
        fail("%s/%s preview reports are not deterministic" % (runtime, format_name))
    second_preview = supplemental_file(preview_2, ".html", "second preview")
    read_record(root, first_preview, "first preview")
    read_record(root, second_preview, "second preview")
    if first_preview["sha256"] != second_preview["sha256"] or first_preview[
        "bytes"
    ] != second_preview["bytes"]:
        fail("%s/%s preview output is not deterministic" % (runtime, format_name))

    dump_1 = result_json(root, canonical["dump"], "%s/%s first dump" % (runtime, format_name))
    dump_1_projection = dump_projection(dump_1, format_name)
    lineage.append(
        require_lineage(
            canonical["dump"]["result"],
            input_record(canonical["replay"], "dump"),
            "%s/%s dump-to-replay" % (runtime, format_name),
        )
    )
    replayed = canonical["replay"]["artifact"]
    dump_2_path = "scenario-%s-%s-dump-2.json" % (runtime, format_name)
    dump_2 = find_supplemental(
        commands,
        dump_2_path,
        [
            "office-%s" % runtime,
            "dump",
            replayed["path"],
            "--json",
        ],
    )
    lineage.append(
        require_lineage(
            replayed,
            input_record(dump_2["attestation"], "package"),
            "%s/%s replay-to-second-dump" % (runtime, format_name),
        )
    )
    dump_2_value = supplemental_result(
        root,
        dump_2,
        "%s/%s second dump" % (runtime, format_name),
    )
    dump_2_projection = dump_projection(dump_2_value, format_name)
    if dump_1_projection != dump_2_projection:
        fail("%s/%s dump projection did not reach a fixpoint" % (runtime, format_name))

    refusal = validate_refusal(
        root,
        commands,
        raw_outputs,
        indexes,
        runtime,
        format_name,
        final,
        host_docx_refusals,
    )
    semantic_results = {}
    for operation in COMPARE_OPERATIONS:
        value = result_json(
            root,
            canonical[operation],
            "%s/%s %s result" % (runtime, format_name, operation),
        )
        semantic_results[operation] = normalize_runtime_paths(value, runtime)
    return {
        "annotation_script_sha256": annotation_digest,
        "batch_script_sha256": batch_digest,
        "dump_fixpoint_sha256": value_sha256(dump_1_projection),
        "final_artifact": final,
        "format": format_name,
        "lineage": lineage,
        "package_semantics": {
            "authored": batch_semantics,
            "final": final_semantics,
        },
        "preview": {
            "bytes": first_preview["bytes"],
            "first": first_preview["path"],
            "semantic_sha256": value_sha256(preview_1_projection),
            "second": second_preview["path"],
            "sha256": first_preview["sha256"],
        },
        "refusal": refusal,
        "runtime": runtime,
        "semantic_results": semantic_results,
        "template_data_sha256": template_digest,
        "template_marker": TEMPLATE_MARKERS[format_name],
    }


def build_document(root, commands, raw_commands, workflows, host_docx_refusals):
    raw_outputs, indexes = raw_output_maps(commands, raw_commands)
    mapped_workflows = workflow_map(workflows)
    scenarios = []
    for runtime in RUNTIMES:
        for format_name in FORMATS:
            scenarios.append(
                validate_scenario(
                    root,
                    commands,
                    mapped_workflows,
                    raw_outputs,
                    indexes,
                    host_docx_refusals,
                    runtime,
                    format_name,
                )
            )
    cross_runtime = {}
    for format_name in FORMATS:
        native = next(
            item
            for item in scenarios
            if item["runtime"] == "native" and item["format"] == format_name
        )
        wasm = next(
            item
            for item in scenarios
            if item["runtime"] == "wasm" and item["format"] == format_name
        )
        for field in (
            "annotation_script_sha256",
            "batch_script_sha256",
            "dump_fixpoint_sha256",
            "template_data_sha256",
        ):
            if native[field] != wasm[field]:
                fail("native/Wasm %s differs for %s" % (field, format_name))
        if native["preview"]["semantic_sha256"] != wasm["preview"][
            "semantic_sha256"
        ]:
            fail("native/Wasm preview semantics differ for %s" % format_name)
        if native["semantic_results"] != wasm["semantic_results"]:
            fail("native/Wasm semantic read results differ for %s" % format_name)
        if native["package_semantics"] != wasm["package_semantics"]:
            fail("native/Wasm package semantics differ for %s" % format_name)
        if format_name == "docx":
            for field in (
                "diagnostic_semantic_sha256",
                "error_code",
                "execution",
                "exit_status",
                "script_semantic_sha256",
            ):
                if native["refusal"][field] != wasm["refusal"][field]:
                    fail("native/Wasm DOCX refusal %s differs" % field)
        cross_runtime[format_name] = {
            "dump_fixpoint_sha256": native["dump_fixpoint_sha256"],
            "preview_semantic_sha256": native["preview"]["semantic_sha256"],
            "semantic_results_sha256": value_sha256(native["semantic_results"]),
            "package_semantics_sha256": value_sha256(native["package_semantics"]),
        }
    for scenario in scenarios:
        del scenario["semantic_results"]
    return {
        "cross_runtime": cross_runtime,
        "required_count": 4,
        "scenarios": scenarios,
        "schema": "office.fresh-agent.scenarios/1",
    }


def atomic_write_json(path, value):
    parent = os.path.dirname(os.path.abspath(path))
    descriptor, temporary = tempfile.mkstemp(prefix=".scenario-policy.", dir=parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, ensure_ascii=True, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        if os.path.lexists(path):
            fail("scenario evidence output already exists")
        os.link(temporary, path, follow_symlinks=False)
        os.unlink(temporary)
        temporary = None
    finally:
        if temporary is not None:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass


def main(argv):
    if len(argv) != 8 or argv[1] not in ("build", "verify"):
        print(
            "usage: scenario_policy.py build|verify PROBE_ROOT COMMANDS "
            "RAW_COMMANDS WORKFLOWS DOCX_REFUSALS SCENARIOS",
            file=sys.stderr,
        )
        return 64
    (
        mode,
        root,
        commands_path,
        raw_path,
        workflows_path,
        docx_refusals_path,
        scenarios_path,
    ) = argv[1:]
    root = os.path.realpath(root)
    if not os.path.isdir(root):
        fail("probe root is not a directory")
    commands = load_json_file(commands_path, "command ledger")
    raw_commands = load_json_file(raw_path, "raw command ledger", 64 * 1024 * 1024)
    workflows = load_json_file(workflows_path, "workflow ledger")
    host_docx_refusals = host_docx_refusal_map(
        root,
        load_json_file(docx_refusals_path, "host DOCX refusal evidence"),
    )
    expected = build_document(
        root,
        commands,
        raw_commands,
        workflows,
        host_docx_refusals,
    )
    if mode == "build":
        atomic_write_json(scenarios_path, expected)
    else:
        observed = load_json_file(scenarios_path, "scenario evidence")
        if observed != expected:
            fail("scenario evidence does not match the host-derived state")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except (OSError, ScenarioError, UnicodeError, ValueError) as error:
        print("scenario policy rejected evidence: %s" % error, file=sys.stderr)
        sys.exit(1)
